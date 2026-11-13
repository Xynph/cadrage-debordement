extends SceneTree
const Rooms = preload("res://qa_runner.gd")
const RESOLUTIONS = [Vector2i(1280,720),Vector2i(1366,768),Vector2i(1440,900),Vector2i(1920,1080),Vector2i(2560,1440)]
const ROUTES = ["Réception","Bureau","Effectif","Composition","Préparation","Plan de jeu","Vestiaire","Match","Recrutement","Formation","Centre","Suivi des jeunes","Club","Staff","Travail du club","Stratégie","Finances","Calendrier","Classements","Rivalités","Carrière","Sélections","Presse","Accueil","Création","Packs"]
var app: Control
var output := OS.get_environment("CD_GEOMETRY_OUTPUT")
var failures: Array[String] = []
var records: Array = []
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); printerr("FAIL: ",message)
func settle() -> void:
	await create_timer(.12).timeout
	for i in 8: await process_frame
func worker() -> void:
	var deadline := Time.get_ticks_msec()+60000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec()<deadline: await process_frame
	check(not app.waiting and not app.model.is_empty(),"Worker répond")
	app.timer.stop()
	await settle()
func rect(value: Rect2) -> Array:
	return [snappedf(value.position.x,.01),snappedf(value.position.y,.01),snappedf(value.size.x,.01),snappedf(value.size.y,.01)]
func overflow(value: Rect2, bounds: Rect2) -> Array:
	return [maxf(0,bounds.position.x-value.position.x),maxf(0,bounds.position.y-value.position.y),maxf(0,value.end.x-bounds.end.x),maxf(0,value.end.y-bounds.end.y)]
func useful(c: Control) -> bool:
	return not c is ScrollBar and (c is BaseButton or c is LineEdit or c is TextEdit or c is Label or c is RichTextLabel or c is Range)
func scan(node: Node, viewport: Rect2, scrolls: Array, out: Array, clips: Array, legitimate_scroll: bool = false) -> void:
	if node is Window: return
	if node is Control and not node.is_visible_in_tree(): return
	var in_scroll := legitimate_scroll
	if node is ScrollContainer:
		var h: ScrollBar = node.get_h_scroll_bar()
		var v: ScrollBar = node.get_v_scroll_bar()
		scrolls.append({"path":str(app.get_path_to(node)),"rect":rect(node.get_global_rect()),"horizontal_mode":node.horizontal_scroll_mode,"vertical_mode":node.vertical_scroll_mode,"horizontal_range":maxf(0,h.max_value-h.page),"vertical_range":maxf(0,v.max_value-v.page),"minimum":rect(Rect2(Vector2.ZERO,node.get_combined_minimum_size()))})
		in_scroll = true
	if node is Control and useful(node):
		var bounds: Rect2 = node.get_global_rect()
		var excess := overflow(bounds,viewport)
		if excess.max()>1.5 and not legitimate_scroll: out.append({"path":str(app.get_path_to(node)),"rect":rect(bounds),"overflow":excess})
		var parent := node.get_parent()
		while parent != null and parent != app:
			if parent is Control and parent.clip_contents:
				var clipped := overflow(bounds,parent.get_global_rect())
				if clipped.max()>1.5:
					clips.append({"path":str(app.get_path_to(node)),"by":str(app.get_path_to(parent)),"excess":clipped,"scroll":parent is ScrollContainer,"inside_scroll":legitimate_scroll,"interactive":node is BaseButton or node is LineEdit or node is TextEdit or node is Range,"disabled_horizontal":parent is ScrollContainer and parent.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED,"disabled_vertical":parent is ScrollContainer and parent.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED})
			parent = parent.get_parent()
	for child in node.get_children(): scan(child,viewport,scrolls,out,clips,in_scroll)
func measure(label: String) -> Dictionary:
	var scrolls: Array = []; var out: Array = []; var clips: Array = []
	scan(app,Rect2(Vector2.ZERO,Vector2(root.size)),scrolls,out,clips)
	var record := {"resolution":[root.size.x,root.size.y],"label":label,"route":app.route,"date":app.model.get("meta",{}).get("date"),"content_scale_size":[root.content_scale_size.x,root.content_scale_size.y],"content_scale_mode":root.content_scale_mode,"viewport":rect(root.get_visible_rect()),"scrolls":scrolls,"outside_unscrolled":out,"clips":clips}
	if is_instance_valid(app.body_scroll):
		record.workspace = rect(app.body_scroll.get_global_rect())
		record.body = rect(app.body.get_global_rect())
		record.body_minimum = [app.body.get_combined_minimum_size().x,app.body.get_combined_minimum_size().y]
		record.outer_scroll = maxf(0,app.body_scroll.get_v_scroll_bar().max_value-app.body_scroll.get_v_scroll_bar().page)
	record.important = []
	for id: String in ["CarnetCalendar","CalendarMonthGrid","CalendarWeekGrid","MonthDayDetail","CalendarUpcomingContext","ContextualInvitations","ContextualObserveTraining","ImmersiveInbox","CarnetPreparation"]:
		var item := app.find_child(id,true,false) as Control
		if item != null:
			record.important.append({"name":id,"rect":rect(item.get_global_rect()),"minimum":[item.get_combined_minimum_size().x,item.get_combined_minimum_size().y]})
	records.append(record)
	return record
func capture(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(label+"-"+str(root.size.x)+".png"))
func exposed_rect(control: Control) -> Rect2:
	var visible := Rect2(Vector2.ZERO,Vector2(root.size))
	var ancestor := control.get_parent()
	while ancestor != null and ancestor != app:
		if ancestor is Control and ancestor.clip_contents: visible = visible.intersection(ancestor.get_global_rect())
		ancestor = ancestor.get_parent()
	return visible
func expose(control: Control) -> void:
	var ancestor := control.get_parent()
	while ancestor != null and ancestor != app:
		if ancestor is ScrollContainer:
			ancestor.ensure_control_visible(control)
			await settle()
		ancestor = ancestor.get_parent()
func expose_fast(control: Control) -> void:
	var ancestor := control.get_parent()
	while ancestor != null and ancestor != app:
		if ancestor is ScrollContainer and not ancestor.get_global_rect().grow(1.5).encloses(control.get_global_rect()):
			ancestor.ensure_control_visible(control)
			for frame in 2: await process_frame
		ancestor = ancestor.get_parent()
func audit_interactions(label: String) -> void:
	if label != app.route and label != "Préparation entraînement": return
	var findings: Array = []
	var examined := 0
	var reserved: bool = app.route in ["Effectif","Composition","Match"]
	for control: Control in app.root_content.find_children("*","Control",true,false):
		if not control.is_visible_in_tree() or not (control is BaseButton or control is LineEdit or control is TextEdit): continue
		examined += 1
		if not exposed_rect(control).grow(1.5).encloses(control.get_global_rect()): await expose_fast(control)
		var visible := exposed_rect(control)
		var accessible := visible.grow(1.5).encloses(control.get_global_rect())
		if not accessible: findings.append({"path":str(app.get_path_to(control)),"rect":rect(control.get_global_rect()),"visible_bounds":rect(visible),"overflow":overflow(control.get_global_rect(),visible),"reserved":reserved})
		if not reserved: check(accessible,"Commande entière après défilement "+label+" "+str(root.size)+" "+str(control.name))
	records.append({"resolution":[root.size.x,root.size.y],"label":label+" commandes","route":app.route,"examined":examined,"reserved":reserved,"inaccessible_bounds":findings})
func check_reading(label: String) -> void:
	var actions: Array[Control] = []
	for id: String in ["MonthNext","MonthPrevious","MonthToday","CalendarOpenTraining","CalendarTemplate","CalendarApplyTemplate","ContextualObserveTraining","OfficeSquadAction","OfficeStandingsAction","OfficeMarketAction","OfficeCalendarAction"]:
		var action := app.find_child(id,true,false) as Control
		if action != null: actions.append(action)
	for id: String in ["CalendarProgramScroll","CalendarDayDetailScroll","ContextualPageWorkspace","OfficeReadingScroll"]:
		var scroll := app.find_child(id,true,false) as ScrollContainer
		if scroll == null: continue
		var items := scroll.find_children("*","Control",true,false).filter(func(c: Control): return c.is_visible_in_tree() and useful(c))
		if not items.is_empty(): actions.append(items[-1])
	var fixed: Control = app.find_child("MonthToday",true,false)
	if fixed == null: fixed = app.find_child("ContextualInvitations",true,false)
	if fixed == null: fixed = app.find_child("ContextualObserveTraining",true,false)
	if fixed == null: fixed = app.find_child("OfficePreparationAction",true,false)
	var initial := fixed.get_global_rect() if fixed != null else Rect2()
	var notebook := app.find_child("OpenCoachNotebook",true,false) as Control
	var notebook_initial := notebook.get_global_rect() if notebook != null else Rect2()
	var reading: Array = []
	for control: Control in actions:
		await expose(control)
		var accessible := exposed_rect(control).grow(1.5).encloses(control.get_global_rect())
		check(accessible,"Contenu exposable "+label+" "+str(root.size)+" "+str(control.name))
		reading.append({"path":str(app.get_path_to(control)),"rect":rect(control.get_global_rect()),"visible_bounds":rect(exposed_rect(control)),"accessible":accessible})
	if notebook != null: check(notebook.get_global_rect().is_equal_approx(notebook_initial),"Carnet Gabi fixe "+label+" "+str(root.size))
	if fixed != null:
		check(fixed.get_global_rect().is_equal_approx(initial),"En-tête/action fixe "+label+" "+str(root.size))
		records.append({"resolution":[root.size.x,root.size.y],"label":label+" accessibilité","reading":reading,"fixed":str(fixed.name),"fixed_rect":rect(fixed.get_global_rect())})
		await capture(label+"-last-content")
func dialog_measure(label: String, target: Window = null) -> void:
	await settle()
	var found := false
	var windows: Array = [target] if target != null else app.get_children()
	for candidate: Node in windows:
		if not candidate is Window or not candidate.visible: continue
		var dialog: Window = candidate
		found = true
		var controls: Array = []
		var bounds := Rect2(Vector2.ZERO,Vector2(dialog.size)).intersection(Rect2(-Vector2(dialog.position),Vector2(root.size)))
		for control in dialog.find_children("*","Control",true,false):
			if not control.is_visible_in_tree() or not useful(control): continue
			var scroller := control.get_parent()
			while scroller != dialog and scroller != null:
				if scroller is ScrollContainer:
					scroller.ensure_control_visible(control)
					await process_frame
				scroller = scroller.get_parent()
			var visible_bounds := bounds
			var ancestor := control.get_parent()
			while ancestor != null and ancestor != dialog:
				if ancestor is Control and ancestor.clip_contents: visible_bounds = visible_bounds.intersection(ancestor.get_global_rect())
				ancestor = ancestor.get_parent()
			var accessible := visible_bounds.grow(1.5).encloses(control.get_global_rect())
			var interactive: bool = control is BaseButton or control is LineEdit or control is TextEdit
			if interactive: check(accessible,"Commande dialogue exposable "+label+" "+str(root.size)+" "+str(control.name))
			controls.append({"name":str(dialog.get_path_to(control)),"rect":rect(control.get_global_rect()),"global_rect":rect(Rect2(control.get_global_rect().position+Vector2(dialog.position),control.get_global_rect().size)),"visible_bounds":rect(visible_bounds),"overflow":overflow(control.get_global_rect(),bounds),"interactive":interactive,"accessible":accessible})
		var record := {"resolution":[root.size.x,root.size.y],"label":label,"dialog":rect(Rect2(Vector2(dialog.position),Vector2(dialog.size))),"overflow":overflow(Rect2(Vector2(dialog.position),Vector2(dialog.size)),Rect2(Vector2.ZERO,Vector2(root.size))),"controls":controls}
		records.append(record)
		check(record.overflow.max()<=1.5,"Fenêtre entière "+label+" "+str(root.size))
		await capture(label)
		dialog.hide()
		if dialog != app.file_dialog and dialog != app.pack_manager.picker: dialog.queue_free()
	check(found,"Fenêtre réellement ouverte : "+label)
	await settle()
func dialogs() -> void:
	app.confirm("Mesure de confirmation","Cette décision reste en attente pendant la mesure.",func(): check(false,"Aucune confirmation ne doit être validée"))
	await dialog_measure("confirmation")
	app.notice("Information","Les données du club restent disponibles.")
	await dialog_measure("information")
	app.pause_menu(); await dialog_measure("pause")
	app.settings(); await dialog_measure("preferences")
	app._credits(); await dialog_measure("credits")
	app.open_file(true); await dialog_measure("import-file-picker")
	load("res://ui/preparation_briefing.gd").open_all(app,func(): pass)
	await dialog_measure("preparation-briefing")
	load("res://ui/immersive08/fatigue_overview.gd").open_adjustment(app,app.model.squad[0])
	await dialog_measure("fatigue-adjustment")
	load("res://ui/development_view.gd").open_player(app,str(app.model.squad[0].id))
	await dialog_measure("youth-promotion")
	load("res://ui/academy_pathways_view.gd").open_professional(app,str(app.model.squad[0].id))
	await dialog_measure("youth-loan")
func run() -> void:
	root.size = Vector2i(1920,1080); DisplayServer.window_set_size(root.size)
	app = load("res://main.tscn").instantiate(); root.add_child(app)
	if not app.has_method("_command"):
		printerr("FAIL: scène principale non exécutable ; consulter erreurs de parsing")
		quit(2); return
	await worker()
	print("GEOMETRY setup: app ready")
	if not app._has_career():
		app._command("new_career",{"mode":"common","club":29}); await worker()
	if not await Rooms.settle_club_meetings(app,self,check): await app._close(1); return
	print("GEOMETRY setup: career ready")
	var disk := str(app.model.meta.dataDir).path_join("donnees.json")
	var before := FileAccess.get_sha256(disk)
	var commands: int = app.bridge._next_id
	var requested := OS.get_environment("CD_GEOMETRY_RESOLUTIONS")
	for resolution: Vector2i in RESOLUTIONS:
		if not requested.is_empty() and not str(resolution.x) in requested.split(","): continue
		root.size = resolution; DisplayServer.window_set_size(resolution); await settle()
		for route: String in ROUTES:
			var wanted_routes := OS.get_environment("CD_GEOMETRY_ROUTES")
			if not wanted_routes.is_empty() and not route in wanted_routes.split(","): continue
			app._navigate(route); await settle()
			if is_instance_valid(app.coach): app.coach.close()
			var record := measure(route)
			if route in ["Réception","Préparation","Calendrier","Bureau"]:
				check(record.get("outer_scroll",0)<=1.5,"Page entière "+route+" "+str(resolution)+" scroll="+str(record.get("outer_scroll",0)))
				await capture(route)
				await check_reading(route)
			await audit_interactions(route)
			if route == "Préparation":
				app.Immersive.open_training(app); await settle()
				var training_record := measure("Préparation entraînement")
				check(training_record.get("outer_scroll",0)<=1.5,"Entraînement entier "+str(resolution)+" scroll="+str(training_record.get("outer_scroll",0)))
				await capture("preparation-entrainement")
				await check_reading("Préparation entraînement")
				await audit_interactions("Préparation entraînement")
			if route == "Calendrier":
				var month: Control = app.find_child("CarnetCalendar",true,false)
				if month != null:
					month._view_as("week"); await settle(); measure("Calendrier semaine")
					month._view_as("month"); await settle()
			print("GEOMETRY ",resolution," ",route," scroll=",record.get("outer_scroll",0)," outside=",record.outside_unscrolled.size()," clips=",record.clips.size())
		app._navigate("Bureau"); await settle()
		if OS.get_environment("CD_GEOMETRY_SKIP_DIALOGS") != "1": await dialogs()
	check(app.bridge._next_id==commands and FileAccess.get_sha256(disk)==before,"Navigation de mesure sans commande ni écriture")
	var report := {"checks":checks,"failures":failures,"records":records,"display":DisplayServer.get_name(),"physical_window":[root.size.x,root.size.y],"viewport":rect(root.get_visible_rect()),"content_scale_size":[root.content_scale_size.x,root.content_scale_size.y],"content_scale_mode":root.content_scale_mode,"requested_resolutions":requested,"requested_routes":OS.get_environment("CD_GEOMETRY_ROUTES"),"dialogs_requested":OS.get_environment("CD_GEOMETRY_SKIP_DIALOGS")!="1","profile_unchanged":FileAccess.get_sha256(disk)==before,"excluded":["dialogues conditionnels restants et sous-onglets : inventaire documentaire","rencontres en cours : aucun scénario de match démarré","Sélections : route peut revenir à Réception selon mandat"]}
	var file := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE); file.store_string(JSON.stringify(report,"  ")); file.close()
	print("SMALL WINDOW GEOMETRY ",checks," checks ",failures.size()," failures; output=",output)
	await app._close(0 if failures.is_empty() else 1)

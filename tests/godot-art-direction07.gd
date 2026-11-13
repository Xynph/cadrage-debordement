extends SceneTree
const ContextualFlow = preload("helpers/contextual_flow.gd")
## Catches unreadable light controls, clipped navigation and presentation writes.
var app: Control
var checks := 0
var failures: Array[String] = []
var proof := OS.get_environment("CD_ART07_ARTIFACTS")
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); printerr("FAIL: " + message)
func settle() -> void:
	await create_timer(.12).timeout
	for i in 8: await process_frame
func worker() -> void:
	var limit := Time.get_ticks_msec()+30000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec()<limit: await process_frame
	check(not app.waiting and not app.model.is_empty(), "Worker répond")
	app.timer.stop(); await settle()
func command(id: String, payload: Dictionary = {}) -> void:
	app._command(id,payload); await worker()
	check(app.bridge.last_response_ok,"Worker réel " + id+" "+app.last_error)
func contrast(a: Color,b: Color) -> float:
	var first := a.srgb_to_linear().get_luminance()
	var second := b.srgb_to_linear().get_luminance()
	return (maxf(first,second)+.05)/(minf(first,second)+.05)
func capture(id: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(image.get_size()==root.size,"Capture physique "+id)
	check(image.save_png(proof.path_join(id+".png"))==OK,"Capture enregistrée "+id)
func current_chrome(page: String) -> void:
	var viewport := Rect2(Vector2.ZERO,Vector2(root.size)).grow(1)
	var rail := app.find_child("ImmersiveSidebar",true,false) as Control
	check(rail != null and viewport.encloses(rail.get_global_rect()) and rail.get_global_rect().size.x <= root.size.x*.2,"Navigation latérale contenue "+page)
	var header := app.find_child("ImmersiveTopbar",true,false) as Control
	check(header != null and viewport.encloses(header.get_global_rect()),"Bandeau entièrement contenu "+page)
	var caption := "Tactique" if page == "Composition" else page
	var breadcrumb := false
	if header != null:
		for label: Label in header.find_children("*","Label",true,false):
			if label.text == caption:
				var size := label.get_theme_font_size("font_size")
				breadcrumb = label.is_visible_in_tree() and size >= 12 and viewport.encloses(label.get_global_rect()) and label.get_theme_font("font").get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x <= label.size.x
	check(breadcrumb,"Page identifiée et texte lisible dans le bandeau "+page)
	var selected: String = {"Bureau":"Bureau","Effectif":"Effectif","Composition":"Tactique","Préparation":"Tactique","Plan de jeu":"Tactique","Club":"Club","Finances":"Finances","Classements":"Compétitions","Calendrier":"Compétitions"}.get(page,"")
	for name in ["Réception","Bureau","Effectif","Tactique","Entraînement","Recrutement","Club","Finances","Compétitions","Formation"]:
		var button := app.find_child("Nav_"+name,true,false) as Button
		check(button != null and button.is_visible_in_tree() and button.focus_mode == Control.FOCUS_ALL and viewport.encloses(button.get_global_rect()),"Navigation entière et accessible au clavier "+name+" / "+page)
		if button == null: continue
		var style := button.get_theme_stylebox("normal") as StyleBoxFlat
		var background := style.bg_color if style != null and style.bg_color.a > 0 else Color("11191e")
		check(button.get_theme_font_size("font_size") >= 12 and contrast(button.get_theme_color("font_color"),background) >= 4.5,"Contraste du chapitre "+name+" / "+page)
		var icon_visible := false
		if rail != null:
			for child in rail.get_children():
				if child is TextureRect and child.is_visible_in_tree() and button.get_global_rect().has_point(child.get_global_rect().get_center()): icon_visible = true
		check(icon_visible,"Pictogramme du chapitre "+name+" / "+page)
		if name == selected: check(style != null and style.bg_color.a > 0 and style.border_color.a > 0,"Sélection persistante "+page)
func run() -> void:
	root.size=Vector2i(2560,1440);DisplayServer.window_set_size(root.size)
	app=load("res://main.tscn").instantiate();root.add_child(app);await worker()
	await command("import",{"text":FileAccess.get_file_as_string(proof.path_join("career.json"))})
	await ContextualFlow.settle_club_meetings(app, self, check)
	await command("export")
	var before: String=app.model.meta.exportText
	var disk := OS.get_environment("CD_GODOT_DATA_DIR").path_join("donnees.json")
	var bytes := FileAccess.get_file_as_bytes(disk)
	var paper:Theme=load("res://theme.gd").paper()
	for kind in ["Button","OptionButton"]:
		for state in ["normal","hover","pressed"]:
			var style:StyleBoxFlat=paper.get_stylebox(state,kind)
			var ink:Color=paper.get_color("font_color" if state=="normal" else "font_"+state+"_color",kind)
			check(contrast(ink,style.bg_color)>=4.5,"Contraste de lecture "+kind+" "+state)
		check(paper.get_stylebox("normal",kind).bg_color.get_luminance()>.75,"Commande claire distincte de l'ancien bloc gris "+kind)
		var focus:StyleBoxFlat=paper.get_stylebox("focus",kind)
		check(focus.border_width_left>=2 and contrast(focus.border_color,paper.get_stylebox("normal",kind).bg_color)>=3,"Focus visible "+kind)
	for primary in [false,true]:
		var action:Button=load("res://ui/carnet_skin.gd").button("Action",func():pass,primary)
		var focus:StyleBoxFlat=action.get_theme_stylebox("focus")
		check(contrast(focus.border_color,action.get_theme_stylebox("normal").bg_color)>=3,"Focus action carnet "+str(primary))
		action.free()
	var sizes := [Vector2i(2560,1440),Vector2i(1920,1080),Vector2i(1600,900),Vector2i(1280,720)]
	if OS.get_environment("CD_ART07_SPIKE")=="1": sizes=[Vector2i(2560,1440)]
	for resolution in sizes:
		root.size=resolution;DisplayServer.window_set_size(resolution);await settle()
		for page in ["Bureau","Effectif","Composition","Préparation","Plan de jeu","Club","Finances","Classements","Calendrier","Carrière"]:
			app._navigate(page);await settle();app.coach.close();await settle()
			check(root.content_scale_size==resolution and app.size==Vector2(resolution),"Canvas natif "+page+" "+str(resolution))
			current_chrome(page)
			await capture(page.to_lower().replace("é","e").replace("è","e").replace(" ","-")+"-"+str(resolution.x))
	await command("export")
	check(app.model.meta.exportText==before,"Navigation et habillage conservent export/RNG/horloge")
	check(FileAccess.get_file_as_bytes(disk)==bytes,"Navigation et habillage conservent profil disque")
	# A second real club exercises the coloured identity after the grey club.
	await command("new_career",{"club":0,"mode":"common"})
	await ContextualFlow.settle_club_meetings(app, self, check)
	root.size=Vector2i(2560,1440);DisplayServer.window_set_size(root.size);await settle()
	for page in ["Bureau","Effectif","Finances"]:
		app._navigate(page);await settle();app.coach.close();await settle()
		await capture("toulouse-"+page.to_lower()+"-2560")
	if OS.get_environment("CD_ART07_MATCHES")=="1":
		# Visual review of a trend from actual results, never invented chart data.
		for week in 2:
			for action in ["begin_match","delegate","finish_round"]:await command(action)
			await ContextualFlow.settle_club_meetings(app, self, check)
		app._navigate("Bureau");await settle();app.coach.close();await settle()
		await capture("toulouse-bureau-deux-matchs-2560")
	var report:Dictionary={"checks":checks,"failures":failures,"display":DisplayServer.get_name(),"proof":proof}
	FileAccess.open(proof.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("ART_DIRECTION07 ",JSON.stringify(report))
	app.closing=true;app.bridge.stop();app.queue_free();await create_timer(.2).timeout
	quit(0 if failures.is_empty() else 1)

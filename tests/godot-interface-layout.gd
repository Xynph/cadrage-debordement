extends SceneTree
const ContextualFlow = preload("helpers/contextual_flow.gd")
# Real-window regression: removing the central resize handler must break the
# native 720p reference, compact pitch visibility and focused bench exposure.
var app: Control
var checks := 0
var failures: Array[String] = []
var proof := OS.get_environment("CD_LAYOUT_ARTIFACTS")
var scenario := OS.get_environment("CD_LAYOUT_CASE")
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); printerr("FAIL: " + message)
func settle() -> void:
	await create_timer(.22).timeout
	for i in 12: await process_frame
func worker() -> void:
	var limit := Time.get_ticks_msec()+30000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec()<limit: await process_frame
	check(not app.waiting and not app.model.is_empty(), "Worker répond")
	app.timer.stop()
	await settle()
func command(id: String, payload: Dictionary = {}) -> void:
	app._command(id,payload); await worker()
	check(app.bridge.last_response_ok,"Worker réel " + id+" "+app.last_error)
func named(id: String) -> Control: return app.find_child(id,true,false)
func resize_to(resolution: Vector2i) -> void:
	root.size=resolution; DisplayServer.window_set_size(resolution)
	await settle()
func lineup_slot(number: int) -> Button:
	return named("LineupSlot%02d" % number) as Button
func enter(c: Control) -> void:
	c.grab_focus(); await settle()
	for down in [true,false]:
		var event := InputEventKey.new();event.keycode=KEY_ENTER;event.pressed=down
		Input.parse_input_event(event);await process_frame
	await settle()
func capture(id: String) -> void:
	if DisplayServer.get_name()=="headless":return
	if OS.get_environment("CD_LAYOUT_CAPTURE_JOURNAL_ONLY")=="1" and not id.begins_with("journal-"):return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(proof.path_join(id+".png"))
func click_at(control:Control, fraction:float) -> void:
	var bounds:=control.get_global_rect()
	await click_point(bounds.position+bounds.size*Vector2(fraction,.5))
func click_point(point:Vector2) -> void:
	for down in [true,false]:
		var event:=InputEventMouseButton.new()
		event.position=point;event.global_position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down
		root.push_input(event,true);await process_frame
	await settle()
func hits(button: Button, point: Vector2) -> bool:
	var local := button.get_global_transform().affine_inverse()*point
	if button.has_method("_has_point"): return button._has_point(local)
	return Rect2(Vector2.ZERO,button.size).has_point(local)
func shared_hit(first: Button, second: Button) -> bool:
	var overlap := first.get_global_rect().intersection(second.get_global_rect())
	if not overlap.has_area():return false
	if hits(first,overlap.get_center()) and hits(second,overlap.get_center()):return true
	for y in range(ceili(overlap.position.y),ceili(overlap.end.y)):
		for x in range(ceili(overlap.position.x),ceili(overlap.end.x)):
			var point := Vector2(x,y)
			if hits(first,point) and hits(second,point):return true
	return false
func press_from_mail() -> bool:
	app._navigate("Réception"); await settle(); app.coach.close()
	for id in ["InboxActivity_todo","InboxPressInvitation","InboxOpenPressInvitation"]:
		var action := named(id) as Button
		var available := action != null and action.is_visible_in_tree() and not action.disabled
		check(available,"Accès public à la conférence : "+id)
		if not available: return false
		await enter(action)
	check(app.route == "Presse","Le courrier ouvre sa conférence existante")
	return app.route == "Presse"
func density_contract() -> void:
	# Catches the old 1080p cap: a 1440p desktop must gain canvas space,
	# rather than enlarge the same controls by 4/3.
	check(root.content_scale_size==root.size and app.size==Vector2(root.size),"Canvas PC natif sans agrandissement "+str(root.size))
	var skin:Script=load("res://ui/carnet_skin.gd")
	var sample:Label=skin.label("Une ligne de lecture courante",15)
	app.add_child(sample)
	check(sample.get_theme_font_size("font_size")==12,"Corps courant rendu à 12px")
	sample.queue_free()
	var action:Button=skin.button("Choisir",func():pass)
	app.add_child(action)
	check(action.get_combined_minimum_size().y<=28 and action.get_theme_font_size("font_size")==12,"Action dense lisible dans 28px")
	action.queue_free()
	var metric:VBoxContainer=skin.metric("125 000 €","Trésorerie")
	app.add_child(metric)
	check(metric.get_child(0).get_theme_font_size("font_size")<=20,"Métrique compacte au lieu d'une deuxième page")
	metric.queue_free()
	var viewport := Rect2(Vector2.ZERO, Vector2(root.size))
	var density := minf(root.size.x / 2560.0, root.size.y / 1440.0)
	var heading: Label = app.heading
	check(heading != null and viewport.encloses(heading.get_global_rect()), "Titre natif entièrement contenu")
	if heading != null:
		var font_size := heading.get_theme_font_size("font_size")
		var font := heading.get_theme_font("font")
		check(absf(font_size - 53.0 * density) <= 1.0 and font.get_string_size(heading.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= heading.size.x, "Titre natif lisible dans sa largeur au format choisi")
	var bureau := named("Nav_Bureau") as Button
	check(bureau != null and bureau.focus_mode == Control.FOCUS_ALL and viewport.encloses(bureau.get_global_rect()), "Navigation latérale entière et accessible au clavier")
	if bureau != null:
		check(absf(bureau.get_global_rect().size.y - 49.0 * density) <= 1.0, "Hauteur de navigation native à la résolution physique")
func run() -> void:
	var initial:=int(OS.get_environment("CD_LAYOUT_INITIAL"))
	root.size=Vector2i(2560,1440) if initial==2560 else (Vector2i(1920,1080) if initial==1920 else (Vector2i(1600,900) if initial==1600 else Vector2i(1280,720)))
	DisplayServer.window_set_size(root.size)
	app=load("res://main.tscn").instantiate();root.add_child(app);await worker()
	check(root.content_scale_size==root.size,"Référence physique correcte au démarrage")
	check(scenario in ["","management","journal"],"Scénario interface reconnu")
	if scenario == "journal":
		await journal_reading()
		finish()
		return
	await command("import",{"text":FileAccess.get_file_as_string(proof.path_join("career.json"))})
	await ContextualFlow.settle_club_meetings(app, self, check)
	app._navigate("Composition");await settle();app.coach.close()
	density_contract()
	await capture("composition-native-"+str(root.size.x))
	if OS.get_environment("CD_LAYOUT_DENSITY_PROBE")=="1":
		print("PC_DENSITY ",JSON.stringify({"checks":checks,"failures":failures}))
		app.closing=true;app.bridge.stop();app.queue_free()
		await create_timer(.2).timeout
		quit(0 if failures.is_empty() else 1)
		return
	await command("export")
	var before: String=app.model.meta.exportText
	var disk := OS.get_environment("CD_GODOT_DATA_DIR").path_join("donnees.json")
	var bytes := FileAccess.get_file_as_bytes(disk)
	check(not bytes.is_empty(),"Profil réel non vide")
	var history: Array=app.navigation_controller.history.duplicate(true)
	await resize_to(Vector2i(1920,1080))
	app._navigate("Composition");await settle();app.coach.close()
	var original:Control=app.root_content
	var guide_before:Dictionary=app.coach.profile.data.duplicate(true)
	var starters: Array[Button] = []
	for number in range(1, 16):
		var slot := lineup_slot(number)
		check(slot != null, "Poste natif présent %d" % number)
		if slot != null: starters.append(slot)
	var bench := lineup_slot(23)
	check(bench != null and bench.focus_mode == Control.FOCUS_ALL, "Le banc 23 est une commande clavier")
	if bench != null: bench.grab_focus()
	for resolution in [Vector2i(2560,1440),Vector2i(1920,1080),Vector2i(1280,720),Vector2i(1600,900),Vector2i(1600,720),Vector2i(1280,720)]:
		await resize_to(resolution)
		var expected:Vector2i=resolution
		check(root.content_scale_size==expected,"Référence physique "+str(resolution))
		check(app.root_content==original,"Resize conserve les instances "+str(resolution))
		var viewport: Rect2 = app.body_scroll.get_global_rect().grow(1)
		for i in starters.size():
			check(is_instance_valid(starters[i]) and lineup_slot(i+1)==starters[i] and viewport.encloses(starters[i].get_global_rect()),"Carte entière %d %s"%[i+1,resolution])
			for j in range(i+1,starters.size()):
				check(not shared_hit(starters[i],starters[j]),"Zones cliquables distinctes %d et %d à %s"%[i+1,j+1,resolution])
		if bench != null:
			check(lineup_slot(23)==bench and bench.has_focus(),"Même focus du banc23 après resize "+str(resolution))
			check(viewport.encloses(bench.get_global_rect()),"Banc23 réexposé après resize "+str(resolution))
	await capture("composition-1280")
	if bench != null:
		await resize_to(Vector2i(1920,1080))
		var opening := lineup_slot(10)
		var center := lineup_slot(13)
		if opening!=null and center!=null:
			var overlap := opening.get_global_rect().intersection(center.get_global_rect())
			var point := overlap.get_center() if overlap.has_area() else opening.get_global_rect().position+opening.get_global_rect().size*Vector2(.5,.8)
			check(hits(opening,point) and not hits(center,point),"Le contour transparent du centre ne masque pas le nom de l’ouvreur")
			await click_point(point)
			var opener := app.find_child("LineupCandidates",true,false) as AcceptDialog
			check(app.selected_slot==9,"Le vrai clic sélectionne l’ouvreur")
			await enter(lineup_slot(10))
			opener = app.find_child("LineupCandidates",true,false) as AcceptDialog
			check(opener != null and opener.visible,"La seconde activation ouvre les candidats de l’ouvreur")
			if opener!=null:opener.hide();opener.queue_free();await settle()
		bench=lineup_slot(23)
		await enter(bench)
		check(app.selected_slot==22,"Sélection réelle du banc23 par Entrée")
		await enter(lineup_slot(23))
		var candidates := app.find_child("LineupCandidates",true,false) as AcceptDialog
		check(candidates != null and candidates.visible,"Entrée ouvre la liste de candidats du poste choisi")
		if candidates != null:
			var slot: Dictionary = app.model.selection.slots[22]
			var focus: Button = candidates.get_ok_button()
			var enabled_ids: Array = []
			for option: Button in candidates.find_children("LineupPlayer*","Button",true,false):
				if not option.disabled:
					focus = option
					enabled_ids.append(str(option.get_meta("player_id")))
			var eligible: Array = app.model.squad.filter(func(player: Dictionary): return player.id in slot.eligibleIds and float(player.get("injury",0)) <= 0)
			var expected_ids := eligible.map(func(player: Dictionary): return str(player.id))
			enabled_ids.sort()
			expected_ids.sort()
			check(enabled_ids==expected_ids,"Candidats autorisés issus des qualifications et disponibilités du vrai poste")
			focus.grab_focus()
			for resolution in [Vector2i(2560,1440),Vector2i(1920,1080),Vector2i(1280,720),Vector2i(1600,900),Vector2i(1280,720)]:
				await resize_to(resolution)
				check(is_instance_valid(candidates) and candidates.visible and app.selected_slot==22,"Même liste du banc23 après resize "+str(resolution))
				check(is_instance_valid(focus) and focus.has_focus(),"Focus conservé dans la liste du banc23 "+str(resolution))
				check(Rect2(Vector2.ZERO,Vector2(resolution)).grow(1).encloses(Rect2(Vector2(candidates.position),Vector2(candidates.size))),"Fenêtre des candidats entièrement accessible "+str(resolution))
			await capture("banc23-1280")
			candidates.hide()
			candidates.queue_free()
			await settle()
	check(app.navigation_controller.history==history,"Aucun historique parasite de resize")
	check(app.coach.profile.data==guide_before,"Resize ne consomme aucun contexte Gabi")
	var dock:=named("CoachCompactDock")
	check(dock!=null,"Emplacement distinct du guide dans le footer")
	if dock!=null:check(not dock.get_global_rect().intersects(named("DecisionFeedbackButton").get_global_rect()),"Dock distinct N10")
	app._navigate("Effectif");await settle();app.coach.close()
	var search:LineEdit=named("RosterSearch")
	search.text="texte non envoyé";search.caret_column=5;search.select(2,5);search.grab_focus()
	for resolution in [Vector2i(2560,1440),Vector2i(1920,1080),Vector2i(1280,720)]:await resize_to(resolution)
	check(named("RosterSearch")==search and search.text=="texte non envoyé" and search.caret_column==5 and search.has_selection(),"Champ, caret et sélection gardés")
	check(search.has_focus(),"Focus saisie gardé")
	search.text="";search.text_changed.emit("");await settle()
	var rows:=0
	var strict_rows := 0
	var roster_bounds := named("SquadScroll").get_global_rect()
	var row_geometry: Array = []
	for row in named("SquadScroll").find_children("*","Button",true,false):
		if not row.has_meta("player_id"): continue
		var bounds: Rect2 = row.get_global_rect()
		if roster_bounds.encloses(bounds): strict_rows += 1
		if roster_bounds.grow(1).encloses(bounds): rows += 1
		if row_geometry.size() < 3: row_geometry.append(str(bounds))
	print("ROSTER_RESIZE_GEOMETRY ",JSON.stringify({"viewport":str(roster_bounds),"rows":row_geometry,"strict":strict_rows,"pixel_tolerance":rows}))
	check(rows>=3,"Effectif : au moins trois lignes après resize, tolérance de rasterisation 1px")
	app.coach.open_help();await settle()
	await click_at(named("GuideOptions"),.5)
	# UI-only error projection for the screenshot, restored before invariants.
	var had_error:bool=app.model.meta.has("saveError")
	var old_error:Variant=app.model.meta.get("saveError")
	app.model.meta.saveError=true;app.status.text=app._settled_status_text()
	await settle()
	await capture("gabi-effectif-1280")
	if had_error:app.model.meta.saveError=old_error
	else:app.model.meta.erase("saveError")
	app.status.text=app._settled_status_text()
	app.coach.close();await settle()
	app.confirm("Confirmation conservée","Aucune décision pendant resize",func():check(false,"Confirmation ne doit pas s'exécuter"))
	await settle()
	var confirmation:ConfirmationDialog
	for c in app.get_children():
		if c is ConfirmationDialog and c.visible:confirmation=c
	for resolution in [Vector2i(2560,1440),Vector2i(1920,1080),Vector2i(1280,720)]:await resize_to(resolution)
	check(is_instance_valid(confirmation) and confirmation.visible,"Même confirmation exclusive intacte")
	confirmation.hide();confirmation.queue_free();await settle()
	load("res://ui/preferences_dialog.gd").open(app,app.user_preferences);await settle()
	var preferences:Window=app.find_child("PreferencesDialog",true,false)
	var volume:LineEdit=app.find_child("PreferencesVolume",true,false).get_line_edit()
	volume.text="63";volume.caret_column=1
	for resolution in [Vector2i(2560,1440),Vector2i(1920,1080),Vector2i(1280,720)]:await resize_to(resolution)
	check(is_instance_valid(preferences) and preferences.visible and volume.text=="63" and volume.caret_column==1,"Préférences non validées préservées")
	preferences.hide();preferences.queue_free();await settle()
	load("res://ui/squad_views.gd").contract(app,app.model.squad[0],false);await settle()
	var offer:Window=app.find_child("ContractOffer",true,false)
	var salary:LineEdit=offer.find_child("OfferSalary",true,false).get_line_edit()
	salary.grab_focus();await settle();salary.text="12345";salary.caret_column=3
	for resolution in [Vector2i(2560,1440),Vector2i(1920,1080),Vector2i(1280,720)]:await resize_to(resolution)
	check(is_instance_valid(offer) and offer.visible and salary.text=="12345" and salary.caret_column==3,"Brouillon contrat sur même dialogue")
	offer.hide();offer.queue_free();await settle()
	app._navigate("Préparation");await settle();app.coach.close()
	await enter(named("PreparationTabEntrainement"))
	var preparation:Control=named("CarnetPreparation")
	for resolution in [Vector2i(2560,1440),Vector2i(1920,1080),Vector2i(1280,720)]:
		await resize_to(resolution)
		check(named("CarnetPreparation")==preparation and app.management_ui.preparation.tab==2,"Onglet entraînement conservé")
		for button in named("PreparationEntrainement").find_children("*","BaseButton",true,false):
			check(app.body_scroll.get_global_rect().encloses(button.get_global_rect()),"Commande entraînement entière "+str(button.name))
	await capture("preparation-1280")
	if await press_from_mail():
		var tabs:TabContainer=named("PressTabs")
		tabs.current_tab=1
		var answers:Array=app.body.find_children("PressAnswer_*","Button",true,false)
		if not answers.is_empty():
			await enter(answers[0])
			var draft:Variant=app.get_meta("press_draft_choices",{}).duplicate(true)
			for resolution in [Vector2i(2560,1440),Vector2i(1920,1080),Vector2i(1280,720)]:await resize_to(resolution)
			check(app.get_meta("press_draft_choices",{})==draft and tabs.current_tab==1 and answers[0].button_pressed,"Brouillon et onglet Presse conservés")
		else:check(false,"Fixture dispose de réponses Presse")
	check(FileAccess.get_file_as_bytes(disk)==bytes,"Resize et lecture : disque inchangé")
	await command("export")
	check(app.model.meta.exportText==before,"Resize et lecture : export S/RNG identique")
	# A real command creates the N10 receipt, outside the read-only invariant.
	var attack:String=app.model.tactics.attacks.filter(func(v):return v.id!=app.model.tactics.attack)[0].id
	await command("set_tactics",{"attack":attack,"defense":app.model.tactics.defense})
	app._navigate("Bureau");await settle();app.coach.close()
	for resolution in [Vector2i(1280,720),Vector2i(1600,900),Vector2i(1920,1080)]:
		await resize_to(resolution)
		var receipt_button := named("DecisionFeedbackButton")
		var guide_dock := named("CoachCompactDock")
		check(receipt_button!=null and guide_dock!=null,"Reçu et emplacement du guide présents "+str(resolution))
		if receipt_button==null or guide_dock==null:continue
		check(guide_dock.get_global_rect().size.x>=100 and not guide_dock.get_global_rect().intersects(receipt_button.get_global_rect()),"Place physique du guide distincte du reçu "+str(resolution))
		for fraction in [.25,.5,.75]:
			await click_at(receipt_button,fraction)
			var receipt:Window=app.find_child("DecisionFeedbackDialog",true,false)
			check(receipt!=null and receipt.visible,"Clic réel N10 %s %s"%[resolution,fraction])
			if receipt!=null:receipt.hide();receipt.queue_free();await settle()
	if scenario != "management": await journal_reading()
	finish()

func journal_reading() -> void:
	var disk := OS.get_environment("CD_GODOT_DATA_DIR").path_join("donnees.json")
	await command("import",{"text":FileAccess.get_file_as_string(proof.path_join("live.json"))})
	app._navigate("Match");await settle();app.coach.close()
	var match_surface: Control = app.contextual_director.view if app.contextual_director.active() and app.contextual_director.kind == "live" else app.match_screen
	var journal_button: Button
	for button: Button in match_surface.find_children("*","Button",true,false):
		if button.text == "JOURNAL" and button.is_visible_in_tree(): journal_button = button; break
	check(journal_button != null, "Le Journal s’ouvre depuis la vraie surface de match visible")
	if journal_button != null: await enter(journal_button)
	await settle()
	await command("export")
	var live_before:String=app.model.meta.exportText
	var live_bytes:=FileAccess.get_file_as_bytes(disk)
	var journal:Control=match_surface.find_child("MatchJournal",true,false)
	var stage:Node=match_surface.stage
	var journal_search:LineEdit=journal.find_child("MatchJournalSearch",true,false)
	journal_search.grab_focus();await settle()
	for down in [true,false]:
		var key:=InputEventKey.new();key.keycode=KEY_E;key.unicode=101;key.pressed=down
		Input.parse_input_event(key);await process_frame
	await settle()
	check(journal_search.text=="e" and journal.visible_events.size()>3,"Recherche Journal tapée et filtrée réellement")
	journal.scroll.scroll_vertical=100
	await settle()
	var journal_scroll:int=journal.scroll.scroll_vertical
	for resolution in [Vector2i(2560,1440),Vector2i(1280,720),Vector2i(1600,900),Vector2i(1920,1080),Vector2i(1280,720)]:
		await resize_to(resolution)
		check(match_surface.find_child("MatchJournal",true,false)==journal and match_surface.stage==stage,"Journal et caméra sur les mêmes instances")
		check(journal_search.text=="e" and journal_search.caret_column==1 and journal_search.has_focus(),"Recherche Journal et caret conservés")
		check(journal.scroll.scroll_vertical==journal_scroll,"Position de relecture Journal conservée")
		check(journal.scroll.size.y>=200,"Journal conserve plusieurs lignes")
		if resolution==Vector2i(1920,1080):await capture("journal-1920")
	await capture("journal-1280")
	check(FileAccess.get_file_as_bytes(disk)==live_bytes,"Match lecture resize disque inchangé")
	await command("export")
	check(app.model.meta.exportText==live_before,"Match lecture resize S/RNG inchangés")

func finish() -> void:
	var file:=FileAccess.open(proof.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures},"  "));file.close()
	app.closing=true;app.bridge.stop()
	print("Interface adaptative : ",checks," contrôles ; ",failures.size()," échec(s)")
	quit(0 if failures.is_empty() else 1)

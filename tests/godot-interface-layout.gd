extends SceneTree
# Real-window regression: removing the central resize handler must break the
# native 720p reference, compact pitch visibility and focused bench exposure.
var app: Control
var checks := 0
var failures: Array[String] = []
var proof := OS.get_environment("CD_LAYOUT_ARTIFACTS")
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
func board() -> Control:
	for c in app.body.find_children("*","Control",true,false):
		if c.get_script()==load("res://ui/lineup_board.gd"): return c
	return null
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
	var point:=control.get_global_rect().position+control.size*Vector2(fraction,.5)
	for down in [true,false]:
		var event:=InputEventMouseButton.new()
		event.position=point;event.global_position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down
		root.push_input(event,true);await process_frame
	await settle()
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
	check(app.heading.get_theme_font_size("font_size")<=20,"Titre du shell PC compact")
	check(named("Chapter_Bureau").get_combined_minimum_size().y<=30,"Navigation latérale compacte")
func run() -> void:
	var initial:=int(OS.get_environment("CD_LAYOUT_INITIAL"))
	root.size=Vector2i(2560,1440) if initial==2560 else (Vector2i(1920,1080) if initial==1920 else (Vector2i(1600,900) if initial==1600 else Vector2i(1280,720)))
	DisplayServer.window_set_size(root.size)
	app=load("res://main.tscn").instantiate();root.add_child(app);await worker()
	check(root.content_scale_size==root.size,"Référence physique correcte au démarrage")
	await command("import",{"text":FileAccess.get_file_as_string(proof.path_join("career.json"))})
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
	for resolution in [Vector2i(2560,1440),Vector2i(1920,1080),Vector2i(1280,720),Vector2i(1600,900),Vector2i(1600,720),Vector2i(1280,720)]:
		await resize_to(resolution)
		var expected:Vector2i=resolution
		check(root.content_scale_size==expected,"Référence physique "+str(resolution))
		check(app.root_content==original,"Resize conserve les instances "+str(resolution))
		for i in 15:
			check(app.body_scroll.get_global_rect().encloses(board().tiles[i].get_global_rect()),"Carte entière %d %s"%[i+1,resolution])
			for j in range(i+1,15):check(not board().tiles[i].get_global_rect().intersects(board().tiles[j].get_global_rect()),"Cartes distinctes")
	await capture("composition-1280")
	await enter(named("LineupSlot23"))
	check(app.selected_slot==22,"Sélection réelle du banc23")
	for resolution in [Vector2i(2560,1440),Vector2i(1920,1080),Vector2i(1280,720),Vector2i(1600,900),Vector2i(1280,720)]:
		await resize_to(resolution)
		check(named("LineupSlot23").has_focus(),"Focus banc23 conservé")
		check(app.body_scroll.get_global_rect().encloses(named("LineupSlot23").get_global_rect()),"Banc23 réexposé après resize")
	check(app.navigation_controller.history==history,"Aucun historique parasite de resize")
	check(app.coach.profile.data==guide_before,"Resize ne consomme aucun contexte Gabi")
	await capture("banc23-1280")
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
	for row in named("SquadScroll").find_children("*","Button",true,false):
		if named("SquadScroll").get_global_rect().encloses(row.get_global_rect()):rows+=1
	check(rows>=3,"Effectif : au moins trois lignes après resize")
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
	app._navigate("Presse");await settle();app.coach.close()
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
		for fraction in [.25,.5,.75]:
			await click_at(named("DecisionFeedbackButton"),fraction)
			var receipt:Window=app.find_child("DecisionFeedbackDialog",true,false)
			check(receipt!=null and receipt.visible,"Clic réel N10 %s %s"%[resolution,fraction])
			if receipt!=null:receipt.hide();receipt.queue_free();await settle()
	await command("import",{"text":FileAccess.get_file_as_string(proof.path_join("live.json"))})
	app._navigate("Match");await settle();app.coach.close()
	app.match_screen._select_tab("Journal");await settle()
	await command("export")
	var live_before:String=app.model.meta.exportText
	var live_bytes:=FileAccess.get_file_as_bytes(disk)
	var journal:Control=named("MatchJournal")
	var stage:Node=app.match_screen.stage
	var journal_search:LineEdit=named("MatchJournalSearch")
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
		check(named("MatchJournal")==journal and app.match_screen.stage==stage,"Journal et caméra sur les mêmes instances")
		check(journal_search.text=="e" and journal_search.caret_column==1 and journal_search.has_focus(),"Recherche Journal et caret conservés")
		check(journal.scroll.scroll_vertical==journal_scroll,"Position de relecture Journal conservée")
		check(journal.scroll.size.y>=200,"Journal conserve plusieurs lignes")
		if resolution==Vector2i(1920,1080):await capture("journal-1920")
	await capture("journal-1280")
	check(FileAccess.get_file_as_bytes(disk)==live_bytes,"Match lecture resize disque inchangé")
	await command("export")
	check(app.model.meta.exportText==live_before,"Match lecture resize S/RNG inchangés")
	var file:=FileAccess.open(proof.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures},"  "));file.close()
	app.closing=true;app.bridge.stop()
	print("Interface adaptative : ",checks," contrôles ; ",failures.size()," échec(s)")
	quit(0 if failures.is_empty() else 1)

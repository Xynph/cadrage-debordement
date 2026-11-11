extends SceneTree
const ContextualFlow = preload("helpers/contextual_flow.gd")
var app: Control
var failures: Array[String] = []
var captures: Array = []
var unavailable_routes: Array = []
var checks := 0
var focused := OS.get_environment("CD_ART_DIRECTION_FOCUS") == "1"
var dialogs_only := OS.get_environment("CD_ART_DIRECTION_DIALOGS_ONLY") == "1"
var scenario := OS.get_environment("CD_ART_DIRECTION_CASE")
var resolutions: Array[Vector2i] = [Vector2i(1280,720),Vector2i(1600,900),Vector2i(1920,1080)]
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); printerr(message)
func settle() -> void:
	for i in 8: await process_frame
func wait_model() -> bool:
	var deadline := Time.get_ticks_msec() + 60000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec() < deadline: await process_frame
	app.timer.stop()
	check(not app.waiting and not app.model.is_empty() and app.bridge.last_response_ok, "Réponse moteur : " + app.last_error)
	check(app.last_error.is_empty(), "Commande acceptée : " + app.last_error)
	await settle()
	return not app.waiting and not app.model.is_empty() and app.bridge.last_response_ok and app.last_error.is_empty()
func send(id: String, payload: Dictionary = {}, target: String = "") -> bool:
	print("SDK_COMMAND ",Time.get_ticks_msec()," art-direction ",id)
	var accepted: bool=app._command(id,payload,target)
	check(accepted,"Commande publique acceptée : "+id)
	if not accepted:return false
	return await wait_model()
func navigate(route: String) -> bool:
	if route=="Presse":
		var press: Dictionary=app.model.get("clubLife",{}).get("press",{})
		var invitation_value: Variant=press.get("conference",{}).get("invitationId")
		var invitation: String=invitation_value if invitation_value is String else ""
		var outcome: Variant=press.get("lastOutcome")
		if invitation.is_empty() and outcome is Dictionary: invitation=str(outcome.get("invitationId",""))
		app._show_press_inbox();await settle()
		var entries: Array=app.find_children("*","Button",true,false).filter(func(button):return button.get_meta("message_id","")==invitation)
		if not invitation.is_empty() and not entries.is_empty():
			entries[0].pressed.emit();await settle()
			var open:=app.find_child("InboxOpenPressInvitation",true,false) as Button
			if open!=null and not open.disabled: open.pressed.emit();await settle()
		var visible: bool=app.route=="Presse" or app.contextual_director.active() and app.contextual_director.kind=="press"
		if not visible:
			unavailable_routes.append({"requested":route,"actual":app.route,"resolution":str(root.size),"reason":"Aucune invitation réelle consultable dans ce contexte"})
		return visible
	app._navigate(route);await settle()
	var reached: bool=app.route==route
	check(reached,"Route réellement affichée : "+route+" → "+app.route)
	return reached
func capture(label: String) -> void:
	await settle()
	await RenderingServer.frame_post_draw
	var filename := "%d-%s.png" % [root.size.x, label.validate_filename()]
	var rendered:=root.get_texture().get_image()
	check(rendered.get_size()==root.size,"Dimensions réelles de capture : "+filename)
	check(rendered.save_png(OS.get_environment("CD_ART_DIRECTION_DIR").path_join(filename))==OK,"Capture enregistrée : "+filename)
	captures.append(filename)
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	if not scenario.is_empty():
		if scenario == "progression": resolutions = []
		else:
			var width := int(scenario.get_slice("-",1))
			resolutions = resolutions.filter(func(value: Vector2i): return value.x == width)
			check(scenario.begins_with("routes-") and resolutions.size() == 1,"Cas artistique explicite valide : "+scenario)
			if resolutions.is_empty(): finish(); return
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	if not await wait_model(): finish(); return
	var maximize:=Callable(app,"_keep_filled_display")
	if root.size_changed.is_connected(maximize):root.size_changed.disconnect(maximize)
	if root.focus_entered.is_connected(maximize):root.focus_entered.disconnect(maximize)
	root.mode=Window.MODE_WINDOWED
	if not await send("new_career", {"mode":"common", "club":0}, "Bureau"): finish(); return
	# The current press room belongs to its pending invitation. Capture it before
	# settling appointments; a receipt must never manufacture another meeting.
	if scenario != "progression" and not dialogs_only and OS.get_environment("CD_ART_DIRECTION_MATCH_ONLY") != "1":
		for resolution in resolutions:
			root.size = resolution
			var opened := await navigate("Presse")
			check(opened,"Invitation initiale ouvre la vraie conférence à "+str(resolution))
			if opened: await capture("Presse")
	await ContextualFlow.settle_club_meetings(app, self, check)
	if OS.get_environment("CD_ART_DIRECTION_MATCH_ONLY") == "1":
		await match_review()
		finish()
		return
	var academy: Dictionary = app.model.get("clubLife",{}).get("academyPathways",{})
	if not academy.get("active", false):
		var activation: Dictionary = academy.get("context",{}).duplicate()
		activation.confirmed = true
		if not await send("academy_activate", activation): finish(); return
	for resolution in resolutions:
		root.size = resolution
		var routes := ["Centre", "Stratégie", "Plan de jeu"] if focused else ["Accueil","Création","Bureau","Effectif","Composition","Préparation","Plan de jeu","Recrutement","Formation","Centre","Staff","Travail du club","Vestiaire","Finances","Stratégie","Club","Carrière","Calendrier","Classements","Rivalités","Match"]
		if dialogs_only: routes = []
		for route in routes:
			if not await navigate(route):continue
			var actual := app.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, app.size)
			var logical := root.get_visible_rect()
			check(actual.size.x >= logical.size.x - 2 and actual.size.y >= logical.size.y - 2, "Plein canevas " + route + " " + str(actual) + " / " + str(logical))
			await capture(route)
			var tabs := app.find_children("*", "TabContainer", true, false)
			for control: TabContainer in tabs:
				if not control.is_visible_in_tree(): continue
				for index in range(1, control.get_tab_count()):
					if focused and ((route == "Centre" and index != 1) or route == "Stratégie"): continue
					control.current_tab = index
					await capture(route + "-" + control.get_tab_title(index))
					if route == "Centre" and index == 1:
						for button: Button in control.find_children("*", "Button", true, false):
							if button.text == "OUVRIR LE PARCOURS INDIVIDUEL":
								button.pressed.emit()
								await capture("Centre-Parcours-detail")
								break
				control.current_tab = 0
			if route == "Formation":
				app.management_ui.development.mode = "professional"
				app._render()
				await capture("Formation-professionnels")
				app.management_ui.development.mode = "academy"
			if route == "Classements":
				app.table_division = "accession"
				app._render()
				await capture("Classements-accession")
				app.table_division = "elite"
		if focused:
			app._navigate("Effectif")
			await settle()
			app.management_ui.compare = [str(app.model.squad[0].id), str(app.model.squad[1].id)]
			preload("res://ui/squad_views.gd").comparison(app)
			await capture("Comparaison")
			app._clear_dialogs()
			continue
		app.pack_manager.open("career")
		await capture("Packs")
		app._navigate("Effectif")
		await settle()
		app.management_ui.compare = [str(app.model.squad[0].id), str(app.model.squad[1].id)]
		preload("res://ui/squad_views.gd").comparison(app)
		await capture("Comparaison")
		app._clear_dialogs()
		preload("res://ui/squad_views.gd").contract(app, app.model.squad[0], false)
		await capture("Contrat")
		app._clear_dialogs()
		preload("res://ui/club_views.gd").season_archives(app)
		await capture("Archives")
		app._clear_dialogs()
		app.pause_menu()
		await capture("Menu-sauvegardes")
		app._clear_dialogs()
		app._credits()
		await capture("Crédits")
		app._clear_dialogs()
		app._navigate("Préparation")
		await settle()
		preload("res://ui/decision_views.gd").dossier(app)
		await capture("Dossier-adverse")
		app._clear_dialogs()
		app.settings()
		await capture("Paramètres")
		app._clear_dialogs()
	if dialogs_only or scenario.begins_with("routes-"): finish(); return
	root.size = Vector2i(1600,900)
	for week in 2:
		var previous_week: int=app.model.meta.week
		if not await ContextualFlow.prepare_match_day(app,self,check): finish(); return
		for command in ["begin_match", "delegate", "finish_round"]:
			if not await send(command): finish(); return
			if command == "begin_match": await ContextualFlow.skip_talk(app, self, "pre", check)
			if command == "finish_round" and not await ContextualFlow.finish_match_week(app,self,check,previous_week): finish(); return
	for route in ["Bureau", "Finances", "Presse", "Rivalités"]:
		if await navigate(route):await capture(route + "-apres-deux-matchs")
	if not await ContextualFlow.prepare_match_day(app,self,check): finish(); return
	if not await send("begin_match", {}, "Match"): finish(); return
	await ContextualFlow.skip_talk(app, self, "pre", check)
	if not await send("pause", {"paused":true}): finish(); return
	await capture("Match-direct")
	var screen: Control = app.match_screen
	for tab in ["Banc", "Stats"]:
		screen._toggle_drawer(tab)
		await capture("Match-" + tab)
	finish()
func match_review() -> void:
	if not await ContextualFlow.prepare_match_day(app,self,check): finish(); return
	if not await send("begin_match", {}, "Match"): finish(); return
	await ContextualFlow.skip_talk(app, self, "pre", check)
	if not await send("delegate"): finish(); return
	for resolution in [Vector2i(1280,720), Vector2i(1920,1080)]:
		root.size = resolution
		app._navigate("Match")
		await settle()
		var screen: Control = app.match_screen
		check(screen.get_global_rect().end.x <= app.size.x + 1, "Barre de commandes bornée à " + str(resolution))
		screen._toggle_drawer("Stats")
		await capture("Match-Stats-final")
		for index in 3:
			var quality: String = ["economy", "balanced", "detail"][index]
			check(app.user_preferences.set_value("quality", quality) and screen.stage._quality == quality, "Qualité appliquée au vrai match " + quality)
		await capture("Match-qualite-detail")
func finish() -> void:
	var report := FileAccess.open(OS.get_environment("CD_ART_DIRECTION_DIR").path_join("report.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify({"case":scenario,"checks":checks,"failures":failures,"captures":captures,"unavailable_routes":unavailable_routes},"  "))
	report.close()
	if is_instance_valid(app):
		app.closing = true
		app.timer.stop()
		app.bridge.stop()
	print("ART DIRECTION : ", checks, " contrôles ; ", captures.size(), " captures ; ", failures.size(), " échecs")
	quit(0 if failures.is_empty() else 1)

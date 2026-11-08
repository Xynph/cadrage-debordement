extends SceneTree
var app: Control
var failures: Array[String] = []
var captures: Array = []
var checks := 0
var focused := OS.get_environment("CD_ART_DIRECTION_FOCUS") == "1"
var dialogs_only := OS.get_environment("CD_ART_DIRECTION_DIALOGS_ONLY") == "1"
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); printerr(message)
func settle() -> void:
	for i in 8: await process_frame
func wait_model() -> bool:
	var deadline := Time.get_ticks_msec() + 60000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec() < deadline: await process_frame
	check(not app.waiting and not app.model.is_empty(), "Réponse moteur : " + app.last_error)
	check(app.last_error.is_empty(), "Commande acceptée : " + app.last_error)
	await settle()
	return not app.waiting and not app.model.is_empty()
func capture(label: String) -> void:
	await settle()
	await RenderingServer.frame_post_draw
	var filename := "%d-%s.png" % [root.size.x, label.validate_filename()]
	root.get_texture().get_image().save_png(OS.get_environment("CD_ART_DIRECTION_DIR").path_join(filename))
	captures.append(filename)
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	if not await wait_model(): finish(); return
	app._command("new_career", {"mode":"common", "club":0}, "Bureau")
	if not await wait_model(): finish(); return
	if OS.get_environment("CD_ART_DIRECTION_MATCH_ONLY") == "1":
		await match_review()
		finish()
		return
	var academy: Dictionary = app.model.get("clubLife",{}).get("academyPathways",{})
	if not academy.get("active", false):
		var activation: Dictionary = academy.get("context",{}).duplicate()
		activation.confirmed = true
		app._command("academy_activate", activation)
		await wait_model()
	for resolution in [Vector2i(1280,720),Vector2i(1600,900),Vector2i(1920,1080)]:
		root.size = resolution
		var routes := ["Centre", "Stratégie", "Presse", "Plan de jeu"] if focused else ["Accueil","Création","Bureau","Effectif","Composition","Préparation","Plan de jeu","Recrutement","Formation","Centre","Staff","Travail du club","Vestiaire","Finances","Stratégie","Club","Carrière","Calendrier","Classements","Presse","Rivalités","Match"]
		if dialogs_only: routes = []
		for route in routes:
			app._navigate(route)
			await settle()
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
	if dialogs_only: finish(); return
	root.size = Vector2i(1600,900)
	for week in 2:
		for command in ["begin_match", "delegate", "finish_round"]:
			app._command(command)
			await wait_model()
	for route in ["Bureau", "Finances", "Presse", "Rivalités"]:
		app._navigate(route)
		await capture(route + "-apres-deux-matchs")
	app._command("begin_match", {}, "Match")
	await wait_model()
	app._command("pause", {"paused":true})
	await wait_model()
	await capture("Match-direct")
	var screen: Control = app.body.find_child("CarnetMatch",true,false)
	for tab in ["Banc", "Stats"]:
		screen.tab = tab
		screen._side()
		await capture("Match-" + tab)
	finish()
func match_review() -> void:
	app._command("begin_match", {}, "Match")
	await wait_model()
	app._command("delegate")
	await wait_model()
	for resolution in [Vector2i(1280,720), Vector2i(1920,1080)]:
		root.size = resolution
		app._navigate("Match")
		await settle()
		var screen: Control = app.body.find_child("CarnetMatch",true,false)
		check(screen.get_global_rect().end.x <= app.size.x + 1, "Barre de commandes bornée à " + str(resolution))
		screen.tab = "Stats"
		screen._side()
		await capture("Match-Stats-final")
		var picker: OptionButton = screen.find_child("MatchQuality",true,false)
		for index in 3:
			picker.select(index)
			picker.item_selected.emit(index)
			check(screen.stage._quality == ["economy", "balanced", "detail"][index], "Qualité appliquée " + str(index))
		await capture("Match-qualite-detail")
func finish() -> void:
	var report := FileAccess.open(OS.get_environment("CD_ART_DIRECTION_DIR").path_join("report.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failures":failures,"captures":captures},"  "))
	report.close()
	if is_instance_valid(app):
		app.closing = true
		app.timer.stop()
		app.bridge.stop()
	print("ART DIRECTION : ", checks, " contrôles ; ", captures.size(), " captures ; ", failures.size(), " échecs")
	quit(0 if failures.is_empty() else 1)

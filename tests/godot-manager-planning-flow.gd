extends SceneTree
const Flow = preload("helpers/contextual_flow.gd")
var app: Control
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL : " + message)

func settle() -> void:
	for i in 8: await process_frame

func wait_command() -> void:
	var deadline := Time.get_ticks_msec() + 30000
	while app.waiting and Time.get_ticks_msec() < deadline: await process_frame
	check(not app.waiting and app.bridge.last_response_ok, "Commande réelle acceptée")
	app.timer.stop()
	await settle()

func state() -> Dictionary:
	app._command("export")
	await wait_command()
	return JSON.parse_string(app.model.meta.exportText).state

func shot(label: String) -> void:
	if OS.get_environment("CD_MANAGER_PLANNING_GRAPHICS") != "1": return
	await RenderingServer.frame_post_draw
	var directory := OS.get_environment("CD_MANAGER_PLANNING_OUTPUT")
	check(root.get_texture().get_image().save_png(directory.path_join(label + ".png")) == OK, "Capture " + label)

func run() -> void:
	root.size = Vector2i(1280, 720)
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	app.bridge.command_failed.connect(func(message: String): printerr("REFUS MOTEUR : ", message))
	var deadline := Time.get_ticks_msec() + 30000
	while app.model.is_empty() and Time.get_ticks_msec() < deadline: await process_frame
	check(not app.model.is_empty(), "Vrai worker prêt")
	app.timer.stop()
	app._command("new_career", {"mode":"world-champ","club":0})
	await wait_command()
	await Flow.settle_club_meetings(app, self, check)
	var before := await state()
	app._navigate("Bureau")
	await settle()
	var entry := app.find_child("OfficeManagerPlanning", true, false) as Button
	check(entry != null, "Entrée réelle du Bureau")
	if entry == null:
		app.bridge.stop()
		quit(1)
		return
	entry.pressed.emit()
	await settle()
	var panel = app.find_child("ManagerPlanning", true, false)
	check(panel != null and panel.visible, "Atelier ouvert")
	var players := panel.find_child("PlannerPlayer", true, false) as OptionButton
	check(players.item_count > 1, "Joueur qualifié disponible")
	players.select(1)
	(panel.find_child("PlannerSaveLineup", true, false) as Button).pressed.emit()
	await wait_command()
	check(app.model.managerPlanning.fixtures[0].slots[0] != null, "Intention reçue par le vrai moteur")
	await shot("01-trois-rencontres-1280")
	panel.tabs.current_tab = 1
	await settle()
	(panel.find_child("PlannerScenarioAdd", true, false) as Button).pressed.emit()
	await wait_command()
	check(app.model.managerPlanning.scenario.operations.size() == 1, "Hypothèse enregistrée sans signature")
	if not app.bridge.last_response_ok or not is_instance_valid(panel):
		app.bridge.stop()
		quit(1)
		return
	await shot("02-effectif-futur-1280")
	panel.tabs.current_tab = 2
	await settle()
	(panel.find_child("PlannerSaveGoal", true, false) as Button).pressed.emit()
	await wait_command()
	check(app.model.managerPlanning.goal != null and app.model.managerPlanning.goal.value == null, "Objectif enregistré, mesure inconnue avant match")
	await shot("03-objectif-1280")
	for size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = size
		panel.popup_centered_clamped(Vector2i(1180, 760), 0.9)
		await settle()
		check(Rect2i(Vector2i.ZERO, root.size).encloses(Rect2i(panel.position, panel.size)), "Dialogue contenu " + str(size))
		var scroll := panel.find_child("PlannerScroll", true, false) as ScrollContainer
		check(scroll.get_h_scroll_bar().max_value <= scroll.size.x + 1, "Pas de débordement horizontal " + str(size))
	await shot("04-objectif-1920")
	var after := await state()
	after.erase("managerPlanning")
	check(after == before, "État sportif, financier et hasard inchangés")
	panel.queue_free()
	await settle()
	app._navigate("Préparation")
	await settle()
	check(app.find_child("PreparationManagerPlanning", true, false) != null, "Entrée réelle de Préparation")
	print("ATELIER COMPLET : ", checks, " contrôles ; ", failures.size(), " échec(s)")
	app.bridge.stop()
	quit(0 if failures.is_empty() else 1)

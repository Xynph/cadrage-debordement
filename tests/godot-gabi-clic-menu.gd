extends SceneTree
## Menu principal, bulle de Gabi ouverte : un seul clic sur « Nouvelle carrière » ouvre la création
## (recette native du 16/11/2026 : le premier clic ne faisait que fermer la bulle).
## Clic réel envoyé au viewport (mouvement, appui, relâchement), comme la souris du joueur.
var app: Control
var checks := 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); printerr("FAIL: ", message)

func frames(n: int = 4) -> void:
	for i in n: await process_frame

func click(at: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at; motion.global_position = at
	root.push_input(motion)
	await frames(2)
	for pressed in [true, false]:
		var button := InputEventMouseButton.new()
		button.button_index = MOUSE_BUTTON_LEFT
		button.pressed = pressed
		button.position = at; button.global_position = at
		root.push_input(button)
		await frames(2)

func run() -> void:
	root.size = Vector2i(1600, 900)
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	var until := Time.get_ticks_msec() + 60000
	while app.model.is_empty() and Time.get_ticks_msec() < until: await process_frame
	await frames(8)
	check(app.route == "Accueil", "Départ sur le menu principal (route : " + str(app.route) + ")")
	check(is_instance_valid(app.coach), "Gabi présent sur le menu")
	if is_instance_valid(app.coach):
		app.coach.open_help()
		await frames(8)
		check(app.coach.expanded, "Bulle de Gabi ouverte")
	var create := app.find_child("EntryNewCareer", true, false) as Control
	check(create != null and create.is_visible_in_tree(), "Bouton « Nouvelle carrière » visible")
	if create != null:
		var at := create.get_global_rect().get_center()
		var motion := InputEventMouseMotion.new()
		motion.position = at; motion.global_position = at
		root.push_input(motion)
		await frames(2)
		var hovered := root.gui_get_hovered_control()
		print("GABI_CLIC survol : ", hovered.get_path() if hovered != null else "aucun")
		await click(at)
		await frames(8)
		check(app.route == "Création", "Un seul clic sur « Nouvelle carrière » ouvre la création malgré la bulle (route : " + str(app.route) + ")")
	print("GABI CLIC MENU : ", checks, " contrôles ; ", failures.size(), " échec(s)")
	app.bridge.stop()
	quit(0 if failures.is_empty() else 1)

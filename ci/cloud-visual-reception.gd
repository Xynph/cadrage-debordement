extends SceneTree

var app: Control
var checks := 0
var failures: Array[String] = []
var viewport_size: Vector2i
var output := OS.get_environment("QA_OUTPUT")
var evidence: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> bool:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("FAIL: " + message)
	return condition

func settle() -> void:
	await create_timer(0.2).timeout
	for index in 4:
		await process_frame

func ready_for_input() -> bool:
	var deadline := Time.get_ticks_msec() + 30000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec() < deadline:
		await process_frame
	await settle()
	return check(not app.waiting and not app.model.is_empty() and app.bridge.last_response_ok,
		"Réponse du moteur : " + str(app.last_command) + " " + str(app.last_error))

func control(id: String) -> Button:
	return app.find_child(id, true, false) as Button

func click(id: String) -> bool:
	var button := control(id)
	if not check(button != null and button.is_visible_in_tree() and not button.disabled, "Bouton utilisable : " + id):
		return false
	var ancestor := button.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			ancestor.ensure_control_visible(button)
		ancestor = ancestor.get_parent()
	await settle()
	var point := button.get_global_transform_with_canvas() * (button.size * 0.5)
	if not check(root.get_visible_rect().has_point(point), "Bouton dans la fenêtre : " + id):
		return false
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		event.position = point
		event.global_position = point
		event.pressed = down
		root.push_input(event, true)
		await process_frame
	await settle()
	return true

func capture(name: String) -> void:
	await settle()
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(image.get_size() == viewport_size and DisplayServer.window_get_size() == viewport_size,
		"Capture native à la définition demandée : " + name)
	check(image.save_png(output.path_join(name + ".png")) == OK, "Capture enregistrée : " + name)
	evidence.append({"image":name, "route":app.route, "date":app.model.meta.get("calendarToday", ""),
		"caption": app.primary_button.text if is_instance_valid(app.primary_button) else "",
		"header":app.header_date.text if is_instance_valid(app.header_date) else ""})

func run() -> void:
	var dimensions := OS.get_environment("QA_RESOLUTION").split("x")
	viewport_size = Vector2i(int(dimensions[0]), int(dimensions[1]))
	root.mode = Window.MODE_WINDOWED
	root.size = viewport_size
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await settle()
	root.size = viewport_size
	if await ready_for_input():
		check(DisplayServer.get_name() == "X11", "Vrai rendu X11 distant")
		await verify_club()
	await finish()

func verify_club() -> void:
	app._command("new_career", {"mode":"world-champ", "club":102})
	if not await ready_for_input(): return
	if not check(app.route == "Réception", "Une carrière en club arrive en Réception"): return
	await capture("01-reception")
	var players: Array = app.model.get("squad", [])
	var estimated := players.filter(func(player: Dictionary): return player.get("playerFacts", {}).get("dimensionsSource") == "estimated")
	if estimated.is_empty():
		app._command("new_career", {"mode":"fiction", "club":0})
		if not await ready_for_input(): return
		players = app.model.get("squad", [])
		estimated = players.filter(func(player: Dictionary): return player.get("playerFacts", {}).get("dimensionsSource") == "estimated")
	if not check(not estimated.is_empty(), "Le moteur a projeté au moins une fiche avec des mensurations complétées"): return
	var player: Dictionary = estimated[0]
	var facts: Dictionary = player.playerFacts
	app.selected_player = str(player.id)
	if not await click("Nav_Effectif"): return
	if not await click("OpenPlayerFull"): return
	var identity := app.find_child("PlayerIdentityFacts", true, false)
	if not check(identity != null and app.selected_player == str(player.id), "La fiche ouverte correspond au profil ciblé"): return
	var origin := identity.get_node_or_null("PlayerOriginFact") as Label
	var dimensions := identity.get_node_or_null("PlayerDimensionsFact") as Label
	var caption := "%d cm · %d kg" % [int(facts.heightCm), int(facts.weightKg)]
	check(origin != null and origin.tooltip_text.is_empty() and not origin.text.contains("*"),
		"Origine sans marque ni infobulle de provenance")
	check(dimensions != null and dimensions.text == caption and dimensions.tooltip_text.is_empty(),
		"Mensurations complétées présentées sans marque ni infobulle")
	print("Profil : ", player.name, " · ", facts.get("nationality", ""), " · ", caption,
		" · origine=", facts.get("nationalitySource", ""), " · mensurations=", facts.dimensionsSource)
	await capture("02-fiche-mensurations")

func finish() -> void:
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"display":DisplayServer.get_name(), "checks":checks,
			"failures":failures, "captures":evidence}, "  "))
		file.close()
	print("RECETTE VISUELLE : ", checks, " contrôles ; ", failures.size(), " échecs")
	await app._close(0 if failures.is_empty() else 1)

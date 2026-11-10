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
		"caption": app.primary_button.text, "header":app.header_date.text})

func run() -> void:
	var dimensions := OS.get_environment("QA_RESOLUTION").split("x")
	viewport_size = Vector2i(int(dimensions[0]), int(dimensions[1]))
	root.mode = Window.MODE_WINDOWED
	root.size = viewport_size
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await settle()
	root.mode = Window.MODE_WINDOWED
	root.size = viewport_size
	await settle()
	if not await ready_for_input():
		await finish()
		return
	if not check(not app._has_career(), "Profil de recette neuf"):
		await finish()
		return
	app._command("new_career", {"mode":"world-champ", "club":102}, "Bureau")
	if await ready_for_input():
		await verify_journey()
	await finish()

func verify_journey() -> void:
	var date: String = app.model.meta.calendarToday
	var conference: Dictionary = app.model.clubLife.press.conference
	check(date == "2026-08-17" and conference.required and app.route == "Bureau", "Date de départ et invitation obligatoire")
	check(DisplayServer.get_name() == "X11", "Vrai rendu X11 distant")
	await capture("01-bureau")
	if not await click("ImmersiveContinue"): return
	if not check(app.route == "Réception", "L’action principale ouvre Réception"): return
	check(control("InboxOpenPressInvitation") == null, "Invitation à ouvrir avant la conférence")
	await capture("02-reception")
	if not await click("InboxPressInvitation"): return
	await capture("03-invitation")
	if not await click("InboxOpenPressInvitation"): return
	if not check(app.route == "Presse", "Le lien de l’invitation ouvre Presse"): return
	await capture("04-conference")
	var submit := control("PressSubmit")
	if not check(submit != null and submit.disabled, "Publication indisponible avant les réponses"): return
	for question: Dictionary in conference.questions:
		if not await click("PressAnswer_" + str(question.id) + "_r4"): return
	if not await click("PressSubmit") or not await ready_for_input(): return
	check(app.model.clubLife.press.lastOutcome is Dictionary and not app.model.clubLife.press.conference.required,
		"Le moteur confirme la publication et libère la progression")
	check(app.model.meta.calendarToday == date, "Publier ne change pas la date")
	if app.route == "Presse": await capture("05-publication")
	if not await click("PressBackToInvitation"): return
	if not check(app.route == "Réception", "Retour vers le courrier publié"): return
	await capture("06-courrier-publie")
	if not await click("ImmersiveCalendarDate"): return
	if not check(app.route == "Calendrier", "La date du bandeau ouvre le calendrier"): return
	check(app.model.calendarPlanning.today == date, "Le calendrier concorde avec la date du jeu")
	await capture("07-calendrier")
	if not await click("ImmersiveContinue") or not await ready_for_input(): return
	check(app.model.meta.calendarToday == "2026-08-18" and app.model.calendarPlanning.today == "2026-08-18",
		"Le bouton Jour suivant avance du 17 au 18 août")
	await capture("08-calendrier-lendemain")

func finish() -> void:
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"display":DisplayServer.get_name(), "checks":checks,
			"failures":failures, "captures":evidence}, "  "))
		file.close()
	print("RECETTE VISUELLE : ", checks, " contrôles ; ", failures.size(), " échecs")
	await app._close(0 if failures.is_empty() else 1)

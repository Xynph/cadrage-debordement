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

func f1() -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_F1
		event.pressed = down
		root.push_input(event, true)
		await process_frame
	await settle()

func verify_club() -> void:
	app._command("new_career", {"mode":"world-champ", "club":102})
	if not await ready_for_input(): return
	await f1()
	var coach := app.find_child("CoachGuide", true, false) as Control
	if not check(coach != null and coach.expanded, "F1 ouvre le guide de la carrière"): return
	var portrait := coach.find_child("GabiPortrait3D", true, false) as TextureRect
	if not check(portrait != null and portrait.is_visible_in_tree(), "Le guide affiche son véritable portrait 3D"): return
	var display := portrait.find_child("GabiPortraitViewport", true, false) as SubViewport
	var animations := portrait.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if not check(display != null and animations != null and portrait.texture is ViewportTexture, "Sous-rendu Godot et AnimationPlayer natifs"): return
	var bounds := portrait.get_global_rect()
	check(bounds.size.x >= 200.0 and root.get_visible_rect().encloses(bounds), "Le portrait agrandi reste dans la fenêtre")
	check(animations.current_animation == "Repos" and animations.get_animation("Repos").loop_mode == Animation.LOOP_LINEAR, "Repos en boucle")
	var phase := animations.current_animation_position
	await create_timer(.35).timeout
	check(animations.current_animation_position != phase, "Le repos avance réellement")
	await capture("01-gabi-repos")
	coach.close()
	await settle()
	check(display.render_target_update_mode == SubViewport.UPDATE_DISABLED, "Rendu suspendu quand le portrait est caché")
	app._navigate("Composition")
	await settle()
	await f1()
	check(animations.current_animation == "Approbation", "La composition déclenche le vrai geste du GLB")
	await capture("02-gabi-approbation")
	await create_timer(animations.get_animation("Approbation").length + .35).timeout
	check(animations.current_animation == "Repos", "Retour au repos après le geste")
	portrait.set_reduced_motion(true)
	await settle()
	check(not animations.is_playing(), "Les mouvements réduits figent la pose")
	await capture("03-gabi-mouvement-reduit")

func finish() -> void:
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"display":DisplayServer.get_name(), "checks":checks,
			"failures":failures, "captures":evidence}, "  "))
		file.close()
	print("RECETTE VISUELLE : ", checks, " contrôles ; ", failures.size(), " échecs")
	await app._close(0 if failures.is_empty() else 1)

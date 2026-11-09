extends SceneTree
var app: Control
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); printerr("FAIL: ", message)
func settle() -> void:
	for i in 10: await process_frame
func command(id: String, payload: Dictionary = {}) -> void:
	app._command(id, payload)
	var deadline := Time.get_ticks_msec() + 45000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec() < deadline: await process_frame
	check(not app.waiting and not app.model.is_empty() and app.bridge.last_response_ok, "Vrai worker : " + id)
	app.timer.stop()
	await settle()
func click(control: Control) -> void:
	var point := control.get_global_transform() * (control.size / 2)
	var motion := InputEventMouseMotion.new()
	motion.position = point; motion.global_position = point
	root.push_input(motion, true)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point; event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		event.pressed = down
		root.push_input(event, true)
		await process_frame
	await settle()
func capture(id: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(OS.get_environment("CD_INTERCLUB_ARTIFACTS").path_join(id + ".png")) == OK, "Capture " + id)
func run() -> void:
	root.mode = Window.MODE_WINDOWED
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await command("snapshot")
	await command("new_career", {"mode": "common", "club": 0})
	await command("export")
	var before: String = app.model.meta.exportText
	var profile: String = str(app.model.meta.dataDir).path_join("donnees.json")
	var bytes := FileAccess.get_file_as_bytes(profile)
	root.size = Vector2i(1920, 1080)
	app._navigate("Recrutement")
	await settle()
	for resolution in [Vector2i(1920, 1080), Vector2i(1280, 720)]:
		root.size = resolution
		await settle()
		if is_instance_valid(app.coach): app.coach.close()
		await settle()
		check(app.find_child("CarnetMarket", true, false) != null, "Vraie route immersive " + str(resolution))
		var market := app.find_child("OpenInterclubMarket", true, false) as Button
		var youth := app.find_child("OpenRegenScouting", true, false) as Button
		check(market != null, "Entrée marché entre clubs " + str(resolution))
		check(youth != null, "Entrée relève conservée " + str(resolution))
		if market == null or youth == null: continue
		var viewport := Rect2(Vector2.ZERO, root.get_visible_rect().size)
		for action: Button in [market, youth]:
			check(action.is_visible_in_tree() and not action.disabled and viewport.encloses(action.get_global_rect()), "Action entièrement visible : " + str(action.name))
			check(app.body_scroll.get_global_rect().encloses(action.get_global_rect()), "Action dans la zone visible de recrutement : " + str(action.name))
			var text_width := action.get_theme_font("font").get_string_size(action.text, HORIZONTAL_ALIGNMENT_LEFT, -1, action.get_theme_font_size("font_size")).x
			var icon_width := action.get_theme_constant("icon_max_width") + action.get_theme_constant("h_separation") if action.icon != null else 0
			check(text_width + icon_width + action.get_theme_stylebox("normal").get_minimum_size().x <= action.size.x + 1, "Libellé entier : " + str(action.name))
		check(not market.get_global_rect().intersects(youth.get_global_rect()), "Actions voisines sans chevauchement")
		for decoration: Control in market.get_parent().get_children():
			if decoration != market and decoration != youth and decoration.mouse_filter == Control.MOUSE_FILTER_IGNORE and decoration.get_global_rect().intersects(market.get_global_rect()):
				check(decoration.get_index() < market.get_index() and decoration.get_index() < youth.get_index(), "Actions dessinées au-dessus du décor")
		for action: Button in app.find_children("*", "Button", true, false):
			if action != market and action.is_visible_in_tree() and action.get_parent() == market.get_parent():
				check(not market.get_global_rect().intersects(action.get_global_rect()), "Marché sans chevauchement avec " + str(action.name))
		await capture("recrutement-" + str(resolution.x))
		await click(market)
		var dialog := app.get_node_or_null("InterclubMarket") as AcceptDialog
		check(dialog != null and dialog.visible, "Clic réel ouvre le marché " + str(resolution))
		if dialog != null:
			check(dialog.find_child("InterclubSearch", true, false) != null, "Recherche du vrai dialogue")
			check(not app.model.clubLife.interclubMarket.candidates.is_empty(), "Candidats du vrai worker présents")
			await capture("marche-" + str(resolution.x))
		app._clear_dialogs()
		await settle()
		await click(youth)
		var scouting := app.get_node_or_null("RegenScouting") as AcceptDialog
		check(scouting != null and scouting.visible, "Clic réel conserve la relève " + str(resolution))
		app._clear_dialogs()
		await settle()
	await command("export")
	check(before == app.model.meta.exportText, "Consultation sans changement de carrière ou RNG")
	check(bytes == FileAccess.get_file_as_bytes(profile), "Profil disque inchangé")
	app.queue_free()
	await settle()
	print("Marché immersif : ", checks, " contrôles, ", failures.size(), " échecs")
	quit(0 if failures.is_empty() else 1)

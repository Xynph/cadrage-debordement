class_name MacOSReceipt
extends SceneTree
## Dormant in the distribution; selected only in a disposable QA copy.
var app: Control
var failures: Array[String] = []
var checks := 0
var output := OS.get_environment("OVAL_MAC_RECEIPT")
var phase := OS.get_environment("OVAL_MAC_PHASE")

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("FAIL: ", label)

func wait_ready() -> bool:
	var deadline := Time.get_ticks_msec() + 180000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec() < deadline:
		if app.bridge.child_pid <= 0: break
		await process_frame
	app.timer.stop()
	var ok: bool = not app.waiting and not app.model.is_empty() and app.bridge.last_response_ok
	check(ok, "Packaged worker responds: " + app.last_error)
	return ok

func ask(command: String, payload: Dictionary = {}) -> bool:
	check(app._command(command, payload), "Command accepted: " + command)
	return await wait_ready()

func exported_state() -> Dictionary:
	if not await ask("export"): return {}
	return JSON.parse_string(app.model.meta.exportText).get("state", {})

func write_json(name_: String, value: Variant) -> void:
	var file := FileAccess.open(output.path_join(name_), FileAccess.WRITE)
	check(file != null, "Receipt file writable")
	if file != null: file.store_string(JSON.stringify(value)); file.close()

func capture(name_: String) -> void:
	check(DisplayServer.get_name() != "headless", "Native macOS window")
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(not image.is_empty() and image.get_width() >= 1280, "Rendered viewport")
	check(image.save_png(output.path_join(name_ + ".png")) == OK, "Viewport capture saved")

func run() -> void:
	check(OS.get_name() == "macOS" and not OS.has_feature("editor"), "Real exported macOS application")
	check(output.is_absolute_path(), "Explicit disposable evidence directory")
	if not failures.is_empty(): await finish(); return
	if current_scene != null: current_scene.free()
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	current_scene = app
	if not await wait_ready(): await finish(); return
	await capture(phase + "-startup")
	if phase == "fresh":
		check(not app._has_career(), "Empty first launch")
		if not await ask("new_career", {"mode":"world-champ", "club":3}): await finish(); return
		var before: Dictionary = await exported_state()
		app.pack_manager.scope = "career"
		app.pack_manager.open("career")
		app.pack_manager.choose_file()
		await process_frame
		check(app.pack_manager.picker.visible, "ZIP picker opens")
		app.pack_manager.picker.file_selected.emit(OS.get_environment("OVAL_MAC_PACK"))
		app.pack_manager.picker.hide()
		if not await wait_ready(): await finish(); return
		var preview: Dictionary = app.model.get("packs", {}).get("preview", {})
		check(not preview.is_empty(), "Original ZIP inspected")
		check(int(preview.get("counts", {}).get("journalists", 0)) == 10, "Ten journalist identities")
		check(int(preview.get("counts", {}).get("outlets", 0)) == 4, "Four outlet identities")
		app.pack_manager.install()
		if not await wait_ready(): await finish(); return
		app.pack_manager.select(str(preview.get("id", "")), "career")
		if not await wait_ready(): await finish(); return
		check(app.model.packs.career == preview.get("id"), "Installed pack selected")
		var after: Dictionary = await exported_state()
		before.erase("identityPack")
		var sports := after.duplicate(true)
		sports.erase("identityPack")
		check(before == sports, "Pack preserves simulation state")
		if OS.get_environment("OVAL_MAC_FIXTURE") == "1":
			var people: Array = app.model.clubLife.press.people
			check(people.any(func(p: Dictionary): return p.id == "presse-0" and p.name == "Camille Essai" and p.outlet == "Le Courrier des Touches"), "Fictional press projected")
		if not await ask("save"): await finish(); return
		write_json("saved-state.json", after)
		write_json("saved-press.json", app.model.clubLife.press.people)
	else:
		check(app._has_career(), "Career resumes in a new application process")
		var original: Variant = JSON.parse_string(FileAccess.get_file_as_string(output.path_join("saved-state.json")))
		check(await exported_state() == original, "Saved simulation resumes identically")
		var people: Variant = JSON.parse_string(FileAccess.get_file_as_string(output.path_join("saved-press.json")))
		check(app.model.clubLife.press.people == people, "Pack press identities survive restart")
	app._navigate("Presse")
	await capture(phase + "-press")
	await finish()

func finish() -> void:
	if is_instance_valid(app):
		app.closing = true
		app.timer.stop()
		if is_instance_valid(app.coach): app.coach.destroy()
		if is_instance_valid(app.soundscape): app.soundscape.dispose()
		app.bridge.stop()
		var deadline := Time.get_ticks_msec() + 5000
		while app.bridge.child_pid > 0 and Time.get_ticks_msec() < deadline: await process_frame
		check(app.bridge.child_pid <= 0, "Owned Node stops cleanly")
	var report := {"passed":failures.is_empty(), "phase":phase, "checks":checks, "failures":failures, "platform":OS.get_name(), "display":DisplayServer.get_name(), "executable":OS.get_executable_path(), "pid":OS.get_process_id()}
	if output.is_absolute_path(): write_json(phase + "-report.json", report)
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)

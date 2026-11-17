class_name MacOSReceipt
extends SceneTree
## Dormant in the distribution; selected only in a disposable QA copy.
var app: Control
var failures: Array[String] = []
var checks := 0
var captures: Array[Dictionary] = []
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

func has_text(node: Node, text: String) -> bool:
	if node is Label and text in node.text: return true
	for child in node.get_children():
		if has_text(child, text): return true
	return false

func preferences() -> void:
	check(app.coach.profile.last_error.is_empty(), "Guide starts without a persistence error")
	if phase == "fresh":
		var guide: Dictionary = app.coach.profile.data.duplicate(true)
		guide.muted = true
		guide.rate = 1.25
		check(app.coach.profile.save_profile(guide), "Guide settings written by packaged atomic helper")
		check(app.user_preferences.set_value("volume", 41), "Interface settings written atomically")
		check(app.soundscape.preferences.set_value("interface_volume", 17), "Sound settings written atomically")
	else:
		check(app.coach.profile.data.muted and is_equal_approx(float(app.coach.profile.data.rate), 1.25), "Guide settings survive application restart")
		check(int(app.user_preferences.data.volume) == 41, "Interface settings survive application restart")
		check(app.soundscape.preferences.get_value("interface_volume") == 17, "Sound settings survive application restart")

func capture(name_: String) -> void:
	check(DisplayServer.get_name() != "headless", "Native macOS window")
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(not image.is_empty() and image.get_width() > 0 and image.get_height() > 0, "Rendered viewport")
	if image.is_empty(): return
	# Hosted Macs can constrain the native window to their virtual display.
	# Validate actual rendered content instead of assuming a 1280-pixel display.
	var colors: Dictionary = {}
	for y in 16:
		for x in 16:
			colors[image.get_pixel(int(float(x) * (image.get_width() - 1) / 15), int(float(y) * (image.get_height() - 1) / 15)).to_html()] = true
	check(colors.size() > 8, "Rendered interface has visible content")
	captures.append({"name":name_, "width":image.get_width(), "height":image.get_height(), "sampled_colors":colors.size(), "window":[root.size.x, root.size.y]})
	check(image.save_png(output.path_join(name_ + ".png")) == OK, "Viewport capture saved")

func run() -> void:
	check(OS.get_name() == "macOS" and not OS.has_feature("editor"), "Real exported macOS application")
	check(OS.has_feature(OS.get_environment("OVAL_MAC_ARCH")), "Native application architecture")
	check(output.is_absolute_path(), "Explicit disposable evidence directory")
	if not failures.is_empty(): await finish(); return
	if current_scene != null: current_scene.free()
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	current_scene = app
	if not await wait_ready(): await finish(); return
	check(has_text(app, "Édition macOS"), "Home identifies the Mac application")
	check(not has_text(app, "Édition Windows") and not has_text(app, "APPLICATION WINDOWS NATIVE"), "Home has no Windows-only label")
	await preferences()
	await capture(phase + "-startup")
	if phase == "fresh":
		check(not app._has_career(), "Empty first launch")
		if not await ask("new_career", {"mode":"world-champ", "club":3}): await finish(); return
		if not await load("res://qa_runner.gd").settle_club_meetings(app, self, check): await finish(); return
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
	var state: Dictionary = await exported_state()
	var exported_path := output.path_join("Carrière de réception — " + phase + ".json")
	var old := FileAccess.open(exported_path, FileAccess.WRITE)
	if old != null: old.store_string("previous export"); old.close()
	check(old != null, "Existing export created for replacement probe")
	app.export_path = exported_path
	check(app._write_export(), "Career export replaces an existing file atomically")
	var document: Variant = JSON.parse_string(FileAccess.get_file_as_string(exported_path))
	check(document is Dictionary and document.get("state") == state, "Career export on disk matches the live state")
	check(app.coach.profile.last_error.is_empty(), "Guide remains free of write errors")
	app.pack_manager.open("career")
	check(app.route == "Packs", "Installed pack page is reachable")
	await capture(phase + "-packs")
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
	var report := {"passed":failures.is_empty(), "phase":phase, "checks":checks, "failures":failures, "platform":OS.get_name(), "display":DisplayServer.get_name(), "executable":OS.get_executable_path(), "pid":OS.get_process_id(), "captures":captures}
	if output.is_absolute_path(): write_json(phase + "-report.json", report)
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)

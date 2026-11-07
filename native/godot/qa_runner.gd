extends Node

# Real scene reception. Run with --path native/godot --script absolute/tests/godot-ui.gd.
# CD_GODOT_DATA_DIR must point to a disposable isolated profile.
var app: Control
var root: Window
var engine_pid := -1
var failures: Array[String] = []
var captures := ""
var checks := 0

func _ready() -> void:
	root = get_tree().root
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("FAIL: ", message)

func _settle() -> void:
	for i in range(4): await get_tree().process_frame

func _wait_model() -> bool:
	var deadline := Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		if not app.waiting and not app.model.is_empty(): return true
	_check(false, "Response timed out")
	return false

func _command(name: String, payload: Dictionary = {}) -> void:
	app._command(name, payload)
	await _wait_model()

func _capture(name: String) -> void:
	if captures.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	_check(image.get_size() == DisplayServer.window_get_size(), "Capture matches native client size " + name)
	var pixel_end: Vector2 = app.body.get_global_transform_with_canvas() * app.body.size
	_check(pixel_end.y <= image.get_height() + 1, "Live page fits native client " + name + " " + str(pixel_end))
	var footer_end: Vector2 = app.status.get_global_transform_with_canvas() * app.status.size
	_check(footer_end.y <= image.get_height() + 1, "Footer visible " + name)
	var error := image.save_png(captures.path_join(name + ".png"))
	_check(error == OK, "Capture " + name)

func _run() -> void:
	if OS.get_environment("CD_GODOT_DATA_DIR").is_empty():
		printerr("Explicit disposable CD_GODOT_DATA_DIR required")
		get_tree().quit(2)
		return
	captures = OS.get_environment("CD_GODOT_QA_CAPTURES")
	if not captures.is_empty(): DirAccess.make_dir_recursive_absolute(captures)
	await _wait_model()
	engine_pid = app.bridge.child_pid
	app.timer.stop()
	_check(app.model.get("protocol", 0) == 1, "Real engine protocol")
	_check(app.model.get("squad", []).size() >= 23, "Actual squad available")
	_check(app.catalogue.size() == 30, "Thirty territory catalogue")
	for resolution in [Vector2i(1440, 900), Vector2i(1920, 1080)]:
		DisplayServer.window_set_size(resolution)
		if DisplayServer.get_name() == "headless": root.size = resolution
		await _settle()
		for page in ["Bureau", "Club", "Effectif", "Match"]:
			app._navigate(page)
			await _settle()
			_check(app.heading.size.x > 200, "Header visible " + page)
			_check(app.body.get_global_rect().end.y <= app.size.y + 1, "Page fits window " + page)
			_check(app.body.get_global_rect().end.x <= app.size.x + 1, "Page fits width " + page)
			var pixel_end: Vector2 = app.body.get_global_transform_with_canvas() * app.body.size
			_check(pixel_end.y <= resolution.y + 1, "Page fits native client height " + page + " " + str(pixel_end))
			_check(pixel_end.x <= resolution.x + 1, "Page fits native client width " + page + " " + str(pixel_end))
			await _capture(page.to_lower() + "-" + str(resolution.x))
		app.selected_club = 29
		app._navigate("Club")
		await _settle()
		await _capture("club-long-" + str(resolution.x))
		app.selected_club = 0
	var before := JSON.stringify(app.model.squad)
	await _command("train", {"mode": "normal"})
	_check(app.model.meta.trained, "Training action committed")
	_check(JSON.stringify(app.model.squad) != before, "Training changes actual squad state")
	await _command("auto_lineup")
	await _command("save")
	app._navigate("Match")
	await _command("begin_match")
	_check(app.model.live != null, "Actual match begins")
	await _command("tick", {"steps": 8})
	await _command("pause", {"paused": true})
	_check(app.model.live.paused, "Pause command")
	await _settle()
	await _capture("match-live-1920")
	app.match_view.set_camera("tactical")
	await _settle()
	await _capture("match-tactical-1920")
	await _command("delegate")
	_check(app.model.live.finished, "Native match completed")
	await _capture("match-result-1920")
	var retained_match_page: Node = app.match_page
	await _command("finish_round")
	_check(app.model.meta.round == 1, "Round advanced")
	await _command("auto_lineup")
	_check(app.match_page == retained_match_page, "Same Match page after round validation")
	_check(not app.pause_button.disabled, "Second kickoff available without navigation")
	if not app.pause_button.disabled:
		app.pause_button.pressed.emit()
		await _wait_model()
		_check(app.model.live != null and app.model.meta.round == 1, "Second match starts through native kickoff button")
		await _command("pause", {"paused": true})
		_check(app.model.live.paused, "Second match can pause through engine")
	await _command("save")
	var export_file := OS.get_environment("CD_GODOT_DATA_DIR").path_join("export-ui.json")
	app.import_mode = false
	app._file_selected(export_file)
	await _wait_model()
	_check(FileAccess.file_exists(export_file), "UI export actually written")
	await _command("new_career", {"club": 1})
	app._navigate("Bureau")
	await _settle()
	await _capture("bureau-bordeaux-1920")
	app._navigate("Effectif")
	await _settle()
	await _capture("effectif-bordeaux-1920")
	app.import_mode = true
	app._file_selected(export_file)
	await _wait_model()
	_check(app.model.club.id == 0 and app.model.meta.round == 1, "UI import restores exported career")
	app.bridge.stop()
	for i in range(300):
		if app.bridge.child_pid <= 0: break
		await get_tree().process_frame
	var result := {"passed": failures.is_empty(), "checks": checks, "failures": failures, "native_display": DisplayServer.get_name(), "captures": captures, "pid": OS.get_process_id(), "engine_pid": engine_pid, "executable": OS.get_executable_path()}
	if not captures.is_empty():
		var file := FileAccess.open(captures.path_join("report.json"), FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(result, "\t"))
			file.close()
	print(JSON.stringify(result))
	get_tree().quit(0 if failures.is_empty() else 1)

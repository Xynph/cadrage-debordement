extends SceneTree

# Real scene reception. Run with --path native/godot --script absolute/tests/godot-ui.gd.
# CD_GODOT_DATA_DIR must point to a disposable isolated profile.
var app: Control
var failures: Array[String] = []
var captures := ""

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		printerr("FAIL: ", message)

func _settle() -> void:
	for i in range(4): await process_frame

func _wait_model() -> bool:
	for i in range(1800):
		await process_frame
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
	var error := image.save_png(captures.path_join(name + ".png"))
	_check(error == OK, "Capture " + name)

func _run() -> void:
	if OS.get_environment("CD_GODOT_DATA_DIR").is_empty():
		printerr("Explicit disposable CD_GODOT_DATA_DIR required")
		quit(2)
		return
	captures = OS.get_environment("CD_GODOT_QA_CAPTURES")
	if not captures.is_empty(): DirAccess.make_dir_recursive_absolute(captures)
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await _wait_model()
	app.timer.stop()
	_check(app.model.get("protocol", 0) == 1, "Real engine protocol")
	_check(app.model.get("squad", []).size() >= 23, "Actual squad available")
	_check(app.catalogue.size() == 30, "Thirty territory catalogue")
	for resolution in [Vector2i(1440, 900), Vector2i(1920, 1080)]:
		DisplayServer.window_set_size(resolution)
		root.size = resolution
		await _settle()
		for page in ["Bureau", "Club", "Effectif", "Match"]:
			app._navigate(page)
			await _settle()
			_check(app.heading.size.x > 200, "Header visible " + page)
			_check(app.body.get_global_rect().end.y <= app.size.y + 1, "Page fits window " + page)
			await _capture(page.to_lower() + "-" + str(resolution.x))
		app.selected_club = 29
		app._navigate("Club")
		await _settle()
		await _capture("club-long-" + str(resolution.x))
		app.selected_club = 0
	var before: float = app.model.squad[0].physicalLoad
	await _command("train", {"mode": "normal"})
	_check(app.model.meta.trained, "Training action committed")
	_check(float(app.model.squad[0].physicalLoad) != before, "Training changes real load")
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
	await _command("finish_round")
	_check(app.model.meta.round == 1, "Round advanced")
	await _command("save")
	app.bridge.stop()
	app.queue_free()
	await _settle()
	print(JSON.stringify({"passed": failures.is_empty(), "failures": failures, "native_display": DisplayServer.get_name(), "captures": captures}))
	quit(0 if failures.is_empty() else 1)

extends SceneTree
## Aperçu autonome. J/S : jour/soirée. 1/2/3 : caméras TV, tactique, action.
## CD_STADIUM_PROOF : dossier absolu facultatif pour captures et mesures.

const Stadium = preload("res://match_stadium_evening.gd")
const View = preload("res://match_view.gd")
const SAMPLES := 120

var view: NativeMatchView
var kit: Stadium
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func fixture() -> Dictionary:
	var players: Array[Dictionary] = []
	for side in 2:
		for slot in 15:
			var featured := side == 0 and slot == 0
			players.append({
				"id": "%d-%d" % [side, slot], "side": side, "slot": slot, "featured": featured,
				"x": 51.0 if featured else 34.0 + side * 21.0 + (slot % 3) * 2.5,
				"y": 35.0 if featured else 7.0 + slot * 4.0,
			})
	return {
		"paused": true,
		"scene": {"kind": "carry", "possession": 0, "players": players, "ball": {"x": 51.0, "y": 35.0}},
		"teams": [{"color": "#a12f41"}, {"color": "#5a92bd"}],
	}


func handle_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_J: kit.set_evening(false)
		KEY_S: kit.set_evening(true)
		KEY_1: view.set_camera("tv")
		KEY_2: view.set_camera("tactical")
		KEY_3: view.set_camera("action")
		KEY_ESCAPE: quit()


func run() -> void:
	var frame := fixture()
	view = View.new()
	root.add_child(view)
	view.set_process(false)
	view.apply_frame(frame)
	view._process(1.0)
	check(view._actors.size() == 30, "30 joueurs présents")
	var original_actors := view._actors.keys()
	var original_ball := view._ball.position
	var environment := view.find_children("*", "WorldEnvironment", false, false)[0] as WorldEnvironment
	var original_environment := environment.environment
	var original_sun := view._sun.light_energy
	kit = Stadium.new()
	kit.attach(view)
	kit.attach(view)
	check(kit.get_child_count() == 3, "installation idempotente")
	check(kit.get_node("Floodlights").get_child_count() == 4, "quatre projecteurs")
	kit.set_evening(true)
	check(kit.visible and view._sun.light_energy < original_sun, "activation soirée")
	check(environment.environment != original_environment, "environnement distinct")
	check(view._actors.keys() == original_actors and view._ball.position.is_equal_approx(original_ball),
		"présence et ballon stables")
	for spot: SpotLight3D in kit.get_node("Floodlights").get_children():
		check(spot.is_visible_in_tree() and not spot.shadow_enabled, "projecteur sans ombres")
	kit.set_evening(false)
	check(not kit.visible and is_equal_approx(view._sun.light_energy, original_sun), "retour jour")
	check(environment.environment == original_environment, "restauration environnement")
	print("MATCH_STADIUM_EVENING ", JSON.stringify({"players": view._actors.size(), "failures": failures}))
	if not failures.is_empty() or DisplayServer.get_name() == "headless":
		quit(0 if failures.is_empty() else 1)
		return
	root.title = "Oval Legacy 27 · Stade · J jour / S soirée · 1 TV / 2 tactique / 3 action"
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	view.set_process(true)
	var proof := OS.get_environment("CD_STADIUM_PROOF")
	if proof.is_empty():
		root.window_input.connect(handle_input)
		return
	view.set_process(false)
	if not proof.is_absolute_path() or DirAccess.make_dir_recursive_absolute(proof) != OK:
		push_error("CD_STADIUM_PROOF doit désigner un dossier absolu accessible.")
		quit(1)
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var profiles: Array[Dictionary] = []
	for evening in [false, true]:
		kit.set_evening(evening)
		var label := "soiree" if evening else "jour"
		for camera in ["tv", "tactical", "action"]:
			view.set_camera(camera)
			view._process(1.0 / 60.0)
			await RenderingServer.frame_post_draw
			if root.get_texture().get_image().save_png(proof.path_join("%s-%s.png" % [label, camera])) != OK:
				push_error("Écriture de capture impossible.")
				quit(1)
				return
		view.set_camera("tactical")
		for warmup in 24:
			await RenderingServer.frame_post_draw
		var frame_ms: Array[float] = []
		var projection_ms: Array[float] = []
		var previous := Time.get_ticks_usec()
		for sample in SAMPLES:
			var before := Time.get_ticks_usec()
			view._process(1.0 / 60.0)
			projection_ms.append((Time.get_ticks_usec() - before) / 1000.0)
			await RenderingServer.frame_post_draw
			var now := Time.get_ticks_usec()
			frame_ms.append((now - previous) / 1000.0)
			previous = now
		frame_ms.sort()
		projection_ms.sort()
		profiles.append({
			"preset": label, "camera": "tactical", "quality": "balanced",
			"players": view._actors.size(), "samples": SAMPLES, "size": [root.size.x, root.size.y],
			"frame_ms_median": frame_ms[60], "frame_ms_p95": frame_ms[113],
			"projection_ms_median": projection_ms[60], "projection_ms_p95": projection_ms[113],
			"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			"primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		})
	var file := FileAccess.open(proof.path_join("stade-mesures.json"), FileAccess.WRITE)
	if file == null:
		push_error("Écriture du rapport impossible.")
		quit(1)
		return
	file.store_string(JSON.stringify({
		"adapter": RenderingServer.get_video_adapter_name(), "godot": Engine.get_version_info().string,
		"vsync": DisplayServer.window_get_vsync_mode(), "max_fps": Engine.max_fps, "profiles": profiles,
	}, "\t"))
	file.close()
	quit()

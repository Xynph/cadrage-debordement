extends SceneTree
## Reproductible visual fixture, separate from the engine and from player saves.
## Run graphically only; the parent serializes graphics with the other agents.

var view: Node3D
var proof := OS.get_environment("CD_MATCH_PROOF")

func _initialize() -> void:
	call_deferred("run")

func fixture(frame: int) -> Dictionary:
	var players: Array = []
	var x := 50.0 + minf(frame, 44) * 0.02
	var y := 35.0
	if frame >= 45:
		x -= minf(frame - 45, 44) * 0.018
		y += minf(frame - 45, 44) * 0.018
	var receiving := frame >= 90
	for side in 2:
		for slot in 15:
			var is_lead := side == 0 and slot == 0
			var is_receiver := side == 0 and slot == 1
			players.append({"id": "%d-%d" % [side, slot], "side": side, "slot": slot,
				"x": x if is_lead else (53.0 if is_receiver else 21.0 + side * 40.0 + slot % 3 * 3.0),
				"y": y if is_lead else (35.8 if is_receiver else 7.0 + slot * 4.0),
				"featured": is_receiver if receiving else is_lead})
	return {"scene": {"key": str(frame), "kind": "reception" if receiving else "carry", "possession": 0,
		"players": players, "origin": {"x": 50.0, "y": 35.0},
		"ball": {"x": 53.0 if receiving else x, "y": 35.8 if receiving else y}},
		"teams": [{"color": "#a12f41"}, {"color": "#5a92bd"}]}

func save_frame(filename: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(proof.path_join(filename))
	if error != OK:
		push_error("Écriture de capture impossible : " + filename + " (" + str(error) + ")")
		quit(1)

func run() -> void:
	if proof.is_empty() or DisplayServer.get_name() == "headless":
		push_error("Capture graphique requise et CD_MATCH_PROOF doit nommer un dossier sur E:.")
		quit(1)
		return
	var directory_error := DirAccess.make_dir_recursive_absolute(proof)
	if directory_error != OK:
		push_error("Dossier de preuve inaccessible : " + proof)
		quit(1)
		return
	root.title = "Oval Legacy 27 — fixture Match3D native0.6"
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	var script := OS.get_environment("CD_MATCH_VIEW_SCRIPT")
	view = load(script if not script.is_empty() else "res://match_view.gd").new()
	root.add_child(view)
	await process_frame
	view.set_process(false)
	view.apply_frame(fixture(0))
	view._process(1.0)
	for mode in ["tv", "tactical", "action"]:
		view.set_camera(mode)
		# Receive the settled framing, rather than a single frame interpolated
		# from the previous camera (which looked tactical for every profile).
		for settle_frame in 90:
			view._process(1.0 / 60.0)
			await process_frame
		await save_frame(mode + ".png")
	# 120 authored frames at 30fps. Save every other frame: the exact same
	# movement, pivot, repeated snapshots and receiver switch in both versions.
	for frame in 120:
		if frame % 6 == 0 or frame == 45 or frame == 90:
			view.apply_frame(fixture(frame))
		view._process(1.0 / 30.0)
		view._camera.position = Vector3(4.0, 3.3, 6.4)
		view._camera.look_at(Vector3(1.3, 0.9, 0.3))
		view._camera.size = 5.5
		if frame % 2 == 0:
			await save_frame("motion-%03d.png" % frame)
	# Fixed 30-actor scene, same camera and authored motion for all three profiles.
	var benchmarks: Array = []
	view.set_camera("tv")
	for quality in ["economy", "balanced", "detail"]:
		view.set_quality(quality)
		view.apply_frame(fixture(0))
		view._process(1.0)
		for frame in 60:
			view._process(1.0 / 60.0)
			await process_frame
		var samples: Array[float] = []
		var cpu_samples: Array[float] = []
		var previous := Time.get_ticks_usec()
		for frame in 180:
			var started := Time.get_ticks_usec()
			view._process(1.0 / 60.0)
			cpu_samples.append((Time.get_ticks_usec() - started) / 1000.0)
			await process_frame
			var now := Time.get_ticks_usec()
			samples.append((now - previous) / 1000.0)
			previous = now
		samples.sort()
		cpu_samples.sort()
		benchmarks.append({"profile": quality, "actors": view._actors.size(), "frames": samples.size(),
			"frame_ms_median": samples[90], "frame_ms_p95": samples[171],
			"projection_cpu_ms_median": cpu_samples[90], "projection_cpu_ms_p95": cpu_samples[171],
			"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			"primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})
	var report := FileAccess.open(proof.path_join("bench.json"), FileAccess.WRITE)
	if report == null:
		push_error("Rapport de mesure impossible à écrire : " + str(FileAccess.get_open_error()))
		quit(1)
		return
	report.store_string(JSON.stringify({"fixture": "native06-motion-120f-30fps", "adapter": RenderingServer.get_video_adapter_name(),
		"view_script": script, "samples": benchmarks}, "  "))
	print("MATCH_MOTION_GRAPHICS_PROOF ", proof)
	view.queue_free()
	await process_frame
	quit()

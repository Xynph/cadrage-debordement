extends SceneTree

var view: Node3D
var players: Array = []
var proof := OS.get_environment("CD_MATCH_PROOF")

func _initialize() -> void:
	call_deferred("run")

func live(x: float) -> Dictionary:
	players[0].x = x
	return {"scene": {"key": str(x), "kind": "carry", "possession": 0,
		"players": players, "ball": {"x": x, "y": 35}, "origin": {"x": x - 2, "y": 35}},
		"teams": [{"color": "#a12f41"}, {"color": "#5a92bd"}]}

func run() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	view = load("res://match_view.gd").new()
	root.add_child(view)
	await process_frame
	for side in 2:
		for slot in 15:
			players.append({"id": "%d-%d" % [side, slot], "side": side, "slot": slot,
				"x": 50 if side == 0 and slot == 0 else 20 + side * 40 + slot % 3 * 3,
				"y": 35 if side == 0 and slot == 0 else 7 + slot * 4,
				"featured": side == 0 and slot == 0})
	view.apply_frame(live(50.0))
	for i in 45: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(proof.path_join("terrain.png"))
	view.set_camera("action")
	for i in 100: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(proof.path_join("action.png"))
	# A continuous authored test traversal, not a fabricated match outcome.
	# Camera is intentionally close for checking wrists, feet and source animation.
	view.set_process(false)
	view._camera.position = Vector3(4, 3, 6)
	view._camera.look_at(Vector3(0, 1, 0))
	view._camera.size = 4.3
	for frame in 120:
		if frame % 15 == 0: view.apply_frame(live(50.0 + frame / 120.0 * 5.0))
		view._process(1.0 / 30.0)
		view._camera.position = view._actors["0-0"].node.position + Vector3(3.8, 2.4, 5)
		view._camera.look_at(view._actors["0-0"].node.position + Vector3(0, 0.95, 0))
		view._camera.size = 3.1
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(proof.path_join("motion-%03d.png" % frame))
	view.set_process(true)
	view.set_camera("tv")
	var benchmarks: Array = []
	for quality in ["economy", "balanced", "detail"]:
		view.set_quality(quality)
		for i in 60: await process_frame
		var samples: Array[float] = []
		var previous := Time.get_ticks_usec()
		for frame in 180:
			if frame % 30 == 0: view.apply_frame(live(50.0 + sin(frame * 0.1)))
			await process_frame
			var now := Time.get_ticks_usec()
			samples.append((now - previous) / 1000.0)
			previous = now
		samples.sort()
		benchmarks.append({"profile": quality, "actors": view._actors.size(), "frames": samples.size(),
			"frame_ms_median": samples[90], "frame_ms_p95": samples[171],
			"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			"primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})
	var file := FileAccess.open(proof.path_join("bench.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"adapter": RenderingServer.get_video_adapter_name(), "samples": benchmarks}, "  "))
	print("MATCH_GRAPHICS_PROOF ", proof)
	quit()

extends SceneTree
## Comparatif de présentation seulement : mêmes racines et mêmes instantanés.
## Cinq secondes de fixture déclarée, puis cinq secondes de vrais fragments.
var proof := OS.get_environment("CD_MATCH_CONTACT_PROOF")
var views: Array[Node3D] = []
var caption: Label
var metrics := {"fixture_frames": 150, "real_frames": 150, "captured_frames": 0, "brace_frames": 0}

func _initialize() -> void:
	call_deferred("run")

func fixture(frame: int) -> Dictionary:
	var players: Array = []
	var distance := lerpf(2.4, 0.9, smoothstep(0.0, 45.0, frame)) if frame < 75 else lerpf(0.9, 2.8, smoothstep(75.0, 120.0, frame))
	for side in 2:
		for slot in 15:
			players.append({"id": "%d-%d" % [side, slot], "side": side,
				"x": (50.0 if side == 0 else 50.0 + distance) if slot == 0 else 22.0 + side * 45.0 + slot % 3 * 2.0,
				"y": 35.0 if slot == 0 else 5.0 + slot * 4.0,
				"featured": side == 0 and slot == 0})
	return {"scene": {"key": "fixture", "kind": "carry" if frame < 120 else "kickoff", "possession": 0, "players": players,
		"ball": {"x": 50.0, "y": 35.0}}, "teams": [{"color": "#a12f41"}, {"color": "#5a92bd"}]}

func capture(frame: int) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(proof.path_join("contact-%03d.png" % frame))
	if error != OK:
		push_error("Capture contact impossible : " + str(error))
		quit(1)
	metrics.captured_frames += 1

func run() -> void:
	if proof.is_empty() or DisplayServer.get_name() == "headless":
		push_error("CD_MATCH_CONTACT_PROOF et un rendu Windows graphique sont requis.")
		quit(1)
		return
	if DirAccess.make_dir_recursive_absolute(proof) != OK:
		push_error("Dossier de preuve inaccessible : " + proof)
		quit(1)
		return
	var real_path := OS.get_environment("CD_MATCH_CONTACT_REAL")
	var real: Variant = JSON.parse_string(FileAccess.get_file_as_string(real_path))
	if not real is Dictionary or not real.get("lives", null) is Array or real.lives.is_empty():
		push_error("Fragments réels issus du worker requis, sans reconstruction.")
		quit(1)
		return
	root.title = "Oval Legacy 27 — réception contact native07"
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	var base := ColorRect.new()
	base.color = Color("17282e")
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(base)
	for index in 2:
		var container := SubViewportContainer.new()
		container.position = Vector2(index * 640, 56)
		container.size = Vector2(640, 664)
		container.stretch = true
		root.add_child(container)
		var viewport := SubViewport.new()
		viewport.size = Vector2i(640, 664)
		viewport.own_world_3d = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		container.add_child(viewport)
		var script := OS.get_environment("CD_MATCH_CONTACT_BASE") if index == 0 else "res://match_view.gd"
		var view = load(script).new()
		viewport.add_child(view)
		views.append(view)
		var title := Label.new()
		title.position = Vector2(16 + index * 640, 8)
		title.text = "AVANT · mêmes trajectoires" if index == 0 else "APRÈS · préparation et protection proches"
		title.add_theme_font_size_override("font_size", 21)
		root.add_child(title)
	caption = Label.new()
	caption.position = Vector2(16, 34)
	caption.add_theme_font_size_override("font_size", 14)
	root.add_child(caption)
	await process_frame
	for view in views:
		view.set_process(false)
		view.set_camera("action")
		view.apply_frame(fixture(0))
		view._process(1.0)
	for frame in 300:
		var is_fixture := frame < 150
		var live: Dictionary = fixture(frame) if is_fixture else real.lives[mini(real.lives.size() - 1, (frame - 150) / 22)]
		if frame % 3 == 0 or frame == 150:
			for view in views: view.apply_frame(live)
		var kind: String = str(live.scene.kind)
		caption.text = ("FIXTURE DE PROXIMITÉ · aucune décision sportive" if is_fixture else "FRAGMENTS RÉELS DU WORKER · seed %s · %s" % [str(real.best.seed), kind])
		for view in views:
			view._process(1.0 / 30.0)
			var focus: Vector3 = view._ball.global_position if view._ball.visible else Vector3.ZERO
			view._camera.position = focus + Vector3(3.5, 2.1, 5.0)
			view._camera.look_at(focus + Vector3(0.0, 0.2, 0.0))
			view._camera.size = 4.5 if is_fixture else 9.0
		if views[1]._actors.values().any(func(entry: Dictionary) -> bool: return float(entry.contact_weight) > 0.05): metrics.brace_frames += 1
		if frame % 2 == 0: await capture(frame)
		else: await process_frame
	metrics.adapter = RenderingServer.get_video_adapter_name()
	metrics.real_source = real.source
	metrics.real_best = real.best
	var report := FileAccess.open(proof.path_join("graphics.json"), FileAccess.WRITE)
	if report == null:
		push_error("Rapport graphique inaccessible : " + str(FileAccess.get_open_error()))
		quit(1)
		return
	report.store_string(JSON.stringify(metrics, "  "))
	print("MATCH_CONTACT07_GRAPHICS ", JSON.stringify(metrics))
	quit()

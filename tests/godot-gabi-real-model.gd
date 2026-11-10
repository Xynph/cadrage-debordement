extends SceneTree
const Rooms = preload("res://qa_runner.gd")

var app: Control
var checks := 0
var failures: Array[String] = []
var captures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		printerr("FAIL: ", message)

func settle() -> void:
	for frame in 8: await process_frame

func pose(skeleton: Skeleton3D) -> Array[Transform3D]:
	var result: Array[Transform3D] = []
	for bone in skeleton.get_bone_count(): result.append(skeleton.get_bone_pose(bone))
	return result

func run() -> void:
	var dimensions_to_check := [Vector2i(1920, 1080), Vector2i(2560, 1440)]
	if OS.get_environment("QA_RESOLUTION") == "2560x1440": dimensions_to_check = [Vector2i(2560, 1440)]
	root.size = dimensions_to_check[0]
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	var deadline := Time.get_ticks_msec() + 90000
	while (app.waiting or app.model.is_empty()) and app.last_error.is_empty() and Time.get_ticks_msec() < deadline:
		await process_frame
	check(not app.model.is_empty() and app.bridge.last_response_ok, "Vraie application reliée au moteur : " + str(app.last_error))
	if app.model.is_empty():
		await app._close(1)
		return
	app.timer.stop()
	app._command("new_career", {"mode":"common", "club":29})
	deadline = Time.get_ticks_msec() + 30000
	while app.waiting and Time.get_ticks_msec() < deadline: await process_frame
	await settle()
	check(not app.waiting and app.bridge.last_response_ok, "Carrière jetable créée par le vrai moteur")
	if app.waiting or not app.bridge.last_response_ok:
		await app._close(1)
		return
	if not await Rooms.settle_club_meetings(app, self, check): await app._close(1); return
	app._navigate("Bureau")
	await settle()
	var coach: Control = app.coach
	check(is_instance_valid(coach), "Guide intégré présent")
	var portrait: TextureRect = coach.portrait
	var player := portrait.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var skeleton: Skeleton3D
	for node in portrait.find_children("*", "Skeleton3D", true, false):
		skeleton = node
		break
	check(portrait.texture is ViewportTexture and player != null, "Vrai GLB et SubViewport chargés")
	check(skeleton != null and skeleton.get_bone_count() == 20, "Rig livré à vingt os")
	if player == null or skeleton == null:
		await app._close(1)
		return
	check(coach.speech.muted and coach.speech.player == null, "Guide de carrière silencieux sans lecteur audio")
	var filename: String = str(app.model.meta.dataDir).path_join("donnees.json")
	check(FileAccess.file_exists(filename), "Profil sportif présent pour le contrôle de non-mutation")
	var before := FileAccess.get_sha256(filename) if FileAccess.file_exists(filename) else "absent"
	for clip in ["Repos", "Approbation", "Salut", "Explication", "Ecoute", "RegardCarnet"]:
		check(player.has_animation(clip), "Clip livré : " + clip)
		if not player.has_animation(clip): continue
		player.play(clip, 0.0)
		player.seek(0.0, true)
		var first := pose(skeleton)
		player.seek(player.get_animation(clip).length * 0.45, true)
		check(pose(skeleton) != first, "Le clip déforme réellement le rig : " + clip)
	check(player.get_animation("Repos").loop_mode == Animation.LOOP_LINEAR, "Repos en boucle")
	for dimensions in dimensions_to_check:
		root.size = dimensions
		if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(dimensions)
		coach.close()
		await settle()
		var key := InputEventKey.new()
		key.keycode = KEY_F1
		key.pressed = true
		Input.parse_input_event(key)
		await process_frame
		key = InputEventKey.new()
		key.keycode = KEY_F1
		Input.parse_input_event(key)
		await settle()
		if OS.get_environment("QA_RESOLUTION") == "2560x1440": check(root.size == dimensions, "Client réel exclusivement 2560 × 1440")
		check(coach.expanded, "F1 ouvre le guide à " + str(dimensions))
		check(not coach.speech.speaking and coach.speech.player == null, "F1 conserve le silence")
		portrait.set_reduced_motion(false)
		portrait._play_idle()
		var first := pose(skeleton)
		player.advance(0.45)
		check(pose(skeleton) != first and player.is_playing(), "Repos animé sur le modèle réel")
		portrait.set_reduced_motion(true)
		var stopped := pose(skeleton)
		await create_timer(0.25).timeout
		check(not player.is_playing() and pose(skeleton) == stopped, "Mouvements réduits : pose réellement fixe")
		portrait.set_reduced_motion(false)
		portrait.hide()
		check(not player.is_playing() and not portrait.is_processing(), "Portrait masqué suspendu")
		portrait.show()
		check(player.current_animation == "Repos", "Portrait réaffiché au repos")
		for clip in ["Repos", "Salut", "RegardCarnet"]:
			portrait._play_gesture(clip)
			await create_timer(0.25).timeout
			player.seek(player.get_animation(clip).length * 0.45, true)
			player.pause()
			if DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				var file := OS.get_environment("CD_GABI_REAL_OUTPUT").path_join("gabi-%s-%s.png" % [dimensions.x, clip])
				check(root.get_texture().get_image().save_png(file) == OK, "Capture : " + file)
				captures.append(file)
	var after := FileAccess.get_sha256(filename) if FileAccess.file_exists(filename) else "absent"
	check(before == after, "Le guide ne modifie pas le profil sportif")
	var report := FileAccess.open(OS.get_environment("CD_GABI_REAL_OUTPUT").path_join("report.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failures":failures,"display":DisplayServer.get_name(),"captures":captures}, "  "))
	report.close()
	print("GABI MODÈLE RÉEL : %d contrôles ; %d échecs" % [checks, failures.size()])
	await app._close(0 if failures.is_empty() else 1)

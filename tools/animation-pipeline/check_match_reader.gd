extends SceneTree
## Exécute le vrai lecteur sans modifier modèle, runtime, règles ou sauvegarde.
## Depuis la racine : godot --headless --path native/godot --script ../../tools/animation-pipeline/check_match_reader.gd
## CD_ANIMATION_READER_RESULTS choisit un NOUVEAU fichier JSON de preuve ; aucun écrasement.

var failures: Array[String] = []
var passed := 0
var metrics: Dictionary = {}

func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
	else:
		failures.append(label)
		printerr("FAIL: ", label)

func _initialize() -> void:
	call_deferred("run")

func fixture(paused: bool = false) -> Dictionary:
	return {"paused": paused, "scene": {"key": "animation-reader-probe", "kind": "message", "players": [
		{"id": "probe-a", "side": 0, "x": 50.0, "y": 35.0},
		{"id": "probe-b", "side": 1, "x": 51.0, "y": 35.0}], "ball": {}}}

func poses(rig: Skeleton3D) -> Array[Transform3D]:
	var result: Array[Transform3D] = []
	for index in rig.get_bone_count():
		result.append(rig.get_bone_pose(index))
	return result

func same_poses(rig: Skeleton3D, before: Array[Transform3D]) -> bool:
	for index in rig.get_bone_count():
		if not rig.get_bone_pose(index).is_equal_approx(before[index]):
			return false
	return true

func finish() -> void:
	var result := {"schema": "oval-animation-reader/v1", "passed": passed, "failures": failures,
		"engine": Engine.get_version_info().string, "display_server": DisplayServer.get_name(), "metrics": metrics,
		"limits": ["Fixtures authored, no sporting causality validated", "No Windows or graphical performance reception", "Only staged athlete checked; its hash identifies the tested asset, not an acceptance for distribution"]}
	var output := OS.get_environment("CD_ANIMATION_READER_RESULTS")
	if output.is_empty():
		output = ProjectSettings.globalize_path("res://../../tools/animation-pipeline/reader-results.json")
	output = output.simplify_path()
	# Proof output must never overwrite an input, runtime file or earlier proof.
	# The extension check also prevents accidentally treating a GLB/script as JSON.
	if not output.is_absolute_path() or output.get_extension().to_lower() != "json" or FileAccess.file_exists(output) or DirAccess.dir_exists_absolute(output):
		printerr("Reader results require a new absolute .json path: ", output)
		quit(1)
		return
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		printerr("Could not write reader results: ", output)
		quit(1)
		return
	file.store_string(JSON.stringify(result, "\t") + "\n")
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		printerr("Could not flush reader results: ", output, " error=", write_error)
		quit(1)
		return
	print("ANIMATION_READER_CHECKS ", JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)

func run() -> void:
	var source := "res://assets/match3d/quaternius-rugby-athlete.glb"
	metrics.loaded_asset_sha256 = FileAccess.get_sha256(ProjectSettings.globalize_path(source))
	check(ResourceLoader.exists(source), "Existing athlete imported and available")
	var import_config := ConfigFile.new()
	var import_ok := import_config.load(source + ".import") == OK
	var imported_path: String = str(import_config.get_value("remap", "path", "")) if import_ok else ""
	var md5_path := imported_path.get_basename() + ".md5"
	var cache_values: Dictionary = {}
	if import_ok and FileAccess.file_exists(md5_path):
		for line in FileAccess.get_file_as_string(md5_path).split("\n"):
			var parts := line.split("=", true, 1)
			if parts.size() == 2:
				cache_values[parts[0].strip_edges()] = parts[1].strip_edges().trim_prefix("\"").trim_suffix("\"")
	check(cache_values.get("source_md5", "") == FileAccess.get_md5(source), "Import cache matches staged GLB content")
	check(not imported_path.is_empty() and cache_values.get("dest_md5", "") == FileAccess.get_md5(imported_path), "Imported scene cache is intact")
	if not failures.is_empty():
		finish()
		return
	var view = load("res://match_view.gd").new()
	root.add_child(view)
	await process_frame
	view.set_process(false)
	var initial := fixture()
	var original := initial.duplicate(true)
	view.apply_frame(initial)
	view._process(0.0)
	check(initial == original, "Reader preserves input fixture")
	var a: Dictionary = view._actors["probe-a"]
	var b: Dictionary = view._actors["probe-b"]
	var rig: Skeleton3D = a.rig
	var player: AnimationPlayer = a.animation
	check(rig != null and player != null, "Real reader constructs skeleton and animation player")
	if rig == null or player == null:
		view.queue_free()
		finish()
		return
	check(rig.get_bone_count() == 31, "Existing skeleton retains 31 bones")
	check(player.get_animation_list().size() == 11, "Existing animation player retains 11 clips")
	check(player.callback_mode_process == AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL, "Reader owns animation advancement")
	metrics.bones = rig.get_bone_count()
	metrics.clips = []
	for name in player.get_animation_list():
		var clip := player.get_animation(name)
		check(clip.length > 0.0, "Nonempty duration: " + str(name))
		metrics.clips.append({"name": name, "length_seconds": clip.length, "tracks": clip.get_track_count(), "loop_mode": clip.loop_mode})
		player.play(name)
		for fraction in [0.0, 0.25, 0.75, 1.0]:
			player.seek(clip.length * fraction, true)
			var finite := true
			for index in rig.get_bone_count():
				finite = finite and rig.get_bone_global_pose(index).is_finite()
			check(finite, "Finite actual sampled bones: %s @ %.2f" % [name, fraction])
	for key in ["idle", "walk", "run"]:
		var name: StringName = a[key]
		check(not name.is_empty() and player.has_animation(name), "Reader resolves locomotion clip: " + key)
		if name.is_empty() or not player.has_animation(name):
			continue
		var clip := player.get_animation(name)
		check(clip.loop_mode == Animation.LOOP_LINEAR, "Locomotion clip loops: " + key)
		player.play(name)
		player.seek(0.0, true)
		player.advance(clip.length + 0.125)
		check(absf(player.current_animation_position - 0.125) < 0.0001, "Loop wraps time after one complete period: " + key)
	# A normal scene-tree frame must not advance the frame-owned player by itself.
	player.play(a.idle)
	player.seek(0.3, true)
	var manual_time := player.current_animation_position
	await process_frame
	check(is_equal_approx(manual_time, player.current_animation_position), "Scene-tree tick does not advance manual player")
	# Exercise actual pause route after one settling step, including all local bones.
	view.apply_frame(fixture(true))
	view._process(1.0 / 60.0)
	var paused_time := player.current_animation_position
	var paused_poses := poses(rig)
	var paused_root: Transform3D = a.node.transform
	for frame in 120:
		view._process(1.0 / 60.0)
	check(is_equal_approx(paused_time, player.current_animation_position), "Pause freezes exact clip time over 120 reader steps")
	check(same_poses(rig, paused_poses), "Pause preserves all 31 local bone poses")
	check((a.node.transform as Transform3D).is_equal_approx(paused_root), "Pause preserves actor root")
	metrics.pause_clip_time = paused_time
	# Restore the actual contact helper's touched bones, rather than inspect source text.
	var presentation = load("res://match_presentation.gd")
	var base: Dictionary = {}
	var before := poses(rig)
	presentation.brace_contact(a.node, rig, b.node, b.rig, 1.0, false, base)
	check(base.size() > 0 and not same_poses(rig, before), "Contact helper changes real bones and records their source rotations")
	metrics.contact_restored_bones = base.size()
	presentation.restore_contact(rig, base)
	check(base.is_empty() and same_poses(rig, before), "Contact restore returns exact source poses and clears its buffer")
	# Production preparation/dressing has run in _make_actor; compare actual shared mesh.
	var mesh_a: MeshInstance3D = a.model.find_children("*", "MeshInstance3D", true, false)[0]
	var mesh_b: MeshInstance3D = b.model.find_children("*", "MeshInstance3D", true, false)[0]
	check(mesh_a.mesh == mesh_b.mesh, "Production athlete preparation shares the mesh between two actors")
	check(mesh_a.mesh.get_surface_count() == 1 and mesh_a.mesh.resource_name == "AthleteRugbyOriginal", "Production prepare accepts all original surface regions")
	check(mesh_a.material_override is ShaderMaterial and mesh_b.material_override is ShaderMaterial, "Production dressing applies real ShaderMaterials")
	view.queue_free()
	await process_frame
	finish()

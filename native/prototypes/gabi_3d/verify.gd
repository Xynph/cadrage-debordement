extends SceneTree

const SCENE := preload("res://gabi_lab.tscn")
const IDLE := &"Repos"
const APPROVAL := &"Approbation"
const SPEECH := &"Parole"

var checks: Array[Dictionary] = []
var capture_dir := ""
var lab: Node3D


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			capture_dir = arg.trim_prefix("--capture-dir=")
	_run.call_deferred()


func _run() -> void:
	lab = SCENE.instantiate()
	root.add_child(lab)
	await process_frame
	var player: AnimationPlayer = lab.animations
	var skeleton := lab.get_node("Gabi").find_child("Skeleton3D", true, false) as Skeleton3D
	_check(skeleton != null and skeleton.get_bone_count() == 20, "20 os importés")
	var skinned := _find_skinned_mesh(lab.get_node("Gabi"))
	_check(skinned != null and skinned.skin != null, "maillage réellement lié au squelette")
	_check(player != null, "AnimationPlayer importé")
	if skeleton == null or player == null:
		_finish()
		return
	for name: StringName in [IDLE, APPROVAL, SPEECH]:
		_check(player.has_animation(name), "clip importé " + name)
		if not player.has_animation(name):
			_finish()
			return
	var head := skeleton.find_bone("Head")
	var hand := skeleton.find_bone("Hand.R")
	for eye_name: String in ["Globe_L", "Globe_R"]:
		var eye := lab.get_node("Gabi").find_child(eye_name, true, false) as MeshInstance3D
		_check(eye != null and eye.skin != null and eye.mesh.get_surface_count() >= 4,
			"globe géométrique importé " + eye_name)
	_check(head >= 0 and hand >= 0, "os du visage et de la main identifiables")
	if head < 0 or hand < 0:
		_finish()
		return
	_check(lab.current_clip == IDLE and player.get_animation(IDLE).loop_mode == Animation.LOOP_LINEAR,
		"repos bouclé au démarrage")
	_check(not lab.voice.playing, "aucune voix automatique au démarrage")
	player.seek(0.0, true)
	var head_at_start := skeleton.get_bone_global_pose(head)
	var hand_at_start := skeleton.get_bone_global_pose(hand)
	player.seek(player.current_animation_length - 0.001, true)
	_check(skeleton.get_bone_global_pose(head).is_equal_approx(head_at_start)
		and skeleton.get_bone_global_pose(hand).is_equal_approx(hand_at_start),
		"jonction de boucle sans saut")
	await _capture("01-repos")
	lab.clip_buttons[APPROVAL].pressed.emit()
	player.seek(0.79, true)
	_check(lab.current_clip == APPROVAL and lab.clip_buttons[APPROVAL].button_pressed, "bouton Approbation")
	_check(skeleton.get_bone_global_pose(hand).origin.distance_to(hand_at_start.origin) > 0.16,
		"geste réel de la main")
	_check(skeleton.get_bone_global_pose(head).basis.get_rotation_quaternion().angle_to(
		head_at_start.basis.get_rotation_quaternion()) > deg_to_rad(5), "hochement réel")
	await _capture("02-approbation")
	player.advance(2.5)
	_check(lab.current_clip == IDLE, "retour au repos après l’approbation")
	lab.view_buttons[&"portrait"].pressed.emit()
	_check(lab.portrait and lab.camera.size < 0.7 and lab.view_buttons[&"portrait"].button_pressed,
		"cadrage Visage")
	await _capture("03-visage")
	lab.view_buttons[&"profil"].pressed.emit()
	_check(lab.portrait and lab.azimuth == -90 and lab.view_buttons[&"profil"].button_pressed,
		"cadrage Profil et état sélectionné")
	await _capture("04-profil")
	lab.view_buttons[&"ensemble"].pressed.emit()
	_check(not lab.portrait and lab.camera.size > 2.0, "retour En pied")
	lab.clip_buttons[SPEECH].pressed.emit()
	_check(lab.current_clip == SPEECH and lab.voice.playing, "parole déclenche le clip vocal")
	_check(absf(lab.voice.stream.get_length() - 1.875) < 0.005, "durée de la voix source conservée")
	_check(lab.caption.text == "« Continue à construire. »" and "sans synchronisation" in lab.feedback.text,
		"réplique affichée et absence de synchronisation signalée")
	player.seek(0.70, true)
	_check(skeleton.get_bone_global_pose(hand).origin.distance_to(hand_at_start.origin) > 0.06,
		"geste distinct pendant la parole")
	await _capture("05-parole")
	lab.clip_buttons[IDLE].pressed.emit()
	_check(not lab.voice.playing and lab.caption.text.is_empty(), "interrompre la parole arrête voix et réplique")
	lab.clip_buttons[SPEECH].pressed.emit()
	player.advance(2.5)
	_check(lab.current_clip == IDLE and not lab.voice.playing, "fin de parole ramène au repos")
	var rotate_key := InputEventKey.new()
	rotate_key.keycode = KEY_RIGHT
	rotate_key.pressed = true
	Input.parse_input_event(rotate_key)
	await process_frame
	_check(lab.azimuth == -4.0, "rotation clavier")
	_finish()


func _find_skinned_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D and node.skin != null:
		return node
	for child: Node in node.get_children():
		var mesh := _find_skinned_mesh(child)
		if mesh != null:
			return mesh
	return null


func _capture(name: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := capture_dir.path_join(name + ".png")
	_check(image != null and image.save_png(path) == OK, "capture " + name)


func _check(ok: bool, label: String) -> void:
	checks.append({"ok": ok, "controle": label})


func _finish() -> void:
	var errors := checks.filter(func(row: Dictionary) -> bool: return not row.ok)
	var report := {"controles": checks.size(), "echecs": errors.size(),
		"mode": DisplayServer.get_name(), "taille": str(root.size), "resultats": checks}
	var json := JSON.stringify(report, "\t")
	print(json)
	if not capture_dir.is_empty():
		var file := FileAccess.open(capture_dir.path_join("recette-godot.json"), FileAccess.WRITE)
		if file != null:
			file.store_string(json)
	if is_instance_valid(lab):
		lab.queue_free()
	await process_frame
	await process_frame
	quit(0 if errors.is_empty() else 1)

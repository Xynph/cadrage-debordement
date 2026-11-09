extends SceneTree


func _initialize() -> void:
	for clip_name in ["celebration_authored", "celebration_retargeted_clean", "celebration_retargeted_noisy"]:
		if not _validate_clip(clip_name):
			quit(1)
			return
	quit()


func _validate_clip(clip_name: String) -> bool:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var read_error := document.append_from_file("res://%s.glb" % clip_name, state)
	if read_error != OK:
		push_error("Échec de la lecture du GLB %s (%s)" % [clip_name, error_string(read_error)])
		return false
	var scene := document.generate_scene(state)
	if scene == null:
		push_error("Aucune scène produite pour %s" % clip_name)
		return false
	var players := scene.find_children("*", "AnimationPlayer", true, false)
	var skeletons := scene.find_children("*", "Skeleton3D", true, false)
	if players.size() != 1 or skeletons.size() != 1:
		push_error("Le clip %s doit avoir un lecteur d’animations et un squelette" % clip_name)
		scene.free()
		return false
	var player := players[0] as AnimationPlayer
	var skeleton := skeletons[0] as Skeleton3D
	var valid := player.has_animation(clip_name) and is_equal_approx(player.get_animation(clip_name).length, 2.0) and skeleton.get_bone_count() == 22
	if valid:
		print("%s — clip de 2 s, 22 os" % clip_name)
	else:
		push_error("Animation ou squelette invalide pour %s" % clip_name)
	scene.free()
	return valid

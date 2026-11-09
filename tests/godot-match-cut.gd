extends SceneTree

const Presentation = preload("res://match_presentation.gd")
const ATHLETE = preload("res://assets/match3d/quaternius-rugby-athlete.glb")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		printerr("FAIL: ", message)

func foot_position(rig: Skeleton3D, side: String) -> Vector3:
	return rig.to_global(rig.get_bone_global_pose(rig.find_bone("Foot." + side)).origin)

func run() -> void:
	var cut = load("res://match_cut.gd")
	if cut == null:
		check(false, "Couche du crochet disponible")
		quit(1)
		return
	var incoming := Vector3(0, 0, 4)
	check(cut.direction(incoming, Vector3(1.4, 0, 1.8), 0.55) == 1, "Crochet vers +X")
	check(cut.direction(incoming, Vector3(-1.4, 0, 1.8), 0.55) == -1, "Crochet vers -X")
	check(cut.direction(incoming, Vector3(0, 0, 1.8), 0.55) == 0, "Course droite")
	check(cut.direction(incoming, Vector3(0, 0, -1.8), 0.55) == 0, "Demi-tour exclu")
	check(cut.direction(incoming, Vector3(12, 0, 16), 0.55) == 0, "Repositionnement lointain exclu")
	check(cut.direction(Vector3.ZERO, Vector3(1.4, 0, 1.8), 0.55) == 0, "Aucun crochet sans course préalable")
	check(cut.direction(incoming, Vector3(1.4, 0, 1.8), 0.0) == 0, "Durée nulle exclue")

	var actor := Node3D.new()
	root.add_child(actor)
	var model: Node3D = ATHLETE.instantiate()
	actor.add_child(model)
	var rig := Presentation.rig_for(model)
	check(rig != null and rig.get_bone_count() == 31, "Squelette du GLB d’origine")
	if rig == null:
		quit(1)
		return
	var animation := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for clip: StringName in animation.get_animation_list():
		if str(clip).ends_with("Man_Run"):
			animation.play(clip)
			animation.advance(0.24)
			break
	check(str(animation.current_animation).ends_with("Man_Run"), "Course d’origine utilisée comme base")
	var torso := rig.find_bone("Torso")
	var initial_up := rig.get_bone_global_pose(torso).basis.y.normalized()
	var right := (rig.global_basis.inverse() * actor.global_basis.x).normalized()
	var initial_root := actor.global_transform
	var initial_anchor := Presentation.ball_anchor(actor, rig)
	var saved := {}
	var plant := {}
	cut.apply(actor, rig, 1, 0.35, saved, plant)
	var positive := (rig.get_bone_global_pose(torso).basis.y.normalized() - initial_up).dot(right)
	check(positive > 0.025, "Inclinaison visible du buste dans le premier sens")
	check(actor.global_transform.is_equal_approx(initial_root), "La racine sportive conserve son transform")
	check(Presentation.ball_anchor(actor, rig).is_equal_approx(initial_anchor), "Le centre de tenue du ballon reste fixe")
	cut.restore(rig, saved)
	check(rig.get_bone_global_pose(torso).basis.y.normalized().is_equal_approx(initial_up), "La pose de course est restaurée")
	plant.clear()
	cut.apply(actor, rig, -1, 0.35, saved, plant)
	var negative := (rig.get_bone_global_pose(torso).basis.y.normalized() - initial_up).dot(right)
	check(negative < -0.025, "Inclinaison dans le sens opposé")
	cut.restore(rig, saved)
	cut.apply(actor, rig, -1, 1.0, saved, plant)
	check(saved.is_empty() and rig.get_bone_global_pose(torso).basis.y.normalized().is_equal_approx(initial_up), "Fondu terminé sur la course")

	actor.position.y += 0.03 - foot_position(rig, "R").y
	var anchored := foot_position(rig, "R")
	plant.clear()
	cut.apply(actor, rig, 1, 0.25, saved, plant)
	cut.restore(rig, saved)
	actor.position.x += 0.045
	cut.apply(actor, rig, 1, 0.28, saved, plant)
	var slip := foot_position(rig, "R").distance_to(anchored)
	check(slip < 0.018, "Le pied extérieur reste planté sur un déplacement court")
	cut.restore(rig, saved)
	actor.position.x += 0.15
	var uncorrected := foot_position(rig, "R")
	cut.apply(actor, rig, 1, 0.30, saved, plant)
	check(foot_position(rig, "R").distance_to(uncorrected) < 0.01, "L’appui s’efface avant le seuil de relâchement")
	cut.restore(rig, saved)
	actor.position.x += 0.01
	cut.apply(actor, rig, 1, 0.30, saved, plant)
	check(not plant.has("world"), "L’appui est relâché plutôt que de tirer le joueur")
	cut.restore(rig, saved)
	cut.apply(actor, rig, 0, 0.3, saved, plant)
	check(saved.is_empty(), "Désactiver le crochet retire ses modifications")
	print("MATCH_CUT_CHECKS ", JSON.stringify({"failures": failures, "slip_m": slip, "positive_lean": positive, "negative_lean": negative}))
	actor.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

extends RefCounted
## Un crochet de présentation sur le clip de course. La trajectoire du moteur,
## l’orientation de la racine et le point d’attache du ballon restent inchangés.

const Presentation = preload("res://match_presentation.gd")

static func direction(incoming: Vector3, displacement: Vector3, duration: float) -> int:
	if duration <= 0.0 or not is_finite(duration) or not incoming.is_finite() or not displacement.is_finite():
		return 0
	incoming.y = 0.0
	displacement.y = 0.0
	var incoming_speed := incoming.length()
	var outgoing_speed := displacement.length() / duration
	# Au-delà de cette plage, le changement ressemble à un nouveau cadrage du jeu.
	if incoming_speed < 1.5 or incoming_speed > 8.0 or outgoing_speed < 1.5 or outgoing_speed > 8.0:
		return 0
	var turn := incoming.signed_angle_to(displacement, Vector3.UP)
	if absf(turn) < deg_to_rad(24.0) or absf(turn) > deg_to_rad(100.0):
		return 0
	return 1 if turn > 0.0 else -1

static func restore(rig: Skeleton3D, saved: Dictionary) -> void:
	for index: int in saved:
		var pose: Array = saved[index]
		rig.set_bone_pose_position(index, pose[0])
		rig.set_bone_pose_rotation(index, pose[1])
	saved.clear()

static func apply(actor: Node3D, rig: Skeleton3D, side: int, progress: float, saved: Dictionary, plant: Dictionary) -> void:
	if side not in [-1, 1] or progress <= 0.04 or progress >= 0.9:
		plant.clear()
		return
	var torso := rig.find_bone("Torso")
	if torso < 0:
		return
	var weight := smoothstep(0.04, 0.22, progress) * (1.0 - smoothstep(0.45, 0.9, progress))
	_save_pose(rig, torso, saved)
	var axis := (rig.global_basis.inverse() * actor.global_basis.z).normalized()
	var tilt := Basis(Quaternion(axis, -float(side) * 0.20 * weight))
	Presentation._orient(rig, torso, tilt * rig.get_bone_global_pose(torso).basis, 1.0)
	# Le pied opposé au virage porte l’appui. Sa position ne touche pas le torse.
	_support(actor, rig, "R" if side > 0 else "L", progress, saved, plant)

static func _support(actor: Node3D, rig: Skeleton3D, side: String, progress: float, saved: Dictionary, plant: Dictionary) -> void:
	if progress < 0.16 or progress >= 0.52 or plant.has("released"):
		return
	var upper := rig.find_bone("UpperLeg." + side)
	var lower := rig.find_bone("LowerLeg." + side)
	var foot := rig.find_bone("Foot." + side)
	if mini(upper, mini(lower, foot)) < 0:
		return
	var source := rig.to_global(rig.get_bone_global_pose(foot).origin)
	if not plant.has("world"):
		if source.y < -0.025 or source.y > 0.075:
			return
		plant.world = source
	var offset: Vector3 = plant.world - source
	var distance := offset.length()
	if distance >= 0.20:
		plant.clear()
		plant.released = true
		return
	var weight := smoothstep(0.16, 0.23, progress) * (1.0 - smoothstep(0.37, 0.52, progress))
	weight *= 1.0 - smoothstep(0.12, 0.20, distance)
	if weight <= 0.0:
		return
	for index in [upper, lower, foot]:
		_save_pose(rig, index, saved)
	Presentation._solve_leg(rig, side, source + offset * weight, actor.global_basis.z)

static func _save_pose(rig: Skeleton3D, index: int, saved: Dictionary) -> void:
	saved[index] = [rig.get_bone_pose_position(index), rig.get_bone_pose_rotation(index)]

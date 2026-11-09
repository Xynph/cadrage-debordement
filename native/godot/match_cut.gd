extends RefCounted
## Pose de crochet et répartition du déplacement visuel sur le même trajet.

const Presentation = preload("res://match_presentation.gd")
const LIVE_PLANT_START := 0.145
const LIVE_PLANT_END := 0.345
const LIVE_REJOIN := 0.54
const LIVE_PLANT_POSITION := 0.225

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

static func live_travel(progress: float) -> float:
	# Freinage, appui puis reprise de la courbe originale avec la même vitesse.
	# Ces deux segments cubiques ont une pente nulle de part et d’autre de l’appui.
	if progress < LIVE_PLANT_START:
		var t := progress / LIVE_PLANT_START
		return LIVE_PLANT_POSITION * smoothstep(0.0, 1.0, t) + LIVE_PLANT_START * t * (1.0 - t) * (1.0 - t)
	if progress < LIVE_PLANT_END:
		return LIVE_PLANT_POSITION
	if progress < LIVE_REJOIN:
		var t := inverse_lerp(LIVE_PLANT_END, LIVE_REJOIN, progress)
		return lerpf(LIVE_PLANT_POSITION, LIVE_REJOIN, smoothstep(0.0, 1.0, t)) - (LIVE_REJOIN - LIVE_PLANT_END) * t * t * (1.0 - t)
	return progress

static func apply(actor: Node3D, rig: Skeleton3D, side: int, progress: float, saved: Dictionary, plant: Dictionary) -> void:
	if side not in [-1, 1] or progress <= 0.04 or progress >= 0.9:
		plant.clear()
		return
	var weight := smoothstep(0.04, 0.22, progress) * (1.0 - smoothstep(0.45, 0.9, progress))
	_lean(actor, rig, side, 0.20 * weight, saved)
	# Le pied opposé au virage porte l’appui. Sa position ne touche pas le torse.
	_support(actor, rig, "R" if side > 0 else "L", progress, saved, plant)

static func apply_live(actor: Node3D, rig: Skeleton3D, side: int, progress: float, saved: Dictionary, plant: Dictionary) -> void:
	if side not in [-1, 1] or progress <= 0.04 or progress >= 0.9:
		plant.clear()
		return
	var weight := smoothstep(0.04, 0.28, progress) * (1.0 - smoothstep(0.60, 0.90, progress))
	_lean(actor, rig, side, 0.29 * weight, saved)

	# Le poids quitte la jambe avant que la racine reprenne son déplacement.
	var support := smoothstep(0.26, 0.32, progress) * (1.0 - smoothstep(0.56, 0.63, progress))
	if support <= 0.0:
		return
	var side_name := "R" if side > 0 else "L"
	var upper := rig.find_bone("UpperLeg." + side_name)
	var lower := rig.find_bone("LowerLeg." + side_name)
	var foot := rig.find_bone("Foot." + side_name)
	if mini(upper, mini(lower, foot)) < 0:
		return
	if not plant.has("world"):
		var hip := rig.to_global(rig.get_bone_global_pose(upper).origin)
		var outward := actor.global_basis.x.normalized() * float(side) * 0.13
		var forward := actor.global_basis.z.normalized() * 0.12
		plant.world = Vector3(hip.x, 0.045, hip.z) + outward + forward
	for index in [upper, lower, foot]:
		_save_pose(rig, index, saved)
	var source := rig.to_global(rig.get_bone_global_pose(foot).origin)
	Presentation._solve_leg(rig, side_name, source.lerp(plant.world, support), actor.global_basis.z)

static func _lean(actor: Node3D, rig: Skeleton3D, side: int, angle: float, saved: Dictionary) -> void:
	var torso := rig.find_bone("Torso")
	if torso < 0:
		return
	_save_pose(rig, torso, saved)
	var axis := (rig.global_basis.inverse() * actor.global_basis.z).normalized()
	var tilt := Basis(Quaternion(axis, -float(side) * angle))
	Presentation._orient(rig, torso, tilt * rig.get_bone_global_pose(torso).basis, 1.0)

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

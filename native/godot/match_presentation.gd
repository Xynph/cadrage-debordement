extends RefCounted
## Purely visual pose layer over the licensed athlete. No sporting decisions.
## The two-bone solver preserves the imported limb lengths; unreachable targets
## are clamped, never stretched. Source locomotion supplies the swing phases;
## short ground-support locks reduce visible skating without moving any actor.

static func rig_for(model: Node3D) -> Skeleton3D:
	for child in model.find_children("*", "Skeleton3D", true, false):
		return child as Skeleton3D
	return null

static func carrier_id(scene: Dictionary) -> String:
	if str(scene.get("kind", "")) not in ["carry", "reception", "turnover", "setpiece-win", "setpiece-loss"]:
		return ""
	for player: Dictionary in scene.get("players", []):
		if player.get("featured", false) and int(player.get("side", -1)) == int(scene.get("possession", -2)):
			return str(player.get("id", ""))
	return ""

static func ball_anchor(actor: Node3D, rig: Skeleton3D) -> Vector3:
	var torso := rig.find_bone("Torso")
	var chest := rig.to_global(rig.get_bone_global_pose(torso).origin)
	# Forward is +Z in the original CC0 athlete. Close two-handed protection.
	return chest + actor.global_basis * Vector3(0.0, -0.015, 0.29)

static func hold_ball(actor: Node3D, rig: Skeleton3D, center: Vector3, weight: float) -> void:
	for side in ["L", "R"]:
		var sign_ := 1.0 if side == "L" else -1.0
		var hand := center + actor.global_basis * Vector3(sign_ * 0.21, -0.045, 0.015)
		var pole := actor.global_basis * Vector3(sign_ * 0.7, -0.8, -0.15)
		_solve_arm(rig, side, hand, pole, weight)
		var palm := rig.find_bone("Palm." + side)
		var middle := rig.find_bone("MiddleHand." + side)
		var pose := rig.get_bone_global_pose(palm)
		var direction := (rig.get_bone_global_pose(middle).origin - pose.origin).normalized()
		var tangent := rig.global_basis.inverse() * actor.global_basis * Vector3(-sign_ * 0.6, 0.25, 0.8).normalized()
		_orient(rig, palm, Basis(Quaternion(direction, tangent.normalized())) * pose.basis, weight)

static func support_feet(actor: Node3D, rig: Skeleton3D, feet: Dictionary, speed: float, turn: float) -> void:
	# A distant scene reformation is not a plausible stride. Never pin a leg
	# across a sharp pivot or a long root translation, and never move the root.
	if speed > 8.0 or absf(turn) > 0.055:
		feet.clear()
		return
	if not feet.has("source"):
		feet.source = {}
	for side in ["L", "R"]:
		var foot := rig.find_bone("Foot." + side)
		if foot < 0:
			continue
		var source := rig.to_global(rig.get_bone_global_pose(foot).origin)
		var relative := actor.to_local(source)
		var previous: Vector3 = feet.source.get(side, relative)
		feet.source[side] = relative
		if source.y > 0.15:
			feet.erase(side)
			continue
		if not feet.has(side):
			# A low foot can still be swinging forwards just before heel strike.
			# Pin only its rearward support phase, never that incoming swing.
			if source.y > 0.065 or relative.z > previous.z + 0.0001:
				continue
			feet[side] = Vector3(source.x, 0.025, source.z)
		var anchor: Vector3 = feet[side]
		var correction := anchor - source
		# Keep corrections small relative to the imported athlete's limb length.
		var weight := 1.0 - smoothstep(0.065, 0.15, source.y)
		var target := source + correction.limit_length(0.24) * weight
		_solve_leg(rig, side, target, actor.global_basis * Vector3(0, 0, 1))

static func _solve_leg(rig: Skeleton3D, side: String, target_world: Vector3, pole_world: Vector3) -> void:
	var upper := rig.find_bone("UpperLeg." + side)
	var lower := rig.find_bone("LowerLeg." + side)
	var foot := rig.find_bone("Foot." + side)
	if mini(upper, mini(lower, foot)) < 0:
		return
	var a := rig.get_bone_global_pose(upper)
	var b := rig.get_bone_global_pose(lower)
	var c := rig.get_bone_global_pose(foot)
	var first := a.origin.distance_to(b.origin)
	var second := b.origin.distance_to(c.origin)
	var delta := rig.to_local(target_world) - a.origin
	var distance := clampf(delta.length(), absf(first - second) + 0.00001, (first + second) * 0.998)
	var axis := delta.normalized()
	# Retain the authored bend plane instead of snapping knees to a new pole.
	var pole := b.origin - a.origin
	var bend := pole - axis * pole.dot(axis)
	if bend.length_squared() < 0.000000001:
		pole = rig.global_basis.inverse() * pole_world
		bend = pole - axis * pole.dot(axis)
	var along := (first * first - second * second + distance * distance) / (2.0 * distance)
	var height := sqrt(maxf(0.0, first * first - along * along))
	var knee := a.origin + axis * along + bend.normalized() * height
	var turn := Quaternion((b.origin - a.origin).normalized(), (knee - a.origin).normalized())
	_orient(rig, upper, Basis(turn) * a.basis, 1.0)
	var corrected_knee := rig.get_bone_global_pose(lower).origin
	var target := a.origin + axis * distance
	turn = Quaternion((c.origin - b.origin).normalized(), (target - corrected_knee).normalized())
	_orient(rig, lower, Basis(turn) * b.basis, 1.0)
	# The source asset's foot controls are children of Bone, not LowerLeg.
	# Reposition those controls at the solved ankle; both segment lengths hold.
	var parent := rig.get_bone_parent(foot)
	var local := rig.get_bone_global_pose(parent).affine_inverse() * target if parent >= 0 else target
	rig.set_bone_pose_position(foot, local)

static func _orient(rig: Skeleton3D, index: int, target_basis: Basis, weight: float) -> void:
	var parent := rig.get_bone_parent(index)
	var parent_basis := rig.get_bone_global_pose(parent).basis if parent >= 0 else Basis.IDENTITY
	var local := (parent_basis.inverse() * target_basis).orthonormalized().get_rotation_quaternion()
	rig.set_bone_pose_rotation(index, rig.get_bone_pose_rotation(index).slerp(local, weight))

static func _solve_arm(rig: Skeleton3D, side: String, target_world: Vector3, pole_world: Vector3, weight: float) -> void:
	var upper := rig.find_bone("UpperArm." + side)
	var lower := rig.find_bone("LowerArm." + side)
	var palm := rig.find_bone("Palm." + side)
	if mini(upper, mini(lower, palm)) < 0: return
	var a := rig.get_bone_global_pose(upper)
	var b := rig.get_bone_global_pose(lower)
	var c := rig.get_bone_global_pose(palm)
	var first := a.origin.distance_to(b.origin)
	var second := b.origin.distance_to(c.origin)
	var delta := rig.to_local(target_world) - a.origin
	var distance := clampf(delta.length(), absf(first - second) + 0.00001, (first + second) * 0.98)
	var axis := delta.normalized()
	var pole := rig.global_basis.inverse() * pole_world
	var bend := (pole - axis * pole.dot(axis)).normalized()
	var along := (first * first - second * second + distance * distance) / (2.0 * distance)
	var height := sqrt(maxf(0.0, first * first - along * along))
	var elbow := a.origin + axis * along + bend * height
	var turn := Quaternion((b.origin - a.origin).normalized(), (elbow - a.origin).normalized())
	_orient(rig, upper, Basis(turn) * a.basis, weight)
	b = rig.get_bone_global_pose(lower)
	c = rig.get_bone_global_pose(palm)
	turn = Quaternion((c.origin - b.origin).normalized(), (rig.to_local(target_world) - b.origin).normalized())
	_orient(rig, lower, Basis(turn) * b.basis, weight)

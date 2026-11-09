extends RefCounted
## Chorégraphie de présentation sur une passe explicitement identifiée.
## Le journal courant ne transmet pas encore ces deux participants.

const Presentation = preload("res://match_presentation.gd")
const RELEASE := 0.28
const CATCH := 0.76
const MIN_SPAN := 0.60


static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


static func plan(scene: Dictionary) -> Dictionary:
	var key: Variant = scene.get("key")
	var transfer: Variant = scene.get("pass")
	var ball: Variant = scene.get("ball")
	var team: Variant = scene.get("possession")
	var players: Variant = scene.get("players")
	if scene.get("kind") != "pass" or not key is String or key.strip_edges().is_empty():
		return {}
	if not transfer is Dictionary or not players is Array or not _number(team) or team not in [0, 1]:
		return {}
	if not ball is Dictionary or not _number(ball.get("x")) or not _number(ball.get("y")):
		return {}
	if ball.x < 0.0 or ball.x > 100.0 or ball.y < 0.0 or ball.y > 70.0:
		return {}
	var sender: Variant = transfer.get("fromId")
	var receiver: Variant = transfer.get("toId")
	if not sender is String or not receiver is String or sender.is_empty() or receiver.is_empty() or sender == receiver:
		return {}
	var present := {}
	for player in players:
		if not player is Dictionary or player.get("id") not in [sender, receiver]:
			continue
		var id: String = player.id
		var side: Variant = player.get("side")
		if present.has(id) or not _number(side) or side != team:
			return {}
		present[id] = true
	if present.size() != 2:
		return {}
	return {"key": key, "passer": sender, "receiver": receiver}


static func sample(progress: float, passer_anchor: Vector3, receiver_anchor: Vector3) -> Dictionary:
	if not is_finite(progress) or not passer_anchor.is_finite() or not receiver_anchor.is_finite():
		return {}
	var span := receiver_anchor - passer_anchor
	var distance := span.length()
	if not is_finite(distance) or distance < MIN_SPAN:
		return {}
	var t := clampf(progress, 0.0, 1.0)
	var direction := span / distance
	var release_point := passer_anchor + direction * 0.20 + Vector3.UP * 0.06
	var catch_point := receiver_anchor - direction * 0.18 + Vector3.UP * 0.03
	var stage := "held"
	var ball := passer_anchor.lerp(release_point, smoothstep(0.0, RELEASE, t))
	if t >= CATCH:
		stage = "received"
		ball = catch_point.lerp(receiver_anchor, smoothstep(CATCH, 1.0, t))
	elif t > RELEASE:
		stage = "flight"
		var flight := inverse_lerp(RELEASE, CATCH, t)
		ball = release_point.lerp(catch_point, flight)
		ball.y += sin(flight * PI) * minf(distance * 0.09, 0.32)
	return {
		"stage": stage, "ball": ball,
		"passer_target": ball if stage == "held" else release_point,
		"passer_weight": 1.0 - smoothstep(RELEASE, 0.54, t),
		"receiver_target": ball if stage == "received" else catch_point,
		"receiver_weight": smoothstep(0.46, CATCH, t),
	}


static func pose(actor: Node3D, rig: Skeleton3D, target: Vector3, weight: float, base: Dictionary) -> void:
	if not is_instance_valid(actor) or not is_instance_valid(rig) or not target.is_finite() or not is_finite(weight) or weight <= 0.0:
		return
	var changed: Array[int] = []
	for side in ["L", "R"]:
		if rig.find_bone("MiddleHand." + side) < 0:
			return
		for part in ["UpperArm.", "LowerArm.", "Palm."]:
			var bone := rig.find_bone(part + side)
			if bone < 0:
				return
			changed.append(bone)
	# Restauré par le propriétaire de la pose avant la prochaine animation.
	for bone in changed:
		if not base.has(bone):
			base[bone] = rig.get_bone_pose_rotation(bone)
	Presentation.hold_ball(actor, rig, target, minf(weight, 1.0))

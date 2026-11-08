extends SceneTree
## Les fixtures distinguent proximité géométrique et décision de plaquage.
var failures: Array[String] = []
var metrics := {}

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		printerr("FAIL: ", message)

func _initialize() -> void:
	call_deferred("run")

func fixture(distance: float = 0.95, kind: String = "carry") -> Dictionary:
	return {"scene": {"key": "contact-fixture", "kind": kind, "possession": 0,
		"players": [{"id": "carrier", "side": 0, "featured": true, "x": 50.0, "y": 35.0},
			{"id": "near", "side": 1, "x": 50.0 + distance, "y": 35.0},
			{"id": "far", "side": 1, "x": 57.0, "y": 38.0}],
		"ball": {"x": 50.0, "y": 35.0}}}

func step(view: Node3D, count: int) -> void:
	for frame in count: view._process(1.0 / 60.0)

func rotations(rig: Skeleton3D) -> Array[Quaternion]:
	var result: Array[Quaternion] = []
	for index in rig.get_bone_count(): result.append(rig.get_bone_pose_rotation(index))
	return result

func segments(rig: Skeleton3D) -> Array[float]:
	var result: Array[float] = []
	for side in ["L", "R"]:
		for chain in [["UpperArm.", "LowerArm.", "Palm."], ["UpperLeg.", "LowerLeg.", "Foot."]]:
			for index in 2:
				var first := rig.find_bone(chain[index] + side)
				var second := rig.find_bone(chain[index + 1] + side)
				result.append(rig.get_bone_global_pose(first).origin.distance_to(rig.get_bone_global_pose(second).origin))
	return result

func run() -> void:
	var source = load("res://match_view.gd")
	var view = source.new()
	var reference = source.new()
	root.add_child(view)
	root.add_child(reference)
	await process_frame
	view.set_process(false)
	reference.set_process(false)
	var close := fixture()
	var original := close.duplicate(true)
	view.apply_frame(close)
	reference.apply_frame(fixture(6.0))
	step(view, 24)
	step(reference, 24)
	var carrier: Dictionary = view._actors.carrier
	var defender: Dictionary = view._actors.near
	var reference_rig: Skeleton3D = reference._actors.carrier.rig
	var torso: int = carrier.rig.find_bone("Torso")
	var lean: float = carrier.rig.get_bone_pose_rotation(torso).angle_to(reference_rig.get_bone_pose_rotation(torso))
	check(lean > 0.035 and lean < 0.28, "Only actual close bodies produce a bounded carrier brace")
	metrics.carrier_lean_rad = lean
	var shoulder: int = defender.rig.find_bone("UpperArm.L")
	check(defender.rig.get_bone_pose_rotation(shoulder).angle_to(reference._actors.near.rig.get_bone_pose_rotation(shoulder)) > 0.035, "The real nearby opponent raises their arms into a guard")
	check(carrier.node.position.is_equal_approx(Vector3.ZERO) and defender.node.position.is_equal_approx(Vector3(0.95, 0, 0)), "Bracing never moves either transmitted root")
	check(close == original, "The complete sporting projection stays immutable")
	var maximum_hand_gap := 0.0
	var opponent_ball_gap := INF
	var largest_length_error := 0.0
	# Repeated UI refreshes keep the same settled stance rather than replaying a hit.
	var settled := rotations(carrier.rig)
	for frame in 90:
		if frame % 3 == 0: view.apply_frame(close)
		view._process(1.0 / 60.0)
		reference._process(1.0 / 60.0)
		var center: Vector3 = view._ball.global_position
		for side in ["L", "R"]:
			var palm: int = carrier.rig.find_bone("Palm." + side)
			maximum_hand_gap = maxf(maximum_hand_gap, carrier.rig.to_global(carrier.rig.get_bone_global_pose(palm).origin).distance_to(center))
			var other_palm: int = defender.rig.find_bone("Palm." + side)
			opponent_ball_gap = minf(opponent_ball_gap, defender.rig.to_global(defender.rig.get_bone_global_pose(other_palm).origin).distance_to(center))
		for pair in [[carrier.rig, segments(reference._actors.carrier.rig)], [defender.rig, segments(reference._actors.near.rig)]]:
			var after := segments(pair[0])
			for index in after.size(): largest_length_error = maxf(largest_length_error, absf(after[index] / pair[1][index] - 1.0))
	check(maximum_hand_gap < 0.285, "Both carrier hands remain on the visible ball during the brace")
	check(opponent_ball_gap > 0.3, "The opponent guards the upper body without miming possession of the ball")
	check(largest_length_error < 0.003, "Contact preserves every tested arm and leg segment length")
	check(carrier.rig.get_bone_pose_rotation(torso).angle_to(settled[torso]) < 0.003, "Identical snapshots do not accumulate a torso bend or restart an impact")
	metrics.maximum_hand_gap_m = maximum_hand_gap
	metrics.minimum_opponent_ball_gap_m = opponent_ball_gap
	metrics.maximum_limb_length_error = largest_length_error
	# A close future endpoint cannot pose an athlete still metres away on their
	# actual render curve. Conversely, separation immediately caps the brace.
	view._actors.near.node.position = Vector3(5.0, 0, 0)
	view._actors.near.from = Vector3(5.0, 0, 0)
	view._actors.near.elapsed = 0.0
	view._process(1.0 / 60.0)
	check(view._actors.carrier.contact_weight == 0.0 and view._actors.near.contact_weight == 0.0, "Actual separation cancels a brace even when a future endpoint is close")
	step(view, 40)
	check(view._actors.carrier.contact_weight > 0.9, "The brace returns only after the displayed bodies are close again")
	# Ending the action removes the pose completely, including stale opponent arms.
	for kind in ["try", "kick", "message", "kickoff", "scrum", "reception", "setpiece-win"]:
		var excluded := fixture(0.95, kind)
		view.apply_frame(excluded)
		step(view, 30)
		check(view.get("_contact_plan") == {}, "No geometric brace on excluded action: " + kind)
	var no_ball := fixture()
	no_ball.scene.erase("ball")
	view.apply_frame(no_ball)
	step(view, 30)
	check(view.get("_contact_plan") == {} and not view._ball.visible, "An absent ball disables both the brace and stale ball presence")
	view.apply_frame(fixture())
	step(view, 24)
	var removed := fixture()
	removed.scene.players.remove_at(1)
	view.apply_frame(removed)
	step(view, 1)
	check(not view._actors.has("near") and view.get("_contact_plan") == {}, "Removed opponents cannot leave a stale contact pair")
	var paused := fixture()
	paused.paused = true
	view.apply_frame(paused)
	step(view, 1)
	var frozen := rotations(view._actors.carrier.rig)
	var frozen_ball: Transform3D = view._ball.transform
	step(view, 60)
	check(rotations(view._actors.carrier.rig) == frozen and view._ball.transform.is_equal_approx(frozen_ball), "Pause freezes skeleton and ball without a recurring contact pulse")
	check(view.get("_contact_plan") == {}, "A paused snapshot never invents a live contact")
	if ResourceLoader.exists("res://match_contact.gd"):
		var contact = load("res://match_contact.gd")
		var plan: Dictionary = contact.plan(close.scene)
		check(plan.get("carrier") == "carrier" and plan.get("opponent") == "near", "The pair uses only the featured carrier and closest real opponent")
		var absent_feature := fixture()
		absent_feature.scene.players[0].featured = false
		check(contact.plan(absent_feature.scene).is_empty(), "No carrier is guessed when no player is featured")
		var invalid := fixture()
		invalid.scene.players[1].x = NAN
		check(contact.plan(invalid.scene).is_empty(), "Non-finite positions cannot create a contact pair")
		check(contact.plan(fixture(6.0).scene).is_empty(), "Distant authored endpoints do not create an anticipation pair")
		var reversed: Dictionary = close.scene.duplicate(true)
		reversed.players.reverse()
		check(contact.plan(reversed) == plan, "Pair selection is independent of transmitted player order")
		var turnover := fixture(0.95, "turnover")
		check(contact.plan(turnover.scene) == plan, "A turnover only braces its transmitted new possessor; it does not assign a fallen victim")
		check(contact.strength(Vector3.ZERO, Vector3(6.0, 0, 0)) == 0.0, "Distant interpolated bodies never react to a future close endpoint")
		check(contact.strength(Vector3.ZERO, Vector3.ZERO) == 0.0, "Coincident schematic positions do not claim a bodily contact")
	else:
		check(false, "A separate pure geometric contact planner is available")
	print("MATCH_CONTACT07_CHECKS ", JSON.stringify({"failures": failures, "metrics": metrics}))
	view.queue_free()
	reference.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

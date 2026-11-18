extends SceneTree
## Behavioural fixtures: same snapshot, restart, direction change and reception.
## Coordinates are authored test data, never claims about a real match.

var failures: Array[String] = []
var metrics := {}

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		printerr("FAIL: ", message)

func _initialize() -> void:
	call_deferred("run")

func fixture(x: float = 50.0, kind: String = "carry", id: String = "a") -> Dictionary:
	return {"scene": {"key": "%s-%s-%s" % [kind, id, x], "kind": kind, "possession": 0,
		"players": [{"id": "a", "side": 0, "featured": id == "a", "x": x, "y": 35.0},
			{"id": "b", "side": 0, "featured": id == "b", "x": 56.0, "y": 35.0}],
		"origin": {"x": 50.0, "y": 35.0}, "ball": {"x": x if id == "a" else 56.0, "y": 35.0}}}

## Équipe de `n` joueurs alignés en x, au jeu courant (allure d'un déplacement : rythme du match 3D).
func team(x: float, n: int, key: String) -> Dictionary:
	var players: Array = []
	for i in n:
		players.append({"id": "t%d" % i, "side": i % 2, "featured": i == 0, "x": x, "y": 10.0 + i * 3.0})
	return {"scene": {"key": key, "kind": "turnover", "possession": 0, "players": players, "ball": {"x": x, "y": 10.0}}}

## Allure plafonnée (18/11/2026) : un joueur qui doit parcourir 15 m ne les avale plus en 0,55 s
## (27 m/s) ; il court au plus à Motion.ALLURE_MAX et ses jambes suivent la distance parcourue.
## Un très grand déplacement d'équipe (plus de 22 m pour au moins 6 joueurs à l'image) est un
## replacement pendant une coupe, pas une glissade.
func check_sprint_cap(view: Node3D) -> void:
	var Motion = load("res://match_motion.gd")
	view.apply_frame(team(40.0, 2, "cap-0"))
	view._process(2.0)
	var actor: Node3D = view._actors.t0.node
	var start := actor.position
	view.apply_frame(team(55.0, 2, "cap-1"))
	var peak := 0.0
	var seconds := 0.0
	var previous := actor.position
	for frame in 300:
		view._process(1.0 / 60.0)
		peak = maxf(peak, actor.position.distance_to(previous) * 60.0)
		previous = actor.position
		if actor.position.distance_to(start + Vector3(15.0, 0.0, 0.0)) > 0.01: seconds += 1.0 / 60.0
	check(peak <= Motion.ALLURE_MAX + 0.3, "A 15 m move never exceeds sprint pace (peak %.1f m/s)" % peak)
	check(seconds >= 15.0 / Motion.ALLURE_MAX, "A 15 m move lasts at least its sprint time (%.2f s)" % seconds)
	check(view.deplacement_restant() <= 0.0001, "Nothing left to run once the move is over")
	metrics.sprint_peak_mps = snappedf(peak, 0.01)
	metrics.sprint_15m_seconds = snappedf(seconds, 0.01)
	view.apply_frame(team(70.0, 2, "cap-2"))
	check(view.deplacement_restant() >= 15.0 / Motion.ALLURE_MAX - 0.01, "The director can see the move still has to be played")
	view._process(5.0)
	# Équipe qui se reforme à 40 m (après un essai) : replacée pendant une coupe.
	view.set_camera("tv")
	view.apply_frame(team(50.0, 12, "reform-0"))
	view._process(5.0)
	await process_frame
	var coupes: int = view.replacements_coupes
	view.apply_frame(team(10.0, 12, "reform-1"))
	var farthest := 0.0
	for id: String in view._actors:
		var entry: Dictionary = view._actors[id]
		farthest = maxf(farthest, (entry.node as Node3D).position.distance_to(entry.target))
	check(view.replacements_coupes == coupes + 1 and view._camera_cut, "A 40 m team reformation is a camera cut")
	check(farthest <= Motion.DERNIERS_PAS + 0.01, "Reformed players reappear a few steps from their place (%.1f m)" % farthest)
	metrics.reform_farthest_m = snappedf(farthest, 0.01)

## Rythme du direct d'origine : chaque fait reste à l'écran selon son type ; la cadence est un multiplicateur.
func check_rythme() -> void:
	var Rythme = load("res://match_rythme.gd")
	check(Rythme.prochain("try", 1).secondes >= 2.0 and Rythme.prochain("try", 1).pas == 1, "A try stays on screen for seconds at ×1")
	check(is_equal_approx(Rythme.prochain("scrum", 1).secondes, 1.5), "A scrum lasts about 1.5 s at ×1")
	check(Rythme.prochain("carry", 1).secondes >= 0.6, "A carry is no longer a 0.32 s flash")
	for kind in ["try", "scrum", "carry", "ruck", "?"]:
		for k in [1, 4, 12]:
			var suite: Dictionary = Rythme.prochain(kind, k)
			check(float(suite.secondes) >= Rythme.PAS_MIN - 0.0001 or k == 1, "%s ×%d: never faster than the engine round trip" % [kind, k])
			check(is_equal_approx(float(suite.pas) / float(suite.secondes), float(k) / Rythme.duree(kind)), "%s ×%d keeps the cadence multiplier" % [kind, k])

func run() -> void:
	var view = load("res://match_view.gd").new()
	root.add_child(view)
	await process_frame
	view.set_process(false)
	view.apply_frame(fixture())
	view._process(1.0)
	var actor: Node3D = view._actors.a.node
	var moving := fixture(52.4)
	var before := moving.duplicate(true)
	view.apply_frame(moving)
	view._process(1.0 / 60.0)
	var first_step := actor.position.x
	for frame in 11: view._process(1.0 / 60.0)
	var previous := actor.position.x
	view._process(1.0 / 60.0)
	var cruise_step := actor.position.x - previous
	check(first_step < cruise_step * 0.3, "A stationary athlete loads their stride before reaching full interpolation speed")
	# UI refreshes of the exact same sporting endpoint must not prolong the journey.
	view.apply_frame(moving)
	for frame in 24: view._process(1.0 / 60.0)
	check(actor.position.distance_to(Vector3(2.4, 0, 0)) < 0.001, "Repeated identical snapshot does not restart the movement blend")
	check(moving == before, "Movement preserves its complete input dictionary")
	metrics.start_to_cruise_ratio = first_step / maxf(cruise_step, 0.00001)
	# A reversal is authored, but the body must not rotate in a single abrupt frame.
	view.apply_frame(fixture(50.4))
	var heading := actor.rotation.y
	view._process(1.0 / 60.0)
	var turn := absf(angle_difference(heading, actor.rotation.y))
	check(turn <= 0.15, "A reversal has a bounded angular step")
	metrics.reversal_step_rad = turn
	for frame in 40: view._process(1.0 / 60.0)
	# A new receiver must not cause a six-metre instantaneous ball teleport.
	var held: Vector3 = view._ball.global_position
	var held_basis: Basis = view._ball.global_basis
	view._actors.b.node.rotation.y = view._actors.a.node.rotation.y + PI
	var receiving := fixture(50.4, "reception", "b")
	var receiving_before := receiving.duplicate(true)
	view.apply_frame(receiving)
	view._process(1.0 / 60.0)
	var ball_step: float = held.distance_to(view._ball.global_position)
	check(ball_step < 0.55, "A different receiver approaches the ball through a continuous visible transfer")
	var ball_turn := held_basis.get_rotation_quaternion().angle_to(view._ball.global_basis.get_rotation_quaternion())
	check(ball_turn < 0.2, "A reception does not instantly flip the ball to the receiver's heading")
	for frame in 50: view._process(1.0 / 60.0)
	var receiver: Dictionary = view._actors.b
	var anchor: Vector3 = load("res://match_presentation.gd").ball_anchor(receiver.node, receiver.rig)
	# Port du ballon (4b036446, #587) : le ballon n'est plus posé sur le point fixe ball_anchor mais
	# replacé d'après les poignets (carry_ball : deux mains devant le ventre, écart borné à 0,3 m).
	# L'arrivée se mesure donc à la tolérance du port (0,4 m de l'ancre) et les mains au ballon réel.
	check(view._ball.global_position.distance_to(anchor) < 0.4, "The reception finishes at the receiving athlete's hands")
	for side in ["L", "R"]:
		var palm: int = receiver.rig.find_bone("Palm." + side)
		check(receiver.rig.to_global(receiver.rig.get_bone_global_pose(palm).origin).distance_to(view._ball.global_position) < 0.3, "Receiving hands close on the real ball: " + side)
	check(receiving == receiving_before, "Reception preserves its complete input dictionary")
	metrics.first_receiver_ball_step_m = ball_step
	metrics.first_receiver_ball_rotation_rad = ball_turn
	# Incoming snapshots may move the receiving endpoint before the catch finishes.
	view.apply_frame(fixture(50.4))
	view._process(1.0)
	for update in 4:
		var moving_receiver := fixture(50.4, "reception", "b")
		moving_receiver.scene.players[1].x += update * 0.3
		moving_receiver.scene.ball.x += update * 0.3
		view.apply_frame(moving_receiver)
		for frame in 10: view._process(1.0 / 60.0)
	var caught: Vector3 = load("res://match_presentation.gd").ball_anchor(view._actors.b.node, view._actors.b.rig)
	# Même tolérance que l'arrivée de la réception (port du ballon #587, ballon replacé d'après les poignets).
	check(view._ball.global_position.distance_to(caught) < 0.4, "Moving receiver snapshots do not indefinitely restart the ball's incoming journey")
	# At a slow continuous walk a low support foot should remain planted rather
	# than skating along with the root. Measure the actual rendered skeleton.
	view.apply_frame(fixture(50.4))
	view._process(1.0)
	var support_pairs := 0
	var largest_slip := 0.0
	var feet := {}
	for frame in 240:
		if frame % 15 == 0: view.apply_frame(fixture(50.4 + frame * 0.012))
		view._process(1.0 / 60.0)
		var rig: Skeleton3D = view._actors.a.rig
		for side in ["L", "R"]:
			var foot := rig.to_global(rig.get_bone_global_pose(rig.find_bone("Foot." + side)).origin)
			var supported: bool = view._actors.a.feet.has(side)
			if frame > 75 and feet.has(side) and supported and feet[side].supported and foot.y < 0.075 and feet[side].position.y < 0.075:
				var displacement: Vector3 = foot - feet[side].position
				displacement.y = 0.0
				largest_slip = maxf(largest_slip, displacement.length())
				support_pairs += 1
			feet[side] = {"position": foot, "supported": supported}
	check(support_pairs >= 25, "Slow walk has a measurable ground-support phase")
	check(largest_slip < 0.025, "A slow support foot has less than 2.5cm frame-to-frame ground slip")
	metrics.support_pairs = support_pairs
	metrics.max_support_slip_m = largest_slip
	# Inspect geometry rather than merely checking that the IK method was called.
	var support_rig: Skeleton3D = view._actors.a.rig
	for side in ["L", "R"]:
		var upper := support_rig.find_bone("UpperLeg." + side)
		var lower := support_rig.find_bone("LowerLeg." + side)
		var foot := support_rig.find_bone("Foot." + side)
		var first := support_rig.get_bone_global_pose(upper).origin.distance_to(support_rig.get_bone_global_pose(lower).origin)
		var second := support_rig.get_bone_global_pose(lower).origin.distance_to(support_rig.get_bone_global_pose(foot).origin)
		var foot_world := support_rig.to_global(support_rig.get_bone_global_pose(foot).origin)
		load("res://match_presentation.gd")._solve_leg(support_rig, side, foot_world + Vector3(0.07, 0.02, 0.01), Vector3.FORWARD)
		var after_first := support_rig.get_bone_global_pose(upper).origin.distance_to(support_rig.get_bone_global_pose(lower).origin)
		var after_second := support_rig.get_bone_global_pose(lower).origin.distance_to(support_rig.get_bone_global_pose(foot).origin)
		check(absf(first / after_first - 1.0) < 0.002 and absf(second / after_second - 1.0) < 0.002, "Support solver preserves both leg segment lengths: " + side)
	# Switching to a frozen snapshot must not finish a residual walk afterwards.
	var paused := fixture(60.0)
	paused.paused = true
	view.apply_frame(paused)
	view._process(1.0 / 60.0)
	var frozen := actor.transform
	var frozen_ball: Transform3D = view._ball.transform
	for frame in 60: view._process(1.0 / 60.0)
	check(actor.transform.is_equal_approx(frozen), "Paused sporting snapshot settles on its endpoint without residual root glide")
	check(view._ball.transform.is_equal_approx(frozen_ball), "Paused snapshot keeps the visible ball settled")
	var kick := fixture(60.0, "kick")
	view.apply_frame(kick)
	view._process(0.05)
	kick.paused = true
	view.apply_frame(kick)
	view._process(1.0 / 60.0)
	var paused_kick: Transform3D = view._ball.transform
	for frame in 30: view._process(1.0 / 60.0)
	check(view._ball.transform.is_equal_approx(paused_kick), "Pausing an unchanged released-ball endpoint stops the remaining visual flight")
	# No contact is inferred from a geometric coincidence of two opposing players.
	var ambiguous := fixture(60.0, "turnover")
	ambiguous.scene.players[1].side = 1
	ambiguous.scene.players[1].x = 60.2
	view.apply_frame(ambiguous)
	view._process(1.0)
	check(view._actors.size() == 2, "Ambiguous contest preserves exactly the transmitted presence")
	await check_sprint_cap(view)
	check_rythme()
	print("MATCH_MOTION_CHECKS ", JSON.stringify({"failures": failures, "metrics": metrics}))
	view.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

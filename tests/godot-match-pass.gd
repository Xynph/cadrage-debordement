extends SceneTree

const Pass = preload("res://match_pass.gd")
const Presentation = preload("res://match_presentation.gd")
const Match = preload("res://match_view.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func fixture() -> Dictionary:
	# Démonstration dessinée à la main, indépendante des événements de carrière.
	return {"kind": "pass", "key": "fixture-passe", "possession": 0,
		"pass": {"fromId": "porteur", "toId": "soutien"}, "ball": {"x": 49.0, "y": 39.0},
		"players": [
			{"id": "porteur", "side": 0, "slot": 8, "x": 52.0, "y": 34.0},
			{"id": "soutien", "side": 0, "slot": 12, "x": 49.0, "y": 39.0},
			{"id": "defenseur", "side": 1, "slot": 12, "x": 55.0, "y": 37.0}]}


func check_contract(scene: Dictionary) -> void:
	check(Pass.plan(scene) == {"key": "fixture-passe", "passer": "porteur", "receiver": "soutien"},
		"La passe explicite identifie deux joueurs présents")
	for invalid in [
		{"kind": "reception"}, {"key": ""}, {"possession": 1},
		{"pass": {"fromId": "porteur", "toId": "defenseur"}},
		{"pass": {"fromId": "porteur", "toId": "porteur"}},
		{"pass": {"fromId": "porteur"}}, {"ball": {"x": NAN, "y": 39.0}},
		{"ball": {}}, {"pass": false}, {"players": [null]},
	]:
		var changed := scene.duplicate(true)
		changed.merge(invalid, true)
		check(Pass.plan(changed).is_empty(), "Une passe invalide est refusée : %s" % str(invalid))
	var duplicate := scene.duplicate(true)
	duplicate.players.append(duplicate.players[0].duplicate())
	check(Pass.plan(duplicate).is_empty(), "Un identifiant en double est ambigu")


func check_live_contract(demo: Dictionary) -> void:
	for team in [0, 1]:
		var scene := demo.duplicate(true)
		var direction := 1 if team == 0 else -1
		scene.kind = "carry"
		scene.possession = team
		scene.players[0].side = team
		scene.players[1].side = team
		scene.players[1].featured = true
		scene.players[2].side = 1 - team
		scene.pass.from = {"x": 50 + direction * 2, "y": 34}
		scene.pass["catch"] = {"x": 50, "y": 39}
		var plan := Pass.plan(scene)
		check(plan.get("passer") == "porteur" and plan.get("receiver") == "soutien"
			and plan.get("origin") == Vector2(50 + direction * 2, 34)
			and plan.get("catch_point") == Vector2(50, 39), "La progression au large transporte deux points et deux rôles")
		var invalid := scene.duplicate(true)
		invalid.players[1].featured = false
		check(Pass.plan(invalid).is_empty(), "La passe vise le porteur canonique")
		invalid = scene.duplicate(true)
		invalid.pass["catch"].x = 50 + direction * 3
		check(Pass.plan(invalid).is_empty(), "Le repère absolu refuse une passe vers l’avant pour chaque équipe")
		invalid = scene.duplicate(true)
		invalid.pass["catch"].y = INF
		check(Pass.plan(invalid).is_empty(), "Les coordonnées doivent rester finies et sur le terrain")
		invalid = scene.duplicate(true)
		invalid.erase("pass")
		check(Pass.plan(invalid).is_empty(), "Un portage sans paire explicite conserve le rendu normal")


func draw_pass(view: NativeMatchView, progress: float, pass_plan: Dictionary) -> Dictionary:
	var sender: Dictionary = view._actors[pass_plan.passer]
	var receiver: Dictionary = view._actors[pass_plan.receiver]
	var start := Presentation.ball_anchor(sender.node, sender.rig)
	var end := Presentation.ball_anchor(receiver.node, receiver.rig)
	var pose := Pass.sample(progress, start, end)
	view._ball.global_position = pose.ball
	view._ball_marker.global_position = Vector3(pose.ball.x, 0.028, pose.ball.z)
	Pass.pose(sender.node, sender.rig, pose.passer_target, pose.passer_weight, sender.contact_base)
	Pass.pose(receiver.node, receiver.rig, pose.receiver_target, pose.receiver_weight, receiver.contact_base)
	return pose


func run() -> void:
	var scene := fixture()
	check_contract(scene)
	check_live_contract(scene)
	var pass_plan := Pass.plan(scene)
	if pass_plan.is_empty():
		quit(1)
		return
	var view: NativeMatchView = Match.new()
	root.add_child(view)
	view.set_process(false)
	view.apply_frame({"scene": scene})
	view._process(0.55)
	var sender: Dictionary = view._actors[pass_plan.passer]
	var receiver: Dictionary = view._actors[pass_plan.receiver]
	var rig: Skeleton3D = sender.rig
	if not rig or not receiver.rig:
		push_error("Le modèle Quaternius stagé et importé est requis")
		quit(1)
		return
	var sender_transform: Transform3D = sender.node.global_transform
	var receiver_transform: Transform3D = receiver.node.global_transform
	var from := Presentation.ball_anchor(sender.node, sender.rig)
	var to := Presentation.ball_anchor(receiver.node, receiver.rig)
	var held := Pass.sample(0.0, from, to)
	var flight := Pass.sample(0.50, from, to)
	var received := Pass.sample(1.0, from, to)
	check(held.stage == "held" and held.ball == from and held.passer_weight == 1.0,
		"La passe commence à deux mains, près du porteur")
	check(flight.stage == "flight" and flight.ball.distance_to(from) > 0.5 and flight.ball.distance_to(to) > 0.5,
		"Le ballon quitte le porteur avant d’atteindre le soutien")
	check(received.stage == "received" and received.ball == to and received.receiver_weight == 1.0,
		"La réception rejoint le point d’ancrage du soutien")
	check(Pass.sample(0.50, from, to) == flight, "Un temps figé rejoue la même pose de ballon")
	check(Pass.sample(NAN, from, to).is_empty() and Pass.sample(0.50, from, from).is_empty(),
		"Un temps non fini ou deux points confondus ne créent pas de vol")
	for phase in [Pass.RELEASE, Pass.CATCH]:
		var before: Vector3 = Pass.sample(phase - 0.0001, from, to).ball
		var after: Vector3 = Pass.sample(phase + 0.0001, from, to).ball
		check(before.distance_to(after) < 0.01, "Continuité du ballon à %s" % str(phase))
	var palm := rig.find_bone("Palm.L")
	var resting := rig.get_bone_pose_rotation(palm)
	var upper := rig.find_bone("UpperArm.L")
	var lower := rig.find_bone("LowerArm.L")
	var arm_length := rig.get_bone_global_pose(upper).origin.distance_to(rig.get_bone_global_pose(lower).origin)
	var preparation := draw_pass(view, Pass.RELEASE, pass_plan)
	check(preparation.passer_target.is_equal_approx(view._ball.global_position), "Point de lâcher rendu identique")
	check(not rig.get_bone_pose_rotation(palm).is_equal_approx(resting), "Le vrai squelette tourne la main")
	check(is_equal_approx(arm_length, rig.get_bone_global_pose(upper).origin.distance_to(rig.get_bone_global_pose(lower).origin)),
		"La longueur du bras importé reste constante")
	check(sender.node.global_transform == sender_transform and receiver.node.global_transform == receiver_transform,
		"La pose de passe ne déplace aucun joueur")
	Presentation.restore_contact(rig, sender.contact_base)
	check(rig.get_bone_pose_rotation(palm).is_equal_approx(resting) and sender.contact_base.is_empty(),
		"La pose d’origine est restaurée sans accumulation")
	Presentation.restore_contact(receiver.rig, receiver.contact_base)

	# Les racines avancent uniquement via la projection de match existante.
	var start_scene := scene.duplicate(true)
	start_scene.players[0].x -= 0.7
	start_scene.players[1].x -= 2.6
	view.apply_frame({"scene": start_scene})
	view._process(0.55)
	var receiver_start: Vector3 = receiver.node.global_position
	view.apply_frame({"scene": scene})
	var folder := OS.get_environment("CD_MATCH_PASS_PROOF")
	var graphical := DisplayServer.get_name() != "headless"
	var capture := graphical and not folder.is_empty()
	var demo := graphical and "--demo" in OS.get_cmdline_user_args()
	if capture:
		check(DirAccess.make_dir_recursive_absolute(folder) == OK, "Dossier de captures accessible")
	if capture or demo:
		root.title = "Oval Legacy 27 · Démonstration de passe"
		view.set_camera("action")
	var displacement_at_catch := 0.0
	var largest_hold_gap := 0.0
	for frame in range(33):
		view._process(0.55 / 32.0 if frame else 0.0)
		var drawn := draw_pass(view, float(frame) / 32.0, pass_plan)
		if drawn.stage == "held" or drawn.stage == "received":
			var holder: Dictionary = sender if drawn.stage == "held" else receiver
			var holder_rig: Skeleton3D = holder.rig
			for side in ["L", "R"]:
				var hand := holder_rig.to_global(holder_rig.get_bone_global_pose(holder_rig.find_bone("Palm." + side)).origin)
				largest_hold_gap = maxf(largest_hold_gap, hand.distance_to(drawn.ball))
		if frame == 25:
			displacement_at_catch = receiver_start.distance_to(receiver.node.global_position)
		var snapshot := capture and frame in [8, 17, 27]
		if demo or snapshot:
			var focus := Vector3(0.0, 0.4, 2.5)
			view._camera.global_position = focus + Vector3(4.0, 8.0, 12.0)
			view._camera.look_at(focus)
			view._camera.size = 9.2
			await RenderingServer.frame_post_draw
		if snapshot:
			var image := root.get_texture().get_image()
			check(image.save_png(folder.path_join("passe-%s.png" % drawn.stage)) == OK, "Capture enregistrée")
		if demo:
			await create_timer(0.035).timeout
	check(displacement_at_catch > 1.0 and displacement_at_catch < 2.6,
		"Le soutien reçoit avant la fin de son déplacement")
	check(largest_hold_gap < 0.39, "Le ballon reste proche des deux mains pendant les prises")
	for failure in failures:
		push_error(failure)
	print("MATCH_PASS_CHECKS ", JSON.stringify({"failures": failures, "real_rig": true,
		"phases": [held.stage, flight.stage, received.stage],
		"catch_displacement_m": displacement_at_catch, "largest_hold_gap_m": largest_hold_gap}))
	view.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

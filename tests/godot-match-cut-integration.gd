extends SceneTree

const MatchView = preload("res://match_view.gd")
const Motion = preload("res://match_motion.gd")

var failures: Array[String] = []
var proof := OS.get_environment("CD_MATCH_CUT_PROOF")


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func frame(x: float, y: float, paused := false) -> Dictionary:
	var players: Array[Dictionary] = [{"id": "carrier", "side": 0, "x": x, "y": y, "featured": true}]
	for index in 29:
		players.append({
			"id": "player-%d" % index, "side": 0 if index < 14 else 1,
			"x": 10.0 + (index % 8) * 4.0, "y": 5.0 + floori(index / 8.0) * 15.0,
		})
	return {"paused": paused, "scene": {
		"kind": "carry", "possession": 0, "players": players, "ball": {"x": x, "y": y},
	}}


func run() -> void:
	var directions: Array[int] = []
	for side in [-1, 1]:
		var view := MatchView.new()
		root.add_child(view)
		view.set_process(false)
		view.apply_frame(frame(48.0, 35.0))
		view.apply_frame(frame(50.8, 35.0))
		view._process(0.25)
		view.apply_frame(frame(50.8, 35.0 + side * 2.8))
		var carrier: Dictionary = view._actors["carrier"]
		directions.append(carrier.cut_direction)
		check(view._actors.size() == 30 and carrier.rig != null, "30 joueurs et squelette natif")
		view.apply_frame(frame(50.8, 35.0 + side * 2.8))
		view._process(0.14)
		var expected := Motion.position_at(carrier.from, carrier.target, carrier.tangent,
			float(carrier.elapsed) / MatchView.BLEND_SECONDS)
		check(carrier.node.position.is_equal_approx(expected), "Trajectoire de présentation conservée")
		check(not carrier.cut_pose.is_empty() and view._ball_attached, "Crochet et ballon tenu")
		if not proof.is_empty():
			view.set_camera("action")
			await process_frame
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(proof.path_join("crochet-%d.png" % side)) == OK,
				"Capture du crochet")
		view.apply_frame(frame(50.8, 35.0 + side * 2.8, true))
		view._process(0.1)
		var paused_ball := view._ball.position
		view._process(0.1)
		check(carrier.cut_direction == 0 and carrier.cut_pose.is_empty(), "Fin du crochet pendant la pause")
		check(view._ball.position.is_equal_approx(paused_ball), "Ballon stable pendant la pause")
		view.queue_free()
		await process_frame
	check(directions.size() == 2 and directions[0] != 0 and directions[0] == -directions[1],
		"Directions opposées pour les deux appuis")
	var view := MatchView.new()
	root.add_child(view)
	view.set_process(false)
	view.apply_frame(frame(48.0, 35.0))
	view.apply_frame(frame(50.8, 35.0))
	view._process(0.55)
	view._process(0.15)
	view.apply_frame(frame(50.8, 37.8))
	check(view._actors["carrier"].cut_direction != 0, "Raccord entre deux positions moteur")
	view._process(0.55)
	view._process(0.4)
	view.apply_frame(frame(53.6, 37.8))
	check(view._actors["carrier"].cut_direction == 0, "Pas de crochet après un arrêt")
	view.queue_free()
	await process_frame
	if not proof.is_empty():
		await RenderingServer.frame_post_draw
	print("MATCH_CUT_INTEGRATION ", JSON.stringify({"directions": directions, "failures": failures}))
	quit(0 if failures.is_empty() else 1)

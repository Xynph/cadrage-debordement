extends SceneTree

const Match = preload("res://match_view.gd")
const Presentation = preload("res://match_presentation.gd")

var failures: Array[String] = []
var proof := OS.get_environment("CD_LIVE_PASS_PROOF_DIR")


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
		printerr(description)


func anchor(entry: Dictionary) -> Vector3:
	return Presentation.ball_anchor(entry.node, entry.rig)


func hand_gap(entry: Dictionary, ball: Vector3) -> float:
	var rig: Skeleton3D = entry.rig
	var gap := 0.0
	for name_ in ["Palm.L", "Palm.R"]:
		var palm := rig.to_global(rig.get_bone_global_pose(rig.find_bone(name_)).origin)
		gap = maxf(gap, palm.distance_to(ball))
	return gap


func advance(view: NativeMatchView, seconds: float) -> void:
	for frame in range(10):
		view._process(seconds / 10.0)


func capture(view: NativeMatchView, scene: Dictionary, label: String) -> void:
	if proof.is_empty() or DisplayServer.get_name() == "headless":
		return
	var release: Dictionary = scene.pass.from
	var receipt: Dictionary = scene.pass["catch"]
	var center := Vector3((release.x + receipt.x) * 0.5 - 50.0, 0.55, (release.y + receipt.y) * 0.5 - 35.0)
	view._camera.position = center + Vector3(6, 9, 13)
	view._camera.look_at(center)
	view._camera.size = 10.0
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(image.save_png(proof.path_join("passe-live-%s.png" % label)) == OK, "La capture est enregistrée.")


func run() -> void:
	var file := OS.get_environment("CD_LIVE_PASS_FIXTURE")
	var sample: Variant = JSON.parse_string(FileAccess.get_file_as_string(file))
	if not sample is Dictionary or not sample.get("before") is Dictionary or not sample.get("scene") is Dictionary:
		printerr("Deux instantanés du moteur sont requis.")
		quit(1)
		return
	var scene: Dictionary = sample.scene
	if not proof.is_empty() and DisplayServer.get_name() != "headless":
		check(DisplayServer.window_get_current_screen() == 1, "La recette graphique reste sur l’écran de droite.")
	var view: NativeMatchView = Match.new()
	root.add_child(view)
	view.set_process(false)
	view.apply_frame({"scene": sample.before})
	advance(view, 0.6)
	var previous_passer: Vector3 = view._actors[scene.pass.fromId].node.position
	var previous_receiver: Vector3 = view._actors[scene.pass.toId].node.position
	var previous_ball := view._ball.global_position
	view.apply_frame({"scene": scene})
	var current: Variant = view.get("_pass_plan")
	if not current is Dictionary or current.is_empty():
		check(false, "Le direct doit consommer la passe projetée par le moteur.")
		view.queue_free()
		await process_frame
		quit(1)
		return
	var sender: Dictionary = view._actors[scene.pass.fromId]
	var receiver: Dictionary = view._actors[scene.pass.toId]
	# Un joueur exclu temporairement (carton jaune) n'est plus dans la scène du moteur : le XV est complet
	# des deux côtés sauf exclusion déclarée, et chaque joueur projeté a exactement un acteur.
	var projected_ids: Dictionary = {}
	for projected_player: Dictionary in scene.players:
		if int(projected_player.get("side", -1)) in [0, 1]: projected_ids[str(projected_player.get("id", ""))] = true
	var every_actor: bool = projected_ids.keys().all(func(id): return view._actors.has(id))
	check(projected_ids.size() >= 28 and projected_ids.size() <= 30 and every_actor and view._actors.size() <= 30, "Le XV reste complet des deux côtés (hors exclusion temporaire).")
	check(view._carrier_id == scene.pass.toId, "Le porteur canonique reste le receveur.")
	check(sender.node.position.is_equal_approx(previous_passer)
		and receiver.node.position.is_equal_approx(previous_receiver)
		and view._ball.global_position.is_equal_approx(previous_ball), "La réception du modèle conserve les positions de l’image précédente.")
	advance(view, 0.04)
	var release := Vector3(float(scene.pass.from.x) - 50.0, 0.0, float(scene.pass.from.y) - 35.0)
	var catch_point: Dictionary = scene.pass["catch"]
	var receipt := Vector3(float(catch_point.x) - 50.0, 0.0, float(catch_point.y) - 35.0)
	check(sender.node.position.distance_to(previous_passer) > 0.001
		and sender.node.position.distance_to(release) > 0.001
		and receiver.node.position.distance_to(previous_receiver) > 0.001
		and receiver.node.position.distance_to(receipt) > 0.001
		and view._ball.global_position.distance_to(previous_ball) > 0.001, "Les joueurs et le ballon convergent sur les premières images.")
	advance(view, 0.14)
	check(hand_gap(sender, view._ball.global_position) < 0.39, "Avant le lâcher, le ballon est près des mains du passeur.")
	await capture(view, scene, "avant")
	advance(view, 0.14)
	var airborne := view._ball.global_position
	check(airborne.y > 0.9 and airborne.distance_to(anchor(sender)) > 0.65
		and airborne.distance_to(anchor(receiver)) > 0.65, "Le ballon traverse l’espace entre les deux squelettes.")
	check(not view.get("_pass_plan").is_empty() and not view._ball_attached,
		"En cadence normale, le premier tick de 0,32 s tombe pendant le vol.")
	await capture(view, scene, "vol")
	var elapsed: float = view.get("_pass_elapsed")
	view.apply_frame({"scene": scene})
	check(is_equal_approx(float(view.get("_pass_elapsed")), elapsed), "La même action n’est pas rejouée après actualisation.")
	view.set_live_cadence(4)
	advance(view, 0.13)
	check(not view.get("_pass_plan").is_empty() and hand_gap(receiver, view._ball.global_position) < 0.39,
		"Le receveur garde la prise à l’écran, même si la cadence change pendant la passe.")
	await capture(view, scene, "prise")
	advance(view, 0.08)
	check(view._ball_attached and view._ball.global_position.distance_to(anchor(receiver)) < 0.45,
		"Le porteur reprend la tenue normale après la passe.")
	advance(view, 0.6)
	var final_position := Vector3(float(scene.ball.x) - 50.0, 0.0, float(scene.ball.y) - 35.0)
	check(receiver.node.position.is_equal_approx(final_position), "Le porteur termine au point canonique du moteur.")

	# La cadence accélérée conserve le transfert court et la même destination.
	var fast_scene := scene.duplicate(true)
	fast_scene.key = "passe-cadence-acceleree"
	view.apply_frame({"scene": fast_scene})
	advance(view, 0.25)
	check(not view.get("_pass_plan").is_empty() and not view._ball_attached, "La passe accélérée reste visible avant 0,30 s.")
	view.set_live_cadence(1)
	advance(view, 0.06)
	check(view.get("_pass_plan").is_empty() and view._ball_attached,
		"Une passe accélérée finit après 0,30 s malgré un retour à la cadence normale.")

	# Un nouveau modèle qui passe en pause se fige sur la situation canonique.
	var next_scene := scene.duplicate(true)
	next_scene.key = "nouvelle-action"
	view.apply_frame({"scene": next_scene})
	advance(view, 0.12)
	view.apply_frame({"scene": next_scene, "paused": true})
	advance(view, 0.2)
	check(view.get("_pass_plan").is_empty() and view._ball_attached
		and view._ball.global_position.is_equal_approx(anchor(receiver)), "La pause arrête la passe et fige le porteur canonique.")
	view.apply_frame({"scene": next_scene})
	advance(view, 0.2)
	check(view.get("_pass_plan").is_empty(), "La reprise du même instantané ne réarme pas la passe.")
	view.set_action_motion(false)
	next_scene.key = "nouvelle-action-en-mode-calme"
	view.apply_frame({"scene": next_scene})
	advance(view, 0.12)
	check(view.get("_pass_plan").is_empty(), "Le mode calme conserve la scène sans transfert animé.")

	view.queue_free()
	await process_frame
	if not proof.is_empty() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	if failures.is_empty():
		print("MATCH_LIVE_PASS_OK")
	quit(0 if failures.is_empty() else 1)

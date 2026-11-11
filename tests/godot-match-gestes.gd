extends SceneTree
## Gestes de rugby : touche portée, ballon porté, essai aplati, sur la séquence
## extraite du moteur (tests/fixtures/match-gestes-sequence.json).

const View = preload("res://match_view.gd")
const Presentation = preload("res://match_presentation.gd")
const STEP := 1.0 / 30.0
const TICK := 0.32

var failures: Array[String] = []
var checks := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("FAIL: ", message)

func _initialize() -> void:
	call_deferred("run")

func live(frames: Array, index: int, paused: bool = false) -> Dictionary:
	var events: Array = []
	for earlier in index + 1:
		events.append_array(frames[earlier].events)
	return {"scene": frames[index].scene, "teams": frames[index].teams, "events": events, "paused": paused}

func featured(scene: Dictionary) -> String:
	for player: Dictionary in scene.players:
		if player.featured:
			return player.id
	return ""

func lift(view, id: String, bases: Dictionary) -> float:
	return (view._actors[id].model as Node3D).position.y - float(bases[id])

func hands(view, id: String) -> float:
	var rig: Skeleton3D = view._actors[id].rig
	var worst := 0.0
	for hand in ["Palm.L", "Palm.R"]:
		worst = maxf(worst, rig.to_global(rig.get_bone_global_pose(rig.find_bone(hand)).origin).distance_to(view._ball.global_position))
	return worst

func make_view(gestes: bool):
	var view = View.new()
	root.add_child(view)
	view.set_process(false)
	view.set_gestes(gestes)
	view.set_live_cadence(1)
	return view

func run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1280, 720)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://").path_join("../../tests/fixtures/match-gestes-sequence.json")))
	check(parsed is Dictionary and parsed.get("frames") is Array, "Séquence du moteur lisible")
	if not failures.is_empty():
		quit(1)
		return
	var frames: Array = parsed.frames
	var before := frames.duplicate(true)
	var kinds: Array = frames.map(func(frame: Dictionary) -> String: return frame.scene.kind)
	var at_lineout := kinds.find("lineout")
	var at_try := kinds.find("try")
	check(at_lineout >= 0 and at_try == at_lineout + 2 and kinds[at_lineout + 1] == "setpiece-win", "La séquence contient alignement, touche conservée puis essai")
	check(at_try + 1 < frames.size(), "Une scène suit l'essai")

	# Sans le drapeau : aucun geste, aucune attente, le jeu reste celui d'avant.
	var plain = make_view(false)
	await process_frame
	check(plain._gestes == null, "Sans CD_MATCH_GESTES la vue n'a pas de gestes")
	for index in frames.size():
		plain.apply_frame(live(frames, index))
		for frame in 12: plain._process(STEP)
		check(not plain.is_presenting_extended_pass(), "Sans gestes le match n'attend jamais : " + str(kinds[index]))
	for id: String in plain._actors:
		check(is_zero_approx((plain._actors[id].model as Node3D).rotation.x), "Sans gestes aucun corps n'est incliné")
	plain.queue_free()

	var view = make_view(true)
	await process_frame
	var gestes: RefCounted = view._gestes
	check(gestes != null and not gestes.active(), "Les gestes s'activent explicitement et restent au repos")
	view.apply_frame(live(frames, 0))
	view._process(1.0)
	var bases := {}
	for id: String in view._actors:
		bases[id] = (view._actors[id].model as Node3D).position.y
	var index := 0
	var since := 0.0
	var clock := 0.0
	var peak := 0.0
	var rival_peak := 0.0
	var caught := false
	var waited := 0.0
	var maul_checked := false
	var try_checked := false
	var aligned := false
	var winner_jumper := ""
	var maul_carrier := ""
	var maul_opponents := 0
	var maul_spread := 0.0
	var maul_pitch := 0.0
	var maul_ball := 99.0
	var maul_arrival := 99.0
	var grounded := Vector3.INF
	var scorer_pitch := 0.0
	var scorer_hands := 99.0
	var cheering := 0
	while index < frames.size() - 1 or gestes.active():
		since += STEP
		if index < frames.size() - 1 and since >= TICK and not view.is_presenting_extended_pass():
			index += 1
			since = 0.0
			view.apply_frame(live(frames, index))
		view._process(STEP)
		clock += STEP
		if clock > 60.0:
			break
		if view.is_presenting_extended_pass():
			waited += STEP
		var kind: String = kinds[index]
		if kind == "lineout" and gestes.phase == "touche" and gestes.awaiting and gestes.done and not aligned:
			aligned = true
			var thrower: Node3D = view._actors[gestes.thrower].node
			check(thrower.position.z < -35.0 and absf(thrower.position.x - (float(frames[index].scene.origin.x) - 50.0)) < 0.01, "Le lanceur est en touche, sur la ligne de remise en jeu")
			check(hands(view, gestes.thrower) < 0.3 and view._ball.global_position.y > 1.9, "Le lanceur tient le ballon au-dessus de la tête")
			check(not view.is_presenting_extended_pass(), "Alignement prêt : le match reprend la main")
			var lines: Array[float] = [0.0, 0.0]
			for id: String in gestes.cast:
				if gestes.cast[id].role in ["jumper", "lift_front", "lift_back"]:
					lines[gestes.cast[id].team] += view._actors[id].node.position.x / 3.0
			check(absf(absf(lines[0] - lines[1]) - 1.2) < 0.05 and lines[0] < lines[1], "Deux lignes séparées par un couloir, chacune de son côté")
		if gestes.phase == "touche" and not gestes.awaiting:
			winner_jumper = gestes.jumper
			peak = maxf(peak, lift(view, gestes.jumper, bases))
			var rival: String = gestes.jumpers[1 - gestes.side]
			if not rival.is_empty():
				rival_peak = maxf(rival_peak, lift(view, rival, bases))
			if absf(gestes.time - 2.1) < STEP * 0.6:
				caught = hands(view, gestes.jumper) < 0.3 and view._ball.global_position.y > 2.8
		if gestes.phase == "maul" and gestes.done and not maul_checked:
			maul_checked = true
			maul_carrier = gestes.carrier
			var holder: Dictionary = view._actors[gestes.carrier]
			maul_ball = Presentation.ball_anchor(holder.node, holder.rig).distance_to(view._ball.global_position)
			var engine_ball := Vector3(float(frames[index].scene.ball.x) - 50.0, 0.0, float(frames[index].scene.ball.y) - 35.0)
			maul_arrival = Vector3(view._ball.global_position.x, 0.0, view._ball.global_position.z).distance_to(engine_ball)
			for id: String in gestes.cast:
				var member: Dictionary = gestes.cast[id]
				if member.role == "opp_pack": maul_opponents += 1
				if member.role in ["pack", "tail", "opp_pack"]:
					maul_spread = maxf(maul_spread, (view._actors[id].node as Node3D).position.distance_to(holder.node.position))
				if member.role == "pack":
					maul_pitch = maxf(maul_pitch, (view._actors[id].model as Node3D).rotation.x)
		if gestes.phase == "essai_maul" and gestes.done and not try_checked:
			try_checked = true
			grounded = view._ball.global_position
			scorer_pitch = (view._actors[gestes.carrier].model as Node3D).rotation.x
			scorer_hands = hands(view, gestes.carrier)
			check(gestes.carrier == featured(frames[at_try].scene), "Le marqueur est celui que le moteur désigne")
			for id: String in gestes.cast:
				if id != gestes.carrier and gestes.cast[id].team == gestes.side:
					var rig: Skeleton3D = view._actors[id].rig
					if rig.to_global(rig.get_bone_global_pose(rig.find_bone("Palm.L")).origin).y > 1.9: cheering += 1
	check(aligned, "La scène d'alignement met les deux équipes en place avant le lancer")
	check(winner_jumper == gestes.jumpers[0] or winner_jumper == gestes.jumpers[1], "Le sauteur appartient à un bloc de saut")
	check(peak > 0.95, "Le sauteur est porté à plus de 95 cm : " + str(peak))
	check(rival_peak > 0.4 and rival_peak < peak - 0.2, "Le bloc adverse conteste, moins haut : " + str(rival_peak))
	check(caught, "Prise à deux mains au sommet, ballon à plus de 2,8 m")
	check(maul_checked, "La touche conservée « ballon porté » forme un regroupement")
	check(maul_carrier == featured(frames[at_lineout + 1].scene), "Le porteur du ballon porté est l'acteur désigné par le moteur")
	check(maul_ball < 0.05, "Le ballon est dans les bras du porteur : " + str(maul_ball))
	check(maul_arrival < 0.6, "Le ballon porté arrive au point de ballon du moteur : " + str(maul_arrival))
	check(maul_opponents >= 1, "Au moins un adversaire est lié : c'est bien un maul")
	check(maul_spread < 3.8, "Le regroupement reste compact : " + str(maul_spread))
	check(maul_pitch > 0.2, "Les liés poussent buste engagé : " + str(maul_pitch))
	check(try_checked, "L'essai prolonge le ballon porté")
	var try_point := Vector3(float(frames[at_try].scene.ball.x) - 50.0, 0.0, float(frames[at_try].scene.ball.y) - 35.0)
	check(grounded.is_finite() and Vector3(grounded.x, 0.0, grounded.z).distance_to(try_point) < 0.01 and grounded.y < 0.2, "Ballon aplati au point d'essai du moteur : " + str(grounded))
	check(scorer_pitch > 1.2 and scorer_hands < 0.3, "Le marqueur est allongé, mains sur le ballon : %s / %s" % [scorer_pitch, scorer_hands])
	check(cheering >= 3, "Les partenaires lèvent les bras : " + str(cheering))
	check(waited > 6.0, "Le match attend la fin des gestes : " + str(waited))
	check(kinds[index] == kinds[frames.size() - 1] and not gestes.active() and gestes.cast.is_empty(), "La scène suivante libère tous les joueurs")
	for frame in 40: view._process(STEP)
	for id: String in view._actors:
		var model: Node3D = view._actors[id].model
		check(is_zero_approx(model.rotation.x) and is_equal_approx(model.position.y, float(bases[id])), "Corps rendu à l'animation source : " + id)
	check(frames == before, "Les scènes du moteur ne sont jamais modifiées")

	# Pause, cadence rapide et mode calme : pas de geste.
	view.apply_frame(live(frames, at_lineout))
	check(gestes.active(), "L'alignement reprend sur une nouvelle scène de touche")
	view.apply_frame(live(frames, at_lineout, true))
	check(not gestes.active(), "La pause annule le geste en cours")
	view.set_live_cadence(4)
	view.apply_frame(live(frames, at_lineout - 1))
	view.apply_frame(live(frames, at_lineout))
	check(not gestes.active(), "Cadence accélérée : pas de geste")
	view.set_live_cadence(1)
	view.set_action_motion(false)
	view.apply_frame(live(frames, at_lineout - 1))
	view.apply_frame(live(frames, at_lineout))
	check(not gestes.active(), "Mode calme : pas de geste")
	view.set_action_motion(true)

	# Essai hors ballon porté : le marqueur désigné plonge seul.
	view.apply_frame(live(frames, 0))
	for frame in 30: view._process(STEP)
	view.apply_frame(live(frames, at_try))
	check(gestes.phase == "essai" and gestes.carrier == featured(frames[at_try].scene), "Essai isolé : plongeon du marqueur désigné")
	clock = 0.0
	while not gestes.done and clock < 10.0:
		view._process(STEP)
		clock += STEP
	check(Vector3(view._ball.global_position.x, 0.0, view._ball.global_position.z).distance_to(try_point) < 0.01 and view._ball.global_position.y < 0.2, "Essai isolé : ballon aplati au point du moteur")
	check(hands(view, gestes.carrier) < 0.3, "Essai isolé : mains sur le ballon")
	view.apply_frame({})
	check(not gestes.active(), "Scène vide : gestes libérés")

	print("MATCH_GESTES_CHECKS ", checks, " failures=", failures.size())
	quit(1 if not failures.is_empty() else 0)

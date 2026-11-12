extends SceneTree
## « On ne dit essai que si on voit l'essai » : la mise en scène de l'essai (match_gestes.gd).
## 1. Le marqueur n'est pas le porteur : le porteur garde le ballon, fait une passe en
##    retrait au marqueur venu en soutien ; le ballon ne saute jamais d'un joueur à l'autre.
## 2. Le marqueur est le porteur : il court et aplatit lui-même.
## 3. Longue échappée : la course dure ce qu'elle dure, sans allure surhumaine.
## Dans tous les cas, le ballon est aplati dans l'en-but, derrière la ligne, mains du
## marqueur sur le ballon. 4. Ballon porté formé après une touche « équilibrée » (fait
## « porte » du moteur) : la vue joue le ballon porté puis l'essai qui en sort.

const View = preload("res://match_view.gd")
const Presentation = preload("res://match_presentation.gd")
const Gestes = preload("res://match_gestes.gd")
const STEP := 1.0 / 30.0

var failures: Array[String] = []
var checks := 0


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("FAIL: ", message)


func _initialize() -> void:
	call_deferred("run")


func players(places: Dictionary, featured: String, possession: int) -> Array:
	var list: Array = []
	for side in 2:
		for slot in 15:
			var id := "%d-%d" % [side, slot]
			var spot: Vector2 = places.get(id, Vector2(40.0 + side * 25.0 + slot % 3 * 3.0, 4.0 + slot * 4.3))
			list.append({"id": id, "side": side, "slot": slot, "featured": id == featured and side == possession, "x": spot.x, "y": spot.y})
	return list


func scene(kind: String, key: String, places: Dictionary, featured: String, ball: Vector2, origin: Vector2, possession: int = 0) -> Dictionary:
	return {"kind": kind, "key": key, "possession": possession, "team": possession, "players": players(places, featured, possession),
		"ball": {"x": ball.x, "y": ball.y}, "origin": {"x": origin.x, "y": origin.y}}


func frame(value: Dictionary, events: Array = []) -> Dictionary:
	return {"scene": value, "teams": [{"color": "#a12f41"}, {"color": "#5a92bd"}], "events": events, "paused": false}


func make_view():
	var view = View.new()
	root.add_child(view)
	view.set_process(false)
	view.set_gestes(true)
	view.set_live_cadence(1)
	return view


func palm_distance(view, id: String) -> float:
	var rig: Skeleton3D = view._actors[id].rig
	var worst := 0.0
	for hand in ["Palm.L", "Palm.R"]:
		worst = maxf(worst, rig.to_global(rig.get_bone_global_pose(rig.find_bone(hand)).origin).distance_to(view._ball.global_position))
	return worst


## Joue une action balle en main puis l'essai ; rend les mesures image par image.
func play_try(label: String, holder: String, holder_at: Vector2, scorer: String, scorer_at: Vector2, try_at: Vector2) -> Dictionary:
	var view = make_view()
	await process_frame
	var team := int(holder.get_slice("-", 0))
	var carry := scene("carry", "[30,\"%s porte\",\"carry\"]" % label, {holder: holder_at, scorer: scorer_at}, holder, holder_at, holder_at - Vector2(6 if team == 0 else -6, 0), team)
	view.apply_frame(frame(carry))
	for i in 45:
		view._process(STEP)
	var gestes: RefCounted = view._gestes
	var places := {scorer: try_at}
	if holder != scorer:
		places[holder] = holder_at + Vector2(3, 0)
	view.apply_frame(frame(scene("try", "[31,\"%s essai\",\"try\"]" % label, places, scorer, try_at, holder_at, team)))
	var out := {"phase": str(gestes.phase), "giver": str(gestes.giver), "pass_at": float(gestes.pass_at), "drive": float(gestes.drive),
		"ball_peak": 0.0, "ball_peak_outside_pass": 0.0, "held_before_pass": 0.0, "forward_pass": -99.0, "scorer_peak": 0.0, "giver_peak": 0.0,
		"grounded": Vector3.INF, "hands": 99.0, "pitch": 0.0, "seconds": 0.0, "dir": float(gestes.dir)}
	var last_ball: Vector3 = view._ball.global_position
	var last_scorer: Vector3 = view._actors[scorer].node.position
	var last_giver: Vector3 = view._actors[holder].node.position
	var clock := 0.0
	while gestes.active() and not gestes.done and clock < 20.0:
		view._process(STEP)
		clock += STEP
		var ball: Vector3 = view._ball.global_position
		var pace := ball.distance_to(last_ball) / STEP
		out.ball_peak = maxf(out.ball_peak, pace)
		var flying: bool = not out.giver.is_empty() and clock > out.pass_at - Gestes.PASS_FLIGHT - STEP and clock < out.pass_at + STEP
		if not flying and clock > 0.3:
			out.ball_peak_outside_pass = maxf(out.ball_peak_outside_pass, pace)
		last_ball = ball
		var spot: Vector3 = view._actors[scorer].node.position
		out.scorer_peak = maxf(out.scorer_peak, Vector2(spot.x - last_scorer.x, spot.z - last_scorer.z).length() / STEP)
		last_scorer = spot
		if not out.giver.is_empty():
			var giver_spot: Vector3 = view._actors[holder].node.position
			out.giver_peak = maxf(out.giver_peak, Vector2(giver_spot.x - last_giver.x, giver_spot.z - last_giver.z).length() / STEP)
			last_giver = giver_spot
			if clock > 0.3 and clock < out.pass_at - Gestes.PASS_FLIGHT - STEP:
				var hands: Dictionary = view._actors[holder]
				out.held_before_pass = maxf(out.held_before_pass, Presentation.ball_anchor(hands.node, hands.rig).distance_to(ball))
			if absf(clock - out.pass_at) < STEP * 0.6:
				# Passe en retrait : le receveur n'est pas devant le porteur au moment de la passe.
				out.forward_pass = (spot.x - giver_spot.x) * out.dir
	# Fin du plongeon : ballon au sol, marqueur allongé, mains sur le ballon.
	out.grounded = view._ball.global_position
	out.hands = palm_distance(view, scorer)
	out.pitch = (view._actors[scorer].model as Node3D).rotation.x
	out.seconds = clock
	view.queue_free()
	await process_frame
	return out


func in_goal(point: Vector3, direction: float) -> bool:
	return point.is_finite() and point.x * direction > 50.5 and point.x * direction < 55.0 and point.y < 0.2


func run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1280, 720)
	var results := {}

	# 1. Dernière passe : porteur dans les 22, marqueur en soutien à 16 m.
	var a: Dictionary = await play_try("passe", "0-9", Vector2(82, 30), "0-12", Vector2(72, 44), Vector2(100, 40))
	results["passe"] = a
	check(a.phase == "essai" and a.giver == "0-9", "Le porteur fait la dernière passe : " + str(a.giver))
	check(a.pass_at >= 0.6, "La passe attend l'arrivée du soutien : %.2f s" % a.pass_at)
	check(a.held_before_pass < 0.35, "Le ballon reste dans les mains du porteur jusqu'à la passe : %.2f m" % a.held_before_pass)
	check(a.forward_pass <= 0.05 and a.forward_pass > -5.0, "La passe n'est jamais en avant (loi 11) : %.2f m" % a.forward_pass)
	check(a.ball_peak_outside_pass < 13.0, "Hors passe, le ballon suit un joueur, il ne saute pas : %.1f m/s" % a.ball_peak_outside_pass)
	check(a.ball_peak < 30.0, "Même pendant la passe, le ballon vole à une vitesse de passe : %.1f m/s" % a.ball_peak)
	check(a.scorer_peak <= Gestes.PACE_MAX + 0.3 and a.giver_peak <= Gestes.PACE_MAX, "Allures humaines : marqueur %.1f m/s, porteur %.1f m/s" % [a.scorer_peak, a.giver_peak])
	check(in_goal(a.grounded, a.dir), "Ballon aplati derrière la ligne, dans l'en-but : " + str(a.grounded))
	check(absf(a.grounded.z - (40.0 - 35.0)) < 0.01, "Dans l'axe du point d'essai du moteur : " + str(a.grounded))
	check(a.hands < 0.4 and a.pitch > 1.2, "Le marqueur est allongé, mains sur le ballon : %.2f m / %.2f rad" % [a.hands, a.pitch])

	# 2. Le porteur marque lui-même : aucune passe.
	var b: Dictionary = await play_try("seul", "0-9", Vector2(88, 30), "0-9", Vector2(88, 30), Vector2(100, 30))
	results["seul"] = b
	check(b.phase == "essai" and b.giver.is_empty() and is_zero_approx(b.pass_at), "Le porteur marque seul, sans passe")
	check(b.ball_peak_outside_pass < 13.0, "Le ballon reste dans ses bras : %.1f m/s" % b.ball_peak_outside_pass)
	check(in_goal(b.grounded, b.dir) and b.hands < 0.4 and b.pitch > 1.2, "Aplati dans l'en-but : %s, mains %.2f m" % [b.grounded, b.hands])

	# 3. Longue échappée (48 m), équipe qui attaque vers la gauche.
	var c: Dictionary = await play_try("echappee", "1-13", Vector2(52, 35), "1-13", Vector2(52, 35), Vector2(0, 35))
	results["echappee"] = c
	check(c.dir < 0.0 and in_goal(c.grounded, c.dir), "Aplati dans l'en-but adverse, côté gauche : " + str(c.grounded))
	check(c.scorer_peak <= Gestes.PACE_MAX + 0.3, "Aucune allure surhumaine sur 48 m : %.1f m/s" % c.scorer_peak)
	check(c.drive > 6.0 and c.seconds < 12.0, "La course dure ce qu'elle dure, sous l'échéance de la régie : %.1f s (%.1f s au total)" % [c.drive, c.seconds])

	# 4. Ballon porté formé après une touche « équilibrée » : fait « porte » du moteur.
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://").path_join("../../tests/fixtures/match-gestes-sequence.json")))
	check(parsed is Dictionary and parsed.get("frames") is Array, "Séquence du moteur lisible")
	if parsed is Dictionary:
		for porte in [true, false]:
			var frames: Array = (parsed.frames as Array).duplicate(true)
			var won := -1
			for i in frames.size():
				if frames[i].scene.kind == "setpiece-win" and i > 0 and frames[i - 1].scene.kind == "lineout":
					won = i
			frames[won].events[0].scene.move = "equilibre"
			if porte: frames[won].events[0].scene["porte"] = true
			var view = make_view()
			await process_frame
			var gestes: RefCounted = view._gestes
			var seen := {}
			var grounded := Vector3.INF
			for index in frames.size() - 1:
				var events: Array = []
				for earlier in index + 1:
					events.append_array(frames[earlier].events)
				view.apply_frame({"scene": frames[index].scene, "teams": frames[index].teams, "events": events, "paused": false})
				var clock := 0.0
				while (clock < 0.32 or view.is_presenting_extended_pass()) and clock < 30.0:
					view._process(STEP)
					clock += STEP
					seen[str(gestes.phase)] = true
					if gestes.phase in ["essai", "essai_maul"] and gestes.done: grounded = view._ball.global_position
			if porte:
				check(seen.has("maul") and seen.has("essai_maul"), "Touche « équilibrée » avec ballon porté formé : regroupement puis essai qui en sort : " + str(seen.keys()))
				check(in_goal(grounded, float(gestes.dir) if gestes.active() else 1.0) or in_goal(grounded, 1.0) or in_goal(grounded, -1.0), "Essai du ballon porté aplati dans l'en-but : " + str(grounded))
			else:
				check(not seen.has("maul"), "Sans ballon porté formé, pas de regroupement inventé : " + str(seen.keys()))
			view.queue_free()
			await process_frame

	print("MATCH_ESSAI ", JSON.stringify(results))
	print("MATCH_ESSAI_CHECKS %d failures=%d" % [checks, failures.size()])
	for failure in failures:
		printerr(failure)
	quit(0 if failures.is_empty() else 1)

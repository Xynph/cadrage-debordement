extends SceneTree
## Plaquage, ruck et joie d'essai de la vue 3D (match_impacts.gd), sans bibliothèque
## d'animations : clips du modèle de joueur. Coordonnées de test, jamais un vrai match.

const ALLURE_TOLERANCE := 0.3

var failures: Array[String] = []
var metrics := {}

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		printerr("FAIL: ", message)

func _initialize() -> void:
	call_deferred("run")

## Progression du porteur « c » (camp 0) de `depuis` à `x` ; la défense est alignée en x = `ligne`,
## les soutiens de chaque camp derrière. `avance` : part de la course faite (images des temps forts).
func carry(key: String, depuis: float, x: float, ligne: float, avance: float = 1.0) -> Dictionary:
	var players: Array = [{"id": "c", "side": 0, "featured": true, "x": lerpf(depuis, x, avance), "y": 35.0}]
	for i in 5:
		players.append({"id": "a%d" % i, "side": 0, "featured": false, "x": lerpf(depuis, x, avance) - 3.0 - i * 1.5, "y": 27.0 + i * 4.0})
		players.append({"id": "d%d" % i, "side": 1, "featured": false, "x": ligne + (i % 2) * 2.0, "y": 25.0 + i * 5.0})
	return {"scene": {"key": key, "kind": "carry", "possession": 0, "players": players,
		"origin": {"x": depuis, "y": 35.0}, "ball": {"x": x, "y": 35.0}}}

func clip_de(view, id: String) -> String:
	return str((view._actors[id].animation as AnimationPlayer).current_animation)

func run() -> void:
	var Motion = load("res://match_motion.gd")
	var view = load("res://match_view.gd").new()
	root.add_child(view)
	await process_frame
	view.set_process(false)
	# Départ : porteur en x = 40, défense en ligne 22 m devant (x = 62), arrêt du porteur à x = 55.
	view.apply_frame(carry("depart", 40.0, 40.0, 62.0))
	view._process(3.0)
	var arret := Vector3(5.0, 0.0, 0.0)
	# Images des temps forts : le porteur avance par pas de 0,2 s, même fait.
	var peak := 0.0
	var previous := {}
	for id: String in view._actors: previous[id] = (view._actors[id].node as Node3D).position
	var contact_at := -1.0
	var ecart_contact := -1.0
	var chute := false
	var seconds := 0.0
	var mouvement := 15.0 / 6.5
	for frame in 60 * 8:
		var t := frame / 60.0
		if frame % 12 == 0 and t <= mouvement + 0.2:
			view.apply_frame(carry("course", 40.0, 55.0, 62.0, clampf(t / mouvement, 0.0, 1.0)))
		view._process(1.0 / 60.0)
		seconds = t
		for id: String in view._actors:
			var at: Vector3 = (view._actors[id].node as Node3D).position
			if id != "c": peak = maxf(peak, at.distance_to(previous[id]) * 60.0)
			previous[id] = at
		if contact_at < 0.0 and view._impacts.plaquages > 0:
			contact_at = t
			ecart_contact = view._impacts.distance_contact
			var porteur: Vector3 = view._actors.c.node.position
			var plaqueur: Vector3 = view._actors[view._impacts.plaqueur].node.position
			metrics.contact_distance_m = snappedf(porteur.distance_to(plaqueur), 0.01)
			check(porteur.distance_to(plaqueur) < 1.5, "The tackler is within 1.5 m of the carrier at contact (%.2f m)" % porteur.distance_to(plaqueur))
			check(porteur.distance_to(arret) < 0.7, "Contact happens where the engine stops the carry, not 15 m before")
		if contact_at >= 0.0 and clip_de(view, "c").ends_with("Man_Death"):
			chute = true
		if contact_at >= 0.0 and t > contact_at + 2.2:
			break
	check(contact_at >= 0.0, "A tackle happens at the end of the carry")
	check(chute, "The tackled carrier plays the fall clip")
	check(peak <= Motion.ALLURE_MAX + ALLURE_TOLERANCE, "Tackler and ruck support never exceed sprint pace (peak %.1f m/s)" % peak)
	metrics.contact_s = snappedf(contact_at, 0.01)
	metrics.support_peak_mps = snappedf(peak, 0.01)
	# Ruck : 2 à 4 joueurs de chaque camp penchés autour du ballon au sol.
	for camp in [0, 1]:
		var n: int = view._impacts.penches(camp)
		check(n >= 2 and n <= 4, "Ruck: side %d has 2-4 players bent over the ball (%d)" % [camp, n])
		metrics["ruck_side_%d" % camp] = n
	var centre: Vector3 = view._impacts.centre
	var loin := 0.0
	for id: String in view._impacts.ruck:
		var at: Vector3 = view._actors[id].node.position
		loin = maxf(loin, Vector2(at.x - centre.x, at.z - centre.z).length())
		check(absf((view._actors[id].model as Node3D).rotation.x) > 0.4, "Ruck player %s leans over the ball" % id)
	check(loin <= 2.5, "Ruck players gather within 2.5 m of the ball on the ground (%.2f m)" % loin)
	metrics.ruck_farthest_m = snappedf(loin, 0.01)
	var ballon: Vector3 = view._ball.global_position
	check(Vector2(ballon.x - centre.x, ballon.z - centre.z).length() < 1.0 and ballon.y < 0.4 and ballon.y > 0.1, "The ball lies on the grass at the centre of the ruck (%.2f m high)" % ballon.y)
	metrics.ball_height_m = snappedf(ballon.y, 0.01)
	var rig: Skeleton3D = view._actors.c.rig
	var tete := rig.find_bone("Head")
	if tete >= 0:
		var head := rig.to_global(rig.get_bone_global_pose(tete).origin)
		check(head.y < 0.8, "The tackled carrier lies on the ground (head %.2f m high)" % head.y)
		var local: Vector3 = (view._actors.c.node as Node3D).global_basis.inverse() * (head - (view._actors.c.node as Node3D).global_position)
		metrics.fallen_head_local = [snappedf(local.x, 0.01), snappedf(local.y, 0.01), snappedf(local.z, 0.01)]
	check(view.is_presenting_extended_pass() or view._impacts.depuis >= view._impacts.TENUE, "The director waits for the tackle and ruck")
	# Fait suivant : le ruck se défait, le porteur se relève.
	view.apply_frame(carry("suite", 55.0, 58.0, 64.0))
	for frame in 90: view._process(1.0 / 60.0)
	check(not clip_de(view, "c").ends_with("Man_Death"), "The tackled carrier gets up at the next action")
	check(view._impacts.ruck.is_empty(), "The ruck breaks up at the next action")
	for id: String in view._actors:
		check(absf((view._actors[id].model as Node3D).rotation.x) < 0.01, "%s stands up straight after the ruck" % id)
	for frame in 300: view._process(1.0 / 60.0)
	# Aucun plaquage sans défenseur à portée.
	var seul := carry("seul", 58.0, 70.0, 95.0)
	view.apply_frame(seul)
	var plaquages: int = view._impacts.plaquages
	for frame in 240: view._process(1.0 / 60.0)
	check(view._impacts.plaquages == plaquages, "No tackle is invented when no defender is within reach")
	# Essai : les coéquipiers du marqueur applaudissent une fois arrivés.
	var essai := carry("essai", 90.0, 100.0, 95.0)
	essai.scene.kind = "try"
	view.apply_frame(essai)
	var applaudissent := 0
	for frame in 60 * 6:
		view._process(1.0 / 60.0)
		var n := 0
		for id: String in view._actors:
			if int(view._actors[id].side) == 0 and id != "c" and clip_de(view, id).ends_with("Man_Clapping"): n += 1
		applaudissent = maxi(applaudissent, n)
	check(applaudissent >= 3, "Teammates of the try scorer applaud (%d)" % applaudissent)
	check(not clip_de(view, "d0").ends_with("Man_Clapping"), "Opponents do not applaud the try")
	metrics.try_clapping = applaudissent
	print("MATCH_CONTACTS_CHECKS ", JSON.stringify({"failures": failures, "metrics": metrics}))
	view.queue_free()
	await process_frame
	quit(1 if not failures.is_empty() else 0)

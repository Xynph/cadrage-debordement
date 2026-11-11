extends SceneTree
## Chorégraphe de temps forts (CD_MATCH_CHOREGRAPHE=1) dans la vue 3D.
## 1. Pistes valides : chaque joueur suit sa piste (après le raccord de 0,6 s), le ballon
##    est dans les mains du porteur des pistes ou sur sa trajectoire, il finit au sol au
##    point d'essai ; allure à l'écran plafonnée ; animation de course quand on court.
## 2. Fin des pistes : les joueurs restent où ils sont, la vue reprend son interpolation.
## 3. Repli : pistes absentes, d'une autre version ou incomplètes refusées, rien ne change ;
##    une nouvelle image de la régie met fin aux pistes.
## Pistes : CD_CHOREGRAPHIE_PISTES (écrites par tests/godot-match-choregraphie.cjs).

const View = preload("res://match_view.gd")
const Presentation = preload("res://match_presentation.gd")
const STEP := 1.0 / 30.0

var failures: Array[String] = []
var checks := 0
var results: Dictionary = {}


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("FAIL: ", message)


func _initialize() -> void:
	call_deferred("run")


func start_frame(entree: Dictionary, key: String) -> Dictionary:
	var players: Array = []
	for p: Dictionary in entree.joueurs:
		players.append({"id": str(p.id), "side": int(p.side), "slot": int(p.slot), "x": float(p.x), "y": float(p.y),
			"featured": str(p.id) == str(entree.get("porteur", ""))})
	var scene := {"kind": "reception", "key": key, "possession": int(entree.possession), "team": int(entree.possession), "players": players,
		"ball": entree.ballon, "origin": entree.ballon}
	return {"scene": scene, "teams": [{"color": "#a12f41"}, {"color": "#5a92bd"}], "events": [], "paused": false}


func make_view():
	var view = View.new()
	root.add_child(view)
	view.set_process(false)
	view.set_gestes(true)
	view.set_live_cadence(1)
	return view


func track_point(pistes: Dictionary, id: String, t: float) -> Vector3:
	for j: Dictionary in pistes.joueurs:
		if str(j.id) == id:
			var i := clampi(int(round(t / float(pistes.pas))), 0, j.x.size() - 1)
			return Vector3(float(j.x[i]) - 50.0, 0.0, float(j.y[i]) - 35.0)
	return Vector3.INF


func run() -> void:
	var texte := FileAccess.get_file_as_string(OS.get_environment("CD_CHOREGRAPHIE_PISTES"))
	var donnees: Variant = JSON.parse_string(texte)
	check(donnees is Dictionary, "pistes lisibles")
	if not donnees is Dictionary:
		finish()
		return
	var entree: Dictionary = donnees.entree
	var pistes: Dictionary = donnees.pistes
	var duree := float(pistes.duree)

	# --- 1. Lecture des pistes ------------------------------------------------
	var view = make_view()
	await process_frame
	view.apply_frame(start_frame(entree, "[69,\"depart\",\"reception\"]"))
	for i in 30:
		view._process(STEP)
	check(view.jouer_choregraphie(pistes), "pistes acceptées")
	check(view.choregraphie_active(), "pistes actives")
	var ecart_max := 0.0
	var allure_max := 0.0
	var ballon_max := 0.0
	var mains_max := 0.0
	var course_vue := false
	var porteurs_vus: Dictionary = {}
	var avant: Dictionary = {}
	for id: String in view._actors:
		avant[id] = view._actors[id].node.position
	var ballon_avant: Vector3 = view._ball.global_position
	var t := 0.0
	var images := 0
	while view.choregraphie_active() and not view.choregraphie_finie() and images < int((duree + 2.0) / STEP):
		view._process(STEP)
		images += 1
		t = view.choregraphie_temps()
		for id: String in view._actors:
			var at: Vector3 = view._actors[id].node.position
			check(at.is_finite(), "position finie")
			allure_max = maxf(allure_max, Vector2(at.x - avant[id].x, at.z - avant[id].z).length() / STEP)
			avant[id] = at
			if t > 0.7:
				var piste := track_point(pistes, id, t)
				# Échantillon le plus proche : 0,1 s d'avance ou de retard au plus, soit < 1 m à 9,4 m/s.
				ecart_max = maxf(ecart_max, Vector2(at.x - piste.x, at.z - piste.z).length())
			if view._actors[id].running:
				course_vue = true
		var porteur: String = view._choregraphie.porteur()
		if not porteur.is_empty():
			porteurs_vus[porteur] = true
			check(view._actors[porteur].holding and view._carrier_id == porteur, "le porteur des pistes tient le ballon (%.1f s)" % t)
			# Après le raccord de prise (0,2 s), le ballon est dans ses mains.
			if view._choregraphie.etat(porteur) != "aplati" and t - view._choregraphie.source_depuis > 0.25:
				var entry: Dictionary = view._actors[porteur]
				mains_max = maxf(mains_max, view._ball.global_position.distance_to(Presentation.ball_anchor(entry.node, entry.rig)))
		var b: Vector3 = view._ball.global_position
		if t > 0.7:
			if b.distance_to(ballon_avant) / STEP > 15.0: print("BALLON_RAPIDE %.2f %.1f %s %s" % [t, b.distance_to(ballon_avant) / STEP, porteur, view._choregraphie.source_ballon])
			ballon_max = maxf(ballon_max, b.distance_to(ballon_avant) / STEP)
		ballon_avant = b
	check(view.choregraphie_finie(), "pistes lues jusqu'au bout (%.1f / %.1f s)" % [t, duree])
	check(absf(images * STEP - duree) < 0.2, "durée à l'écran = durée des pistes (%.2f / %.1f s)" % [images * STEP, duree])
	check(ecart_max < 1.0, "chaque joueur suit sa piste (écart %.2f m)" % ecart_max)
	check(allure_max < 10.5, "aucune allure surhumaine à l'écran (%.1f m/s)" % allure_max)
	check(ballon_max < 25.0, "ballon jamais téléporté (%.1f m/s)" % ballon_max)
	check(mains_max < 0.05, "ballon dans les mains du porteur (%.3f m)" % mains_max)
	check(course_vue, "animation de course pendant les pistes")
	check(porteurs_vus.has(str(pistes.marqueur)), "le marqueur a porté le ballon")
	var essai := Vector3(float(pistes.essai.x) - 50.0, 0.0, float(pistes.essai.y) - 35.0)
	var fin: Vector3 = view._ball.global_position
	check(Vector2(fin.x - essai.x, fin.z - essai.z).length() < 0.2 and fin.y < 0.25, "ballon aplati au point d'essai (%s)" % str(fin))
	check(view._choregraphie.porteur().is_empty(), "plus de porteur après l'aplati")
	results["lecture"] = {"duree": duree, "images": images, "ecart_max": snappedf(ecart_max, 0.01), "allure_max": snappedf(allure_max, 0.1),
		"ballon_max": snappedf(ballon_max, 0.1), "mains_max": snappedf(mains_max, 0.001), "porteurs": porteurs_vus.keys()}

	# --- 2. Fin des pistes : chacun reste en place, interpolation d'origine ----
	var places: Dictionary = {}
	for id: String in view._actors:
		places[id] = view._actors[id].node.position
	view.arreter_choregraphie()
	check(not view.choregraphie_active(), "pistes arrêtées")
	for i in 10:
		view._process(STEP)
	var bouge := 0.0
	for id: String in view._actors:
		bouge = maxf(bouge, (view._actors[id].node.position as Vector3).distance_to(places[id]))
	check(bouge < 0.05, "en fin de pistes, personne ne saute ni ne repart seul (%.3f m)" % bouge)
	view.queue_free()
	await process_frame

	# --- 3. Repli -------------------------------------------------------------
	var repli = make_view()
	await process_frame
	repli.apply_frame(start_frame(entree, "[69,\"depart\",\"reception\"]"))
	for i in 30:
		repli._process(STEP)
	check(not repli.jouer_choregraphie({}), "pas de pistes : refusé")
	var autre := pistes.duplicate(true)
	autre.version = 2
	check(not repli.jouer_choregraphie(autre), "autre version : refusé")
	var tronquee := pistes.duplicate(true)
	tronquee.joueurs[0].x = tronquee.joueurs[0].x.slice(0, 5)
	check(not repli.jouer_choregraphie(tronquee), "piste incomplète : refusé")
	check(not repli.choregraphie_active(), "rien d'actif après un refus")
	# Sans pistes, une nouvelle image se joue par l'interpolation d'origine.
	var cible: Dictionary = start_frame(entree, "[70,\"suite\",\"carry\"]")
	cible.scene.kind = "carry"
	for p: Dictionary in cible.scene.players:
		p.x = float(p.x) + (3.0 if int(p.side) == 0 else -3.0)
	var premier: String = str(cible.scene.players[0].id)
	var depart: Vector3 = repli._actors[premier].node.position
	repli.apply_frame(cible)
	for i in 30:
		repli._process(STEP)
	var arrivee: Vector3 = repli._actors[premier].node.position
	check(absf(absf(arrivee.x - depart.x) - 3.0) < 0.05, "repli : la vue rejoint la scène suivante comme avant (%.2f m)" % absf(arrivee.x - depart.x))
	# Une image de la régie pendant les pistes y met fin.
	check(repli.jouer_choregraphie(pistes), "pistes acceptées")
	for i in 15:
		repli._process(STEP)
	repli.apply_frame(start_frame(entree, "[71,\"autre\",\"reception\"]"))
	check(not repli.choregraphie_active(), "une nouvelle image met fin aux pistes")
	repli.queue_free()
	await process_frame
	finish()


func finish() -> void:
	print("MATCH_CHOREGRAPHIE ", JSON.stringify(results))
	print("MATCH_CHOREGRAPHIE_CHECKS %d failures=%d" % [checks, failures.size()])
	for failure in failures:
		printerr(failure)
	quit(0 if failures.is_empty() else 1)

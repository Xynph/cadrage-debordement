extends SceneTree
## Chorégraphe de temps forts (CD_MATCH_CHOREGRAPHE=1) dans la vue 3D.
## 1. Pistes valides, pour chaque type (essai, franchissement, jeu au pied, ballon porté,
##    pénalité au but ou en touche) et chaque remise en jeu (mêlée, touche, coup d'envoi, jeu
##    ouvert, pénalité) : chaque joueur suit sa piste (après le
##    raccord de 0,6 s, ou d'emblée sur une coupe), le ballon est dans les mains du porteur des
##    pistes ou sur sa trajectoire, il finit là où les pistes le laissent ; allure à l'écran
##    plafonnée ; animation de course quand on court ; mêlée liée, lancer, saut, coup de pied montrés.
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
	check(donnees is Dictionary and donnees.get("cas") is Array and not donnees.cas.is_empty(), "pistes lisibles")
	if not donnees is Dictionary or not donnees.get("cas") is Array or donnees.cas.is_empty():
		finish()
		return
	# --- 1. Lecture des pistes, pour chaque type mis en scène -------------------
	var view = null
	for cas: Dictionary in donnees.cas:
		view = make_view()
		await process_frame
		lire(view, cas)
		view.queue_free()
		await process_frame
	var entree: Dictionary = donnees.cas[0].entree
	var pistes: Dictionary = donnees.cas[0].pistes
	view = make_view()
	await process_frame
	view.apply_frame(start_frame(entree, "[69,\"depart\",\"reception\"]"))
	for i in 30:
		view._process(STEP)
	check(view.jouer_choregraphie(pistes), "pistes acceptées (fin)")
	while view.choregraphie_active() and not view.choregraphie_finie():
		view._process(STEP)

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
	autre.version = 99
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


## Lit des pistes jusqu'au bout dans une vue neuve et contrôle que la vue les suit.
func lire(view, cas: Dictionary) -> void:
	var entree: Dictionary = cas.entree
	var pistes: Dictionary = cas.pistes
	var nom := str(cas.get("source", pistes.get("type", "")))
	var duree := float(pistes.duree)
	var coupe := bool(pistes.get("coupe", false))
	view.apply_frame(start_frame(entree, "[69,\"depart\",\"reception\"]"))
	for i in 30:
		view._process(STEP)
	check(view.jouer_choregraphie(pistes), "%s : pistes acceptées" % nom)
	check(view.choregraphie_active(), "%s : pistes actives" % nom)
	# Coupe sur une remise en jeu formée : chacun est déjà à sa place de départ.
	if coupe:
		view._process(0.0)
		var ecart0 := 0.0
		for id: String in view._actors:
			var at: Vector3 = view._actors[id].node.position
			var piste0 := track_point(pistes, id, 0.0)
			ecart0 = maxf(ecart0, Vector2(at.x - piste0.x, at.z - piste0.z).length())
		check(ecart0 < 0.05, "%s : coupe sur la remise en jeu en place (écart %.2f m)" % [nom, ecart0])
	var ecart_max := 0.0
	var allure_max := 0.0
	var ballon_max := 0.0
	var mains_max := 0.0
	var course_vue := false
	var porteurs_vus: Dictionary = {}
	var etats_vus: Dictionary = {}
	var avant: Dictionary = {}
	for id: String in view._actors:
		avant[id] = view._actors[id].node.position
	var ballon_avant: Vector3 = view._ball.global_position
	var arbitre_ecart := 0.0
	var arbitre_vu := false
	var carton_vu := false
	var t := 0.0
	var images := 0
	var raccord := 0.05 if coupe else 0.7
	while view.choregraphie_active() and not view.choregraphie_finie() and images < int((duree + 2.0) / STEP):
		view._process(STEP)
		images += 1
		t = view.choregraphie_temps()
		for id: String in view._actors:
			var at: Vector3 = view._actors[id].node.position
			check(at.is_finite(), "position finie")
			# Sur une coupe, la première image peut sauter (changement de plan) ; ensuite non.
			if images > 1 or not coupe:
				allure_max = maxf(allure_max, Vector2(at.x - avant[id].x, at.z - avant[id].z).length() / STEP)
			avant[id] = at
			if t > raccord:
				var piste := track_point(pistes, id, t)
				# Échantillon le plus proche : 0,1 s d'avance ou de retard au plus, soit < 1 m à 9,4 m/s.
				ecart_max = maxf(ecart_max, Vector2(at.x - piste.x, at.z - piste.z).length())
			if view._actors[id].running:
				course_vue = true
			etats_vus[view._choregraphie.etat(id)] = true
		# Arbitre (quatrième tranche) : à sa place des pistes, carton levé quand les pistes le disent.
		if pistes.has("arbitre"):
			var pa: Variant = view._choregraphie.arbitre_position()
			if pa != null:
				arbitre_vu = true
				var ia := clampi(int(round(t / float(pistes.pas))), 0, pistes.arbitre.x.size() - 1)
				arbitre_ecart = maxf(arbitre_ecart, Vector2((pa as Vector3).x - (float(pistes.arbitre.x[ia]) - 50.0), (pa as Vector3).z - (float(pistes.arbitre.y[ia]) - 35.0)).length())
			if view._choregraphie.arbitre_carton_visible():
				carton_vu = true
		var porteur: String = view._choregraphie.porteur()
		if not porteur.is_empty():
			porteurs_vus[porteur] = true
			check(view._actors[porteur].holding and view._carrier_id == porteur, "%s : le porteur des pistes tient le ballon (%.1f s)" % [nom, t])
			# Après le raccord de prise (0,2 s), le ballon est dans ses mains.
			if view._choregraphie.etat(porteur) != "aplati" and t - view._choregraphie.source_depuis > 0.25:
				var entry: Dictionary = view._actors[porteur]
				mains_max = maxf(mains_max, view._ball.global_position.distance_to(Presentation.ball_anchor(entry.node, entry.rig)))
		var b: Vector3 = view._ball.global_position
		if t > raccord and (images > 1 or not coupe):
			ballon_max = maxf(ballon_max, b.distance_to(ballon_avant) / STEP)
		ballon_avant = b
	check(view.choregraphie_finie(), "%s : pistes lues jusqu'au bout (%.1f / %.1f s)" % [nom, t, duree])
	check(absf(images * STEP - duree) < 0.2, "%s : durée à l'écran = durée des pistes (%.2f / %.1f s)" % [nom, images * STEP, duree])
	check(ecart_max < 1.0, "%s : chaque joueur suit sa piste (écart %.2f m)" % [nom, ecart_max])
	check(allure_max < 10.5, "%s : aucune allure surhumaine à l'écran (%.1f m/s)" % [nom, allure_max])
	# Lancer en touche et coup de pied compris (vitesse en trois dimensions, hauteur comprise).
	check(ballon_max < 30.0, "%s : ballon jamais téléporté (%.1f m/s)" % [nom, ballon_max])
	check(mains_max < 0.05, "%s : ballon dans les mains du porteur (%.3f m)" % [nom, mains_max])
	check(course_vue, "%s : animation de course pendant les pistes" % nom)
	# Chaque porteur des pistes a eu le ballon à l'écran.
	for paire: Variant in pistes.ballon.porteurs:
		if paire is Array and paire[1] != null:
			check(porteurs_vus.has(str(paire[1])), "%s : %s a porté le ballon à l'écran" % [nom, str(paire[1])])
	# Fin : le ballon est là où les pistes le laissent (aplati, au sol, sorti en touche) ou dans les mains.
	var n: int = pistes.ballon.x.size() - 1
	var fin: Vector3 = view._ball.global_position
	if view._choregraphie.porteur().is_empty():
		var vise := Vector3(float(pistes.ballon.x[n]) - 50.0, 0.0, float(pistes.ballon.y[n]) - 35.0)
		check(Vector2(fin.x - vise.x, fin.z - vise.z).length() < 0.3 and fin.y < 0.3, "%s : ballon au sol là où les pistes le laissent (%s)" % [nom, str(fin)])
	if pistes.has("essai"):
		var essai := Vector3(float(pistes.essai.x) - 50.0, 0.0, float(pistes.essai.y) - 35.0)
		check(Vector2(fin.x - essai.x, fin.z - essai.z).length() < 0.2 and fin.y < 0.25, "%s : ballon aplati au point d'essai (%s)" % [nom, str(fin)])
		check(view._choregraphie.porteur().is_empty(), "%s : plus de porteur après l'aplati" % nom)
	if str(pistes.get("ouverture", "")) == "melee":
		check(etats_vus.has("melee"), "%s : mêlée liée montrée" % nom)
	if str(pistes.get("ouverture", "")) == "touche":
		check(etats_vus.has("saut") and etats_vus.has("lancer"), "%s : lancer et sauteur levé montrés" % nom)
	if str(pistes.type) == "jeu_au_pied":
		check(etats_vus.has("jeu_au_pied"), "%s : coup de pied montré" % nom)
	if str(pistes.type) == "ballon_porte":
		check(etats_vus.has("maul") and etats_vus.has("saut"), "%s : sauteur levé puis avants liés du ballon porté montrés" % nom)
	if str(pistes.type) in ["penalite_au_but", "penalite_en_touche"]:
		check(etats_vus.has("jeu_au_pied"), "%s : frappe du botteur montrée" % nom)
	if str(pistes.type) == "penalite_a_la_main":
		check(etats_vus.has("tape"), "%s : pénalité tapée du pied montrée" % nom)
	if str(pistes.type) == "faute_de_main":
		check(etats_vus.has("en_avant") or etats_vus.has("passe"), "%s : faute de main montrée" % nom)
	if str(pistes.type) == "contestation_au_sol":
		check(etats_vus.has("grattage"), "%s : gratteur au-dessus du ballon montré" % nom)
	if pistes.has("arbitre"):
		check(arbitre_vu, "%s : arbitre à l'écran" % nom)
		check(arbitre_ecart < 1.0, "%s : l'arbitre suit sa piste (écart %.2f m)" % [nom, arbitre_ecart])
		var carton_attendu := false
		for e: Variant in pistes.evenements:
			if e is Dictionary and str(e.get("type", "")) == "carton":
				carton_attendu = true
		check(carton_vu == carton_attendu, "%s : carton levé à l'écran quand l'arbitre le montre (%s)" % [nom, str(carton_vu)])
	if str(pistes.type) == "penalite_au_but":
		check(etats_vus.has("placement"), "%s : ballon posé montré" % nom)
	results[nom] = {"duree": duree, "images": images, "ecart_max": snappedf(ecart_max, 0.01), "allure_max": snappedf(allure_max, 0.1), "arbitre": snappedf(arbitre_ecart, 0.01),
		"ballon_max": snappedf(ballon_max, 0.1), "mains_max": snappedf(mains_max, 0.001), "porteurs": porteurs_vus.size()}


func finish() -> void:
	print("MATCH_CHOREGRAPHIE ", JSON.stringify(results))
	print("MATCH_CHOREGRAPHIE_CHECKS %d failures=%d" % [checks, failures.size()])
	for failure in failures:
		printerr(failure)
	quit(0 if failures.is_empty() else 1)

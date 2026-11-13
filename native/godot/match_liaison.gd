extends RefCounted
## Liaison 3D entre deux temps forts contigus (13 novembre 2026, demande de Léo : « laisser une
## seconde ou deux avec le ballon qui sort… puis les joueurs qui se placent »).
##
## Quand un temps fort part là où le précédent s'est arrêté (seuls des faits d'arrêt de jeu
## entre les deux : sortie en touche, en-avant, pénalité, essai transformé, ballon mort), la
## régie ne coupe plus sec sur la remise en jeu : elle joue une courte liaison, toujours à
## vitesse réelle (correction de Léo, 09h47 : jamais d'accéléré, la vitesse des Paramètres ne
## concerne que la 2D), à la manière d'une réalisation TV :
##   - plan A, en temps réel (1,8 à 3 s) : le ballon sort ou tombe, coup de sifflet et bras de
##     l'arbitre, les joueurs décélèrent (jamais de gel), mains sur les hanches, premiers pas
##     vers la remise en jeu, capitaine qui indique le choix d'une pénalité (déjà décidé par le
##     moteur : poteaux, touche, mêlée) ;
##   - si la mise en place réelle serait longue (un joueur au moins ne peut pas rejoindre sa
##     place au trot dans le plan), COUPE franche de caméra (aucun fondu) puis plan B (1,5 s) :
##     alignement déjà formé, mêlée prête, botteur qui pose le ballon, chacun fait ses derniers
##     pas ; sinon le plan A continue jusqu'à la remise en jeu en place (4,6 s au plus).
## Le temps fort suivant part ensuite de ces places exactes : ni saut, ni coupe de plus.
##
## Rien de sportif n'est décidé ici : places d'arrivée, équipe, choix de la pénalité et
## marque viennent du moteur (scène du premier plan du temps fort suivant). Les petits
## détails (strap renoué, joueur essoufflé, capitaine qui parle) sont tirés d'une graine
## dérivée de l'identifiant du match et du temps fort (jamais le tirage du moteur), et le
## même détail ne revient jamais deux liaisons de suite.
##
## Sortie : pistes au format du chorégraphe (match_choregraphie.gd, version 2), un jeu de
## pistes par plan, plus le programme de l'arbitre et la légende (le fait d'arrêt de jeu).

const VERSION := 2
const PAS := 0.1
## Faits d'arrêt de jeu, et faits sans jeu, qui peuvent séparer deux temps forts contigus.
const ARRETS := ["touch", "hand-fault", "penalty", "ingoal"]
const NEUTRES := ["advantage", "sub", "card", "tactic", "message"]
const POINTS := ["try", "transformation", "goal", "miss"]
## Décélération des joueurs au coup de sifflet (m/s²) et allures de mise en place (m/s).
const DECELERATION := 4.5
const TROT_AVANT := 3.2
const TROT_ARRIERE := 2.5
const ALLURE_MAX := 4.4
## Profil de course (accélération, croisière, freinage, rampes de 25 %) : pointe / allure moyenne.
const RAMPE := 0.25
const POINTE := 1.0 / (1.0 - RAMPE)
## Plan A (temps réel avant une éventuelle coupe), par type de liaison.
const PLAN_A := {"touche": 2.6, "melee": 2.3, "penalite": 2.5, "penalite_main": 1.9, "renvoi": 3.0, "renvoi_22": 2.2}
## Plan B, après la coupe : remise en jeu formée, derniers pas.
const PLAN_B := 1.6
## Liaison continue (sans coupe) : au plus cette durée.
const CONTINUE_MAX := 4.6
## Derniers pas après la coupe : chacun réapparaît à cette distance au plus de sa place.
const DERNIERS_PAS := 1.4
const DETAILS := ["strap", "souffle", "capitaine_parle", "mains_hanches"]
const ETATS_ARRET := ["mains_hanches", "souffle"]


static func _fait(e: Variant) -> Dictionary:
	if not e is Dictionary:
		return {}
	return e.scene if e.get("scene") is Dictionary else e


static func _kind(e: Variant) -> String:
	return str(_fait(e).get("kind", ""))


static func _v2(p: Variant, defaut := Vector2(50, 35)) -> Vector2:
	return Vector2(float(p.get("x", defaut.x)), float(p.get("y", defaut.y))) if p is Dictionary and p.has("x") and p.has("y") else defaut


## Graine stable : identifiant du match et du temps fort (FNV-1a).
static func graine(rencontre: String, cle: String) -> int:
	var valeur: int = 2166136261
	for octet in (rencontre + "|" + cle).to_utf8_buffer():
		valeur = ((valeur ^ int(octet)) * 16777619) & 0x7fffffff
	return valeur


## Les deux temps forts sont-ils contigus, et quelle liaison les relie ? Rend {} sinon
## (la régie garde alors son comportement : 2D entre les deux, ou coupe d'entrée).
static func analyser(tf1: Dictionary, tf2: Dictionary, events: Array) -> Dictionary:
	if tf1.is_empty() or tf2.is_empty() or tf2.get("suite", false):
		return {}
	var plans1: Array = tf1.get("plans", [])
	var plans2: Array = tf2.get("plans", [])
	if plans1.is_empty() or plans2.is_empty() or not plans2[0].get("scene") is Dictionary:
		return {}
	var dernier: Dictionary = plans1[-1]
	var premier: Dictionary = plans2[0]
	var fin_kind := str(dernier.get("kind", ""))
	var kind := str(premier.get("kind", ""))
	var a := int(dernier.get("index", -1)) + 1
	var b := int(premier.get("index", -1))
	if a <= 0 or b < a or b > events.size():
		return {}
	var entre: Array[String] = []
	var arret_index := int(dernier.get("index", -1)) if fin_kind in ARRETS or fin_kind in POINTS else -1
	var sortie: Dictionary = {}
	var avantage := false
	## Du jeu entre les deux (renvoi reçu, mêlée jouée…) : liaison possible seulement par une coupe,
	## si le premier finit sur un arrêt de jeu et que le second s'ouvre sur une remise en jeu formée.
	var jeu_entre := false
	for i in range(a, b):
		var k := _kind(events[i])
		entre.append(k)
		if k == "advantage": avantage = true
	for i in range(a, b):
		var k := entre[i - a]
		# Ballon récupéré pendant l'avantage d'une pénalité : la pénalité reprend.
		if k == "turnover" and avantage: continue
		if k in ARRETS or k in POINTS:
			arret_index = i
			if k == "touch":
				var f := _fait(events[i])
				sortie = {"de": _v2(f.get("from")), "vers": _v2(f.get("to")), "cause": str(f.get("cause", ""))}
			continue
		if k in NEUTRES: continue
		jeu_entre = true
	if jeu_entre:
		if not (fin_kind in ARRETS or fin_kind in POINTS) or kind not in ["lineout", "scrum", "goal", "miss"]:
			return {}
		# Dernier arrêt avant la remise en jeu (la légende dit pourquoi elle a lieu) ; rien d'animé entre.
		sortie = {}
	var penalite := fin_kind == "penalty" or "penalty" in entre
	if jeu_entre:
		# Pénalité jouée entre deux : seule compte celle qui précède la remise en jeu.
		penalite = entre.size() > 0 and entre[-1] in ["penalty", "advantage"] and "penalty" in entre
	var points := fin_kind in POINTS or entre.any(func(k: String) -> bool: return k in POINTS)
	var type := ""
	var choix := ""
	match kind:
		"lineout":
			type = "touche"
			if penalite: choix = "touche"
		"scrum":
			type = "melee"
			if penalite: choix = "melee"
		"goal", "miss":
			if penalite:
				type = "penalite"
				choix = "poteaux"
		"kickoff":
			if points: type = "renvoi"
		"drop22", "goalLine":
			type = "renvoi_22"
		"carry":
			if penalite and arret_index >= 0:
				type = "penalite_main"
				choix = "main"
	if type.is_empty():
		return {}
	# Le coup de pied de pénaltouche n'est jamais montré : pas de sortie de ballon animée.
	if choix == "touche" or str(sortie.get("cause", "")) == "penalty-touch":
		sortie = {}
	# Sortie déjà montrée par le temps fort précédent.
	if fin_kind == "touch":
		sortie = {}
	var scene: Dictionary = premier.scene
	var cible: Dictionary = tf2.depart if tf2.get("depart") is Dictionary and not (tf2.depart as Dictionary).is_empty() else scene
	var equipe := int(scene.get("possession", -1))
	var marque := _v2(scene.get("origin"), _v2(scene.get("ball")))
	var texte := ""
	if arret_index >= 0 and arret_index < events.size() and events[arret_index] is Dictionary:
		texte = str(events[arret_index].get("text", ""))
	return {"type": type, "choix": choix, "equipe": equipe, "marque": marque, "sortie": sortie, "arret": arret_index,
		"arret_kind": _kind(events[arret_index]) if arret_index >= 0 and arret_index < events.size() else fin_kind,
		"texte": texte, "scene": scene, "cible": cible, "plan_kind": kind, "points": fin_kind in POINTS or points, "coupe_forcee": jeu_entre,
		"marqueur": int((dernier.get("scene", {}) as Dictionary).get("possession", 1 - equipe)) if dernier.get("scene") is Dictionary else 1 - equipe}


# --- Construction -----------------------------------------------------------------

## Un joueur suivi : segments de trajet, états, regard.
class Trajet:
	var id := ""
	var side := 0
	var slot := -1
	var p0 := Vector2.ZERO
	var v0 := Vector2.ZERO
	var arret := Vector2.ZERO
	var t_arret := 0.0
	## [{t0, t1, a, b}] : courses au profil de RAMPE, dans l'ordre.
	var courses: Array = []
	var etats: Array = []
	var regard := Vector2.ZERO
	var cap0 := 0.0

	## Profil de course de 0 à 1 (accélération, croisière, freinage).
	static func profil(u: float) -> float:
		u = clampf(u, 0.0, 1.0)
		var r := 0.25
		var v := 1.0 / (1.0 - r)
		if u < r: return 0.5 * v * u * u / r
		if u > 1.0 - r:
			var w := 1.0 - u
			return 1.0 - 0.5 * v * w * w / r
		return 0.5 * v * r + v * (u - r)

	func position(t: float) -> Vector2:
		if t <= t_arret and v0.length() > 0.01:
			var d := v0.normalized()
			var s := v0.length() * t - 0.5 * 4.5 * t * t
			return p0 + d * s
		var p := arret
		for c: Dictionary in courses:
			if t < float(c.t0): return p
			if t <= float(c.t1):
				return (c.a as Vector2).lerp(c.b, profil((t - float(c.t0)) / maxf(0.001, float(c.t1) - float(c.t0))))
			p = c.b
		return p

	func fin() -> Vector2:
		return arret if courses.is_empty() else courses[-1].b


static func _trajet(id: String, side: int, slot: int, p0: Vector2, v0: Vector2) -> Trajet:
	var j := Trajet.new()
	j.id = id
	j.side = side
	j.slot = slot
	j.p0 = p0
	j.v0 = v0.limit_length(9.0)
	j.t_arret = j.v0.length() / DECELERATION
	j.arret = p0 + (j.v0.normalized() * j.v0.length() * j.t_arret * 0.5 if j.v0.length() > 0.01 else Vector2.ZERO)
	return j


## Course de `j` jusqu'à `b`, arrivée à `t1`, départ au plus tôt à `t0_min`, à l'allure de trot
## (plus vite si nécessaire, ALLURE_MAX au plus). Rend faux si l'allure dépasserait ALLURE_MAX.
static func _courir(j: Trajet, b: Vector2, t0_min: float, t1: float, trot: float) -> bool:
	var a := j.fin()
	var d := a.distance_to(b)
	if d < 0.15:
		return true
	var depart := maxf(t0_min, t1 - POINTE * d / trot)
	if t1 - depart < 0.4:
		depart = t1 - 0.4
	var allure := POINTE * d / maxf(0.001, t1 - depart)
	j.courses.append({"t0": depart, "t1": t1, "a": a, "b": b})
	return allure <= ALLURE_MAX and depart >= t0_min - 0.001


## Courses de la mise en place : liaison continue (vrai) ou besoin d'une coupe (faux).
static func _faisable(trajets: Dictionary, cibles: Dictionary, duree: float, ramasseur: String, ballon: Vector2, retards: Dictionary) -> bool:
	for id: String in trajets:
		var j: Trajet = trajets[id]
		var d := j.arret.distance_to(cibles[id])
		if id == ramasseur:
			d = j.arret.distance_to(ballon) + ballon.distance_to(cibles[id])
		var dispo := duree - 0.35 - float(retards.get(id, 0.0)) - j.t_arret - 0.25 - (0.6 if id == ramasseur else 0.0)
		if POINTE * d / maxf(0.1, dispo) > ALLURE_MAX:
			return false
	return true


## Construit la liaison. `joueurs` : id -> {p: Vector2 (repère du terrain), v: Vector2 (m/s)} ;
## `ballon` : {p: Vector3 (repère de la vue), porteur: id ou ""} ; `arbitre` : Vector2 ;
## `precedent` : détail de la liaison précédente (jamais deux fois de suite).
static func construire(info: Dictionary, joueurs: Dictionary, ballon: Dictionary, arbitre: Vector2, seed: int, precedent := "") -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var type := str(info.type)
	var cible: Dictionary = info.cible
	var scene: Dictionary = info.scene
	var equipe := int(info.equipe)
	var dir := 1.0 if equipe == 0 else -1.0
	var marque: Vector2 = info.marque
	# Places d'arrivée : celles du moteur pour le temps fort suivant.
	var cibles: Dictionary = {}
	var slots: Dictionary = {}
	var sides: Dictionary = {}
	var vedette := ""
	for p: Variant in cible.get("players", []):
		if p is Dictionary and joueurs.has(str(p.get("id", ""))):
			var id := str(p.id)
			cibles[id] = _v2(p)
			slots[id] = int(p.get("slot", -1))
			sides[id] = int(p.get("side", -1))
	for p: Variant in scene.get("players", []):
		if p is Dictionary and p.get("featured", false) and int(p.get("side", -2)) == equipe and cibles.has(str(p.get("id", ""))):
			vedette = str(p.id)
	if cibles.size() < 4:
		return {}
	var trajets: Dictionary = {}
	for id: String in cibles:
		var j: Dictionary = joueurs[id]
		trajets[id] = _trajet(id, int(sides[id]), int(slots[id]), j.p, j.get("v", Vector2.ZERO))
	# Joueur qui récupère le ballon et le tient à la reprise (talonneur, demi de mêlée, botteur).
	var ramasseur := ""
	for id: String in cibles:
		if int(sides[id]) != equipe: continue
		if type == "touche" and int(slots[id]) == 1: ramasseur = id
	# Mêlée : le ballon finit au sol, à la marque de la mêlée (scène du moteur) ; l'avant de l'équipe
	# qui introduit le plus proche de cette marque le ramasse et l'y apporte.
	var ballon_melee := _v2(scene.get("ball"), marque)
	if type == "melee":
		var proche := INF
		for id: String in cibles:
			if int(sides[id]) == equipe and int(slots[id]) < 8 and (cibles[id] as Vector2).distance_to(ballon_melee) < proche:
				proche = (cibles[id] as Vector2).distance_to(ballon_melee)
				ramasseur = id
	if ramasseur.is_empty() and not vedette.is_empty(): ramasseur = vedette
	var ballon_vue: Vector3 = ballon.get("p", Vector3(marque.x - 50.0, 0.1, marque.y - 35.0))
	var porteur := str(ballon.get("porteur", ""))
	if not trajets.has(porteur): porteur = ""
	# --- Ballon du plan A : sortie, chute, ou reste où il est.
	var bal := {"t": [0.0], "p": [Vector3(ballon_vue.x + 50.0, ballon_vue.z + 35.0, ballon_vue.y)]}
	var porteurs: Array = [[0.0, porteur if not porteur.is_empty() else null]]
	var sortie: Dictionary = info.sortie
	var repos := Vector2(ballon_vue.x + 50.0, ballon_vue.z + 35.0)
	var botteur := ""
	var t_ballon := 0.0
	var duree_a := float(PLAN_A[type])
	if not sortie.is_empty():
		var vers: Vector2 = sortie.vers
		var dehors := vers + Vector2(0.0, -2.0 if vers.y < 35.0 else 2.0)
		var depuis := repos
		var dist := depuis.distance_to(vers)
		if str(sortie.cause) == "carry-touch" and not porteur.is_empty() and dist <= 9.0:
			# Porteur poussé en touche : il franchit la ligne ballon en main, puis le lâche.
			var j: Trajet = trajets[porteur]
			var t1 := maxf(0.6, dist / 5.5)
			j.v0 = Vector2.ZERO
			j.t_arret = 0.0
			j.arret = j.p0
			j.courses.append({"t0": 0.0, "t1": t1 + 0.5, "a": j.p0, "b": dehors})
			t_ballon = t1 + 0.7
			porteurs.append([t_ballon, null])
			bal.t.append(t_ballon)
			bal.p.append(Vector3(dehors.x, dehors.y, 1.0))
			bal.t.append(t_ballon + 0.35)
			bal.p.append(Vector3(dehors.x + 0.5, dehors.y, 0.12))
			repos = dehors + Vector2(0.5, 0.0)
		elif dist > 2.0 and str(sortie.cause) != "carry-touch":
			# Coup de pied en touche : le ballon file vers la ligne et roule au-delà.
			var vol := clampf(dist / 22.0, 0.7, 1.6)
			var haut := minf(10.0, dist * 0.2)
			if not porteur.is_empty():
				botteur = porteur
				porteurs.append([0.18, null])
			for k in range(1, 9):
				var u := float(k) / 8.0
				var p := depuis.lerp(vers, u)
				bal.t.append(0.18 + vol * u)
				bal.p.append(Vector3(p.x, p.y, lerpf(0.9, 0.4, u) + 4.0 * haut * u * (1.0 - u)))
			repos = vers + (vers - depuis).normalized() * 3.0 + Vector2(0.0, -2.5 if vers.y < 35.0 else 2.5)
			bal.t.append(0.18 + vol + 0.9)
			bal.p.append(Vector3(repos.x, repos.y, 0.12))
			t_ballon = 0.18 + vol + 0.9
			duree_a = maxf(duree_a, 0.18 + vol + 1.4)
	if t_ballon == 0.0:
		if not porteur.is_empty() and type != "renvoi":
			# Coup de sifflet : le porteur lâche le ballon à ses pieds (ballon mort).
			var j: Trajet = trajets[porteur]
			var lache := 0.55
			var p := j.position(lache)
			var avant := j.v0.normalized() if j.v0.length() > 0.5 else Vector2(dir, 0.0)
			porteurs.append([lache, null])
			bal.t.append(lache)
			bal.p.append(Vector3(p.x, p.y, 1.0))
			repos = p + avant * 0.9
			bal.t.append(lache + 0.45)
			bal.p.append(Vector3(repos.x, repos.y, 0.12))
			t_ballon = lache + 0.45
		else:
			var h := (bal.p[0] as Vector3).z
			bal.t.append(clampf(h / 6.0, 0.25, 0.8))
			bal.p.append(Vector3(repos.x, repos.y, 0.12))
			t_ballon = clampf(h / 6.0, 0.25, 0.8)
	# --- Retards de départ (au coup de sifflet, chacun ne repart pas au même instant).
	var retards: Dictionary = {}
	for id: String in trajets:
		retards[id] = rng.randf_range(0.0, 0.5)
	var arrivee_ballon := repos
	var continue_ok := type != "renvoi" and not bool(info.get("coupe_forcee", false)) and _faisable(trajets, cibles, CONTINUE_MAX, ramasseur, arrivee_ballon, retards)
	var coupe := not continue_ok
	var duree_continue := CONTINUE_MAX
	if continue_ok:
		# Durée juste suffisante (au moins le plan A + 1,2 s), toujours à vitesse réelle.
		duree_continue = maxf(duree_a + 1.2, 3.0)
		while duree_continue < CONTINUE_MAX and not _faisable(trajets, cibles, duree_continue, ramasseur, arrivee_ballon, retards):
			duree_continue += 0.2
		duree_continue = minf(duree_continue, CONTINUE_MAX)
	var duree_plan_a := duree_continue if continue_ok else duree_a
	# --- Courses du plan A.
	for id: String in trajets:
		var j: Trajet = trajets[id]
		var but: Vector2 = cibles[id]
		var t0 := j.t_arret + 0.25 + float(retards[id])
		if id == porteur and t_ballon > 0.0 and not j.courses.is_empty():
			t0 = maxf(t0, float(j.courses[-1].t1) + 0.2)
		var trot := TROT_AVANT if int(slots[id]) < 8 else TROT_ARRIERE
		if id == ramasseur and continue_ok:
			# Aller au ballon, le ramasser (0,4 s), puis rejoindre sa place : même allure sur les
			# deux trajets, au trot si le temps le permet (on attend alors un peu avant de partir).
			var point := arrivee_ballon - (arrivee_ballon - j.fin()).normalized() * 0.45
			var d1 := j.fin().distance_to(point)
			var d2 := point.distance_to(but)
			var fin_course := duree_plan_a - 0.35
			var dispo := maxf(0.8, fin_course - t0 - 0.4)
			var utile := minf(dispo, POINTE * (d1 + d2) / trot)
			var depart := fin_course - 0.4 - utile
			var prise := maxf(depart + utile * d1 / maxf(0.01, d1 + d2), t_ballon + 0.1)
			var allure := maxf(0.5, POINTE * (d1 + d2) / maxf(0.01, utile))
			_courir(j, point, depart, prise, allure)
			j.etats.append([prise - 0.15, "ramassage"])
			j.etats.append([prise + 0.35, "course"])
			porteurs.append([prise + 0.1, id])
			_courir(j, but, prise + 0.4, fin_course, allure)
			if type == "melee":
				# Il pose le ballon à la marque une fois à sa place.
				porteurs.append([fin_course + 0.05, null])
				# Au sol jusqu'à la prise (le tracé du ballon ne compte plus tant qu'il est porté).
				bal.t.append(prise + 0.1)
				bal.p.append(Vector3(arrivee_ballon.x, arrivee_ballon.y, 0.12))
				bal.t.append(fin_course + 0.05)
				bal.p.append(Vector3(but.x, but.y, 1.0))
				bal.t.append(fin_course + 0.3)
				bal.p.append(Vector3(ballon_melee.x, ballon_melee.y, 0.12))
		elif continue_ok:
			_courir(j, but, t0, duree_plan_a - 0.35 - rng.randf_range(0.0, 0.3), trot)
		else:
			# Premiers pas vers la remise en jeu, au trot ou en marchant, jusqu'à la coupe.
			var reste := maxf(0.0, duree_plan_a - t0)
			var pas := minf(j.arret.distance_to(but), trot * 0.75 * reste)
			if pas > 0.8:
				j.courses.append({"t0": t0, "t1": duree_plan_a + 0.5, "a": j.arret, "b": j.arret + (but - j.arret).normalized() * pas * (duree_plan_a + 0.5 - t0) / maxf(0.1, reste)})
	# --- Gestes du plan A : arbitre, capitaine, détails.
	var arbitre_a := _place_arbitre(type, marque, dir)
	var programme: Array = [{"plan": 0, "t": 0.0, "lieu": arbitre_a, "signal": "sifflet"},
		{"plan": 0, "t": 0.5, "lieu": arbitre_a, "signal": "bras", "direction": _direction_bras(type, info, dir), "hauteur": 1.0 if type.begins_with("penalite") else 0.0},
		{"plan": 0, "t": 2.1, "lieu": arbitre_a, "signal": ""}]
	if not botteur.is_empty():
		trajets[botteur].etats.append([0.0, "jeu_au_pied"])
		trajets[botteur].etats.append([0.8, "course"])
	var capitaine := ""
	if not str(info.choix).is_empty() and str(info.choix) != "main":
		capitaine = _capitaine(trajets, equipe, ramasseur, arbitre_a, rng)
		if not capitaine.is_empty():
			var j: Trajet = trajets[capitaine]
			var vise := _vise_choix(str(info.choix), j.position(1.2), marque, dir)
			j.etats.append([0.9, "montre"])
			j.etats.append([2.2, "course"])
			j.regard = vise
			# Il s'arrête pour indiquer : sa course part après le geste.
			for c: Dictionary in j.courses: c.t0 = maxf(float(c.t0), 2.2)
			_reajuster(j)
	# Détail vivant, jamais le même deux liaisons de suite.
	var possibles: Array = DETAILS.filter(func(d: String) -> bool: return d != precedent)
	var detail: String = possibles[rng.randi() % possibles.size()]
	var figurants: Array = trajets.keys().filter(func(id: String) -> bool: return id != ramasseur and id != capitaine and id != porteur and id != botteur)
	figurants.sort()
	_details(detail, trajets, figurants, duree_plan_a, rng, equipe, type, info)
	if bool(info.get("points", false)) and (type == "renvoi" or bool(info.get("coupe_forcee", false))):
		# Points marqués à la fin du temps fort précédent : l'équipe qui a marqué se félicite.
		var marqueur := 1 - equipe if type == "renvoi" else int(info.get("marqueur", 1 - equipe))
		_celebration(trajets, figurants, 1 - marqueur, rng)
	# --- Pistes du plan A.
	var regard_a := marque if type in ["touche", "melee", "penalite", "renvoi_22"] else Vector2(50, 35)
	var pistes_a := _pistes(trajets, duree_plan_a, regard_a, bal, porteurs, type, false)
	pistes_a["liaison"] = type
	var plans: Array = [pistes_a]
	var tenue: Dictionary = {}
	var programme_b: Array = []
	if coupe:
		# --- Plan B après la coupe : remise en jeu formée, derniers pas.
		var b: Dictionary = {}
		for id: String in cibles:
			var j0: Trajet = trajets[id]
			var depuis_a := j0.position(duree_plan_a)
			var but: Vector2 = cibles[id]
			var d := minf(DERNIERS_PAS * rng.randf_range(0.5, 1.0), depuis_a.distance_to(but))
			var de := but - (but - depuis_a).normalized() * d if depuis_a.distance_to(but) > 0.01 else but
			var j := _trajet(id, int(sides[id]), int(slots[id]), de, Vector2.ZERO)
			var fin := rng.randf_range(0.8, 1.2)
			if d > 0.15:
				j.courses.append({"t0": 0.0, "t1": fin, "a": de, "b": but})
			b[id] = j
		var bal_b := {"t": [0.0], "p": []}
		var porteurs_b: Array = []
		var tenant := ramasseur if trajets.has(ramasseur) else ""
		if type == "penalite" and b.has(tenant):
			# Botteur qui pose le ballon sur sa marque, puis se relève face aux poteaux.
			var j: Trajet = b[tenant]
			j.courses.clear()
			j.p0 = cibles[tenant]
			j.arret = cibles[tenant]
			j.etats = [[0.0, "placement"], [0.9, "course"]]
			bal_b.p.append(Vector3(marque.x, marque.y, 0.12))
			porteurs_b.append([0.0, null])
		elif type == "melee":
			bal_b.p.append(Vector3(ballon_melee.x, ballon_melee.y, 0.12))
			porteurs_b.append([0.0, null])
		else:
			var tient: Vector2 = cibles.get(tenant, marque)
			bal_b.p.append(Vector3(tient.x, tient.y, 1.0))
			porteurs_b.append([0.0, tenant if not tenant.is_empty() else null])
		if type == "melee":
			tenue = _melee(b, equipe)
		var pistes_b := _pistes(b, PLAN_B, regard_a, bal_b, porteurs_b, type, true)
		pistes_b["liaison"] = type
		plans.append(pistes_b)
		programme_b = [{"plan": 1, "t": 0.0, "lieu": _place_arbitre_formee(type, marque, dir, equipe), "signal": ""}]
	else:
		if type == "penalite" and trajets.has(ramasseur):
			var j: Trajet = trajets[ramasseur]
			j.etats.append([duree_plan_a - 1.0, "placement"])
			j.etats.append([duree_plan_a - 0.2, "course"])
			pistes_a = _pistes(trajets, duree_plan_a, regard_a, bal, porteurs, type, false)
			pistes_a["liaison"] = type
			plans[0] = pistes_a
		if type == "melee":
			tenue = _melee(trajets, equipe)
			pistes_a = _pistes(trajets, duree_plan_a, regard_a, bal, porteurs, type, false)
			pistes_a["liaison"] = type
			plans[0] = pistes_a
	programme.append_array(programme_b)
	var total := 0.0
	for p: Dictionary in plans: total += float(p.duree)
	return {"type": type, "choix": info.choix, "coupe": coupe, "plans": plans, "duree": total, "arbitre": programme,
		"detail": detail, "tenue": tenue, "texte": str(info.get("texte", "")), "ramasseur": ramasseur, "capitaine": capitaine}


static func _reajuster(j: Trajet) -> void:
	for c: Dictionary in j.courses:
		if float(c.t1) - float(c.t0) < 0.6: c.t1 = float(c.t0) + 0.6


## Mêlée : piliers et talonneurs en flexion puis liés à la fin de la liaison, tenus pendant la
## mêlée (rendu : tenue de pose de la vue, relâchée à la sortie du ballon).
static func _melee(trajets: Dictionary, _equipe: int) -> Dictionary:
	var tenue: Dictionary = {}
	for id: String in trajets:
		var j: Trajet = trajets[id]
		var fin := 0.0
		for c: Dictionary in j.courses: fin = maxf(fin, float(c.t1))
		if j.slot in [0, 1, 2]:
			j.etats.append([fin + 0.05, "flexion"])
			tenue[id] = [0.62, -0.24]
		elif j.slot in [3, 4, 5, 6, 7]:
			j.etats.append([fin + 0.1, "flexion"])
			tenue[id] = [0.62, -0.24]
	return tenue


static func _capitaine(trajets: Dictionary, equipe: int, exclu: String, pres: Vector2, rng: RandomNumberGenerator) -> String:
	var candidats: Array = []
	for id: String in trajets:
		var j: Trajet = trajets[id]
		if j.side == equipe and id != exclu and j.slot in [1, 5, 6, 7, 9, 11]:
			candidats.append([j.arret.distance_to(pres), id])
	candidats.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] or (a[0] == b[0] and str(a[1]) < str(b[1])))
	if candidats.is_empty(): return ""
	return candidats[mini(rng.randi() % 2, candidats.size() - 1)][1]


static func _vise_choix(choix: String, depuis: Vector2, marque: Vector2, dir: float) -> Vector2:
	match choix:
		"poteaux": return Vector2(100.0 if dir > 0.0 else 0.0, 35.0)
		"touche": return Vector2(depuis.x + dir * 12.0, 0.0 if depuis.y < 35.0 else 70.0)
		_: return marque


static func _direction_bras(type: String, _info: Dictionary, dir: float) -> Vector2:
	if type == "renvoi": return Vector2(0.0, 0.0)
	return Vector2(dir, 0.0)


static func _place_arbitre(type: String, marque: Vector2, dir: float) -> Vector2:
	match type:
		"touche": return Vector2(marque.x - dir * 4.0, 9.0 if marque.y < 35.0 else 61.0)
		"melee": return Vector2(marque.x, marque.y - 7.0 if marque.y > 12.0 else marque.y + 7.0)
		"renvoi": return Vector2(50.0 + 6.0, 27.0)
		_: return Vector2(marque.x - dir * 3.0, marque.y - 4.0 if marque.y > 10.0 else marque.y + 4.0)


static func _place_arbitre_formee(type: String, marque: Vector2, dir: float, _equipe: int) -> Vector2:
	match type:
		"touche": return Vector2(marque.x - dir * 3.0, 17.0 if marque.y < 35.0 else 53.0)
		# À côté de la mêlée, hors des deux paquets (les avants s'étendent à 3 m de part et d'autre de la marque).
		"melee": return Vector2(marque.x + 1.0, marque.y - 6.5 if marque.y > 10.0 else marque.y + 6.5)
		"renvoi": return Vector2(50.0 + 10.0, 22.0)
		_: return Vector2(marque.x - dir * 5.0, marque.y - 6.0 if marque.y > 10.0 else marque.y + 6.0)


## Petit détail vivant, sur un ou deux figurants qui attendent (jamais sur un joueur en course).
static func _details(detail: String, trajets: Dictionary, figurants: Array, duree: float, rng: RandomNumberGenerator, equipe: int, _type: String, _info: Dictionary) -> void:
	var libres: Array = []
	for id: String in figurants:
		var j: Trajet = trajets[id]
		var depart := duree
		for c: Dictionary in j.courses: depart = minf(depart, float(c.t0))
		var attente := depart - (j.t_arret + 0.2)
		if attente >= 1.0: libres.append([attente, id, j.t_arret + 0.2, depart])
	libres.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0] or (a[0] == b[0] and str(a[1]) < str(b[1])))
	# Mains sur les hanches : quelques joueurs qui attendent, toujours (sobre).
	for k in mini(3, libres.size()):
		var l: Array = libres[k]
		if rng.randf() < 0.6:
			trajets[l[1]].etats.append([float(l[2]) + 0.1, "mains_hanches"])
			trajets[l[1]].etats.append([float(l[3]) - 0.15, "course"])
	if libres.is_empty():
		return
	var choisi: Array = libres[rng.randi() % mini(4, libres.size())]
	var j: Trajet = trajets[choisi[1]]
	var debut := float(choisi[2]) + 0.15
	var fin := float(choisi[3]) - 0.15
	j.etats = j.etats.filter(func(e: Array) -> bool: return float(e[0]) < debut - 0.01 or float(e[0]) > fin + 0.01)
	match detail:
		"strap":
			j.etats.append([debut, "strap"])
			j.etats.append([minf(fin, debut + 1.6), "course"])
		"souffle":
			j.etats.append([debut, "souffle"])
			j.etats.append([minf(fin, debut + 1.4), "course"])
		"capitaine_parle":
			# Un joueur parle à deux coéquipiers proches, qui se tournent vers lui.
			j.etats.append([debut, "explique"])
			j.etats.append([fin, "course"])
			var proches := 0
			for l: Array in libres:
				var autre: Trajet = trajets[l[1]]
				if autre.id != j.id and autre.side == j.side and autre.arret.distance_to(j.arret) < 8.0 and proches < 2:
					autre.regard = j.arret
					proches += 1
		_:
			j.etats.append([debut, "mains_hanches"])
			j.etats.append([fin, "course"])


## Après un essai : deux joueurs de l'équipe qui a marqué se félicitent, un adversaire est déçu.
static func _celebration(trajets: Dictionary, figurants: Array, equipe: int, rng: RandomNumberGenerator) -> void:
	var marqueurs := 0
	var decus := 0
	for id: String in figurants:
		var j: Trajet = trajets[id]
		if j.side != equipe and marqueurs < 2 and rng.randf() < 0.7:
			j.etats = j.etats.filter(func(e: Array) -> bool: return float(e[0]) > 2.4)
			j.etats.append([0.15 + 0.3 * marqueurs, "joie"])
			j.etats.append([2.4, "course"])
			for c: Dictionary in j.courses: c.t0 = maxf(float(c.t0), 2.4)
			_reajuster(j)
			marqueurs += 1
		elif j.side == equipe and decus < 1 and rng.randf() < 0.5:
			j.etats = j.etats.filter(func(e: Array) -> bool: return float(e[0]) > 2.6)
			j.etats.append([0.4, "deception"])
			j.etats.append([2.6, "course"])
			for c: Dictionary in j.courses: c.t0 = maxf(float(c.t0), 2.6)
			_reajuster(j)
			decus += 1


## Échantillonne les trajets au pas PAS : pistes du chorégraphe (version 2).
static func _pistes(trajets: Dictionary, duree: float, regard_defaut: Vector2, bal: Dictionary, porteurs: Array, type: String, coupe: bool) -> Dictionary:
	var n := int(round(duree / PAS)) + 1
	duree = float(n - 1) * PAS
	var joueurs: Array = []
	var ids: Array = trajets.keys()
	ids.sort()
	for id: String in ids:
		var j: Trajet = trajets[id]
		var xs: Array = []
		var ys: Array = []
		var vs: Array = []
		var caps: Array = []
		var precedent := j.position(0.0)
		var cap := j.v0.angle() if j.v0.length() > 0.5 else (regard_defaut - precedent).angle()
		for k in n:
			var t := float(k) * PAS
			var p := j.position(t)
			var suivant := j.position(t + PAS)
			var mouvement := suivant - p
			var v := mouvement.length() / PAS
			var regard: Vector2 = j.regard if j.regard != Vector2.ZERO else regard_defaut
			var voulu := mouvement.angle() if v > 0.5 else ((regard - p).angle() if (regard - p).length() > 0.5 else cap)
			# Rotation bornée : 4 rad/s, jamais de volte-face instantanée.
			cap += clampf(angle_difference(cap, voulu), -4.0 * PAS, 4.0 * PAS)
			xs.append(p.x)
			ys.append(p.y)
			vs.append(v)
			caps.append(cap)
			precedent = p
		var etats := j.etats.duplicate()
		etats.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
		joueurs.append({"id": j.id, "side": j.side, "x": xs, "y": ys, "v": vs, "cap": caps, "etats": etats})
	porteurs = porteurs.duplicate()
	porteurs.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	# Ballon : interpolation linéaire entre ses repères (sortie, chute, repos).
	var bx: Array = []
	var by: Array = []
	var bh: Array = []
	var ts: Array = bal.t
	var ps: Array = bal.p
	for k in n:
		var t := float(k) * PAS
		var p: Vector3 = ps[0]
		for i in range(ps.size() - 1, -1, -1):
			if i < ts.size() and t >= float(ts[i]):
				if i + 1 < ps.size() and i + 1 < ts.size():
					p = (ps[i] as Vector3).lerp(ps[i + 1], clampf((t - float(ts[i])) / maxf(0.001, float(ts[i + 1]) - float(ts[i])), 0.0, 1.0))
				else:
					p = ps[i]
				break
		bx.append(p.x)
		by.append(p.y)
		bh.append(maxf(0.1, p.z))
	return {"version": VERSION, "pas": PAS, "duree": duree, "coupe": coupe, "type": "liaison_" + type, "joueurs": joueurs,
		"ballon": {"x": bx, "y": by, "h": bh, "porteurs": porteurs}, "evenements": []}

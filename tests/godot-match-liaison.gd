extends SceneTree
## Liaison entre deux temps forts contigus (native/godot/match_liaison.gd), sur des temps forts
## construits ici : contiguïté reconnue ou refusée, type de liaison, coupe franche quand la mise en
## place serait longue, aucune accélération (durées fixes, en secondes réelles), aucun saut de
## position à l'intérieur d'un plan, départ depuis les places à l'écran et arrivée aux places du
## moteur, déterminisme et détail jamais répété deux fois de suite. Lancé par godot-match-liaison.cjs.

const Liaison = preload("res://match_liaison.gd")

var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("run")


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)


## Quinze joueurs par équipe ; `formation` : places du moteur (cible), `ecart` : où ils sont à l'écran.
func joueurs(centre: Vector2, ecart: float, equipe: int) -> Array:
	var liste: Array = []
	for side in 2:
		for slot in 15:
			var p := centre + Vector2((slot % 5) * 1.6 - 3.2 + (side * 2 - 1) * 1.2, (slot / 5) * 3.0 + (side * 0.8)) * ecart
			liste.append({"id": "%d-%d" % [side, slot], "side": side, "slot": slot, "x": clampf(p.x, 1.0, 99.0), "y": clampf(p.y, 1.0, 69.0),
				"featured": side == equipe and slot == 9})
	return liste


func ecran(liste: Array, decalage: Vector2, vitesse: Vector2) -> Dictionary:
	var vus: Dictionary = {}
	for p: Dictionary in liste:
		vus[p.id] = {"p": Vector2(p.x, p.y) + decalage, "v": vitesse}
	return vus


func temps_forts(fin_kind: String, entre: Array, kind: String, scene: Dictionary, suite := false) -> Array:
	var events: Array = [{"scene": {"kind": "carry"}, "text": "Jeu."}, {"scene": {"kind": fin_kind}, "text": "Fin du temps fort."}]
	for e: Dictionary in entre:
		events.append({"scene": e, "text": "Arrêt : " + str(e.kind) + "."})
	events.append({"scene": {"kind": kind}, "text": "Remise en jeu."})
	var tf1 := {"cle": "a", "plans": [{"index": 1, "kind": fin_kind, "scene": {}}], "debut": 0, "fin": 1}
	var tf2 := {"cle": "b", "suite": suite, "plans": [{"index": events.size() - 1, "kind": kind, "scene": scene}], "debut": 2, "fin": events.size() - 1}
	return [tf1, tf2, events]


## Aucun saut dans un plan ; rend la vitesse la plus forte (m/s).
func sans_saut(pistes: Dictionary, nom: String) -> float:
	var pas := float(pistes.pas)
	var pire := 0.0
	for j: Dictionary in pistes.joueurs:
		for k in range(1, (j.x as Array).size()):
			var d := Vector2(float(j.x[k]) - float(j.x[k - 1]), float(j.y[k]) - float(j.y[k - 1])).length() / pas
			if d > float(OS.get_environment("CD_LIAISON_DEBUG")) and OS.get_environment("CD_LIAISON_DEBUG") != "": print(nom, " ", j.id, " k=", k, " v=", d, " etats=", j.etats)
			pire = maxf(pire, d)
	check(pire <= 9.0, "%s : aucun saut dans un plan (pointe %.1f m/s)" % [nom, pire])
	return pire


func depart_et_arrivee(lien: Dictionary, vus: Dictionary, cible: Array, nom: String) -> void:
	var a: Dictionary = lien.plans[0]
	var pire_depart := 0.0
	for j: Dictionary in a.joueurs:
		pire_depart = maxf(pire_depart, Vector2(float(j.x[0]), float(j.y[0])).distance_to(vus[j.id].p))
	check(pire_depart < 0.01, "%s : la liaison part des places à l'écran (écart %.3f m)" % [nom, pire_depart])
	var dernier: Dictionary = lien.plans[-1]
	var places: Dictionary = {}
	for p: Dictionary in cible: places[p.id] = Vector2(p.x, p.y)
	var pire_arrivee := 0.0
	for j: Dictionary in dernier.joueurs:
		pire_arrivee = maxf(pire_arrivee, Vector2(float(j.x[-1]), float(j.y[-1])).distance_to(places[j.id]))
	check(pire_arrivee < 0.05, "%s : chacun finit à sa place du moteur (écart %.3f m)" % [nom, pire_arrivee])


func run() -> void:
	# --- Touche : coup de pied en touche non montré, avants loin de l'alignement → coupe franche.
	var alignement := joueurs(Vector2(40, 6), 1.0, 0)
	var donnees := temps_forts("turnover", [{"kind": "touch", "from": {"x": 30, "y": 30}, "to": {"x": 40, "y": 0}, "cause": "direct-touch"}],
		"lineout", {"possession": 0, "origin": {"x": 40, "y": 0}, "ball": {"x": 40, "y": 0}, "players": alignement})
	var info := Liaison.analyser(donnees[0], donnees[1], donnees[2])
	check(str(info.get("type", "")) == "touche", "Touche reconnue : " + str(info.get("type", "")))
	check(not (info.get("sortie", {}) as Dictionary).is_empty(), "Sortie en touche à montrer (coup de pied non montré)")
	check(str(info.get("texte", "")).contains("touch"), "Légende : le fait d'arrêt de jeu")
	var vus := ecran(alignement, Vector2(-8, 26), Vector2(3.0, 0.5))
	var lien := Liaison.construire(info, vus, {"p": Vector3(-20.0, 1.0, -5.0), "porteur": "1-9"}, Vector2(50, 35), 1234)
	check(bool(lien.get("coupe", false)) and (lien.plans as Array).size() == 2, "Mise en place longue : coupe franche, deux plans")
	check(float(lien.plans[0].duree) >= 1.5 and float(lien.plans[0].duree) <= 3.4, "Plan en temps réel avant la coupe : %.1f s" % float(lien.plans[0].duree))
	check(float(lien.plans[1].duree) >= 1.0 and float(lien.plans[1].duree) <= 2.1, "Après la coupe : %.1f s" % float(lien.plans[1].duree))
	check(bool(lien.plans[1].coupe) and not bool(lien.plans[0].coupe), "Seul le plan B part d'une coupe")
	for k in (lien.plans as Array).size(): sans_saut(lien.plans[k], "Touche, plan %d" % k)
	depart_et_arrivee(lien, vus, alignement, "Touche")
	check(lien.plans[1].ballon.porteurs[0][1] == "0-1", "Après la coupe, le talonneur a le ballon")
	check((lien.arbitre as Array).any(func(e: Dictionary) -> bool: return e.signal == "sifflet") and (lien.arbitre as Array).any(func(e: Dictionary) -> bool: return e.signal == "bras"), "Arbitre : sifflet puis bras")
	# Même graine, même liaison ; autre détail que le précédent.
	var encore := Liaison.construire(info, vus, {"p": Vector3(-20.0, 1.0, -5.0), "porteur": "1-9"}, Vector2(50, 35), 1234)
	check(JSON.stringify(encore) == JSON.stringify(lien), "Déterministe : même graine, même liaison")
	for graine in 12:
		var a := Liaison.construire(info, vus, {"p": Vector3(-20.0, 1.0, -5.0), "porteur": ""}, Vector2(50, 35), graine, "strap")
		check(str(a.detail) != "strap", "Détail jamais répété deux fois de suite (graine %d)" % graine)
	# --- Mêlée proche : liaison continue, sans coupe, 4,6 s au plus.
	var melee := joueurs(Vector2(60, 30), 1.0, 1)
	donnees = temps_forts("turnover", [{"kind": "hand-fault"}], "scrum", {"possession": 1, "origin": {"x": 60, "y": 32}, "ball": {"x": 60, "y": 32}, "players": melee})
	info = Liaison.analyser(donnees[0], donnees[1], donnees[2])
	check(str(info.get("type", "")) == "melee", "Mêlée reconnue")
	vus = ecran(melee, Vector2(-2.5, 1.5), Vector2(1.5, 0.0))
	lien = Liaison.construire(info, vus, {"p": Vector3(9.0, 0.1, -3.0), "porteur": ""}, Vector2(55, 25), 77)
	check(not bool(lien.coupe) and (lien.plans as Array).size() == 1, "Mise en place courte : liaison continue")
	check(float(lien.duree) >= 3.0 and float(lien.duree) <= 4.7, "Liaison continue de 3 à 4,6 s : %.1f s" % float(lien.duree))
	var pointe := sans_saut(lien.plans[0], "Mêlée continue")
	check(pointe <= 6.5, "Mise en place au trot, jamais en sprint (%.1f m/s)" % pointe)
	depart_et_arrivee(lien, vus, melee, "Mêlée")
	check(lien.plans[0].ballon.porteurs.any(func(p: Array) -> bool: return p[1] != null and str(p[1]).begins_with("1-")), "Un avant de l'équipe qui introduit ramasse le ballon")
	var bal_fin := Vector2(float(lien.plans[0].ballon.x[-1]), float(lien.plans[0].ballon.y[-1]))
	check(bal_fin.distance_to(Vector2(60, 32)) < 0.05 and lien.plans[0].ballon.porteurs[-1][1] == null, "Le ballon finit posé à la marque de la mêlée")
	check(not (lien.tenue as Dictionary).is_empty(), "Avants liés tenus pendant la mêlée")
	# --- Pénalité tentée : capitaine qui montre les poteaux, botteur qui pose le ballon.
	var penalite := joueurs(Vector2(70, 30), 1.0, 0)
	donnees = temps_forts("penalty", [{"kind": "advantage"}], "goal", {"possession": 0, "origin": {"x": 72, "y": 30}, "ball": {"x": 100, "y": 35}, "players": penalite})
	info = Liaison.analyser(donnees[0], donnees[1], donnees[2])
	check(str(info.get("type", "")) == "penalite" and str(info.choix) == "poteaux", "Pénalité tentée : choix des poteaux lu dans le moteur")
	lien = Liaison.construire(info, ecran(penalite, Vector2(-1, 2), Vector2.ZERO), {"p": Vector3(20.0, 1.0, -5.0), "porteur": "0-3"}, Vector2(60, 25), 5)
	var montre := false
	var pose := false
	for plan: Dictionary in lien.plans:
		for j: Dictionary in plan.joueurs:
			for e: Array in j.etats:
				if e[1] == "montre": montre = true
				if e[1] == "placement" and j.id == "0-9": pose = true
	check(montre and str(lien.capitaine) != "", "Le capitaine indique le choix")
	check(pose, "Le botteur pose le ballon")
	for k in (lien.plans as Array).size(): sans_saut(lien.plans[k], "Pénalité, plan %d" % k)
	# --- Renvoi après un essai transformé : joie, retour au centre (coupe), formation de renvoi.
	var renvoi := joueurs(Vector2(50, 25), 1.4, 1)
	donnees = temps_forts("transformation", [], "kickoff", {"possession": 1, "origin": {"x": 50, "y": 35}, "ball": {"x": 50, "y": 35}, "players": renvoi})
	info = Liaison.analyser(donnees[0], donnees[1], donnees[2])
	check(str(info.get("type", "")) == "renvoi", "Renvoi après essai reconnu")
	vus = ecran(renvoi, Vector2(42, 5), Vector2.ZERO)
	lien = Liaison.construire(info, vus, {"p": Vector3(48.0, 2.0, 0.0), "porteur": ""}, Vector2(80, 30), 9)
	check(bool(lien.coupe), "Retour au centre : coupe franche")
	var joie := false
	for j: Dictionary in lien.plans[0].joueurs:
		for e: Array in j.etats: if e[1] == "joie": joie = true
	check(joie, "Célébration courte avant la coupe")
	depart_et_arrivee(lien, vus, renvoi, "Renvoi")
	# --- Renvoi aux 22 : reconnu.
	donnees = temps_forts("ingoal", [], "goalLine", {"possession": 0, "origin": {"x": 0, "y": 35}, "players": joueurs(Vector2(8, 30), 1.0, 0)})
	check(str(Liaison.analyser(donnees[0], donnees[1], donnees[2]).get("type", "")) == "renvoi_22", "Renvoi d'en-but reconnu")
	# --- Pas contigus : du jeu entre les deux, ou suite de la même action → aucune liaison.
	donnees = temps_forts("turnover", [{"kind": "touch"}, {"kind": "lineout"}, {"kind": "setpiece-loss"}], "carry", {"possession": 0, "players": alignement})
	check(Liaison.analyser(donnees[0], donnees[1], donnees[2]).is_empty(), "Touche jouée entre les deux : pas contigus")
	donnees = temps_forts("carry", [{"kind": "kickoff"}, {"kind": "reception"}], "scrum", {"possession": 0, "players": melee})
	check(Liaison.analyser(donnees[0], donnees[1], donnees[2]).is_empty(), "Jeu courant puis renvoi et réception : pas de liaison")
	# Essai transformé, renvoi joué (non montré), touche : célébration puis coupe vers l'alignement formé.
	donnees = temps_forts("transformation", [{"kind": "kickoff"}, {"kind": "reception"}, {"kind": "touch", "from": {"x": 50, "y": 30}, "to": {"x": 40, "y": 0}, "cause": "direct-touch"}],
		"lineout", {"possession": 0, "origin": {"x": 40, "y": 0}, "players": alignement})
	donnees[0].plans[0].scene = {"possession": 1}
	info = Liaison.analyser(donnees[0], donnees[1], donnees[2])
	check(str(info.get("type", "")) == "touche" and bool(info.get("coupe_forcee", false)) and (info.sortie as Dictionary).is_empty(), "Après l'essai, renvoi joué : touche par coupe, sans sortie animée")
	lien = Liaison.construire(info, ecran(alignement, Vector2(-5, 3), Vector2.ZERO), {"p": Vector3(48.0, 2.0, 0.0), "porteur": ""}, Vector2(80, 30), 21)
	check(bool(lien.coupe) and (lien.plans as Array).size() == 2, "Jeu non montré entre les deux : toujours une coupe")
	var joie_1 := false
	for j: Dictionary in lien.plans[0].joueurs:
		for e: Array in j.etats: if e[1] == "joie" and str(j.id).begins_with("1-"): joie_1 = true
	check(joie_1, "L'équipe qui a marqué se félicite avant la coupe")
	# En-avant, puis mêlée et jeu non montrés, puis touche : le plan A reste sur l'en-avant (aucun pas vers
	# l'alignement qui se formera ailleurs), légende et bandeau de cet arrêt ; la coupe mène à la touche.
	donnees = temps_forts("hand-fault", [{"kind": "scrum"}, {"kind": "carry"}, {"kind": "touch", "from": {"x": 45, "y": 20}, "to": {"x": 40, "y": 0}, "cause": "carry-touch"}],
		"lineout", {"possession": 0, "origin": {"x": 40, "y": 0}, "players": alignement})
	donnees[0].plans[0].scene = {"possession": 0}
	donnees[2][1].scene["team"] = 0
	info = Liaison.analyser(donnees[0], donnees[1], donnees[2])
	check(str(info.get("type", "")) == "touche" and bool(info.get("coupe_forcee", false)), "En-avant puis jeu puis touche : touche par coupe")
	vus = ecran(joueurs(Vector2(15, 35), 1.0, 0), Vector2.ZERO, Vector2.ZERO)
	lien = Liaison.construire(info, vus, {"p": Vector3(-35.0, 0.1, 0.0), "porteur": ""}, Vector2(20, 30), 31)
	check(bool(lien.coupe) and (lien.plans as Array).size() == 2 and float(lien.plans[0].duree) <= 2.0, "Plan A court sur l'en-avant, puis coupe (%s)" % str((lien.plans as Array).map(func(p: Dictionary) -> float: return float(p.duree))))
	var derive := 0.0
	for j: Dictionary in lien.plans[0].joueurs:
		derive = maxf(derive, Vector2(float(j.x[-1]) - float(j.x[0]), float(j.y[-1]) - float(j.y[0])).length())
	check(derive < 0.5, "Plan A : personne ne part vers l'alignement à venir (%.1f m au plus)" % derive)
	check(str(lien.bandeaux[0].libelle) == "En-avant" and int(lien.bandeaux[0].equipe) == 0 and str(lien.bandeaux[1].libelle) == "Touche" and int(lien.bandeaux[1].equipe) == 0,
		"Bandeau : l'en-avant, puis la touche (%s)" % str(lien.bandeaux))
	check(str(lien.textes[0]) == "Fin du temps fort." and str(lien.textes[1]).contains("touch") and int(lien.arrets[0]) == 1, "Légende et journal : l'arrêt montré dans chaque plan (%s)" % str(lien.textes))
	var arbitre_a: Vector2 = lien.arbitre[0].lieu
	check(arbitre_a.distance_to(Vector2(15, 35)) < 8.0, "Plan A : l'arbitre est près de l'en-avant, pas à la touche (%s)" % str(arbitre_a))
	donnees = temps_forts("touch", [], "lineout", {"possession": 0, "origin": {"x": 40, "y": 0}, "players": alignement}, true)
	check(Liaison.analyser(donnees[0], donnees[1], donnees[2]).is_empty(), "Suite de la même action : pas de liaison")
	donnees = temps_forts("carry", [], "carry", {"possession": 0, "players": alignement})
	check(Liaison.analyser(donnees[0], donnees[1], donnees[2]).is_empty(), "Jeu courant qui continue : pas de liaison")
	print("Liaison : ", checks, " contrôles ; ", failures.size(), " échec(s)")
	for f in failures: print("ÉCHEC : ", f)
	quit(0 if failures.is_empty() else 1)

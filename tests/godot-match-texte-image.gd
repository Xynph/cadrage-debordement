extends SceneTree
## Texte et image du match 3D en temps forts : le journal ouvert, le bandeau du haut et la ligne météo
## ne disent un fait qu'au début de sa lecture 3D, jamais quand le moteur le calcule ou que la régie le
## met en file. Fixture de temps fort (forme de native/engine/match-direct.cjs), régie hors arbre :
## essai pas encore aplati, transformation et tir au but avant la frappe, pistes avant leur jalon,
## mi-temps atteinte par le moteur pendant la dernière action.
const Regie = preload("res://ui/contextual/match_temps_forts.gd")
const Meteo = preload("res://ui/contextual/meteo_texte.gd")
const Between = preload("res://ui/contextual/match_between.gd")
const Terrain2D = preload("res://ui/contextual/match_terrain_2d.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("ECHEC : ", message)

func textes(live: Dictionary) -> Array:
	return (live.get("events", []) as Array).map(func(e: Variant) -> String: return str(e.get("text", "")) if e is Dictionary else str(e))

## Régie posée sur le plan `k` du temps fort, dans la phase donnée.
func poser(regie: Node, k: int, phase: String, temps: float, essai_montre: bool = true, jalon_montre: bool = false) -> void:
	regie.etat = Regie.JEU
	regie.index = k
	regie.phase = phase
	regie.temps = temps
	regie._essai_montre = essai_montre
	regie._jalon_montre = jalon_montre

func run() -> void:
	var equipes := [{"name": "Domicile XV", "abbr": "DOM"}, {"name": "Visiteurs XV", "abbr": "VIS"}]
	var events := [
		{"min": 10, "text": "Coup d'envoi."},
		{"min": 11, "text": "Course de Martin."},
		{"min": 12, "text": "Essai de Bernard, transformé par Petit : 7-0."},
		{"min": 14, "text": "Pénalité réussie par Petit : 10-0."},
	]
	var scene := {"possession": 0, "ball": {"x": 85.0, "y": 30.0}, "players": []}
	var plans := [
		{"index": 1, "kind": "carry", "texte": "Course de Martin.", "scene": scene},
		{"index": 2, "kind": "try", "texte": "Essai de Bernard.", "mouvement": 2.4, "duree": 3.4, "scene": scene},
		{"index": 2, "kind": "transformation", "annonce": "Transformation.", "texte": "Transformation réussie.", "scene": scene},
		{"index": 3, "kind": "goal", "annonce": "Tir au but.", "texte": "Pénalité réussie par Petit : 10-0.", "scene": scene},
	]
	var live := {"teams": equipes, "events": events, "minute": 14, "score": [10, 0]}
	var regie: Node = Regie.new()
	regie.tf = {"plans": plans}
	regie._events = events
	regie._teams = equipes
	regie._vus = 1

	# Course : son fait est au journal dès le début du plan.
	poser(regie, 0, "jeu", 0.0)
	check(textes(regie.montre(live)) == ["Coup d'envoi.", "Course de Martin."], "Course : le journal dit le plan en cours, rien après (" + str(textes(regie.montre(live))) + ")")

	# Essai joué mais pas encore aplati : ni la légende ni le journal ne l'annoncent.
	poser(regie, 1, "jeu", 1.0, false)
	var avant := textes(regie.montre(live))
	check(avant == ["Coup d'envoi.", "Course de Martin."], "Essai pas encore aplati : absent du journal (" + str(avant) + ")")
	check(not Regie.fait_a_l_ecran(plans[1], "jeu", 1.0, false, false), "Essai pas encore aplati : pas à l'écran")

	# Essai aplati : il entre au journal, sans sa transformation ni le score.
	poser(regie, 1, "jeu", 2.5, true)
	var aplati := textes(regie.montre(live))
	check(aplati.size() == 3 and aplati[2] == "Essai de Bernard.", "Essai aplati : au journal sans la transformation (" + str(aplati) + ")")
	check(str(events[2].text).contains("transformé"), "Le journal du moteur n'est pas modifié")

	# Transformation : pose « prêt » puis frappe ; le résultat n'entre qu'après RESULTAT.
	poser(regie, 2, "pret", 0.5)
	check(textes(regie.montre(live)) == ["Coup d'envoi.", "Course de Martin.", "Essai de Bernard."], "Transformation, pose prêt : l'essai reste au journal, sans le résultat")
	poser(regie, 2, "jeu", Regie.RESULTAT - 0.1)
	check(textes(regie.montre(live))[2] == "Essai de Bernard.", "Transformation avant le résultat : rien du tir au journal")
	poser(regie, 2, "jeu", Regie.RESULTAT + 0.1)
	check(textes(regie.montre(live))[2] == "Essai de Bernard, transformé par Petit : 7-0.", "Transformation vue : le journal donne le texte entier")

	# Tir au but : rien du résultat pendant la pose ni avant la frappe.
	poser(regie, 3, "pret", 0.0)
	check(textes(regie.montre(live)).size() == 3, "Tir au but, pose prêt : résultat absent du journal")
	poser(regie, 3, "jeu", 0.4)
	check(textes(regie.montre(live)).size() == 3, "Tir au but avant la frappe : résultat absent du journal")
	poser(regie, 3, "jeu", Regie.RESULTAT)
	check(textes(regie.montre(live)).size() == 4, "Tir au but vu : résultat au journal")

	# Pistes du chorégraphe : le fait attend son jalon.
	poser(regie, 0, "choregraphie", 0.0, true, false)
	check(textes(regie.montre(live)).size() == 1, "Pistes avant le jalon : le fait n'est pas au journal")
	poser(regie, 0, "choregraphie", 0.0, true, true)
	check(textes(regie.montre(live)).size() == 2, "Pistes au jalon : le fait entre au journal")

	# Faits déjà connus du joueur avant le temps fort : jamais retirés.
	regie._vus = 4
	poser(regie, 1, "jeu", 0.5, false)
	check(textes(regie.montre(live)).size() == 4, "Faits déjà connus : le journal les garde")
	regie._vus = 1

	# Outils de coupe.
	check(Regie.sans_transformation("Essai de Bernard, transformé par Petit : 7-0.") == "Essai de Bernard.", "Coupe de l'essai à la transformation")
	check(Regie.sans_transformation("Essai de pénalité.") == "Essai.", "Essai sans transformation dans le texte : « Essai. » (comme le moteur)")

	# Mi-temps atteinte par le moteur pendant la dernière action : bandeau du haut et ligne météo
	# disent l'action montrée, « Mi-temps » attend la fin du temps fort.
	var etat := Regie.etat_du_plan(plans[0], equipes)
	check(etat.contains("a le ballon dans les 22 mètres adverses") and not etat.contains("Mi-temps"), "Bandeau du haut pendant l'action : possession montrée (" + etat + ")")
	check(Regie.etat_du_plan({"kind": "carry"}, equipes) == "Le match", "Plan sans scène : bandeau neutre")
	var pause := {"teams": equipes, "atBreak": true, "period": 1, "meteo": {"libelle": "grand vent", "ventDos": [0, 1]}}
	check(Meteo.bandeau(pause).begins_with("Mi-temps"), "Le moteur est à la mi-temps (fixture)")
	var pendant := Meteo.bandeau(Regie.meteo_montree(pause, true))
	check(not pendant.begins_with("Mi-temps") and pendant.contains("1re période"), "Ligne météo pendant la dernière action : pas encore la mi-temps (" + pendant + ")")
	check(Meteo.bandeau(Regie.meteo_montree(pause, false)).begins_with("Mi-temps"), "Ligne météo après l'action : la mi-temps")
	check(bool(pause.atBreak), "Le modèle du moteur n'est pas modifié")

	# Ligne d'état du haut pendant un plan : le fait montré, jamais l'état du moteur.
	# Essai pas encore aplati : la possession du porteur, rien de l'essai ; aplati : « Essai — … ».
	var course := Regie.etat_montre(plans[1], "jeu", 1.0, false, false, equipes)
	check(course == "Domicile XV a le ballon dans les 22 mètres adverses", "Ligne d'état, essai pas encore aplati : la course du porteur (" + course + ")")
	var essai := Regie.etat_montre(plans[1], "jeu", 2.5, true, false, equipes)
	check(essai == "Essai — Domicile XV" and not essai.contains("a le ballon"), "Ligne d'état, essai aplati : l'essai, pas la possession en retard (" + essai + ")")
	check(Regie.etat_montre(plans[1], "choregraphie", 0.0, true, true, equipes) == "Essai — Domicile XV", "Ligne d'état, essai des pistes au jalon : l'essai")
	check(Regie.etat_montre(plans[2], "pret", 0.2, true, false, equipes) == "Transformation — Domicile XV", "Ligne d'état, transformation : l'arrêt, sans le résultat")
	# Touche pour l'autre équipe : la ligne nomme l'équipe qui lance, pas celle d'avant.
	var touche_plan := {"index": 3, "kind": "lineout", "texte": "Touche pour Visiteurs XV.", "scene": {"possession": 1, "team": 1, "ball": {"x": 40.0, "y": 0.0}, "players": []}}
	var touche := Regie.etat_montre(touche_plan, "jeu", 0.5, true, false, equipes)
	check(touche == "Touche pour Visiteurs XV" and not touche.contains("Domicile"), "Ligne d'état, touche de l'autre équipe : « Touche pour » l'équipe qui lance (" + touche + ")")
	check(Regie.etat_montre({"kind": "scrum", "scene": {"possession": 0, "ball": {"x": 50.0}}}, "jeu", 0.5, true, false, equipes) == "Mêlée pour Domicile XV", "Ligne d'état, mêlée : « Mêlée pour … »")
	# Match filmé du 25/11 : « X a le ballon dans les 22 » pendant l'en-avant de X, mêlée pour l'autre.
	var en_avant := Regie.etat_montre({"kind": "hand-fault", "scene": {"possession": 1, "ball": {"x": 80.0}}}, "jeu", 0.5, true, false, equipes)
	check(en_avant == "En-avant", "Ligne d'état, en-avant : l'arrêt de jeu, pas la possession (" + en_avant + ")")
	var penalite := Regie.etat_montre({"kind": "penalty", "scene": {"possession": 0, "ball": {"x": 60.0}}}, "jeu", 0.5, true, false, equipes)
	check(penalite == "Pénalité pour Domicile XV", "Ligne d'état, pénalité : « Pénalité pour … » (" + penalite + ")")
	# Vérificateur du 25/11 (16e) : carton jaune pendant l'arrêt de la pénalité, bandeau revenu à
	# « X a le ballon dans les 22 ». L'arrêt reste affiché pendant le carton (et un remplacement qui suit).
	var arret := [{"kind": "carry", "scene": {"possession": 1, "ball": {"x": 30.0}}},
		{"kind": "penalty", "scene": {"possession": 0, "ball": {"x": 70.0}}},
		{"kind": "card", "scene": {"possession": 1, "team": 1, "ball": {"x": 70.0}}},
		{"kind": "sub", "scene": {"possession": 1, "ball": {"x": 70.0}}},
		{"kind": "goal", "annonce": "Tir au but.", "scene": {"possession": 0, "ball": {"x": 100.0}}}]
	for i in [2, 3]:
		var etat_arret := Regie.etat_montre_dans(arret, i, "jeu", 0.5, true, false, equipes)
		check(etat_arret == "Pénalité pour Domicile XV", "Ligne d'état, %s pendant la pénalité : l'arrêt reste affiché (%s)" % [str(arret[i].kind), etat_arret])
	check(Regie.etat_montre_dans(arret, 0, "jeu", 0.5, true, false, equipes).contains("a le ballon"), "Ligne d'état, jeu courant : la possession")
	check(Regie.etat_montre_dans(arret, 4, "pret", 0.2, true, false, equipes) == "Tir au but — Domicile XV", "Ligne d'état, tir au but après le carton : le tir")
	# Vérificateur du 25/11 : bandeau de liaison « Pénalité Alder Fen XV » sans « pour ».
	check(Regie.texte_bandeau("Pénalité", "Domicile XV") == "Pénalité pour Domicile XV", "Bandeau de liaison : « Pénalité pour … »")
	check(Regie.texte_bandeau("Touche", "Domicile XV") == "Touche pour Domicile XV" and Regie.texte_bandeau("Mêlée", "Domicile XV") == "Mêlée pour Domicile XV", "Bandeau de liaison : « Touche pour … », « Mêlée pour … »")
	check(Regie.texte_bandeau("En-avant", "Domicile XV") == "En-avant — Domicile XV" and Regie.texte_bandeau("Ballon mort", "") == "Ballon mort", "Bandeau de liaison : fait « — équipe », libellé seul sans équipe")

	# Écran intermédiaire : le terrain 2D rejoue des faits en retard sur la borne du moteur ; la ligne
	# d'état suit le dernier fait joué (celui du bandeau du fil), pas le dernier fait de la borne
	# (constat du film : « Meadowbridge a le ballon dans son camp » sous une touche pour l'autre équipe).
	var terrain = Terrain2D.new()
	var deroule := [
		{"i": 5, "minute": 3, "horloge": "3′", "kind": "turnover", "equipe": 0, "texte": "Ballon récupéré.", "scene": {"kind": "turnover", "possession": 0, "ballon": [30.0, 35.0], "origine": [30.0, 35.0], "joueurs": []}},
		{"i": 6, "minute": 3, "horloge": "3′", "kind": "lineout", "equipe": 1, "texte": "Touche pour Visiteurs XV.", "scene": {"kind": "lineout", "possession": 1, "ballon": [60.0, 0.0], "origine": [60.0, 0.0], "joueurs": []}},
	]
	terrain.alimenter(deroule, 7)
	terrain.avancer(10.0)
	var entracte = Between.new()
	entracte.terrain = terrain
	entracte.etat = Label.new()
	# Borne du moteur : son dernier fait est la touche pour les visiteurs.
	var direct := {"possession": 1, "zone": {"x": 60.0, "kind": "lineout"}, "borne": 7}
	var vu_live := {"teams": equipes, "events": events}
	entracte._etat(vu_live, direct, equipes)
	check(terrain.en_retard() and int(terrain.joue.get("i", -1)) == 5, "Fixture : le terrain montre le ballon récupéré, la touche attend")
	check(entracte.etat.text == "Domicile XV a le ballon dans son camp", "Écran intermédiaire : la ligne suit le fait joué, pas la borne du moteur (" + entracte.etat.text + ")")
	terrain.avancer(10.0)
	entracte._etat(vu_live, direct, equipes)
	check(not terrain.en_retard() and entracte.etat.text.begins_with("Visiteurs XV a le ballon"), "Écran intermédiaire, terrain à jour : l'état borné du moteur (" + entracte.etat.text + ")")
	check(Between.etat_du_deroule(deroule[1], equipes) == "Touche pour Visiteurs XV", "Fait du terrain 2D : touche pour l'équipe qui lance")
	# Régie qui impose un texte (liaison, plan 3D) : il prime sur le terrain 2D.
	entracte.etat_force = "Touche pour Visiteurs XV"
	entracte._etat(vu_live, direct, equipes)
	check(entracte.etat.text == "Touche pour Visiteurs XV", "Texte imposé par la régie : prioritaire")
	entracte.etat_force = ""
	# Vérificateur du 25/11 (8e) : carton joué sur le terrain 2D, juste avant la pénalité ; la ligne
	# disait « Visiteurs XV a le ballon dans le camp adverse » (possession du moteur). Elle garde l'arrêt.
	var terrain_arret = Terrain2D.new()
	var arret_2d := [
		{"i": 8, "minute": 8, "horloge": "8′", "kind": "hand-fault", "equipe": 0, "texte": "En-avant de Domicile XV.", "scene": {"kind": "hand-fault", "possession": 1, "ballon": [55.0, 30.0], "origine": [55.0, 30.0], "joueurs": []}},
		{"i": 9, "minute": 8, "horloge": "8′", "kind": "penalty", "equipe": 0, "texte": "Plaquage dangereux de Visiteurs XV. Pénalité pour Domicile XV.", "scene": {"kind": "penalty", "possession": 0, "ballon": [60.0, 30.0], "origine": [60.0, 30.0], "joueurs": []}},
		{"i": 10, "minute": 8, "horloge": "8′", "kind": "card", "equipe": 1, "texte": "Carton jaune pour Paul DURAND : exclusion de 10 minutes de jeu.", "scene": {"kind": "card", "possession": 1, "ballon": [60.0, 30.0], "origine": [60.0, 30.0], "joueurs": []}},
	]
	entracte.terrain = terrain_arret
	var direct_arret := {"possession": 1, "zone": {"x": 60.0, "kind": "card"}, "borne": 11}
	var vues_2d: Array = []
	terrain_arret.alimenter(arret_2d, 11)
	for k in 30:
		terrain_arret.avancer(1.0)
		entracte._etat(vu_live, direct_arret, equipes)
		if vues_2d.is_empty() or vues_2d[-1] != entracte.etat.text: vues_2d.append(entracte.etat.text)
	check(not terrain_arret.en_retard() and str(terrain_arret.joue.get("kind", "")) == "card", "Fixture : le carton est le dernier fait joué")
	check(not vues_2d.any(func(t: String) -> bool: return t.contains("a le ballon")), "Écran intermédiaire, en-avant, pénalité puis carton : jamais la possession du moteur (%s)" % str(vues_2d))
	check(entracte.etat.text == "Carton jaune pour Paul DURAND", "Écran intermédiaire, carton joué : la ligne dit le carton (" + entracte.etat.text + ")")
	terrain_arret.free()
	# Film 4 (club 102, graine 123, 68′) : arrêt-décision d'un carton ouvert (`_arret`) pendant que le terrain 2D rejoue
	# d'autres faits (jeu courant, touche) : la ligne alternait carton / possession / carton. Elle garde le carton
	# à chaque rafraîchissement, jusqu'à la reprise du match.
	var terrain_rejeu = Terrain2D.new()
	var rejeu_2d := [
		{"i": 20, "minute": 68, "horloge": "68′", "kind": "card", "equipe": 1, "texte": "Carton jaune pour Paul DURAND : exclusion de 10 minutes de jeu.", "scene": {"kind": "card", "possession": 1, "ballon": [60.0, 30.0], "origine": [60.0, 30.0], "joueurs": []}},
		{"i": 21, "minute": 68, "horloge": "68′", "kind": "carry", "equipe": 1, "texte": "Visiteurs XV avance.", "scene": {"kind": "carry", "possession": 1, "ballon": [65.0, 30.0], "origine": [60.0, 30.0], "joueurs": []}},
		{"i": 22, "minute": 69, "horloge": "69′", "kind": "lineout", "equipe": 0, "texte": "Touche.", "scene": {"kind": "lineout", "possession": 0, "ballon": [90.0, 5.0], "origine": [90.0, 5.0], "joueurs": []}},
		{"i": 23, "minute": 69, "horloge": "69′", "kind": "carry", "equipe": 0, "texte": "Domicile XV avance.", "scene": {"kind": "carry", "possession": 0, "ballon": [80.0, 30.0], "origine": [90.0, 5.0], "joueurs": []}},
	]
	entracte.terrain = terrain_rejeu
	entracte._arret = {"raison": "carton", "cle": "c68", "horloge": "68′", "texte": "Carton jaune pour Paul DURAND : exclusion de 10 minutes de jeu."}
	var direct_rejeu := {"possession": 0, "zone": {"x": 80.0, "kind": "carry"}, "borne": 24}
	var vues_rejeu: Array = []
	terrain_rejeu.alimenter(rejeu_2d, 24)
	for k in 40:
		terrain_rejeu.avancer(0.5)
		entracte._etat(vu_live, direct_rejeu, equipes)
		if vues_rejeu.is_empty() or vues_rejeu[-1] != entracte.etat.text: vues_rejeu.append(entracte.etat.text)
	check(terrain_rejeu.joue_i == 23, "Fixture : le terrain a rejoué tous les faits pendant l'arrêt (%d)" % terrain_rejeu.joue_i)
	check(vues_rejeu == ["Carton jaune pour Paul DURAND"], "Arrêt-décision du carton : la ligne reste sur le carton à chaque rafraîchissement (%s)" % str(vues_rejeu))
	entracte._arret = {}
	entracte._etat(vu_live, direct_rejeu, equipes)
	check(not entracte.etat.text.begins_with("Carton"), "Match repris : la ligne suit de nouveau le jeu (" + entracte.etat.text + ")")
	terrain_rejeu.free()
	entracte.etat.free()
	entracte.free()
	terrain.free()

	# Trace des légendes : en liaison, le texte est celui de l'arrêt (essai) et non celui du plan à venir (touche).
	var lien := {"arrets": [2, 3], "kinds": ["try", "lineout"], "arret": 3}
	var suite := {"index": 4, "kind": "lineout", "horloge": "46′"}
	var fait := Regie.meta_legende("liaison", suite, lien, 0)
	check(fait.kind == "try" and fait.journal == 2 and fait.horloge == "", "Liaison, plan A : la trace porte l'essai, pas la touche à venir (" + str(fait) + ")")
	fait = Regie.meta_legende("liaison", suite, lien, 1)
	check(fait.kind == "lineout" and fait.journal == 3, "Liaison, plan B : la trace porte la remise en jeu (" + str(fait) + ")")
	fait = Regie.meta_legende("jeu", suite, lien, 0)
	check(fait.kind == "lineout" and fait.journal == 4 and fait.horloge == "46′", "Hors liaison : la trace garde le plan courant (" + str(fait) + ")")
	regie.free()
	print("MATCH_TEXTE_IMAGE %d controles, %d echec" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

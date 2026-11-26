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
	entracte.etat.free()
	entracte.free()
	terrain.free()

	# Vérificateur de #1305 (film 1, 20′-21′ ; film 3, 47′) : carton jaune, reprise du jeu, puis arrêt Blessure.
	# Phrase de jeu réelle de l'écran (aplat, pastille, ligne d'état) relue à chaque écriture de la ligne.
	var ecran = Between.new()
	var terrain_c = Terrain2D.new()
	ecran.terrain = terrain_c
	ecran.phrase_fm = PanelContainer.new()
	ecran.phrase_fm.add_theme_stylebox_override("panel", StyleBoxFlat.new())
	var ligne_c := HBoxContainer.new()
	ecran.phrase_fm.add_child(ligne_c)
	ecran.etat = Label.new()
	ligne_c.add_child(ecran.etat)
	Between.BullesAdjoint.poser(ecran)
	var carton_2d := [
		{"i": 20, "minute": 20, "horloge": "20′", "kind": "card", "equipe": 1, "texte": "Carton jaune pour Paul DURAND : exclusion de 10 minutes de jeu.", "scene": {"kind": "card", "possession": 1, "ballon": [60.0, 30.0], "origine": [60.0, 30.0], "joueurs": []}},
		{"i": 21, "minute": 20, "horloge": "20′", "kind": "carry", "equipe": 1, "texte": "Visiteurs XV avance.", "scene": {"kind": "carry", "possession": 1, "ballon": [65.0, 30.0], "origine": [60.0, 30.0], "joueurs": []}},
	]
	var live_c := {"teams": equipes, "events": events, "minute": 21}
	var direct_c := {"possession": 1, "zone": {"x": 65.0, "kind": "carry"}, "borne": 22, "reperes": [{"kind": "card", "nom": "Paul DURAND", "minute": 20}]}
	ecran._dernier = [{}, live_c, direct_c]
	var vue_c := func() -> String:
		var tag := ligne_c.get_node_or_null("MatchBetweenPlayLineTag")
		return ecran.etat.text + (" [pastille]" if tag != null and not tag.is_queued_for_deletion() else "")
	# Comme l'écran : rafraîchissement du direct (ligne puis phrase de jeu, update_frame), puis réécriture de la
	# ligne seule par le fil ou le terrain (match_between_fil.gd) ; on relit le texte après chacun.
	var bulles_c: Node = ecran.get_node(Between.BullesAdjoint.NOM)
	var rafraichir_c := func(lu: Array) -> void:
		ecran._etat(live_c, direct_c, equipes)
		bulles_c.appliquer_phrase()
		lu.append(vue_c.call())
		ecran._etat(live_c, direct_c, equipes)
		lu.append(vue_c.call())
	terrain_c.alimenter(carton_2d.slice(0, 1), 21)
	terrain_c.avancer(10.0)
	ecran._arret = {"raison": "carton", "cle": "carton-20", "horloge": "20′", "texte": "Carton jaune pour Paul DURAND : exclusion de 10 minutes de jeu."}
	var ouvert_c: Array = []
	rafraichir_c.call(ouvert_c)
	check(ouvert_c.all(func(t: String) -> bool: return t == "Carton jaune pour Paul DURAND [pastille]"), "Carton, arrêt ouvert : la ligne dit le carton, avec sa pastille (%s)" % str(ouvert_c))
	ecran._arret = {}
	var avant_c: Array = []
	rafraichir_c.call(avant_c)
	check(avant_c.all(func(t: String) -> bool: return t == "Carton jaune pour Paul DURAND [pastille]"), "Carton dernier fait joué, avant la reprise : le carton reste (%s)" % str(avant_c))
	# Reprise : le terrain 2D joue le fait suivant ; ni pastille ni texte du carton, sur plusieurs rafraîchissements.
	terrain_c.alimenter(carton_2d, 22)
	terrain_c.avancer(10.0)
	var reprise_c: Array = []
	for k in 3: rafraichir_c.call(reprise_c)
	check(str(terrain_c.joue.get("kind", "")) == "carry", "Fixture : le jeu a repris sur le terrain 2D")
	check(reprise_c.all(func(t: String) -> bool: return t.begins_with("Visiteurs XV a le ballon") and not t.contains("pastille")), "Après la reprise : la possession, sans la pastille du carton (%s)" % str(reprise_c))
	# Arrêt Blessure dans les 3 minutes du carton : il ne réaffiche pas le carton.
	ecran._arret = {"raison": "blessure", "cle": "incident-x-22", "horloge": "21′", "texte": "VIS · Blessure : Jean MARTIN doit quitter le terrain, Luc PETIT le remplace."}
	var blessure_c: Array = []
	rafraichir_c.call(blessure_c)
	check(blessure_c.all(func(t: String) -> bool: return not t.contains("Carton") and not t.contains("pastille")), "Arrêt Blessure après le carton : le carton n'est pas réaffiché (%s)" % str(blessure_c))
	ecran._arret = {}
	ecran.phrase_fm.free()
	ecran.free()
	terrain_c.free()

	# Vérificateur de #1305 (film 1) : horloge de l'écran intermédiaire 20:28 → 20:04 → 20:10 → 20:22 → 21:59 → 21:12.
	# Le texte posé par la régie ne recule jamais dans la période ; il repart à la mi-temps.
	var horloges: Array = []
	for vu: Array in [["20", 28], ["20", 4], ["20", 10], ["20", 22], ["21", 59], ["21", 12], ["22", 3]]:
		var h: Array = regie.retenir_horloge(str(vu[0]), int(vu[1]))
		horloges.append("%s:%02d" % [h[0], int(h[1])])
	check(horloges == ["20:28", "20:28", "20:28", "20:28", "21:59", "21:59", "22:03"], "Horloge de l'écran intermédiaire : jamais en arrière (%s)" % str(horloges))
	check("%s:%02d" % regie.retenir_horloge("40+2", 30) == "40+2:30" and "%s:%02d" % regie.retenir_horloge("40+1", 50) == "40+2:30", "Arrêts de jeu « 40+2 » : jamais en arrière non plus")
	regie._horloge_vue = []
	check("%s:%02d" % regie.retenir_horloge("40", 5) == "40:05", "Seconde période : l'horloge repart de 40")

	# Vérificateur de #1305 : « BLESSURE · 6′ » à la 21′. Le choix de blessure laissé au staff restait en attente dans
	# le moteur et revenait comme nouvel arrêt après le carton : un arrêt déjà montré ne revient pas.
	var script_app := GDScript.new()
	script_app.source_code = "extends Control\nvar management_ui := {}\n"
	script_app.reload()
	var app_arret: Control = script_app.new()
	regie.app = app_arret
	var montres: Array = []
	for cle: String in ["incident-m-12", "carton-80", "incident-m-12", "carton-80", "incident-m-95"]:
		if not regie.arret_vu("r|" + cle, true): montres.append(cle)
	check(montres == ["incident-m-12", "carton-80", "incident-m-95"], "Arrêts-décisions : chacun montré une fois, la blessure de la 6′ ne revient pas à la 21′ (%s)" % str(montres))
	regie.app = null
	app_arret.free()

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

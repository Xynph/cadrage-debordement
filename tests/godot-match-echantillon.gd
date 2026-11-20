extends SceneTree
## Écran entre deux temps forts (lot 5, 16/11/2026) : statistiques et lecture de Gabi sur un
## échantillon court. Projection `direct` de fixture (forme de native/engine/match-direct.cjs) :
## à la 2e minute, parts masquées, chiffres atténués, Gabi sans pourcentage ni ton alarmiste ;
## à la 12e minute, chiffres pleins et lecture de l'occupation. Bandeau du direct à l'échelle ;
## légende d'un essai retenue jusqu'à l'aplatissement.
const Between = preload("res://ui/contextual/match_between.gd")
const LiveView = preload("res://ui/contextual/live_view.gd")
const Regie = preload("res://ui/contextual/match_temps_forts.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("ECHEC : ", message)

func rang(cle: String, valeurs: Array, vide: bool, court: bool, unite: String = "") -> Dictionary:
	return {"cle": cle, "label": cle, "valeurs": valeurs, "unite": unite, "vide": vide, "court": court}

func direct(minute: int, seuil: int = 10) -> Dictionary:
	var court := minute < seuil
	return {"version": 1, "camp": 1, "score": [0, 0], "possession": 0, "zone": {"x": 30.0},
		"echantillon": {"minutes": minute, "suffisant": not court, "seuil": seuil},
		"tableau": [rang("possession", [57, 43], court, court, "%"), rang("occupation", [70, 30], court, court, "%"),
			rang("metres", [23, 34], false, court), rang("plaquages", [3, 12], false, court)],
		"fil": [{"i": 0, "horloge": "%d′" % minute, "texte": "Coup d’envoi.", "kind": "kickoff", "equipe": 0}],
		"domination": {"minutes": [10, 20], "miTemps": null}, "reperes": [], "deroule": [], "borne": 1, "notes": {}, "cartons": []}

## Textes d'un chiffre clé (libellé, notre valeur, la leur).
func textes_chiffre(between: Control, cle: String) -> Array:
	var bloc: Node = between.chiffres.find_child("MatchBetweenFigure_" + cle, false, false)
	return bloc.find_children("*", "Label", true, false).map(func(l: Label): return l.text) if bloc != null else []

func texte_gabi(between: Control) -> String:
	var morceaux: PackedStringArray = []
	for label: Label in between.adjoint.find_children("*", "Label", true, false): morceaux.append(label.text)
	return " ".join(morceaux)

func run() -> void:
	root.size = Vector2i(1920, 1080)
	var between: Control = Between.new()
	between.size = Vector2(1920, 940)
	root.add_child(between)
	for i in 3: await process_frame
	var equipes := [{"name": "Domicile XV", "abbr": "DOM"}, {"name": "Visiteurs XV", "abbr": "VIS"}]
	var live := {"teams": equipes, "events": [{}], "lineup": [], "minute": 2}
	between.update_frame({}, live, direct(2), func(_c: Variant): pass)
	for i in 2: await process_frame
	check(between.echantillon_court, "2e minute : échantillon court")
	check(is_equal_approx(between.chiffres.modulate.a, Between.ATTENUE), "2e minute : chiffres atténués")
	check(between.precision_chiffres.visible and between.precision_chiffres.text.contains("Trop tôt") and between.precision_chiffres.text.contains("10e"), "2e minute : la précision dit quand conclure (" + between.precision_chiffres.text + ")")
	# Possession et occupation : en tête des chiffres clés face à face (maquette DA du 19/11/2026), « — » tant que court.
	check(textes_chiffre(between, "possession") == ["POSSESSION", "—", "—"] and textes_chiffre(between, "occupation") == ["OCCUPATION", "—", "—"], "2e minute : possession et occupation masquées " + str(textes_chiffre(between, "possession")))
	check(between.chiffres.get_children().map(func(n: Node): return str(n.name)) == ["MatchBetweenFigure_possession", "MatchBetweenFigure_occupation"], "Chiffres clés : possession et occupation (les mètres sont dans les statistiques complètes)")
	var gabi := texte_gabi(between)
	check(not gabi.contains("%") and not gabi.contains("trop") and gabi.contains("se met en place"), "2e minute : Gabi posé, sans pourcentage (" + gabi + ")")
	# 12e minute : chiffres pleins, Gabi lit l'occupation (30 % pour son camp, écart net).
	live.minute = 12
	between.update_frame({}, live, direct(12), func(_c: Variant): pass)
	for i in 2: await process_frame
	check(not between.echantillon_court and between.chiffres.modulate.a == 1.0, "12e minute : chiffres pleins")
	check(not between.precision_chiffres.visible, "12e minute : plus d'avertissement")
	# Notre camp (1) à gauche, l'adversaire à droite ; les deux parts du moteur dans la barre et l'infobulle.
	check(textes_chiffre(between, "possession") == ["POSSESSION", "43 %", "57 %"] and between.chiffres.get_child(0).tooltip_text.contains("57 %"), "12e minute : possession affichée " + str(textes_chiffre(between, "possession")))
	check(textes_chiffre(between, "occupation") == ["OCCUPATION", "30 %", "70 %"], "12e minute : occupation affichée " + str(textes_chiffre(between, "occupation")))
	gabi = texte_gabi(between)
	check(gabi.contains("30 %") and gabi.contains("dégagement") and not gabi.contains("trop dans notre camp"), "12e minute : lecture de l'occupation, sans alarme (" + gabi + ")")
	# Projection d'avant le lot 5 (sans `echantillon`) : rien n'est atténué.
	var ancien := direct(12)
	ancien.erase("echantillon")
	check(not Between.est_court(ancien), "Ancienne projection : échantillon jugé suffisant")
	# Bandeau et légende du direct : 1 jusqu'en 1080p, ×1,33 en 1440p.
	check(LiveView.echelle_pour(720.0) == 1.0 and LiveView.echelle_pour(1080.0) == 1.0, "Bandeau : jamais réduit sous 1080p")
	check(is_equal_approx(LiveView.echelle_pour(1440.0), 1440.0 / 1080.0), "Bandeau : agrandi en 1440p")
	# Charte §7 (revue DA du 19/11/2026, choix de Léo) : journal en 16 px sur panneau 85 %, au-dessus du plancher T2.
	check(roundi(LiveView.BANDEAU_TAILLES.legende * LiveView.echelle_pour(1080.0)) >= 16, "Légende du temps fort lisible en 1080p")
	check(Between.muette("Les indicateurs ne justifient pas de changement offensif prioritaire.") and not Between.muette("Occupation de 30 % : rechercher du terrain au pied."), "Conseil sans proposition : Gabi lit le match montré")
	# Essai : rien n'est écrit ni acclamé avant que le ballon soit aplati (fin du mouvement du plan).
	var essai := {"kind": "try", "mouvement": 2.4, "duree": 3.4}
	check(Regie.essai_en_cours(essai, 0.0) and Regie.essai_en_cours(essai, 2.3), "Essai : légende tue pendant la course")
	check(not Regie.essai_en_cours(essai, 2.4), "Essai : légende à l'aplatissement")
	check(not Regie.essai_en_cours({"kind": "try", "mouvement": 0.0}, 0.0), "Essai sans mouvement : légende tout de suite")
	check(not Regie.essai_en_cours({"kind": "carry", "mouvement": 2.0}, 0.5), "Course : légende inchangée")
	# Lot 8 : ballon porté qui finit en essai, la conquête ne marque pas l'arrêt avant l'essai.
	var porte := [{"kind": "lineout", "coupe": true}, {"kind": "setpiece-win", "coupe": false}, {"kind": "try", "coupe": false}, {"kind": "transformation", "coupe": true}]
	check(Regie.enchaine_essai(porte, 1), "Ballon porté puis essai : la durée de la conquête est un plancher")
	check(not Regie.enchaine_essai(porte, 0) and not Regie.enchaine_essai(porte, 2) and not Regie.enchaine_essai(porte, 3), "Autres plans : durée inchangée")
	check(not Regie.enchaine_essai([{"kind": "setpiece-win"}, {"kind": "carry"}], 0), "Conquête sans essai : durée inchangée")
	# Tuile Bonus (`direct.bonus`, match-bonus.cjs) : règle, état et dilemme de fin de match avec deux consignes.
	var fin := direct(75)
	check(not between.bonus_tuile.visible, "Sans bonus en jeu : pas de tuile Bonus")
	fin["bonus"] = {"version": 1, "regle": "3 essais d’écart · défaite de 5 pts ou moins",
		"offensif": {"acquis": false, "manque": 1, "horsDePortee": false, "texte": "Bonus offensif à 1 essai"},
		"defensif": {"statut": "sans-objet", "manque": null, "texte": ""},
		"situation": {"cle": "offensif", "texte": "+6 à la 75e, 2 essais d’écart : viser le bonus offensif ou sécuriser la victoire ?",
			"consignes": [{"id": "viser", "label": "Viser le bonus", "attack": "large", "defense": "equilibre", "penalty": "touch", "aide": "Jeu au large."},
				{"id": "securiser", "label": "Sécuriser", "attack": "conquete", "defense": "prudente", "penalty": "points", "aide": "Jeu au près."}]}}
	var recus: Array = []
	between.consigne_bonus.connect(func(c: Dictionary): recus.append(c))
	between.update_frame({"tactics": {"attack": "conquete", "defense": "prudente", "penalty": "points"}}, live, fin, func(_c: Variant): pass)
	for i in 2: await process_frame
	check(between.bonus_tuile.visible and between.bonus_regle.text.contains("3 essais"), "Tuile Bonus : règle du championnat")
	check(between.bonus_situation.visible and between.bonus_situation.text.begins_with("+6 à la 75e"), "Tuile Bonus : dilemme affiché")
	var viser := between.find_child("MatchBetweenBonusChoice_viser", true, false) as Button
	var securiser := between.find_child("MatchBetweenBonusChoice_securiser", true, false) as Button
	check(viser != null and securiser != null and viser.text == "Viser le bonus", "Tuile Bonus : deux consignes")
	if viser != null:
		viser.pressed.emit()
		check(recus.size() == 1 and recus[0].get("attack") == "large" and recus[0].get("penalty") == "touch", "Tuile Bonus : la consigne part avec ses commandes")
	var fond := func(b: Button) -> Color: return (b.get_theme_stylebox("normal") as StyleBoxFlat).bg_color if b != null and b.get_theme_stylebox("normal") is StyleBoxFlat else Color.BLACK
	check(securiser != null and securiser.text.ends_with("en place") and fond.call(securiser) == Between.SURVOL and fond.call(viser) != Between.SURVOL, "Tuile Bonus : la consigne en place est marquée (mot et filet), jamais en or")
	# 1280×720 : la tuile reste dans l'écran, ses boutons aussi.
	root.size = Vector2i(1280, 720)
	between.size = Vector2(1280, 620)
	for i in 4: await process_frame
	var cadre: Rect2 = between.bonus_tuile.get_global_rect()
	check(cadre.size.x > 0 and cadre.end.x <= 1281.0 and cadre.end.y <= 721.0, "Tuile Bonus visible en 1280×720 (" + str(cadre) + ")")
	fin["bonus"] = null
	between.update_frame({}, live, fin, func(_c: Variant): pass)
	check(not between.bonus_tuile.visible, "Élimination directe ou amical : tuile masquée")
	print("MATCH_ECHANTILLON %d controles, %d echec" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

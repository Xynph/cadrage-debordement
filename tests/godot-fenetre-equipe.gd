extends SceneTree
## Fenêtre « Équipe » du match en direct (profil Monde préparé par tests/godot-fenetre-equipe.cjs, jour de match) :
## un seul bouton ÉQUIPE (plus de TACTIQUE ni de BANC), la fenêtre s'ouvre en plein écran et met le match en
## pause ; quinze médaillons avec portrait et banc en tuiles ; un vrai remplacement (charge `substitute`
## {slot, outId, inId} lue par le vrai moteur) ; une consigne depuis l'onglet Consignes (`set_consignes`) ;
## les cris de la touche envoient `cri` ; rien ne déborde en 1280×720, 1920×1080 et 2560×1440 ;
## « Valider et reprendre » relance le match. Champs du pilotage encore absents du moteur (cris, fatigue,
## conseil de changement, adversaire, niveau) : ajoutés au modèle montré, pour l'écran seulement.
## Captures (affichage graphique) : CD_EQUIPE_OUTPUT=<dossier>.
var app: Control
var director: Node
var vue: Control
var fenetre: Control
var sortie := OS.get_environment("CD_EQUIPE_OUTPUT")
var echecs: Array[String] = []
var controles := 0
var rapport := {}

func _initialize() -> void: call_deferred("executer")

func verifier(ok: bool, message: String) -> void:
	controles += 1
	if not ok:
		echecs.append(message)
		printerr("FAIL: ", message)

func poser(images := 8) -> void:
	for i in images: await process_frame

func jusqua(condition: Callable, limite_ms: int = 30000) -> bool:
	var fin := Time.get_ticks_msec() + limite_ms
	while Time.get_ticks_msec() < fin:
		if condition.call(): return true
		await process_frame
	return condition.call()

func attendre(commande: String) -> void:
	var limite := Time.get_ticks_msec() + 120000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec() < limite: await process_frame
	verifier(not app.waiting and app.bridge.last_response_ok, commande + " : réponse du vrai moteur " + str(app.last_error))
	await poser(6)

func demander(commande: String, payload := {}) -> void:
	app._command(commande, payload)
	await attendre(commande)

func live() -> Dictionary:
	return app.model.get("live") if app.model.get("live") is Dictionary else {}

func talk() -> Dictionary:
	var v: Variant = app.model.get("clubLife", {}).get("matchTalks", {}).get("scene")
	return v if v is Dictionary else {}

func boutons_textes(racine: Node) -> Array:
	return racine.find_children("*", "Button", true, false).filter(func(b: Button) -> bool: return b.is_visible_in_tree()).map(func(b: Button) -> String: return b.text.strip_edges().to_upper())

func taille(largeur: int, hauteur: int) -> void:
	root.size = Vector2i(largeur, hauteur)
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(root.size)
	await poser(10)

func capturer(nom: String) -> void:
	await poser(12)
	if DisplayServer.get_name() != "headless" and not sortie.is_empty():
		verifier(root.get_texture().get_image().save_png(sortie.path_join(nom + ".png")) == OK, "capture " + nom)

## Modèle montré : le vrai modèle, plus les champs de pilotage que le moteur n'expose pas encore.
func modele_enrichi() -> Dictionary:
	var m: Dictionary = app.model.duplicate(true)
	var l: Dictionary = m.live
	var lineup: Array = l.get("lineup", [])
	var reserves: Array = l.get("reserves", [])
	var notes := {}
	for n in lineup.size():
		if not lineup[n] is Dictionary: continue
		if not lineup[n].has("rating"): lineup[n]["rating"] = 72 + (n * 7) % 14
		lineup[n]["condition"] = [71, 52, 61, 74, 77, 63, 66, 80, 82, 79, 88, 85, 83, 90, 86][n]
		notes[str(lineup[n].id)] = {"note": 5.9 + float((n * 3) % 22) / 10.0, "faits": 3}
	for n in reserves.size():
		if reserves[n] is Dictionary and not reserves[n].has("rating"): reserves[n]["rating"] = 72 + (n * 5) % 6
	if reserves.size() > 0 and reserves[0] is Dictionary: reserves[0]["conseil"] = "Veut se montrer"
	var direct: Dictionary = l.get("direct") if l.get("direct") is Dictionary else {}
	direct["notes"] = notes
	l["direct"] = direct
	var p: Dictionary = l.get("pilotage") if l.get("pilotage") is Dictionary else {}
	var joueurs := {}
	var etats := [["galvanise", "Galvanisé"], ["tendu", "Tendu"], ["indifferent", "Indifférent"], ["motive", "Motivé"], ["indifferent", "Indifférent"], ["vexe", "Vexé"], ["indifferent", "Indifférent"], ["serein", "Serein"], ["motive", "Motivé"], ["galvanise", "Galvanisé"]]
	for n in mini(lineup.size(), etats.size()):
		if lineup[n] is Dictionary: joueurs[str(lineup[n].id)] = {"etat": etats[n][0], "label": etats[n][1], "phase": "pre", "confiance": 60}
	p["joueurs"] = joueurs
	var consignes: Dictionary = p.get("consignes", {}).duplicate() if p.get("consignes") is Dictionary else {}
	consignes["rucks"] = "agressive"
	p["consignes"] = consignes
	p["bilans"] = [{"axe": "rucks", "valeur": "agressive", "depuis": 41, "texte": "Rucks « Contester » depuis 41′ : 3 pénalités, 2 ballons arrachés."}]
	p["cris"] = {"options": [{"id": "encourager", "label": "Encourager", "note": "Rassure les tendus", "disponible": true},
		{"id": "exiger", "label": "Exiger", "note": "Déjà crié à 41′ : s’use", "disponible": true},
		{"id": "calmer", "label": "Calmer", "note": "Moins de fautes au sol", "disponible": true},
		{"id": "defense", "label": "Serrer la défense", "note": "Ils attaquent large", "disponible": true},
		{"id": "tout", "label": "Tout donner", "note": "Pour la fin de match", "disponible": false}], "actif": {"id": "calmer", "label": "Calmer", "jusqua": 58}}
	if lineup.size() >= 7:
		p["fatigue"] = [1, 2, 5, 6].map(func(n: int) -> Dictionary: return {"id": str(lineup[n].id), "condition": lineup[n].condition, "prevue": int(lineup[n].condition) - 7})
		var entrant := ""
		for option: Variant in l.get("substitutions", []):
			if option is Dictionary and int(option.slot) == 1 and not (option.get("inIds", []) as Array).is_empty(): entrant = str(option.inIds[0])
		if entrant.is_empty() and reserves.size() > 0: entrant = str(reserves[0].id)
		p["conseilChangement"] = {"outId": str(lineup[1].id), "inId": entrant, "texte": "Le talonneur est à 52 %, deux lancers ratés. Le remplaçant est frais et veut se montrer."}
	p["adversaire"] = {"consignes": {"rucks": "agressive", "piedJeu": "plus"}, "journal": ["Vestiaire adverse à la pause : discours exigeant."], "lecture": "Ils concèdent 2 pénalités par 10 minutes : jouer vite les ballons au sol les punit."}
	l["pilotage"] = p
	return m

func ouvrir_par_le_bouton() -> void:
	var bouton: Button = vue.find_child("MatchBetweenTeam", true, false)
	verifier(bouton != null, "bouton ÉQUIPE de l'écran intermédiaire")
	if bouton == null: bouton = vue.find_child("MatchTeamButton", true, false)
	if bouton != null:
		bouton.disabled = false
		bouton.pressed.emit()
	await poser(4)

func controler_mise_en_page(contexte: String) -> void:
	await poser(6)
	verifier(fenetre.is_visible_in_tree(), contexte + " : fenêtre visible")
	var cadre := fenetre.get_global_rect()
	var ecran := Rect2(Vector2.ZERO, Vector2(root.size))
	verifier(ecran.grow(1).encloses(cadre), contexte + " : fenêtre dans l'écran %s" % cadre)
	for echec in fenetre.debordements(): verifier(false, contexte + " : " + echec)
	var page: Control = fenetre.find_child("TeamPage", true, false)
	verifier(page != null and ecran.grow(1).encloses(page.get_global_rect()), contexte + " : page de la maquette dans l'écran")

func composition_enrichie(contexte: String) -> void:
	fenetre.choisir_onglet("composition")
	fenetre.update_frame(modele_enrichi())
	await poser(8)
	var terrain: Control = fenetre.find_child("TeamPitch", true, false)
	verifier(fenetre.medaillons.size() == 15, contexte + " : 15 médaillons (%d)" % fenetre.medaillons.size())
	var portraits := 0
	for slot: int in fenetre.medaillons:
		var m: Control = fenetre.medaillons[slot]
		if m.find_child("Portrait", true, false) != null: portraits += 1
		if terrain != null: verifier(terrain.get_global_rect().grow(2).encloses(m.get_global_rect()), contexte + " : médaillon %d dans le terrain" % (slot + 1))
	verifier(portraits == 15, contexte + " : 15 portraits sur le terrain (%d)" % portraits)
	var niveaux := fenetre.medaillons.values().filter(func(m: Variant) -> bool: return not str(m.get("niveau")).is_empty()).size()
	verifier(niveaux == 15, contexte + " : badge de niveau sur les 15 (%d)" % niveaux)
	var etats := fenetre.find_children("TeamPlayerState", "", true, false).size()
	verifier(etats >= 5, contexte + " : états après causerie (%d)" % etats)
	verifier(fenetre.find_children("TeamPlayerNote", "", true, false).size() == 15, contexte + " : note du match sous chaque nom")
	verifier(fenetre.tuiles.size() == live().get("reserves", []).size() and fenetre.tuiles.size() > 0, contexte + " : une tuile par remplaçant (%d)" % fenetre.tuiles.size())
	for id: String in fenetre.tuiles: verifier(fenetre.tuiles[id].find_child("Portrait", true, false) != null, contexte + " : portrait du remplaçant " + id)
	for nom in ["TeamShouts", "TeamFatigue", "TeamAdvice", "TeamFooterReferee"]:
		var n: Control = fenetre.find_child(nom, true, false)
		verifier(n != null and n.is_visible_in_tree(), contexte + " : bloc " + nom)
	await controler_mise_en_page(contexte + " composition")

func consignes_enrichies(contexte: String) -> void:
	fenetre.choisir_onglet("consignes")
	fenetre.update_frame(modele_enrichi())
	await poser(8)
	for nom in ["TeamConsignes", "TeamReferee", "TeamOpponent", "TeamFollowers", "TeamGamePlan"]:
		var n: Control = fenetre.find_child(nom, true, false)
		verifier(n != null and n.is_visible_in_tree(), contexte + " : bloc " + nom)
	var crans := fenetre.find_children("Consigne_*_*", "Button", true, false).size()
	verifier(crans == 15, contexte + " : 5 axes × 3 crans (%d)" % crans)
	var jauges := fenetre.find_children("TeamRefereeGauge_*", "", true, false).size()
	verifier(jauges == 4, contexte + " : 4 jauges de l'arbitre (%d)" % jauges)
	await controler_mise_en_page(contexte + " consignes")

func executer() -> void:
	await taille(1920, 1080)
	app = load("res://main.tscn").instantiate(); root.add_child(app)
	await attendre("ouverture")
	director = app.find_child("ContextualDirector", true, false)
	await demander("begin_match")
	if director != null and director.view != null and director.view.has_method("_continue") and not talk().is_empty():
		director.view._continue(true)
		await attendre("match_talk_continue")
	await jusqua(func() -> bool: return app.find_child("ContextualLiveMatch", true, false) != null, 20000)
	vue = app.find_child("ContextualLiveMatch", true, false)
	verifier(vue != null and "equipe" in vue, "direct ouvert avec la fenêtre Équipe")
	if vue == null or not "equipe" in vue:
		_fin()
		return
	fenetre = vue.equipe
	# Un seul bouton ÉQUIPE : plus de TACTIQUE ni de BANC nulle part dans le direct.
	await jusqua(func() -> bool: return live().get("direct") is Dictionary, 30000)
	await poser(10)
	var textes := boutons_textes(vue)
	rapport.boutons = textes
	verifier("ÉQUIPE" in textes, "bouton ÉQUIPE visible (%s)" % str(textes))
	verifier(not "TACTIQUE" in textes and not "BANC" in textes, "ni TACTIQUE ni BANC (%s)" % str(textes))
	for nom in ["MatchBetweenTactics", "MatchBetweenBench"]: verifier(vue.find_child(nom, true, false) == null, "ancien bouton absent : " + nom)
	verifier(vue.find_children("*", "Button", true, false).all(func(b: Button) -> bool: return b.text.strip_edges().to_upper() not in ["TACTIQUE", "BANC"]), "aucun bouton TACTIQUE ou BANC, même masqué")
	# Ouverture : plein écran, le match se met en pause.
	await ouvrir_par_le_bouton()
	verifier(fenetre.visible, "la fenêtre s'ouvre")
	verifier(await jusqua(func() -> bool: return bool(live().get("paused", false)) and not app.waiting, 30000), "le match se met en pause à l'ouverture")
	var minute := int(live().get("minute", 0))
	await poser(90)
	verifier(int(live().get("minute", 0)) == minute and bool(live().get("paused", false)), "le match reste en pause fenêtre ouverte")
	# Modèle réel (sans les champs à venir) : blocs optionnels masqués, rien ne casse.
	fenetre.update_frame(app.model)
	await poser(6)
	verifier(fenetre.medaillons.size() == 15, "15 médaillons sur le vrai modèle")
	var p_reel: Dictionary = live().get("pilotage") if live().get("pilotage") is Dictionary else {}
	if not p_reel.has("cris"): verifier(fenetre.find_child("TeamShouts", true, false) == null, "sans cris dans le modèle : colonne masquée")
	if not p_reel.has("fatigue"): verifier(fenetre.find_child("TeamFatigue", true, false) == null, "sans prévision : bande « Dans 10 minutes » masquée")
	if not p_reel.has("conseilChangement"): verifier(fenetre.find_child("TeamAdvice", true, false) == null, "sans conseil : carte de Gabi masquée")
	# Remplacement réel : un joueur du XV, puis un remplaçant autorisé par le moteur.
	var slot := -1
	var entrant := ""
	for option: Variant in live().get("substitutions", []):
		if option is Dictionary and not (option.get("inIds", []) as Array).is_empty() and slot < 0:
			slot = int(option.slot)
			entrant = str(option.inIds[0])
	verifier(slot >= 0, "au moins un changement autorisé match arrêté")
	if slot >= 0:
		var sortant := str(live().lineup[slot].id)
		fenetre.choisir_poste(slot)
		await poser(4)
		verifier(fenetre.poste_choisi == slot, "joueur du XV choisi")
		var tuile: Button = fenetre.tuiles.get(entrant)
		verifier(tuile != null and bool(tuile.get_meta("eligible", false)), "remplaçant autorisé en clair")
		var interdit := fenetre.tuiles.keys().filter(func(id: String) -> bool: return not bool(fenetre.tuiles[id].get_meta("eligible", true)))
		for id: String in interdit: verifier(fenetre.tuiles[id].modulate.a < 0.6, "remplaçant non autorisé atténué " + id)
		if tuile != null: tuile.pressed.emit()
		verifier(app.last_command == "substitute", "clic sur le remplaçant : commande substitute")
		await attendre("substitute")
		rapport.remplacement = {"slot": slot, "outId": sortant, "inId": entrant, "apres": str(live().lineup[slot].id)}
		verifier(str(live().lineup[slot].id) == entrant, "le moteur a fait entrer %s au poste %d" % [entrant, slot + 1])
		verifier(not live().get("reserves", []).any(func(r: Variant) -> bool: return r is Dictionary and str(r.id) == entrant), "le remplaçant a quitté le banc")
		await poser(4)
		var statut: Label = fenetre.find_child("TeamStatus", true, false)
		rapport.statut = statut.text if statut != null else ""
		verifier(statut != null and statut.text.contains("entre à la place"), "message du changement : « %s »" % rapport.statut)
	# Onglet Consignes : un cran envoie set_consignes, le moteur le garde.
	(fenetre.find_child("TeamTabConsignes", true, false) as Button).pressed.emit()
	await poser(4)
	verifier(fenetre.onglet == "consignes", "onglet Consignes")
	var cran: Button = fenetre.find_child("Consigne_rythme_rapide", true, false)
	verifier(cran != null, "cran Rythme · Accélérer")
	if cran != null:
		cran.pressed.emit()
		verifier(app.last_command == "set_consignes", "clic sur un cran : set_consignes")
		await attendre("set_consignes")
		verifier(str(live().get("pilotage", {}).get("consignes", {}).get("rythme", "")) == "rapide", "consigne Rythme gardée par le moteur")
	# Cris de la touche : le bouton envoie `cri`.
	fenetre.choisir_onglet("composition")
	fenetre.update_frame(modele_enrichi())
	await poser(4)
	var cri: Button = fenetre.find_child("TeamShout_encourager", true, false)
	verifier(cri != null and not cri.disabled, "cri « Encourager » disponible")
	var actif: Button = fenetre.find_child("TeamShout_calmer", true, false)
	verifier(actif != null and actif.disabled, "cri actif non relançable")
	if cri != null:
		cri.pressed.emit()
		verifier(app.last_command == "cri", "clic sur un cri : commande cri")
		await jusqua(func() -> bool: return not app.waiting, 20000)
		rapport.cri_reponse = str(app.last_error)
	# Mise en page : trois tailles, deux onglets ; captures en 1080p et 720p.
	for t: Vector2i in [Vector2i(1920, 1080), Vector2i(1280, 720), Vector2i(2560, 1440)]:
		await taille(t.x, t.y)
		var nom := "%dx%d" % [t.x, t.y]
		await composition_enrichie(nom)
		if t.x != 2560: await capturer("equipe-composition-" + nom)
		await consignes_enrichies(nom)
		if t.x != 2560: await capturer("equipe-consignes-" + nom)
	await taille(1920, 1080)
	# Joueur choisi puis remplaçant (état sélectionné) pour la capture.
	fenetre.choisir_onglet("composition")
	fenetre.update_frame(modele_enrichi())
	await poser(4)
	fenetre.choisir_poste(1)
	await capturer("equipe-composition-selection-1920x1080")
	# Valider et reprendre : la fenêtre se ferme, le match repart.
	fenetre.update_frame(app.model)
	var reprise: Button = fenetre.find_child("TeamResume", true, false)
	verifier(reprise != null, "bouton Valider et reprendre")
	if reprise != null: reprise.pressed.emit()
	verifier(not fenetre.visible, "la fenêtre se ferme")
	verifier(await jusqua(func() -> bool: return not bool(live().get("paused", true)), 30000), "le match repart")
	_fin()

func _fin() -> void:
	print("EQUIPE ", JSON.stringify({"controles": controles, "failures": echecs, "rapport": rapport}))
	app.closing = true
	app.bridge.stop()
	quit(0 if echecs.is_empty() else 1)

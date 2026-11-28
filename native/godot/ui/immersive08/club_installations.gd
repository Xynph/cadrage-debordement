extends "res://ui/immersive08/club_conseil.gd"
## Écran Club : installations, « À décider », vestiaire et stade (vue d'ensemble et onglet Infrastructures).

static func _installations(panneau: Panel, app: Control, finance: Dictionary, strategie: Dictionary) -> void:
	var largeur := panneau.size.x / C.density
	for colonne: Array in [["Installation", 64.0, 260.0, false], ["État", 340.0, 200.0, false], ["Niveau", 560.0, 200.0, false], ["Prochaine amélioration", 790.0, 230.0, false], ["Coût", 1030.0, 130.0, true], ["Statut", 1194.0, 196.0, false]]:
		Kit.etiquette(panneau, float(colonne[1]) + (float(colonne[2]) if colonne[3] else 0.0), 82, str(colonne[0]), float(colonne[2]), colonne[3])
	D.line(panneau, Vector2(18, 92), Vector2(largeur - 18, 92), Charte.FILET)
	var devis: Variant = finance.get("facility")
	var academie: Variant = app.model.get("clubLife", {}).get("academyPathways", {}).get("facilities")
	var suivi: Dictionary = app.model.get("clubLife", {}).get("academyFollowUp", {})
	var centre_ouvert: bool = suivi.get("available", false) == true
	var soutien: Dictionary = app.model.get("clubLife", {}).get("clubSupport", {})
	var medical: Array = soutien.get("medical", {}).get("players", [])
	var fans: Dictionary = strategie.get("fans", {})
	var rangees: Array = []
	var statut := ""
	if devis is Dictionary:
		if devis.get("used", false): statut = "Fait cette saison"
		elif not devis.get("affordable", true): statut = "À financer"
		elif not strategie.get("available", false): statut = "Indisponible en ce moment"
		else: statut = "Devis disponible"
	rangees.append({"id": "ClubFacilityTraining", "nom": "Centre d’entraînement", "niveau": "%s / 10" % G.n(devis.level) if devis is Dictionary else "Niveau indisponible", "segments": [10, int(devis.level)] if devis is Dictionary else [], "suite": "Niveau %s" % G.n(devis.nextLevel) if devis is Dictionary else "—", "cout": G.euros(devis.cost) if devis is Dictionary else "", "statut": statut, "action": func(): _tab(app, "infrastructure", "ClubTab_infrastructure")})
	rangees.append({"id": "ClubFacilityMedical", "nom": "Cellule médicale", "niveau": "%s suivi%s" % [G.n(medical.size()), "s" if medical.size() > 1 else ""] if not soutien.is_empty() else "—", "segments": [], "suite": "Retour des blessés", "cout": "", "statut": "", "action": func(): app._navigate("Travail du club")})
	var academie_niveau := G.n(academie) + " / 3" if academie != null else "Niveau indisponible"
	var academie_suite := "Installations du centre"
	if academie == null and centre_ouvert:
		academie_niveau = "%s / %s" % [G.n(suivi.get("total", 0)), G.n(suivi.get("capacity", 75))]
		academie_suite = "%s jeunes au centre" % G.n(int(suivi.get("crabos", {}).get("count", 0)) + int(suivi.get("espoirs", {}).get("count", 0)))
	rangees.append({"id": "ClubFacilityAcademy", "nom": "Académie", "niveau": academie_niveau, "segments": [3, int(academie)] if academie != null else [], "suite": academie_suite, "cout": "", "statut": "", "action": func(): app._navigate("Centre")})
	rangees.append({"id": "ClubFacilityStadium", "nom": str(G.identity(app.model.club).get("stadium", "Le stade")), "niveau": _milliers(fans.capacity) + " places" if fans.has("capacity") else "—", "segments": [], "suite": "Affluence " + _milliers(fans.expectedAttendance) if fans.has("expectedAttendance") else "Photo, ville et crédits", "cout": "", "statut": "", "action": func(): _tab(app, "territory", "ClubTab_overview")})
	for i in rangees.size():
		var donnees: Dictionary = rangees[i]
		var rangee := Button.new()
		rangee.name = str(donnees.id)
		Kit.styler_ligne(rangee, Color.TRANSPARENT)
		rangee.accessibility_name = str(donnees.nom)
		rangee.pressed.connect(donnees.action)
		panneau.add_child(rangee)
		D.place(rangee, Rect2(18, 98 + i * 40, largeur - 36, 40))
		# Charte : pas de bandes alternées, un filet entre deux lignes.
		if i > 0: D.line(panneau, Vector2(18, 98 + i * 40), Vector2(largeur - 18, 98 + i * 40), Charte.FILET)
		var nom := Kit.texte(rangee, 46, 27, str(donnees.nom), Charte.IVOIRE, 266, 19)
		nom.add_theme_font_override("font", Kit.texte_gras())
		ConseilLettre.picto_ligne(rangee, str(donnees.id), Rect2(6, 6, 28, 28))
		ConseilLettre.pastille_ligne(rangee, ConseilLettre.etat_installation(str(donnees.id), app, finance, strategie), 322, str(donnees.id) + "Etat")
		var segments: Array = donnees.segments
		if segments.is_empty(): Kit.texte(rangee, 542, 27, str(donnees.niveau), Charte.IVOIRE, 210, 18)
		else:
			_segments(rangee, 542, 15, 120, int(segments[0]), int(segments[1]))
			Kit.texte(rangee, 742, 27, str(donnees.niveau), Charte.IVOIRE, 70, 18, HORIZONTAL_ALIGNMENT_RIGHT).name = "ClubFacilityLevel"
		Kit.texte(rangee, 772, 27, str(donnees.suite), Charte.IVOIRE_2, 230, 18)
		if not str(donnees.cout).is_empty(): Kit.texte(rangee, 1142, 27, str(donnees.cout), Charte.IVOIRE, 130, 18, HORIZONTAL_ALIGNMENT_RIGHT)
		if not str(donnees.statut).is_empty(): Kit.texte(rangee, 1176, 27, str(donnees.statut), Charte.IVOIRE_2, 190, 17)
	var details := Kit.lien(panneau, Rect2(24, 270, 0, 34), "Projets et devis des installations →", func(): _tab(app, "infrastructure", "ClubTab_infrastructure"), "ClubFacilityDetails", 19)
	details.tooltip_text = ""

# --- À décider -----------------------------------------------------------------------------------------------------------

static func _decider(panneau: Panel, app: Control, finance: Dictionary, board: Dictionary, strategie: Dictionary) -> void:
	var largeur := panneau.size.x / C.density
	var elements: Array = []
	var en_attente: Array = board.get("objectives", []).filter(func(objectif: Dictionary): return objectif.get("status") == "pending")
	en_attente.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.get("deadline", 0)) < int(b.get("deadline", 0)))
	if en_attente.is_empty():
		elements.append({"id": "ClubFixMilestone", "genre": "alerte", "titre": "Aucune échéance fixée avec le conseil.", "detail": "", "bulle": "Fixe-en une : il en tiendra compte au bilan de fin de saison.", "action": "Fixer un jalon", "ouvrir": func(): _open_strategy(app, 1)})
	else:
		var jalon: Dictionary = en_attente[0]
		elements.append({"id": "ClubNextMilestone", "genre": "neutre", "titre": "Prochain jalon : %s" % str(GOALS.get(str(jalon.get("type", "")), "jalon du conseil")).to_lower(), "detail": "", "pastille": ["Sem. %s" % G.n(jalon.get("deadline", "—")), "flag", Pastilles.TURQUOISE, func(): _open_strategy(app, 1)], "action": "Suivre les objectifs", "ouvrir": func(): _open_strategy(app, 1)})
	var devis: Variant = finance.get("facility")
	if devis is Dictionary and not devis.get("used", false):
		var tuile_devis := [Pastilles.euros_courts(devis.cost), "1 par saison"]
		var pastille_devis: Array = []
		if not devis.get("affordable", true): pastille_devis = ["Trésorerie insuffisante", "warning", Pastilles.ORANGE, func(): app._navigate("Finances")]
		elements.append({"id": "ClubQuoteLink", "genre": "alerte", "titre": "Devis du centre d’entraînement, niveau %s" % G.n(devis.nextLevel), "detail": "", "tuile": tuile_devis, "pastille": pastille_devis, "bulle": "%s · une amélioration par saison" % G.euros(devis.cost), "action": "Voir le devis", "ouvrir": func(): _tab(app, "infrastructure", "ClubTab_infrastructure")})
	if strategie.get("available", false):
		elements.append({"id": "ClubBoardRequest", "genre": "alerte", "titre": "Demande à la direction possible.", "detail": "", "action": "Présenter la demande", "ouvrir": func(): _open_strategy(app, 1)})
	Kit.texte(panneau, largeur - 24, 40, str(elements.size()), Charte.IVOIRE_2, 60, 18, HORIZONTAL_ALIGNMENT_RIGHT)
	D.line(panneau, Vector2(18, 56), Vector2(largeur - 18, 56), Charte.FILET)
	for i in mini(3, elements.size()):
		var element: Dictionary = elements[i]
		var haut := 66.0 + i * 86.0
		var cadre := D.rect(panneau, Rect2(18, haut, largeur - 36, 78), Charte.PANNEAU_2 if i == 0 else Color.TRANSPARENT, 16)
		cadre.name = "ClubDecideRow%d" % i
		_coche(panneau, Rect2(30, haut + 14, 26, 26), str(element.genre), Charte.IVOIRE)
		# Titre et détail sur une ligne chacun (texte complet en infobulle) : jamais de chevauchement, à 1280 comme à 1920.
		var a_detail: bool = element.has("tuile") or not (element.get("pastille", []) as Array).is_empty()
		var titre := _texte_lignes(panneau, 72, haut + (10 if a_detail else 26), 470, str(element.titre), 19, Kit.texte_gras(), Charte.IVOIRE, 1)
		titre.name = "ClubDecideTitle%d" % i
		titre.tooltip_text = str(element.titre)
		titre.mouse_filter = Control.MOUSE_FILTER_PASS
		titre.tooltip_text = str(element.get("bulle", element.titre))
		var x_detail := 72.0
		if element.has("tuile"):
			var tuile := Pastilles.tuile(str(element.tuile[0]), str(element.tuile[1]), Pastilles.ORANGE, Charte.PANNEAU_3 if i == 0 else Charte.PANNEAU_2, 22, "ClubDecideTile%d" % i, true, element.ouvrir)
			x_detail += Pastilles.poser(panneau, tuile, x_detail, haut + 38) + 8.0
		var pastille: Array = element.get("pastille", [])
		if not pastille.is_empty():
			var badge := Pastilles.pastille(str(pastille[0]), pastille[2], str(pastille[1]), "", 17, "ClubDecideBadge%d" % i, pastille[3])
			Pastilles.poser(panneau, badge, x_detail, haut + 42)
		if i == 0:
			Kit.bouton_ivoire(panneau, Rect2(largeur - 30 - 250, haut + 16, 250, 46), str(element.action), element.ouvrir, str(element.id))
		else:
			var lien := Kit.lien(panneau, Rect2(largeur - 30, haut + 22, 0, 34), str(element.action) + " →", element.ouvrir, str(element.id), 18, true)
			lien.tooltip_text = ""
	if elements.is_empty(): Kit.texte(panneau, 24, 100, "Rien à trancher cette semaine.", Charte.IVOIRE, 600, 20).name = "ClubDecideNone"
	D.line(panneau, Vector2(18, 330), Vector2(largeur - 18, 330), Charte.FILET)
	_footer(panneau, app, finance, board)

static func _vestiaire(panneau: Panel, app: Control) -> void:
	var largeur := panneau.size.x / C.density
	var lien := Kit.lien(panneau, Rect2(largeur - 24, 12, 0, 34), "Entrer au vestiaire →", func(): app._navigate("Vestiaire"), "ClubLockerAction", 18, true)
	lien.tooltip_text = ""
	var squad: Array = app.model.get("squad", [])
	var blesses := 0
	var suspendus := 0
	var selection := 0
	var absents: Array = []
	for joueur: Variant in squad:
		if not joueur is Dictionary: continue
		match Etat.indisponibilite(joueur):
			"blesse":
				blesses += 1
				absents.append(joueur)
			"suspendu":
				suspendus += 1
				absents.append(joueur)
			"selection":
				selection += 1
				absents.append(joueur)
	var details: Array[String] = []
	if blesses > 0: details.append(P.plural(blesses, "blessé", "blessés"))
	if suspendus > 0: details.append(P.plural(suspendus, "suspendu", "suspendus"))
	if selection > 0: details.append("%d en sélection" % selection)
	var moral: Variant = app.model.meta.get("morale")
	var cote := (largeur - 48.0 - 24.0) / 3.0
	var tuiles := [
		{"id": "ClubMorale", "etiquette": "Moral", "valeur": G.n(moral) if moral != null else "—", "sur": "/ 100", "barre": float(moral) if moral != null else -1.0, "suite": ""},
		{"id": "ClubAvailable", "etiquette": "Disponibles", "valeur": str(squad.size() - absents.size()), "sur": "/ %d" % squad.size(), "barre": -1.0, "suite": " · ".join(details) if not details.is_empty() else "Aucun absent"},
	]
	for i in tuiles.size():
		var tuile: Dictionary = tuiles[i]
		var bouton := Button.new()
		bouton.name = str(tuile.id)
		Kit.styler_ligne(bouton, Charte.PANNEAU_2)
		# Tuile de chiffre = carte rayon 12 px (16 en référence 2560, charte §3).
		for etat in ["normal", "hover", "pressed", "disabled", "focus"]:
			var fond := bouton.get_theme_stylebox(etat) as StyleBoxFlat
			if fond == null: continue
			fond.set_corner_radius_all(maxi(3, C.px(16)))
			Charte.ombrer(fond, 16)
		bouton.accessibility_name = "%s · %s %s · vestiaire" % [tuile.etiquette, tuile.valeur, tuile.sur]
		bouton.pressed.connect(func(): app._navigate("Vestiaire"))
		panneau.add_child(bouton)
		# Mini-courbe du moral au survol (relevé hebdomadaire du moteur).
		if str(tuile.id) == "ClubMorale": preload("res://ui/mini_courbe_survol.gd").lier(app, bouton, "morale", "Moral du vestiaire")
		D.place(bouton, Rect2(24 + i * (cote + 12), 66, cote, 150))
		load("res://ui/retour_tuile.gd").brancher(bouton, bouton, C.px(16))
		Kit.etiquette(bouton, 14, 30, str(tuile.etiquette), cote - 28)
		var chiffre := D.text(bouton, 14, 88, str(tuile.valeur), 46, Charte.IVOIRE, 800, 120)
		chiffre.add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
		var largeur_chiffre := Charte.TITRE_EXTRA_ITALIQUE.get_string_size(str(tuile.valeur), HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(12, C.px(46))).x / C.density
		Kit.texte(bouton, 14 + largeur_chiffre + 8, 86, str(tuile.sur), Charte.IVOIRE_2, 80, 19)
		if float(tuile.barre) >= 0.0:
			D.rect(bouton, Rect2(14, 104, cote - 28, 8), Charte.PANNEAU_3, Charte.RAYON_PILULE)
			D.rect(bouton, Rect2(14, 104, (cote - 28) * clampf(float(tuile.barre) / 100.0, 0.0, 1.0), 8), Charte.IVOIRE_2, Charte.RAYON_PILULE)
		if not str(tuile.suite).is_empty(): _texte_lignes(bouton, 14, 112, cote - 28, str(tuile.suite), 16, Charte.TEXTE, Charte.IVOIRE_2, 2).mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Leader du vestiaire : le nom ouvre la fiche, le survol la mini-fiche.
	var relation: Dictionary = app.model.get("clubLife", {}).get("relationships", {})
	var chef := P.player(app.model, str(relation.get("leaderId", "")))
	var tuile_chef := D.rect(panneau, Rect2(24 + 2 * (cote + 12), 66, cote, 150), Charte.PANNEAU_2, 16)
	tuile_chef.name = "ClubLeader"
	tuile_chef.mouse_filter = Control.MOUSE_FILTER_PASS
	Kit.etiquette(tuile_chef, 14, 30, "Leader", cote - 28)
	if chef.is_empty(): Kit.texte(tuile_chef, 14, 80, "À déterminer", Charte.IVOIRE_2, cote - 28, 20)
	else:
		var nom := Kit.nom(app, tuile_chef, Rect2(10, 48, cote - 20, 40), Kit.casse(str(chef.get("name", ""))), str(chef.get("id", "")), "ClubLeaderLink", Charte.IVOIRE, 24)
		nom.accessibility_name = str(chef.get("name", "")) + " · leader du vestiaire"
		Kit.texte(tuile_chef, 14, 112, "capitaine · %s" % str(chef.get("pos", "")) if not str(chef.get("pos", "")).is_empty() else "capitaine", Charte.IVOIRE_2, cote - 28, 17)
	Kit.etiquette(panneau, 24, 254, "Absents", 300)
	D.line(panneau, Vector2(18, 262), Vector2(largeur - 18, 262), Charte.FILET)
	absents.sort_custom(func(a: Dictionary, b: Dictionary): return float(a.get("injury", 0)) > float(b.get("injury", 0)))
	var maximum := 8
	if absents.is_empty(): Kit.texte(panneau, 24, 300, "Aucun joueur absent cette semaine.", Charte.IVOIRE_2, 600, 19).name = "ClubAbsentNone"
	for i in mini(maximum, absents.size()):
		var joueur: Dictionary = absents[i]
		var haut := 266.0 + i * LIGNE
		if i > 0: D.line(panneau, Vector2(18, haut), Vector2(largeur - 18, haut), Charte.FILET)
		Kit.nom(app, panneau, Rect2(24, haut + 3, 330, LIGNE - 6), Kit.casse(str(joueur.get("name", ""))), str(joueur.get("id", "")), "ClubAbsentName%d" % i, Charte.IVOIRE, 18)
		Kit.texte(panneau, largeur - 24, haut + 22, _statut_absent(joueur), Charte.IVOIRE_2, largeur - 400, 17, HORIZONTAL_ALIGNMENT_RIGHT)
	if absents.size() > maximum:
		var reste := Kit.lien(panneau, Rect2(24, 266 + maximum * LIGNE + 10, 0, 34), "+ %d autres absents → vestiaire" % (absents.size() - maximum), func(): app._navigate("Vestiaire"), "ClubAbsentMore", 18)
		reste.tooltip_text = ""

static func _statut_absent(joueur: Dictionary) -> String:
	match Etat.indisponibilite(joueur):
		"blesse":
			var semaines := ceili(float(joueur.get("injury", 0)))
			return "Blessé · retour dans %s" % P.plural(semaines, "semaine", "semaines")
		"suspendu":
			return "Suspendu · %s" % P.plural(int(joueur.get("suspension", 1)), "match", "matchs")
		"selection": return "En sélection"
	return ""

# --- Onglets autres que la vue d'ensemble (dessinés depuis y = 214, remontés par le corps de la page) --------------------

## Carte du stade (photo du club, nom, capacité) : un clic ouvre « Le stade ».
static func _stade(panneau: Panel, app: Control, fans: Dictionary) -> void:
	var identite := G.identity(app.model.club)
	var image := G.club_picture(app.model.club, "stadium", false)
	panneau.clip_contents = true
	panneau.add_child(image)
	D.place(image, Rect2(0, 56, panneau.size.x / C.density, 150))
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Kit.texte(panneau, 24, 238, str(identite.get("stadium", "Le stade du club")), Charte.IVOIRE, 760, 24).add_theme_font_override("font", Kit.texte_gras())
	var x_tuile := 24.0
	for chiffre: Array in [["capacity", "places", Pastilles.TURQUOISE], ["expectedAttendance", "affluence", Pastilles.BLEU], ["subscribers", "abonnés", Pastilles.VIOLET]]:
		if not fans.has(chiffre[0]): continue
		x_tuile += Pastilles.poser(panneau, Pastilles.tuile(_milliers(fans[chiffre[0]]), str(chiffre[1]), chiffre[2], Charte.PANNEAU_2, 22, "ClubStadiumFigure_" + str(chiffre[0]), true, func(): _tab(app, "territory", "ClubTab_overview")), x_tuile, 246) + 8.0
	var voir_stade := Kit.lien(panneau, Rect2(panneau.size.x / C.density - 24, 12, 0, 34), "Voir le stade →", func(): _tab(app, "territory", "ClubTab_overview"), "ClubSeeStadiumLink", 19, true)
	voir_stade.tooltip_text = ""

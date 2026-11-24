extends "res://ui/immersive08/academy_tableau.gd"
## Écran Formation (découpe de academy_canvas.gd, sans changement) : onglet Passerelles (parcours, prospects, juniors).

# --- Passerelles -------------------------------------------------------------------------------------------------------

func _inactive_pathway_status() -> String:
	return "Parcours à activer" if pathway.get("available", false) else "Au calendrier des Espoirs"

func _pathways() -> void:
	var panel := D.rect(self, Rect2(0, 216, WIDTH, 980), Charte.PANNEAU, Charte.RAYON_PANNEAU)
	panel.name = "AcademyPathwayPane"
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	Kit.titre(panel, 24, 52, "Du centre au rugby professionnel", 30, 1200)
	Kit.texte(panel, 24, 86, Copy.notice("academy", pathway.get("description", "Choisis un Espoir pour suivre sa progression.")), Charte.IVOIRE_2, 1700, 18)
	var loans: Array = pathway.get("loans", [])
	var promoted: Array = pathway.get("promotions", [])
	var active: bool = pathway.get("active", false)
	var entries := [
		["ACADÉMIE", P.plural(roster.size(), "espoir", "espoirs"), "Meilleurs potentiels", _prospects(), func(): _open_tab(0), "AcademyStage0"],
		["PASSERELLES", P.plural(loans.size(), "prêt en cours", "prêts en cours") if active else _inactive_pathway_status(), "Joueurs en prêt", loans, func(): app._navigate("Centre"), "AcademyStage1"],
		["ÉQUIPE PREMIÈRE", P.plural(promoted.size(), "promotion", "promotions") if active else "Premiers contrats", "Joueurs promus", promoted, func(): app._navigate("Effectif"), "AcademyStage2"],
	]
	var largeur := (WIDTH - 48.0 - 2 * 24.0) / 3.0
	for i in entries.size():
		var entry: Array = entries[i]
		var x := 24.0 + i * (largeur + 24.0)
		var tuile := Button.new()
		tuile.name = str(entry[5])
		tuile.flat = true
		tuile.focus_mode = Control.FOCUS_ALL
		tuile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tuile.accessibility_name = "%s : %s" % [str(entry[0]), str(entry[1])]
		tuile.add_theme_stylebox_override("normal", C.box(Charte.PANNEAU_2, Color.TRANSPARENT, 16, 0))
		tuile.add_theme_stylebox_override("hover", C.box(Charte.PANNEAU_3, Color.TRANSPARENT, 16, 0))
		var focus := C.box(Color.TRANSPARENT, Charte.IVOIRE, 16, 0)
		focus.set_border_width_all(2)
		tuile.add_theme_stylebox_override("focus", focus)
		tuile.pressed.connect(entry[4])
		panel.add_child(tuile)
		D.place(tuile, Rect2(x, 122, largeur, 104))
		Kit.marqueur(tuile, Rect2(12, 20, 6, 64), Charte.IVOIRE if i == 0 else Charte.IVOIRE_2)
		D.text(tuile, 34, 44, str(entry[0]), 30, Charte.IVOIRE, 700, largeur - 60).add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
		D.text(tuile, 34, 84, str(entry[1]) + "  →", 22, Charte.IVOIRE_2, 600, largeur - 60)
		for enfant in tuile.get_children():
			if enfant is Control: (enfant as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		Kit.etiquette(panel, x, 270, str(entry[2]), largeur)
		var people: Array = entry[3]
		if people.is_empty():
			var legende := "Aucun dossier"
			if not active and i > 0: legende = "Disponible dans le centre" if pathway.get("available", false) else "—"
			Kit.texte(panel, x, 312, legende, Charte.IVOIRE_3, largeur, 18)
		for j in mini(8, people.size()):
			_ligne_personne(panel, people[j], Rect2(x, 288 + j * 40, largeur, 38), i == 0)
	var centre := Kit.lien(panel, Rect2(24, 650, 0, 40), "Ouvrir les parcours du centre : mentorats, prêts et détection →", func(): app._navigate("Centre"), "AcademyOpenCentre", 20)
	centre.tooltip_text = ""
	var suivi := Kit.lien(panel, Rect2(24, 698, 0, 40), "Suivre les objectifs et gains observés →", func(): Pages.ouvrir(app, "suivi"), "AcademyFollowUp", 20)
	suivi.tooltip_text = ""
	_junior(panel)

## Ligne d'un jeune des parcours : portrait, nom (fiche / mini-fiche), poste et âge, potentiel.
func _ligne_personne(parent: Control, p: Dictionary, zone: Rect2, avec_potentiel: bool) -> void:
	var ligne := D.rect(parent, zone, Color.TRANSPARENT, 8)
	D.line(ligne, Vector2(0, zone.size.y - 1), Vector2(zone.size.x, zone.size.y - 1), Charte.FILET)
	ligne.mouse_filter = Control.MOUSE_FILTER_PASS
	_portrait(ligne, p, Rect2(6, 4, 30, 30))
	var id := str(p.get("id", ""))
	var cible := {"kind":"academy", "id":id}
	var nom_texte := str(p.get("name", "Joueur"))
	var lien: Control = null
	if not id.is_empty() and app.navigation_controller.entity_available(cible):
		var bouton := Button.new()
		bouton.name = "AcademyPathway_" + id.replace(":", "_")
		bouton.flat = true
		bouton.text = nom_texte
		bouton.alignment = HORIZONTAL_ALIGNMENT_LEFT
		bouton.focus_mode = Control.FOCUS_ALL
		bouton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		bouton.add_theme_font_override("font", Charte.TITRE_GRAS)
		bouton.add_theme_font_size_override("font_size", maxi(12, C.px(22)))
		for etat in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: bouton.add_theme_color_override(etat, Charte.IVOIRE)
		bouton.add_theme_stylebox_override("normal", C.box(Color.TRANSPARENT, Color.TRANSPARENT, 8, 0))
		bouton.add_theme_stylebox_override("hover", C.box(Color(Charte.IVOIRE, .08), Color.TRANSPARENT, 8, 0))
		var focus := C.box(Color.TRANSPARENT, Charte.IVOIRE, 8, 0)
		focus.set_border_width_all(2)
		bouton.add_theme_stylebox_override("focus", focus)
		bouton.pressed.connect(func():
			state.player = id
			app.navigation_controller.open_entity(cible))
		ligne.add_child(bouton)
		D.place(bouton, Rect2(44, 0, 300, zone.size.y))
		MiniFiche.lier(app, bouton, id, "academy")
		lien = bouton
	else:
		D.text(ligne, 44, 26, nom_texte, 22, Charte.IVOIRE, 700, 300)
	Kit.texte(ligne, 360, 26, "%s · %s ans" % [str(p.get("pos", "Carrière")), G.n(p.get("age", "—"))], Charte.IVOIRE_2, zone.size.x - 520, 17)
	if avec_potentiel:
		var potentiel: Variant = G.knowledge_sort_value(p, "potential")
		D.text(ligne, zone.size.x - 14, 27, ("★ " if _pepite(p) else "") + G.potential_text(p), 20, Charte.couleur_attribut(potentiel) if potentiel != null else Charte.IVOIRE_3, 700, 160, HORIZONTAL_ALIGNMENT_RIGHT)

func _prospects() -> Array:
	var prospects := roster.duplicate()
	prospects.sort_custom(_potential_before)
	return prospects

func _junior(parent: Control) -> void:
	var results: Array = pathway.get("results", [])
	var contexte := _inactive_pathway_status()
	if pathway.get("active", false):
		var tour := int(pathway.get("juniorRound", 0))
		var total := int(pathway.get("totalRounds", 0))
		contexte = "période %d / %d" % [mini(tour + 1, total), total] if tour < total else "périodes terminées"
	Kit.etiquette(parent, 24, 790, "Compétition junior", 600)
	var phrase := "Calendrier indépendant du championnat pro" if pathway.get("available", false) else "Suivi des Espoirs dans Formation"
	if not results.is_empty():
		var dernier: Dictionary = results[-1]
		var club: Dictionary = app.model.club
		var domicile: bool = dernier.get("home") == club.get("id")
		var adverse := _club(dernier.get("away") if domicile else dernier.get("home"))
		var score: Array = dernier.get("score", [])
		if score.size() == 2: phrase = "Dernier résultat connu · période %s · %s %s – %s %s" % [G.n(int(dernier.get("round", 0)) + 1), G.club_abbr(club), G.n(score[0 if domicile else 1]), G.n(score[1 if domicile else 0]), G.club_abbr(adverse)]
	var ligne := Kit.lien(parent, Rect2(24, 806, 0, 40), "%s · %s →" % [contexte.capitalize(), phrase], func(): app._navigate("Centre"), "AcademyJuniorCompetition", 19)
	ligne.tooltip_text = ""

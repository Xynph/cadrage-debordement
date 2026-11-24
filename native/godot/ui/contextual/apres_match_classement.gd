extends "res://ui/contextual/apres_match_verdict.gd"
## Après-match (apres_match.gd), morceau : colonne de droite : classement complet, ta place, autres matchs, légende, bloc « Valider le résultat ».
## Chaîne d'héritage de l'écran : socle ← outils ← joueurs ← bandeau ← verdict ← classement ← apres_match.gd.

func _zones() -> Array:
	var z: Variant = _ligue().get("zones")
	return z if z is Array else []

func _zone(rang: int) -> Dictionary:
	for z: Variant in _zones():
		if z is Dictionary and rang >= int(z.get("from", 0)) and rang <= int(z.get("to", -1)): return z
	return {}

func _colonne_classement(parent: VBoxContainer) -> void:
	var classement := _classement()
	if not classement.is_empty():
		var cadre := _panneau(Charte.PANNEAU, 16, 10)
		cadre.name = "ApresMatchClassement"
		parent.add_child(cadre)
		var col := _v(0)
		cadre.add_child(col)
		var titre := _h(8)
		titre.custom_minimum_size.y = _d(28)
		col.add_child(titre)
		var etape := _etape_courte()
		titre.add_child(_texte(("Classement après la " + etape if not etape.is_empty() else "Classement après la journée").to_upper(), 18, Charte.IVOIRE, Charte.TITRE_GRAS))
		var droite := _texte(" · ".join(PackedStringArray([_nom_competition(), "%d clubs" % classement.size()]).slice(0 if not _nom_competition().is_empty() else 1)), 12, Charte.IVOIRE_2)
		droite.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		C.fill(droite)
		titre.add_child(droite)
		col.add_child(_ligne_table(["", "#", "CLUB", "J", "V", "N", "D", "DIFF.", "PTS", "FORME"], true))
		for r: Variant in classement:
			if r is Dictionary: col.add_child(_ligne_club(r, classement.size()))
		var legende := _legende()
		if legende != null: col.add_child(legende)
		_ta_place = _place(classement, _e < 0.8)
		if _ta_place != null: parent.add_child(_ta_place)
	_autres = _autres_matchs(_e < 0.8)
	if _autres != null: parent.add_child(_autres)
	var vide := Control.new()
	vide.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(vide)
	parent.add_child(_bloc_valider())

const LARGEURS := [30, 30, 0, 30, 30, 30, 30, 50, 40, 140]

func _cellule(texte: String, k: int, couleur: Color = Charte.IVOIRE, police: Font = Charte.TEXTE, taille: float = 13) -> Label:
	var l := _texte(texte, taille, couleur, police)
	if LARGEURS[k] > 0: l.custom_minimum_size.x = _d(LARGEURS[k])
	else: C.fill(l)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if k in [1, 3, 4, 5, 6, 7, 8] else HORIZONTAL_ALIGNMENT_LEFT
	l.clip_text = true
	return l

func _ligne_table(entetes: Array, entete: bool) -> PanelContainer:
	var ligne := PanelContainer.new()
	var style := _fond(Color(0, 0, 0, 0), 0, 0)
	style.border_width_bottom = 1
	style.border_color = Charte.FILET
	ligne.add_theme_stylebox_override("panel", style)
	ligne.custom_minimum_size.y = _d(24)
	var r := _h(6)
	ligne.add_child(r)
	for k in entetes.size(): r.add_child(_cellule(str(entetes[k]), k, Charte.IVOIRE_2, Charte.TITRE, 12))
	return ligne

## Ligne d'un club : zone (liseré, symbole dessiné), rang, sigle et nom (lien vers sa fiche), J V N D, différence,
## points, forme (cinq pastilles V/N/D). Notre club : fond choisi et liseré à sa couleur.
func _ligne_club(r: Dictionary, total: int) -> PanelContainer:
	var rang := int(r.get("rang", 0))
	var nous := bool(r.get("nous", false))
	var zone := _zone(rang)
	var ligne := PanelContainer.new()
	ligne.name = "ApresMatchLigne%d" % rang
	ligne.set_meta("rang", rang)
	ligne.set_meta("zone", str(zone.get("kind", "")))
	# Pas de bandes alternées : un filet entre les lignes ; notre club en ligne sélectionnée (SELECTION, coins de 6 px).
	var style := _fond(Charte.SELECTION if nous else Color(0, 0, 0, 0), 0, 0, -1, -1, Charte.RAYON_PETIT if nous else 0)
	if not nous and rang < total:
		style.border_width_bottom = 1
		style.border_color = Charte.FILET
	# Fin de zone : filet plus marqué sous la dernière ligne de la zone.
	if not zone.is_empty() and rang < total and _zone(rang + 1).get("kind") != zone.get("kind"):
		style.border_width_bottom = 1
		style.border_color = Charte.IVOIRE_3
	ligne.add_theme_stylebox_override("panel", style)
	ligne.custom_minimum_size.y = _d(24)
	var rangee := _h(6)
	ligne.add_child(rangee)
	var case_zone := _h(0)
	case_zone.custom_minimum_size.x = _d(LARGEURS[0])
	var lisere := ColorRect.new()
	lisere.custom_minimum_size.x = maxi(2, _d(3))
	lisere.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var club := _club(r.get("clubId"))
	lisere.color = Charte.club_trait(_couleur(club)) if nous else (Zones.tint(str(zone.kind)) if not zone.is_empty() else Color(0, 0, 0, 0))
	case_zone.add_child(lisere)
	var centre := CenterContainer.new()
	C.fill(centre)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not zone.is_empty():
		var marque := Zones.mark_slot(str(zone.kind), 10.0 * _e)
		centre.add_child(marque)
		centre.tooltip_text = str(zone.get("label", ""))
		centre.mouse_filter = Control.MOUSE_FILTER_PASS
	case_zone.add_child(centre)
	rangee.add_child(case_zone)
	rangee.add_child(_cellule(str(rang), 1))
	var case_club := _h(8)
	C.fill(case_club)
	# Petites hauteurs : sans le sigle, le nom du club garde sa place (la forme a sa largeur minimale).
	if _e >= 0.8: case_club.add_child(_sigle(club if not club.is_empty() else {"abbr": r.get("abbr", "")}, 28, 20, 12))
	var nom := str(r.get("nom", "")) if club.is_empty() else G.club_name(club)
	var lien := _lien(nom, {"kind": "club", "id": _cle_id(r.get("clubId"))}, 13)
	lien.name = "ApresMatchClubLigne%d" % rang
	if nous: lien.add_theme_font_override("font", C.BOLD)
	lien.clip_text = true
	lien.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	lien.tooltip_text = nom
	C.fill(lien)
	case_club.add_child(lien)
	rangee.add_child(case_club)
	rangee.add_child(_cellule(str(int(r.get("joues", 0))), 3))
	for k in [["gagnes", 4], ["nuls", 5], ["perdus", 6]]:
		rangee.add_child(_cellule(str(int(r.get(k[0], 0))) if r.has(k[0]) else "", k[1]))
	rangee.add_child(_cellule(signe(int(r.get("diff", 0))), 7, Charte.IVOIRE_2, Charte.TEXTE, 12))
	rangee.add_child(_cellule(str(int(r.get("points", 0))), 8, Charte.IVOIRE, C.BOLD))
	var forme := _h(3)
	forme.custom_minimum_size.x = maxi(_d(LARGEURS[9]), 5 * 20 + 4 * 3)
	forme.name = "Forme"
	for lettre: String in forme_vnd(r.get("forme", []) if r.get("forme") is Array else []):
		forme.add_child(_pastille(lettre, 24, 16, 11))
	rangee.add_child(forme)
	return ligne

## Forme en lettres V / N / D. Le moteur (CDWorldCareer.rows, via match-multiplex.cjs) l'écrit déjà en V / N / D, où
## D veut dire défaite ; une forme brute W / D / L (D = nul) est reconnue à ses W ou L et convertie (W→V, D→N, L→D).
static func forme_vnd(forme: Array) -> Array[String]:
	var brute := forme.any(func(x: Variant): return str(x) in ["W", "L"])
	var table: Dictionary = {"W": "V", "D": "N", "L": "D"} if brute else {"V": "V", "N": "N", "D": "D"}
	var sortie: Array[String] = []
	for x: Variant in forme:
		if table.has(str(x)): sortie.append(str(table[str(x)]))
	return sortie

## Légende des zones présentes : symbole dessiné et libellé (« 1er à 4e · Phases finales »), puis la note courte.
func _legende() -> Control:
	var zones := _zones()
	var note := str(_ligue().get("zoneShortNote", "")) if _ligue().get("zoneShortNote") is String else ""
	if zones.is_empty() and note.is_empty(): return null
	var rang := _h(24)
	rang.name = "ApresMatchLegende"
	rang.custom_minimum_size.y = _d(26)
	for z: Variant in zones:
		if not z is Dictionary: continue
		var item := _h(5)
		item.add_child(Zones.mark_slot(str(z.get("kind", "")), 10.0 * _e))
		var de := int(z.get("from", 0))
		var a := int(z.get("to", 0))
		item.add_child(_texte(("%s à %s" % [ordinal(de), ordinal(a)] if a > de else ordinal(de)) + " · " + str(z.get("label", "")), 12, Charte.IVOIRE))
		rang.add_child(item)
	if not note.is_empty(): rang.add_child(_texte(note, 12, Charte.IVOIRE_2))
	return rang

## Écart de points écrit en toutes lettres : « 3 pts d'avance sur le 13e », « à 20 pts du 1er », « à égalité avec le 11e ».
static func ecart_texte(ecart: int, rang: int) -> String:
	if ecart > 0: return "%d pt%s d’avance sur le %s" % [ecart, "s" if ecart > 1 else "", ordinal(rang)]
	if ecart < 0: return "à %d pt%s du %s" % [-ecart, "s" if ecart < -1 else "", ordinal(rang)]
	return "à égalité avec le %s" % ordinal(rang)

## Ta place : écart de points avec le premier et nos voisins directs (chacun mène à la fiche du club). `condense` :
## une seule ligne (petites hauteurs d'écran), toujours présente.
func _place(classement: Array, condense: bool = false) -> Control:
	var nous := {}
	for r: Variant in classement:
		if r is Dictionary and bool(r.get("nous", false)): nous = r
	if nous.is_empty(): return null
	var rang := int(nous.get("rang", 0))
	var voisins: Array = []
	for cible in [1, rang - 1, rang + 1, rang + 2]:
		if cible < 1 or cible > classement.size() or cible == rang or voisins.size() >= 3: continue
		if voisins.any(func(v: Dictionary): return int(v.get("rang", 0)) == cible): continue
		var r: Variant = classement[cible - 1]
		if r is Dictionary: voisins.append(r)
	var cadre := _panneau(Charte.PANNEAU, 16, 6 if condense else 10)
	cadre.name = "ApresMatchTaPlace"
	cadre.set_meta("condense", condense)
	var col := _v(6)
	cadre.add_child(col)
	var titre := _h(8)
	col.add_child(titre)
	titre.add_child(_texte("TA PLACE", 15, Charte.IVOIRE, Charte.TITRE_GRAS))
	var zone := _zone(rang)
	var resume := "%s · %d pts" % [ordinal(rang), int(nous.get("points", 0))] + ((" · " + str(zone.get("label", "")).to_lower()) if not zone.is_empty() else "")
	if condense:
		titre.add_child(_texte(resume, 12, Charte.IVOIRE_2))
		var flux := HFlowContainer.new()
		flux.add_theme_constant_override("h_separation", _d(14))
		col.add_child(flux)
		for v: Dictionary in voisins:
			var club_v := _club(v.get("clubId"))
			var nom_v := G.club_name(club_v) if not club_v.is_empty() else str(v.get("nom", ""))
			var lien := _lien(ecart_texte(int(nous.get("points", 0)) - int(v.get("points", 0)), int(v.get("rang", 0))) + ", " + nom_v, {"kind": "club", "id": _cle_id(v.get("clubId"))}, 12)
			lien.name = "ApresMatchEcart%d" % int(v.get("rang", 0))
			_aide(lien, "%s · %d pts" % [nom_v, int(v.get("points", 0))])
			flux.add_child(lien)
		return cadre
	var droite := _texte(resume, 12, Charte.IVOIRE_2)
	droite.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	C.fill(droite)
	titre.add_child(droite)
	var cases := _h(8)
	col.add_child(cases)
	for v: Dictionary in voisins:
		var ecart := int(nous.get("points", 0)) - int(v.get("points", 0))
		var club := _club(v.get("clubId"))
		var nom := G.club_name(club) if not club.is_empty() else str(v.get("nom", ""))
		var b := _lien("", {"kind": "club", "id": _cle_id(v.get("clubId"))}, 12)
		b.name = "ApresMatchEcart%d" % int(v.get("rang", 0))
		_aide(b, "%s · %d pts" % [nom, int(v.get("points", 0))])
		b.add_theme_stylebox_override("normal", _fond(Charte.PANNEAU_2, 10, 6, -1, -1, Charte.RAYON_CARTE))
		b.add_theme_stylebox_override("hover", _fond(Charte.PANNEAU_3, 10, 6, -1, -1, Charte.RAYON_CARTE))
		var focus_case := _fond(Charte.PANNEAU_3, 10, 6, -1, -1, Charte.RAYON_CARTE)
		focus_case.border_color = Charte.OR
		focus_case.set_border_width_all(2)
		b.add_theme_stylebox_override("focus", focus_case)
		b.add_theme_stylebox_override("pressed", _fond(Charte.PANNEAU_3, 10, 6, -1, -1, Charte.RAYON_CARTE))
		C.fill(b)
		var contenu := _v(0)
		contenu.mouse_filter = Control.MOUSE_FILTER_IGNORE
		contenu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		contenu.offset_left = _d(10)
		contenu.offset_top = _d(4)
		contenu.add_child(_texte(signe(ecart) if ecart != 0 else "=", 20, Charte.IVOIRE, Charte.TITRE_GRAS))
		contenu.add_child(_texte(ecart_texte(ecart, int(v.get("rang", 0))) + ", " + nom, 12, Charte.IVOIRE_2, Charte.TEXTE, true))
		b.add_child(contenu)
		b.custom_minimum_size.y = _d(60)
		b.clip_contents = true
		cases.add_child(b)
	return cadre

## Les autres matchs de la journée (`journee.matchs`, résultats réels du moteur) ; un clic ouvre le calendrier du jour
## (le jeu n'a pas d'écran de résumé d'une rencontre : sa fiche est une petite fenêtre). Une colonne avec les noms
## entiers ; `sigles` (place comptée) : trois colonnes « sigle score sigle », noms entiers en infobulle. Jamais de « … ».
func _autres_matchs(sigles: bool = false) -> Control:
	var matchs: Variant = _journee().get("matchs")
	if not matchs is Array or matchs.is_empty(): return null
	var cadre := _panneau(Charte.PANNEAU, 16, 10)
	cadre.name = "ApresMatchAutresMatchs"
	cadre.set_meta("sigles", sigles)
	var col := _v(4)
	cadre.add_child(col)
	var etape := _etape_courte()
	col.add_child(_texte(("Les autres matchs de la " + etape if not etape.is_empty() else "Les autres matchs de la journée").to_upper(), 15, Charte.IVOIRE, Charte.TITRE_GRAS))
	var grille := GridContainer.new()
	grille.columns = 3 if sigles else 1
	grille.name = "ApresMatchAutresGrille"
	grille.add_theme_constant_override("h_separation", _d(16))
	grille.add_theme_constant_override("v_separation", _d(2))
	col.add_child(grille)
	var date := str(_fixture().get("date", ""))
	var cible: Dictionary = {"kind": "date", "id": date} if not date.is_empty() else {"kind": "competition", "id": str(_fixture().get("competitionId", ""))}
	var n := 0
	for m: Variant in matchs:
		if not m is Dictionary: continue
		var dom: Dictionary = m.get("home", {}) if m.get("home") is Dictionary else {}
		var ext: Dictionary = m.get("away", {}) if m.get("away") is Dictionary else {}
		var c1 := _club(dom.get("id"))
		var c2 := _club(ext.get("id"))
		var n1 := G.club_name(c1) if not c1.is_empty() else str(dom.get("nom", ""))
		var n2 := G.club_name(c2) if not c2.is_empty() else str(ext.get("nom", ""))
		var b := _lien("", cible, 13)
		b.name = "ApresMatchAutreMatch%d" % n
		_aide(b, "%s %d – %d %s · le calendrier du jour" % [n1, int(dom.get("score", 0)), int(ext.get("score", 0)), n2])
		C.fill(b)
		var rang := _h(6)
		rang.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rang.add_child(_sigle(c1 if not c1.is_empty() else {"abbr": dom.get("abbr", "")}, 28, 20, 12))
		if not sigles:
			var nom1 := _texte(n1, 13)
			C.fill(nom1)
			rang.add_child(nom1)
		var score := _texte("%d – %d" % [int(dom.get("score", 0)), int(ext.get("score", 0))], 14, Charte.IVOIRE, Charte.TITRE_GRAS)
		score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		score.custom_minimum_size.x = _d(56)
		rang.add_child(score)
		if not sigles:
			var nom2 := _texte(n2, 13)
			nom2.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			C.fill(nom2)
			rang.add_child(nom2)
		rang.add_child(_sigle(c2 if not c2.is_empty() else {"abbr": ext.get("abbr", "")}, 28, 20, 12))
		# Le bouton ne mesure pas ses enfants : la rangée est posée dessus et lui donne sa taille minimale.
		b.add_child(rang)
		rang.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		b.custom_minimum_size = Vector2(rang.get_combined_minimum_size().x, maxf(_d(24), rang.get_combined_minimum_size().y))
		rang.minimum_size_changed.connect(func(): b.custom_minimum_size = Vector2(rang.get_combined_minimum_size().x, maxf(_d(24), rang.get_combined_minimum_size().y)))
		grille.add_child(b)
		n += 1
	return cadre

## Seul aplat doré de l'écran (charte : le bouton principal d'une page sans Continuer), en pilule : valide le résultat.
func _bloc_valider() -> Control:
	var col := _v(10)
	col.name = "ApresMatchSuite"
	col.alignment = BoxContainer.ALIGNMENT_END
	var aide := _texte("Valide le résultat · la suite de ta semaine s’ouvre ensuite", 13, Charte.IVOIRE_2)
	aide.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# Petites hauteurs : le libellé du bouton suffit, la colonne de droite garde le classement entier.
	aide.visible = _e >= 0.8
	col.add_child(aide)
	var b := Button.new()
	b.name = "ApresMatchValider"
	b.text = ""
	b.accessibility_name = "Valider le résultat · touche Espace"
	b.custom_minimum_size = Vector2(_d(440), _d(56))
	b.size_flags_horizontal = Control.SIZE_SHRINK_END
	for look in ["normal", "hover", "pressed", "disabled"]: b.add_theme_stylebox_override(look, StyleBoxEmpty.new())
	# Focus (charte §7) : le seul cadre complet permis, et seulement en navigation au clavier ; au repos et à la souris,
	# rien (le bouton a pourtant le focus à l'ouverture : Espace ou Entrée valident).
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var cadre_focus := Panel.new()
	cadre_focus.name = "ApresMatchValiderFocus"
	var trait_focus := StyleBoxFlat.new()
	trait_focus.draw_center = false
	# Anneau de focus de la charte : doré, 2 px, décalé de 2 px, en pilule comme le bouton.
	trait_focus.border_color = Charte.OR
	trait_focus.set_border_width_all(2)
	trait_focus.set_corner_radius_all(Charte.RAYON_PILULE)
	trait_focus.anti_aliasing = true
	cadre_focus.add_theme_stylebox_override("panel", trait_focus)
	cadre_focus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cadre_focus.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for cote: String in ["offset_left", "offset_top"]: cadre_focus.set(cote, -_d(4))
	for cote: String in ["offset_right", "offset_bottom"]: cadre_focus.set(cote, _d(4))
	cadre_focus.hide()
	b.add_child(cadre_focus)
	b.focus_entered.connect(_maj_focus_clavier)
	b.focus_exited.connect(_maj_focus_clavier)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.set_meta("contextual_enabled", true)
	var plaque := Trace.new("pave", Charte.OR)
	plaque.name = "ApresMatchValiderFond"
	plaque.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	b.add_child(plaque)
	b.mouse_entered.connect(func(): plaque.couleur = Charte.OR_VIF; plaque.queue_redraw())
	b.mouse_exited.connect(func(): plaque.couleur = Charte.OR; plaque.queue_redraw())
	var rang := _h(14)
	rang.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rang.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rang.offset_left = _d(28)
	rang.offset_right = -_d(28)
	b.add_child(rang)
	var libelle := _texte("VALIDER LE RÉSULTAT", 22, Charte.PANNEAU, Charte.TITRE_EXTRA)
	libelle.name = "ApresMatchValiderTexte"
	C.fill(libelle)
	rang.add_child(libelle)
	var filet := ColorRect.new()
	filet.color = Color(Charte.PANNEAU, 0.35)
	filet.custom_minimum_size = Vector2(1, _d(24))
	filet.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	filet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rang.add_child(filet)
	rang.add_child(_texte("Espace", 13, Charte.PANNEAU))
	b.pressed.connect(valider)
	bouton_valider = b
	col.add_child(b)
	return col

func _maj_focus_clavier() -> void:
	if not is_instance_valid(bouton_valider): return
	var cadre_focus := bouton_valider.get_node_or_null("ApresMatchValiderFocus") as Control
	if cadre_focus != null: cadre_focus.visible = clavier and bouton_valider.has_focus()

func valider() -> void:
	if director != null and director.has_method("command"): director.command("finish_round")

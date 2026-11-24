extends "res://ui/contextual/apres_match_joueurs.gd"
## Après-match (apres_match.gd), morceau : bandeau vestiaire : menu Plus, score, plaques des clubs, lignes d'information.
## Chaîne d'héritage de l'écran : socle ← outils ← joueurs ← bandeau ← verdict ← classement ← apres_match.gd.

func _bandeau() -> Control:
	var bandeau := Control.new()
	bandeau.name = "ApresMatchBandeau"
	bandeau.custom_minimum_size.y = _d(324)
	bandeau.clip_contents = true
	var photo := C.photo("lockerroom", Vector2.ZERO, true, 0.35)
	photo.tooltip_text = ""
	photo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bandeau.add_child(photo)
	C.veil(bandeau)
	var marge := MarginContainer.new()
	marge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	marge.add_theme_constant_override("margin_left", _d(48))
	marge.add_theme_constant_override("margin_top", _d(20))
	marge.add_theme_constant_override("margin_right", _d(24))
	marge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bandeau.add_child(marge)
	var col := _v(10)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marge.add_child(col)
	# Ligne du haut : FIN, compétition · étape · stade · date, et le menu Plus à droite.
	var haut := _h(12)
	col.add_child(haut)
	var fin := PanelContainer.new()
	fin.add_theme_stylebox_override("panel", _fond(Charte.PANNEAU_3, 6, 1, -1, -1, Charte.RAYON_PETIT))
	fin.add_child(_texte("FIN", 12, Charte.IVOIRE, Charte.TITRE_GRAS))
	fin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	haut.add_child(fin)
	var lieu: Array[String] = []
	for morceau: String in [_nom_competition(), _etape_courte(), P.fixture_venue(_fixture(), false) if not _fixture().is_empty() else "", P.fixture_date(_fixture()) if not _fixture().is_empty() else ""]:
		if not morceau.is_empty(): lieu.append(morceau)
	var contexte := _texte(" · ".join(PackedStringArray(lieu)), 13, Charte.IVOIRE_2)
	contexte.name = "ApresMatchContexte"
	C.fill(contexte)
	haut.add_child(contexte)
	haut.add_child(_menu_plus())
	# Verdict : pastille V/N/D en pilule et mot.
	var verdict := _h(16)
	col.add_child(verdict)
	var lettre: String = {"victoire": "V", "defaite": "D", "nul": "N"}.get(issue(), "N")
	verdict.add_child(_pastille(lettre, 72, 48, 32))
	var mot := _texte({"victoire": "Victoire", "defaite": "Défaite", "nul": "Match nul"}.get(issue(), "Match nul").to_upper(), 28, Charte.IVOIRE, Charte.TITRE_EXTRA)
	mot.name = "ApresMatchVerdict"
	verdict.add_child(mot)
	col.add_child(_ligne_score())
	for ligne: HBoxContainer in _meta(): col.add_child(ligne)
	return bandeau

func _menu_plus() -> MenuButton:
	var plus := MenuButton.new()
	plus.name = "ApresMatchPlus"
	plus.text = "Plus  ▾"
	plus.flat = false
	# Bouton secondaire de la charte : pilule à contour FILET sur un panneau (lisible sur la photo voilée), focus doré.
	C.style_bouton_contour(plus, 15)
	for look in ["normal", "disabled"]:
		var s := (plus.get_theme_stylebox(look) as StyleBoxFlat).duplicate() as StyleBoxFlat
		s.bg_color = Color(Charte.PANNEAU, 0.85)
		plus.add_theme_stylebox_override(look, s)
	plus.add_theme_font_override("font", Charte.TEXTE)
	plus.add_theme_font_size_override("font_size", _f(15))
	plus.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	plus.set_meta("contextual_enabled", true)
	var menu := plus.get_popup()
	var cibles: Array = [{"kind": "detail", "ouvert": true}]
	menu.add_item("Statistiques, notes et journal", 0)
	var competition := str(_fixture().get("competitionId", ""))
	if not _classement().is_empty() and not competition.is_empty():
		menu.add_item("Classements de la compétition", cibles.size())
		cibles.append({"kind": "competition", "id": competition})
	var date := str(_fixture().get("date", ""))
	if not date.is_empty():
		menu.add_item("Calendrier du jour", cibles.size())
		cibles.append({"kind": "date", "id": date})
	plus.set_meta("cibles", cibles)
	menu.id_pressed.connect(func(id: int): if id >= 0 and id < cibles.size(): ouvrir(cibles[id]))
	return plus

## Score : un seul panneau (PANNEAU 90 %, rayon 18) qui porte les deux clubs (écusson et nom, lien vers sa fiche) et le
## score crème 48 px. Pas de fond à la couleur des clubs : elle reste sur leur écusson.
func _ligne_score() -> PanelContainer:
	var cadre := PanelContainer.new()
	cadre.name = "ApresMatchScoreCadre"
	cadre.add_theme_stylebox_override("panel", _fond(Color(Charte.PANNEAU, 0.9), 16, 0, -1, -1, Charte.RAYON_PANNEAU))
	cadre.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var ligne := _h(0)
	ligne.name = "ApresMatchScore"
	cadre.add_child(ligne)
	var equipes: Array = _live().get("teams", [])
	var score: Array = _live().get("score", [0, 0])
	for cote in 2:
		var club: Dictionary = equipes[cote] if cote < equipes.size() and equipes[cote] is Dictionary else {}
		if cote == 1:
			var chiffre := PanelContainer.new()
			chiffre.add_theme_stylebox_override("panel", _fond(Color(0, 0, 0, 0), 20, 0))
			var texte := _texte("%d – %d" % [int(score[0]) if score.size() > 0 else 0, int(score[1]) if score.size() > 1 else 0], 48, Charte.IVOIRE, Charte.TITRE_EXTRA)
			texte.name = "ApresMatchScoreChiffres"
			chiffre.add_child(texte)
			ligne.add_child(chiffre)
		ligne.add_child(_plaque(club, cote))
	return cadre

## Plaque d'un club dans le panneau du score : son écusson et son nom (lien vers sa fiche), sans fond.
func _plaque(club: Dictionary, cote: int) -> PanelContainer:
	var p := PanelContainer.new()
	p.name = "ApresMatchPlaque%d" % cote
	p.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	p.custom_minimum_size.y = _d(52)
	var marge := MarginContainer.new()
	marge.add_theme_constant_override("margin_left", _d(0 if cote == 0 else 4))
	marge.add_theme_constant_override("margin_right", _d(4 if cote == 0 else 0))
	p.add_child(marge)
	var rang := _h(10)
	marge.add_child(rang)
	var sigle := _sigle(club, 48, 34, 19)
	var nom: Control
	if club.get("id") != null: nom = _lien(G.club_name(club).to_upper(), {"kind": "club", "id": _cle_id(club.get("id"))}, 26)
	else: nom = _texte(G.club_name(club).to_upper(), 26)
	nom.add_theme_font_override("font", Charte.TITRE_GRAS)
	nom.name = "ApresMatchClub%d" % cote
	if cote == 0:
		rang.add_child(sigle)
		rang.add_child(nom)
	else:
		rang.add_child(nom)
		rang.add_child(sigle)
	return p

## Lignes d'information sous le score : classement avant → après, homme du match, essais, bonus de la journée.
func _meta() -> Array[HBoxContainer]:
	var lignes: Array[HBoxContainer] = []
	var une := _h(22)
	var deux := _h(22)
	var nous := {}
	for r: Variant in _classement():
		if r is Dictionary and bool(r.get("nous", false)): nous = r
	if not nous.is_empty():
		var bloc := _h(5)
		bloc.name = "ApresMatchRang"
		bloc.add_child(_texte("Classement", 15, Charte.IVOIRE_2))
		var avant: Variant = nous.get("rangOfficiel")
		var rang := int(nous.get("rang", 0))
		var valeur := (ordinal(int(avant)) + " → " if avant is float or avant is int else "") + ordinal(rang)
		var competition := str(_fixture().get("competitionId", ""))
		if competition.is_empty(): bloc.add_child(_texte(valeur, 15, Charte.IVOIRE, texte_gras()))
		else:
			var lien_rang := _lien(valeur, {"kind": "competition", "id": competition}, 15)
			lien_rang.name = "ApresMatchRangLien"
			lien_rang.add_theme_font_override("font", texte_gras())
			_aide(lien_rang, "Classements de la compétition")
			bloc.add_child(lien_rang)
		var delta := int(nous.get("delta", 0))
		if avant is float or avant is int:
			if delta != 0: bloc.add_child(_triangle(delta > 0, Charte.V if delta > 0 else Charte.D))
			bloc.add_child(_texte(("%s place%s" % [signe(delta), "s" if absi(delta) > 1 else ""]) if delta != 0 else "même place", 15, Charte.IVOIRE_2))
		une.add_child(bloc)
	var homme: Variant = _direct().get("hommeDuMatch")
	if homme is Dictionary and not str(homme.get("nom", "")).is_empty():
		var bloc := _h(5)
		bloc.name = "ApresMatchHomme"
		bloc.add_child(_texte("Homme du match", 15, Charte.IVOIRE_2))
		bloc.add_child(_lien_joueur(str(homme.get("joueur", "")), str(homme.get("nom", "")), int(homme.get("camp", -1)), 15, texte_gras()))
		var note := note_texte(homme.get("note"))
		if not note.is_empty(): bloc.add_child(_texte("(%s)" % note, 15, Charte.IVOIRE_2))
		(une if nous.is_empty() else deux).add_child(bloc)
	var essais: Variant = _live().get("tries")
	if essais is Array and essais.size() == 2:
		var bloc := _h(5)
		bloc.add_child(_texte("Essais", 15, Charte.IVOIRE_2))
		bloc.add_child(_texte("%d – %d" % [int(essais[0]), int(essais[1])], 15, Charte.IVOIRE, texte_gras()))
		deux.add_child(bloc)
	var equipes: Array = _live().get("teams", [])
	for r: Variant in _classement():
		if not r is Dictionary: continue
		var dans := false
		for e: Variant in equipes:
			if e is Dictionary and _cle_id(e.get("id")) == _cle_id(r.get("clubId")): dans = true
		if not dans: continue
		var nom := G.club_name(_club(r.get("clubId"))) if not _club(r.get("clubId")).is_empty() else str(r.get("nom", ""))
		for bonus: Array in [["bonusOff", "Point de bonus offensif"], ["bonusDef", "Point de bonus défensif"]]:
			if int(r.get(bonus[0], 0)) > 0: deux.add_child(_texte("%s pour %s" % [bonus[1], nom], 15, Charte.IVOIRE_2))
	for ligne in [une, deux]:
		if ligne.get_child_count() > 0: lignes.append(ligne)
	return lignes

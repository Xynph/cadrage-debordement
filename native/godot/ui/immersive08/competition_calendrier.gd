extends "res://ui/immersive08/competition_classement.gd"
## Compétitions, parties Calendrier, Phases finales et Statistiques : filtres, lignes de rencontres, tableau des phases, statistiques.
## Hérite du classement (competition_classement.gd) ; l'écran se lit par competition_canvas.gd.

func _filtre(parent: Node, area: Rect2, caption: String, selected: bool, callback: Callable, id: String) -> Button:
	var button := _lien(parent, area, caption, callback, id, 21, selected)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(key, Charte.IVOIRE if selected else Charte.IVOIRE_2)
	button.add_theme_color_override("font_hover_color", Charte.IVOIRE)
	button.set_meta("selected", selected)
	return button

func _calendar() -> void:
	var panel := _panel(self, Rect2(0, TOP, LEFT, 760), "TOUTE LA SAISON · CALENDRIER DU CLUB", "", "CalendarScroll")
	left_bottom = TOP + 760
	var selected := str(state.get("calendar_filter", "all"))
	# Bandeau des filtres (demande de Léo du 21/11/2026) : pastilles de filtre et en-têtes dans un bandeau détouré.
	Bandeau.poser(panel, Rect2(8, 54, LEFT - 16, 90), 36.0)
	var x := 24
	for spec: Array in [[170, "Tous les matchs", "all"], [120, "À jouer", "upcoming"], [120, "Résultats", "played"]]:
		_filtre(panel, Rect2(x, 62, spec[0], 40), spec[1], selected == spec[2], func():
			state.calendar_filter = spec[2]
			_page_state("CalendarPagination").page = 0
			app._render(false), "CalendarFilter_" + str(spec[2]))
		x += int(spec[0]) + 12
	_selections_du_club(panel, x + 20.0)
	var visible := fixtures.filter(func(fixture: Dictionary): return selected == "all" or bool(fixture.get("played", false)) == (selected == "played"))
	D.text(panel, LEFT - 24, 88, P.plural(visible.size(), "rencontre", "rencontres"), 20, C.MUTED, 500, 240, HORIZONTAL_ALIGNMENT_RIGHT)
	var period := "DATE / PHASE" if international else "JOURNÉE / PHASE"
	for spec: Array in [[19, period, 230], [296, "ADVERSAIRE", 430], [650, "LIEU", 290], [954, "COMPÉTITION", 185], [LEFT - 157, "RÉSULTAT", 140]]:
		D.text(panel, spec[0], 134, spec[1], 15, C.MUTED, 700, spec[2])
	D.line(panel, Vector2(9, 142), Vector2(LEFT - 9, 142), Charte.FILET)
	# Toute la saison sur une page qui défile (décision de Léo) : plus de pagination.
	var panel_h := 210 + 48 * maxi(1, visible.size()) + 40
	panel.size.y = C.px(panel_h)
	left_bottom = TOP + panel_h
	for i in visible.size():
		_calendar_row(panel, visible[i], 148 + 48 * i, LEFT, false)
	if visible.is_empty(): D.text(panel, 23, 219, "Aucune rencontre", 24, C.MUTED, 500, LEFT - 47, HORIZONTAL_ALIGNMENT_LEFT, true)
	_result_legend(panel, 24, panel_h - 48)

## Joueurs du club retenus en sélection, dans le bandeau des filtres : chiffre, date de retour et lien, tous menant
## aux disponibilités internationales (Sélections). Rendu au Calendrier après le retrait de l'ancienne grille du mois (#1177).
func _selections_du_club(panel: Control, x: float) -> void:
	var dispo := preload("res://ui/international_availability.gd")
	var etat: Dictionary = dispo.data(app.model)
	var absents := int(etat.get("absentCount", 0))
	if not bool(etat.get("clubManaged", false)) and absents <= 0: return
	var ouvrir := func(): dispo.open(app)
	x += Pieces.pastille(panel, x, 65, "%d en sélection" % absents if absents > 0 else "0 absent", "flag" if absents > 0 else "check",
		"InternationalAvailabilityChip", "", Charte.PERTE if absents > 0 else Charte.GAIN, Charte.PANNEAU_3, ouvrir) + 10
	var tuile := panel.find_child("InternationalAvailabilityChipLien", true, false)
	if tuile != null: tuile.name = "InternationalAvailabilityTile"
	if absents > 0:
		var retour := dispo._date(etat.get("nextReturn"))
		x += Pieces.pastille(panel, x, 65, "Retour " + retour, "hourglass", "InternationalAvailabilityReturn", "Convocations confirmées · retour prévu à partir du " + retour,
			Charte.REPOS, Charte.PANNEAU_3, ouvrir) + 10
		var detail := panel.find_child("InternationalAvailabilityReturnLien", true, false)
		if detail != null: detail.name = "InternationalAvailabilityDetail"
	_lien(panel, Rect2(x, 62, 300, 40), "Préparer les absences →" if absents > 0 else "Fenêtres internationales →", ouvrir, "InternationalAvailabilityOpen", 20)

## Date courte « 21/11 » d'une rencontre (vide sans date ISO).
func _short_date(fixture: Dictionary) -> String:
	var raw := str(fixture.get("date", ""))
	if raw.length() >= 10 and raw[4] == "-" and raw[7] == "-": return "%s/%s" % [raw.substr(8, 2), raw.substr(5, 2)]
	return ""

## Code court de la journée ou de la phase (« J9 », « DF », « F »).
func _round_code(fixture: Dictionary) -> String:
	var phase := str(fixture.get("phase", "league"))
	if phase in ["league", "pool"]:
		var label := _fixture_label(fixture)
		if label.begins_with("Journée "): return "J" + label.trim_prefix("Journée ")
		var round_value: Variant = fixture.get("competitionRound")
		if round_value is int or round_value is float: return "J%d" % (int(round_value) + 1)
		return "J" + str(int(fixture.get("week", 0)) + 1)
	return {"semi": "DF", "final": "F", "quarter": "QF", "r16": "8e", "barrage": "Bar.", "elimination": "Bar.", "access": "Acc.", "cup": "Cpe", "third-place": "3e"}.get(phase, _phase(fixture).left(4))

func _calendar_row(parent: Node, fixture: Dictionary, y: float, width: float, compact: bool) -> void:
	var home: Dictionary = fixture.get("home", {})
	var away: Dictionary = fixture.get("away", {})
	var is_home: bool = home.get("id") == own.id
	var opponent := away if is_home else home
	var played: bool = fixture.get("played", false)
	var current := _is_next(fixture)
	var line_height := 34 if compact else 48
	var date := _date(fixture)
	var venue := _venue_name(fixture)
	var competition := _competition_name(fixture)
	var period := _fixture_label(fixture) if date.is_empty() else date
	var row := Button.new()
	row.name = "CalendarFixture_" + str(fixture.get("id", y))
	row.set_meta("fixture_id", str(fixture.get("id", "")))
	row.set_meta("immersive_style_applied", true)
	var competition_id := _competition_id(fixture)
	var dated_competition := competition_id in JAPAN_COMPETITIONS or competition_id in ["nationale","access-nationale","champ"]
	var timing := P.fixture_date(fixture, true) + " · " + _dated_phase(fixture) if not date.is_empty() and dated_competition else period
	row.accessibility_name = "%s · %s · %s · %s" % [timing,G.club_name(opponent),_location(fixture),competition]
	if not venue.is_empty() and venue != _location(fixture):
		row.accessibility_name += " · " + venue
	row.tooltip_text = row.accessibility_name
	var normal := StyleBoxFlat.new()
	normal.bg_color = Charte.PANNEAU_3 if current else Charte.PANNEAU
	normal.set_corner_radius_all(Charte.RAYON_PETIT)
	if current:
		normal.border_color = Charte.IVOIRE
		normal.border_width_left = maxi(3, C.px(4))
	load("res://ui/survol_ligne.gd").appliquer(row, false, normal.bg_color, app.accent)
	if current: row.add_theme_stylebox_override("normal", normal)
	if target_available(app, "fixture", fixture.get("id", "")):
		Link.bind(row, app, {"kind":"fixture", "id":str(fixture.get("id", ""))}, "Ouvrir la rencontre · " + row.accessibility_name)
	else:
		row.focus_mode = Control.FOCUS_NONE
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)
	D.place(row, Rect2(2, y, width - 4, line_height))
	D.line(row, Vector2(9, line_height - 1), Vector2(width - 15, line_height - 1), Color(C.LINE, .75))
	var middle := line_height / 2.0 + 7
	var fid := str(fixture.get("id", y)).validate_node_name()
	if compact:
		D.text(row, 12, middle, _round_code(fixture), 19, C.MUTED, 700, 66)
		var short_label := D.text(row, 72, middle, _short_date(fixture) if not _short_date(fixture).is_empty() else _fixture_label(fixture), 19, C.IVORY, 600, 0)
		if not date.is_empty(): D.line(row, Vector2(72, middle + 4), Vector2(72 + short_label.size.x / C.density, middle + 4), Charte.IVOIRE_3)
		_crest(row, opponent, Rect2(170, (line_height - 26) / 2.0, 26, 26))
		D.text(row, 204, middle, G.club_name(opponent), 20, C.IVORY, 700, 236)
		D.text(row, 444, middle, _location(fixture, true), 19, C.MUTED, 500, 96)
		var theirs := 0
		for club: Dictionary in _own_league_rows():
			if club.id == opponent.get("id") and P.standings_open(club): theirs = int(club.get("rank", 0))
		if theirs > 0: D.text(row, 546, middle, _ordinal(theirs), 19, C.MUTED, 500, 46)
		var code := _fixture_outcome(fixture)
		var score := _score(fixture, own.id)
		if played: _result_badge(row, Rect2(width - 124, (line_height - 28) / 2.0, 108, 28), code, code + " " + score if code != "—" else score)
		else:
			var tag := D.text(row, width - 16, middle, "À jouer →" if current else "—", 19, C.IVORY if current else C.MUTED, 700, 110, HORIZONTAL_ALIGNMENT_RIGHT)
			tag.name = "CalendarToPlay_" + fid
			if current:
				# La flèche promet l'action : « À jouer → » ouvre la Préparation (ou le direct).
				var go := Button.new()
				go.name = "CalendarPrepare_" + fid
				go.flat = true
				go.set_meta("immersive_style_applied", true)
				go.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
				go.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
				go.tooltip_text = "Préparer le match"
				go.pressed.connect(func(): app._navigate("Match" if not app._live().is_empty() else "Préparation"))
				row.add_child(go)
				D.place(go, Rect2(width - 140, 0, 136, line_height))
		_entity_area(row, Rect2(166, 0, 278, line_height), {"kind":"club", "id":str(opponent.get("id", ""))}, "CalendarOpponent_" + fid, "Ouvrir le club · " + G.club_name(opponent))
		if not date.is_empty():
			_entity_area(row, Rect2(8, 0, 156, line_height), {"kind":"date", "id":str(fixture.get("date", ""))}, "CalendarDate_" + fid, "Voir la date dans le calendrier · " + date)
		return
	if date.is_empty():
		D.text(row, 16, middle, period, 23, C.IVORY, 500, 232)
	else:
		var date_label := D.text(row, 16, middle - 7, date, 21, C.IVORY, 600, 232)
		date_label.name = "CalendarFixtureDate"
		D.text(row, 16, middle + 11, _dated_phase(fixture), 16, C.MUTED, 500, 232)
	var emblem_x := 250
	_crest(row, opponent, Rect2(emblem_x, (line_height - 34) / 2.0, 34, 34))
	D.text(row, emblem_x + 45, middle, G.club_name(opponent), 24, C.IVORY, 600, 340)
	_entity_area(row, Rect2(emblem_x, 0, 445, line_height), {"kind":"club", "id":str(opponent.get("id", ""))}, "CalendarOpponent_" + fid, "Ouvrir le club · " + G.club_name(opponent))
	if not date.is_empty():
		_entity_area(row, Rect2(12, 0, 232, line_height), {"kind":"date", "id":str(fixture.get("date", ""))}, "CalendarDate_" + fid, "Voir la date dans le calendrier · " + date)
	var place_x := 650
	var location_kind := _location_kind(fixture)
	_icon(row, C.fixture_location_icon(location_kind), Rect2(place_x, (line_height - 18) / 2.0, 18, 18), C.MUTED)
	var venue_parts := venue.split(" · ",false,1)
	if venue_parts.size() == 2:
		D.text(row,place_x+25,middle-7,venue_parts[0],_taille_dans(venue_parts[0], 262.0, 21, 600),C.IVORY,600,262)
		D.text(row,place_x+25,middle+11,venue_parts[1],_taille_dans(venue_parts[1], 262.0, 16, 500),C.MUTED,500,262)
	else:
		var lieu := venue if not venue.is_empty() else _location(fixture)
		D.text(row,place_x+25,middle,lieu,_taille_dans(lieu, 262.0, 21, 500),C.IVORY,500,262)
	D.text(row,954,middle,World.short_name(_competition_id(fixture),competition,app.model),21,C.MUTED,500,185)
	_entity_area(row, Rect2(954,0,185,line_height), {"kind":"competition", "id":competition_id}, "CalendarCompetition_" + fid, "Voir le classement · " + competition)
	var result_x := width - 157
	var code := _fixture_outcome(fixture)
	var score := _score(fixture, own.id)
	if played:
		_result_badge(row, Rect2(result_x, (line_height - 32) / 2.0, width - result_x - 14, 32), code, code + " " + score if code != "—" else score)
	else:
		_box_tag(row, Rect2(result_x, (line_height - 32) / 2.0, width - result_x - 14, 32), "À jouer", Charte.IVOIRE if current else Charte.IVOIRE_2)

## Plus grande police (jusqu'à `depart`, au moins 15) qui fait tenir `texte` dans `largeur` : on réduit avant de couper par « … ».
func _taille_dans(texte: String, largeur: float, depart: int, poids: int) -> int:
	var taille := depart
	while taille > 15 and Reperes.largeur(texte, taille, poids) > largeur: taille -= 1
	return taille

func _playoffs() -> void:
	var panel := _panel(self, Rect2(0, TOP, LEFT, 760), "PHASES FINALES – " + _league_short(league).to_upper(), "trophy", "CompetitionPlayoffsPanel")
	_division_menu(panel, 24, 66, 540)
	var japanese: bool = league.id in ["jlo-d1", "jlo-d2"]
	var phases: Array = season_results.filter(func(result: Dictionary):
		var competition := _competition_id(result, league.id)
		return _knockout(result) and (competition == league.id
			or (japanese and competition == "jlo-d1-d2")
			or (result.get("phase") == "access" and competition != "access-nationale" and league.id in ["elite", "accession"])
			or (competition == "access-nationale" and league.id in ["nationale", "accession"])))
	var panel_h := 270 + 54 * maxi(1, phases.size())
	panel.size.y = C.px(panel_h)
	left_bottom = TOP + panel_h
	if league.get("champion") is Dictionary:
		_icon(panel, "trophy", Rect2(22, 121, 51, 51), WARM)
		D.text(panel, 89, 156, "CHAMPION · " + G.club_name(league.champion).to_upper(), 36, WARM, 800, 1180)
		if league.get("finalist") is Dictionary:
			D.text(panel, 89, 188, "Finaliste · " + G.club_name(league.finalist), 25, C.IVORY, 500, 1160, HORIZONTAL_ALIGNMENT_LEFT, true)
	else:
		D.text(panel, 21, 154, "Les affiches se précisent au fil de la saison.", 30, C.IVORY, 700, 1250)
		# Les phases citées sont celles que le moteur a déjà publiées pour cette compétition (jamais de règlement figé).
		var stages: Array[String] = []
		for result: Dictionary in phases:
			var stage_name := _phase(result).get_slice(" · ", 0)
			if stage_name not in stages: stages.append(stage_name)
		if not stages.is_empty(): D.text(panel, 22, 185, " · ".join(stages), 23, C.MUTED, 500, 1250, HORIZONTAL_ALIGNMENT_LEFT, true)
	if phases.is_empty(): D.text(panel, 23, 244, "Aucun résultat de phase finale conservé cette saison.", 27, C.MUTED, 500, 1230, HORIZONTAL_ALIGNMENT_LEFT, true)
	for i in phases.size():
		var result: Dictionary = phases[i]
		var card := _bande(panel, Rect2(16, 218 + i * 54, LEFT - 32, 47))
		var competition := _competition_id(result)
		var nationale := competition in ["nationale", "access-nationale"]
		var stage_width := 304 if japanese or competition == "access-nationale" else 210
		var stage := Club.competition_name(competition, app.model) if competition == "access-nationale" else _phase(result)
		var show_details := nationale or competition in ["champ", "champions", "challenge"]
		var timing := _date(result) if show_details else ""
		if show_details and result.get("neutral", false):
			timing = timing + " · Neutre" if not timing.is_empty() else "Terrain neutre"
		D.text(card, 14, 31 if timing.is_empty() else 22, stage, 24, WARM, 600, stage_width)
		if not timing.is_empty(): D.text(card, 14, 41, timing, 18, C.MUTED, 600, stage_width)
		var matchup := _matchup(result)
		var score: Variant = result.get("score")
		var winner: Variant = result.get("winner")
		var tiebreak: bool = show_details and score is Array and score.size() == 2 and score[0] == score[1] and identities.has(winner)
		D.text(card, stage_width + 18, 22 if tiebreak else 31, G.club_name(matchup[0]) + "  –  " + G.club_name(matchup[1]), 25, C.IVORY, 600, 1054 - stage_width)
		if tiebreak:
			D.text(card, stage_width + 18, 41, "%s après départage" % G.club_name(identities[winner]), 18, C.MUTED, 600, 1054 - stage_width)
		D.text(card, LEFT - 57, 31, _score(result), 27, C.IVORY, 700, 142, HORIZONTAL_ALIGNMENT_RIGHT)
		_entity_area(card, Rect2(0, 0, LEFT - 32, 47), {"kind":"fixture", "id":str(result.get("fixtureId", ""))}, "PlayoffFixture_%d" % i, "Ouvrir la rencontre")

func _stats() -> void:
	var panel := _panel(self, Rect2(0, TOP, LEFT, 760), "STATISTIQUES – " + _league_short(league).to_upper(), "flag", "CompetitionStatsPanel")
	_division_menu(panel, 24, 66, 540)
	var rows: Array = league.get("rows", [])
	var own_row: Dictionary = {}
	for row: Dictionary in rows:
		if row.get("id") == own.id:
			own_row = row
			break
	var summary := _section(panel, Rect2(16, 124, LEFT - 32, 269), "NOTRE CLUB · BILAN DES POULES" if league.has("pools") else "NOTRE CLUB · BILAN DU CHAMPIONNAT", "shield", "StandingsContext")
	_crest(summary, own, Rect2(18, 67, 93, 93))
	var club_label := D.text(summary, 132, 104, G.club_name(own), 37, C.IVORY, 800, 1100)
	club_label.name = "StandingsContextClubName"
	D.text(summary, 135, 142, ("Rang " + S.count_text(own_row.get("rank")) if P.standings_open(own_row) else "Pas encore de classement") + "  ·  " + S.number_text(own_row.get("points")) + " pts  ·  " + S.count_text(own_row.get("played")) + " matchs", 26, C.MUTED, 500, 1080)
	for i in 3:
		var code: String = ["V", "N", "D"][i]
		var quantity := S.count_text(own_row.get(["won", "drawn", "lost"][i]))
		_result_badge(summary, Rect2(135 + 166 * i, 161, 148, 43), code, quantity + " " + str(S.RESULTS[code].plural).to_lower(), quantity != "—")
	_recent_form(summary, own_row.get("form"), 132, 219)
	var rows_played := rows.filter(func(row: Dictionary): return float(row.get("played", 0)) > 0)
	var aggregate := _section(panel, Rect2(16, 411, LEFT - 32, 294), "CHIFFRES DE LA PHASE DE POULES" if league.has("pools") else "CHIFFRES DE LA PHASE RÉGULIÈRE", "trophy", "CompetitionLeagueStats")
	var games := 0
	var points := 0
	var draw_count := 0
	for club: Dictionary in rows_played:
		games += int(club.get("played", 0))
		points += int(club.get("pf", 0))
		draw_count += int(club.get("drawn", 0))
	var game_count := games / 2.0
	var values: Array = [G.n(game_count), G.n(points), G.n(draw_count / 2.0), "%.1f" % (points / game_count) if game_count > 0 else "—"]
	for i in 4:
		var x := 26 + i * 309
		_tuile(aggregate, Rect2(x, 70, 288, 127))
		D.text(aggregate, x + 22, 112, ["Matchs joués", "Points marqués", "Matchs nuls", "Points / match"][i], 26, C.MUTED, 500, 254)
		D.text(aggregate, x + 22, 170, values[i], 61, C.IVORY, 800, 253)

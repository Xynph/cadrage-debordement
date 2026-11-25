extends "res://ui/immersive08/competition_calendrier.gd"
## Compétitions, colonne de droite (ta place, prochain rendez-vous, calendrier du club) et bande du bas (derniers résultats, meilleures lignes).
## Hérite du calendrier (competition_calendrier.gd) ; l'écran se lit par competition_canvas.gd.

func _colonne_droite() -> void:
	var y := float(TOP)
	y = _ta_place(y) + GAP
	y = _prochain(y) + GAP
	y = _calendrier_club(y)
	right_bottom = y

## Ta place : rang, points, zone, et les trois écarts (sur le premier, sur le club devant, sur le club derrière).
func _ta_place(y: float) -> float:
	var card := _carte(self, Rect2(LEFT + GAP, y, RIGHT, 300), "TA PLACE", "CompetitionPlace")
	var row := _own_row()
	if row.is_empty() or not P.standings_open(row):
		D.text(card, 24, 100, "Pas encore de classement.", 24, C.MUTED, 600, RIGHT - 48)
		return y + 300
	var rank := int(row.get("rank", 0))
	var rank_label := D.text(card, 24, 116, _ordinal(rank), 68, C.IVORY, 800, 0)
	rank_label.add_theme_font_override("font", Charte.TITRE_EXTRA)
	rank_label.name = "CompetitionPlaceRank"
	var rank_w := rank_label.size.x / C.density
	var points := D.text(card, 24 + rank_w + 18, 114, "%s pts" % S.number_text(row.get("points")), 44, C.IVORY, 800, 0)
	points.add_theme_font_override("font", Charte.TITRE_GRAS)
	D.text(card, 24, 148, "%s V  ·  %s N  ·  %s D  ·  diff. %s" % [S.count_text(row.get("won")), S.count_text(row.get("drawn")), S.count_text(row.get("lost")), _standing_text(row, "difference")], 19, C.MUTED, 500, RIGHT - 48)
	var zone: Dictionary = Zones.of(row)
	if not zone.is_empty():
		var kind := str(zone.get("kind", ""))
		D.rect(card, Rect2(24, 162, 4, 26), Zones.tint(kind)).name = "CompetitionPlaceZoneEdge"
		var side := Zones.mark_side()
		Zones.mark(card, kind, Rect2(40, 175 - side / 2.0, side, side), Zones.tint(kind))
		var zone_text := D.text(card, 64, 182, "Dans la zone : " + str(zone.get("label", "")), 20, C.IVORY, 600, RIGHT - 88)
		zone_text.name = "CompetitionPlaceZone"
	# Les trois écarts : premier, club juste devant, club juste derrière.
	var ranked: Array = _own_league_rows().filter(func(club: Dictionary): return P.standings_open(club))
	ranked.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.get("rank", 0)) < int(b.get("rank", 0)))
	var gaps: Array = []
	var seen := {}
	var picks: Array = []
	if not ranked.is_empty(): picks.append(ranked[0])
	for club: Dictionary in ranked:
		if int(club.get("rank", 0)) == rank - 1: picks.append(club)
		if int(club.get("rank", 0)) == rank + 1: picks.append(club)
	for club: Dictionary in picks:
		if club.id == own.id or seen.has(club.id): continue
		seen[club.id] = true
		gaps.append(club)
	var tile_w := (RIGHT - 48 - 2 * 12) / 3.0
	for i in mini(gaps.size(), 3):
		var club: Dictionary = gaps[i]
		var delta := int(float(row.get("points", 0)) - float(club.get("points", 0)))
		var tile_x := 24 + i * (tile_w + 12)
		var tile := D.rect(card, Rect2(tile_x, 206, tile_w, 84), Charte.PANNEAU_2, Charte.RAYON_CARTE)
		tile.name = "CompetitionGap_%d" % i
		var signed := "+%d" % delta if delta > 0 else str(delta)
		var value := D.text(tile, 14, 40, signed, 40, C.IVORY, 800, tile_w - 20)
		value.add_theme_font_override("font", Charte.TITRE_GRAS)
		D.text(tile, 14, 58, "sur le %s" % _ordinal(int(club.get("rank", 0))), 16, C.MUTED, 600, tile_w - 20)
		D.fit_title(D.text(tile, 14, 78, G.club_name(club), 16, C.MUTED, 500, tile_w - 20), tile_w - 20, 30, 2, 13)
		D.text(tile, tile_w - 14, 40, "→", 24, C.MUTED, 700, 30, HORIZONTAL_ALIGNMENT_RIGHT)
		var link := _entity_area(tile, Rect2(0, 0, tile_w, 84), {"kind":"club", "id":str(club.id)}, "CompetitionGapLink_%d" % i, "Ouvrir le club · " + G.club_name(club))
		if link != null:
			link.tooltip_text = "Ouvrir le club · " + G.club_name(club)
			load("res://ui/retour_tuile.gd").brancher(link, tile, C.px(Charte.RAYON_CARTE))
	return y + 300

## Libellés du rendez-vous quand aucune rencontre du championnat n'est à venir (exempt, préparation, saison terminée).
func _rendez_vous_sans_match() -> Dictionary:
	var upcoming := P.next_nationale_fixture(app.model)
	if not upcoming.is_empty():
		return {"chip": "SEMAINE EXEMPTE", "title": Office.scheduled_opponent(app, upcoming), "when": Office.scheduled_when(app, upcoming), "venue": Office.scheduled_venue(app, upcoming), "button": app.primary_text().trim_suffix("  →"), "action": app.primary_action, "id": "CompetitionAdvanceWeek", "title_name": "UpcomingOpponent"}
	var japan := SeasonPreparation.is_japan(app.model.meta)
	var preparation := SeasonPreparation.data(app.model.meta)
	if not preparation.is_empty():
		if SeasonPreparation.is_champ(app.model.meta):
			var fixture := P.next_scheduled_fixture(app.model)
			if fixture.is_empty():
				return {"chip": "", "title": "Préparation · " + World.name_for(app.model, "champ"), "when": World.preparation_note(preparation), "venue": "", "button": app.primary_text().trim_suffix("  →"), "action": app.primary_action, "id": "CompetitionChampAdvance", "title_name": "UpcomingOpponent"}
			return {"chip": "PRÉPARATION", "title": Office.scheduled_opponent(app, fixture), "when": Office.scheduled_when(app, fixture), "venue": Office.scheduled_venue(app, fixture), "button": app.primary_text().trim_suffix("  →"), "action": app.primary_action, "id": "CompetitionChampAdvance", "title_name": "UpcomingOpponent"}
		return {"chip": "", "title": "Préparation · " + World.name_for(app.model, str(app.model.meta.get("leagueId", "srp"))), "when": World.preparation_note(preparation), "venue": "", "button": "Ouvrir le dossier de préparation", "action": func(): app.Immersive.open_preparation(app, 0), "id": "CompetitionJapanLink" if japan else "CompetitionPacificLink", "title_name": "UpcomingOpponent"}
	var scheduled := P.next_fixture(app.model)
	if not scheduled.is_empty():
		return {"chip": "PROCHAINE RENCONTRE", "title": Office.scheduled_opponent(app, scheduled), "when": Office.scheduled_when(app, scheduled), "venue": Office.scheduled_venue(app, scheduled), "button": app.primary_text().trim_suffix("  →"), "action": app.primary_action, "id": "CompetitionScheduledAdvance", "title_name": "UpcomingOpponent"}
	return {"chip": "", "title": "Aucune rencontre programmée", "when": str(app.model.meta.get("roundLabel", "")), "venue": "", "button": "Voir le calendrier du club", "action": func(): _switch("calendar"), "id": "CompetitionCalendarLink", "title_name": ""}

func _prochain(y: float) -> float:
	var card := _carte(self, Rect2(LEFT + GAP, y, RIGHT, 330 if next_fixture.is_empty() else 430), "PROCHAIN RENDEZ-VOUS", "CompetitionNextFixture")
	if next_fixture.is_empty():
		var info := _rendez_vous_sans_match()
		if not str(info.chip).is_empty(): D.text(card, 24, 92, str(info.chip), 17, C.MUTED, 700, RIGHT - 48)
		var title := D.text(card, 24, 140, str(info.title), 36, C.IVORY, 800, RIGHT - 48)
		title.add_theme_font_override("font", Charte.TITRE_GRAS)
		if not str(info.title_name).is_empty(): title.name = str(info.title_name)
		var moment := D.text(card, 24, 184, str(info["when"]), 24, C.IVORY, 600, RIGHT - 48)
		if info.title_name == "UpcomingOpponent": moment.name = "UpcomingWhen"
		if not str(info.venue).is_empty(): D.text(card, 24, 222, "Lieu · " + str(info.venue), 20, C.MUTED, 500, RIGHT - 48, HORIZONTAL_ALIGNMENT_LEFT, true)
		_principal(card, Rect2(24, 262, RIGHT - 48, 52), str(info.button).to_upper() + "  →", info.action, str(info.id))
		return y + 330
	var home: Dictionary = next_fixture.get("home", {})
	var away: Dictionary = next_fixture.get("away", {})
	var caption := str(next_fixture.get("label", _phase(next_fixture)))
	var date := _date(next_fixture)
	D.text(card, 24, 86, caption.to_upper(), 17, C.MUTED, 700, RIGHT - 48)
	if date.is_empty():
		D.text(card, 24, 116, _location(next_fixture), 26, C.IVORY, 700, RIGHT - 48)
	else:
		var date_label := D.text(card, 24, 118, date, 27, C.IVORY, 700, RIGHT - 48)
		date_label.name = "CompetitionNextDate"
		D.line(card, Vector2(24, 124), Vector2(24 + date_label.get_theme_font("font").get_string_size(date, HORIZONTAL_ALIGNMENT_LEFT, -1, date_label.get_theme_font_size("font_size")).x / C.density, 124), Charte.IVOIRE_3)
		var date_link := _entity_area(card, Rect2(20, 92, RIGHT - 40, 34), {"kind":"date", "id":str(next_fixture.get("date", ""))}, "CompetitionNextDateLink", "Voir la date dans le calendrier · " + date)
		if date_link != null: date_link.size.y = maxf(C.px(34), maxf(date_link.size.y, ceilf(date_label.size.y)))
	var home_plate := _plaque(card, Rect2(24, 138, 290, 64), home, "CompetitionNextHome", false)
	D.text(card, 362, 176, "CONTRE", 18, C.MUTED, 700, 100, HORIZONTAL_ALIGNMENT_CENTER)
	var away_plate := _plaque(card, Rect2(410, 138, 290, 64), away, "CompetitionNextAway", true)
	home_plate.tooltip_text = home_plate.tooltip_text if not home_plate.tooltip_text.is_empty() else G.club_name(home)
	away_plate.tooltip_text = away_plate.tooltip_text if not away_plate.tooltip_text.is_empty() else G.club_name(away)
	var location := D.text(card, 24, 234, _location(next_fixture), 21, C.IVORY, 700, 0)
	var venue := _venue_name(next_fixture)
	if not venue.is_empty():
		var venue_label := D.text(card, 24 + location.size.x / C.density + 16, 234, venue, 21, C.MUTED, 500, RIGHT - 80 - location.size.x / C.density)
		venue_label.name = "CompetitionNextVenue"
	var opponent := away if home.get("id") == own.get("id") else home
	var mine := _own_row()
	var theirs: Dictionary = {}
	for club: Dictionary in _own_league_rows():
		if club.id == opponent.get("id"): theirs = club
	if not mine.is_empty() and not theirs.is_empty() and P.standings_open(mine) and P.standings_open(theirs):
		var gap := absi(int(float(mine.get("points", 0)) - float(theirs.get("points", 0))))
		D.text(card, 24, 268, "%s contre %s  ·  %d pt%s d’écart" % [_ordinal(int(mine.get("rank", 0))), _ordinal(int(theirs.get("rank", 0))), gap, "s" if gap > 1 else ""], 20, C.IVORY, 500, RIGHT - 48)
	if not mine.is_empty() and not theirs.is_empty():
		D.text(card, 24, 304, "FORME", 15, C.MUTED, 700, 70)
		_recent_form(card, mine.get("form"), 90, 284)
		D.text(card, 276, 304, "nous", 17, C.MUTED, 500, 50)
		_recent_form(card, theirs.get("form"), 340, 284)
		D.text(card, 526, 304, "eux", 17, C.MUTED, 500, 50)
	var previous := _previous_meeting(home, away)
	if not previous.is_empty():
		var recorded_id := str(previous.get("fixtureId", ""))
		var text := "Déjà joué cette saison : %s" % _meeting_text(previous)
		if target_available(app, "fixture", recorded_id):
			var meeting := _lien(card, Rect2(18, 322, RIGHT - 36, 36), text, func(): open_target(app, "fixture", recorded_id), "CompetitionLastMeeting", 19, true)
			meeting.tooltip_text = "Voir la rencontre"
		else: D.text(card, 24, 346, text, 19, C.MUTED, 500, RIGHT - 48, HORIZONTAL_ALIGNMENT_LEFT, true)
	var live: bool = not app._live().is_empty()
	var action := _principal(card, Rect2(24, 368, 330, 52), ("Rejoindre le match" if live else "Préparer le match").to_upper() + "  →", func(): app._navigate("Match" if live else "Préparation"), "CompetitionPrepareMatch")
	action.tooltip_text = "Préparer le match"
	if target_available(app, "club", opponent.get("id", "")):
		_lien(card, Rect2(380, 374, 320, 40), "Dossier adverse →", func(): open_target(app, "club", str(opponent.id)), "CompetitionOpponentFile", 20)
	return y + 430

func _previous_meeting(home: Dictionary, away: Dictionary) -> Dictionary:
	for result: Dictionary in season_results:
		var pair: Array = result.get("pair", [])
		if pair.size() == 2 and result.get("score") is Array and ((pair[0] == home.get("id") and pair[1] == away.get("id")) or (pair[0] == away.get("id") and pair[1] == home.get("id"))): return result
	return {}

func _meeting_text(result: Dictionary) -> String:
	var clubs := _matchup(result)
	var outcome := ""
	var pair: Array = result.get("pair", [])
	var score: Array = result.get("score", [])
	if score.size() == 2 and pair.size() == 2:
		var mine_index := 0 if pair[0] == own.get("id") else 1
		if score[mine_index] > score[1 - mine_index]: outcome = "victoire "
		elif score[mine_index] < score[1 - mine_index]: outcome = "défaite "
		else: outcome = "nul "
	return outcome + "%s %s %s" % [G.club_name(clubs[0]), _score(result), G.club_name(clubs[1])]

## Les six prochains rendez-vous du club : chaque ligne ouvre la rencontre, le club ou la date.
func _calendrier_club(y: float) -> float:
	var card := _carte(self, Rect2(LEFT + GAP, y, RIGHT, 340), "CALENDRIER DU CLUB", "CompetitionCalendarPreview")
	D.text(card, RIGHT - 24, 40, "6 prochains", 17, C.MUTED, 500, 200, HORIZONTAL_ALIGNMENT_RIGHT)
	_lien(card, Rect2(RIGHT - 264, 296, 250, 36), "Toute la saison →", func(): _switch("calendar"), "OpenFullCalendar", 20, false, HORIZONTAL_ALIGNMENT_RIGHT)
	if fixtures.is_empty():
		D.text(card, 24, 112, "Aucun rendez-vous programmé.", 22, C.MUTED, 500, RIGHT - 48, HORIZONTAL_ALIGNMENT_LEFT, true)
		return y + 340
	for entry: Array in [[14, "J."], [74, "DATE"], [206, "ADVERSAIRE"], [444, "LIEU"], [546, "RANG"]]:
		D.text(card, entry[0], 78, entry[1], 14, C.MUTED, 700, 150)
	var anchor := fixtures.find_custom(func(fixture: Dictionary): return not fixture.get("played", false))
	var from := clampi(anchor - 1 if anchor >= 0 else fixtures.size() - 6, 0, maxi(0, fixtures.size() - 6))
	for i in mini(fixtures.size() - from, 6):
		_calendar_row(card, fixtures[from + i], 88 + i * 34, RIGHT, true)
	return y + 340

## Sous les tableaux : derniers résultats de la compétition, puis meilleure attaque et meilleure défense.
func _bas_gauche() -> void:
	var y := left_bottom + GAP
	var started: bool = league.get("rows", []).any(func(club: Dictionary): return float(club.get("played", 0)) > 0)
	if not started:
		_opening_strip(y)
		left_bottom = y + 211
		return
	var results: Array = season_results.filter(func(result: Dictionary): return _competition_id(result, league.id) == league.id and result.get("pair") is Array and result.get("score") is Array).slice(0, 5)
	var height := 70 + maxi(1, results.size()) * 34 + 12
	var recent := _panel(self, Rect2(0, y, LEFT, height), "DERNIERS RÉSULTATS", "", "CompetitionRecentResults")
	for i in results.size():
		var result: Dictionary = results[i]
		var clubs := _matchup(result)
		var top := 58 + i * 34
		var fixture_id := str(result.get("fixtureId", ""))
		var line := Button.new()
		line.name = "RecentResult_%d" % i
		line.set_meta("immersive_style_applied", true)
		# Rayure une ligne sur deux et survol de ligne communs (ui/survol_ligne.gd, comme l'Effectif).
		load("res://ui/survol_ligne.gd").appliquer(line, false, Color.TRANSPARENT, app.accent).rang_fixe = i
		if target_available(app, "fixture", fixture_id):
			Link.bind(line, app, {"kind":"fixture", "id":fixture_id}, "Ouvrir la rencontre · %s %s %s" % [G.club_name(clubs[0]), _score(result), G.club_name(clubs[1])])
		else:
			line.focus_mode = Control.FOCUS_NONE
			line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		recent.add_child(line)
		D.place(line, Rect2(8, top, LEFT - 16, 32))
		D.text(line, 16, 23, _phase(result), 17, C.MUTED, 500, 220)
		D.text(line, 700, 23, G.club_name(clubs[0]), 21, C.IVORY, 700, 400, HORIZONTAL_ALIGNMENT_RIGHT)
		_crest(line, clubs[0], Rect2(716, 3, 26, 26))
		D.text(line, 800, 23, _score(result), 22, C.IVORY, 800, 120, HORIZONTAL_ALIGNMENT_CENTER)
		_crest(line, clubs[1], Rect2(868, 3, 26, 26))
		D.text(line, 904, 23, G.club_name(clubs[1]), 21, C.IVORY, 700, 420)
		_entity_area(line, Rect2(300, 0, 440, 32), {"kind":"club", "id":str(clubs[0].get("id", ""))}, "RecentHome_%d" % i, "Ouvrir le club · " + G.club_name(clubs[0]))
		_entity_area(line, Rect2(864, 0, 460, 32), {"kind":"club", "id":str(clubs[1].get("id", ""))}, "RecentAway_%d" % i, "Ouvrir le club · " + G.club_name(clubs[1]))
	if results.is_empty(): D.text(recent, 24, 100, "Aucun résultat enregistré pour cette division.", 22, C.MUTED, 500, LEFT - 48, HORIZONTAL_ALIGNMENT_LEFT, true)
	y += height + GAP
	var half := (LEFT - GAP) / 2.0
	_leader(Rect2(0, y, half, 130), "MEILLEURE ATTAQUE", "pf", "Points marqués", true)
	_leader(Rect2(half + GAP, y, half, 130), "MEILLEURE DÉFENSE", "pa", "Points encaissés", false)
	left_bottom = y + 130

## Avant la première journée : le coup d’envoi et le format de la saison remplacent les classements vides.
func _opening_strip(y: float) -> void:
	var panel := _panel(self, Rect2(0, y, LEFT, 211), "L’OUVERTURE DE LA SAISON", "", "CompetitionOpeningStrip")
	var first := fixtures.filter(func(fixture: Dictionary): return not fixture.get("played", false))
	var rounds := 0
	for fixture: Dictionary in fixtures:
		if _competition_id(fixture, league.id) == league.id and own.get("id") in [fixture.get("home", {}).get("id"), fixture.get("away", {}).get("id")]: rounds += 1
	var facts: Array = [["COUP D’ENVOI", "" if first.is_empty() else _date(first[0]), ""],
		["LE CHAMPIONNAT", "%s clubs" % G.n(league.get("rows", []).size()), "%s journées à jouer" % G.n(rounds) if rounds > 0 else ""],
		["À SUIVRE", "Attaque · défense", ""]]
	var tile_w := (LEFT - 48 - 2 * 14) / 3.0
	for i in facts.size():
		var tile := D.rect(panel, Rect2(24 + i * (tile_w + 14), 62, tile_w, 134), Charte.PANNEAU_2, Charte.RAYON_CARTE)
		D.text(tile, 18, 32, facts[i][0], 16, C.MUTED, 700, tile_w - 30)
		D.text(tile, 18, 76, facts[i][1] if not str(facts[i][1]).is_empty() else "À venir", 34, C.IVORY, 800, tile_w - 30)
		D.text(tile, 18, 112, facts[i][2], 17, C.MUTED, 500, tile_w - 30, HORIZONTAL_ALIGNMENT_LEFT, true)

func _leader(area: Rect2, title: String, metric: String, caption: String, high: bool) -> void:
	var panel := _panel(self, area, title, "", "CompetitionLeader_" + metric)
	var best: Dictionary = {}
	var tied := 0
	for club: Dictionary in league.get("rows", []):
		if float(club.get("played", 0)) <= 0 or S.count_text(club.get(metric)) == "—": continue
		if best.is_empty() or (float(club[metric]) > float(best[metric]) if high else float(club[metric]) < float(best[metric])):
			best = club
			tied = 1
		elif club[metric] == best[metric]:
			tied += 1
	if not best.is_empty(): _crest(panel, best, Rect2(24, 56, 64, 64))
	var club_name := D.text(panel, 106, 82, "Donnée à venir" if best.is_empty() else G.club_name(best), 26, C.IVORY, 700, area.size.x - 330)
	D.text(panel, 106, 110, caption + (" · %d ex æquo" % tied if tied > 1 else ""), 18, C.MUTED, 500, area.size.x - 330, HORIZONTAL_ALIGNMENT_LEFT, true)
	var value := D.text(panel, area.size.x - 24, 108, S.count_text(best.get(metric)), 56, C.IVORY, 800, 180, HORIZONTAL_ALIGNMENT_RIGHT)
	value.add_theme_font_override("font", Charte.TITRE_EXTRA)
	if not best.is_empty():
		var link := _entity_area(panel, Rect2(16, 50, area.size.x - 220, 76), {"kind":"club", "id":str(best.id)}, "CompetitionLeaderLink_" + metric, "Ouvrir le club · " + G.club_name(best))
		if link != null: club_name.tooltip_text = G.club_name(best)

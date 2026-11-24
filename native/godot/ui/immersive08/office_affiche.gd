extends "res://ui/immersive08/office_socle.gd"
## Écran Bureau : compte à rebours et affiche du prochain match (bandeau, face-à-face, semaine sans match, direct ; découpe de office_canvas.gd, sans changement).

## « SAMEDI, DANS 4 JOURS » depuis la date du jour du moteur et celle du match ; vide si l'une manque.
static func compte_a_rebours(app: Control, fixture: Dictionary) -> String:
	var today := str(app.model.get("meta", {}).get("calendarToday", ""))
	var date: Variant = fixture.get("date")
	if today.is_empty() or not date is String or date.is_empty(): return ""
	var depart := Time.get_unix_time_from_datetime_string(today)
	var arrivee := Time.get_unix_time_from_datetime_string(date)
	if depart <= 0 or arrivee <= 0: return ""
	var jours := int(roundf((arrivee - depart) / 86400.0))
	var nom: String = JOURS[int(Time.get_datetime_dict_from_datetime_string(date, false).get("weekday", 0))]
	if jours < 0: return ""
	if jours == 0: return "AUJOURD’HUI"
	if jours == 1: return "DEMAIN"
	return "%s, DANS %d JOURS" % [nom, jours]

# ---------------------------------------------------------------------------------------------------------
# Affiche du prochain match
# ---------------------------------------------------------------------------------------------------------

static func _fixture(card: Panel, app: Control, w: int = 1496) -> void:
	card.clip_contents = true
	# Photo et liseré de club suivent les coins arrondis du panneau.
	card.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	Charte.ombre_derriere(card)
	var photo := D.photo(card, P.fixture_ground(app.model.meta, "office-hero"), Rect2(0, 0, w, BAND), .53)
	photo.name = "OfficeFixturePhoto"
	D.rect(card, Rect2(0, 0, w, BAND), Color(Charte.FOND, .74)).name = "OfficeFixtureVeil"
	var territory := Office.territory_art(app.model.club, true)
	if territory != null:
		card.add_child(territory)
		D.place(territory, Rect2(w - 700, 10, 684, BAND - 20))
		# Les vignettes du club ouvrent l'écran Club (jamais une tuile légendée qui ne fait rien).
		var ouvrir := _zone(card, Rect2(w - 700, 10, 684, BAND - 20), "", func(): app._navigate("Club"), "OfficeTerritoryOpen", 20)
		ouvrir.tooltip_text = "Ouvrir l'écran Club"
		ouvrir.accessibility_name = "Ouvrir l'écran Club"
	var signature: Color = Charte.club_trait(app.accent)
	D.rect(card, Rect2(0, 0, 5, FIXTURE_H), signature)
	var body := Control.new()
	body.name = "OfficeFixtureBody"
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(body)
	D.place(body, Rect2(0, BAND, w, FIXTURE_H - BAND))
	var match_info := Office.live_match(app.model)
	if not match_info.is_empty():
		_live_content(body, app, match_info)
		return
	var next: Dictionary = app.model.next if app.model.get("next") is Dictionary else {}
	if next.is_empty():
		_sans_prochain(card, body, app)
		return
	_prochain(card, app, next, w)

## Rencontre à venir : bandeau (caption + compte à rebours), clubs, date, lieu, feuille, face-à-face, actions.
static func _prochain(card: Panel, app: Control, next: Dictionary, w: int) -> void:
	var match_label := str(next.get("label", P.league_name(app.model)))
	var competition := Office.fixture_stage(app.model, next, match_label)
	var location := "NEUTRE" if next.get("neutral", false) else "DOMICILE" if next.get("home", {}).get("id") == app.model.club.id else "EXTÉRIEUR"
	var caption := D.text(card, 28, 62, "PROCHAIN MATCH · %s · %s" % [competition.to_upper(), location], 20, Charte.IVOIRE, 700, w - 780)
	caption.name = "OfficeFixtureCaption"
	Office.describe_fixture(caption, match_label + " · " + location)
	var reste := compte_a_rebours(app, next)
	if not reste.is_empty(): _ex(D.text(card, 28, 104, reste, 34, Charte.IVOIRE, 800, w - 780)).name = "OfficeFixtureCountdown"
	if P.is_derby(app.model): D.derby_chip(card, Rect2(minf(28 + _largeur(caption.text, 20, C.font(700)) + 18, w - 900), 38, 98, 29))
	var home: Dictionary = next.get("home", {})
	var away: Dictionary = next.get("away", {})
	var demi := w / 2.0
	var y0 := BAND + 16
	for cote in 2:
		var club: Dictionary = home if cote == 0 else away
		var x0 := 28.0 if cote == 0 else demi + 40.0
		var base := y0 + 52
		_crest(card, club, Rect2(x0, y0, 64, 64))
		Office.reading_overlay(app, card, Rect2(x0, y0, 64, 64), Office.club_reading_target(app, club), "OfficeNext%sClubCrest" % ["Home" if cote == 0 else "Away"], G.club_name(club))
		var nom := _ex(D.text(card, x0 + 84, base, G.club_name(club).to_upper(), 44, Charte.IVOIRE, 800, demi - 160))
		_label_reading(app, card, nom, Office.club_reading_target(app, club), "OfficeNext%sClubName" % ["Home" if cote == 0 else "Away"], nom.text)
		if club.has("rank") and club.has("points"):
			var rang := G.n(club.rank)
			var texte := "%s%s · %s pts" % [rang, "er" if rang == "1" else "e", G.n(club.points)] if P.standings_open(club) else "Pas encore classé · %s pts" % G.n(club.points)
			D.text(card, x0 + 84, base + 28, texte, 20, Charte.club_texte(app.accent) if club.get("id") == app.model.club.id else Charte.IVOIRE_2, 600, demi - 160)
	D.text(card, demi, y0 + 46, "CONTRE", 20, Charte.IVOIRE_2, 700, 120, HORIZONTAL_ALIGNMENT_CENTER)
	# Colonne de gauche : quand, où, feuille, actions.
	var y := y0 + 90
	var calendrier := C.icon("calendar", 25, Charte.IVOIRE_2)
	card.add_child(calendrier)
	D.place(calendrier, Rect2(28, y + 4, 25, 25))
	var date := P.fixture_date(next, true)
	if date.is_empty(): date = "SEMAINE %d" % [int(next.get("week", 0)) + 1]
	var quand := D.text(card, 66, y + 26, date + " · " + Office.fixture_competition(app.model, next), 21, Charte.IVOIRE, 600, 740, HORIZONTAL_ALIGNMENT_LEFT, true)
	quand.name = "OfficeFixtureDate"
	_label_reading(app, card, quand, Office.date_reading_target(app, next), "OfficeNextDate", quand.text)
	var terrain := P.fixture_venue(next, false)
	if not terrain.is_empty():
		var maison := C.icon("home", 23, Charte.IVOIRE_2)
		card.add_child(maison)
		D.place(maison, Rect2(29, y + 40, 23, 23))
		D.text(card, 66, y + 60, terrain, 21, Charte.IVOIRE_2, 500, 640, HORIZONTAL_ALIGNMENT_LEFT, true).name = "OfficeFixtureVenue"
	var valide: bool = app.model.get("selection", {}).get("valid", false)
	D.text(card, 28, y + 98, "Feuille complète" if valide else "Feuille à préparer", 21, Charte.V if valide else Charte.IVOIRE, 700, 330)
	_principal(card, Rect2(28, y + 118, 340, 54), "PRÉPARER LE MATCH", func(): app._navigate("Préparation"), "OfficePreparationAction", app.accent)
	_lien(card, 392, y + 129, "Vérifier les 23 →", func(): app._navigate("Composition"), "OfficeSelectionAction", 21)
	_face_a_face(card, app, home, away, Rect2(demi + 40, y - 8, demi - 68, 190))

## Face-à-face chiffré (emprunt à la variante 3) : une ligne par donnée connue des deux clubs, jamais inventée.
static func _face_a_face(card: Control, app: Control, home: Dictionary, away: Dictionary, zone: Rect2) -> void:
	var lignes: Array = []
	var rows: Array[Dictionary] = [_ligne_club(app.model, home.get("id")), _ligne_club(app.model, away.get("id"))]
	var equipes: Array[Dictionary] = [home, away]
	var rang: Array[String] = ["", ""]
	for i in 2:
		var equipe: Dictionary = equipes[i]
		var ligne: Dictionary = rows[i]
		var source: Dictionary = equipe if equipe.has("rank") and equipe.has("points") else ligne
		if source.has("rank") and source.has("points"):
			var r := G.n(source.rank)
			rang[i] = "%s%s · %s pts" % [r, "er" if r == "1" else "e", G.n(source.points)] if P.standings_open(source) else "Pas encore classé"
	if not rang[0].is_empty() and not rang[1].is_empty(): lignes.append(["Classement", rang[0], rang[1]])
	if rows.all(func(r: Dictionary): return r.get("form") is Array and not r.form.is_empty()): lignes.append(["5 derniers", rows[0].form, rows[1].form])
	if rows.all(func(r: Dictionary): return r.has("won") and r.has("drawn") and r.has("lost") and int(r.get("played", 0)) > 0):
		lignes.append(["Bilan", "%sV · %sN · %sD" % [G.n(rows[0].won), G.n(rows[0].drawn), G.n(rows[0].lost)], "%sV · %sN · %sD" % [G.n(rows[1].won), G.n(rows[1].drawn), G.n(rows[1].lost)]])
	if rows.all(func(r: Dictionary): return r.has("pf") and r.has("pa") and int(r.get("played", 0)) > 0):
		lignes.append(["Différence de points", "%+d" % (int(rows[0].pf) - int(rows[0].pa)), "%+d" % (int(rows[1].pf) - int(rows[1].pa))])
	var panneau := D.rect(card, zone, Color(Charte.PANNEAU_2, .0))
	panneau.name = "OfficeFaceAFace"
	var l := zone.size.x
	var tete_g := D.text(card, zone.position.x, zone.position.y + 16, G.club_name(home).to_upper(), 17, Charte.IVOIRE_2, 700, l * .36)
	Office.reading_overlay(app, card, Rect2(tete_g.position.x / C.density, tete_g.position.y / C.density - 6, tete_g.size.x / C.density, 32), Office.club_reading_target(app, home), "OfficeFaceHomeClub", tete_g.text)
	D.text(card, zone.position.x + l / 2.0, zone.position.y + 16, "FACE À FACE", 17, Charte.IVOIRE, 700, l * .28, HORIZONTAL_ALIGNMENT_CENTER)
	var tete_d := D.text(card, zone.position.x + l, zone.position.y + 16, G.club_name(away).to_upper(), 17, Charte.IVOIRE_2, 700, l * .36, HORIZONTAL_ALIGNMENT_RIGHT)
	Office.reading_overlay(app, card, Rect2(tete_d.position.x / C.density, tete_d.position.y / C.density - 6, tete_d.size.x / C.density, 32), Office.club_reading_target(app, away), "OfficeFaceAwayClub", tete_d.text)
	if lignes.is_empty():
		D.text(card, zone.position.x + l / 2.0, zone.position.y + 70, "Début de saison : aucun match joué.", 20, Charte.IVOIRE_2, 500, l, HORIZONTAL_ALIGNMENT_CENTER, true)
		return
	for i in lignes.size():
		var ligne: Array = lignes[i]
		var y := zone.position.y + 28 + i * 38
		if i > 0: D.line(card, Vector2(zone.position.x - 8, y), Vector2(zone.position.x + l + 8, y), Charte.FILET)
		# La ligne « Classement » ouvre le classement complet ; les autres lignes sont des chiffres lus.
		if str(ligne[0]) == "Classement":
			var vers := _zone(card, Rect2(zone.position.x - 8, y, l + 16, 36), "", func(): Office.open_current_standings(app), "OfficeFaceClassement", 20)
			vers.tooltip_text = "Ouvrir le classement complet"
			vers.accessibility_name = "Ouvrir le classement complet"
		D.text(card, zone.position.x + l / 2.0, y + 25, str(ligne[0]), 18, Charte.IVOIRE_2, 500, l * .34, HORIZONTAL_ALIGNMENT_CENTER, true)
		for cote in 2:
			var valeur: Variant = ligne[1 + cote]
			var gauche: bool = cote == 0
			if valeur is Array:
				_forme(card, zone.position.x if gauche else zone.position.x + l, y + 6, valeur, not gauche)
			else:
				D.text(card, zone.position.x if gauche else zone.position.x + l, y + 25, str(valeur), 21, Charte.IVOIRE, 600, l * .34, HORIZONTAL_ALIGNMENT_LEFT if gauche else HORIZONTAL_ALIGNMENT_RIGHT, true)

## États sans « prochain match » (semaine exempte, préparation, intersaison) : texte sous le bandeau.
static func _sans_prochain(card: Panel, body: Control, app: Control) -> void:
	var japan := SeasonPreparation.is_japan(app.model.meta)
	var preparation := SeasonPreparation.data(app.model.meta)
	var upcoming := P.next_nationale_fixture(app.model)
	var scheduled := P.next_scheduled_fixture(app.model)
	if not upcoming.is_empty():
		D.chip(body, Rect2(24, 22, 281, 29), "SEMAINE EXEMPTE", Charte.IVOIRE)
		var opponent := D.text(body, 27, 121, Office.scheduled_opponent(app, upcoming), 51, Charte.IVOIRE, 800, 645)
		opponent.name = "UpcomingOpponent"
		var timing := D.text(body, 27, 183, "Prochain match · " + Office.scheduled_when(app, upcoming), 27, Charte.IVOIRE, 600, 645)
		timing.name = "UpcomingWhen"
		_scheduled_reading(app, body, upcoming, opponent, timing)
		var venue := Office.scheduled_venue(app, upcoming)
		if not venue.is_empty(): D.text(body, 27, 223, "Lieu · " + venue, 21, Charte.IVOIRE_2, 400, 645, HORIZONTAL_ALIGNMENT_LEFT, true)
	elif preparation.is_empty() and not scheduled.is_empty():
		D.text(body, 27, 45, "PROCHAINE RENCONTRE", 22, Charte.IVOIRE, 700, 640)
		var opponent := D.text(body, 27, 115, Office.scheduled_opponent(app, scheduled), 48, Charte.IVOIRE, 800, 645)
		var timing := D.text(body, 27, 169, Office.scheduled_when(app, scheduled), 27, Charte.IVOIRE, 600, 645)
		_scheduled_reading(app, body, scheduled, opponent, timing)
		D.text(body, 27, 210, P.fixture_venue(scheduled), 22, Charte.IVOIRE_2, 400, 645, HORIZONTAL_ALIGNMENT_LEFT, true)
	elif preparation.is_empty():
		D.text(body, 27, 100, "La saison se termine." if app.model.meta.get("canAdvanceSeason", false) else "Le travail continue.", 42, Charte.IVOIRE, 700, 740)
		D.text(body, 27, 156, "Retrouve les résultats et prépare la suite du projet.", 21, Charte.IVOIRE_2, 400, 740, HORIZONTAL_ALIGNMENT_LEFT, true)
	elif SeasonPreparation.is_champ(app.model.meta):
		var fixture := P.next_scheduled_fixture(app.model)
		D.chip(body, Rect2(24, 22, 210, 29), "PRÉPARATION", Charte.IVOIRE)
		if fixture.is_empty():
			D.text(body, 27, 121, "Préparation · " + World.name_for(app.model, "champ"), 58, Charte.IVOIRE, 800, 920)
			D.text(body, 27, 183, World.preparation_note(preparation), 30, Charte.IVOIRE, 600, 720)
		else:
			var opponent := D.text(body, 27, 121, Office.scheduled_opponent(app, fixture), 51, Charte.IVOIRE, 800, 645)
			opponent.name = "UpcomingOpponent"
			var timing := D.text(body, 27, 183, Office.scheduled_when(app, fixture), 27, Charte.IVOIRE, 600, 645)
			timing.name = "UpcomingWhen"
			_scheduled_reading(app, body, fixture, opponent, timing)
			var venue := Office.scheduled_venue(app, fixture)
			if not venue.is_empty(): D.text(body, 27, 223, "Lieu · " + venue, 21, Charte.IVOIRE_2, 400, 645, HORIZONTAL_ALIGNMENT_LEFT, true)
	else:
		D.chip(body, Rect2(24, 22, 322 if japan else 281, 29), World.name_for(app.model, str(app.model.meta.get("leagueId", "srp"))).to_upper(), Charte.IVOIRE)
		D.text(body, 27, 121, "Préparation · " + World.name_for(app.model, str(app.model.meta.get("leagueId", "srp"))), 58, Charte.IVOIRE, 800, 920)
		D.text(body, 27, 183, World.preparation_note(preparation), 30, Charte.IVOIRE, 600, 720)
		D.text(body, 27, 223, "Avance de quatre semaines au plus, jusqu’à la prochaine rencontre.", 21, Charte.IVOIRE_2, 400, 735, HORIZONTAL_ALIGNMENT_LEFT, true)
	_principal(body, Rect2(27, 244, 420, 54), app.primary_text().trim_suffix("  →"), app.primary_action, "OfficePreparationAction", app.accent)

static func _live_content(body: Control, app: Control, match_info: Dictionary) -> void:
	D.text(body, 27, 28, match_info.heading, 22, Charte.IVOIRE, 700, 400).name = "OfficeLiveHeading"
	if not match_info.location.is_empty():
		D.chip(body, Rect2(300, 8, 176, 29), match_info.location, Charte.IVOIRE_2)
	var teams: Array = match_info.teams
	for i in teams.size():
		var team: Dictionary = teams[i]
		var y := 40 + 64 * i
		_crest(body, team, Rect2(27, y, 54, 54))
		D.text(body, 99, y + 38, G.club_name(team), 36, Charte.IVOIRE, 800, 548)
	D.text(body, 27, 200, match_info.score, 40, Charte.IVOIRE, 800, 158).name = "OfficeLiveScore"
	D.text(body, 188, 198, match_info.state, 24, Charte.IVOIRE, 650, 490).name = "OfficeLiveState"
	if not match_info.detail.is_empty():
		D.text(body, 27, 232, match_info.detail, 21, Charte.IVOIRE_2, 400, 638, HORIZONTAL_ALIGNMENT_LEFT, true).name = "OfficeLiveFixtureDetail"
	_principal(body, Rect2(27, 244, 358, 54), app.primary_text().trim_suffix("  →"), app.primary_action, "OfficePreparationAction", app.accent)
	var review := _lien(body, 410, 255, "Revoir le match →", func(): app._navigate("Match"), "OfficeMatchReviewAction", 21)
	review.visible = match_info.finished

extends "res://ui/immersive08/competition_colonne.gd"
## Classements, phases finales, calendrier et résultats de la carrière native.
## Fichier public de l'écran (construction, en-tête, sous-pages rencontre et archives) ; le reste vit dans la chaîne
## competition_socle.gd ← competition_classement.gd ← competition_calendrier.gd ← competition_colonne.gd.

const Socle = preload("res://ui/immersive08/competition_socle.gd")

## Points d'entrée publics de la lecture : redéfinis ici, car `has_method` d'un script ne voit pas les statiques hérités
## (navigation_controller.gd teste `target_available` sur ce fichier). Le corps est dans competition_socle.gd.
static func target_available(owner_app: Control, kind: String, id: Variant) -> bool:
	return Socle.target_available(owner_app, kind, id)

static func open_target(owner_app: Control, kind: String, id: Variant) -> bool:
	return Socle.open_target(owner_app, kind, id)

static func session_context_matches(owner_app: Control, id: Variant) -> bool:
	return Socle.session_context_matches(owner_app, id)

static func open_archives(owner_app: Control) -> void:
	Socle.open_archives(owner_app)

static func same_club_id(value: Variant, id: String) -> bool:
	return Socle.same_club_id(value, id)

static func build(owner_app: Control, canvas: Control) -> void:
	var page: Control = load("res://ui/immersive08/competition_canvas.gd").new()
	page.app = owner_app
	canvas.add_child(page)
	D.place(page, Rect2(0, 0, WIDTH, 1240))
	page._build()
	var bottom: float = maxf(1240.0, page.content_bottom + 10.0)
	page.size.y = C.px(bottom)
	canvas.custom_minimum_size.y = maxf(canvas.custom_minimum_size.y, C.px(bottom))

func _context(reading_only: bool = false) -> void:
	var own_value: Variant = app.model.get("club")
	own = own_value if own_value is Dictionary else {}
	international = app.model.meta.get("mode") == "world"
	if not app.management_ui.get("competition") is Dictionary: app.management_ui.competition = {}
	state = app.management_ui.competition
	var club_league := str(app.model.meta.get("leagueId", ""))
	if not reading_only and state.get("club_league") != club_league:
		state.club_league = club_league
		if not club_league.is_empty(): app.table_division = club_league
	var selected_league: String = club_league if app.route == "Calendrier" else app.table_division
	leagues = app.model.get("leagues", [])
	if leagues.is_empty(): leagues = [{"id": "elite", "name": "Championnat historique", "rows": app.model.get("league", [])}]
	league = leagues[0]
	for division: Dictionary in leagues:
		if division.id == selected_league: league = division
		for club: Dictionary in division.get("rows", []): identities[club.id] = club
	for club: Dictionary in app.catalogue:
		if not identities.has(club.id): identities[club.id] = club
	if own.has("id"): identities[own.id] = own
	var next_value: Variant = app.model.get("next")
	next_fixture = next_value if next_value is Dictionary else {}
	fixtures = app.model.get("calendar", []).duplicate()
	if not international:
		fixtures.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.get("week", 0)) < int(b.get("week", 0)))
	season_results = app.model.get("history", []).duplicate()
	season_results.reverse()

func _build() -> void:
	name = "CarnetCalendar" if app.route == "Calendrier" else "CarnetStandings"
	_context()
	mode = "calendar" if app.route == "Calendrier" else str(state.get("tab", "league"))
	if _sous_page(): return
	_header()
	left_bottom = TOP + 760.0
	# « Dans le monde » (revue FM27, idée 30, choix A de Léo du 23/11/2026) : le journal du monde, onglet de Compétitions.
	if mode == "monde":
		content_bottom = load("res://ui/immersive08/dans_le_monde.gd").construire(self)
		return
	match mode:
		"calendar": _calendar()
		"playoffs": _playoffs()
		"stats": _stats()
		_: _classement()
	_bas_gauche()
	_colonne_droite()
	content_bottom = maxf(left_bottom, right_bottom)

# --- Outils de composition (jetons de la charte, aucune couleur codée en dur) -----------------------------------

func _header() -> void:
	var title := D.text(self, 0, 50, "COMPÉTITIONS", 50, C.IVORY, 800, 440)
	title.add_theme_font_override("font", Charte.TITRE_FICHE)
	title.name = "CompetitionTitle"
	var round_label := str(app.model.meta.get("roundLabel", "")) if league.id == state.club_league else "Phase régulière" if league.get("phase", "league") == "league" else _phase(league)
	var short_round := round_label.trim_prefix(str(league.get("name","")) + " · ")
	var subhead := "%s  ·  saison %s  ·  %s" % [_league_short(league), G.season_label(app.model.meta.get("season", "—")), short_round]
	var sub := D.text(self, 450, 46, subhead, 22, C.MUTED, 500, 1100, HORIZONTAL_ALIGNMENT_LEFT, true)
	sub.name = "CompetitionSubhead"
	if _followed_from_afar():
		var afar := D.text(self, 1580, 44, "CONSULTATION", 20, C.MUTED, 700, 200)
		afar.name = "CompetitionFollowedFromAfar"
		afar.mouse_filter = Control.MOUSE_FILTER_STOP
		afar.tooltip_text = AFAR_HINT
	var emblem := G._pack_texture(str(league.get("logoPath", "")))
	if emblem != null:
		var logo := TextureRect.new()
		logo.name = "CompetitionOfficialLogo"
		logo.texture = emblem
		logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		logo.accessibility_name = str(league.get("name", "Championnat"))
		add_child(logo)
		D.place(logo, Rect2(WIDTH - 150, 0, 150, 60))
	var x := 0
	for spec: Array in [[250, "Classements", "league", "Section_Classements"], [270, "Phases finales", "playoffs", "CompetitionPlayoffs"],
		[240, "Calendrier", "calendar", "Section_Calendrier"], [250, "Statistiques", "stats", "CompetitionStats"]]:
		_onglet(Rect2(x, 78, spec[0], 52), spec[1], mode == spec[2], func(): _switch(str(spec[2])), spec[3])
		x += int(spec[0]) + 4
	_onglet(Rect2(x, 78, 230, 52), "Rivalités", false, func(): app._navigate("Rivalités"), "Section_Rivalités")
	if international:
		_onglet(Rect2(x + 234, 78, 280, 52), "Dans le monde", mode == "monde", func(): _switch("monde"), "CompetitionMonde")
	var archives := _lien(self, Rect2(WIDTH - 340, 86, 340, 40), "Archives des saisons →", func(): Club.season_archives(app), "OpenArchives", 20, false, HORIZONTAL_ALIGNMENT_RIGHT)
	archives.tooltip_text = "Les saisons passées : champions, montées, descentes"
	if EquipeType.disponible(app.model):
		_lien(self, Rect2(WIDTH - 540, 86, 190, 40), "XV type →", func(): EquipeType.ouvrir(app, league.id if league.get("id") else "", "journee"), "CompetitionEquipeType", 20, false, HORIZONTAL_ALIGNMENT_RIGHT)
	D.line(self, Vector2(0, 132), Vector2(WIDTH, 132), Charte.FILET)

## Championnat suivi de loin (Réglages › Championnats suivis, carrière Monde configurée).
func _followed_from_afar() -> bool:
	var detail: Variant = app.model.get("clubLife", {}).get("leagueDetail", {})
	if not detail is Dictionary or not bool(detail.get("configured", false)) or league.has("pools"): return false
	for item: Variant in detail.get("leagues", []):
		if item is Dictionary and str(item.get("id", "")) == str(league.get("id", "")): return not bool(item.get("detailed", true))
	return false

## Menu de compétition : se ferme au clic ailleurs et à Échap (avant le retour d'historique).
func _input(event: InputEvent) -> void:
	if _menu_list == null or not is_instance_valid(_menu_list) or not _menu_list.visible: return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_menu_list.visible = false
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		var point := get_viewport().get_mouse_position()
		if not _menu_list.get_global_rect().has_point(point) and not _menu_button.get_global_rect().has_point(point): _menu_list.visible = false

func _fermer_page() -> void:
	app.management_ui.erase("competition_page")
	app._navigate("Classements", true, true)

func _sous_page() -> bool:
	var request: Variant = app.management_ui.get("competition_page")
	if not request is Dictionary: return false
	var kind := str(request.get("kind", ""))
	var fixture: Dictionary = {}
	if kind == "fixture":
		fixture = _target_fixture(app, str(request.get("id", "")))
		if fixture.is_empty():
			app.management_ui.erase("competition_page")
			return false
	elif kind != "archives":
		app.management_ui.erase("competition_page")
		return false
	var back := _lien(self, Rect2(0, 8, 460, 40), "← Retour au classement", _fermer_page, "CompetitionPageBack", 21)
	back.tooltip_text = "Retour · Échap"
	D.line(self, Vector2(0, 62), Vector2(WIDTH, 62), Charte.FILET)
	if kind == "archives":
		_page_archives()
	else:
		_page_rencontre(fixture)
	return true

func _titre_page(texte: String) -> void:
	var title := D.text(self, 0, 116, texte.to_upper(), 46, C.IVORY, 800, WIDTH)
	title.add_theme_font_override("font", Charte.TITRE_FICHE)
	title.name = "CompetitionPageTitle"

func _page_archives() -> void:
	_titre_page("Le carnet des saisons")
	var panel := D.rect(self, Rect2(0, 140, LEFT, 1000), Charte.PANNEAU, Charte.RAYON_PANNEAU)
	panel.name = "CompetitionArchivesPage"
	var content := C.v(10)
	content.name = "SeasonArchives"
	panel.add_child(content)
	D.place(content, Rect2(32, 24, LEFT - 64, 940))
	var seasons: Array = app.model.get("archives", {}).get("seasons", []).duplicate()
	seasons.reverse()
	var world: GDScript = World
	if seasons.is_empty():
		content.add_child(C.wrap("Aucune saison archivée", 22, C.MUTED))
	var lines := 1
	for year: Dictionary in seasons:
		var heading := C.label("SAISON " + G.season_label(year.season), 30, C.IVORY, true, 800)
		heading.add_theme_font_override("font", Charte.TITRE_GRAS)
		heading.name = "SeasonArchiveHeading_" + G.n(year.season)
		content.add_child(heading)
		for winner: Dictionary in Club.archive_titles(year):
			_ligne_archive(content, "Champion %s : %s" % [Club.competition_name(winner.leagueId, app.model), Club._archive_club(app, winner.clubId)], winner.clubId, 22, C.IVORY)
		var standings: Dictionary = year.get("standings", {})
		for league_id: Variant in standings.keys():
			var ranks: Array = standings.get(league_id, [])
			var position := ranks.find(own.get("id"))
			if position >= 0: _ligne_archive(content, "Ton club · %s · %s sur %d en phase régulière" % [Club.competition_name(str(league_id), app.model), _ordinal(position + 1), ranks.size()], null, 20, C.IVORY)
		for pair: Array in [["promoted", "Montées" if year.get("movement", {}).get("promoted", []).size() > 1 else "Montée"], ["relegated", "Descentes" if year.get("movement", {}).get("relegated", []).size() > 1 else "Descente"]]:
			var moved: Array = year.get("movement", {}).get(pair[0], [])
			if moved.is_empty(): continue
			var names := PackedStringArray()
			for id: Variant in moved: names.append(Club._archive_club(app, id))
			_ligne_archive(content, pair[1] + " · " + ", ".join(names), moved[0] if moved.size() == 1 else null, 20, C.MUTED)
		for barrage: Dictionary in world.japan_barrages(year):
			for line: String in world.japan_lines(app, barrage): _ligne_archive(content, line, null, 20, C.MUTED)
		content.add_child(C.rule())
	# Hauteur du panneau : estimée ligne par ligne (titre de saison, ligne, filet), sans grand vide sous une page courte.
	var estimate := 48.0
	for child: Node in content.get_children():
		estimate += 14.0 if child is HSeparator else 52.0 if str(child.name).begins_with("SeasonArchiveHeading_") else 38.0
	lines = int(estimate)
	var height := maxf(180.0, float(lines))
	panel.size.y = C.px(height)
	content.size.y = C.px(height - 60)
	content_bottom = 160.0 + height

## Une ligne du carnet ; quand elle cite un seul club connu, toute la ligne ouvre sa fiche (flèche et soulignement au survol).
func _ligne_archive(parent: Control, text: String, club_id: Variant, size: int, tint: Color) -> void:
	var linked := club_id != null and target_available(app, "club", str(club_id))
	var label := C.wrap(text + ("  →" if linked else ""), size, tint)
	parent.add_child(label)
	if not linked: return
	var area := Button.new()
	# Identifiant entier (le JSON livre « 12.0 », et le point est interdit dans un nom de nœud).
	area.name = "SeasonArchiveClub_" + (str(int(club_id)) if club_id is float or club_id is int else str(club_id).validate_node_name())
	area.flat = true
	area.set_meta("immersive_style_applied", true)
	for look in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Charte.PANNEAU_3 if look == "hover" else Color(0, 0, 0, 0)
		style.set_corner_radius_all(Charte.RAYON_PETIT)
		if look == "focus":
			style.border_color = Charte.IVOIRE
			style.border_width_bottom = maxi(2, C.px(2))
		area.add_theme_stylebox_override(look, style)
	area.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	label.add_child(area)
	area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	area.show_behind_parent = true
	Link.bind(area, app, {"kind":"club", "id":str(club_id)}, "Ouvrir le club · " + Club._archive_club(app, club_id))

## Habille les textes d'une vue historique aux jetons de la charte (texte ivoire sur surface sombre).
func _recolorer(racine: Node) -> void:
	for node: Node in racine.find_children("*", "Label", true, false):
		var label := node as Label
		label.add_theme_color_override("font_color", C.IVORY)
		label.add_theme_font_override("font", Charte.TEXTE)
		label.add_theme_font_size_override("font_size", maxi(C.px(19), label.get_theme_font_size("font_size")))
	for node: Node in racine.find_children("*", "OptionButton", true, false):
		var choice := node as OptionButton
		choice.add_theme_color_override("font_color", C.IVORY)

func _page_rencontre(fixture: Dictionary) -> void:
	var competition_id := _competition_id(fixture)
	var heading := _fixture_label(fixture)
	if international:
		var stage := _dated_phase(fixture)
		heading = _competition_name(fixture) + " · " + stage
		if competition_id == "access-nationale": heading = _competition_name(fixture)
	_titre_page(heading)
	# Gabarit du « Prochain rendez-vous » : plaques inclinées aux couleurs des clubs, score entre les deux.
	var panel := D.rect(self, Rect2(0, 140, LEFT, 800), Charte.PANNEAU, Charte.RAYON_PANNEAU)
	panel.name = "CompetitionFixtureDetails"
	panel.set_meta("entity_kind", "fixture")
	panel.set_meta("entity_id", str(fixture.get("id", "")))
	var home_club: Dictionary = fixture.get("home", {})
	var away_club: Dictionary = fixture.get("away", {})
	var home_plate := _plaque(panel, Rect2(32, 28, 560, 88), home_club, "FixtureClub_home", false)
	var away_plate := _plaque(panel, Rect2(LEFT - 592, 28, 560, 88), away_club, "FixtureClub_away", true)
	for plate: Button in [home_plate, away_plate]:
		if plate.tooltip_text.is_empty(): plate.tooltip_text = plate.accessibility_name
	var middle := _score(fixture) if fixture.get("played", false) else "CONTRE"
	var middle_label := D.text(panel, 592, 86, middle, 52 if fixture.get("played", false) else 22, C.IVORY if fixture.get("played", false) else C.MUTED, 800, LEFT - 1184, HORIZONTAL_ALIGNMENT_CENTER)
	middle_label.add_theme_font_override("font", Charte.TITRE_GRAS)
	middle_label.name = "CompetitionFixtureScore"
	# Centré entre les deux plaques une fois la police de titre posée (sa largeur change avec la police).
	var middle_w := middle_label.get_theme_font("font").get_string_size(middle, HORIZONTAL_ALIGNMENT_LEFT, -1, middle_label.get_theme_font_size("font_size")).x
	middle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	middle_label.size.x = middle_w + 4
	middle_label.position.x = LEFT / 2.0 * C.density - middle_w / 2.0
	var content := C.v(14)
	panel.add_child(content)
	D.place(content, Rect2(32, 140, LEFT - 64, 640))
	var place := _location(fixture)
	var venue := _venue_name(fixture)
	if not venue.is_empty(): place += "  ·  " + venue
	var date := P.fixture_date(fixture, true)
	if not date.is_empty():
		var raw_date: Variant = fixture.get("date")
		if target_available(app, "date", raw_date):
			content.add_child(_nav_lien(date + " · voir dans le calendrier →", {"kind":"date", "id":raw_date}, "FixtureCalendarDate", 22))
		else: content.add_child(C.label(date, 26, C.IVORY, true, 700))
	if target_available(app, "competition", competition_id):
		content.add_child(_nav_lien(_competition_name(fixture) + " · voir le classement →", {"kind":"competition", "id":competition_id}, "FixtureCompetition", 22))
	content.add_child(C.label(_phase(fixture) + "  ·  " + place, 24, C.MUTED))
	if fixture.get("played", false):
		var code := _fixture_outcome(fixture)
		var verdict := str(S.RESULTS.get(code, {}).get("label", "Issue non renseignée"))
		var result := C.label((code + "  ·  " + verdict if code in RESULT_TINTS else verdict).to_upper(), 34, RESULT_TINTS.get(code, C.IVORY), true, 800)
		result.add_theme_font_override("font", Charte.TITRE_GRAS)
		result.name = "CompetitionFixtureResult"
		content.add_child(result)
		_fixture_statistics(content, fixture)
		var winner: Variant = _fixture_winner(fixture)
		if winner != null and identities.has(winner):
			content.add_child(C.label("Vainqueur : " + G.club_name(identities[winner]), 26, C.IVORY))
	else:
		content.add_child(C.label("Match à jouer", 30, C.IVORY, true, 700))
		if _is_next(fixture):
			var live: bool = not app._live().is_empty()
			var prepare := Button.new()
			prepare.name = "CompetitionFixturePrepare"
			prepare.text = ("Rejoindre le match" if live else "Préparer le match").to_upper() + "  →"
			prepare.set_meta("immersive_style_applied", true)
			C.style_bouton_contour(prepare, 22)
			prepare.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			prepare.pressed.connect(func(): app._navigate("Match" if live else "Préparation"))
			content.add_child(prepare)
	content_bottom = 960.0

## Lien de la charte vers une entité (club, date, compétition) : un clic change d'écran.
func _nav_lien(caption: String, target: Dictionary, id: String, size: int = 20) -> Button:
	var button := Button.new()
	button.name = id
	button.text = caption
	button.set_meta("immersive_style_applied", true)
	C.style_bouton_lien(button, size, true)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	Link.bind(button, app, target, caption)
	return button

extends RefCounted
const FocusLater := preload("res://ui/focus_later.gd")

const Charte = preload("res://ui/charte.gd")
const G = preload("res://ui/game_skin.gd")
const C = preload("res://ui/immersive08/components.gd")
const P = preload("res://ui/immersive08/projection.gd")
const Sheet = preload("res://ui/national_sheet.gd")
const Availability = preload("res://ui/international_availability.gd")
const Visuel = preload("res://ui/selections_visuel.gd")
const PastillesClub = preload("res://ui/immersive08/pastilles_club.gd")
const FIXTURES_PER_PAGE := 10

const MONTHS_FR := ["janvier","février","mars","avril","mai","juin","juillet","août","septembre","octobre","novembre","décembre"]

# Date ISO (AAAA-MM-JJ) en français lisible ; toute autre valeur est rendue telle quelle.
static func french_date(iso: Variant) -> String:
	var parts := str(iso).split("-")
	if parts.size() != 3 or not parts[1].is_valid_int() or int(parts[1]) < 1 or int(parts[1]) > 12: return str(iso)
	var day := int(parts[2])
	return "%s %s %s" % ["1er" if day == 1 else str(day), MONTHS_FR[int(parts[1]) - 1], parts[0]]

static func _period(from: Variant, through: Variant) -> String:
	return "du %s au %s" % [french_date(from), french_date(through)]

static func nation_only(model: Dictionary) -> bool:
	return model.get("international", {}).get("role") == "nation"

static func navigation_allowed(model: Dictionary, route: String) -> bool:
	return not nation_only(model) or route in ["Accueil", "Création", "Packs", "Réception", "Sélections", "Calendrier", "Recherche", "Réglages"]

static func managed_team(model: Dictionary) -> Dictionary:
	var international: Dictionary = model.get("international", {})
	for team: Dictionary in international.get("teams", []):
		if team.id == international.get("nation"): return team
	return {}

# A consultation target belongs to the UI session, never to the sporting role.
static func team_by_id(model: Dictionary, nation_id: String) -> Dictionary:
	var international: Variant = model.get("international")
	if not international is Dictionary: return {}
	for team: Dictionary in international.get("teams", []):
		if str(team.get("id", "")) == nation_id: return team
	return {}

static func open_target(app: Control, nation_id: String) -> bool:
	if not target_available(app, nation_id): return false
	var reading: Dictionary = app.management_ui.get("international", {})
	reading.navigation_id = nation_id
	app.management_ui.international = reading
	return true

static func target_available(app: Control, nation_id: String) -> bool:
	return not nation_id.is_empty() and not team_by_id(app.model, nation_id).is_empty()

static func _nation_link(app: Control, nation_id: String, caption: String) -> Button:
	var link := G.button(caption, func(): app.navigation_controller.open_entity({"kind":"nation", "id":nation_id}))
	link.name = "OpenNation_" + nation_id.validate_node_name()
	link.accessibility_name = "Consulter la sélection · " + caption
	link.tooltip_text = link.accessibility_name
	link.set_meta("entity_kind", "nation")
	link.set_meta("entity_id", nation_id)
	return link

static func _projected_reading(app: Control, content: Control, target: Dictionary, control_name: String, caption: String) -> Control:
	if not app.navigation_controller.entity_available(target): return content
	var destination := target.duplicate(true)
	# Preserve the original label's immersive styling before wrapping it in a
	# transparent reading control. Generic legacy buttons have larger margins.
	preload("res://ui/immersive08/legacy_style.gd").apply(content, app.accent)
	var link := Button.new()
	link.name = control_name
	link.set_meta("immersive_style_applied", true)
	link.custom_minimum_size = content.get_combined_minimum_size()
	link.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if content is Label: link.add_theme_font_size_override("font_size", content.get_theme_font_size("font_size"))
	link.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	link.add_theme_stylebox_override("focus", G.T.box(Color.TRANSPARENT, 2, G.GOLD))
	link.set_meta("entity_kind", str(destination.kind))
	link.set_meta("entity_id", str(destination.id))
	link.accessibility_name = "Consulter · " + caption
	link.tooltip_text = link.accessibility_name
	link.pressed.connect(func(): app.navigation_controller.open_entity(destination))
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	link.add_child(content)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.minimum_size_changed.connect(func():
		if is_instance_valid(link): link.custom_minimum_size.y = content.get_combined_minimum_size().y)
	return link

static func _nation_details(app: Control, team: Dictionary) -> Control:
	var page := G.v(8)
	page.name = "InternationalNationDetails"
	G.fill(page, true)
	page.set_meta("nation_id", str(team.id))
	var heading := G.h(12)
	page.add_child(heading)
	heading.add_child(nation_badge(team, 60))
	var title := G.label(str(team.name), 27, G.INK, true)
	title.name = "InternationalNationName"
	heading.add_child(title)
	var back := G.button("Toutes les sélections", func():
		app.management_ui.international.navigation_id = ""
		app._render(false))
	back.name = "InternationalNationDirectory"
	page.add_child(back)
	var list := G.scroll(page)
	var international: Dictionary = app.model.get("international", {})
	var names := _team_names(international)
	var nation_id := str(team.id)
	for callup: Dictionary in international.get("callups", []):
		if str(callup.get("nation", "")) != nation_id or callup.get("players", []).is_empty(): continue
		var camp := G.panel(list)
		camp.add_child(G.section("Convocations connues", _period(callup.get("from", ""), callup.get("through", ""))))
		for player: Dictionary in callup.get("players", []):
			var known := false
			for source: String in ["squad", "market"]:
				if app.model.get(source, []).any(func(person: Dictionary): return str(person.get("id", "")) == str(player.get("id", ""))): known = true
			var caption := "%s · %s" % [player.get("name", ""), player.get("pos", "")]
			if known:
				var player_id := str(player.id)
				var link := G.button(caption, func(): app.navigation_controller.open_entity({"kind":"player", "id":player_id}))
				link.accessibility_name = "Consulter la fiche · " + str(player.name)
				link.set_meta("entity_kind", "player")
				link.set_meta("entity_id", player_id)
				camp.add_child(link)
			else: camp.add_child(G.wrap(caption, 15, G.INK))
	var found := false
	for edition: Dictionary in international.get("editions", []):
		var fixtures: Array = edition.get("fixtures", []).filter(func(fixture: Dictionary):
			return fixture.get("homeId") == nation_id or fixture.get("awayId") == nation_id)
		if fixtures.is_empty(): continue
		found = true
		var card := G.panel(list)
		card.add_child(G.section(_edition_title(edition, _edition_year(edition))))
		for table: Dictionary in edition.get("tables", []):
			for standing: Dictionary in table.get("rows", []):
				if str(standing.get("teamId", "")) == nation_id:
					card.add_child(G.wrap("Classement · %s · %s J · %s pts" % [G.n(standing.get("rank")), G.n(standing.get("played")), G.n(standing.get("points"))], 15, G.INK))
		for fixture: Dictionary in fixtures:
			var line := G.h(8)
			card.add_child(line)
			line.add_child(G.label(P.fixture_date(fixture), 14, G.MUTED))
			for side: String in ["homeId", "awayId"]:
				var id := str(fixture.get(side, ""))
				var caption := str(names.get(id, id)) if not id.is_empty() else "À déterminer"
				if not team_by_id(app.model, id).is_empty(): line.add_child(_nation_link(app, id, caption))
				else: line.add_child(G.label(caption, 15, G.INK))
				if side == "homeId": line.add_child(G.label("–", 15, G.MUTED))
			var result: Variant = fixture.get("result")
			if result is Dictionary: line.add_child(G.label("%s – %s" % [G.n(result.get("home")), G.n(result.get("away"))], 15, G.INK))
	if not found: list.add_child(G.wrap("Aucune rencontre annoncée pour cette sélection."))
	return page

static func nation_badge(team: Dictionary, width: int) -> Control:
	var code := str(team.get("flagCode", "")).to_lower()
	var path := "res://art/flags/%s.svg" % code
	if not code.replace("-", "").is_valid_identifier() or not ResourceLoader.exists(path):
		return C.icon("flag", width, C.GOLD)
	var badge := TextureRect.new()
	badge.texture = load(path)
	badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	badge.custom_minimum_size = Vector2(width, width * .7)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return badge

static func current_fixture(model: Dictionary) -> Dictionary:
	var fixture: Variant = model.get("international", {}).get("currentManagedFixture")
	return fixture if fixture is Dictionary and fixture.has("id") and fixture.has("date") else {}

static func _editable_fixture(model: Dictionary) -> Dictionary:
	var current := current_fixture(model)
	if not current.is_empty(): return current
	var upcoming: Variant = model.get("international", {}).get("nextManagedFixture")
	return upcoming if upcoming is Dictionary and upcoming.has("id") else {}

static func play_current(app: Control) -> void:
	var fixture := current_fixture(app.model)
	if fixture.is_empty(): return
	var payload := {"fixtureId":fixture.id, "fromDate":fixture.date}
	var international: Dictionary = app.model.international
	var available := Sheet.slots(international)
	if not available.is_empty():
		var draft := Sheet.draft_for(app, international, fixture, available)
		payload.lineup = draft.slice(0, Sheet.XV.size())
		payload.reserves = draft.slice(Sheet.XV.size())
	app._command("national_play_match", payload)

static func calendar(app: Control) -> Control:
	var page := G.v(8)
	page.name = "InternationalCalendar"
	var international: Dictionary = app.model.get("international", {})
	var names := _team_names(international)
	var today := _today(app.model)
	var nation: String = international.get("nation", "")
	page.add_child(G.section("Calendrier de la sélection", str(names.get(nation, nation))))
	var current := current_fixture(app.model)
	var next: Dictionary = international.nextManagedFixture if international.get("nextManagedFixture") is Dictionary else {}
	if next.get("date", "") <= today: next = {}
	for edition: Dictionary in international.get("editions", []):
		for fixture: Dictionary in edition.get("fixtures", []):
			if fixture.get("homeId") != nation and fixture.get("awayId") != nation: continue
			var date: String = fixture.get("date", "")
			if current.is_empty() and date == today: current = fixture
			if date > today and fixture.get("result") == null and (next.is_empty() or date < next.get("date", "")):
				next = fixture
	var daily := G.panel(page)
	daily.add_child(G.section("Aujourd’hui", P.fixture_date({"date":today})))
	var daily_match := G.wrap("Aucun match aujourd’hui." if current.is_empty() else _fixture_row(current, names), 16, G.INK)
	daily_match.name = "InternationalTodayFixture"
	daily.add_child(daily_match)
	var upcoming := G.panel(page)
	upcoming.add_child(G.section("Prochain match"))
	var upcoming_match := G.wrap("Aucune prochaine rencontre annoncée." if next.is_empty() else _fixture_row(next, names), 16, G.INK)
	upcoming_match.name = "InternationalNextFixture"
	upcoming.add_child(upcoming_match)
	if not _editable_fixture(app.model).is_empty() and not Sheet.slots(international).is_empty():
		page.add_child(G.button("Préparer la feuille de match", func():
			app.management_ui.international_section = "sheet"
			app._navigate("Sélections"), true))
	elif not current_fixture(app.model).is_empty():
		_add_play_button(app, page, international, names)
	var competitions := G.button("Voir les compétitions", func():
		app.management_ui.international_section = "editions"
		app._navigate("Sélections"))
	competitions.name = "InternationalCalendarCompetitions"
	page.add_child(competitions)
	return page

static func _today(model: Dictionary) -> String:
	return str(model.get("meta", {}).get("calendarToday", model.get("calendarPlanning", {}).get("today", "")))

static func _team_names(international: Dictionary) -> Dictionary:
	var names := {}
	var extra: Variant = international.get("teamNames")
	if extra is Dictionary:
		for id: Variant in extra: names[id] = extra[id]
	for team: Dictionary in international.get("teams", []):
		names[team.id] = team.name
	return names

static func _fixture_name(fixture: Dictionary, names: Dictionary) -> String:
	var home: Variant = fixture.get("homeId")
	var away: Variant = fixture.get("awayId")
	var home_name: String = names.get(home, home) if home is String else "À déterminer"
	var away_name: String = names.get(away, away) if away is String else "À déterminer"
	return "%s – %s" % [home_name, away_name]

static func _fixture_row(fixture: Dictionary, names: Dictionary) -> String:
	var line := "%s · %s" % [P.fixture_date(fixture), _fixture_name(fixture, names)]
	var result: Variant = fixture.get("result")
	if result is Dictionary: line += " · %s – %s" % [G.n(result.home), G.n(result.away)]
	return line

static func _add_play_button(app: Control, parent: Control, international: Dictionary, names: Dictionary) -> void:
	var fixture := current_fixture(app.model)
	if not fixture.is_empty():
		var play := G.button("Jouer · " + _fixture_name(fixture, names), play_current.bind(app), true)
		play.name = "NationalPlayMatch"
		play.disabled = app.waiting
		parent.add_child(play)
	elif international.get("nextManagedFixture") is Dictionary:
		var next: Dictionary = international.nextManagedFixture
		parent.add_child(G.wrap("Prochain match · %s · %s" % [P.fixture_date(next), _fixture_name(next, names)]))

static func build(app: Control) -> Control:
	var target := team_by_id(app.model, str(app.management_ui.get("international", {}).get("navigation_id", "")))
	if not target.is_empty(): return _nation_details(app, target)
	var page := G.v(10)
	page.name = "InternationalSelections"
	G.fill(page, true)
	var international: Dictionary = app.model.get("international", {})
	var names := _team_names(international)
	var nation := str(international.get("nation", ""))
	var role: String = international.get("role", "club")
	page.add_child(_hero(names, role, nation))
	page.add_child(_key_figures(international))
	# Corps de page : les onglets à gauche, le calendrier international et l'annuaire des sélections à droite.
	var body := G.h(14)
	body.name = "InternationalBody"
	G.fill(body, true)
	page.add_child(body)
	var main := G.v(8)
	G.fill(main, true, 1.8)
	body.add_child(main)
	_add_play_button(app, main, international, names)
	var side := C.card("Le calendrier international")
	side.name = "InternationalUpcoming"
	C.fill(side, true)
	body.add_child(side)
	_upcoming(app, C.content(side), international, names)
	Visuel.annuaire(app, C.content(side), international)
	var tabs := TabContainer.new()
	tabs.name = "InternationalTabs"
	G.fill(tabs, true)
	main.add_child(tabs)
	# Onglets lisibles : même corps que les boutons de la page, jamais sous 14 px.
	tabs.add_theme_font_size_override("font_size", maxi(14, C.px(20)))
	tabs.add_child(_callups(app, international, names))
	tabs.add_child(_editions(app, international, names))
	tabs.add_child(Visuel.offres(app, international, role))
	var sections := ["callups", "editions", "offers"]
	sections.append("availability")
	tabs.add_child(Visuel.disponibilites(app))
	var fixture := _editable_fixture(app.model)
	var available := Sheet.slots(international)
	if not fixture.is_empty() and not available.is_empty():
		sections.append("sheet")
		tabs.add_child(Sheet.build(app, international, fixture, available))
	tabs.current_tab = maxi(0, sections.find(app.management_ui.get("international_section", "")))
	tabs.tab_changed.connect(func(index: int):
		app.management_ui.international_section = sections[index])
	return page

## En-tête de la page : photo de la banque, rôle du manager et ce que la page permet de suivre.
static func _hero(names: Dictionary, role: String, nation: String) -> Control:
	var card := C.card()
	card.name = "InternationalHero"
	var row := C.h(18)
	C.content(card).add_child(row)
	var picture := C.photo("mail-selection-nationale", Vector2(320, 120), true, .35)
	picture.name = "InternationalHeroPhoto"
	picture.tooltip_text = "Rassemblement international"
	row.add_child(picture)
	var words := C.v(4)
	C.fill(words)
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(words)
	var nation_name := str(names.get(nation, nation))
	var overline := "CLUB ET SÉLECTION · " + nation_name.to_upper() if role == "dual" else "SÉLECTION · " + nation_name.to_upper() if role == "nation" else "TA CARRIÈRE EN CLUB"
	words.add_child(C.label(overline, 19, C.GOLD, true, 700))
	var title := C.label("Tes internationaux" if role != "nation" else "Le groupe de " + nation_name, 44, C.IVORY, true, 800)
	title.name = "InternationalHeroTitle"
	words.add_child(title)
	return card

## Chiffres clés tirés de la projection internationale (aucun calcul sportif côté interface).
static func _key_figures(international: Dictionary) -> Control:
	var row := C.h(12)
	row.name = "InternationalKeyFigures"
	var availability: Dictionary = international.get("availability", {}) if international.get("availability") is Dictionary else {}
	var called := 0
	for callup: Dictionary in international.get("callups", []): called += callup.get("players", []).size()
	if availability.get("clubManaged", false): called = int(availability.get("absentCount", called))
	var next_return := Availability._date(availability.get("nextReturn")) if called > 0 else "Groupe au complet"
	var jobs: int = international.get("jobs", []).size()
	var figures := [
		["JOUEURS CONVOQUÉS", G.n(called), C.GOLD if called > 0 else C.MINT, "InternationalFigureCalled"],
		["PROCHAIN RETOUR AU CLUB", next_return, C.MINT, "InternationalFigureReturn"],
		["COMPÉTITIONS SUIVIES", G.n(international.get("editions", []).size()), C.IVORY, "InternationalFigureEditions"],
		["POSTES DE SÉLECTIONNEUR", G.n(jobs) if jobs > 0 else "Aucun ouvert", C.GOLD if jobs > 0 else C.MUTED, "InternationalFigureJobs"],
	]
	for figure: Array in figures:
		var card := C.card()
		card.name = figure[3]
		C.fill(card)
		row.add_child(card)
		var content := C.content(card)
		content.add_child(C.label(figure[0], 16, C.MUTED, true, 700))
		var value := C.label(figure[1], 30, figure[2], true, 700)
		value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		value.tooltip_text = str(figure[1])
		content.add_child(value)
	return row

## Les prochaines rencontres internationales (toutes sélections), les plus proches d'abord.
static func _upcoming(app: Control, parent: Control, international: Dictionary, names: Dictionary) -> void:
	var today := _today(app.model)
	var coming: Array = []
	for edition: Dictionary in international.get("editions", []):
		for fixture: Dictionary in edition.get("fixtures", []):
			var date := str(fixture.get("date", ""))
			if date.is_empty() or date < today or fixture.get("result") is Dictionary: continue
			coming.append({"fixture":fixture, "competition":_edition_title(edition, _edition_year(edition))})
	coming.sort_custom(func(a: Dictionary, b: Dictionary): return str(a.fixture.get("date", "")) < str(b.fixture.get("date", "")))
	if coming.is_empty():
		parent.add_child(PastillesClub.pastille("Aucune rencontre annoncée", PastillesClub.BLEU, "calendar", "", 20, "InternationalUpcomingNone"))
	for index in mini(4, coming.size()):
		var entry: Dictionary = coming[index]
		var line := C.v(1)
		line.name = "InternationalUpcoming_%d" % index
		parent.add_child(line)
		var rencontre := C.wrap(_fixture_row(entry.fixture, names), 19, C.IVORY, true, 600)
		var gras := FontVariation.new()
		gras.base_font = Charte.TEXTE
		gras.variation_embolden = .44
		rencontre.add_theme_font_override("font", gras)
		line.add_child(rencontre)
		var competition := C.wrap(str(entry.competition), 16, C.MUTED)
		competition.add_theme_font_override("font", Charte.TEXTE)
		line.add_child(competition)
	parent.add_child(C.rule())

static func _callups(app: Control, international: Dictionary, names: Dictionary) -> Control:
	var view := G.v()
	view.name = "Convocations"
	var squad: Array = app.model.get("squad", []) if app.model.get("squad") is Array else []
	for callup: Dictionary in international.get("callups", []):
		var list := G.panel(view)
		var caption := str(names.get(callup.nation, callup.nation))
		var heading := G.section(caption, _period(callup.from, callup.through))
		var title := heading.get_child(0) as Control
		heading.remove_child(title)
		var title_link := _projected_reading(app, title, {"kind":"nation", "id":str(callup.nation)}, "InternationalCallupNation_" + str(callup.nation).validate_node_name(), caption)
		heading.add_child(title_link)
		heading.move_child(title_link, 0)
		# Drapeau de la sélection devant son nom : la convocation se lit d'un coup d'œil.
		var top := G.h(12)
		list.add_child(top)
		top.add_child(nation_badge(team_by_id(app.model, str(callup.nation)), 46))
		G.fill(heading)
		top.add_child(heading)
		for player: Dictionary in callup.get("players", []):
			var identity := "%s · %s · %s ans" % [player.name, player.pos, G.n(player.age)]
			identity += " · Niveau " + G.rating_text(player)
			var row := G.h(10)
			list.add_child(row)
			var known: Dictionary = player
			for person: Variant in squad:
				if person is Dictionary and str(person.get("id", "")) == str(player.get("id", "")): known = person
			var face := G.portrait(posmod(str(player.get("id", player.name)).hash(), 32), 38, known)
			face.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(face)
			var reading := _projected_reading(app, G.wrap(identity, 15, G.INK), {"kind":"player", "id":str(player.get("id", ""))}, "InternationalCallupPlayer_" + str(player.get("id", "")).validate_node_name(), str(player.name))
			reading.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			G.fill(reading)
			row.add_child(reading)
	if view.get_child_count() == 0:
		# Aucune phrase : une pastille d'état (coche + deux mots), cliquable vers les disponibilités.
		view.add_child(PastillesClub.pastille("Groupe au complet", PastillesClub.VERT, "check", "Aucun joueur du club convoqué cette semaine", 22, "InternationalCallupsNone", Availability.open.bind(app)))
	return view

static func _edition_year(edition: Dictionary) -> int:
	var year := str(edition.get("year", "")).to_int()
	if year > 0: return year
	var suffix := str(edition.get("id", "")).right(4)
	if suffix.is_valid_int(): return suffix.to_int()
	var fixtures: Array = edition.get("fixtures", [])
	return str(fixtures[0].get("date", "")).left(4).to_int() if not fixtures.is_empty() else 0

static func _edition_title(edition: Dictionary, year: int) -> String:
	var title: String = edition.get("name", edition.get("id", "Édition"))
	return title + " · " + str(year) if year > 0 and not title.contains(str(year)) else title

static func host_mail_edition(model: Dictionary, event: Dictionary) -> Dictionary:
	var id := str(event.get("id", ""))
	if event.get("kind") != "international_host" or id.get_slice("/", 0) not in ["host", "host-guide"]: return {}
	var edition_id := id.substr(id.find("/") + 1)
	for edition: Dictionary in model.get("international", {}).get("editions", []):
		if edition.get("id") == edition_id and not _host_data(edition).is_empty(): return edition
	return {}

static func host_mail_caption(edition: Dictionary) -> String:
	var year := _edition_year(edition)
	return "Voir l’accueil %d" % year if year > 0 else "Voir l’accueil"

static func open_host(app: Control, edition: Dictionary) -> void:
	app.management_ui.international_editions = {"year":_edition_year(edition), "edition":edition.id, "mode":2}
	app.management_ui.international_section = "editions"
	app._navigate("Sélections")

static func _default_year(years: Array[int], today: String) -> int:
	var target := today.left(4).to_int()
	if target > 0:
		for year in years:
			if year >= target: return year
	return years.back()

static func _picker(parent: Node, id: String, caption: String, choices: Array, selected: int, action: Callable) -> void:
	parent.add_child(G.label(caption, 14, G.MUTED))
	var picker := OptionButton.new()
	picker.name = id
	picker.accessibility_name = caption
	for choice: Variant in choices: picker.add_item(str(choice))
	picker.select(selected)
	picker.item_selected.connect(action)
	parent.add_child(picker)

static func _refresh_editions(app: Control, id: String) -> void:
	app._render(false)
	var focus := app.find_child(id, true, false) as Control
	if focus != null: FocusLater.grab(focus)

static func _editions(app: Control, international: Dictionary, names: Dictionary) -> Control:
	var view := G.v()
	view.name = "Compétitions"
	var years: Array[int] = []
	var grouped := {}
	for edition: Dictionary in international.get("editions", []):
		var year := _edition_year(edition)
		if not grouped.has(year):
			grouped[year] = []
			years.append(year)
		grouped[year].append(edition)
	if years.is_empty():
		view.add_child(G.wrap("Aucune édition internationale disponible."))
		return view
	years.sort()
	var state: Dictionary = app.management_ui.get("international_editions", {})
	app.management_ui.international_editions = state
	var year: int = int(state.get("year", -1))
	if not year in years: year = _default_year(years, _today(app.model))
	var editions: Array = grouped[year]
	var ids := editions.map(func(edition: Dictionary): return edition.id)
	var index := maxi(0, ids.find(state.get("edition", "")))
	var current: Dictionary = editions[index]
	var controls := G.h(12)
	view.add_child(controls)
	var year_labels := years.map(func(value: int): return str(value) if value > 0 else "Sans année")
	_picker(controls, "InternationalEditionYear", "Année", year_labels, years.find(year), func(selected: int):
		state.merge({"year":years[selected], "edition":"", "page":0, "pool":0}, true)
		_refresh_editions(app, "InternationalEditionYear"))
	var titles := editions.map(func(edition: Dictionary): return _edition_title(edition, year))
	_picker(controls, "InternationalEdition", "Édition", titles, index, func(selected: int):
		state.merge({"edition":ids[selected], "page":0, "pool":0}, true)
		_refresh_editions(app, "InternationalEdition"))
	var host := _host_data(current)
	var modes := ["Classement", "Rencontres"]
	if not host.is_empty(): modes.append("Accueil")
	var mode := int(state.get("mode", 0))
	if mode < 0 or mode >= modes.size(): mode = 0
	_picker(controls, "InternationalEditionMode", "Vue", modes, mode, func(selected: int):
		state.mode = selected
		_refresh_editions(app, "InternationalEditionMode"))
	var list := G.panel(view)
	list.add_child(G.section(_edition_title(current, year)))
	match mode:
		0: _edition_standings(app, list, current.get("tables", []), names, state)
		1: _edition_fixtures(app, list, current.get("fixtures", []), names, state)
		2: _edition_host(list, host)
	return view

static func _host_data(edition: Dictionary) -> Dictionary:
	var host: Variant = edition.get("host")
	return host if host is Dictionary else {}

static func _host_text(data: Dictionary, key: String) -> String:
	var value: Variant = data.get(key)
	return value.strip_edges() if value is String else ""

static func _edition_host(parent: Control, host: Dictionary) -> void:
	var card := G.v(8)
	card.name = "InternationalHostDetails"
	parent.add_child(card)
	var countries: Variant = host.get("countries")
	var country_names := {}
	if countries is Array:
		for country: Dictionary in countries:
			var name := _host_text(country, "name")
			if name.is_empty(): continue
			country_names[country.get("id", name)] = name
			var capital := _host_text(country, "capital")
			card.add_child(G.section(name, "Capitale · " + capital if not capital.is_empty() else ""))
			var details: Variant = country.get("details")
			if details is Array:
				for detail: Variant in details:
					if detail is String and not detail.strip_edges().is_empty():
						card.add_child(G.wrap(detail, 15, G.INK))
	var final_country := _host_text(host, "finalCountry")
	var final_site: Array[String] = []
	for part: String in [_host_text(host, "stadium"), _host_text(host, "city"), str(country_names.get(final_country, final_country))]:
		if not part.is_empty(): final_site.append(part)
	if not final_site.is_empty():
		card.add_child(G.section("Finale", " · ".join(final_site)))
	for date_field: Array in [["opens", "Ouverture"], ["ends", "Clôture"], ["announcementDate", "Annonce"]]:
		var date := P.fixture_date({"date":_host_text(host, date_field[0])})
		if not date.is_empty(): card.add_child(G.wrap(date_field[1] + " · " + date, 15, G.INK))

static func _edition_standings(app: Control, list: Control, tables: Array, names: Dictionary, state: Dictionary) -> void:
	if tables.is_empty():
		list.add_child(G.wrap("Aucun classement pour cette édition."))
		return
	var pool := clampi(int(state.get("pool", 0)), 0, tables.size() - 1)
	if tables.size() > 1:
		var options := tables.map(func(table: Dictionary): return "Poule " + str(table.pool) if table.get("pool") != null else "Classement")
		var controls := G.h()
		list.add_child(controls)
		_picker(controls, "InternationalEditionPool", "Poule", options, pool, func(selected: int):
			state.pool = selected
			_refresh_editions(app, "InternationalEditionPool"))
	for row: Dictionary in tables[pool].get("rows", []):
		var team: String = row.get("teamId", "")
		var caption := "%s. %s · %s J · %s pts" % [G.n(row.rank), names.get(team, team), G.n(row.played), G.n(row.points)]
		list.add_child(_projected_reading(app, G.wrap(caption, 15, G.INK), {"kind":"nation", "id":team}, "InternationalStandingNation_" + team.validate_node_name(), str(names.get(team, team))))

static func _edition_fixtures(app: Control, list: Control, fixtures: Array, names: Dictionary, state: Dictionary) -> void:
	if fixtures.is_empty():
		list.add_child(G.wrap("Aucune rencontre pour cette édition."))
		return
	var pages := ceili(float(fixtures.size()) / FIXTURES_PER_PAGE)
	var page := clampi(int(state.get("page", 0)), 0, pages - 1)
	var start := page * FIXTURES_PER_PAGE
	for index in range(start, mini(start + FIXTURES_PER_PAGE, fixtures.size())):
		var fixture := G.wrap(_fixture_row(fixtures[index], names), 15, G.INK)
		fixture.name = "InternationalFixture_" + str(index)
		list.add_child(fixture)
	if pages <= 1: return
	var controls := G.h()
	list.add_child(controls)
	var previous := G.button("← Précédent", func():
		state.page = page - 1
		_refresh_editions(app, "InternationalFixturePrevious"))
	previous.name = "InternationalFixturePrevious"
	previous.disabled = page == 0
	controls.add_child(previous)
	controls.add_child(G.label("%d / %d" % [page + 1, pages], 14, G.MUTED))
	var next := G.button("Suivant →", func():
		state.page = page + 1
		_refresh_editions(app, "InternationalFixtureNext"))
	next.name = "InternationalFixtureNext"
	next.disabled = page + 1 == pages
	controls.add_child(next)

static func _take(app: Control, nation: String, name: String, role: String) -> void:
	var detail := "Tu continueras à diriger ton club et prendras en charge cette sélection." if role == "dual" else "Ta carrière se poursuivra à la tête de cette sélection."
	app.confirm("Prendre en charge " + name, detail,
		func(): app._command("national_take_job", {"nation":nation, "role":role, "confirmed":true}))

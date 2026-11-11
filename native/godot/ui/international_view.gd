extends RefCounted

const G = preload("res://ui/game_skin.gd")
const C = preload("res://ui/immersive08/components.gd")
const P = preload("res://ui/immersive08/projection.gd")
const Sheet = preload("res://ui/national_sheet.gd")
const Availability = preload("res://ui/international_availability.gd")
const FIXTURES_PER_PAGE := 10

static func nation_only(model: Dictionary) -> bool:
	return model.get("international", {}).get("role") == "nation"

static func navigation_allowed(model: Dictionary, route: String) -> bool:
	return not nation_only(model) or route in ["Accueil", "Création", "Packs", "Réception", "Sélections", "Calendrier"]

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
		camp.add_child(G.section("Convocations connues", "%s au %s" % [callup.get("from", ""), callup.get("through", "")]))
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
	var page := G.v(8)
	page.name = "InternationalSelections"
	var international: Dictionary = app.model.get("international", {})
	var names := _team_names(international)
	var nation := str(international.get("nation", ""))
	var role: String = international.get("role", "club")
	if role in ["dual", "nation"]:
		var status := "Club et sélection" if role == "dual" else "Sélection uniquement"
		page.add_child(G.section("%s · %s" % [status, names.get(nation, nation)]))
	else:
		page.add_child(G.section("Votre carrière en club", "Suivez les convocations et les postes disponibles."))
	var directory := HFlowContainer.new()
	directory.name = "InternationalNationLinks"
	page.add_child(directory)
	for team: Dictionary in international.get("teams", []):
		directory.add_child(_nation_link(app, str(team.id), str(team.name)))
	_add_play_button(app, page, international, names)
	var tabs := TabContainer.new()
	tabs.name = "InternationalTabs"
	page.add_child(tabs)
	tabs.add_child(_callups(international, names))
	tabs.add_child(_editions(app, international, names))
	tabs.add_child(_offers(app, international, role))
	var sections := ["callups", "editions", "offers"]
	sections.append("availability")
	tabs.add_child(Availability.build(app))
	var fixture := _editable_fixture(app.model)
	var available := Sheet.slots(international)
	if not fixture.is_empty() and not available.is_empty():
		sections.append("sheet")
		tabs.add_child(Sheet.build(app, international, fixture, available))
	tabs.current_tab = maxi(0, sections.find(app.management_ui.get("international_section", "")))
	tabs.tab_changed.connect(func(index: int):
		app.management_ui.international_section = sections[index])
	return page

static func _callups(international: Dictionary, names: Dictionary) -> Control:
	var view := G.v()
	view.name = "Convocations"
	for callup: Dictionary in international.get("callups", []):
		var list := G.panel(view)
		list.add_child(G.section(str(names.get(callup.nation, callup.nation)),
			"%s au %s" % [callup.from, callup.through]))
		for player: Dictionary in callup.get("players", []):
			var identity := "%s · %s · %s ans" % [player.name, player.pos, G.n(player.age)]
			identity += " · Niveau " + G.rating_text(player)
			list.add_child(G.wrap(identity, 15, G.INK))
	if view.get_child_count() == 0: view.add_child(G.wrap("Aucune convocation enregistrée."))
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
	if focus != null: focus.grab_focus.call_deferred()

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
		list.add_child(G.wrap("%s. %s · %s J · %s pts" % [
			G.n(row.rank), names.get(team, team), G.n(row.played), G.n(row.points)], 15, G.INK))

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

static func _offers(app: Control, international: Dictionary, role: String) -> Control:
	var view := G.v()
	view.name = "Offres"
	var jobs: Array = international.get("jobs", []).duplicate()
	var requested: String = app.management_ui.get("international_nation", "")
	for index in jobs.size():
		if jobs[index].nation == requested:
			jobs.push_front(jobs.pop_at(index))
			break
	for job: Dictionary in jobs:
		var card := G.panel(view)
		var nation: String = job.nation
		var name: String = job.get("name", nation)
		card.add_child(G.section(name))
		if role != "nation":
			var dual := G.button("Conserver le club et prendre la sélection", _take.bind(app, nation, name, "dual"))
			dual.name = "NationalJobDual_" + nation
			card.add_child(dual)
		var only := G.button("Prendre la sélection seule", _take.bind(app, nation, name, "nation"))
		only.name = "NationalJobOnly_" + nation
		card.add_child(only)
	if view.get_child_count() == 0: view.add_child(G.wrap("Aucun poste de sélectionneur disponible."))
	if role == "dual":
		var current := managed_team(app.model)
		if not current.is_empty():
			var full_time := G.button("Se consacrer à cette sélection", _take.bind(app, current.id, current.name, "nation"))
			full_time.name = "NationalJobCurrentOnly"
			view.add_child(full_time)
		view.add_child(G.button("Quitter la sélection", func():
			app.confirm("Quitter la sélection", "Votre carrière en club continue.",
				func(): app._command("national_leave_job", {"confirmed":true}))))
	return view

static func _take(app: Control, nation: String, name: String, role: String) -> void:
	var detail := "Vous continuerez à diriger votre club et prendrez en charge cette sélection." if role == "dual" else "Votre carrière se poursuivra à la tête de cette sélection."
	app.confirm("Prendre en charge " + name, detail,
		func(): app._command("national_take_job", {"nation":nation, "role":role, "confirmed":true}))

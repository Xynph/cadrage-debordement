extends RefCounted

const G = preload("res://ui/game_skin.gd")
const C = preload("res://ui/immersive08/components.gd")
const P = preload("res://ui/immersive08/projection.gd")
const Sheet = preload("res://ui/national_sheet.gd")

static func nation_only(model: Dictionary) -> bool:
	return model.get("international", {}).get("role") == "nation"

static func navigation_allowed(model: Dictionary, route: String) -> bool:
	return not nation_only(model) or route in ["Accueil", "Création", "Packs", "Réception", "Sélections", "Calendrier"]

static func managed_team(model: Dictionary) -> Dictionary:
	var international: Dictionary = model.get("international", {})
	for team: Dictionary in international.get("teams", []):
		if team.id == international.get("nation"): return team
	return {}

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
	var today := str(app.model.get("meta", {}).get("calendarToday", ""))
	var nation: String = international.get("nation", "")
	page.add_child(G.section("Calendrier de la sélection", str(names.get(nation, nation))))
	var total := 0
	for edition: Dictionary in international.get("editions", []):
		var fixtures: Array = edition.get("fixtures", [])
		var managed := fixtures.filter(func(fixture: Dictionary):
			return fixture.get("homeId") == nation or fixture.get("awayId") == nation)
		if managed.is_empty(): continue
		total += managed.size()
		var section := G.panel(page)
		section.add_child(G.section(str(edition.get("name", ""))))
		for fixture: Dictionary in managed:
			var date := str(fixture.get("date", ""))
			section.add_child(G.wrap(_fixture_row(fixture, names), 16, G.GOOD if date == today else G.INK))
	if total == 0: page.add_child(G.wrap("Aucune rencontre programmée pour cette sélection."))
	if not _editable_fixture(app.model).is_empty() and not Sheet.slots(international).is_empty():
		page.add_child(G.button("Préparer la feuille de match", func():
			app.management_ui.international_section = "sheet"
			app._navigate("Sélections"), true))
	else:
		_add_play_button(app, page, international, names)
	return page

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
	_add_play_button(app, page, international, names)
	var tabs := TabContainer.new()
	tabs.name = "InternationalTabs"
	page.add_child(tabs)
	tabs.add_child(_callups(international, names))
	tabs.add_child(_editions(international, names))
	tabs.add_child(_offers(app, international, role))
	var sections := ["callups", "editions", "offers"]
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
			if player.get("note") != null: identity += " · Note " + G.n(player.note)
			list.add_child(G.wrap(identity, 15, G.INK))
	if view.get_child_count() == 0: view.add_child(G.wrap("Aucune convocation enregistrée."))
	return view

static func _editions(international: Dictionary, names: Dictionary) -> Control:
	var view := G.v()
	view.name = "Compétitions"
	for edition: Dictionary in international.get("editions", []):
		var list := G.panel(view)
		list.add_child(G.section(str(edition.get("name", ""))))
		for table: Dictionary in edition.get("tables", []):
			var pool: String = table.pool if table.get("pool") is String else ""
			list.add_child(G.label("Classement" if pool.is_empty() else "Poule " + pool, 16, G.GOLD, true))
			for row: Dictionary in table.get("rows", []):
				var team: String = row.get("teamId", "")
				list.add_child(G.wrap("%s. %s · %s J · %s pts" % [
					G.n(row.rank), names.get(team, team), G.n(row.played), G.n(row.points)], 14, G.INK))
		for fixture: Dictionary in edition.get("fixtures", []):
			list.add_child(G.wrap(_fixture_row(fixture, names), 14, G.INK))
	if view.get_child_count() == 0: view.add_child(G.wrap("Aucune édition internationale disponible."))
	return view

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

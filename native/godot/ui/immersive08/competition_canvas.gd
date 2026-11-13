extends Control
## Classements, phases finales, calendrier et résultats de la carrière native.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const G = preload("res://ui/game_skin.gd")
const P = preload("res://ui/immersive08/projection.gd")
const S = preload("res://ui/data_semantics.gd")
const Club = preload("res://ui/club_views.gd")
const Office = preload("res://ui/immersive08/office.gd")
const Decisions = preload("res://ui/decision_views.gd")
const U = preload("res://ui/immersive08/club_ui.gd")
const World = preload("res://ui/immersive08/world_archive.gd")
const Link = preload("res://ui/entity_link.gd")
const SeasonPreparation = preload("res://ui/immersive08/season_preparation.gd")
const WIDTH := 2248
const LEFT := 1310
const RIGHT := 922
const WARM := Color("efc665")
const WIN := Color("54de81")
const DRAW := Color("a9b2b0")
const LOSS := Color("ef8477")
const PRIMARY := Color("106d43")
const LABELS := {"league": "Championnat", "pool":"Poules", "barrage": "Barrage", "elimination": "Match de barrage", "r16":"Huitième de finale", "quarter":"Quart de finale", "semi": "Demi-finale", "final": "Finale", "access": "Barrage d’accession", "cup": "Coupe", "ended":"Compétition terminée"}
const JAPAN_COMPETITIONS := ["jlo-d1", "jlo-d2", "jlo-d1-d2"]
const RESULT_TINTS := {"V": WIN, "N": DRAW, "D": LOSS}
const TABLE_COLUMNS := [
	["#", 41, 58, "rank"], ["J", 488, 52, "played"], ["V", 549, 50, "won"],
	["N", 610, 50, "drawn"], ["D", 671, 50, "lost"], ["PF", 744, 59, "pf"],
	["PC", 817, 59, "pa"], ["DIFF.", 893, 71, "difference"], ["BONUS", 979, 70, "bonus"],
	["PTS", 1061, 65, "points"]
]

var app: Control
var state: Dictionary
var league: Dictionary
var leagues: Array
var own: Dictionary
var mode := "league"
var identities := {}
var fixtures: Array
var next_fixture: Dictionary
var season_results: Array
var international := false

# Lookup only published view-model data. Missing or ambiguous identifiers never
# fall back to the currently managed club or the next match.
static func target_available(owner_app: Control, kind: String, id: Variant) -> bool:
	match kind:
		"club": return not _target_club(owner_app, str(id)).is_empty()
		"fixture": return not _target_fixture(owner_app, str(id)).is_empty()
		"competition": return owner_app.model.get("leagues", []).any(func(item: Dictionary): return str(item.get("id", "")) == str(id))
		"session": return not _target_session(owner_app, id).is_empty()
		"date": return preload("res://ui/immersive08/calendar_agenda.gd").valid_date(id)
	return false

static func _target_session(owner_app: Control, id: Variant) -> Dictionary:
	if not id is String or id.is_empty(): return {}
	var planning: Variant = owner_app.model.get("calendarPlanning", {})
	if not planning is Dictionary: return {}
	var source: Variant = planning.get("sessions", [])
	if not source is Array: return {}
	var selected: Dictionary = {}
	for item: Variant in source:
		if not item is Dictionary or item.get("id") != id: continue
		if not selected.is_empty(): return {}
		selected = item
	if selected.is_empty() or not preload("res://ui/immersive08/calendar_agenda.gd").valid_date(selected.get("date")): return {}
	return selected

static func session_focus_name(id: String) -> String:
	return "CalendarSessionDetail_" + id.sha256_text()

static func session_context_matches(owner_app: Control, id: Variant) -> bool:
	var session := _target_session(owner_app, id)
	if session.is_empty() or owner_app.route != "Calendrier" or owner_app.get_meta("calendar_table", false): return false
	var reading: Dictionary = owner_app.management_ui.get("calendar_reading", {})
	if reading.get("selected_session", "") != id or reading.get("selected", "") != session.date or reading.get("filter", "all") not in ["all", "training"]: return false
	var program := owner_app.find_child("CarnetCalendar", true, false) as Control
	if program == null or not program.is_visible_in_tree(): return false
	var focus := program.find_child(session_focus_name(id), true, false) as Button
	return focus != null and focus.is_visible_in_tree() and focus.get_meta("entity_kind", "") == "session" and focus.get_meta("entity_id", "") == id

static func _target_club(owner_app: Control, id: String) -> Dictionary:
	if id.is_empty(): return {}
	var own_value: Variant = owner_app.model.get("club")
	var own_club: Dictionary = own_value if own_value is Dictionary else {}
	for division: Dictionary in owner_app.model.get("leagues", []):
		for club: Dictionary in division.get("rows", []):
			if str(club.get("id", "")) == id: return club
	if str(own_club.get("id", "")) == id: return own_club
	for club: Dictionary in owner_app.catalogue:
		if str(club.get("id", "")) == id: return club
	return {}

static func _target_fixture(owner_app: Control, id: String) -> Dictionary:
	if id.is_empty(): return {}
	var candidates: Array[Dictionary] = []
	for source: Array in [owner_app.model.get("calendar", []), owner_app.model.get("calendarPlanning", {}).get("fixtures", [])]:
		for fixture: Dictionary in source:
			if str(fixture.get("id", "")) == id: candidates.append(fixture)
	var next: Variant = owner_app.model.get("next")
	if next is Dictionary and str(next.get("id", "")) == id: candidates.append(next)
	for result: Dictionary in owner_app.model.get("history", []):
		if str(result.get("fixtureId", "")) != id: continue
		var pair: Array = result.get("pair", [])
		if pair.size() != 2: continue
		var fixture := result.duplicate(true)
		fixture.id = result.fixtureId
		fixture.home = _target_club(owner_app, str(pair[0]))
		fixture.away = _target_club(owner_app, str(pair[1]))
		if fixture.home.is_empty() or fixture.away.is_empty(): continue
		fixture.played = true
		candidates.append(fixture)
	if candidates.is_empty(): return {}
	var selected: Dictionary = candidates[0]
	for fixture: Dictionary in candidates.slice(1):
		if fixture.get("home", {}).get("id") != selected.get("home", {}).get("id") or fixture.get("away", {}).get("id") != selected.get("away", {}).get("id"): return {}
		if fixture.has("date") and selected.has("date") and fixture.date != selected.date: return {}
		if fixture.get("played", false) and not selected.get("played", false): selected = fixture
	return selected

static func open_target(owner_app: Control, kind: String, id: Variant) -> bool:
	if not target_available(owner_app, kind, id): return false
	if kind == "competition":
		owner_app.table_division = str(id)
		if not owner_app.management_ui.get("competition") is Dictionary: owner_app.management_ui.competition = {}
		owner_app.management_ui.competition.tab = "league"
		owner_app.management_ui.competition.club_league = str(owner_app.model.get("meta", {}).get("leagueId", ""))
		owner_app._navigate("Classements", false)
		return true
	if kind in ["date", "session"]:
		var reading: Dictionary = owner_app.management_ui.get("calendar_reading", {}).duplicate(true)
		reading.erase("selected_session")
		if kind == "session":
			var session := _target_session(owner_app, id)
			reading.selected = session.date
			reading.filter = "all"
			reading.selected_session = id
			owner_app.set_meta("calendar_table", false)
		else: reading.selected = str(id)
		reading.today = str(owner_app.model.get("calendarPlanning", {}).get("today", owner_app.model.get("meta", {}).get("date", "")))
		reading.focus = session_focus_name(id) if kind == "session" else "MonthDay_" + str(id)
		owner_app.management_ui.calendar_reading = reading
		owner_app._navigate("Calendrier", false)
		return true
	var dialog_name := "CompetitionClubDetails" if kind == "club" else "CompetitionFixtureDetails"
	# Reading history can retain hidden dialogs of the same kind. Only a visible
	# reader blocks a new one; names may be renamed by Godot after suspension.
	for child: Node in owner_app.get_children():
		if child is Window and not child.is_queued_for_deletion() and child.visible and (str(child.name) == dialog_name or child.get_meta("entity_kind", "") == kind): return false
	var context: Control = load("res://ui/immersive08/competition_canvas.gd").new()
	context.app = owner_app
	context.name = "CompetitionReadingContext"
	context.mouse_filter = Control.MOUSE_FILTER_IGNORE
	owner_app.add_child(context)
	context._context(true)
	if kind == "club": context._club_detail(_target_club(owner_app, str(id)))
	else: context._fixture_detail(_target_fixture(owner_app, str(id)))
	var dialog := context.get_meta("reading_dialog", null) as Window
	if not is_instance_valid(dialog) or dialog.is_queued_for_deletion():
		context.queue_free()
		return false
	dialog.set_meta("entity_kind", kind)
	dialog.set_meta("entity_id", str(id))
	dialog.tree_exited.connect(context.queue_free)
	return true

static func build(owner_app: Control, canvas: Control) -> void:
	var page: Control = load("res://ui/immersive08/competition_canvas.gd").new()
	page.app = owner_app
	canvas.add_child(page)
	D.place(page, Rect2(0, 0, WIDTH, 1240))
	page._build()

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
	_header()
	match mode:
		"calendar": _calendar()
		"playoffs": _playoffs()
		"stats": _stats()
		_: _standings()
	_next_match()
	_calendar_preview()
	_bottom()

func _header() -> void:
	var scenery := Control.new()
	scenery.clip_contents = true
	add_child(scenery)
	D.place(scenery, Rect2(1066, 0, 1182, 253))
	var ground := P.fixture_ground({"leagueId":league.id},"stadium")
	D.photo(scenery, ground, Rect2(0, 0, 784, 253),.5 if ground!="stadium" else 0.0)
	var trophy := D.photo(scenery, "trophy", Rect2(475, 0, 707, 253))
	var blend := Shader.new()
	blend.code = "shader_type canvas_item; void fragment() { vec4 art = texture(TEXTURE, UV); COLOR = vec4(art.rgb, art.a * smoothstep(0.0, 0.23, UV.x)); }"
	var material := ShaderMaterial.new()
	material.shader = blend
	trophy.material = material
	_fade(scenery, Rect2(0, 0, 715, 253))
	D.text(self, 24, 47, "CHAQUE POINT COMPTE", 31, WARM, 700, 295)
	D.line(self, Vector2(329, 34), Vector2(466, 34), WARM, 2)
	var title := "Le fil de la saison." if mode == "calendar" else "La course au classement."
	D.text(self, 21, 116, title, 77, C.IVORY, 800, 1240)
	var round_label := str(app.model.meta.get("roundLabel", "")) if league.id == state.club_league else "Phase régulière" if league.get("phase", "league") == "league" else _phase(league)
	var short_round := round_label.trim_prefix(str(league.get("name","")) + " · ")
	var subhead := "%s   ·   SAISON %s   ·   %s" % [_league_short(league).to_upper(), G.season_label(app.model.meta.get("season", "—")), short_round.to_upper()]
	D.rect(self, Rect2(24, 132, 735, 43), Color("142122"), 5, C.LINE)
	D.text(self, 44, 161, subhead, 25, C.IVORY, 600, 691)
	var crest := D.rect(self, Rect2(1122, 103, 218, 78), Color("111a1b"), 8, WARM)
	var emblem := G._pack_texture(str(league.get("logoPath", "")))
	if emblem == null:
		_icon(self, "trophy", Rect2(1188, 18, 87, 87), WARM)
	else:
		var logo := TextureRect.new()
		logo.name = "CompetitionOfficialLogo"
		logo.texture = emblem
		logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		logo.accessibility_name = str(league.get("name", "Championnat"))
		add_child(logo)
		D.place(logo, Rect2(1122, 12, 218, 83))
	D.text(crest, 109, 33, "COUPE D’EUROPE" if league.has("pools") else "CHAMPIONNAT", 26, C.IVORY, 800, 208, HORIZONTAL_ALIGNMENT_CENTER)
	D.text(crest, 109, 63, _league_short(league).to_upper(), 24, C.IVORY, 700, 206, HORIZONTAL_ALIGNMENT_CENTER)
	for spec: Array in [
		[0, 302, "Championnat", "league", "", "Section_Classements"], [307, 247, "Phases finales", "playoffs", "trophy", "CompetitionPlayoffs"],
		[559, 290, "Calendrier", "calendar", "calendar", "Section_Calendrier"], [854, 308, "Statistiques", "stats", "flag", "CompetitionStats"]
	]:
		var tab := D.button(self, Rect2(spec[0], 194, spec[1], 61), spec[2], func(): _switch(str(spec[3])), mode == spec[3], spec[4], false, app.accent, spec[5])
		tab.alignment = HORIZONTAL_ALIGNMENT_CENTER
		tab.add_theme_font_size_override("font_size", maxi(12, C.px(31)))
		tab.add_theme_stylebox_override("normal", _tab_style(int(spec[1]), mode == spec[3], app.accent))
	D.button(self, Rect2(1383, 203, 179, 45), "Rivalités", func(): app._navigate("Rivalités"), false, "shield", true, app.accent, "Section_Rivalités")
	D.button(self, Rect2(1578, 203, 264, 45), "Archives des saisons", func(): Club.season_archives(app), false, "save", true, app.accent, "OpenArchives")
	D.line(self, Vector2(0, 254), Vector2(WIDTH, 254), Color(WARM, .55))

func _switch(tab_id: String) -> void:
	if tab_id == "calendar":
		app._navigate("Calendrier")
	else:
		state.tab = tab_id
		if app.route == "Classements": app._render(false)
		else: app._navigate("Classements")

func _standings() -> void:
	var panel := _panel(self, Rect2(0, 270, LEFT, 728), "CLASSEMENT – " + _league_short(league).to_upper(), "", "StandingsTableFrame")
	var rows: Array = league.get("rows", [])
	var table_y := 50
	var page_key := "standings_" + str(league.id)
	if international:
		_division_choices(panel, 12, 57)
		table_y = 103
		var pools: Array = league.get("pools",[])
		if not pools.is_empty():
			var pool := _select_pool(panel,pools)
			rows = pool.get("rows",[])
			page_key += "_poule_" + G.n(pool.id)
			table_y = 149
	_result_legend(panel, 784, 13)
	var table_header := D.rect(panel, Rect2(1, table_y, LEFT - 2, 44), Color("131e20"), 4)
	D.text(table_header, 117, 29, "CLUB", 23, C.IVORY, 600, 315)
	for column: Array in TABLE_COLUMNS: D.text(table_header, column[1], 30, column[0], 23, C.IVORY, 600, column[2], HORIZONTAL_ALIGNMENT_CENTER)
	D.text(table_header, 1200, 30, "FORME", 23, C.IVORY, 600, 196, HORIZONTAL_ALIGNMENT_CENTER)
	var body := Control.new()
	body.name = "StandingsRows"
	panel.add_child(body)
	var body_y := table_y + 44
	D.place(body, Rect2(1, body_y, LEFT - 2, 683-body_y))
	var stride := 41 if rows.size() <= 14 else 33 if international else 36
	var capacity := maxi(1,mini(16,floori(float(683-body_y)/stride))) if international else 16
	var bounds := _pager(panel, "StandingsPagination", page_key, rows.size(), capacity, 685, 832)
	for i in range(bounds.x, bounds.y):
		_standings_row(body, rows[i], i - bounds.x, stride)
	if rows.is_empty(): D.text(body, 25, 65, "Aucun classement renseigné pour cette division.", 29, C.MUTED, 500, LEFT - 50)
	if not international: _division_choices(panel, 12, 686)
	if league.get("champion") is Dictionary:
		var name_text := "Champion : " + G.club_name(league.champion)
		if league.get("finalist") is Dictionary: name_text += "   ·   Finaliste : " + G.club_name(league.finalist)
		D.text(panel, 23 if international else 792, 711, name_text, 21, WARM, 600, 785 if international else 400, HORIZONTAL_ALIGNMENT_LEFT if international else HORIZONTAL_ALIGNMENT_RIGHT)
	elif not international and rows.size() <= capacity:
		var label := "Vert : 1–6, phase finale" if rows.size() >= 6 else ""
		if league.id == "elite" and rows.size() == 14 and str(app.model.meta.get("mode")) != "fictional14":
			label += "   ·   Or : 13, barrage d’accession   ·   Rouge : 14, descente"
		D.text(panel, 1288, 711, label, 19, C.MUTED, 500, 740, HORIZONTAL_ALIGNMENT_RIGHT)

func _select_pool(panel: Panel, pools: Array) -> Dictionary:
	var key := "standings_pool_" + str(league.id)
	var own_pool := pools.find_custom(func(pool: Dictionary):
		return pool.get("rows",[]).any(func(club: Dictionary): return club.id == own.id))
	var selected := clampi(int(app.management_ui.get(key,maxi(0,own_pool))),0,pools.size()-1)
	D.text(panel, 19, 132, "PHASE DE POULES", 22, C.GOLD, 700, 250)
	var choice := OptionButton.new()
	choice.name = "StandingsPoolChoice"
	choice.add_theme_font_override("font",C.BOLD)
	choice.add_theme_font_size_override("font_size",maxi(12,C.px(23)))
	for pool: Dictionary in pools: choice.add_item(str(pool.get("label","Poule")))
	choice.select(selected)
	choice.item_selected.connect(func(index: int):
		app.management_ui[key] = index
		var owner_app := app
		owner_app._render(false)
		U.focus(owner_app,"StandingsPoolChoice"))
	panel.add_child(choice)
	D.place(choice, Rect2(210,102,265,39))
	return pools[selected]

func _standings_row(parent: Node, club: Dictionary, index: int, stride: int) -> void:
	var mine: bool = club.id == own.id
	var rank := int(club.get("rank", 0)) if P.standings_open(club) else 0
	var france: bool = str(app.model.meta.get("mode")) in ["common", "france30"]
	var zone := Color.TRANSPARENT
	# Les tableaux Monde exposent leurs rangs sans déduire des qualifications de coupe.
	if not international:
		zone = WIN if rank > 0 and rank <= 6 else WARM if france and league.id == "elite" and rank == 13 else LOSS if france and league.id == "elite" and rank == 14 else Color.TRANSPARENT
	var base := Color("111c1e") if index % 2 == 0 else Color("0e1719")
	var fill := Color("0e5234") if mine else base.lerp(zone, .12) if zone.a > 0 else base
	var row := Button.new()
	row.name = "StandingsRow_" + str(club.id)
	row.set_meta("club_id", club.id)
	row.accessibility_name = G.club_name(club) + (" · " + S.count_text(club.get("rank")) + " au classement" if P.standings_open(club) else " · pas encore classé")
	row.add_theme_stylebox_override("normal", C.box(fill, Color.TRANSPARENT, 1, 0))
	row.add_theme_stylebox_override("hover", C.box(Color("234538"), WIN, 3, 0))
	row.add_theme_stylebox_override("focus", C.box(Color.TRANSPARENT, WARM, 3, 0))
	Link.bind(row, app, {"kind":"club", "id":str(club.id)}, "Ouvrir le club · " + G.club_name(club))
	parent.add_child(row)
	D.place(row, Rect2(0, index * stride, LEFT - 2, stride))
	if zone.a > 0: D.rect(row, Rect2(4, 1, 4, stride - 2), zone)
	D.line(row, Vector2(9, stride - 1), Vector2(LEFT - 12, stride - 1), Color(C.LINE, .70))
	var emblem := mini(34,stride-3)
	_crest(row, club, Rect2(87, (stride - emblem) / 2.0, emblem, emblem))
	var baseline := stride / 2.0 + 9
	D.text(row, 140, baseline, G.club_name(club), 27, C.IVORY, 700 if mine else 500, 315)
	for column: Array in TABLE_COLUMNS:
		var key: String = column[3]
		var value := _standing_text(club, key)
		var tint: Color = RESULT_TINTS.get(column[0], C.IVORY) if value != "—" else C.MUTED
		var caption := D.text(row, column[1], baseline, value, 27 if key in ["rank", "points"] else 25, tint, 700 if mine or key in ["rank", "points"] else 500, column[2], HORIZONTAL_ALIGNMENT_CENTER)
		if key in ["won", "drawn", "lost"]:
			caption.name = "StandingCount_" + key
			caption.set_meta("outcome_code", column[0])
	_recent_form(row, club.get("form"), 1096, (stride - 30) / 2.0)

func _standing_text(club: Dictionary, key: String) -> String:
	if key == "difference":
		var difference := S.difference_text(club.get("pf"), club.get("pa"))
		return "+" + difference if difference != "—" and int(difference) > 0 else difference
	if key == "rank" and not P.standings_open(club): return "–"
	if key == "points": return S.number_text(club.get(key))
	return S.count_text(club.get(key))

func _next_match() -> void:
	var panel := _panel(self, Rect2(LEFT + 16, 270, RIGHT, 334), "PROCHAIN RENDEZ-VOUS", "", "CompetitionNextFixture")
	var banner := Control.new()
	banner.clip_contents = true
	panel.add_child(banner)
	D.place(banner, Rect2(4, 50, RIGHT - 8, 280))
	var japan := SeasonPreparation.is_japan(app.model.meta)
	var ground := P.fixture_ground(app.model.meta,"stadium")
	D.photo(banner, ground, Rect2(218, 0, RIGHT - 226, 280),.51 if ground!="stadium" else 0.0)
	_fade(banner, Rect2(215, 0, RIGHT - 241, 280))
	if next_fixture.is_empty():
		var upcoming := P.next_nationale_fixture(app.model)
		if not upcoming.is_empty():
			D.chip(panel,Rect2(36,67,250,29),"SEMAINE EXEMPTE",C.GOLD)
			D.text(panel,36,130,Office.scheduled_opponent(app,upcoming),43,C.IVORY,800,810).name = "UpcomingOpponent"
			D.text(panel,37,179,Office.scheduled_when(app,upcoming),29,C.IVORY,600,802).name = "UpcomingWhen"
			var venue := Office.scheduled_venue(app,upcoming)
			if not venue.is_empty(): D.text(panel,37,219,"Lieu · " + venue,24,C.MUTED,500,802)
			D.button(panel,Rect2(166,247,589,60),app.primary_text().trim_suffix("  →"),app.primary_action,true,"arrow",false,PRIMARY,"CompetitionAdvanceWeek")
			return
		var preparation := SeasonPreparation.data(app.model.meta)
		if not preparation.is_empty():
			if SeasonPreparation.is_champ(app.model.meta):
				var fixture := P.next_scheduled_fixture(app.model)
				if fixture.is_empty():
					D.text(panel,36,130,"Préparation · " + World.name_for(app.model,"champ"),43,C.IVORY,800,810)
					D.text(panel,37,179,World.preparation_note(preparation),29,C.IVORY,600,802)
				else:
					D.chip(panel,Rect2(36,67,210,29),"PRÉPARATION",C.GOLD)
					D.text(panel,36,130,Office.scheduled_opponent(app,fixture),43,C.IVORY,800,810).name = "UpcomingOpponent"
					D.text(panel,37,179,Office.scheduled_when(app,fixture),29,C.IVORY,600,802).name = "UpcomingWhen"
					var venue := Office.scheduled_venue(app,fixture)
					if not venue.is_empty(): D.text(panel,37,219,"Lieu · " + venue,24,C.MUTED,500,802)
				D.button(panel,Rect2(166,247,589,60),app.primary_text().trim_suffix("  →"),app.primary_action,true,"arrow",false,PRIMARY,"CompetitionChampAdvance")
				return
			D.text(panel,36,130,"Préparation · " + World.name_for(app.model, str(app.model.meta.get("leagueId", "srp"))),43,C.IVORY,800,810)
			D.text(panel,37,179,World.preparation_note(preparation),29,C.IVORY,600,802)
			D.button(panel,Rect2(166,247,589,60),"Ouvrir le dossier de préparation",func(): app.Immersive.open_preparation(app,0),true,"arrow",false,PRIMARY,"CompetitionJapanLink" if japan else "CompetitionPacificLink")
			return
		D.text(panel, 36, 130, "Aucune rencontre programmée", 39, C.IVORY, 800, 810)
		D.text(panel, 37, 174, app.model.meta.get("roundLabel", "Consultez le calendrier du club."), 27, C.MUTED, 500, 802)
		D.button(panel, Rect2(166, 247, 589, 60), "Voir le calendrier du club", func(): _switch("calendar"), true, "calendar", false, PRIMARY, "CompetitionCalendarLink")
		return
	var home: Dictionary = next_fixture.get("home", {})
	var away: Dictionary = next_fixture.get("away", {})
	_crest(panel, home, Rect2(51, 67, 122, 112))
	D.text(panel, 227, 138, "VS", 48, C.IVORY, 800, 69, HORIZONTAL_ALIGNMENT_CENTER)
	_crest(panel, away, Rect2(287, 67, 122, 112))
	D.text(panel, 111, 205, G.club_name(home), 23, C.IVORY, 700, 200, HORIZONTAL_ALIGNMENT_CENTER)
	D.text(panel, 348, 205, G.club_name(away), 23, C.IVORY, 700, 212, HORIZONTAL_ALIGNMENT_CENTER)
	_entity_area(panel, Rect2(11,67,200,142), {"kind":"club", "id":str(home.get("id", ""))}, "CompetitionNextHome", "Ouvrir le club · " + G.club_name(home))
	_entity_area(panel, Rect2(246,67,212,142), {"kind":"club", "id":str(away.get("id", ""))}, "CompetitionNextAway", "Ouvrir le club · " + G.club_name(away))
	var caption := str(next_fixture.get("label", _phase(next_fixture))).to_upper()
	var date := _date(next_fixture)
	if date.is_empty():
		D.text(panel, 40, 243, caption, 27, C.IVORY, 700, 490)
	else:
		var date_label := D.text(panel, 40, 231, date, 27, C.IVORY, 700, 470)
		date_label.name = "CompetitionNextDate"
		var date_link := _entity_area(panel, Rect2(36,210,470,24), {"kind":"date", "id":str(next_fixture.get("date", ""))}, "CompetitionNextDateLink", "Voir la date dans le calendrier · " + date)
		if date_link != null:
			# Cover both the inherited Button font and its separate visible date.
			# The minimum also survives density scaling without shrinking the hit.
			var inherited_height := date_link.get_theme_font("font").get_height(date_link.get_theme_font_size("font_size"))
			date_link.size.y = maxf(18.0,maxf(date_link.size.y,maxf(ceilf(date_label.size.y),ceilf(inherited_height))))
		D.text(panel, 40, 253, caption, 20, C.MUTED, 600, 470)
	var location := _location(next_fixture)
	_box_tag(panel, Rect2(532, 213, 151, 37), location.to_upper(), WARM)
	var venue := _venue_name(next_fixture)
	var venue_parts := venue.split(" · ", false, 1)
	if not venue.is_empty():
		D.rect(panel, Rect2(684, 211, 228, 42), Color(C.BG, .86), 5)
	var venue_label: Label
	if venue_parts.size()==2:
		venue_label = D.text(panel,693,229,venue_parts[0],22,C.IVORY,600,212)
		D.text(panel,693,246,venue_parts[1],17,C.MUTED,500,212)
	elif not venue.is_empty():
		venue_label = D.text(panel,693,239,venue,22,C.IVORY,500,212)
	if venue_label!=null: venue_label.name = "CompetitionNextVenue"
	var live: bool = not app._live().is_empty()
	var action := D.button(panel, Rect2(166, 263, 589, 55), "REJOINDRE LE MATCH" if live else "PRÉPARER LE MATCH", func(): app._navigate("Match" if live else "Préparation"), true, "arrow", false, PRIMARY, "CompetitionPrepareMatch")
	action.alignment = HORIZONTAL_ALIGNMENT_CENTER
	action.add_theme_font_size_override("font_size", maxi(12, C.px(30)))

func _calendar_preview() -> void:
	var panel := _panel(self, Rect2(LEFT + 16, 618, RIGHT, 380), "CALENDRIER DU CLUB", "", "CompetitionCalendarPreview")
	D.button(panel, Rect2(668, 6, 240, 37), "Toute la saison", func(): _switch("calendar"), false, "calendar", true, app.accent, "OpenFullCalendar")
	if fixtures.is_empty():
		D.text(panel, 21, 112, "Aucun rendez-vous programmé.", 26, C.MUTED, 500, RIGHT - 42)
		return
	var anchor := fixtures.find_custom(func(fixture: Dictionary): return not fixture.get("played", false))
	var from := clampi(anchor - 1 if anchor >= 0 else fixtures.size() - 6, 0, maxi(0, fixtures.size() - 6))
	for i in mini(fixtures.size() - from, 6):
		_calendar_row(panel, fixtures[from + i], 50 + i * 53, RIGHT, true)

func _calendar() -> void:
	var panel := _panel(self, Rect2(0, 270, LEFT, 728), "TOUTE LA SAISON · CALENDRIER DU CLUB", "", "CalendarScroll")
	var selected := str(state.get("calendar_filter", "all"))
	for spec: Array in [[18, "Tous les matchs", "all"], [236, "À jouer", "upcoming"], [454, "Résultats", "played"]]:
		D.button(panel, Rect2(spec[0], 61, 205, 39), spec[1], func():
			state.calendar_filter = spec[2]
			_page_state("CalendarPagination").page = 0
			app._render(false), selected == spec[2], "", true, app.accent, "CalendarFilter_" + str(spec[2]))
	var visible := fixtures.filter(func(fixture: Dictionary): return selected == "all" or bool(fixture.get("played", false)) == (selected == "played"))
	D.text(panel, 1288, 88, "%d rencontre(s)" % visible.size(), 23, C.MUTED, 500, 200, HORIZONTAL_ALIGNMENT_RIGHT)
	var header := D.rect(panel, Rect2(1, 111, LEFT - 2, 39), Color("172426"), 3)
	var period := "DATE / PHASE" if international else "JOURNÉE / PHASE"
	for spec: Array in [[19, period, 230], [296, "ADVERSAIRE", 430], [720, "LIEU", 228], [954, "COMPÉTITION", 185], [1142, "RÉSULTAT", 154]]:
		D.text(header, spec[0], 27, spec[1], 23, C.MUTED, 600, spec[2])
	var bounds := _pager(panel, "CalendarPagination", "CalendarPagination", visible.size(), 11, 683, 822)
	for i in range(bounds.x, bounds.y):
		_calendar_row(panel, visible[i], 151 + 48 * (i - bounds.x), LEFT, false)
	if visible.is_empty(): D.text(panel, 23, 219, "Aucune rencontre dans cette vue du calendrier.", 26, C.MUTED, 500, LEFT - 47)
	_result_legend(panel, 25, 689)

func _calendar_row(parent: Node, fixture: Dictionary, y: float, width: float, compact: bool) -> void:
	var home: Dictionary = fixture.get("home", {})
	var away: Dictionary = fixture.get("away", {})
	var is_home: bool = home.get("id") == own.id
	var opponent := away if is_home else home
	var played: bool = fixture.get("played", false)
	var current := _is_next(fixture)
	var line_height := 53 if compact else 48
	var date := _date(fixture)
	var venue := _venue_name(fixture)
	var competition := _competition_name(fixture)
	var period := _fixture_label(fixture) if date.is_empty() else date
	var row := Button.new()
	row.name = "CalendarFixture_" + str(fixture.get("id", y))
	row.set_meta("fixture_id", str(fixture.get("id", "")))
	var competition_id := _competition_id(fixture)
	var dated_competition := competition_id in JAPAN_COMPETITIONS or competition_id in ["nationale","access-nationale","champ"]
	var timing := P.fixture_date(fixture, true) + " · " + _dated_phase(fixture) if not date.is_empty() and dated_competition else period
	row.accessibility_name = "%s · %s · %s · %s" % [timing,G.club_name(opponent),_location(fixture),competition]
	if not venue.is_empty() and venue != _location(fixture):
		row.accessibility_name += " · " + venue
	row.tooltip_text = row.accessibility_name
	row.add_theme_stylebox_override("normal", C.box(Color("202519") if current else Color("101a1b"), Color.TRANSPARENT, 3, 0))
	row.add_theme_stylebox_override("hover", C.box(Color("254035"), C.MINT, 3, 0))
	row.add_theme_stylebox_override("focus", C.box(Color.TRANSPARENT, WARM, 3, 0))
	if target_available(app, "fixture", fixture.get("id", "")):
		Link.bind(row, app, {"kind":"fixture", "id":str(fixture.get("id", ""))}, "Ouvrir la rencontre · " + row.accessibility_name)
	else:
		row.focus_mode = Control.FOCUS_NONE
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)
	D.place(row, Rect2(2, y, width - 4, line_height))
	D.line(row, Vector2(9, line_height - 1), Vector2(width - 15, line_height - 1), Color(C.LINE, .75))
	var middle := line_height / 2.0 + 8
	if date.is_empty():
		D.text(row,16,middle,period,23,C.IVORY,500,178 if compact else 232)
	else:
		var date_label := D.text(row,16,middle-7,date,23,C.IVORY,600,178 if compact else 232)
		date_label.name = "CalendarFixtureDate"
		D.text(row,16,middle+11,_dated_phase(fixture),17,C.MUTED,500,178 if compact else 232)
	var emblem_x := 196 if compact else 250
	_crest(row, opponent, Rect2(emblem_x, (line_height - 34) / 2.0, 34, 34))
	var opponent_name := D.text(row, emblem_x + 45, middle, G.club_name(opponent), 25, C.IVORY, 600, 221 if compact else 400)
	if compact:
		var font := opponent_name.get_theme_font("font")
		var pixels := opponent_name.get_theme_font_size("font_size")
		if font.get_string_size(opponent_name.text, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x > opponent_name.size.x:
			opponent_name.add_theme_font_size_override("font_size", maxi(12, C.px(22)))
			opponent_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			opponent_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			opponent_name.max_lines_visible = 2
			opponent_name.add_theme_constant_override("line_spacing", -4)
			opponent_name.position.y = 0
			opponent_name.size.y = C.px(line_height)
	_entity_area(row, Rect2(emblem_x,0,264 if compact else 445,line_height), {"kind":"club", "id":str(opponent.get("id", ""))}, "CalendarOpponent_" + str(fixture.get("id", y)).validate_node_name(), "Ouvrir le club · " + G.club_name(opponent))
	if not date.is_empty():
		_entity_area(row, Rect2(12,0,178 if compact else 232,line_height), {"kind":"date", "id":str(fixture.get("date", ""))}, "CalendarDate_" + str(fixture.get("id", y)).validate_node_name(), "Voir la date dans le calendrier · " + date)
	var place_x := 470 if compact else 720
	var location_kind := _location_kind(fixture)
	_icon(row, C.fixture_location_icon(location_kind), Rect2(place_x, (line_height - 18) / 2.0, 18, 18), C.GOLD)
	var venue_parts := venue.split(" · ",false,1)
	if not compact and venue_parts.size() == 2:
		D.text(row,place_x+25,middle-7,venue_parts[0],22,C.IVORY,600,204)
		D.text(row,place_x+25,middle+11,venue_parts[1],17,C.MUTED,500,204)
	else:
		D.text(row,place_x+25,middle,venue if not venue.is_empty() and not compact else _location(fixture,compact),22,C.IVORY,500,85 if compact else 204)
	D.text(row,589 if compact else 954,middle,World.short_name(_competition_id(fixture),competition,app.model),22,C.MUTED,500,185)
	_entity_area(row, Rect2(589 if compact else 954,0,185,line_height), {"kind":"competition", "id":competition_id}, "CalendarCompetition_" + str(fixture.get("id", y)).validate_node_name(), "Voir le classement · " + competition)
	var result_x := width - (140 if compact else 157)
	var code := _fixture_outcome(fixture)
	var score := _score(fixture, own.id)
	if played:
		_result_badge(row, Rect2(result_x, (line_height - 34) / 2.0, width - result_x - 14, 34), code, code + " " + score if code != "—" else score)
	else:
		_box_tag(row, Rect2(result_x, (line_height - 34) / 2.0, width - result_x - 14, 34), "À jouer", WARM if current else C.MUTED)

func _playoffs() -> void:
	var panel := _panel(self, Rect2(0, 270, LEFT, 728), "PHASES FINALES – " + _league_short(league).to_upper(), "trophy", "CompetitionPlayoffsPanel")
	_division_choices(panel, 16, 61)
	var japanese: bool = league.id in ["jlo-d1", "jlo-d2"]
	var phases: Array = season_results.filter(func(result: Dictionary):
		var competition := _competition_id(result, league.id)
		return _knockout(result) and (competition == league.id
			or (japanese and competition == "jlo-d1-d2")
			or (result.get("phase") == "access" and competition != "access-nationale" and league.id in ["elite", "accession"])
			or (competition == "access-nationale" and league.id in ["nationale", "accession"])))
	var bounds := _pager(panel, "PlayoffsPagination", "playoffs_" + str(league.id), phases.size(), 8, 682, 823)
	if league.get("champion") is Dictionary:
		_icon(panel, "trophy", Rect2(22, 121, 51, 51), WARM)
		D.text(panel, 89, 156, "CHAMPION · " + G.club_name(league.champion).to_upper(), 36, WARM, 800, 1180)
		if league.get("finalist") is Dictionary:
			D.text(panel, 89, 188, "Finaliste · " + G.club_name(league.finalist), 25, C.IVORY, 500, 1160)
	else:
		D.text(panel, 21, 154, "Les affiches se précisent au fil de la saison.", 30, C.IVORY, 700, 1250)
		var note: String = {
			"jlo-d1": "Barrages, demi-finales, petite finale et finale de D1 · Barrages D1–D2 en deux manches.",
			"jlo-d2": "La saison régulière désigne le champion · Barrages D1–D2 en deux manches.",
		}.get(league.id, "Barrages, demi-finales, finales et barrage d’accession selon la compétition.")
		D.text(panel, 22, 185, note, 23, C.MUTED, 500, 1250)
	if phases.is_empty(): D.text(panel, 23, 244, "Aucun résultat de phase finale conservé cette saison.", 27, C.MUTED, 500, 1230)
	for i in range(bounds.x, bounds.y):
		var result: Dictionary = phases[i]
		var card := D.rect(panel, Rect2(16, 218 + (i - bounds.x) * 54, LEFT - 32, 47), Color("172423"), 5, C.LINE)
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

func _stats() -> void:
	var panel := _panel(self, Rect2(0, 270, LEFT, 728), "STATISTIQUES – " + _league_short(league).to_upper(), "flag", "CompetitionStatsPanel")
	_division_choices(panel, 15, 63)
	var rows: Array = league.get("rows", [])
	var own_row: Dictionary = {}
	for row: Dictionary in rows:
		if row.get("id") == own.id:
			own_row = row
			break
	var summary := _panel(panel, Rect2(16, 124, LEFT - 32, 269), "NOTRE CLUB · BILAN DES POULES" if league.has("pools") else "NOTRE CLUB · BILAN DU CHAMPIONNAT", "shield", "StandingsContext")
	_crest(summary, own, Rect2(18, 67, 93, 93))
	var club_label := D.text(summary, 132, 104, G.club_name(own), 37, C.IVORY, 800, 1100)
	club_label.name = "StandingsContextClubName"
	D.text(summary, 135, 142, ("Rang " + S.count_text(own_row.get("rank")) if P.standings_open(own_row) else "Pas encore de classement") + "  ·  " + S.number_text(own_row.get("points")) + " point(s)  ·  " + S.count_text(own_row.get("played")) + " match(s)", 26, C.MUTED, 500, 1080)
	for i in 3:
		var code: String = ["V", "N", "D"][i]
		var quantity := S.count_text(own_row.get(["won", "drawn", "lost"][i]))
		_result_badge(summary, Rect2(135 + 166 * i, 161, 148, 43), code, quantity + " " + str(S.RESULTS[code].plural).to_lower(), quantity != "—")
	_recent_form(summary, own_row.get("form"), 132, 219)
	D.text(summary, 357, 241, "Forme · du plus ancien au plus récent", 22, C.MUTED, 500, 718)
	var rows_played := rows.filter(func(row: Dictionary): return float(row.get("played", 0)) > 0)
	var aggregate := _panel(panel, Rect2(16, 411, LEFT - 32, 294), "CHIFFRES DE LA PHASE DE POULES" if league.has("pools") else "CHIFFRES DE LA PHASE RÉGULIÈRE", "trophy", "CompetitionLeagueStats")
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
		D.rect(aggregate, Rect2(x, 70, 288, 127), Color("11251e"), 6, Color("436257"))
		D.text(aggregate, x + 22, 112, ["Matchs joués", "Points marqués", "Matchs nuls", "Points / match"][i], 26, C.MUTED, 500, 254)
		D.text(aggregate, x + 22, 170, values[i], 61, C.IVORY, 800, 253)
	D.text(aggregate, 28, 248, "Résultats de toutes les poules conservés par la carrière." if league.has("pools") else "Résultats et compteurs de championnat conservés par la carrière.", 26, C.MUTED, 500, 1210)

func _bottom() -> void:
	var recent := _panel(self, Rect2(0, 1013, 964, 211), "DERNIERS RÉSULTATS", "", "CompetitionRecentResults")
	var results: Array = season_results.filter(func(result: Dictionary): return _competition_id(result,league.id) == league.id and result.get("pair") is Array and result.get("score") is Array).slice(0, 3)
	for i in results.size():
		var result: Dictionary = results[i]
		var clubs := _matchup(result)
		var tile := D.rect(recent, Rect2(13 + i * 314, 59, 302, 138), Color("111d1f"), 8, Color(C.LINE, .60))
		_crest(tile, clubs[0], Rect2(14, 16, 49, 49))
		D.text(tile, 74, 39, G.club_name(clubs[0]), 25, C.IVORY, 700, 220)
		D.text(tile, 74, 68, "vs " + G.club_name(clubs[1]), 22, C.IVORY, 500, 220)
		_box_tag(tile, Rect2(74, 84, 155, 39), _score(result), WIN)
	if results.is_empty(): D.text(recent, 21, 122, "Aucun résultat enregistré pour cette division.", 27, C.MUTED, 500, 924)
	_leader(Rect2(980, 1013, 377, 211), "MEILLEURE ATTAQUE", "flag", "pf", "Points marqués", true)
	_leader(Rect2(1373, 1013, 376, 211), "MEILLEURE DÉFENSE", "shield", "pa", "Points encaissés", false)
	var scorer := _panel(self, Rect2(1765, 1013, 483, 211), "MEILLEUR RÉALISATEUR", "ball", "CompetitionScoring")
	D.photo(scorer, "player-hero", Rect2(6, 51, 158, 155))
	var caption := D.rect(scorer, Rect2(6, 181, 158, 25), Color("101819e8"), 3)
	D.text(caption, 79, 18, "ILLUSTRATION", 16, C.IVORY, 700, 158, HORIZONTAL_ALIGNMENT_CENTER)
	D.text(scorer, 180, 89, "Donnée indisponible", 26, C.IVORY, 700, 280)
	D.text(scorer, 180, 123, "Points individuels", 22, C.MUTED, 500, 280)
	D.text(scorer, 180, 150, "non conservés par la carrière.", 22, C.MUTED, 500, 287)
	D.text(scorer, 180, 191, "—", 45, C.IVORY, 800, 284)

func _leader(area: Rect2, title: String, icon_id: String, metric: String, caption: String, high: bool) -> void:
	var panel := _panel(self, area, title, icon_id, "CompetitionLeader_" + metric)
	var best: Dictionary = {}
	var tied := 0
	for club: Dictionary in league.get("rows", []):
		if float(club.get("played", 0)) <= 0 or S.count_text(club.get(metric)) == "—": continue
		if best.is_empty() or (float(club[metric]) > float(best[metric]) if high else float(club[metric]) < float(best[metric])):
			best = club
			tied = 1
		elif club[metric] == best[metric]:
			tied += 1
	if not best.is_empty(): _crest(panel, best, Rect2(16, 82, 74, 74))
	var club_name := D.text(panel, 105, 94, "Donnée à venir" if best.is_empty() else G.club_name(best), 29, C.IVORY, 700, 252)
	var font := club_name.get_theme_font("font")
	var wrap_name := font.get_string_size(club_name.text, HORIZONTAL_ALIGNMENT_LEFT, -1, club_name.get_theme_font_size("font_size")).x > club_name.size.x
	if wrap_name:
		club_name.add_theme_font_size_override("font_size", maxi(12, C.px(24)))
		club_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		club_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		club_name.max_lines_visible = 2
		club_name.add_theme_constant_override("line_spacing", 0)
		club_name.position.y = C.px(57)
		club_name.size.y = C.px(60)
	D.text(panel, 105, 166 if wrap_name else 151, S.count_text(best.get(metric)), 48 if wrap_name else 56, C.IVORY, 800, 235)
	D.text(panel, 105, 201 if wrap_name else 183, caption + (" · %d ex æquo" % tied if tied > 1 else ""), 23, C.MUTED, 500, 252)

func _division_choices(parent: Node, x: float, y: float) -> void:
	var gap := 8 if international else 13
	var width := floori((LEFT-2*x-gap*(leagues.size()-1))/leagues.size()) if international else 228
	for i in leagues.size():
		var division: Dictionary = leagues[i]
		var caption := _league_short(division)
		var button := D.button(parent,Rect2(x+(width+gap)*i,y,width,34),caption,func():
			app.table_division = division.id
			var owner_app := app
			owner_app._render(false)
			U.focus(owner_app,"StandingsDivision_"+str(division.id)),league.id==division.id,"",true,app.accent,"StandingsDivision_"+str(division.id))
		button.tooltip_text = str(division.get("name", caption)) if division.id in JAPAN_COMPETITIONS else _league_short(division)
		if international:
			button.alignment = HORIZONTAL_ALIGNMENT_CENTER
			if leagues.size() >= 11:
				for state_name in ["normal", "hover", "pressed", "disabled"]:
					var style := button.get_theme_stylebox(state_name)
					style.content_margin_left = C.px(8)
					style.content_margin_right = C.px(8)
				if division.id == "champ": button.add_theme_font_size_override("font_size", maxi(12, C.px(18)))

func _pager(parent: Node, id: String, key: String, total: int, capacity: int, y: float, x: float) -> Vector2i:
	var paging := _page_state(key)
	var pages := maxi(1, ceili(float(total) / capacity))
	paging.page = clampi(int(paging.get("page", 0)), 0, pages - 1)
	if pages > 1:
		var band := Control.new()
		band.name = id
		parent.add_child(band)
		D.place(band, Rect2(x, y, 470, 35))
		var prev := D.button(band, Rect2(0, 0, 155, 35), "← Précédent", func(): _turn(key, -1, id), false, "", true, app.accent, id + "Previous")
		prev.disabled = int(paging.page) == 0
		D.text(band, 230, 25, "Page %d / %d" % [int(paging.page) + 1, pages], 22, C.MUTED, 600, 133, HORIZONTAL_ALIGNMENT_CENTER)
		var following := D.button(band, Rect2(301, 0, 156, 35), "Suivant →", func(): _turn(key, 1, id), false, "", true, app.accent, id + "Next")
		following.disabled = int(paging.page) >= pages - 1
	return Vector2i(int(paging.page) * capacity, mini(total, (int(paging.page) + 1) * capacity))

func _page_state(key: String) -> Dictionary:
	if not app.management_ui.get(key) is Dictionary: app.management_ui[key] = {"page": 0}
	return app.management_ui[key]

func _turn(key: String, direction: int, id: String) -> void:
	var page := _page_state(key)
	page.page = int(page.page) + direction
	var owner_app := app
	app._render(false)
	var target := owner_app.find_child(id + ("Previous" if direction < 0 else "Next"), true, false) as Button
	if target != null and target.disabled:
		target = owner_app.find_child(id + ("Next" if direction < 0 else "Previous"), true, false) as Button
	if target != null: target.grab_focus.call_deferred()

func _entity_area(parent: Node, area: Rect2, target: Dictionary, id: String, caption: String) -> Button:
	if not target_available(app, str(target.kind), target.id): return null
	var button := Button.new()
	button.name = id
	button.flat = true
	button.add_theme_stylebox_override("normal", C.box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0))
	button.add_theme_stylebox_override("hover", C.box(Color(C.MINT, .06), Color(C.MINT, .55), 3, 0))
	button.add_theme_stylebox_override("focus", C.box(Color.TRANSPARENT, WARM, 3, 0))
	Link.bind(button, app, target, caption)
	parent.add_child(button)
	D.place(button, area)
	return button

func _club_detail(club: Dictionary) -> void:
	var view := Decisions.dialog(app, G.club_name(club), "CompetitionClubDetails", 880)
	set_meta("reading_dialog", view[0])
	view[0].set_meta("navigation_read_only", true)
	view[0].set_meta("entity_kind", "club")
	view[0].set_meta("entity_id", str(club.id))
	var content: VBoxContainer = view[1]
	var club_division: Dictionary = {}
	for division: Dictionary in leagues:
		if division.get("rows", []).any(func(item: Dictionary): return item.get("id") == club.id): club_division = division; break
	var division_name := _league_short(club_division) if not club_division.is_empty() else "Club"
	content.add_child(C.label("%s · %s · %s points" % [division_name, "Rang " + S.count_text(club.get("rank")) if P.standings_open(club) else "Pas encore de classement", S.number_text(club.get("points"))], 28, C.IVORY, true, 700))
	var summary := "%s V  ·  %s N  ·  %s D  ·  %s points marqués  ·  %s encaissés" % [S.count_text(club.get("won")), S.count_text(club.get("drawn")), S.count_text(club.get("lost")), S.count_text(club.get("pf")), S.count_text(club.get("pa"))]
	content.add_child(C.wrap(summary, 22, C.MUTED, true))
	var recent: Array = season_results.filter(func(item: Dictionary): return club.id in item.get("pair", [])).slice(0, 10)
	if recent.is_empty(): content.add_child(C.wrap("Aucun résultat de la saison conservé.", 22, C.MUTED, true))
	for result: Dictionary in recent:
		var clubs := _matchup(result)
		content.add_child(C.rule())
		var caption := "%s  %s  %s" % [G.club_name(clubs[0]), _score(result), G.club_name(clubs[1])]
		var fixture_id := str(result.get("fixtureId", ""))
		if target_available(app, "fixture", fixture_id):
			var link := Link.button(app, caption, {"kind":"fixture", "id":fixture_id}, "ClubResult_" + fixture_id.validate_node_name(), view[0])
			link.clip_text = true
			content.add_child(link)
		else: content.add_child(C.label(caption, 25, C.IVORY))
		content.add_child(C.label(_phase(result), 21, C.MUTED))
	view[0].popup_centered(Vector2i(880, 565))

func _fixture_detail(fixture: Dictionary) -> void:
	var heading := _fixture_label(fixture)
	var competition_id := _competition_id(fixture)
	if international:
		var stage := _dated_phase(fixture)
		heading = stage if competition_id == "jlo-d1-d2" else _competition_name(fixture) + " · " + stage
		if competition_id == "access-nationale": heading = _competition_name(fixture)
	var view := Decisions.dialog(app, heading, "CompetitionFixtureDetails", 880)
	set_meta("reading_dialog", view[0])
	view[0].set_meta("navigation_read_only", true)
	view[0].set_meta("entity_kind", "fixture")
	view[0].set_meta("entity_id", str(fixture.get("id", "")))
	var content: VBoxContainer = view[1]
	content.add_child(C.label("%s  —  %s" % [G.club_name(fixture.get("home", {})), G.club_name(fixture.get("away", {}))], 30, C.IVORY, true, 700))
	var club_links := C.h(8)
	content.add_child(club_links)
	for side: String in ["home", "away"]:
		var club: Dictionary = fixture.get(side, {})
		if target_available(app, "club", club.get("id", "")):
			var link := Link.button(app, G.club_name(club), {"kind":"club", "id":str(club.id)}, "FixtureClub_" + side, view[0])
			link.clip_text = true
			link.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			club_links.add_child(link)
	var place := _location(fixture)
	var venue := _venue_name(fixture)
	if not venue.is_empty(): place += "  ·  " + venue
	var date := P.fixture_date(fixture, true)
	if not date.is_empty():
		var raw_date: Variant = fixture.get("date")
		if target_available(app, "date", raw_date):
			content.add_child(Link.button(app, date, {"kind":"date", "id":raw_date}, "FixtureCalendarDate", view[0]))
		else: content.add_child(C.label(date,25,WARM))
	var division_id := _competition_id(fixture)
	if target_available(app, "competition", division_id):
		content.add_child(Link.button(app, _competition_name(fixture), {"kind":"competition", "id":division_id}, "FixtureCompetition", view[0]))
	if competition_id in JAPAN_COMPETITIONS:
		for note: String in Club.japan_date_notes(fixture): content.add_child(C.wrap(note, 20, C.MUTED))
	elif competition_id in ["nationale", "access-nationale", "champ"]:
		_date_provenance(content, fixture)
	content.add_child(C.label(_phase(fixture) + "  ·  " + place, 24, C.MUTED))
	if fixture.get("played", false):
		var code := _fixture_outcome(fixture)
		content.add_child(C.label(_score(fixture) + "  ·  " + str(S.RESULTS.get(code, {}).get("label", "Issue non renseignée")), 37, RESULT_TINTS.get(code, C.IVORY), true, 700))
		_fixture_statistics(content, fixture)
		var winner: Variant = _fixture_winner(fixture)
		if winner != null and identities.has(winner):
			content.add_child(C.label("Vainqueur : " + G.club_name(identities[winner]), 26, C.IVORY))
	else:
		content.add_child(C.label("Match à jouer", 29, WARM))
		if _is_next(fixture):
			var live: bool = not app._live().is_empty()
			var prepare := C.button("Rejoindre le match" if live else "Préparer le match", func(): view[0].queue_free(); app._navigate("Match" if live else "Préparation"), true, app.accent)
			content.add_child(prepare)
	view[0].popup_centered(Vector2i(880, 520))

func _fixture_statistics(content: VBoxContainer, fixture: Dictionary) -> void:
	var result := _history_for(fixture)
	var stats: Variant = fixture.get("stats", result.get("stats"))
	if not stats is Array or stats.size() != 2 or not stats[0] is Dictionary or not stats[1] is Dictionary: return
	content.add_child(C.rule())
	content.add_child(C.label("Statistiques · domicile / extérieur", 23, C.GOLD, true, 700))
	for item: Array in [["Pénalités concédées", "penalties"], ["Cartons jaunes", "yellows"]]:
		content.add_child(C.label("%s · %s / %s" % [item[0], S.count_text(stats[0].get(item[1])), S.count_text(stats[1].get(item[1]))], 22, C.IVORY))
	for item: Array in [["Mêlées conservées", "scrumsWon", "scrums"], ["Touches conservées", "lineoutsWon", "lineouts"], ["Tirs de pénalité", "goals", "goalAttempts"], ["Transformations", "conversions", "conversionAttempts"]]:
		content.add_child(C.wrap("%s · %s / %s — %s / %s" % [item[0], S.count_text(stats[0].get(item[1])), S.count_text(stats[0].get(item[2])), S.count_text(stats[1].get(item[1])), S.count_text(stats[1].get(item[2]))], 22, C.MUTED))

func _date_provenance(content: VBoxContainer, fixture: Dictionary) -> void:
	var source: String = {
		"published": "Date publiée",
		"published-phase-day": "Jour de phase publié",
		"published-window": "Date retenue dans la fenêtre publiée",
		"published-provisional": "Date provisoire publiée",
		"rfu-card": "Date publiée par la RFU",
		"club-announced-stage-date": "Date de phase annoncée par le club",
	}.get(fixture.get("dateSource", ""), "")
	if not source.is_empty(): content.add_child(C.wrap(source, 20, C.MUTED))
	var window: Array = fixture.get("dateWindow", [])
	if window.size()==2:
		content.add_child(C.wrap("Fenêtre du %s au %s" % [Club._calendar_date(window[0]), Club._calendar_date(window[1])],20,C.MUTED))
	var timezone: Variant = fixture.get("timezone")
	if fixture.get("kickoffLocal") is String and timezone is String and not timezone.is_empty():
		content.add_child(C.wrap("Heure locale · " + timezone,20,C.MUTED))
		var kickoff_source: String = {
			"published": "Horaire publié",
			"rfu_fixture_card": "Horaire publié dans la fiche RFU",
			"rfu_match_centre": "Horaire publié dans le centre de match RFU",
		}.get(fixture.get("kickoffSource", ""), "")
		if not kickoff_source.is_empty(): content.add_child(C.wrap(kickoff_source, 20, C.MUTED))

func _fixture_outcome(fixture: Dictionary) -> String:
	if not fixture.get("played", false): return "—"
	var score: Variant = fixture.get("score")
	var index := _side(fixture, own.get("id"))
	if index < 0: return "—"
	var decisive := _knockout(fixture) and _competition_id(fixture) != "jlo-d1-d2"
	if decisive:
		var winner: Variant = _fixture_winner(fixture)
		if winner != null: return "V" if winner == own.id else "D"
	if not score is Array or score.size() != 2 or S.count_text(score[0]) == "—" or S.count_text(score[1]) == "—": return "—"
	if score[0] == score[1] and decisive: return "—"
	return "V" if score[index] > score[1 - index] else "D" if score[index] < score[1 - index] else "N"

func _fixture_winner(fixture: Dictionary) -> Variant:
	var winner: Variant = fixture.get("winner")
	if _side(fixture, winner) >= 0: return winner
	var recorded := _history_for(fixture)
	winner = recorded.get("winner")
	return winner if _side(fixture, winner) >= 0 else null

func _history_for(fixture: Dictionary) -> Dictionary:
	var pair := [fixture.get("home", {}).get("id"), fixture.get("away", {}).get("id")]
	for result: Dictionary in season_results:
		if result.has("fixtureId") and result.fixtureId == fixture.get("id"): return result
	var matches := season_results.filter(func(result: Dictionary): return result.get("phase") == fixture.get("phase") and result.get("pair") == pair and result.get("score") == fixture.get("score"))
	return matches[0] if matches.size() == 1 else {}

func _is_next(fixture: Dictionary) -> bool:
	return not next_fixture.is_empty() and not fixture.get("played",false) and fixture.get("week") == next_fixture.get("week") and fixture.get("home",{}).get("id") == next_fixture.get("home",{}).get("id") and fixture.get("away",{}).get("id") == next_fixture.get("away",{}).get("id") and (not international or fixture.get("date") == next_fixture.get("date"))

func _matchup(result: Dictionary) -> Array:
	var pair: Array = result.get("pair", [])
	if pair.size() != 2: return [{}, {}]
	return [identities.get(pair[0], {}), identities.get(pair[1], {})]

func _location(fixture: Dictionary, compact: bool = false) -> String:
	match _location_kind(fixture):
		"neutral": return "Neutre" if compact else "Terrain neutre"
		"home": return "Dom." if compact else "À domicile"
		"away": return "Ext." if compact else "À l’extérieur"
	return "—"

func _location_kind(fixture: Dictionary) -> String:
	return P.fixture_location_kind(fixture, own.get("id"))

static func _venue_name(fixture: Dictionary) -> String:
	var venue: Variant = fixture.get("venue")
	if venue is Dictionary: venue = venue.get("name")
	return venue if venue is String and venue.to_lower() not in ["home", "away", "neutral"] else ""

static func _side(fixture: Dictionary, id: Variant) -> int:
	if id == null: return -1
	if fixture.get("home", {}).get("id") == id: return 0
	if fixture.get("away", {}).get("id") == id: return 1
	return -1

static func _score(fixture: Dictionary, club_id: Variant = null) -> String:
	var value: Variant = fixture.get("score")
	if not value is Array or value.size() != 2 or S.count_text(value[0]) == "—" or S.count_text(value[1]) == "—": return "—"
	var away := _side(fixture, club_id) == 1
	return "%s – %s" % [G.n(value[1] if away else value[0]), G.n(value[0] if away else value[1])]

static func _league_short(division: Dictionary) -> String:
	var text := str(division.get("name", "Championnat"))
	return str(division.get("shortName", text.get_slice(" — ", 0)))

static func _date(fixture: Dictionary) -> String:
	return P.fixture_date(fixture)

static func _knockout(fixture: Dictionary) -> bool:
	return fixture.get("phase","league") not in ["league","pool"]

static func _competition_id(fixture: Dictionary, fallback: String = "") -> String:
	return str(fixture.get("competitionId",fixture.get("leagueId",fallback)))

func _competition_name(fixture: Dictionary) -> String:
	if not international: return _phase(fixture)
	var id := _competition_id(fixture)
	var caption := World.name_for(app.model, id)
	return caption

static func _phase(fixture: Dictionary) -> String:
	var id := str(fixture.get("phase", "league"))
	var competition := _competition_id(fixture)
	if competition == "jlo-d1" and id == "quarter": return "Barrage D1"
	if competition == "jlo-d1-d2" and id == "promotion":
		var leg_value: Variant = fixture.get("leg")
		var leg := int(leg_value) if leg_value is int or leg_value is float else 0
		# L’historique conserve la manche dans un tour indexé à partir de zéro.
		var round_value: Variant = fixture.get("competitionRound")
		if leg == 0 and (round_value is int or round_value is float): leg = int(round_value) + 1
		return "Barrage D1–D2 · Manche %d" % leg if leg in [1, 2] else "Barrage D1–D2"
	if competition == "jlo-d1" and id == "third-place": return "Petite finale"
	return str(LABELS.get(id, id.capitalize()))

static func _dated_phase(fixture: Dictionary) -> String:
	var phase := _phase(fixture)
	var round_value: Variant = fixture.get("competitionRound")
	if fixture.get("phase") in ["league","pool"] and (round_value is int or round_value is float):
		phase += " · J%d" % (int(round_value)+1)
	return phase

static func _fixture_label(fixture: Dictionary) -> String:
	var label := str(fixture.get("label", ""))
	var round_value: Variant = fixture.get("competitionRound")
	if label.is_empty() and round_value is String: label = round_value
	if label.is_empty() and S.count_text(round_value) not in ["—", "0"] and fixture.get("phase") == "league":
		label = "Journée " + G.n(round_value)
	if label.is_empty(): label = "Semaine " + G.n(int(fixture.get("week", 0)) + 1)
	return str(LABELS.get(label, label))

static func _crest(parent: Node, club: Dictionary, area: Rect2) -> void:
	if club.is_empty(): return
	var shield := G.crest(club, C.px(minf(area.size.x, area.size.y)))
	parent.add_child(shield)
	D.place(shield, area)

static func _icon(parent: Node, icon_id: String, area: Rect2, color: Color) -> void:
	var icon := C.icon(icon_id, int(area.size.x), color)
	parent.add_child(icon)
	D.place(icon, area)

static func _panel(parent: Node, area: Rect2, title: String, icon_id: String, id: String) -> Panel:
	var panel := D.panel(parent, area, "", "", "", id)
	if icon_id.is_empty():
		var slashes := Polygon2D.new()
		slashes.color = WARM
		slashes.position = Vector2(C.px(18), C.px(13))
		slashes.polygon = PackedVector2Array([Vector2(0, 27), Vector2(14, 0), Vector2(21, 0), Vector2(7, 27), Vector2(14, 27), Vector2(28, 0), Vector2(35, 0), Vector2(21, 27)])
		slashes.polygons = [PackedInt32Array([0, 1, 2, 3]), PackedInt32Array([4, 5, 6, 7])]
		slashes.scale = Vector2.ONE * C.density
		panel.add_child(slashes)
	else: _icon(panel, icon_id, Rect2(19, 11, 31, 31), WARM)
	var heading := D.text(panel, 65, 36, title, 31, C.IVORY, 800, area.size.x - 78)
	heading.name = "CardTitle"
	D.line(panel, Vector2(1, 49), Vector2(area.size.x - 1, 49), C.LINE)
	return panel

static func _box_tag(parent: Node, area: Rect2, caption: String, color: Color) -> void:
	var box := D.rect(parent, area, color.darkened(.78), 5, color)
	D.text(box, area.size.x / 2, area.size.y / 2 + 8, caption, 24, color, 700, area.size.x - 7, HORIZONTAL_ALIGNMENT_CENTER)

static func _result_badge(parent: Node, area: Rect2, code: String, caption: String = "", known: bool = true) -> void:
	var outcome: Dictionary = S.RESULTS.get(code, {}) if known else {}
	var color: Color = RESULT_TINTS.get(code, DRAW) if not outcome.is_empty() else DRAW
	var text := caption if not caption.is_empty() else code if not outcome.is_empty() else "—"
	var box := D.rect(parent, area, color, 5)
	box.name = "SemanticBadge"
	box.set_meta("semantic_role", outcome.get("role", "neutral"))
	box.set_meta("semantic_text", text)
	box.accessibility_name = str(outcome.get("label", "Résultat non renseigné")) + " · " + text
	D.text(box, area.size.x / 2, area.size.y / 2 + 8, text, 24, Color("0b1815"), 800, area.size.x - 4, HORIZONTAL_ALIGNMENT_CENTER)

static func _result_legend(parent: Node, x: float, y: float) -> void:
	for i in 3:
		var code: String = ["V", "N", "D"][i]
		_result_badge(parent, Rect2(x + i * 163, y, 25, 27), code)
		D.text(parent, x + 34 + i * 163, y + 20, S.RESULTS[code].label, 21, C.IVORY, 500, 120)

static func _recent_form(parent: Node, values: Variant, x: float, y: float) -> void:
	var group := Control.new()
	group.name = "RecentForm"
	group.tooltip_text = "Résultats de championnat du plus ancien au plus récent"
	parent.add_child(group)
	D.place(group, Rect2(x, y, 204, 31))
	var sequence: Array = values.slice(-6) if values is Array and values.size() > 6 else values if values is Array else []
	if sequence.is_empty(): sequence = ["—"]
	for i in sequence.size(): _result_badge(group, Rect2(i * 34, 0, 30, 30), str(sequence[i]))

static func _fade(parent: Node, area: Rect2) -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, C.BG)
	gradient.add_point(.36, Color(C.BG, .88))
	gradient.set_color(gradient.get_point_count() - 1, Color(C.BG, 0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_to = Vector2.RIGHT
	var view := TextureRect.new()
	view.texture = texture
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(view)
	D.place(view, area)

static func _tab_style(width: int, selected: bool, accent: Color) -> StyleBoxTexture:
	var tint := Color("11191e").lerp(accent,.39)
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="122" viewBox="0 0 %d 61"><defs><linearGradient id="g" x1="0" y1="0" x2="0" y2="1"><stop stop-color="%s"/><stop offset="1" stop-color="%s"/></linearGradient></defs><path d="M1 60L15 9Q19 1 27 1H%dQ%d 1 %d 9L%d 60Z" fill="url(#g)" stroke="%s"/></svg>' % [
		width * 2, width, "#" + C.readable_primary_fill(tint.lightened(.07)).to_html(false) if selected else "#202b2d", "#" + tint.to_html(false) if selected else "#121c1d",
		width - 24, width - 16, width - 13, width - 1, "#" + accent.lightened(.38).to_html(false) if selected else "#576966"
	]
	var image := Image.new()
	image.load_svg_from_string(svg)
	var style := StyleBoxTexture.new()
	style.texture = ImageTexture.create_from_image(image)
	style.content_margin_left = C.px(20)
	style.content_margin_right = C.px(20)
	return style

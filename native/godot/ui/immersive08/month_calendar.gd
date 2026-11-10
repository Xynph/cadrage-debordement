extends VBoxContainer
## Calendrier de carrière : la date simulée et le programme viennent du moteur.

const C = preload("res://ui/immersive08/components.gd")
const G = preload("res://ui/game_skin.gd")
const P = preload("res://ui/immersive08/projection.gd")
const Agenda = preload("res://ui/immersive08/calendar_agenda.gd")
const DAY_SECONDS := 86400
const MONTHS := ["Janvier","Février","Mars","Avril","Mai","Juin","Juillet","Août","Septembre","Octobre","Novembre","Décembre"]
const WEEKDAYS := ["Lundi","Mardi","Mercredi","Jeudi","Vendredi","Samedi","Dimanche"]
const SHORT_DAYS := ["Lun.","Mar.","Mer.","Jeu.","Ven.","Sam.","Dim."]
const PLACES := {"home":"Domicile","away":"Extérieur","neutral":"Terrain neutre"}
const ICON_PATHS := {
	"team":"M12 2a3 3 0 1 1 0 6 3 3 0 0 1 0-6ZM5 5a2.5 2.5 0 1 1 0 5 2.5 2.5 0 0 1 0-5Zm14 0a2.5 2.5 0 1 1 0 5 2.5 2.5 0 0 1 0-5ZM1 18v-3a4 4 0 0 1 6-3 6 6 0 0 0-1 4v2zm22 0h-5v-2a6 6 0 0 0-1-4 4 4 0 0 1 6 3zM7 22v-6a5 5 0 0 1 10 0v6z",
	"strength":"M1 8h3v8H1zm4-3h4v14H5zm5 5h4v4h-4zm5-5h4v14h-4zm5 3h3v8h-3z",
	"speed":"M13 1 3 14h7l-1 9 12-14h-7z",
	"tactics":"M2 3h20v18H2zm2 2v14h7v-3a4 4 0 0 1 0-8V5zm9 0v3a4 4 0 0 1 0 8v3h7V5zm-1 5a2 2 0 1 0 0 4 2 2 0 0 0 0-4",
	"skills":"M12 1a11 11 0 1 0 0 22 11 11 0 0 0 0-22Zm0 4a7 7 0 1 1 0 14 7 7 0 0 1 0-14Zm0 4a3 3 0 1 0 0 6 3 3 0 0 0 0-6Z",
	"recovery":"M12 21 3.5 13C-3 7 5 0 12 7c7-7 15 0 8.5 6z",
	"video":"M1 4h22v16H1zm9 4v8l7-4z",
	"kicking":"M21 3C10 0 0 10 3 21c11 3 21-7 18-18ZM8 14l6-6 2 2-6 6z",
}
const ICON_COLORS := {
	"team":Color("91d9bd"),"strength":Color("e4bf82"),"speed":Color("efc76b"),"tactics":Color("a8bff2"),
	"skills":Color("9bdce3"),"recovery":Color("ea9fa5"),"video":Color("b7a8ec"),"kicking":Color("d7e6a1"),
}
static var _icons: Dictionary = {}

var app: Control
var show_table: Callable
var fixtures: Array = []
var sessions: Array = []
var undated: Array = []
var next_fixture: Dictionary = {}
var fixtures_by_day: Dictionary = {}
var sessions_by_day: Dictionary = {}
var planning: Dictionary = {}
var today := ""
var month := ""
var selected := ""
var filter := "all"
var view_mode := "month"

static func build(owner_app: Control, table_callback: Callable = Callable()) -> Control:
	var view: VBoxContainer = load("res://ui/immersive08/month_calendar.gd").new()
	view._setup(owner_app, table_callback)
	return view

func _setup(owner_app: Control, table_callback: Callable) -> void:
	name = "CarnetCalendar"
	app = owner_app
	show_table = table_callback
	C.fill(self, true)
	add_theme_constant_override("separation", C.px(16))
	planning = app.model.get("calendarPlanning", {})
	today = _date(planning.get("today", app.model.get("meta", {}).get("date")))
	for fixture: Dictionary in Agenda.unique_fixtures(planning.get("fixtures", app.model.get("calendar", []))):
		var date := _date(fixture.get("date"))
		if date.is_empty():
			undated.append(fixture)
			continue
		fixtures.append(fixture)
		_index(fixtures_by_day, date, fixture)
		if not fixture.get("played", false) and (today.is_empty() or date >= today):
			if next_fixture.is_empty() or date < next_fixture.date:
				next_fixture = fixture
	for session: Dictionary in planning.get("sessions", []):
		var date := _date(session.get("date"))
		if date.is_empty(): continue
		sessions.append(session)
		_index(sessions_by_day, date, session)
	var initial := today
	if initial.is_empty() and not next_fixture.is_empty(): initial = next_fixture.date
	if initial.is_empty() and not fixtures.is_empty(): initial = fixtures[0].date
	if initial.is_empty() and not sessions.is_empty(): initial = sessions[0].date
	var reading: Dictionary = app.management_ui.get("calendar_reading", {})
	var remembered := _date(reading.get("selected"))
	filter = str(reading.get("filter","all"))
	if filter not in Agenda.FILTERS: filter = "all"
	view_mode = str(reading.get("view","month"))
	if view_mode not in ["month","week"]: view_mode = "month"
	if reading.get("today") == today and not remembered.is_empty():
		initial = remembered
	month = initial.left(7)
	selected = initial
	_refresh()
	var focus_id := str(reading.get("focus",""))
	if not focus_id.is_empty():
		var focus := find_child(focus_id,true,false) as Control
		if focus != null: focus.call_deferred("grab_focus")

func _index(items: Dictionary, date: String, value: Dictionary) -> void:
	if not items.has(date): items[date] = []
	items[date].append(value)

static func _date(value: Variant) -> String:
	if not value is String or value.length() != 10: return ""
	var parts: PackedStringArray = value.split("-")
	if parts.size() != 3 or parts[0].length() != 4 or parts[1].length() != 2 or parts[2].length() != 2: return ""
	if not parts[0].is_valid_int() or not parts[1].is_valid_int() or not parts[2].is_valid_int(): return ""
	var year := parts[0].to_int()
	var number := parts[1].to_int()
	if year < 2 or year > 9998 or number < 1 or number > 12: return ""
	if parts[2].to_int() < 1 or parts[2].to_int() > _month_length(year, number): return ""
	return value

static func _month_length(year: int, number: int) -> int:
	if number == 2: return 29 if year % 4 == 0 and (year % 100 != 0 or year % 400 == 0) else 28
	return 30 if number in [4,6,9,11] else 31

static func _weekday(date: String) -> int:
	var stamp := int(Time.get_unix_time_from_datetime_string(date + "T00:00:00"))
	return (int(Time.get_datetime_dict_from_unix_time(stamp).weekday) + 6) % 7

static func _display_date(date: String) -> String:
	return "%s %d %s" % [WEEKDAYS[_weekday(date)], date.right(2).to_int(), MONTHS[date.substr(5,2).to_int()-1].to_lower()]

func _shift_month(amount: int) -> void:
	if view_mode == "week":
		var date := Agenda.shift(selected,amount*7)
		if date.is_empty(): return
		_select(date)
		var target := find_child("MonthPrevious" if amount < 0 else "MonthNext",true,false) as Control
		if target != null: target.call_deferred("grab_focus")
		return
	var year := month.left(4).to_int()
	var number := month.right(2).to_int() + amount
	if number == 0:
		year -= 1
		number = 12
	elif number == 13:
		year += 1
		number = 1
	if year < 2 or year > 9998: return
	month = "%04d-%02d" % [year,number]
	selected = today if today.begins_with(month) else month + "-01"
	_refresh()
	var target := find_child("MonthPrevious" if amount < 0 else "MonthNext", true, false) as Control
	if target != null: target.call_deferred("grab_focus")

func _select(date: String) -> void:
	if _date(date).is_empty(): return
	month = date.left(7)
	selected = date
	_refresh()
	var target := find_child("MonthDay_" + date, true, false) as Control
	if target != null: target.call_deferred("grab_focus")

func _filter_by(value: String) -> void:
	if value not in Agenda.FILTERS: return
	filter = value
	_refresh()
	var target := find_child("MonthFilter_" + value, true, false) as Control
	if target != null: target.call_deferred("grab_focus")

func _view_as(value: String) -> void:
	if value not in ["month","week"]: return
	view_mode = value
	_refresh()
	var target := find_child("CalendarView_"+value,true,false) as Control
	if target != null: target.call_deferred("grab_focus")

func _remember_focus(id: String) -> void:
	app.management_ui["calendar_reading"]["focus"] = id

func _refresh() -> void:
	app.management_ui["calendar_reading"] = {"today":today, "selected":selected, "filter":filter,"view":view_mode}
	for child in get_children():
		remove_child(child)
		child.queue_free()
	if month.is_empty():
		_heading("Calendrier", "Les dates n’ont pas encore été fixées.", 0, 0)
		_undated_panel()
		return
	var month_name: String = MONTHS[month.right(2).to_int()-1]
	var week_dates := Agenda.week(selected)
	var current_fixtures := fixtures.filter(func(fixture: Dictionary) -> bool: return fixture.date in week_dates if view_mode == "week" else fixture.date.begins_with(month))
	var current_sessions := sessions.filter(func(session: Dictionary) -> bool: return session.date in week_dates if view_mode == "week" else session.date.begins_with(month))
	var venues := {"home":0,"away":0,"neutral":0}
	for fixture: Dictionary in current_fixtures:
		var location := P.fixture_location_kind(fixture, _club_id())
		if venues.has(location): venues[location] += 1
	var summary := PackedStringArray()
	if venues.home > 0: summary.append(_plural(venues.home, "réception", "réceptions"))
	if venues.away > 0: summary.append(_plural(venues.away, "déplacement", "déplacements"))
	if venues.neutral > 0: summary.append(_plural(venues.neutral, "match sur terrain neutre", "matchs sur terrain neutre"))
	var period := "Cette semaine" if view_mode == "week" else "Ce mois-ci"
	var description := "Aucune rencontre programmée sur cette période." if summary.is_empty() else period + " · " + " · ".join(summary)
	_heading(month_name,description,current_fixtures.size(),current_sessions.size())
	var availability := preload("res://ui/international_availability.gd")
	if availability.data(app.model).get("clubManaged", false):
		add_child(availability.calendar_summary(app))
	var workspace := C.h(16)
	C.fill(workspace, true)
	add_child(workspace)
	var left := C.card()
	left.add_theme_stylebox_override("panel", C.box(C.PANEL, Color("425751"), 10, 0))
	C.fill(left, true)
	workspace.add_child(left)
	var body := C.content(left)
	body.add_theme_constant_override("separation", 0)
	_toolbar(body)
	if view_mode == "week": _week_grid(body)
	else: _grid(body)
	_legend(body)
	_context_panels(body)
	_detail(workspace)
	_undated_panel()

static func _plural(count: int, singular: String, plural: String) -> String:
	return "%d %s" % [count, singular if count == 1 else plural]

func _heading(title: String, description: String, match_count: int, session_count: int) -> void:
	var panel := C.card("", Vector2(0,106))
	var ink := Color("182824").lerp(app.accent, .12)
	var edge := C.box(ink, Color("50665e"), 8, 12)
	edge.border_color = Color("50665e").lerp(app.accent, .35)
	panel.add_theme_stylebox_override("panel", edge)
	var photo := C.photo("stadium", Vector2.ZERO, true, .42)
	panel.add_child(photo)
	panel.move_child(photo, 0)
	photo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	photo.modulate.a = .21
	panel.clip_contents = true
	add_child(panel)
	var body := C.content(panel)
	var season := G.n(app.model.get("meta", {}).get("season", ""))
	var league := P.league_name(app.model)
	body.add_child(C.label(("SAISON %s   /   %s" % [season, league]).to_upper(), 16, C.GOLD, true, 700))
	var heading := title if month.is_empty() else title + " " + month.left(4)
	if view_mode == "week":
		var dates := Agenda.week(selected)
		if not dates.is_empty(): heading = "Semaine du " + _display_date(dates[0]) + " " + dates[0].left(4) + " au " + _display_date(dates[-1]) + " " + dates[-1].left(4)
	body.add_child(C.label(heading, 28, C.IVORY, true, 800))
	var line := C.h(12)
	body.add_child(line)
	var subtitle := C.label(description, 17, C.IVORY, false)
	subtitle.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	line.add_child(C.fill(subtitle))
	if not month.is_empty():
		line.add_child(_pill(_plural(match_count, "match", "matchs"), Color("3b3020"), C.GOLD))
		line.add_child(_pill(_plural(session_count, "entraînement", "entraînements"), Color("183a35"), C.MINT))
	elif show_table.is_valid():
		line.add_child(_action("Tableau des rencontres", show_table, "CalendarShowTable"))

func _toolbar(parent: Node) -> void:
	var padding := C.margin(12)
	parent.add_child(padding)
	var rows := C.v(10)
	padding.add_child(rows)
	var bar := C.h(10)
	rows.add_child(bar)
	var caption := C.label("Planning du club",22,C.IVORY,true,700)
	caption.name = "MonthCalendarCaption"
	caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	bar.add_child(C.fill(caption))
	for mode: Array in [["month","Mois"],["week","Semaine"]]:
		bar.add_child(_action(mode[1],_view_as.bind(mode[0]),"CalendarView_"+mode[0],"Afficher la vue "+mode[1],mode[0] == view_mode))
	bar.add_child(_action("‹",_shift_month.bind(-1),"MonthPrevious","Semaine précédente" if view_mode == "week" else "Mois précédent"))
	if not today.is_empty(): bar.add_child(_action("Aujourd’hui",_jump_to_today,"MonthToday"))
	bar.add_child(_action("›",_shift_month.bind(1),"MonthNext","Semaine suivante" if view_mode == "week" else "Mois suivant"))
	if show_table.is_valid(): bar.add_child(_action("Tableau",show_table,"CalendarShowTable","Tableau des rencontres"))
	var filters := HFlowContainer.new()
	filters.add_theme_constant_override("h_separation",C.px(8))
	filters.add_theme_constant_override("v_separation",C.px(8))
	rows.add_child(filters)
	for option: Array in [["all","Tout"],["matches","Matchs"],["training","Entraînements"],["absences","Absences / retours"],["travel","Matchs à l’extérieur"]]:
		filters.add_child(_action(option[1],_filter_by.bind(option[0]),"MonthFilter_"+option[0],"Filtrer le programme affiché · "+option[1],option[0] == filter))

func _jump_to_today() -> void:
	month = today.left(7)
	_select(today)

func _action(caption: String, callback: Callable, id: String, tooltip: String = "", active: bool = false) -> Button:
	var control := C.button(caption, callback, active, app.accent)
	control.name = id
	control.custom_minimum_size = Vector2(C.px(40),C.px(34))
	control.add_theme_font_size_override("font_size", maxi(16,C.px(18)))
	control.tooltip_text = tooltip
	control.focus_entered.connect(_remember_focus.bind(id))
	if not tooltip.is_empty(): control.accessibility_name = tooltip
	return control

func _grid(parent: Node) -> void:
	var grid := C.v(0)
	grid.name = "CalendarMonthGrid"
	parent.add_child(grid)
	var weekdays := C.h(0)
	grid.add_child(weekdays)
	for index in 7:
		var card := C.card()
		var heading_style := C.box(Color("202c29") if index < 5 else Color("24332c"), Color.TRANSPARENT, 0, 8)
		heading_style.set_corner_radius_all(0)
		card.add_theme_stylebox_override("panel", heading_style)
		var caption := C.label(SHORT_DAYS[index] if C.density < .67 else WEEKDAYS[index], 20, C.MUTED)
		C.content(card).add_child(caption)
		weekdays.add_child(C.fill(card))
	var first := month + "-01"
	var offset := _weekday(first)
	var count := _month_length(month.left(4).to_int(), month.right(2).to_int())
	var start := int(Time.get_unix_time_from_datetime_string(first + "T00:00:00")) - offset * DAY_SECONDS
	var weeks := ceili(float(offset + count) / 7.0)
	var height := 96 if weeks == 6 else 110
	for row_index in weeks:
		var week := C.h(0)
		grid.add_child(week)
		for day_index in 7:
			var epoch := start + (row_index*7 + day_index) * DAY_SECONDS
			var date := Time.get_date_string_from_unix_time(epoch)
			week.add_child(_day(date, day_index >= 5, height))

func _week_grid(parent: Node) -> void:
	var grid := C.h(0)
	grid.name = "CalendarWeekGrid"
	parent.add_child(grid)
	for date: String in Agenda.week(selected):
		grid.add_child(_day(date,_weekday(date) >= 5,210))

func _day_fixtures(date: String) -> Array:
	if filter not in ["all","matches","travel"]: return []
	var result: Array = fixtures_by_day.get(date,[])
	return result.filter(func(fixture: Dictionary): return P.fixture_location_kind(fixture,_club_id()) == "away") if filter == "travel" else result

func _day_sessions(date: String) -> Array:
	return sessions_by_day.get(date,[]) if filter in ["all","training"] else []

func _absence_events(date: String) -> Array[Dictionary]:
	if filter in ["all","absences"]: return Agenda.absence_events(app.model,date)
	var empty: Array[Dictionary] = []
	return empty

func _day(date: String, weekend: bool, height: int) -> Button:
	var cell := Button.new()
	cell.name = "MonthDay_" + date
	cell.set_meta("date", date)
	cell.set_meta("immersive_style_applied",true)
	cell.custom_minimum_size.x = C.px(126)
	C.fill(cell)
	var outside := not date.begins_with(month)
	var past := not today.is_empty() and date < today
	var current := date == today
	var selected_day := date == selected
	var countdown: bool = not today.is_empty() and not next_fixture.is_empty() and date >= today and date < next_fixture.date
	cell.set_meta("countdown", countdown)
	var remaining := _days_before(date, next_fixture.date) if countdown else 0
	var fill := Color("1a2825") if weekend else Color("172326")
	var border := Color("354542")
	if outside or past: fill = Color("111a1d") if outside else Color("141e21")
	if selected_day: fill = fill.lerp(app.accent, .20)
	if current: fill = Color("22372f")
	if current: border = C.MINT
	elif selected_day: border = C.IVORY
	for state in ["normal","hover","pressed"]:
		var background := fill.lightened(.07) if state == "hover" else fill
		var style := C.box(background, border, 0, 0)
		style.set_corner_radius_all(0)
		style.border_color = border
		if selected_day or current: style.set_border_width_all(2)
		cell.add_theme_stylebox_override(state, style)
	var focus := C.box(Color.TRANSPARENT, C.IVORY, 0, 0)
	focus.set_corner_radius_all(0)
	focus.set_border_width_all(2)
	cell.add_theme_stylebox_override("focus", focus)
	cell.pressed.connect(_select.bind(date))
	cell.focus_entered.connect(_remember_focus.bind(str(cell.name)))
	cell.gui_input.connect(_day_key.bind(date))
	cell.accessibility_name = _display_date(date)
	if current: cell.accessibility_name += " · Aujourd’hui"
	if selected_day: cell.accessibility_name += " · Jour sélectionné"
	var margin := C.margin(6)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var lines := C.v(4)
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(lines)
	var head := C.h(4)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.add_child(head)
	var date_label := C.label((SHORT_DAYS[_weekday(date)] + " " if view_mode == "week" else "") + str(date.right(2).to_int()), 22, C.MUTED if outside or past else C.IVORY, true, 700)
	head.add_child(C.fill(date_label))
	if current:
		head.add_child(_pill("AUJOURD’HUI", Color("bce8dc"), Color("173631"), 15))
	elif selected_day:
		head.add_child(_pill("SÉLECTION", C.IVORY, Color("202829"), 15))
	if remaining > 0 and remaining <= 7 and not current and not selected_day:
		head.add_child(C.label("J−%d" % remaining, 17, C.GOLD, true, 700))
	for session: Dictionary in _day_sessions(date): lines.add_child(_session_chip(session))
	for fixture: Dictionary in _day_fixtures(date): lines.add_child(_match_chip(fixture))
	var absences := _absence_events(date)
	if not absences.is_empty(): lines.add_child(_absence_chip(absences))
	if view_mode == "week" and lines.get_child_count() == 1:
		lines.add_child(C.wrap("Aucun événement publié pour ce filtre.",16,C.FAINT))
		var next := _next_event_after(date)
		if not next.is_empty(): lines.add_child(C.wrap(next,16,C.MUTED))
	cell.custom_minimum_size.y = maxi(C.px(height), ceili(lines.get_combined_minimum_size().y) + 2*C.px(6))
	cell.clip_contents = true
	return cell

func _day_key(event: InputEvent, date: String) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or event.ctrl_pressed or event.alt_pressed: return
	var distance: int = {KEY_LEFT:-1,KEY_RIGHT:1,KEY_UP:-7,KEY_DOWN:7}.get(event.keycode,0)
	if distance == 0: return
	var target := Agenda.shift(date,distance)
	if target.is_empty(): return
	get_viewport().set_input_as_handled()
	_select(target)

static func _days_before(start: String, finish: String) -> int:
	return roundi((Time.get_unix_time_from_datetime_string(finish+"T00:00:00") - Time.get_unix_time_from_datetime_string(start+"T00:00:00")) / DAY_SECONDS)

func _club_id() -> Variant:
	return app.model.get("club", {}).get("id")

func _opponent(fixture: Dictionary) -> Dictionary:
	var home: Dictionary = fixture.get("home", {})
	return fixture.get("away", {}) if home.get("id") == _club_id() else home

func _score(fixture: Dictionary) -> String:
	var result: Variant = fixture.get("score")
	if not result is Array or result.size() != 2: return ""
	var side := 0 if fixture.get("home", {}).get("id") == _club_id() else 1
	return "%s–%s" % [G.n(result[side]), G.n(result[1-side])]

func _match_chip(fixture: Dictionary) -> PanelContainer:
	var played: bool = fixture.get("played", false)
	var location := P.fixture_location_kind(fixture, _club_id())
	var base := Color("342d20")
	if location == "away": base = Color("382923")
	elif location == "neutral": base = Color("2c2d41")
	if played: base = Color("203644")
	var panel := _tile(base, Color("61788b") if played else Color("876e4d"), 4)
	panel.name = "MonthMatch_" + str(fixture.get("id","")).validate_node_name()
	panel.set_meta("fixture_id", fixture.get("id"))
	var row := C.h(5)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)
	var club := _opponent(fixture)
	row.add_child(G.crest(club,C.px(32)))
	var text := C.v(0)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(C.fill(text))
	var caption := C.label(G.club_name(club), 18, C.IVORY, true, 700)
	caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text.add_child(caption)
	var time := str(fixture.get("kickoffLocal","")) if fixture.get("kickoffLocal") is String else ""
	var note := _score(fixture) if played else time
	if not note.is_empty(): text.add_child(C.label(note, 18, C.MUTED))
	row.add_child(C.icon(C.fixture_location_icon(location, true), 19, C.GOLD))
	panel.accessibility_name = "Match · %s · %s" % [caption.text, str(PLACES.get(location, ""))]
	if not note.is_empty(): panel.accessibility_name += " · " + note
	return panel

func _open_absences() -> void:
	_remember_focus("CalendarOpenAbsences")
	app.management_ui.international_section = "availability"
	app._navigate("Sélections")

func _absence_chip(events: Array[Dictionary], expanded: bool = false) -> PanelContainer:
	var returning := events.filter(func(event: Dictionary): return event.kind == "return")
	var absent := events.size()-returning.size()
	var panel := _tile(Color("26303e"),C.BLUE,5)
	panel.name = "CalendarAbsence_"+str(events[0].id).validate_node_name()
	panel.set_meta("event_count",events.size())
	var body := C.v(4)
	panel.add_child(body)
	var captions: Array[String] = []
	if absent > 0: captions.append(_plural(absent,"en sélection","en sélection"))
	if not returning.is_empty(): captions.append(_plural(returning.size(),"retour au club","retours au club"))
	body.add_child(C.wrap(" · ".join(captions),20,C.BLUE,true,700))
	var names: Array[String] = []
	for event: Dictionary in events:
		var player: Dictionary = event.player
		var text := str(player.get("name","Joueur")) + " · " + str(player.get("nationName","Sélection"))
		names.append(text)
		if expanded: body.add_child(C.wrap(text,20,C.IVORY))
	panel.accessibility_name = " · ".join(captions)+" · "+" ; ".join(names)
	panel.tooltip_text = panel.accessibility_name
	if expanded:
		body.add_child(C.wrap("Convocations confirmées et dates de retour publiées. Consultez la fiche au retour pour la condition physique.",18,C.MUTED))
		body.add_child(_action("Consulter les disponibilités",_open_absences,"CalendarOpenAbsences"))
	return panel

func _session_chip(session: Dictionary, expanded: bool = false) -> PanelContainer:
	var past := not today.is_empty() and str(session.date) < today
	var panel := _tile(Color("1b2929") if past else Color("1b3631"), Color("3c5450") if past else Color("579284"), 4)
	panel.name = "MonthSession_" + str(session.get("id","")).validate_node_name()
	panel.set_meta("completed", past)
	panel.set_meta("date", session.date)
	var row := C.h(6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)
	row.add_child(_session_icon(str(session.get("kind","team"))))
	var text := C.v(0)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(C.fill(text))
	var label := str(session.get("label","Entraînement"))
	var caption := C.label(label, 18, C.MUTED if past else Color("d8eee7"), true, 700)
	caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text.add_child(caption)
	var forwards := _caption(session.get("forwards"))
	var backs := _caption(session.get("backs"))
	for group: Array in [["Avants",forwards],["Trois-quarts" if expanded else "3/4",backs]]:
		if group[1].is_empty() or not expanded: continue
		var line := C.label("%s · %s" % group, 16, C.MUTED)
		line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		text.add_child(line)
	panel.accessibility_name = label + (" · Créneau passé" if past else "")
	if not forwards.is_empty(): panel.accessibility_name += " · Avants : " + forwards
	if not backs.is_empty(): panel.accessibility_name += " · Trois-quarts : " + backs
	panel.tooltip_text = panel.accessibility_name
	if past:
		var clock := C.icon("clock", 17, C.MUTED)
		clock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(clock)
	return panel

static func _caption(value: Variant) -> String:
	return value if value is String else ""

static func _session_icon(kind: String) -> TextureRect:
	if not ICON_PATHS.has(kind): kind = "team"
	if not _icons.has(kind):
		var image := Image.new()
		var color: Color = ICON_COLORS[kind]
		var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="72" height="72" viewBox="0 0 24 24"><path d="%s" fill="#%s" fill-rule="evenodd"/></svg>' % [ICON_PATHS[kind],color.to_html(false)]
		if image.load_svg_from_string(svg) == OK: _icons[kind] = ImageTexture.create_from_image(image)
	var icon := TextureRect.new()
	icon.texture = _icons.get(kind)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(C.px(20), C.px(20))
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon

static func _tile(base: Color, border: Color, padding: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", C.box(base,border,6,padding))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return panel

static func _pill(caption: String, background: Color, foreground: Color, font_size: int = 19) -> PanelContainer:
	var panel := _tile(background, Color.TRANSPARENT, 3)
	panel.add_child(C.label(caption,font_size,foreground,true,700))
	return panel

func _legend(parent: Node) -> void:
	var pad := C.margin(9)
	parent.add_child(pad)
	var legend := C.h(12)
	pad.add_child(legend)
	for key: String in PLACES:
		legend.add_child(C.icon(C.fixture_location_icon(key, true), 21, C.GOLD))
		legend.add_child(C.label(PLACES[key], 17, C.MUTED))
	legend.add_child(_session_icon("strength"))
	legend.add_child(C.label("Entraînement", 17, C.MUTED))
	legend.add_child(C.icon("clock", 21, C.MUTED))
	legend.add_child(C.label("Créneau passé",17,C.MUTED))

func _next_event_after(date: String) -> String:
	var upcoming: Array = fixtures.filter(func(fixture: Dictionary): return fixture.date > date)
	upcoming.sort_custom(func(a: Dictionary,b: Dictionary): return a.date < b.date)
	if upcoming.is_empty(): return ""
	return "Prochain match publié · %s/%s" % [str(upcoming[0].date).right(2),str(upcoming[0].date).substr(5,2)]

func _context_panels(parent: Node) -> void:
	var padding := C.margin(10)
	parent.add_child(padding)
	var row := C.h(12)
	padding.add_child(row)
	var upcoming := C.card()
	upcoming.name = "CalendarUpcomingContext"
	row.add_child(C.fill(upcoming))
	var list := C.content(upcoming)
	list.add_child(C.label("PROCHAINS RENDEZ-VOUS PUBLIÉS",19,C.GOLD,true,700))
	var reference := selected if today.is_empty() or selected >= today else today
	var next_games: Array = fixtures.filter(func(fixture: Dictionary): return fixture.date >= reference and not fixture.get("played",false))
	next_games.sort_custom(func(a: Dictionary,b: Dictionary): return a.date < b.date if a.date != b.date else Agenda.fixture_key(a) < Agenda.fixture_key(b))
	if next_games.is_empty(): list.add_child(C.wrap("Aucune prochaine rencontre datée dans le calendrier publié.",17,C.MUTED))
	for fixture: Dictionary in next_games.slice(0,3):
		var line := C.h(8)
		list.add_child(line)
		line.add_child(C.label(str(fixture.date).right(2)+"/"+str(fixture.date).substr(5,2),18,C.GOLD,true,700))
		var text := C.label(G.club_name(_opponent(fixture)),18,C.IVORY,true,600)
		text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		line.add_child(C.fill(text))
		var place := P.fixture_location_kind(fixture,_club_id())
		line.add_child(C.label(str(PLACES.get(place,"")),16,C.MUTED))
		line.add_child(_action("Voir",_select.bind(fixture.date),"CalendarUpcoming_"+str(fixture.get("id",fixture.date)).validate_node_name(),"Voir le programme du "+_display_date(fixture.date)))
	var chart := C.card()
	chart.name = "CalendarSessionChart"
	row.add_child(C.fill(chart))
	var content := C.content(chart)
	content.add_child(C.label("SÉANCES PUBLIÉES · SEMAINE SÉLECTIONNÉE",19,C.MINT,true,700))
	var bars := C.h(8)
	content.add_child(bars)
	var dates := Agenda.week(selected)
	var maximum := 1
	for day: String in dates: maximum = maxi(maximum,sessions_by_day.get(day,[]).size())
	for day: String in dates:
		var column := C.v(3)
		bars.add_child(C.fill(column))
		var count: int = sessions_by_day.get(day,[]).size()
		var number := C.label(str(count),18,C.MINT,true,700)
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(number)
		var bar := ProgressBar.new()
		bar.name = "CalendarSessionCount_"+day
		bar.max_value = maximum
		bar.value = count
		bar.show_percentage = false
		bar.fill_mode = ProgressBar.FILL_BOTTOM_TO_TOP
		bar.custom_minimum_size = Vector2(C.px(22),C.px(58))
		bar.add_theme_stylebox_override("background",C.box(Color("142321"),Color.TRANSPARENT,3,0))
		bar.add_theme_stylebox_override("fill",C.box(Color("539d85"),Color.TRANSPARENT,3,0))
		bar.tooltip_text = _display_date(day)+" · "+str(count)+" créneau(x) publié(s)"
		column.add_child(bar)
		var label := C.label(SHORT_DAYS[_weekday(day)],16,C.MUTED)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(label)
	content.add_child(C.wrap("Comptage des créneaux, sans estimation de charge physique.",16,C.FAINT))

func _detail(parent: Node) -> void:
	var card := C.card("",Vector2(420,0))
	card.name = "MonthDayDetail"
	card.add_theme_stylebox_override("panel", C.box(C.PANEL,Color("425751"),10,14))
	parent.add_child(card)
	var body := C.content(card)
	var heading := "PROGRAMME DU JOUR" if selected == today else "JOUR SÉLECTIONNÉ"
	body.add_child(C.label(heading,20,C.MINT if selected == today else C.IVORY,true,700))
	var title := "Aujourd’hui · " + _display_date(selected) if selected == today else _display_date(selected)
	body.add_child(C.wrap(title,24,C.IVORY,true,700))
	if selected != today and not today.is_empty() and selected > today and not next_fixture.is_empty() and selected < next_fixture.date:
		var remaining := _days_before(selected,next_fixture.date)
		if remaining <= 7:
			body.add_child(C.label("À cette date · J−%d" % remaining,19,C.GOLD,true,600))
	var day_sessions: Array = _day_sessions(selected)
	var day_fixtures: Array = _day_fixtures(selected)
	var day_absences := _absence_events(selected)
	for session: Dictionary in day_sessions: body.add_child(_session_chip(session, true))
	for fixture: Dictionary in day_fixtures: body.add_child(_fixture_detail(fixture))
	if not day_absences.is_empty(): body.add_child(_absence_chip(day_absences,true))
	if day_sessions.is_empty() and day_fixtures.is_empty() and day_absences.is_empty():
		body.add_child(C.wrap("Aucun événement correspondant au filtre dans les données publiées pour ce jour.",20,C.MUTED))
	if selected == today and filter in ["all","training"]:
		body.add_child(_action("Entraînement de la semaine", _open_training_today, "CalendarOpenTraining"))
	var next_visible := filter != "travel" or P.fixture_location_kind(next_fixture,_club_id()) == "away"
	if filter in ["all","matches","travel"] and next_visible and not next_fixture.is_empty() and selected != next_fixture.date:
		body.add_child(C.rule())
		var distance := _days_before(today,next_fixture.date) if not today.is_empty() else 0
		var caption := "PROCHAIN MATCH"
		if distance > 0:
			caption += (" · J−%d" if selected == today else " · AUJOURD’HUI J−%d") % distance
		body.add_child(C.wrap(caption,20,C.GOLD,true,700))
		body.add_child(_fixture_detail(next_fixture))
	if filter in ["all","training"] and not next_fixture.is_empty():
		_preparation(body)
		_templates(body)

func _open_training_today() -> void:
	_remember_focus("CalendarOpenTraining")
	if app.management_ui.get("immersive_training") is Dictionary:
		app.management_ui.immersive_training.tab = 0
		app.management_ui.immersive_training.slot = 0
	if app.management_ui.get("preparation") is Dictionary:
		app.management_ui.preparation.outer[2] = 0
		app.management_ui.preparation.focus[2] = "PreparationTabEntrainement"
	app.Immersive.open_training(app)
	var tab := app.find_child("TrainingTab0", true, false) as Button
	if tab == null: tab = app.find_child("PreparationTabEntrainement", true, false) as Button
	if tab != null: tab.grab_focus.call_deferred()

func _open_preparation(fixture: Dictionary) -> void:
	_remember_focus("CalendarOpenFixture_"+str(fixture.get("id","")).validate_node_name())
	app._navigate("Préparation")

func _fixture_detail(fixture: Dictionary) -> PanelContainer:
	var panel := C.card()
	panel.add_theme_stylebox_override("panel",C.box(Color("25372f"), Color("89744f"), 7, 10))
	var body := C.content(panel)
	var opponent := _opponent(fixture)
	var matchup := C.h(10)
	body.add_child(matchup)
	matchup.add_child(G.crest(app.model.club,C.px(50)))
	var points := _score(fixture)
	matchup.add_child(C.label(points if not points.is_empty() else "VS",24,C.GOLD,true,700))
	matchup.add_child(G.crest(opponent,C.px(50)))
	body.add_child(C.wrap(G.club_name(opponent),24,C.IVORY,true,700))
	var place := P.fixture_location_kind(fixture, _club_id())
	var metadata := PackedStringArray()
	if PLACES.has(place): metadata.append(PLACES[place])
	var venue := P.fixture_venue(fixture)
	if not venue.is_empty() and not metadata.has(venue): metadata.append(venue)
	var date := P.fixture_date(fixture,true)
	if not date.is_empty(): metadata.append(date)
	if not metadata.is_empty(): body.add_child(C.wrap(" · ".join(metadata),20,C.MUTED))
	if place == "away": body.add_child(C.wrap("Match à l’extérieur · aucune date de voyage distincte n’est publiée.",18,C.GOLD))
	if not fixture.get("played",false) and app.model.get("next") is Dictionary and Agenda.fixture_key(fixture) == Agenda.fixture_key(app.model.next):
		body.add_child(_action("Préparer ce match",_open_preparation.bind(fixture),"CalendarOpenFixture_"+str(fixture.get("id","")).validate_node_name()))
	return panel

func _preparation(body: VBoxContainer) -> void:
	var related := sessions.filter(func(session: Dictionary) -> bool:
		return next_fixture.has("id") and session.get("fixtureId") == next_fixture.id
	)
	if related.is_empty(): return
	related.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return left.date < right.date)
	body.add_child(C.rule())
	body.add_child(C.label("FIL DE PRÉPARATION",20,C.GOLD,true,700))
	body.add_child(C.wrap(G.club_name(_opponent(next_fixture)),21,C.IVORY,true,700))
	for session: Dictionary in related:
		var label := "%s/%s   %s" % [session.date.right(2),session.date.substr(5,2),session.get("label","Entraînement")]
		body.add_child(C.wrap(label,18,C.MUTED))

func _templates(body: VBoxContainer) -> void:
	var templates: Array = planning.get("templates", [])
	var fixture_id: Variant = next_fixture.get("id")
	if templates.is_empty() or not fixture_id is String or fixture_id.is_empty(): return
	body.add_child(C.rule())
	body.add_child(C.label("SEMAINES TYPES",20,C.GOLD,true,700))
	if not app._live().is_empty():
		var unavailable := C.wrap("Les semaines types sont indisponibles jusqu’à la validation du résultat.",18,C.MUTED)
		unavailable.name = "CalendarTemplateUnavailable"
		body.add_child(unavailable)
		return
	var assignments: Dictionary = planning.get("appliedTemplates", {})
	var active_template: Variant = assignments.get(fixture_id)
	var chooser := OptionButton.new()
	chooser.name = "CalendarTemplate"
	chooser.accessibility_name = "Modèle de semaine"
	chooser.tooltip_text = "Choisissez une semaine type pour rendre le bouton Appliquer disponible."
	chooser.add_theme_font_override("font", C.DISPLAY)
	chooser.add_theme_font_size_override("font_size", maxi(16,C.px(18)))
	chooser.custom_minimum_size.y = C.px(32)
	chooser.add_item("Choisir un modèle…")
	chooser.set_item_disabled(0, true)
	for template: Dictionary in templates:
		var label := str(template.get("label","Semaine type"))
		chooser.add_item(label)
		chooser.set_item_metadata(chooser.item_count-1, template.get("id"))
		if active_template is String and template.get("id") == active_template:
			var active := C.wrap("En place · " + label,18,C.MINT,true,700)
			active.name = "CalendarAppliedTemplate"
			body.add_child(active)
			chooser.set_item_disabled(chooser.item_count-1, true)
	body.add_child(chooser)
	chooser.select(0)
	var apply := _action("Appliquer au prochain match", func():
		if chooser.selected > 0:
			app._command("calendar_template", {"fixtureId":fixture_id,"template":chooser.get_item_metadata(chooser.selected)})
	, "CalendarApplyTemplate", "Choisissez un modèle de semaine avant de l’appliquer.")
	apply.disabled = true
	chooser.item_selected.connect(func(index: int): apply.disabled = index < 1)
	body.add_child(apply)

func _undated_panel() -> void:
	if undated.is_empty(): return
	var panel := C.card("À programmer")
	add_child(panel)
	var body := C.content(panel)
	body.add_child(C.wrap("Les rencontres sans date fixée restent visibles ici.",19,C.MUTED))
	for fixture: Dictionary in undated:
		var caption := G.club_name(_opponent(fixture)) + " · " + str(fixture.get("label","Rencontre"))
		body.add_child(C.wrap(caption,19,C.IVORY,true))

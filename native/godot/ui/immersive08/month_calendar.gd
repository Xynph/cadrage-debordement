extends VBoxContainer
## Calendrier de carrière : la date simulée et le programme viennent du moteur.

const C = preload("res://ui/immersive08/components.gd")
const G = preload("res://ui/game_skin.gd")
const P = preload("res://ui/immersive08/projection.gd")
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
	for fixture: Dictionary in planning.get("fixtures", app.model.get("calendar", [])):
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
	if reading.get("today") == today and not remembered.is_empty():
		initial = remembered
		filter = str(reading.get("filter", "all"))
	month = initial.left(7)
	selected = initial
	_refresh()

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
	filter = value
	_refresh()
	var target := find_child("MonthFilter_" + value, true, false) as Control
	if target != null: target.call_deferred("grab_focus")

func _refresh() -> void:
	app.management_ui["calendar_reading"] = {"today":today, "selected":selected, "filter":filter}
	for child in get_children():
		remove_child(child)
		child.queue_free()
	if month.is_empty():
		_heading("Calendrier", "Les dates n’ont pas encore été fixées.", 0, 0)
		_undated_panel()
		return
	var month_name: String = MONTHS[month.right(2).to_int()-1]
	var current_fixtures := fixtures.filter(func(fixture: Dictionary) -> bool: return fixture.date.begins_with(month))
	var current_sessions := sessions.filter(func(session: Dictionary) -> bool: return session.date.begins_with(month))
	var venues := {"home":0,"away":0,"neutral":0}
	for fixture: Dictionary in current_fixtures:
		var location := P.fixture_location_kind(fixture, _club_id())
		if venues.has(location): venues[location] += 1
	var summary := PackedStringArray()
	if venues.home > 0: summary.append(_plural(venues.home, "réception", "réceptions"))
	if venues.away > 0: summary.append(_plural(venues.away, "déplacement", "déplacements"))
	if venues.neutral > 0: summary.append(_plural(venues.neutral, "match sur terrain neutre", "matchs sur terrain neutre"))
	var description := "Aucune rencontre programmée ce mois-ci." if summary.is_empty() else "Ce mois-ci · " + " · ".join(summary)
	_heading(month_name, description, current_fixtures.size(), current_sessions.size())
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
	_grid(body)
	_legend(body)
	_detail(workspace)
	_undated_panel()

static func _plural(count: int, singular: String, plural: String) -> String:
	return "%d %s" % [count, singular if count == 1 else plural]

func _heading(title: String, description: String, match_count: int, session_count: int) -> void:
	var panel := C.card("", Vector2(0,146))
	var ink := Color("182824").lerp(app.accent, .12)
	var edge := C.box(ink, Color("50665e"), 10, 20)
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
	body.add_child(C.label(("SAISON %s   /   %s" % [season, league]).to_upper(), 21, C.GOLD, true, 700))
	var heading := title if month.is_empty() else title + " " + month.left(4)
	body.add_child(C.label(heading, 53, C.IVORY, true, 800))
	var line := C.h(12)
	body.add_child(line)
	var subtitle := C.label(description, 19, C.IVORY, false)
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
	var bar := C.h(8)
	padding.add_child(bar)
	var caption := C.label("Planning du club", 26, C.IVORY, true, 700)
	caption.name = "MonthCalendarCaption"
	caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	bar.add_child(C.fill(caption))
	if planning.get("simulatedDates", false):
		bar.add_child(_pill("Dates simulées", Color("263432"), C.MUTED, 16))
	bar.add_child(_action("‹", _shift_month.bind(-1), "MonthPrevious", "Mois précédent"))
	if not today.is_empty():
		bar.add_child(_action("Aujourd’hui", _jump_to_today, "MonthToday"))
	bar.add_child(_action("›", _shift_month.bind(1), "MonthNext", "Mois suivant"))
	for option: Array in [["all","Tout"],["matches","Matchs"],["training","Entraînements"]]:
		var id: String = option[0]
		bar.add_child(_action(option[1], _filter_by.bind(id), "MonthFilter_" + id, "", id == filter))
	if show_table.is_valid():
		bar.add_child(_action("Tableau", show_table, "CalendarShowTable", "Tableau des rencontres"))

func _jump_to_today() -> void:
	month = today.left(7)
	_select(today)

func _action(caption: String, callback: Callable, id: String, tooltip: String = "", active: bool = false) -> Button:
	var control := C.button(caption, callback, active, app.accent)
	control.name = id
	control.custom_minimum_size = Vector2(C.px(40),C.px(34))
	control.add_theme_font_size_override("font_size", maxi(12,C.px(19)))
	control.tooltip_text = tooltip
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
	var height := 125 if weeks == 6 else 145
	for row_index in weeks:
		var week := C.h(0)
		grid.add_child(week)
		for day_index in 7:
			var epoch := start + (row_index*7 + day_index) * DAY_SECONDS
			var date := Time.get_date_string_from_unix_time(epoch)
			week.add_child(_day(date, day_index >= 5, height))

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
	var date_label := C.label(date.right(2).to_int(), 25, C.MUTED if outside or past else C.IVORY, true, 700)
	head.add_child(C.fill(date_label))
	if current:
		head.add_child(_pill("AUJOURD’HUI", Color("bce8dc"), Color("173631"), 15))
	elif selected_day:
		head.add_child(_pill("SÉLECTION", C.IVORY, Color("202829"), 15))
	if remaining > 0 and remaining <= 7 and not current and not selected_day:
		head.add_child(C.label("J−%d" % remaining, 17, C.GOLD, true, 700))
	if filter != "matches":
		for session: Dictionary in sessions_by_day.get(date, []): lines.add_child(_session_chip(session))
	if filter != "training":
		for fixture: Dictionary in fixtures_by_day.get(date, []): lines.add_child(_match_chip(fixture))
	cell.custom_minimum_size.y = maxi(C.px(height), ceili(lines.get_combined_minimum_size().y) + 2*C.px(6))
	cell.clip_contents = true
	return cell

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
	if not note.is_empty(): text.add_child(C.label(note, 16, C.MUTED))
	row.add_child(C.icon(C.fixture_location_icon(location, true), 19, C.GOLD))
	panel.accessibility_name = "Match · %s · %s" % [caption.text, str(PLACES.get(location, ""))]
	if not note.is_empty(): panel.accessibility_name += " · " + note
	return panel

func _session_chip(session: Dictionary, expanded: bool = false) -> PanelContainer:
	var done := not today.is_empty() and str(session.date) < today
	var panel := _tile(Color("1b2929") if done else Color("1b3631"), Color("3c5450") if done else Color("579284"), 4)
	panel.name = "MonthSession_" + str(session.get("id","")).validate_node_name()
	panel.set_meta("completed", done)
	panel.set_meta("date", session.date)
	var row := C.h(6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)
	row.add_child(_session_icon(str(session.get("kind","team"))))
	var text := C.v(0)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(C.fill(text))
	var label := str(session.get("label","Entraînement"))
	var caption := C.label(label, 19, C.MUTED if done else Color("d8eee7"), true, 700)
	caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text.add_child(caption)
	var forwards := _caption(session.get("forwards"))
	var backs := _caption(session.get("backs"))
	for group: Array in [["Avants",forwards],["Trois-quarts" if expanded else "3/4",backs]]:
		if group[1].is_empty(): continue
		var line := C.label("%s · %s" % group, 16, C.MUTED)
		line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		text.add_child(line)
	panel.accessibility_name = label + (" · Séance effectuée" if done else "")
	if not forwards.is_empty(): panel.accessibility_name += " · Avants : " + forwards
	if not backs.is_empty(): panel.accessibility_name += " · Trois-quarts : " + backs
	if done:
		var check := C.icon("check", 17, Color("86b6a2"))
		check.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(check)
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
	legend.add_child(C.icon("check", 21, Color("86b6a2")))
	legend.add_child(C.label("Séance effectuée",17,C.MUTED))

func _detail(parent: Node) -> void:
	var card := C.card("",Vector2(402,0))
	card.name = "MonthDayDetail"
	card.add_theme_stylebox_override("panel", C.box(C.PANEL,Color("425751"),10,14))
	parent.add_child(card)
	var body := C.content(card)
	var heading := "PROGRAMME DU JOUR" if selected == today else "JOUR SÉLECTIONNÉ"
	body.add_child(C.label(heading,20,C.MINT if selected == today else C.IVORY,true,700))
	var title := "Aujourd’hui · " + _display_date(selected) if selected == today else _display_date(selected)
	body.add_child(C.wrap(title,27,C.IVORY,true,700))
	if selected != today and not today.is_empty() and selected > today and not next_fixture.is_empty() and selected < next_fixture.date:
		var remaining := _days_before(selected,next_fixture.date)
		if remaining <= 7:
			body.add_child(C.label("À cette date · J−%d" % remaining,19,C.GOLD,true,600))
	var day_sessions: Array = sessions_by_day.get(selected, [])
	var day_fixtures: Array = fixtures_by_day.get(selected, [])
	for session: Dictionary in day_sessions: body.add_child(_session_chip(session, true))
	for fixture: Dictionary in day_fixtures: body.add_child(_fixture_detail(fixture))
	if day_sessions.is_empty() and day_fixtures.is_empty():
		body.add_child(C.wrap("Aucun événement prévu.",18,C.MUTED))
	if not next_fixture.is_empty() and selected != next_fixture.date:
		body.add_child(C.rule())
		var distance := _days_before(today,next_fixture.date) if not today.is_empty() else 0
		var caption := "PROCHAIN MATCH"
		if distance > 0:
			caption += (" · J−%d" if selected == today else " · AUJOURD’HUI J−%d") % distance
		body.add_child(C.wrap(caption,20,C.GOLD,true,700))
		body.add_child(_fixture_detail(next_fixture))
	if not next_fixture.is_empty():
		_preparation(body)
		_templates(body)

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
	if not metadata.is_empty(): body.add_child(C.wrap(" · ".join(metadata),18,C.MUTED))
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
		var tag := "✓ " if not today.is_empty() and str(session.date) < today else ""
		var label := "%s%s/%s   %s" % [tag,session.date.right(2),session.date.substr(5,2),session.get("label","Entraînement")]
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
	var chooser := OptionButton.new()
	chooser.name = "CalendarTemplate"
	chooser.accessibility_name = "Modèle de semaine"
	chooser.tooltip_text = "Choisissez une semaine type pour rendre le bouton Appliquer disponible."
	chooser.add_theme_font_override("font", C.DISPLAY)
	chooser.add_theme_font_size_override("font_size", maxi(12,C.px(19)))
	chooser.custom_minimum_size.y = C.px(32)
	body.add_child(chooser)
	chooser.add_item("Choisir un modèle…")
	chooser.set_item_disabled(0, true)
	for template: Dictionary in templates:
		chooser.add_item(str(template.get("label","Semaine type")))
		chooser.set_item_metadata(chooser.item_count-1, template.get("id"))
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

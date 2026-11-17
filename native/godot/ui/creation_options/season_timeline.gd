extends RefCounted
## Écran « Options de carrière » · « Ta première saison » : frise horizontale de l'été, de la reprise des
## premiers clubs à la 1re journée (écusson de l'adversaire, date, domicile ou extérieur). Le départ choisi
## (premiers clubs, reprise du club, veille de la 1re journée) place le repère « Ton arrivée » ; les étapes
## d'avant sont menées sans toi. La frise suit le choix du départ sans reconstruire la page.
const C = preload("res://ui/immersive08/components.gd")
const Editorial = preload("res://ui/entry_editorial.gd")
const Kit = preload("res://ui/creation_options/kit.gd")
const STARTS := ["premiers-clubs", "club", "veille"]
const FIRST_CLUBS := "2026-07-13"

## Rend un Callable `refresh(start)` qui redessine la frise. `on_change(start)` est appelé après un nouveau
## choix de départ (bulle de Gabi, rendez-vous).
static func build(app: Control, parent: Node, selected: Dictionary, choosable: bool, data: Dictionary, state: String, on_change: Callable) -> Callable:
	var column := Kit.photo_block(parent, "CreationSeasonTimeline", "Ta première saison", "training-session", 1.0, true, .55, .8)
	var start := str(app.management_ui.get("creation_start", "premiers-clubs")) if choosable else ""
	var rail := C.h(0)
	rail.name = "CreationSeasonRail"
	rail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var refresh := func(value: String) -> void:
		for child in rail.get_children():
			rail.remove_child(child)
			child.queue_free()
		_fill(app, rail, selected, value, data, state)
	if choosable:
		var head := Kit.aside(column)
		var caption := C.label("Départ", 18, C.MUTED, false)
		caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		head.add_child(caption)
		var option := OptionButton.new()
		option.name = "CreationStartChoice"
		for text: String in ["Reprise des premiers clubs · lundi 13 juillet", "Reprise de ton club", "Veille de la 1re journée · début septembre"]: option.add_item(text)
		option.select(maxi(0, STARTS.find(start)))
		option.add_theme_font_size_override("font_size", maxi(13, C.px(20)))
		option.custom_minimum_size.y = maxi(26, C.px(38))
		option.disabled = app.waiting
		head.add_child(option)
		var sentence := C.wrap(Kit.entry().call("_career_start_sentence", app, start, selected), 18, C.IVORY)
		sentence.name = "CreationStartSentence"
		sentence.modulate = Color(1, 1, 1, .86)
		column.add_child(sentence)
		option.item_selected.connect(func(index: int) -> void:
			var chosen: String = STARTS[index]
			app.management_ui.creation_start = chosen
			sentence.text = Kit.entry().call("_career_start_sentence", app, chosen, selected)
			refresh.call(chosen)
			if on_change.is_valid(): on_change.call(chosen))
	column.add_child(rail)
	refresh.call(start)
	return refresh

static func _fill(app: Control, rail: HBoxContainer, selected: Dictionary, start: String, data: Dictionary, state: String) -> void:
	var reprise: Dictionary = data.get("reprise", {}) if data.get("reprise") is Dictionary else {}
	var division := str(selected.get("division", ""))
	var known: Dictionary = app.model.get("meta", {}).get("repriseCreation", {}).get(division, {})
	var club_date := str(reprise.get("club", known.get(str(int(selected.get("id", -1))), "")))
	var nodes: Array = []
	if not start.is_empty():
		nodes.append({"key":"first", "caption":"Premiers clubs", "date":str(reprise.get("firstClubs", FIRST_CLUBS)), "detail":"Le rugby reprend" if start != "premiers-clubs" else "Tu fixes la reprise"})
	var club_detail := "Ton groupe reprend"
	if start == "premiers-clubs": club_detail = "Date habituelle, à toi de choisir"
	elif start == "veille": club_detail = "Menée par le staff"
	nodes.append({"key":"club", "caption":"Reprise du club", "date":club_date, "detail":club_detail, "wait":club_date.is_empty() and state == "pending"})
	nodes.append({"key":"friendlies", "caption":"Amicaux"})
	if start == "veille":
		nodes.append({"key":"eve", "caption":"Veille du match", "date":str(reprise.get("eve", "")), "detail":"Dernière séance avant le match", "wait":state == "pending"})
	nodes.append({"key":"fixture", "caption":"1re journée"})
	var arrival := {"premiers-clubs":0, "club":1, "veille":3}.get(start, -1) as int
	for index in nodes.size():
		var node: Dictionary = nodes[index]
		var cell := C.v(5)
		cell.name = "CreationSeasonStep_" + str(node.key)
		cell.alignment = BoxContainer.ALIGNMENT_BEGIN
		C.fill(cell)
		rail.add_child(cell)
		var before := arrival >= 0 and index < arrival
		var here := index == arrival
		var head := C.h(6)
		head.alignment = BoxContainer.ALIGNMENT_CENTER
		cell.add_child(head)
		var caption := Kit.caps(str(node.caption), 17, Editorial.RAIL_GOLD if here else (C.MUTED if before else C.IVORY))
		head.add_child(caption)
		var dot := RailNode.new()
		dot.first = index == 0
		dot.last = index == nodes.size() - 1
		dot.arrival = here
		dot.before = before
		dot.after_arrival = arrival >= 0 and index >= arrival
		dot.reached_by_line = arrival >= 0 and index > arrival
		dot.custom_minimum_size.y = C.px(30)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.resized.connect(dot.queue_redraw)
		cell.add_child(dot)
		var body := C.v(2)
		body.alignment = BoxContainer.ALIGNMENT_BEGIN
		if before: body.modulate = Color(1, 1, 1, .55)
		cell.add_child(body)
		match str(node.key):
			"friendlies": _friendlies(body, data, start, state)
			"fixture": _fixture(app, body, data, state)
			_: _dated(body, str(node.get("date", "")), str(node.get("detail", "")), bool(node.get("wait", false)))
		if here:
			# Repère d'arrivée sous l'étape : les dates des étapes restent alignées.
			var mark := Kit.tag("Ton arrivée", Editorial.RAIL_GOLD)
			mark.name = "CreationSeasonArrival"
			mark.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			cell.add_child(mark)

## Date en grand (jour, mois, jour de la semaine) et une ligne d'explication.
static func _dated(parent: VBoxContainer, iso: String, detail: String, wait: bool) -> void:
	if iso.is_empty() and wait:
		_ghost_date(parent)
		return
	if iso.is_empty():
		var unknown := C.label("—", 40, C.MUTED, true, 800)
		unknown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		parent.add_child(unknown)
	else: parent.add_child(_big_date(iso))
	parent.add_child(_detail(detail))

static func _big_date(iso: String, size: int = 46) -> HBoxContainer:
	var date := Kit.parse(iso)
	var row := C.h(6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.name = "CreationSeasonDate"
	if date.is_empty(): return row
	var day := C.label(str(int(date.day)), size, C.IVORY, true, 800)
	day.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(day)
	var side := C.v(0)
	side.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(side)
	side.add_child(C.label(Kit.month(iso).to_upper(), 18, Editorial.RAIL_GOLD, true, 700))
	side.add_child(C.label(Kit.weekday(iso), 16, C.MUTED, false))
	row.tooltip_text = "%s %d %s %d" % [Kit.weekday(iso), int(date.day), Kit.month(iso), int(date.year)]
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	return row

static func _detail(text: String) -> Label:
	var label := C.wrap(text, 17, C.MUTED)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.max_lines_visible = 2
	return label

static func _ghost_date(parent: VBoxContainer) -> void:
	var row := C.h(6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(row)
	row.add_child(Kit.ghost(58, 44))
	var side := C.v(5)
	side.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(side)
	side.add_child(Kit.ghost(70, 14))
	side.add_child(Kit.ghost(50, 12))
	var line := C.h(0)
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(line)
	line.add_child(Kit.ghost(150, 13))

static func _friendlies(parent: VBoxContainer, data: Dictionary, start: String, state: String) -> void:
	var friendlies: Variant = data.get("friendlies")
	if state == "pending" and not friendlies is Dictionary:
		_ghost_date(parent)
		return
	if not friendlies is Dictionary or int((friendlies as Dictionary).get("count", 0)) <= 0:
		var plan := C.label("À bâtir", 34, C.IVORY, true, 800)
		plan.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		parent.add_child(plan)
		parent.add_child(_detail("Menés par le staff" if start == "veille" else "Programme à décider pendant la préparation"))
		return
	var count := int(friendlies.get("count", 0))
	var row := C.h(8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(row)
	var number := C.label(str(count), 46, C.IVORY, true, 800)
	number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(number)
	var side := C.v(2)
	side.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(side)
	side.add_child(C.label("MATCH AMICAL" if count == 1 else "MATCHS AMICAUX", 18, Editorial.RAIL_GOLD, true, 700))
	var note := Kit.tag("indicatif")
	note.name = "CreationFriendliesIndicative"
	note.tooltip_text = "Programme indicatif : il se décide pendant la préparation."
	note.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	side.add_child(note)
	var chips := HFlowContainer.new()
	chips.name = "CreationFriendlyDates"
	chips.alignment = FlowContainer.ALIGNMENT_CENTER
	chips.add_theme_constant_override("h_separation", C.px(5))
	chips.add_theme_constant_override("v_separation", C.px(4))
	parent.add_child(chips)
	var dates: Array = friendlies.get("dates", []) if friendlies.get("dates") is Array else []
	for iso: Variant in dates.slice(0, 4):
		var chip := Kit.tag(Kit.day_month(str(iso)), C.IVORY)
		chip.tooltip_text = Kit.short_date(str(iso))
		chips.add_child(chip)

static func _fixture(app: Control, parent: VBoxContainer, data: Dictionary, state: String) -> void:
	var fixture: Variant = data.get("firstFixture")
	if state == "pending" and not fixture is Dictionary:
		var row := C.h(8)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		parent.add_child(row)
		row.add_child(Kit.disc_ghost(46))
		var side := C.v(5)
		side.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_child(side)
		side.add_child(Kit.ghost(90, 26))
		side.add_child(Kit.ghost(60, 12))
		var line := C.h(0)
		line.alignment = BoxContainer.ALIGNMENT_CENTER
		parent.add_child(line)
		line.add_child(Kit.ghost(140, 13))
		return
	if not fixture is Dictionary:
		var later := C.label("Au calendrier", 30, C.IVORY, true, 800)
		later.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		parent.add_child(later)
		parent.add_child(_detail("La date et l’adversaire t’attendent dans ton calendrier"))
		return
	var match_day: Dictionary = fixture
	var iso := str(match_day.get("date", ""))
	var home := bool(match_day.get("home", true))
	var opponent := Kit.club_name(app, match_day.get("opponentId"), str(match_day.get("opponentName", "")))
	var row := C.h(10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(row)
	var badge := Kit.crest(app, match_day.get("opponentId"), opponent, C.px(50))
	badge.name = "CreationFirstFixtureCrest"
	row.add_child(badge)
	var side := C.v(0)
	side.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(side)
	side.add_child(C.label(Kit.day_month(iso) if not iso.is_empty() else "—", 32, C.IVORY, true, 800))
	var kickoff: Variant = match_day.get("kickoff")
	var when := Kit.weekday(iso)
	if kickoff != null and not str(kickoff).is_empty(): when += " · " + str(kickoff)
	# Domicile ou extérieur : pictogramme à côté du jour et de l'heure.
	var venue := C.h(5)
	venue.name = "CreationFirstFixtureVenue"
	side.add_child(venue)
	var place := C.icon(C.fixture_location_icon("home" if home else "away"), 17, C.MINT if home else C.GOLD)
	place.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	place.tooltip_text = "Domicile" if home else "Extérieur"
	place.mouse_filter = Control.MOUSE_FILTER_PASS
	venue.add_child(place)
	venue.add_child(C.label(when, 16, C.MUTED, false))
	# Adversaire sur toute la largeur de l'étape, centré (deux lignes au plus).
	var against := C.wrap(("Reçoit " if home else "À ") + opponent, 17, C.IVORY)
	against.name = "CreationFirstFixtureOpponent"
	against.tooltip_text = "%s · %s" % ["Domicile" if home else "Extérieur", opponent]
	against.mouse_filter = Control.MOUSE_FILTER_PASS
	against.max_lines_visible = 2
	against.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(against)

## Repère de la frise : trait continu d'une étape à l'autre, point plein pour l'arrivée.
class RailNode extends Control:
	var first := false
	var last := false
	var arrival := false
	var before := false
	var after_arrival := false
	var reached_by_line := false
	func _draw() -> void:
		var y := size.y / 2.0
		var center := Vector2(size.x / 2.0, y)
		var radius := maxf(3.0, size.y * .2)
		var gold := Editorial.RAIL_GOLD
		var faint := Color(C.MUTED, .45)
		var width := maxf(1.5, size.y * .07)
		if not first: draw_line(Vector2(0, y), Vector2(center.x, y), gold if reached_by_line or arrival else faint, width)
		if not last: draw_line(Vector2(center.x, y), Vector2(size.x, y), gold if after_arrival else faint, width)
		if arrival:
			draw_circle(center, radius * 2.0, Color(gold, .22))
			draw_circle(center, radius * 1.3, gold)
		elif before:
			draw_circle(center, radius, Kit.DEEP)
			draw_arc(center, radius, 0, TAU, 24, faint, width, true)
		else:
			draw_circle(center, radius, C.IVORY if after_arrival else Color(C.IVORY, .7))

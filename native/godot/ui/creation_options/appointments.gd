extends RefCounted
## Écran « Options de carrière » · « Les rendez-vous qui t'attendent » : conférence de presse d'arrivée,
## point avec la direction, puis les repères fixes de la saison (reprise des premiers clubs, retour des
## internationaux après la fenêtre d'été, tests de novembre). La date d'arrivée suit le départ choisi.
const C = preload("res://ui/immersive08/components.gd")
const Editorial = preload("res://ui/entry_editorial.gd")
const Kit = preload("res://ui/creation_options/kit.gd")
const FIRST_CLUBS := "2026-07-13"
const INTERNATIONALS_BACK := "2026-07-18"

## Rend un Callable `refresh(start)` qui réécrit la liste quand le départ change.
static func build(app: Control, parent: Node, selected: Dictionary, choosable: bool, data: Dictionary) -> Callable:
	var column := Kit.block(parent, "CreationAppointments", "Les rendez-vous qui t’attendent", 1.0, true)
	var list := C.v(9)
	list.name = "CreationAppointmentList"
	column.add_child(list)
	var refresh := func(start: String) -> void:
		for child in list.get_children():
			list.remove_child(child)
			child.queue_free()
		_fill(app, list, selected, start if choosable else "", data)
	refresh.call(str(app.management_ui.get("creation_start", "premiers-clubs")))
	return refresh

static func _arrival(app: Control, selected: Dictionary, start: String, data: Dictionary) -> String:
	var reprise: Dictionary = data.get("reprise", {}) if data.get("reprise") is Dictionary else {}
	match start:
		"premiers-clubs": return str(reprise.get("firstClubs", FIRST_CLUBS))
		"club":
			var known: Dictionary = app.model.get("meta", {}).get("repriseCreation", {}).get(str(selected.get("division", "")), {})
			return str(reprise.get("club", known.get(str(int(selected.get("id", -1))), "")))
		"veille": return str(reprise.get("eve", ""))
	return ""

static func _fill(app: Control, list: VBoxContainer, selected: Dictionary, start: String, data: Dictionary) -> void:
	var arrival := _arrival(app, selected, start, data)
	_row(list, "press", arrival, "Ton arrivée", "mail", "Conférence de presse d’arrivée", "Les journalistes t’attendent dès ton premier jour.", false)
	_row(list, "board", "", "1re semaine", "shield", "Point avec la direction", "Selon le club, le président fixe le cap avec toi.", false)
	var late := not start.is_empty() and start != "premiers-clubs"
	_row(list, "first_clubs", FIRST_CLUBS, "", "calendar", "Reprise des premiers clubs", "Avant ton arrivée : le championnat se remet au travail." if late else "Le championnat se remet au travail, toi avec.", late)
	_row(list, "internationals", INTERNATIONALS_BACK, "", "flag", "Retour des internationaux", "Après la fenêtre d’été, environ trois semaines de congés.", false)
	_row(list, "november", "", "Novembre", "globe", "Tests de novembre", "Tes internationaux rejoignent leur sélection.", false)

static func _row(list: VBoxContainer, key: String, iso: String, fallback: String, icon: String, title: String, detail: String, faded: bool) -> void:
	var row := C.h(12)
	row.name = "CreationAppointment_" + key
	if faded: row.modulate = Color(1, 1, 1, .55)
	list.add_child(row)
	var chip := PanelContainer.new()
	chip.set_meta("immersive_style_applied", true)
	var style := C.box(Kit.DEEP, Color(Editorial.RAIL_GOLD, .7) if key == "press" else Editorial.LINE, 0, 4)
	style.set_corner_radius_all(0)
	chip.add_theme_stylebox_override("panel", style)
	chip.custom_minimum_size = Vector2(C.px(92), C.px(54))
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(chip)
	var stamp := C.v(0)
	stamp.alignment = BoxContainer.ALIGNMENT_CENTER
	chip.add_child(stamp)
	var date := Kit.parse(iso)
	if date.is_empty():
		var word := C.label(fallback if not fallback.is_empty() else "—", 18, Editorial.RAIL_GOLD if key == "press" else C.IVORY, true, 700)
		word.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		word.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		stamp.add_child(word)
	else:
		var day := C.label(str(int(date.day)), 28, C.IVORY, true, 800)
		day.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stamp.add_child(day)
		var month := C.label(str(Kit.MONTHS_SHORT[int(date.month) - 1]).to_upper(), 15, Editorial.RAIL_GOLD, true, 700)
		month.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stamp.add_child(month)
		chip.tooltip_text = Kit.short_date(iso)
		chip.mouse_filter = Control.MOUSE_FILTER_PASS
	var pictogram := C.icon(icon, 22, Editorial.RAIL_GOLD if key == "press" else C.MUTED)
	pictogram.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(pictogram)
	var text := C.v(0)
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(C.fill(text))
	text.add_child(Kit.ellipsis(C.label(title, 22, C.IVORY, true, 700)))
	var line := C.wrap(detail, 17, C.MUTED)
	line.max_lines_visible = 2
	text.add_child(line)

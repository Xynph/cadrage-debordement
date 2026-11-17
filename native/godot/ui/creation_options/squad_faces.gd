extends RefCounted
## Écran « Options de carrière » · « Ton vestiaire en trois visages » : le cadre, le meilleur joueur et la
## pépite (portrait, nom, poste, âge, note et potentiel de la pépite), puis le réglage « Niveau de départ »
## qui fait varier ces notes à la création (mention « indicatif »).
const C = preload("res://ui/immersive08/components.gd")
const G = preload("res://ui/carnet_skin.gd")
const Editorial = preload("res://ui/entry_editorial.gd")
const Kit = preload("res://ui/creation_options/kit.gd")
const ROLES := [["leader", "Le cadre", "Il tient le vestiaire."], ["best", "Le meilleur", "Ta référence sur le terrain."], ["prospect", "La pépite", "L’avenir du club."]]

## `on_vary(value)` : appelé quand la case du niveau de départ change (bulle de Gabi).
static func build(app: Control, parent: Node, selected: Dictionary, data: Dictionary, state: String, on_vary: Callable) -> void:
	var column := Kit.block(parent, "CreationSquadFaces", "Ton vestiaire en trois visages", 1.0, false)
	var note := Kit.tag("indicatif")
	note.name = "CreationSquadIndicative"
	note.tooltip_text = "Notes indicatives : elles peuvent varier de ±3 à la création, le potentiel de ±5."
	Kit.aside(column).add_child(note)
	var faces: Dictionary = data.get("faces", {}) if data.get("faces") is Dictionary else {}
	var any := ROLES.any(func(role: Array) -> bool: return faces.get(role[0]) is Dictionary)
	var row := C.h(10)
	row.name = "CreationSquadCards"
	column.add_child(row)
	if state == "pending" and not any:
		for role: Array in ROLES: _ghost_card(row, role)
	elif any:
		for role: Array in ROLES: _card(row, role, faces.get(role[0]))
	else:
		_aggregate(row, selected)
	var level := C.h(10)
	level.name = "CreationLevelSection"
	column.add_child(level)
	var caption := Kit.caps("Niveau de départ", 17)
	caption.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	caption.custom_minimum_size.y = C.px(30)
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	level.add_child(caption)
	var controls := C.v(2)
	level.add_child(C.fill(controls))
	Kit.entry().call("_career_variation_controls", app, controls, true)
	var option := controls.find_child("CreationVaryCurrent", true, false) as CheckBox
	if option != null and on_vary.is_valid(): option.toggled.connect(func(value: bool) -> void: on_vary.call(value))

static func _frame(row: HBoxContainer, id: String) -> VBoxContainer:
	var frame := PanelContainer.new()
	frame.name = id
	frame.set_meta("immersive_style_applied", true)
	var style := C.box(Kit.DEEP, Color(Editorial.LINE, .8), 0, 10)
	style.set_corner_radius_all(0)
	frame.add_theme_stylebox_override("panel", style)
	row.add_child(C.fill(frame))
	var card := C.v(2)
	frame.add_child(card)
	return card

static func _card(row: HBoxContainer, role: Array, face: Variant) -> void:
	var card := _frame(row, "CreationFace_" + str(role[0]))
	var head := Kit.caps(str(role[1]), 17)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(head)
	if not face is Dictionary:
		var none := C.wrap("Personne ne se détache encore.", 17, C.MUTED)
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(none)
		return
	var person: Dictionary = face
	var index := int(person.get("portraitIndex", person.get("id", 0)))
	var portrait := G.portrait(index, C.px(86), person)
	portrait.name = "CreationFacePortrait_" + str(role[0])
	portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	portrait.mouse_filter = Control.MOUSE_FILTER_PASS
	card.add_child(portrait)
	var name := Kit.ellipsis(C.label(str(person.get("name", "")), 21, C.IVORY, true, 700))
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.tooltip_text = "%s · %s" % [str(person.get("name", "")), str(role[2])]
	name.mouse_filter = Control.MOUSE_FILTER_PASS
	card.add_child(name)
	var details := PackedStringArray()
	if not str(person.get("pos", "")).is_empty(): details.append(str(person.pos))
	if person.get("age") != null and int(person.get("age", 0)) > 0: details.append("%d ans" % int(person.age))
	var line := Kit.ellipsis(C.label(" · ".join(details), 17, C.MUTED, false))
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(line)
	var figures := C.h(10)
	figures.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(figures)
	_figure(figures, person.get("rating"), "note", C.IVORY)
	if str(role[0]) == "prospect" and person.get("potential") != null:
		Kit.divider(figures)
		_figure(figures, person.get("potential"), "potentiel", C.MINT)

static func _figure(parent: HBoxContainer, value: Variant, caption: String, color: Color) -> void:
	var column := C.v(0)
	parent.add_child(column)
	var number := C.label(str(roundi(float(value))) if value is float or value is int else "—", 32, color, true, 800)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(number)
	var label := C.label(caption, 15, C.MUTED, false)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(label)

static func _ghost_card(row: HBoxContainer, role: Array) -> void:
	var card := _frame(row, "CreationFace_" + str(role[0]))
	card.alignment = BoxContainer.ALIGNMENT_CENTER
	var head := Kit.caps(str(role[1]), 17)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(head)
	var disc := Kit.disc_ghost(86)
	disc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.add_child(disc)
	for width in [120, 80]:
		var bar := Kit.ghost(width, 14)
		bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		card.add_child(bar)
	var big := Kit.ghost(44, 30)
	big.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.add_child(big)

## Sans visages du moteur : l'effectif agrégé du catalogue (note moyenne, avants, arrières, atout).
static func _aggregate(row: HBoxContainer, selected: Dictionary) -> void:
	var roster: Dictionary = selected.get("startingRoster", {}) if selected.get("startingRoster") is Dictionary else {}
	var card := _frame(row, "CreationSquadAggregate")
	var figures := C.h(16)
	figures.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(figures)
	if roster.is_empty():
		card.add_child(C.wrap("Ton effectif t’attend dans le vestiaire dès ton arrivée.", 19, C.MUTED))
		return
	Kit.figure(figures, String.num(float(roster.get("average", 0)), 1).replace(".", ","), "note moyenne", Editorial.RAIL_GOLD, 38)
	Kit.divider(figures)
	Kit.figure(figures, str(int(roster.get("forwards", 0))), "avants", C.IVORY, 38)
	Kit.divider(figures)
	Kit.figure(figures, str(int(roster.get("backs", 0))), "arrières", C.IVORY, 38)
	if not str(roster.get("strengths", "")).is_empty():
		Kit.divider(figures)
		Kit.figure(figures, str(roster.strengths), "atout du groupe", C.MINT, 30)
	var hint := C.wrap("Les visages du vestiaire se découvrent dans l’effectif, dès ton arrivée.", 17, C.MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(hint)

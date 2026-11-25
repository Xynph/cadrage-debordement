extends RefCounted
## Écran « Options de carrière » · « Ton vestiaire en trois visages » : le cadre, le meilleur joueur et la
## pépite (portrait, nom, poste, âge, note et potentiel de la pépite), puis le réglage « Niveau de départ »
## qui fait varier ces notes à la création (mention « indicatif »).
const C = preload("res://ui/immersive08/components.gd")
const G = preload("res://ui/carnet_skin.gd")
const Editorial = preload("res://ui/entry_editorial.gd")
const Kit = preload("res://ui/creation_options/kit.gd")
const Charte = preload("res://ui/charte.gd")
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
		var reference := float(selected.get("startingRoster", {}).get("average", 0.0)) if selected.get("startingRoster") is Dictionary else 0.0
		for role: Array in ROLES: _card(row, role, faces.get(role[0]), reference)
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
	_qualites(app, column)

## Option façon FM (planche notation 24/11) : qualités des joueurs « Précises » (défaut) ou « En fourchette » tant que
## le joueur n'est pas assez observé. Un clic choisit et valide ; envoyé avec la création (option `qualites`), sauvegardé
## dans la carrière (player-knowledge.cjs : qualités de nos joueurs peu suivis en fourchette).
const QUALITES := [["precises", "Précises", "check"], ["fourchette", "En fourchette tant que pas observé", "search"]]

static func _qualites(app: Control, column: Node) -> void:
	var ligne := C.h(10)
	ligne.name = "CreationQualitesSection"
	column.add_child(ligne)
	var caption := Kit.caps("Qualités des joueurs", 17)
	caption.custom_minimum_size.y = C.px(40)
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ligne.add_child(caption)
	var boutons: Array[Button] = []
	var choix := str(app.management_ui.get("creation_qualites", "precises"))
	for q: Array in QUALITES:
		var b := Button.new()
		b.name = "CreationQualites_" + str(q[0])
		b.text = str(q[1])
		b.focus_mode = Control.FOCUS_ALL
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.add_theme_font_override("font", C.font(700))
		b.add_theme_font_size_override("font_size", C.px(19))
		b.custom_minimum_size.y = C.px(40)
		b.set_meta("cle", str(q[0]))
		ligne.add_child(b)
		boutons.append(b)
	var styler := func(actif: String) -> void:
		for b: Button in boutons:
			var on := str(b.get_meta("cle")) == actif
			var fond := C.box(Charte.DORE if on else Color(0, 0, 0, 0), Color(Charte.CREME, .0 if on else .35), C.px(20), 0)
			fond.content_margin_left = C.px(16); fond.content_margin_right = C.px(16)
			for etat in ["normal", "hover", "pressed", "focus"]: b.add_theme_stylebox_override(etat, fond)
			for etat in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
				b.add_theme_color_override(etat, Charte.ENCRE if on else Charte.CREME)
	styler.call(choix)
	for b: Button in boutons:
		b.pressed.connect(func() -> void:
			app.management_ui.creation_qualites = str(b.get_meta("cle"))
			styler.call(str(b.get_meta("cle"))))

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

static func _card(row: HBoxContainer, role: Array, face: Variant, reference: float = 0.0) -> void:
	var card := _frame(row, "CreationFace_" + str(role[0]))
	var head := Kit.caps(str(role[1]), 17)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(head)
	if not face is Dictionary:
		var none := C.label("—", 30, C.MUTED, true, 800)
		none.tooltip_text = "Personne ne se détache encore."
		none.mouse_filter = Control.MOUSE_FILTER_PASS
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
	_figure(figures, person.get("rating"), "note", reference)
	if str(role[0]) == "prospect" and person.get("potential") != null:
		Kit.divider(figures)
		_figure(figures, person.get("potential"), "potentiel", reference)

## Note et potentiel en LETTRE du staff (E- à S+, jamais le chiffre du moteur) : l'échelle part du niveau moyen du club.
static func _figure(parent: HBoxContainer, value: Variant, caption: String, reference: float) -> void:
	var column := C.v(0)
	parent.add_child(column)
	var Notation: Variant = load("res://ui/notation_staff.gd")
	var indice: int = Notation.indice(float(value), reference if reference > 0.0 else 65.0) if value is float or value is int else -1
	var porte: Control = Notation.porte_pastille({"bas": indice, "haut": indice}, 40.0, "CreationFigure_" + caption)
	porte.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(porte)
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

## Sans visages du moteur : l'effectif agrégé du catalogue (niveau en palier écrit, avants, arrières, atout).
static func _aggregate(row: HBoxContainer, selected: Dictionary) -> void:
	var roster: Dictionary = selected.get("startingRoster", {}) if selected.get("startingRoster") is Dictionary else {}
	var card := _frame(row, "CreationSquadAggregate")
	var figures := C.h(16)
	figures.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(figures)
	if roster.is_empty():
		var vide := C.label("—", 30, C.MUTED, true, 800)
		vide.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vide.tooltip_text = "Ton effectif t’attend dans le vestiaire dès ton arrivée."
		vide.mouse_filter = Control.MOUSE_FILTER_PASS
		card.add_child(vide)
		return
	Kit.figure(figures, str(Kit.entry().call("_rating", roster)), "niveau", Editorial.RAIL_GOLD, 26)
	Kit.divider(figures)
	Kit.figure(figures, str(int(roster.get("forwards", 0))), "avants", C.IVORY, 38)
	Kit.divider(figures)
	Kit.figure(figures, str(int(roster.get("backs", 0))), "arrières", C.IVORY, 38)
	if not str(roster.get("strengths", "")).is_empty():
		Kit.divider(figures)
		Kit.figure(figures, str(roster.strengths), "atout du groupe", C.MINT, 30)
	card.tooltip_text = "Les visages du vestiaire se découvrent dans l’effectif, dès ton arrivée."

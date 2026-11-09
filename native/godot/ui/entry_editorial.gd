extends RefCounted

const C = preload("res://ui/immersive08/components.gd")
const INK = Color("131d1e")
const PANEL = Color("192526")
const LINE = Color("62716b")
const BRASS = Color("c5ac78")

static func surface(node: PanelContainer, fill: Color = PANEL, border: Color = LINE, padding: int = 16) -> void:
	node.set_meta("immersive_style_applied", true)
	node.add_theme_stylebox_override("panel", C.box(fill, border, 3, padding))

static func action(button: Button, primary: bool = false, selected: bool = false, height: int = 42, tile: bool = false) -> void:
	button.set_meta("immersive_style_applied", true)
	button.custom_minimum_size.y = height
	button.add_theme_font_override("font", C.BOLD if primary else C.DISPLAY)
	button.add_theme_font_size_override("font_size", maxi(14, C.px(24 if primary else 21)))
	var normal := BRASS if primary else (Color("333b31") if selected else PANEL)
	var outline := BRASS if primary or selected else LINE
	for state in ["normal", "hover", "pressed", "disabled"]:
		var background := normal
		if state == "hover": background = normal.lightened(.09)
		if state == "pressed": background = normal.darkened(.13)
		if state == "disabled": background = INK
		var style := C.box(background, outline if state != "disabled" else LINE, 3, 8)
		if selected and tile: style.border_width_left = 4
		button.add_theme_stylebox_override(state, style)
	var focus := C.box(Color.TRANSPARENT, C.IVORY, 3, 0)
	focus.set_border_width_all(2)
	button.add_theme_stylebox_override("focus", focus)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, INK if primary else C.IVORY)
	button.add_theme_color_override("font_disabled_color", C.MUTED)

static func fact(parent: Container, value: Variant, caption: String) -> void:
	var column := C.v(0)
	C.fill(column)
	parent.add_child(column)
	column.add_child(C.label(value, 38, C.IVORY, true, 700))
	column.add_child(C.wrap(caption, 20, C.MUTED))

static func divider(parent: Container) -> void:
	var line := ColorRect.new()
	line.color = Color(LINE, .62)
	line.custom_minimum_size.x = 1
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(line)

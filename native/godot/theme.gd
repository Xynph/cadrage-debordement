extends RefCounted

const BG = Color("101519")
const PANEL = Color("192126")
const PANEL_ALT = Color("202a30")
const LINE = Color("34434c")
const INK = Color("f1eee5")
const MUTED = Color("aebbbf")
const GREEN = Color("a1d5ac")
const BODY = preload("res://fonts/DMSans.ttf")
const DISPLAY = preload("res://fonts/BarlowCondensed-SemiBold.ttf")

static func box(color: Color, radius: int = 8, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(1 if border.a > 0 else 0)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	return s

static func make() -> Theme:
	var t := Theme.new()
	t.default_font = BODY
	t.default_font_size = 14
	for kind in ["Label", "Button", "OptionButton", "CheckButton", "PopupMenu"]:
		t.set_color("font_color", kind, INK)
	t.set_color("font_disabled_color", "Button", Color("79878d"))
	t.set_color("font_hover_color", "Button", INK)
	t.set_color("font_pressed_color", "Button", INK)
	t.set_stylebox("normal", "Button", box(PANEL_ALT, 5, LINE))
	t.set_stylebox("hover", "Button", box(Color("34434a"), 5, Color("8b9c9f")))
	t.set_stylebox("pressed", "Button", box(Color("42515a"), 5, INK))
	t.set_stylebox("disabled", "Button", box(PANEL, 5))
	t.set_stylebox("focus", "Button", box(Color.TRANSPARENT, 5, INK))
	t.set_stylebox("normal", "OptionButton", box(PANEL_ALT, 5, LINE))
	t.set_stylebox("hover", "OptionButton", box(Color("34434a"), 5, INK))
	t.set_stylebox("focus", "OptionButton", box(Color.TRANSPARENT, 5, INK))
	t.set_stylebox("panel", "PopupMenu", box(PANEL_ALT, 5, LINE))
	t.set_stylebox("normal","LineEdit",box(BG,4,LINE))
	t.set_stylebox("focus","LineEdit",box(BG,4,INK))
	t.set_color("font_color","LineEdit",INK)
	t.set_color("caret_color","LineEdit",INK)
	t.set_color("selection_color","LineEdit",Color("586776"))
	t.set_stylebox("panel","AcceptDialog",box(PANEL,6,LINE))
	t.set_stylebox("panel","Window",box(PANEL,6,LINE))
	t.set_constant("separation", "VBoxContainer", 12)
	t.set_constant("separation", "HBoxContainer", 12)
	t.set_stylebox("panel", "PanelContainer", box(PANEL))
	t.set_stylebox("background", "ProgressBar", box(Color("34434c"), 2))
	t.set_stylebox("fill", "ProgressBar", box(GREEN, 2))
	return t

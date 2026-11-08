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
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s

static func make() -> Theme:
	var t := Theme.new()
	t.default_font = BODY
	t.default_font_size = 13
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

static func paper() -> Theme:
	var t := make()
	t.default_font_size = 13
	var ink := Color("242321")
	var muted := Color("69645c")
	var paper := Color("f3eddf")
	var line := Color("c7bba7")
	for kind in ["Label", "Button", "OptionButton", "CheckButton", "PopupMenu", "LineEdit", "SpinBox", "AcceptDialog", "Window", "FileDialog"]:
		t.set_color("font_color", kind, ink)
		t.set_color("font_hover_color", kind, ink)
		t.set_color("font_pressed_color", kind, ink)
		t.set_color("font_focus_color", kind, ink)
		t.set_color("font_disabled_color", kind, muted)
		t.set_font_size("font_size", kind, 13)
	for kind in ["Button", "OptionButton"]:
		t.set_stylebox("normal", kind, box(Color("e8dfce"), 3, line))
		for state in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]: t.set_color(state,kind,ink)
		t.set_stylebox("hover", kind, box(Color("ddd1bc"), 3, ink))
		t.set_stylebox("pressed", kind, box(Color("d0c2a9"), 3, ink))
		t.set_stylebox("disabled", kind, box(Color("e7e0d3"), 3, line))
		var focus := box(Color.TRANSPARENT, 3, Color("82592e"))
		focus.set_border_width_all(2)
		t.set_stylebox("focus", kind, focus)
	t.set_stylebox("panel", "PopupMenu", box(paper, 3, line))
	t.set_color("font_hover_color", "PopupMenu", paper)
	t.set_stylebox("hover", "PopupMenu", box(ink, 2))
	t.set_stylebox("normal", "LineEdit", box(Color("fbf7ef"), 3, line))
	t.set_stylebox("focus", "LineEdit", box(Color("fbf7ef"), 3, ink))
	t.set_color("caret_color", "LineEdit", ink)
	t.set_color("selection_color", "LineEdit", Color("c7bba7"))
	for kind in ["AcceptDialog", "Window", "PanelContainer", "Tree", "ItemList"]:
		t.set_stylebox("panel", kind, box(paper, 3, line))
	t.set_color("title_color", "Window", paper)
	t.set_constant("modulate_arrow","OptionButton",1)
	for state in ["up_icon_modulate","up_hover_icon_modulate","up_pressed_icon_modulate","down_icon_modulate","down_hover_icon_modulate","down_pressed_icon_modulate"]:t.set_color(state,"SpinBox",ink)
	for state in ["up_disabled_icon_modulate","down_disabled_icon_modulate"]:t.set_color(state,"SpinBox",muted)
	for kind in ["Tree","ItemList"]:
		t.set_color("font_selected_color",kind,ink)
		for state in ["selected","selected_focus"]:t.set_stylebox(state,kind,box(Color("ddd1bc"),2,line))
	t.set_color("font_color", "Tree", ink)
	t.set_color("font_color", "ItemList", ink)
	t.set_stylebox("background", "ProgressBar", box(Color("d5caba"), 2))
	t.set_stylebox("fill", "ProgressBar", box(Color("38664b"), 2))
	for kind in ["TabContainer", "TabBar"]:
		t.set_color("font_selected_color", kind, ink)
		t.set_color("font_unselected_color", kind, muted)
		t.set_color("font_hovered_color", kind, ink)
		t.set_stylebox("tab_selected", kind, box(Color("faf6ed"), 2, line))
		t.set_stylebox("tab_unselected", kind, box(Color("e3dac9"), 2, line))
		t.set_stylebox("tab_hovered", kind, box(Color("eee5d5"), 2, ink))
		t.set_font_size("font_size", kind, 13)
	t.set_stylebox("panel", "TabContainer", box(paper, 2, line))
	for kind in ["CheckBox", "CheckButton"]:
		t.set_color("font_color", kind, ink)
		t.set_color("font_hover_color", kind, ink)
		t.set_color("font_pressed_color", kind, ink)
		t.set_color("font_disabled_color", kind, muted)
	return t

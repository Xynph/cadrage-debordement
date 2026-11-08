extends RefCounted
# Surfaces de lecture du carnet. Le shell et les photographies gardent leur encre claire.
const Base = preload("res://ui/game_skin.gd")
const T = preload("res://theme.gd")
const W = preload("res://visual_widgets.gd")
const BG = Color("191b1c")
const PANEL = Color("f3eddf")
const PAPER = PANEL
const LINE = Color("d5caba")
const INK = Color("242321")
const MUTED = Color("69645c")
const GOLD = Color("82592e")
const GOOD = Color("38664b")
const ALERT = Color("963f32")
const WHITE = Color("f3eddf")

static func accent_ink(color: Color) -> Color:
	var result := color
	while result.get_luminance() > .20: result = result.darkened(.12)
	return result

static func label(text: Variant, size: int = 15, color: Color = INK, title: bool = false) -> Label:
	return Base.label(text, size, color, title)
static func wrap(text: Variant, size: int = 15, color: Color = MUTED) -> Label:
	return Base.wrap(text, size, color)
static func h(gap: int = 14) -> HBoxContainer: return Base.h(gap)
static func v(gap: int = 14) -> VBoxContainer: return Base.v(gap)
static func fill(c: Control, vertical: bool = false, ratio: float = 1.0) -> Control: return Base.fill(c, vertical, ratio)
static func margin(padding: int = 20) -> MarginContainer: return Base.margin(padding)
static func n(number: Variant) -> String: return Base.n(number)
static func euros(amount: Variant) -> String: return Base.euros(amount)
static func identity(club: Dictionary) -> Dictionary: return Base.identity(club)
static func club_name(club: Dictionary) -> String: return Base.club_name(club)
static func club_abbr(club: Dictionary) -> String: return Base.club_abbr(club)
static func crest(club: Dictionary, width: int = 56) -> Control: return Base.crest(club, width)
static func portrait(index: int, width: int = 60, player: Dictionary = {}) -> TextureRect: return Base.portrait(index, width, player)
static func picture(slug: String, kind: String = "stadium", dark: bool = true) -> Control: return Base.picture(slug, kind, dark)
static func spacer() -> Control: return Base.spacer()
static func scroll(parent: Node) -> VBoxContainer: return Base.scroll(parent)

static func button(text: String, callback: Callable, primary: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = 44
	b.add_theme_font_size_override("font_size", 14)
	var background := INK if primary else Color("e8dfce")
	b.add_theme_stylebox_override("normal", T.box(background, 3, INK if primary else LINE))
	b.add_theme_stylebox_override("hover", T.box(Color("3c403b") if primary else Color("ddd1bc"), 3, INK))
	b.add_theme_stylebox_override("pressed", T.box(Color("4b5348") if primary else Color("d0c2a9"), 3, INK))
	b.add_theme_stylebox_override("disabled", T.box(Color("e7e0d3"), 3, LINE))
	var focus := T.box(Color.TRANSPARENT, 3, GOLD)
	focus.set_border_width_all(2)
	b.add_theme_stylebox_override("focus", focus)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: b.add_theme_color_override(key, WHITE if primary else INK)
	b.add_theme_color_override("font_disabled_color", Color("7b766d"))
	b.pressed.connect(callback)
	return b

static func selected(b: Button, accent: Color) -> void:
	var style := T.box(PAPER.lerp(Color(accent,1), .12), 3, accent_ink(accent))
	style.border_width_left = 4
	b.add_theme_stylebox_override("normal", style)

static func panel(parent: Node, ratio: float = 1.0, color: Color = PANEL) -> VBoxContainer:
	var p := PanelContainer.new()
	fill(p, false, ratio)
	p.theme = T.paper()
	p.add_theme_stylebox_override("panel", T.box(color, 2, LINE))
	parent.add_child(p)
	var c := v(14)
	p.add_child(c)
	return c

static func section(title: String, subtitle: String = "") -> VBoxContainer:
	var c := v(4)
	c.add_child(label(title, 27, INK, true))
	if not subtitle.is_empty(): c.add_child(Base.wrap(subtitle, 13, MUTED))
	return c

static func chapter(parent: Node, number: String, title: String, subtitle: String, accent: Color) -> void:
	var row := h(10)
	parent.add_child(row)
	row.add_child(label(number + " /", 28, accent_ink(accent), true))
	var titles := section(title, subtitle)
	fill(titles)
	row.add_child(titles)
	parent.add_child(separator())

static func separator() -> HSeparator:
	var s := HSeparator.new()
	var line := StyleBoxLine.new()
	line.color = LINE
	line.thickness = 1
	s.add_theme_stylebox_override("separator", line)
	return s

static func metric(number: Variant, caption: String, color: Color = INK) -> VBoxContainer:
	var c := v(1)
	fill(c)
	c.add_child(label(number, 36, color, true))
	c.add_child(Base.wrap(caption, 13, MUTED))
	return c

static func cell(text: Variant, width: int, color: Color = INK, expand: bool = false) -> Label:
	var l := label(text, 14, color)
	l.custom_minimum_size.x = width
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.tooltip_text = str(text)
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	if expand: fill(l)
	return l

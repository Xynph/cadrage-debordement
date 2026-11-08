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
static func h(gap: int = 6) -> HBoxContainer: return Base.h(gap)
static func v(gap: int = 6) -> VBoxContainer: return Base.v(gap)
static func fill(c: Control, vertical: bool = false, ratio: float = 1.0) -> Control: return Base.fill(c, vertical, ratio)
static func margin(padding: int = 8) -> MarginContainer: return Base.margin(padding)
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
	b.custom_minimum_size.y = 28
	b.add_theme_font_size_override("font_size", 12)
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
	# Keep the geometric marker when pointer/focus/press changes the state.
	# Colour alone cannot identify the current player, club or tactic.
	for state in ["normal", "hover", "pressed"]:
		var strength := .12 if state == "normal" else .18 if state == "hover" else .23
		var style := T.box(PAPER.lerp(Color(accent,1), strength), 3, accent_ink(accent))
		style.border_width_left = 4
		b.add_theme_stylebox_override(state, style)
	b.set_meta("carnet_selected", true)

static func clear_selection(b: Button) -> void:
	for state in ["normal", "hover", "pressed"]: b.remove_theme_stylebox_override(state)
	b.set_meta("carnet_selected", false)

static func reading_button(b: Button, minimum_width: int = 92) -> Button:
	# Reading tools fit short rows. Full text stays available for long French labels.
	b.custom_minimum_size = Vector2(minimum_width, 28)
	b.add_theme_font_size_override("font_size", 12)
	b.size_flags_vertical = Control.SIZE_SHRINK_END
	b.clip_text = true
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.tooltip_text = b.text
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style: StyleBoxFlat = b.get_theme_stylebox(state).duplicate()
		style.content_margin_top = 4; style.content_margin_bottom = 4
		style.content_margin_left = 8; style.content_margin_right = 8
		b.add_theme_stylebox_override(state, style)
	return b

static func panel(parent: Node, ratio: float = 1.0, color: Color = PANEL) -> VBoxContainer:
	var p := PanelContainer.new()
	fill(p, false, ratio)
	p.theme = T.paper()
	p.add_theme_stylebox_override("panel", T.box(color, 2, LINE))
	parent.add_child(p)
	var c := v(9)
	p.add_child(c)
	return c

static func section(title: String, subtitle: String = "") -> VBoxContainer:
	var c := v(4)
	var heading := Base.wrap(title, 27, INK)
	heading.add_theme_font_override("font", T.DISPLAY)
	c.add_child(heading)
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
	var value := Base.wrap(number, 34, color)
	value.add_theme_font_override("font", T.DISPLAY)
	c.add_child(value)
	c.add_child(Base.wrap(caption, 13, MUTED))
	return c

# Editorial primitives: all quantities are supplied by the career projection.
static func card(parent: Node, accent: Color = LINE) -> VBoxContainer:
	var frame := PanelContainer.new()
	var style := T.box(Color("faf6ed"), 3, LINE)
	style.border_width_left = 3
	style.border_color = accent
	frame.add_theme_stylebox_override("panel", style)
	parent.add_child(frame)
	var content := v(10)
	frame.add_child(content)
	return content

static func gauge(parent: Node, caption: String, value: float, maximum: float = 100.0, color: Color = GOOD) -> void:
	var block := v(4)
	fill(block)
	parent.add_child(block)
	var row := h(8)
	block.add_child(row)
	var name := Base.wrap(caption, 12, MUTED)
	fill(name)
	row.add_child(name)
	row.add_child(label("%s / %s" % [n(value), n(maximum)], 15, color, true))
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.max_value = maxf(1, maximum)
	bar.value = value
	bar.custom_minimum_size.y = 5
	for key in ["background", "fill"]:
		var style := T.box(LINE if key == "background" else color, 1)
		style.content_margin_left = 0; style.content_margin_right = 0
		style.content_margin_top = 0; style.content_margin_bottom = 0
		bar.add_theme_stylebox_override(key, style)
	block.add_child(bar)

static func photo_note(parent: Node, club: Dictionary, title: String, subtitle: String, kind: String = "stadium", height: int = 130) -> void:
	var photo := picture(str(identity(club).get("slug", "toulouse")), kind)
	photo.custom_minimum_size.y = height
	parent.add_child(photo)
	var content: VBoxContainer = photo.get_meta("content")
	content.add_theme_constant_override("separation", 3)
	for edge in ["left", "right"]: content.get_parent().add_theme_constant_override("margin_" + edge, 8)
	for edge in ["top", "bottom"]: content.get_parent().add_theme_constant_override("margin_" + edge, 4)
	content.add_child(Base.label(title.to_upper(), 12, Color("ddbd80")))
	content.add_child(Base.spacer())
	var caption := Base.wrap(subtitle, 25, WHITE)
	caption.add_theme_font_override("font", T.DISPLAY)
	content.add_child(caption)

static func person(parent: Node, player: Dictionary, title: String, detail: String, width: int = 58) -> void:
	var row := h(12)
	parent.add_child(row)
	row.add_child(portrait(int(player.get("portraitIndex", posmod(str(player.get("id", title)).hash(), 32))), width, player))
	var text := v(3)
	fill(text)
	row.add_child(text)
	var heading := Base.wrap(title, 25, INK)
	heading.add_theme_font_override("font", T.DISPLAY)
	text.add_child(heading)
	text.add_child(Base.wrap(detail, 13, MUTED))

static func trend(parent: Node, numbers: Array, caption: String, accent: Color) -> void:
	if numbers.size() < 2: return
	var chart := W.new()
	chart.mode = "trend"
	chart.values = numbers
	chart.accent = accent_ink(accent)
	chart.grid_color = LINE
	chart.custom_minimum_size.y = 78
	parent.add_child(chart)
	parent.add_child(Base.wrap(caption, 12, MUTED))

static func cell(text: Variant, width: int, color: Color = INK, expand: bool = false) -> Label:
	var l := label(text, 14, color)
	l.custom_minimum_size.x = width
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.tooltip_text = str(text)
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	if expand: fill(l)
	return l

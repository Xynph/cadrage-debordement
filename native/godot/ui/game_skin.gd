extends RefCounted

const T = preload("res://theme.gd")
const W = preload("res://visual_widgets.gd")
const BG = Color("0d1318")
const PANEL = Color("172127")
const LINE = Color("30404a")
const INK = Color("f2eee3")
const MUTED = Color("aab9bf")
const GOLD = Color("ddbd80")
const GOOD = Color("a6d2ae")
static var textures: Dictionary = {}

static func label(text: Variant, size: int = 14, color: Color = INK, title: bool = false) -> Label:
	var l := Label.new()
	l.text = str(text)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if title: l.add_theme_font_override("font", T.DISPLAY)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

static func wrap(text: Variant, size: int = 14, color: Color = MUTED) -> Label:
	var l := label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

static func button(text: String, callback: Callable, primary: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = 42
	b.add_theme_font_size_override("font_size", 12)
	if primary:
		b.add_theme_stylebox_override("normal", T.box(INK, 4))
		b.add_theme_stylebox_override("hover", T.box(Color("d7d6c9"), 4))
		b.add_theme_stylebox_override("pressed", T.box(Color("bec8ba"), 4))
		for key in ["font_color", "font_hover_color", "font_pressed_color"]: b.add_theme_color_override(key, BG)
	b.pressed.connect(callback)
	return b

static func h(gap: int = 12) -> HBoxContainer:
	var c := HBoxContainer.new()
	c.add_theme_constant_override("separation", gap)
	return c

static func nav_button(text:String,callback:Callable,accent:Color,selected:bool) -> Button:
	var b:=button(text,callback)
	b.alignment=HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size.y=34
	b.add_theme_font_size_override("font_size",11)
	var normal:=T.box(Color(accent,.18) if selected else Color.TRANSPARENT,3)
	normal.content_margin_top=6
	normal.content_margin_bottom=6
	normal.content_margin_left=14
	if selected:
		normal.border_width_left=3
		normal.border_color=accent.lightened(.15)
	b.add_theme_stylebox_override("normal",normal)
	var hover:=normal.duplicate()
	hover.bg_color=Color("263740")
	b.add_theme_stylebox_override("hover",hover)
	return b

static func v(gap: int = 12) -> VBoxContainer:
	var c := VBoxContainer.new()
	c.add_theme_constant_override("separation", gap)
	return c

static func fill(c: Control, vertical: bool = false, ratio: float = 1.0) -> Control:
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if vertical: c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.size_flags_stretch_ratio = ratio
	return c

static func margin(padding: int = 20) -> MarginContainer:
	var m := MarginContainer.new()
	for edge in ["left", "right", "top", "bottom"]: m.add_theme_constant_override("margin_" + edge, padding)
	return m

static func panel(parent: Node, ratio: float = 1.0, color: Color = PANEL) -> VBoxContainer:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_stretch_ratio = ratio
	p.add_theme_stylebox_override("panel", T.box(color, 6, LINE))
	parent.add_child(p)
	var m := margin(6)
	p.add_child(m)
	var c := v()
	m.add_child(c)
	return c

static func section(title: String, subtitle: String = "") -> VBoxContainer:
	var c := v(3)
	c.add_child(label(title, 23, INK, true))
	if not subtitle.is_empty(): c.add_child(label(subtitle, 11, MUTED))
	return c

static func separator() -> HSeparator:
	var s := HSeparator.new()
	s.modulate = LINE
	return s

static func metric(number: Variant, caption: String, color: Color = INK) -> VBoxContainer:
	var c := v(0)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.add_child(label(number, 37, color, true))
	c.add_child(label(caption.to_upper(), 10, MUTED))
	return c

static func n(number: Variant) -> String:
	return str(int(number)) if number is float or number is int else str(number)

static func euros(amount: Variant) -> String:
	var value := int(amount) if amount != null else 0
	var digits := str(absi(value))
	var formatted := ""
	for i in digits.length():
		if i > 0 and (digits.length() - i) % 3 == 0: formatted += " "
		formatted += digits[i]
	return ("−" if value < 0 else "") + formatted + " €"

static func identity(club: Dictionary) -> Dictionary:
	return club.get("presentation", club) if club.get("presentation") is Dictionary else club

static func club_name(club: Dictionary) -> String:
	return str(identity(club).get("name", club.get("name", "—")))

static func club_abbr(club: Dictionary) -> String:
	return str(identity(club).get("abbr", "XV"))

static func crest(club: Dictionary, width: int = 56) -> Control:
	var w := W.new()
	var c := identity(club)
	w.initials = str(c.get("abbr", "XV"))
	w.accent = Color(c.get("color", "#b94850"))
	w.custom_minimum_size = Vector2(width, width)
	w.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return w

static func portrait(index: int, width: int = 60) -> TextureRect:
	var r := TextureRect.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = load("res://assets/editorial/portraits-%d.webp" % (index / 16))
	var cell := atlas.atlas.get_size() / 4.0
	atlas.region = Rect2(Vector2(index % 4, (index % 16) / 4) * cell, cell)
	r.texture = atlas
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(width, width)
	r.tooltip_text = "Portrait décoratif fictif généré par IA"
	return r

static func picture(slug: String, kind: String = "stadium", dark: bool = true) -> Control:
	var base := Control.new()
	base.clip_contents = true
	base.custom_minimum_size = Vector2(0, 140)
	var image := TextureRect.new()
	var path := "res://assets/club-atlas/%s-%s.webp" % [slug, kind]
	image.texture = load(path)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	base.add_child(image)
	if dark:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(0.02, 0.04, 0.06, 0.70))
		gradient.set_color(1, Color(0.02, 0.04, 0.06, 0.98))
		gradient.add_point(0.40, Color(0.02, 0.04, 0.06, 0.12))
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.fill_from = Vector2(0.5, 0)
		texture.fill_to = Vector2(0.5, 1)
		var shade := TextureRect.new()
		shade.texture = texture
		shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		base.add_child(shade)
	var overlay := margin(24)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	base.add_child(overlay)
	var content := v(8)
	overlay.add_child(content)
	base.set_meta("content", content)
	return base

static func spacer() -> Control:
	var c := Control.new()
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c

static func scroll(parent: Node) -> VBoxContainer:
	var s := ScrollContainer.new()
	s.follow_focus = true
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(s)
	var c := v(7)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(c)
	return c

static func cell(text: Variant, width: int, color: Color = INK, expand: bool = false) -> Label:
	var l := label(text, 13, color)
	l.custom_minimum_size.x = width
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if expand: l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

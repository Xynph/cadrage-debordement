extends RefCounted

const T = preload("res://theme.gd")
const W = preload("res://visual_widgets.gd")
const Art = preload("res://ui/art_widgets.gd")
const BG = Color("151b1f")
const PANEL = Color("1d262b")
const LINE = Color("445259")
const INK = Color("f5f4ec")
const MUTED = Color("bdc8c9")
const GOLD = Color("ddbd80")
const GOOD = Color("a6d2ae")
static var textures: Dictionary = {}

# Dense carnet scale: explicit legacy sizes keep their role, without enlarging
# every heading and number into a second page at native desktop resolutions.
static func reading_size(requested: int) -> int:
	if requested >= 44: return 26
	if requested >= 34: return 20
	if requested >= 27: return 18
	if requested >= 23: return 16
	if requested >= 18: return 13
	if requested >= 15: return 12
	return mini(requested, 12)

static func label(text: Variant, size: int = 14, color: Color = INK, title: bool = false) -> Label:
	var l := Label.new()
	l.text = str(text)
	l.add_theme_font_size_override("font_size", reading_size(size))
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
	b.custom_minimum_size.y = 28
	b.add_theme_font_size_override("font_size", 12)
	if primary:
		b.add_theme_stylebox_override("normal", T.box(INK, 4))
		b.add_theme_stylebox_override("hover", T.box(Color("d7d6c9"), 4))
		b.add_theme_stylebox_override("pressed", T.box(Color("bec8ba"), 4))
		for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: b.add_theme_color_override(key, BG)
	b.pressed.connect(callback)
	return b

static func h(gap: int = 6) -> HBoxContainer:
	var c := HBoxContainer.new()
	c.add_theme_constant_override("separation", mini(gap, 8))
	return c

static func nav_button(text:String,callback:Callable,accent:Color,selected:bool,chapter:String="") -> Button:
	var b:=button(text,callback)
	b.alignment=HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size.y=28
	b.add_theme_font_size_override("font_size",12)
	var normal:=T.box(Color("263238").lerp(Color(accent,1),.20) if selected else Color.TRANSPARENT,3)
	normal.content_margin_top=4
	normal.content_margin_bottom=4
	normal.content_margin_left=34 if not chapter.is_empty() else 10
	if selected:
		normal.border_width_left=3
		normal.border_color=accent.lightened(.3)
	b.add_theme_stylebox_override("normal",normal)
	var hover:=normal.duplicate()
	hover.bg_color=Color("344349").lerp(Color(accent,1),.12)
	b.add_theme_stylebox_override("hover",hover)
	var pressed:=normal.duplicate()
	pressed.bg_color=Color("44575b").lerp(Color(accent,1),.16)
	b.add_theme_stylebox_override("pressed",pressed)
	var focus:=T.box(Color.TRANSPARENT,3,INK)
	focus.set_border_width_all(2)
	b.add_theme_stylebox_override("focus",focus)
	for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:b.add_theme_color_override(state,INK if selected else MUTED)
	if not chapter.is_empty():
		var icon:=Art.glyph(chapter,INK if selected else MUTED,18)
		icon.name="ChapterIcon"
		b.add_child(icon)
		icon.position=Vector2(10,5)
		b.resized.connect(func():icon.position=Vector2(10,(b.size.y-18)*.5))
		b.set_meta("art_icon",icon)
	return b

static func v(gap: int = 6) -> VBoxContainer:
	var c := VBoxContainer.new()
	c.add_theme_constant_override("separation", mini(gap, 8))
	return c

static func fill(c: Control, vertical: bool = false, ratio: float = 1.0) -> Control:
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if vertical: c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.size_flags_stretch_ratio = ratio
	return c

static func margin(padding: int = 8) -> MarginContainer:
	var m := MarginContainer.new()
	for edge in ["left", "right", "top", "bottom"]: m.add_theme_constant_override("margin_" + edge, padding)
	return m

static func panel(parent: Node, ratio: float = 1.0, color: Color = PANEL) -> VBoxContainer:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_stretch_ratio = ratio
	var style:=T.box(color,3,LINE)
	style.shadow_color=Color(0,0,0,.09)
	style.shadow_size=2
	style.shadow_offset=Vector2(0,1)
	p.add_theme_stylebox_override("panel",style)
	parent.add_child(p)
	var m := margin(4)
	p.add_child(m)
	var c := v()
	m.add_child(c)
	return c

static func section(title: String, subtitle: String = "") -> VBoxContainer:
	var c := v(3)
	c.add_child(label(title, 23, INK, true))
	if not subtitle.is_empty(): c.add_child(label(subtitle, 12, MUTED))
	return c

static func separator() -> HSeparator:
	var s := HSeparator.new()
	s.modulate = LINE
	return s

static func metric(number: Variant, caption: String, color: Color = INK) -> VBoxContainer:
	var c := v(0)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.add_child(label(number, 37, color, true))
	c.add_child(label(caption.to_upper(), 12, MUTED))
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
	var c := identity(club)
	var path := str(c.get("logoPath", club.get("logoPath", "")))
	var texture := _pack_texture(path)
	var provided := texture != null
	if not provided:
		var slug := str(c.get("slug", ""))
		var badge := "res://art/pacific/badges/%s.svg" % slug if slug.begins_with("srp-") else "res://art/japan/badges/%s.svg" % slug if slug.begins_with("jlo-") else "res://art/nationale/badges/%s.svg" % slug if slug.begins_with("nat-") else "res://art/champ/badges/%s.svg" % slug if slug.begins_with("champ-") else ""
		if not badge.is_empty() and ResourceLoader.exists(badge): texture = load(badge) as Texture2D
	if texture != null:
		var image := TextureRect.new()
		image.texture = texture
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.custom_minimum_size = Vector2(width, width)
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		image.tooltip_text = "Blason fourni par le pack" if provided else "Blason d’Oval Legacy 27"
		return image
	var w := W.new()
	w.initials = str(c.get("abbr", "XV"))
	w.accent = Color(c.get("color", "#b94850"))
	w.custom_minimum_size = Vector2(width, width)
	w.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return w

static func _pack_texture(path: String) -> Texture2D:
	if path.is_empty() or not path.is_absolute_path() or not FileAccess.file_exists(path): return null
	if textures.has(path): return textures[path]
	var image := Image.new()
	if image.load(path) != OK: return null
	var longest := maxi(image.get_width(), image.get_height())
	if longest > 512:
		var ratio := 512.0 / longest
		image.resize(maxi(1, roundi(image.get_width() * ratio)), maxi(1, roundi(image.get_height() * ratio)), Image.INTERPOLATE_LANCZOS)
	var texture := ImageTexture.create_from_image(image)
	if textures.size() >= 48: textures.erase(textures.keys()[0])
	textures[path] = texture
	return texture

static func portrait(index: int, width: int = 60, player: Dictionary = {}) -> TextureRect:
	var r := TextureRect.new()
	var identity_data: Dictionary = player.get("identity", {})
	var path := str(player.get("portraitPath", identity_data.get("portraitPath", "")))
	var texture := _pack_texture(path)
	if texture != null:
		r.texture = texture
		r.tooltip_text = "Illustration IA · ressemblance non garantie" if player.get("portraitStatus", identity_data.get("portraitStatus", "")) == "synthetic" else "Photo officielle · archive fournie par le pack"
	elif not str(player.get("id", "")).is_empty() and preload("res://ui/regen_portrait.gd").apply(r, player):
		r.tooltip_text = "Portrait fictif · éléments IA composés hors ligne" if path.is_empty() else "Image du pack indisponible · portrait fictif composé hors ligne"
	else:
		var atlas := AtlasTexture.new()
		index = posmod(index, 32)
		atlas.atlas = load("res://assets/editorial/portraits-%d.webp" % (index / 16))
		var cell := atlas.atlas.get_size() / 4.0
		atlas.region = Rect2(Vector2(index % 4, (index % 16) / 4) * cell, cell)
		r.texture = atlas
		r.tooltip_text = "Portrait décoratif fictif généré par IA" if path.is_empty() else "Image du pack indisponible · portrait fictif généré par IA"
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(width, width)
	return r

static var venue_textures: Dictionary = {}

static func _venue_texture(path: String) -> Texture2D:
	if path.is_empty() or not path.is_absolute_path() or not FileAccess.file_exists(path): return null
	if venue_textures.has(path): return venue_textures[path]
	var image := Image.new()
	if image.load(path) != OK or image.is_empty(): return null
	var texture := ImageTexture.create_from_image(image)
	if venue_textures.size() >= 6: venue_textures.erase(venue_textures.keys()[0])
	venue_textures[path] = texture
	return texture

static func picture(slug: String, kind: String = "stadium", dark: bool = true, external_path: String = "") -> Control:
	var base := Control.new()
	base.clip_contents = true
	base.custom_minimum_size = Vector2(0, 140)
	var image := TextureRect.new()
	var path := "res://assets/club-atlas/%s-%s.webp" % [slug, kind]
	image.texture = _venue_texture(external_path)
	var from_pack := image.texture != null
	if not from_pack and ResourceLoader.exists(path):
		image.texture = load(path)
	base.set_meta("has_photo", image.texture != null)
	base.set_meta("photo_from_pack", from_pack)
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	var overlay := margin(12)
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

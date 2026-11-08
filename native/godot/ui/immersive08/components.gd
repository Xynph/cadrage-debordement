extends RefCounted
## Grammaire visuelle des compositions approuvées ; aucune donnée de carrière.

const Base = preload("res://ui/game_skin.gd")
const BG = Color("0b1012")
const PANEL = Color("111a1c")
const RAISED = Color("172321")
const LINE = Color("53625e")
const IVORY = Color("f2ecdc")
const MUTED = Color("abb7b1")
const FAINT = Color("71867b")
const MINT = Color("82e3a3")
const GOLD = Color("d7ad59")
const AMBER = Color("e7bc63")
const ALERT = Color("df897d")
const BLUE = Color("62b9d4")
const DISPLAY = preload("res://fonts/BarlowCondensed-SemiBold.ttf")
const BODY = preload("res://fonts/DMSans.ttf")
static var density := 1.0
static var _textures: Dictionary = {}

static func configure(height: float) -> void:
	density = clampf(height / 1440.0, .64, 1.0)

static func px(value: float) -> int:
	return roundi(value * density)

static func box(color: Color = PANEL, border: Color = LINE, radius: int = 8, padding: int = 18) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(border, .65)
	style.set_border_width_all(1 if border.a > 0 else 0)
	style.set_corner_radius_all(maxi(3, px(radius)))
	style.content_margin_left = px(padding)
	style.content_margin_right = px(padding)
	style.content_margin_top = px(padding)
	style.content_margin_bottom = px(padding)
	return style

static func label(text: Variant, font_size: int = 22, color: Color = IVORY, display: bool = true) -> Label:
	var control := Label.new()
	control.text = str(text)
	control.add_theme_font_override("font", DISPLAY if display else BODY)
	control.add_theme_font_size_override("font_size", maxi(12, px(font_size)))
	control.add_theme_color_override("font_color", color)
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return control

static func wrap(text: Variant, font_size: int = 20, color: Color = MUTED, display: bool = false) -> Label:
	var control := label(text, font_size, color, display)
	control.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return control

static func h(gap: int = 16) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", px(gap))
	return row

static func v(gap: int = 12) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", px(gap))
	return column

static func fill(control: Control, vertical: bool = false, ratio: float = 1.0) -> Control:
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if vertical: control.size_flags_vertical = Control.SIZE_EXPAND_FILL
	control.size_flags_stretch_ratio = ratio
	return control

static func margin(padding: int = 18) -> MarginContainer:
	var control := MarginContainer.new()
	for edge in ["left", "top", "right", "bottom"]: control.add_theme_constant_override("margin_" + edge, px(padding))
	return control

static func rule() -> HSeparator:
	var control := HSeparator.new()
	var style := StyleBoxLine.new()
	style.color = Color(LINE, .65)
	style.thickness = 1
	control.add_theme_stylebox_override("separator", style)
	return control

static func card(title: String = "", minimum: Vector2 = Vector2.ZERO) -> PanelContainer:
	var frame := PanelContainer.new()
	frame.custom_minimum_size = minimum * density
	frame.add_theme_stylebox_override("panel", box())
	var content := v(12)
	frame.add_child(content)
	frame.set_meta("content", content)
	if not title.is_empty():
		var heading := label(title.to_upper(), 26)
		heading.name = "CardTitle"
		content.add_child(heading)
		content.add_child(rule())
	return frame

static func content(frame: Control) -> VBoxContainer:
	return frame.get_meta("content")

static func button(text: String, callback: Callable, primary: bool = false, accent: Color = Color("176e49")) -> Button:
	var control := Button.new()
	control.text = text
	control.custom_minimum_size.y = px(46)
	control.add_theme_font_override("font", DISPLAY)
	control.add_theme_font_size_override("font_size", maxi(14, px(24)))
	control.add_theme_stylebox_override("normal", box(accent.darkened(.2) if primary else PANEL, accent.lightened(.3) if primary else LINE, 5, 12))
	control.add_theme_stylebox_override("hover", box(accent if primary else RAISED, MINT if primary else IVORY, 5, 12))
	control.add_theme_stylebox_override("pressed", box(accent.darkened(.4) if primary else Color("244030"), MINT, 5, 12))
	control.add_theme_stylebox_override("disabled", box(Color("17201e"), Color("35453e"), 5, 12))
	var focus := box(Color.TRANSPARENT, GOLD, 5, 12)
	focus.set_border_width_all(2)
	control.add_theme_stylebox_override("focus", focus)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: control.add_theme_color_override(state, IVORY)
	control.add_theme_color_override("font_disabled_color", FAINT)
	control.pressed.connect(callback)
	return control

static func chip(text: String, color: Color = MINT) -> PanelContainer:
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", box(Color(color, .10), color, 5, 8))
	var caption := label(text, 21, color)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	frame.add_child(caption)
	return frame

static func gauge(value: float, color: Color = MINT, height: int = 7) -> ProgressBar:
	var control := ProgressBar.new()
	control.value = clampf(value, 0, 100)
	control.show_percentage = false
	control.custom_minimum_size.y = maxi(4, px(height))
	control.add_theme_stylebox_override("background", box(Color("2b3936"), Color.TRANSPARENT, 3, 0))
	control.add_theme_stylebox_override("fill", box(color, Color.TRANSPARENT, 3, 0))
	return control

static func texture(id: String) -> Texture2D:
	if _textures.has(id): return _textures[id]
	if not id.is_valid_filename() or id.contains("."): return null
	var path := "res://art/immersive08/" + id + ".png"
	if not FileAccess.file_exists(path) and not ResourceLoader.exists(path): return null
	var value: Texture2D = load(path)
	if value != null: _textures[id] = value
	return value

static func photo(id: String, minimum: Vector2 = Vector2.ZERO, cover: bool = true) -> TextureRect:
	var control := TextureRect.new()
	control.texture = texture(id)
	control.name = "Art_" + id.replace("-", "_")
	control.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	control.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED if cover else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	control.custom_minimum_size = minimum * density
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.tooltip_text = "Illustration originale fictive générée par IA"
	control.set_meta("immersive_art", id)
	return control

static func veil(parent: Control, horizontal: bool = true) -> TextureRect:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(BG, 1.0))
	gradient.set_color(1, Color(BG, .05))
	gradient.add_point(.45, Color(BG, .95))
	var image := GradientTexture2D.new()
	image.gradient = gradient
	image.fill_from = Vector2.ZERO
	image.fill_to = Vector2.RIGHT if horizontal else Vector2.DOWN
	var overlay := TextureRect.new()
	overlay.texture = image
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(overlay)
	return overlay

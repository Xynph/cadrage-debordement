extends RefCounted
## Présentation commune aux tableaux de bord du club et des finances.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const G = preload("res://ui/game_skin.gd")
const GREEN = Color("176e49")
static var tab_surfaces: Dictionary = {}
static var italic_fonts: Dictionary = {}

static func icon(parent: Node, id: String, at: Vector2, color: Color = C.IVORY, side: int = 27) -> void:
	var picture := C.icon(id, side, color)
	parent.add_child(picture)
	D.place(picture, Rect2(at, Vector2(side, side)))

static func italic(label: Label, weight: int) -> Label:
	if not italic_fonts.has(weight):
		var font := FontVariation.new()
		font.base_font = C.font(weight)
		font.variation_transform = Transform2D(Vector2(1,0),Vector2(-.13,1),Vector2.ZERO)
		italic_fonts[weight] = font
	label.add_theme_font_override("font", italic_fonts[weight])
	return label

static func tab(parent: Node, rectangle: Rect2, caption: String, selected: bool, callback: Callable, id: String) -> Button:
	var control := D.button(parent, rectangle, caption, callback, selected, "", false, GREEN, id)
	control.alignment = HORIZONTAL_ALIGNMENT_CENTER
	control.add_theme_font_size_override("font_size", maxi(14, C.px(27)))
	var dimensions := Vector2i(C.px(rectangle.size.x), C.px(rectangle.size.y))
	var key := str([dimensions, selected])
	if not tab_surfaces.has(key):
		var width := dimensions.x
		var height := dimensions.y
		var slope := C.px(13)
		var colors := ["40a769", "0a542f", "7de299"] if selected else ["283435", "111a1c", "657571"]
		var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d"><defs><linearGradient id="tab" x2="0" y2="1"><stop stop-color="#%s"/><stop offset="1" stop-color="#%s"/></linearGradient></defs><path d="M%d 1 H%d Q%d 1 %d 5 L%d %d Q%d %d %d %d H5 Q1 %d 2 %d L%d 5 Q%d 1 %d 1Z" fill="url(#tab)" stroke="#%s"/></svg>' % [width,height,colors[0],colors[1],slope+3,width-5,width-1,width-2,width-slope,height-5,width-slope-1,height-1,width-slope-5,height-1,height-1,height-5,slope, slope+1,slope+3,colors[2]]
		var bitmap := Image.new()
		if bitmap.load_svg_from_string(svg) == OK:
			var style := StyleBoxTexture.new()
			style.texture = ImageTexture.create_from_image(bitmap)
			tab_surfaces[key] = style
	if tab_surfaces.has(key): control.add_theme_stylebox_override("normal", tab_surfaces[key])
	return control

static func select(app: Control, key: String, value: String, button_id: String) -> void:
	app.management_ui[key] = value
	app._render()
	focus(app, button_id)

static func focus(app: Control, button_id: String, alternate_id: String = "") -> void:
	if button_id.is_empty(): return
	var restore := func():
		if not is_instance_valid(app) or not app.is_inside_tree(): return
		var button: Button = app.find_child(button_id, true, false)
		if button != null and button.disabled and not alternate_id.is_empty():
			button = app.find_child(alternate_id, true, false)
		if button != null and button.is_visible_in_tree() and not button.disabled: button.grab_focus()
	restore.call_deferred()

static func place_detail(parent: Node, rectangle: Rect2, detail: Control) -> void:
	var viewport := Control.new()
	viewport.clip_contents = true
	parent.add_child(viewport)
	D.place(viewport, rectangle)
	viewport.add_child(detail)
	detail.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

static func strategy(model: Dictionary) -> Dictionary:
	return model.get("clubLife", {}).get("clubStrategy", {})

static func amount(value: Variant) -> String:
	if value == null: return "—"
	var absolute := absf(float(value))
	if absolute >= 1000000.0: return ("%.2f M€" % (float(value)/1000000.0)).replace(".", ",").replace("-", "−")
	if absolute >= 10000.0: return ("%.1f k€" % (float(value)/1000.0)).replace(".", ",").replace("-", "−")
	return G.euros(value)

static func art_fade(parent: Control, rectangle: Rect2) -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, C.BG)
	gradient.set_color(1, Color(C.BG, 0.0))
	gradient.add_point(.34, Color(C.BG, .82))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_to = Vector2.RIGHT
	var shade := TextureRect.new()
	shade.texture = texture
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(shade)
	D.place(shade, rectangle)

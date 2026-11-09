extends RefCounted
## Composants natifs placés sur les gabarits approuvés (coordonnées 2560×1440).
const C = preload("res://ui/immersive08/components.gd")
const SURFACE_CACHE_LIMIT := 192
static var surface_textures: Dictionary = {}

static func place(control: Control, rectangle: Rect2) -> Control:
	control.position = rectangle.position * C.density
	control.size = rectangle.size * C.density
	return control

static func surface(width: float, height: float, top: Color, bottom: Color, border: Color, radius: int = 8, highlight: bool = true) -> StyleBoxTexture:
	var w := maxi(1, C.px(width))
	var h := maxi(1, C.px(height))
	var r := C.px(radius)
	# Les pixels horizontaux du dégradé sont constants entre les deux bords.
	# Garder les coins et les extrémités du reflet à leur résolution d’origine.
	var edge := maxi(r + 2, 13 if highlight else 2)
	var strip_width := edge * 2 + 3
	var source_width := mini(w, strip_width)
	var key := str([source_width, h, top, bottom, border, r, highlight])
	if not surface_textures.has(key):
		var shine := '<path d="M12 1H%d" stroke="#b0b8ad" stroke-opacity=".22"/>' % (source_width - 12) if highlight else ""
		var middle := '<stop offset=".14" stop-color="#101719"/>' if top == Color("162022") and bottom == Color("0d1517") else ""
		var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d"><defs><linearGradient id="g" x1="0" y1="0" x2="0" y2="1"><stop stop-color="#%s"/>%s<stop offset="1" stop-color="#%s"/></linearGradient></defs><rect x=".5" y=".5" width="%d" height="%d" rx="%d" fill="url(#g)" stroke="#%s" stroke-opacity="%f"/>%s</svg>' % [source_width, h, top.to_html(false), middle, bottom.to_html(false), source_width - 1, h - 1, r, border.to_html(false), border.a, shine]
		var image := Image.new()
		image.load_svg_from_string(svg)
		if surface_textures.size() >= SURFACE_CACHE_LIMIT: surface_textures.erase(surface_textures.keys()[0])
		surface_textures[key] = ImageTexture.create_from_image(image)
	var style := StyleBoxTexture.new()
	style.texture = surface_textures[key]
	if w >= strip_width:
		style.set_texture_margin(SIDE_LEFT, edge)
		style.set_texture_margin(SIDE_RIGHT, edge)
		# Les bandes de texture ne modifient ni la taille minimale, ni les marges.
		style.content_margin_left = 0
		style.content_margin_right = 0
	return style

static func panel(parent: Node, rectangle: Rect2, title: String = "", icon_id: String = "", badge: String = "", id: String = "") -> Panel:
	var control := Panel.new()
	control.name = id if not id.is_empty() else "Tile"
	control.add_theme_stylebox_override("panel", surface(rectangle.size.x, rectangle.size.y, Color("162022"), Color("0d1517"), C.LINE))
	parent.add_child(control)
	place(control, rectangle)
	if not title.is_empty():
		if not icon_id.is_empty():
			var symbol := C.icon(icon_id, 24, C.GOLD)
			control.add_child(symbol)
			place(symbol, Rect2(19,17,24,24))
		var heading := text(control, 55 if not icon_id.is_empty() else 20, 39, title.to_upper(), 26, C.IVORY, 700, rectangle.size.x-90)
		heading.name = "CardTitle"
		line(control, Vector2(18,56), Vector2(rectangle.size.x-18,56), Color(C.LINE,.7))
		if not badge.is_empty(): text(control, rectangle.size.x-20, 38, badge, 18, C.MUTED, 500, 200, HORIZONTAL_ALIGNMENT_RIGHT)
	return control

static func rect(parent: Node, rectangle: Rect2, color: Color, radius: int = 0, border: Color = Color.TRANSPARENT) -> Panel:
	var control := Panel.new()
	control.add_theme_stylebox_override("panel", C.box(color,border,radius,0))
	parent.add_child(control)
	place(control,rectangle)
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return control

static func text(parent: Node, x: float, baseline: float, value: Variant, font_size: int = 22, color: Color = C.IVORY, weight: int = 600, width: float = 0, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, body: bool = false) -> Label:
	var control := C.label(value,font_size,color,not body,weight)
	control.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	control.horizontal_alignment = align
	var chosen: Font = C.BODY if body else C.font(weight)
	var pixels := maxi(12,C.px(font_size))
	var left := x-width if align == HORIZONTAL_ALIGNMENT_RIGHT else x-width/2 if align == HORIZONTAL_ALIGNMENT_CENTER else x
	parent.add_child(control)
	control.position = Vector2(C.px(left),C.px(baseline)-chosen.get_ascent(pixels))
	control.size = Vector2(C.px(width) if width > 0 else chosen.get_string_size(str(value),HORIZONTAL_ALIGNMENT_LEFT,-1,pixels).x,chosen.get_height(pixels))
	control.tooltip_text = str(value)
	return control

static func line(parent: Node, from: Vector2, to: Vector2, color: Color = C.LINE, thickness: float = 1) -> ColorRect:
	var control := ColorRect.new()
	control.color = color
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(control)
	place(control,Rect2(from,Vector2(maxf(thickness,to.x-from.x),maxf(thickness,to.y-from.y))))
	return control

static func photo(parent: Node, id: String, rectangle: Rect2, vertical_focus: float = 0.0) -> TextureRect:
	var image := C.photo(id, Vector2.ZERO, true, vertical_focus)
	parent.add_child(image)
	place(image,rectangle)
	return image

static func button(parent: Node, rectangle: Rect2, caption: String, callback: Callable, primary: bool = false, icon_id: String = "arrow", small: bool = false, accent: Color = Color("176e49"), id: String = "") -> Button:
	var control := C.button(caption,callback,primary,accent)
	control.name = id if not id.is_empty() else "Action"
	control.alignment = HORIZONTAL_ALIGNMENT_LEFT
	control.clip_text = true
	control.custom_minimum_size = Vector2.ZERO
	control.add_theme_font_size_override("font_size",maxi(12,C.px(21 if small else 25)))
	var top := C.readable_primary_fill(accent.lightened(.12)) if primary else Color("121c1c")
	var bottom := C.readable_primary_fill(accent).darkened(.45) if primary else Color("121c1c")
	var style := surface(rectangle.size.x,rectangle.size.y,top,bottom,Color("74c992") if primary else Color("72817a"),6)
	style.content_margin_left = C.px(18)
	style.content_margin_right = C.px(18)
	control.add_theme_stylebox_override("normal",style)
	if not icon_id.is_empty():
		control.icon = C.icon_texture(icon_id,C.IVORY if primary else C.MUTED)
		control.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		control.expand_icon = true
		control.add_theme_constant_override("icon_max_width",C.px(22))
	parent.add_child(control)
	place(control,rectangle)
	return control

static func chip(parent: Node, rectangle: Rect2, caption: String, color: Color = C.MINT) -> Panel:
	var shade := Color("4a2929") if color == C.ALERT else Color("43361c") if color == C.AMBER else Color("17313a") if color == C.BLUE else Color("123d2c")
	var frame := rect(parent,rectangle,shade,5,Color(color,.7))
	text(frame,rectangle.size.x/2,rectangle.size.y/2+7,caption,19,color,600,rectangle.size.x-(4 if rectangle.size.x<=60 else 12),HORIZONTAL_ALIGNMENT_CENTER)
	return frame

static func tab_state(control: Button, dimensions: Vector2, selected: bool, icon: String) -> void:
	var top := Color("1a6744") if selected else Color("182426")
	var bottom := Color("0b3928") if selected else Color("101819")
	var border := Color("79cf99") if selected else C.LINE
	var states := {
		"normal": [top, bottom],
		"hover": [C.readable_primary_fill(top.lightened(.035)), bottom.lightened(.035)],
		"pressed": [top.darkened(.14), bottom.darkened(.14)],
	}
	for state_name: String in states:
		var colors: Array = states[state_name]
		var style := surface(dimensions.x, dimensions.y, colors[0], colors[1], border, 6)
		style.content_margin_left = C.px(18)
		style.content_margin_right = C.px(18)
		control.add_theme_stylebox_override(state_name, style)
	control.icon = C.icon_texture(icon, C.IVORY if selected else C.MUTED)
	var focus := control.get_theme_stylebox("focus") as StyleBoxFlat
	if focus != null: focus.set_expand_margin_all(2)

static func bar(parent: Node, rectangle: Rect2, value: float, color: Color = C.MINT) -> void:
	rect(parent,rectangle,Color("2b3936"),3)
	var fill := rectangle
	fill.size.x *= clampf(value/100.0,0,1)
	if fill.size.x > 0: rect(parent,fill,color,3)

static func words(value: String, characters: int = 45, count: int = 2) -> Array[String]:
	var result: Array[String] = []
	var current := ""
	for word in value.split(" "):
		if current.length()+word.length()+1 > characters and not current.is_empty():
			result.append(current)
			current = ""
			if result.size() >= count: break
		current += (" " if not current.is_empty() else "") + word
	if result.size() < count and not current.is_empty(): result.append(current)
	return result

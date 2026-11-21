extends RefCounted
## Présentation commune aux tableaux de bord du club et des finances.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const G = preload("res://ui/game_skin.gd")
## Ancien accent des tableaux de bord, encore passé par les appelants ; il n'habille plus ni bouton ni onglet.
const GREEN = Color("176e49")

static func icon(parent: Node, id: String, at: Vector2, color: Color = C.IVORY, side: int = 27) -> void:
	var picture := C.icon(id, side, color)
	parent.add_child(picture)
	D.place(picture, Rect2(at, Vector2(side, side)))

static func tab(parent: Node, rectangle: Rect2, caption: String, selected: bool, callback: Callable, id: String) -> Button:
	# Charte §7.1 : onglet en pilule ; actif = aplat crème, texte PANNEAU ; les autres = contour FILET, texte gris-vert.
	var control := D.button(parent, rectangle, caption, callback, false, "", false, GREEN, id)
	control.alignment = HORIZONTAL_ALIGNMENT_CENTER
	control.add_theme_font_size_override("font_size", maxi(14, C.px(27)))
	var looks := {"normal": [C.IVORY, Color.TRANSPARENT], "hover": [C.IVORY, Color.TRANSPARENT], "pressed": [C.IVORY, Color.TRANSPARENT]} if selected \
		else {"normal": [Color.TRANSPARENT, C.LINE], "hover": [C.RAISED, C.FAINT], "pressed": [C.SELECTED, C.IVORY]}
	for state: String in looks:
		var style := C.box(looks[state][0], looks[state][1], C.Charte.RAYON_PILULE, 18)
		style.content_margin_top = C.px(7)
		style.content_margin_bottom = C.px(7)
		control.add_theme_stylebox_override(state, style)
	for key in ["font_color", "font_focus_color", "font_hover_color", "font_pressed_color"]:
		control.add_theme_color_override(key, C.Charte.PANNEAU if selected else (C.IVORY if key in ["font_hover_color", "font_pressed_color"] else C.MUTED))
	control.set_meta("tab_selected", selected)
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

extends RefCounted
## Plan commun des cartes d'introduction : un calque de référence 2560 × 1440 (× densité du thème),
## mis à l'échelle et centré comme l'accueil (entry_canvas.gd), pour 1080p, 1440p et plein écran.
## Fournit aussi les briques de mise en scène : texte espacé (Barlow Condensed, interlettrage animable)
## et rectangles peints par un shader de ce dossier.
const C = preload("res://ui/immersive08/components.gd")
const REFERENCE := Vector2(2560, 1440)

## Calque de référence ajouté à la carte ; les primitives (primitives.gd) y placent textes et filets.
static func layer(card: Control) -> Control:
	var content := Control.new()
	content.name = "IntroPlan"
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(content)
	card.resized.connect(_fit.bind(card, content))
	_fit(card, content)
	return content

static func _fit(card: Control, content: Control) -> void:
	var reference := REFERENCE * C.density
	var area := card.size if card.size.x > 0 and card.size.y > 0 else card.get_viewport_rect().size
	if area.x <= 0 or area.y <= 0: return
	var scale := minf(area.x / reference.x, area.y / reference.y)
	content.size = reference
	content.scale = Vector2.ONE * scale
	content.position = (area - reference * scale) / 2.0

## Texte centré sur `center_x`, ligne de base `baseline` (coordonnées de référence), interlettrage `tracking`
## en pixels de référence. L'interlettrage reste réglable ensuite avec set_tracking().
static func spaced(parent: Control, value: String, center_x: float, baseline: float, font_size: int, color: Color, font: Font, tracking: float, width: float = 2400.0) -> Label:
	var variation := FontVariation.new()
	variation.base_font = font
	var label := Label.new()
	label.text = value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", variation)
	var pixels := maxi(12, C.px(font_size))
	label.add_theme_font_size_override("font_size", pixels)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", C.px(3))
	label.add_theme_constant_override("shadow_outline_size", C.px(10))
	label.set_meta("center_x", center_x)
	label.set_meta("variation", variation)
	parent.add_child(label)
	label.size = Vector2(C.px(width), font.get_height(pixels))
	label.position = Vector2(C.px(center_x - width / 2.0), C.px(baseline) - font.get_ascent(pixels))
	set_tracking(label, tracking)
	return label

## Interlettrage en pixels de référence ; le texte reste centré (l'espace ajouté après la dernière lettre est compensé).
static func set_tracking(label: Label, tracking: float) -> void:
	var variation: FontVariation = label.get_meta("variation")
	var pixels := tracking * C.density
	variation.spacing_glyph = roundi(pixels)
	var width := label.size.x
	label.position.x = C.px(float(label.get_meta("center_x"))) - width / 2.0 + roundf(pixels) / 2.0

## Rectangle peint par un shader (coordonnées de référence) ; `rectangle` vide = plein cadre de la carte.
static func painted(parent: Control, shader_path: String, rectangle: Rect2 = Rect2()) -> ColorRect:
	var control := ColorRect.new()
	control.color = Color.WHITE
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = load(shader_path)
	control.material = material
	parent.add_child(control)
	if rectangle.size == Vector2.ZERO:
		control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	else:
		control.position = rectangle.position * C.density
		control.size = rectangle.size * C.density
	return control

## Courbe douce commune (accélération puis décélération).
static func soft(t: float) -> float:
	var x := clampf(t, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)

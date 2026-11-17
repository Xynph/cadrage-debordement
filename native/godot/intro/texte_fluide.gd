extends Control
## Texte centré dont l'interlettrage et la montée s'animent sans paliers (prologue de l'intro).
## Un Label applique un interlettrage entier (FontVariation.spacing_glyph) et sa position est calée au pixel :
## un resserrement de 30 à 12 px sur près de 4 s avançait par sauts visibles, lus comme des FPS faibles.
## Ici chaque glyphe est dessiné à une abscisse flottante (crénage conservé par la mise en forme du TextServer).
const C = preload("res://ui/immersive08/components.gd")

var text := ""
var font: Font
var font_size := 16
var color := Color.WHITE
var shadow_color := Color(0, 0, 0, 0.55)
var shadow_offset := Vector2.ZERO
var shadow_outline := 0
## Interlettrage en pixels d'écran (flottant) et décalage vertical vers le bas (flottant).
var tracking := 0.0
var rise := 0.0
var _line: TextLine

func setup(value: String, base_font: Font, pixels: int, ink: Color) -> void:
	text = value
	font = base_font
	font_size = pixels
	color = ink
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_line = TextLine.new()
	_line.add_string(text, font, font_size)
	queue_redraw()

## Interlettrage en pixels de référence (même unité que Plan.set_tracking).
func set_tracking_reference(reference: float) -> void:
	tracking = reference * C.density
	queue_redraw()

func set_rise(pixels: float) -> void:
	rise = pixels
	queue_redraw()

## Largeur dessinée (sans l'espace après la dernière lettre).
func ink_width() -> float:
	if _line == null: return 0.0
	var glyphs := TextServerManager.get_primary_interface().shaped_text_get_glyphs(_line.get_rid())
	var width := 0.0
	for glyph: Dictionary in glyphs: width += float(glyph.get("advance", 0.0))
	return width + tracking * maxf(0.0, float(text.length() - 1))

func _draw() -> void:
	if _line == null or font == null: return
	var ts := TextServerManager.get_primary_interface()
	var glyphs := ts.shaped_text_get_glyphs(_line.get_rid())
	var x := (size.x - ink_width()) / 2.0
	var baseline := font.get_ascent(font_size) + rise
	var canvas := get_canvas_item()
	var last_cluster := -1
	for glyph: Dictionary in glyphs:
		var cluster := int(glyph.get("start", 0))
		# L'interlettrage s'ajoute entre deux caractères, pas entre les glyphes d'un même caractère.
		if last_cluster >= 0 and cluster != last_cluster: x += tracking
		last_cluster = cluster
		var rid: RID = glyph.get("font_rid", RID())
		var index := int(glyph.get("index", 0))
		var offset: Vector2 = glyph.get("offset", Vector2.ZERO)
		var at := Vector2(x, baseline) + offset
		if rid.is_valid() and index != 0:
			if shadow_color.a > 0.0:
				if shadow_outline > 0: ts.font_draw_glyph_outline(rid, canvas, font_size, shadow_outline, at + shadow_offset, index, shadow_color)
				ts.font_draw_glyph(rid, canvas, font_size, at + shadow_offset, index, shadow_color)
			ts.font_draw_glyph(rid, canvas, font_size, at, index, color)
		x += float(glyph.get("advance", 0.0))

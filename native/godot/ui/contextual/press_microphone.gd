extends Control
## Micro du journaliste, dessiné en code : tige, grille et cube de micro aux couleurs du média (sigle du titre). Les
## médias sont ceux du jeu (banque de journalistes) ; aucune marque réelle. Aucune photographie.
var outlet := ""
var outlet_id := ""
var tint := Color("8f2f2a")

static func color_for(id: String) -> Color:
	# Teinte stable par rédaction (hash FNV-1a) : le même média garde la même couleur d'une conférence à l'autre.
	var h := 2166136261
	for c in id.to_utf8_buffer():
		h = ((h ^ c) * 16777619) & 0xffffffff
	return Color.from_hsv(float(h % 360) / 360.0, 0.62, 0.62)

static func initials(name_: String) -> String:
	var result := ""
	for word: String in name_.replace("’", " ").replace("'", " ").split(" ", false):
		if word.length() <= 2 and word.to_lower() in ["le", "la", "l", "de", "du", "des", "et", "y", "the", "and"]: continue
		if result.length() < 3: result += word.left(1).to_upper()
	return result if not result.is_empty() else "?"

func setup(outlet_name: String, id: String) -> void:
	outlet = outlet_name
	outlet_id = id
	tint = color_for(id if not id.is_empty() else outlet_name)
	tooltip_text = outlet_name
	queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	var cx := w * 0.5
	# Tige et pied.
	draw_rect(Rect2(cx - 2.5, h * 0.52, 5, h * 0.40), Color("2a2f2c"))
	draw_rect(Rect2(cx - w * 0.22, h * 0.92, w * 0.44, h * 0.06), Color("1c201e"))
	# Cube de micro (sigle du média) : la face qui se voit à la caméra.
	var cube := Rect2(cx - w * 0.36, h * 0.30, w * 0.72, h * 0.26)
	draw_rect(cube, tint)
	draw_rect(Rect2(cube.position + Vector2(0, cube.size.y - 4), Vector2(cube.size.x, 4)), tint.darkened(0.35))
	var font := get_theme_default_font()
	var label := initials(outlet)
	var font_size := int(cube.size.y * 0.52)
	var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	draw_string(font, Vector2(cx - text_size.x * 0.5, cube.position.y + cube.size.y * 0.5 + font_size * 0.36), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("f6f1e3"))
	# Tête du micro : grille sombre et reflet.
	var head_r := w * 0.20
	var head := Vector2(cx, h * 0.30 - head_r * 0.55)
	draw_circle(head, head_r, Color("23272a"))
	for i in 5:
		var y := head.y - head_r * 0.7 + i * head_r * 0.35
		var half := sqrt(maxf(0.0, head_r * head_r - pow(y - head.y, 2)))
		draw_line(Vector2(cx - half * 0.9, y), Vector2(cx + half * 0.9, y), Color("4a5155"), 1.2)
	draw_circle(head + Vector2(-head_r * 0.35, -head_r * 0.35), head_r * 0.18, Color(1, 1, 1, 0.18))

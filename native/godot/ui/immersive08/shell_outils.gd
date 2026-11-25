extends RefCounted
## Coque commune : petites briques partagées (aplat et pictogramme dessinés, boutons, étiquettes, touches, plancher de texte).
const C = preload("res://ui/immersive08/components.gd")
const Charte = preload("res://ui/charte.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const Shell = preload("res://ui/immersive08/shell.gd")

## Aplat droit de la coque (charte finale : droit partout) : liseré du club, fond doré de Continuer. `rayon` > 0 :
## coins arrondis (pilule avec Charte.RAYON_PILULE) ; sinon rectangle (Charte.decalage vaut 0, plus d'inclinaison).
class Aplat extends Control:
	var couleur := Color.WHITE
	var couleur_survol := Color.TRANSPARENT
	var source: BaseButton
	var rayon := 0
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var h := size.y
		var c := couleur
		if is_instance_valid(source):
			if source.disabled: c = Color(couleur, .55)
			elif couleur_survol.a > 0.0 and (source.is_hovered() or source.button_pressed or source.has_focus()): c = couleur_survol
		if rayon > 0:
			var box := StyleBoxFlat.new()
			box.bg_color = c
			box.set_corner_radius_all(mini(rayon, ceili(h / 2.0)))
			box.anti_aliasing = true
			draw_style_box(box, Rect2(Vector2.ZERO, size))
			return
		var d := Charte.decalage(h)
		draw_colored_polygon(PackedVector2Array([Vector2(d, 0.0), Vector2(size.x, 0.0), Vector2(size.x - d, h), Vector2(0.0, h)]), c)

## Pictogrammes de la coque, dessinés au trait (charte §7.1 : pas de caractère de police, pas de bibliothèque).
class Picto extends Control:
	var forme := ""
	var couleur := Color.WHITE
	var couleur_inactive := Color.WHITE
	var source: BaseButton
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _p(x: float, y: float) -> Vector2:
		return Vector2(x * size.x, y * size.y)
	func _draw() -> void:
		var c := couleur_inactive if is_instance_valid(source) and source.disabled else couleur
		var w := maxf(1.5, size.x * .085)
		match forme:
			"burger":
				for y in [.24, .5, .76]: draw_line(_p(.1, y), _p(.9, y), c, w)
			"gauche", "droite":
				var s := -1.0 if forme == "gauche" else 1.0
				var tip := .5 + s * .34
				draw_line(_p(.5 - s * .34, .5), _p(tip, .5), c, w)
				draw_line(_p(tip, .5), _p(tip - s * .28, .24), c, w)
				draw_line(_p(tip, .5), _p(tip - s * .28, .76), c, w)
				# Impossible (bord de l'historique) : flèche barrée, en plus de la teinte ivoire-3 (couleur jamais seule).
				if is_instance_valid(source) and source.disabled: draw_line(_p(.18, .86), _p(.82, .14), c, w)
			"loupe":
				draw_arc(_p(.42, .42), size.x * .28, 0.0, TAU, 32, c, w, true)
				draw_line(_p(.62, .62), _p(.9, .9), c, w)
			"carriere":
				draw_arc(_p(.5, .52), size.x * .34, deg_to_rad(-60.0), deg_to_rad(230.0), 32, c, w, true)
				var bout := _p(.5, .52) + Vector2.from_angle(deg_to_rad(-60.0)) * size.x * .34
				draw_line(bout, bout + Vector2(-size.x * .2, -size.y * .04), c, w)
				draw_line(bout, bout + Vector2(size.x * .02, size.y * .2), c, w)
			"reglages":
				draw_arc(_p(.5, .5), size.x * .17, 0.0, TAU, 24, c, w, true)
				for i in 8:
					var a := TAU * i / 8.0
					draw_line(_p(.5, .5) + Vector2.from_angle(a) * size.x * .28, _p(.5, .5) + Vector2.from_angle(a) * size.x * .44, c, w)
			"sauver":
				draw_line(_p(.5, .1), _p(.5, .66), c, w)
				draw_line(_p(.5, .66), _p(.26, .42), c, w)
				draw_line(_p(.5, .66), _p(.74, .42), c, w)
				draw_line(_p(.14, .9), _p(.86, .9), c, w)
			"coche":
				draw_polyline(PackedVector2Array([_p(.12, .54), _p(.4, .8), _p(.88, .24)]), c, w, true)
			"alerte":
				draw_line(_p(.5, .1), _p(.5, .62), c, w * 1.2)
				draw_circle(_p(.5, .86), w * .8, c)

## Plancher des textes de la coque en pixels de construction : 12 px réels une fois le gabarit mis à l'échelle
## (_fit_layout peut le réduire de quelques pour cent pour loger le pied de page, 0,977 à 1280 × 720).
static var _coque_floor := 12
## Facteur prévu du gabarit (_fit_layout) pour la fenêtre en cours : cibles de la coque en pixels réels.
static var _coque_factor := 1.0

static func _fpx(size_ref: float) -> int:
	return maxi(_coque_floor, C.px(size_ref))

## Facteur que _fit_layout appliquera au gabarit pour cette taille de fenêtre.
static func _predicted_factor(size: Vector2, reference: Vector2) -> float:
	if size.x <= 0 or size.y <= 0: return 1.0
	var factor := minf(size.x / reference.x, size.y / reference.y)
	var base_footer := C.px(44)
	if base_footer * factor < 38.0 and size.y > 38.0: factor = minf(factor, (size.y - 38.0) / (reference.y - base_footer))
	return factor

## Largeur d'un texte en unités de référence (mesuré à la taille réellement rendue, plancher 12 px compris).
static func _rw(font: Font, text: String, size_ref: float) -> float:
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _fpx(size_ref)).x / C.density

static func _style(color: Color, radius: float = 0.0, border: Color = Color.TRANSPARENT, border_width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.draw_center = color.a > 0.0
	style.set_corner_radius_all(C.px(radius) if radius > 0.0 else 0)
	if border.a > 0.0:
		style.border_color = border
		style.set_border_width_all(border_width)
	return Charte.ombrer(style, radius)

## Bouton de la coque : fond transparent, survol panneau-2, pressé panneau-3, focus clavier anneau doré 2 px
## décalé de 2 px (charte §7.1, États). `contour` : filet 1 px `FILET` (bouton secondaire : Menu, Précédent, Suivant).
## `rayon` en unités de référence (Charte.RAYON_PILULE : pilule).
static func _shell_button(id: String, contour: bool = false, radius: float = 0.0) -> Button:
	var button := Button.new()
	button.name = id
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.clip_text = true
	button.set_meta("immersive_style_applied", true)
	var border := C.LINE if contour else Color.TRANSPARENT
	var fills := {"normal":Color.TRANSPARENT, "hover":C.RAISED, "pressed":C.SELECTED, "hover_pressed":C.SELECTED, "disabled":Color.TRANSPARENT}
	for state: String in fills: button.add_theme_stylebox_override(state, _style(fills[state], radius, border))
	var focus := _style(Color.TRANSPARENT, radius, C.OR, 2)
	focus.set_expand_margin_all(2)
	button.add_theme_stylebox_override("focus", focus)
	button.add_theme_font_override("font", C.BODY)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]: button.add_theme_color_override(state, C.IVORY)
	button.add_theme_color_override("font_disabled_color", C.FAINT)
	return button

static func _button_margins(button: Button, left: float, right: float = 0.0) -> void:
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		var style := button.get_theme_stylebox(state)
		style.content_margin_left = C.px(left)
		style.content_margin_right = C.px(right)

static func _label(parent: Node, rect: Rect2, text: String, size_ref: float, color: Color, font: Font, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", _fpx(size_ref))
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_meta("immersive_style_applied", true)
	parent.add_child(label)
	D.place(label, rect)
	return label

## Touche écrite (« Échap », « Ctrl K », « Ctrl S », « F1 ») : pavé panneau-3 rayon 6 px, Barlow Condensed SemiBold
## ivoire-2.
static func _key(parent: Node, x: float, y: float, text: String, fond: Color = C.SELECTED) -> Panel:
	var width := _rw(C.DISPLAY, text, 16) + 16.0
	var chip := Panel.new()
	chip.name = "Touche_" + text.replace(" ", "")
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_theme_stylebox_override("panel", _style(fond, Shell.RAYON_PETIT_REF))
	parent.add_child(chip)
	D.place(chip, Rect2(x, y, width, 27))
	_label(chip, Rect2(0, 0, width, 27), text, 16, C.MUTED, C.DISPLAY, HORIZONTAL_ALIGNMENT_CENTER)
	return chip

static func _key_width(text: String) -> float:
	return _rw(C.DISPLAY, text, 16) + 16.0

static func _picto(parent: Node, rect: Rect2, forme: String, color: Color = C.MUTED, source: BaseButton = null) -> Picto:
	var picto := Picto.new()
	picto.name = "Picto_" + forme
	picto.forme = forme
	picto.couleur = color
	picto.couleur_inactive = C.FAINT
	picto.source = source
	parent.add_child(picto)
	D.place(picto, rect)
	if source != null: source.draw.connect(picto.queue_redraw)
	return picto

static func _aplat(parent: Node, rect: Rect2, color: Color, radius: int = 0) -> Aplat:
	var shape := Aplat.new()
	shape.couleur = color
	shape.rayon = radius
	parent.add_child(shape)
	D.place(shape, rect)
	return shape

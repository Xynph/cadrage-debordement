extends RefCounted
## Champs de saisie, listes déroulantes et cases à cocher aux jetons de la charte finale (design/art/art-bible.md §3) :
## champs et listes en pilule sur `PANNEAU_3` avec contour 1 px `FILET`, case arrondie crème, anneau de focus doré 2 px.
## Sert aux vues adoptées (Suivi des jeunes) et à la page « Relire les actions ».
## Exemple : `Champs.liste(stage)`, `Champs.champ(search)`, `Champs.case(review_filter)`.
const C = preload("res://ui/immersive08/components.gd")
const Charte = preload("res://ui/charte.gd")

static func _marque(controle: Control) -> void:
	# Les vues adoptées ne sont plus rhabillées par le style générique : ce contrôle est déjà à la charte.
	controle.set_meta("style_charte", true)
	controle.set_meta("immersive_style_applied", true)

## Anneau de focus : doré, 2 px, arrondi comme le contrôle.
static func _anneau(rayon: int) -> StyleBoxFlat:
	var focus := C.box(Color.TRANSPARENT, Charte.OR, rayon, 2)
	focus.set_border_width_all(2)
	return focus

static func champ(champ_texte: LineEdit) -> void:
	_marque(champ_texte)
	var fond := C.box(Charte.PANNEAU_3, Charte.FILET, Charte.RAYON_PILULE, 10)
	fond.content_margin_left = C.px(16)
	fond.content_margin_right = C.px(16)
	for etat in ["normal", "read_only"]: champ_texte.add_theme_stylebox_override(etat, fond)
	champ_texte.add_theme_stylebox_override("focus", _anneau(Charte.RAYON_PILULE))
	champ_texte.add_theme_font_override("font", Charte.TEXTE)
	champ_texte.add_theme_font_size_override("font_size", maxi(12, C.px(18)))
	champ_texte.add_theme_color_override("font_color", Charte.IVOIRE)
	champ_texte.add_theme_color_override("font_placeholder_color", Charte.IVOIRE_3)
	champ_texte.add_theme_color_override("caret_color", Charte.OR)

static func liste(choix: OptionButton) -> void:
	_marque(choix)
	choix.add_theme_font_override("font", Charte.TEXTE)
	choix.add_theme_font_size_override("font_size", maxi(12, C.px(18)))
	for couleur in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]: choix.add_theme_color_override(couleur, Charte.IVOIRE)
	choix.add_theme_color_override("font_disabled_color", Charte.IVOIRE_3)
	var fond := C.box(Charte.PANNEAU_3, Charte.FILET, Charte.RAYON_PILULE, 10)
	fond.content_margin_left = C.px(16)
	var survol := C.box(Charte.PANNEAU_2, Charte.FILET, Charte.RAYON_PILULE, 10)
	survol.content_margin_left = C.px(16)
	for etat in ["normal", "pressed", "disabled"]: choix.add_theme_stylebox_override(etat, fond)
	choix.add_theme_stylebox_override("hover", survol)
	choix.add_theme_stylebox_override("focus", _anneau(Charte.RAYON_PILULE))
	var menu := choix.get_popup()
	menu.add_theme_stylebox_override("panel", C.box(Charte.PANNEAU_3, Charte.FILET, Charte.RAYON_CARTE, 6))
	menu.add_theme_stylebox_override("hover", C.box(Charte.PANNEAU_2, Color.TRANSPARENT, 8, 4))
	menu.add_theme_font_override("font", Charte.TEXTE)
	menu.add_theme_font_size_override("font_size", maxi(12, C.px(18)))
	menu.add_theme_color_override("font_color", Charte.IVOIRE)
	menu.add_theme_color_override("font_hover_color", Charte.IVOIRE)

## Case à cocher (CheckButton ou CheckBox) : carré arrondi ; coché = aplat crème et coche sombre, décoché = contour gris-vert.
static func case(bouton: Button) -> void:
	_marque(bouton)
	var cote := maxi(14, C.px(22))
	for nom in ["unchecked", "radio_unchecked", "unchecked_disabled"]: bouton.add_theme_icon_override(nom, _dessin(cote, false))
	for nom in ["checked", "radio_checked", "checked_disabled"]: bouton.add_theme_icon_override(nom, _dessin(cote, true))
	bouton.add_theme_font_override("font", Charte.TEXTE)
	bouton.add_theme_font_size_override("font_size", maxi(12, C.px(18)))
	for couleur in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]: bouton.add_theme_color_override(couleur, Charte.IVOIRE)
	var vide := StyleBoxEmpty.new()
	for etat in ["normal", "hover", "pressed", "hover_pressed", "disabled"]: bouton.add_theme_stylebox_override(etat, vide)
	bouton.add_theme_stylebox_override("focus", _anneau(Charte.RAYON_PILULE))
	bouton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

static func _dessin(cote: int, coche: bool) -> ImageTexture:
	var image := Image.create(cote, cote, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var rayon := cote * 0.28
	var epaisseur := maxf(1.5, cote / 10.0)
	for x in cote:
		for y in cote:
			# Distance signée au carré arrondi (centre du pixel).
			var p := Vector2(x + 0.5 - cote / 2.0, y + 0.5 - cote / 2.0).abs() - Vector2(cote / 2.0 - rayon, cote / 2.0 - rayon)
			var distance := Vector2(maxf(p.x, 0.0), maxf(p.y, 0.0)).length() + minf(maxf(p.x, p.y), 0.0) - rayon
			var couverture := clampf(0.5 - distance, 0.0, 1.0)
			if couverture <= 0.0: continue
			var couleur := Charte.IVOIRE if coche else Charte.IVOIRE_2
			if not coche and distance < -epaisseur: couleur = Color(couleur, 0.0)
			image.set_pixel(x, y, Color(couleur, couleur.a * couverture))
	if coche:
		# Coche sombre : deux segments épais sur l'aplat crème.
		var a := Vector2(cote * 0.26, cote * 0.52)
		var b := Vector2(cote * 0.43, cote * 0.70)
		var c := Vector2(cote * 0.76, cote * 0.32)
		for x in cote:
			for y in cote:
				var q := Vector2(x + 0.5, y + 0.5)
				var d := minf(_segment(q, a, b), _segment(q, b, c))
				if d < maxf(1.0, cote / 11.0): image.set_pixel(x, y, Charte.PANNEAU)
	return ImageTexture.create_from_image(image)

static func _segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)

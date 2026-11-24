extends RefCounted
## Finances : pièces graphiques communes (styles, textes, panneaux, boutons de la charte, zones cliquables).
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const Charte = preload("res://ui/charte.gd")
const SurvolLigne = preload("res://ui/survol_ligne.gd")
const Pieces = preload("res://ui/immersive08/petites_pieces.gd")
const Traces = preload("res://ui/immersive08/finance_traces.gd")

static func _style(fond: Color, bord: Color = Color.TRANSPARENT, epaisseur: int = 0, bas_seulement: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fond
	style.set_corner_radius_all(Charte.RAYON_PETIT)
	if bord.a > 0.0 and epaisseur > 0:
		style.border_color = bord
		if bas_seulement: style.border_width_bottom = epaisseur
		else: style.set_border_width_all(epaisseur)
	return style

static func _pilule(fond: Color, contour: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var style := C.box(fond, contour, Charte.RAYON_PILULE, 12)
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	return style

static func _titre(parent: Node, x: float, baseline: float, valeur: String, taille: int, couleur: Color = Charte.IVOIRE, largeur: float = 0.0, aligne: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := D.text(parent, x, baseline, valeur, taille, couleur, 700, largeur, aligne)
	label.add_theme_font_override("font", Charte.TITRE_GRAS_ITALIQUE)
	return label

static func _texte(parent: Node, x: float, baseline: float, valeur: String, taille: int, couleur: Color = Charte.IVOIRE, largeur: float = 0.0, aligne: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	return D.text(parent, x, baseline, valeur, taille, couleur, 500, largeur, aligne, true)

static func _etiquette(parent: Node, x: float, baseline: float, valeur: String, largeur: float = 0.0, aligne: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	return D.text(parent, x, baseline, valeur.to_upper(), 15, Charte.IVOIRE_2, 600, largeur, aligne)

static func _panneau(parent: Node, rectangle: Rect2, titre: String, id: String, legende: String = "") -> Panel:
	var panel := Panel.new()
	panel.name = id
	# Panneau de l'écran (rayon 6 propre aux Finances) : ombre portée de la charte, comme tout panneau.
	panel.add_theme_stylebox_override("panel", Charte.ombrer(_style(Charte.PANNEAU), Charte.RAYON_PANNEAU))
	parent.add_child(panel)
	D.place(panel, rectangle)
	if not titre.is_empty():
		var entete := _titre(panel, 20, 40, titre.to_upper(), 26, Charte.IVOIRE, rectangle.size.x - 40)
		entete.name = "CardTitle"
		if not legende.is_empty():
			var droite := _etiquette(panel, rectangle.size.x - 20, 38, legende, rectangle.size.x * .6, HORIZONTAL_ALIGNMENT_RIGHT)
			droite.name = "CardCaption"
	return panel

## Petit « i » juste après le titre d'un panneau (l'explication passe en infobulle).
static func _info_titre(panel: Panel, titre: String, bulle: String, id: String) -> void:
	Pieces.info(panel, 20.0 + Pieces.largeur_titre(titre.to_upper(), 26) + 12.0, 18, bulle, id)

static func _bloc(parent: Node, rectangle: Rect2, fond: Color = Charte.PANNEAU_2, bord: Color = Color.TRANSPARENT) -> Panel:
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _style(fond, bord, 2 if bord.a > 0.0 else 0))
	parent.add_child(panel)
	D.place(panel, rectangle)
	return panel

static func _symbole(parent: Node, rectangle: Rect2, forme: String, couleur: Color = Charte.IVOIRE) -> Traces.Symbole:
	var symbole := Traces.Symbole.new()
	symbole.forme = forme
	symbole.couleur = couleur
	symbole.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(symbole)
	D.place(symbole, rectangle)
	return symbole

## Fenêtre étroite (sous 1920 × 1080) : le plancher de 12 px grossit nettement le petit texte par rapport au gabarit.
static func _etroit() -> bool:
	return float(C.font_px(16)) > float(C.px(16)) * 1.2

static func _forme_palier(palier: int) -> String:
	return "coche" if palier == 0 else "croix" if palier == 2 else "exclam"

## Boutons de la charte : « lien » (texte ivoire + flèche), « ivoire » (l'action principale de l'écran), « onglet ».
static func _bouton(parent: Node, rectangle: Rect2, libelle: String, action: Callable, mode: String, icone: String, id: String, choisi: bool = false) -> Button:
	var bouton := Button.new()
	bouton.name = id
	bouton.text = libelle
	bouton.focus_mode = Control.FOCUS_ALL
	bouton.clip_text = true
	bouton.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	bouton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	bouton.alignment = HORIZONTAL_ALIGNMENT_CENTER if mode == "onglet" else HORIZONTAL_ALIGNMENT_RIGHT
	var titre := mode in ["ivoire", "onglet"]
	bouton.add_theme_font_override("font", Charte.TITRE_GRAS if titre else C.font(600))
	bouton.add_theme_font_size_override("font_size", C.font_px(21 if titre else 18))
	var texte: Color = Charte.IVOIRE if (mode in ["lien", "ivoire"] or choisi) else Charte.IVOIRE_2
	for etat in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		bouton.add_theme_color_override(etat, texte)
	bouton.add_theme_color_override("font_disabled_color", Charte.IVOIRE_3)
	var normal := _style(Charte.PANNEAU_3 if mode == "onglet" and choisi else Charte.IVOIRE if mode == "ivoire" else Color.TRANSPARENT, Charte.IVOIRE if choisi else Color.TRANSPARENT, 3, true)
	var survol := _style(Charte.IVOIRE_2 if mode == "ivoire" else Charte.PANNEAU_3 if choisi else Charte.PANNEAU_2, Charte.IVOIRE if choisi else Color.TRANSPARENT, 3, true)
	var inactif := _style(Charte.PANNEAU_3 if mode == "ivoire" else Color.TRANSPARENT)
	if mode in ["onglet", "ivoire"]:
		# Charte finale : pilule. Onglet actif = aplat crème ; bouton « ivoire » = pilule à contour (un seul aplat doré : Continuer).
		var plein := mode == "onglet" and choisi
		normal = _pilule(Charte.IVOIRE if plein else Color.TRANSPARENT, Charte.FILET if mode == "ivoire" else Color.TRANSPARENT)
		survol = _pilule(Charte.IVOIRE if plein else Charte.PANNEAU_2, Charte.IVOIRE_3 if mode == "ivoire" else Color.TRANSPARENT)
		inactif = _pilule(Color.TRANSPARENT, Charte.FILET if mode == "ivoire" else Color.TRANSPARENT)
		for etat in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			bouton.add_theme_color_override(etat, Charte.PANNEAU if plein else (Charte.IVOIRE_2 if mode == "onglet" and etat == "font_color" else Charte.IVOIRE))
	for style: StyleBoxFlat in [normal, survol, inactif]:
		style.content_margin_left = C.px(12)
		style.content_margin_right = C.px(12)
		style.content_margin_top = 0
		style.content_margin_bottom = 0
	bouton.add_theme_stylebox_override("normal", normal)
	bouton.add_theme_stylebox_override("hover", survol)
	bouton.add_theme_stylebox_override("pressed", survol)
	bouton.add_theme_stylebox_override("hover_pressed", survol)
	bouton.add_theme_stylebox_override("disabled", inactif)
	bouton.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, Charte.IVOIRE, 2))
	if not icone.is_empty():
		bouton.icon = C.icon_texture(icone, Charte.PANNEAU if mode == "onglet" and choisi else Charte.IVOIRE)
		bouton.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		bouton.expand_icon = true
		bouton.add_theme_constant_override("icon_max_width", C.px(20))
	bouton.pressed.connect(action)
	parent.add_child(bouton)
	D.place(bouton, C.reach_rect(rectangle))
	return bouton

## Zone cliquable d'une ligne ou d'un bloc (posée AVANT son texte : les libellés laissent passer la souris).
## `ligne` : la zone est une ligne de tableau (survol de ligne commun, rayure une sur deux) ; sinon une tuile (retour
## commun de ui/retour_tuile.gd).
static func _zone(parent: Node, rectangle: Rect2, action: Callable, id: String, infobulle: String, ligne: bool = false) -> Button:
	var zone := Button.new()
	zone.name = id
	zone.flat = true
	zone.focus_mode = Control.FOCUS_ALL
	zone.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	zone.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	zone.add_theme_stylebox_override("hover", _style(Charte.PANNEAU_2))
	zone.add_theme_stylebox_override("pressed", _style(Charte.PANNEAU_3))
	zone.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, Charte.IVOIRE, 2))
	zone.tooltip_text = infobulle
	zone.accessibility_name = infobulle
	zone.pressed.connect(action)
	parent.add_child(zone)
	D.place(zone, rectangle)
	if ligne: SurvolLigne.appliquer(zone)
	else: load("res://ui/retour_tuile.gd").brancher(zone, zone, C.px(Charte.RAYON_CARTE))
	return zone

## Rayure d'une ligne sur deux (rang impair) posée en Panel, comme l'Effectif (ui/survol_ligne.gd).
static func _rayer(parent: Node, rectangle: Rect2, rang: int) -> void:
	var rayure := SurvolLigne.rayure(parent, rang)
	if rayure != null: D.place(rayure, rectangle)

static func _hachure_legende(parent: Node, x: float, y: float, plein: bool) -> void:
	var cadre := _bloc(parent, Rect2(x, y, 19, 13), Color(Charte.IVOIRE_2, 1.0 if plein else .18), Charte.IVOIRE_2)
	if not plein:
		for i in 3: D.line(cadre, Vector2(3 + i * 5, 11), Vector2(8 + i * 5, 1), Charte.IVOIRE_2)

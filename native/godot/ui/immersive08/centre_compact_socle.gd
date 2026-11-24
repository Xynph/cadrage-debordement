extends RefCounted
## Centre compact, socle (découpe de centre_compact.gd, sans changement) : préchargements, constantes, toile des petites fenêtres,
## marquage du style et petites pièces de dessin (texte, chiffre, icône, rangées, pastille, zone cliquable).
## Chaîne d'héritage : socle ← pièces et en-tête ← listes et chemin ← onglet Centre ← Parcours et Centres ← Filières, Passerelle pro
## et Générations ← centre_compact.gd (fichier public : `build` et `_remplir`).

const V = preload("res://ui/immersive08/centre_visuel.gd")
const T = preload("res://ui/immersive08/centre_onglets.gd")
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const G = preload("res://ui/carnet_skin.gd")
const Charte = preload("res://ui/charte.gd")
const Bandeau = preload("res://ui/bandeau_filtres.gd")
const CarteSurvol = preload("res://ui/carte_joueur_survol.gd")
const Juniors = preload("res://ui/immersive08/centre_juniors.gd")
const Listes = preload("res://ui/immersive08/listes_joueurs.gd")

const NOM_PAGE := "CarnetAcademyPathways"
const CORPS := 13
const PETIT := 12
const HAUT_LIGNE := 36.0
const HAUT_COMMANDE := 28.0
const ECART := 8

## Tout est déjà habillé ici : le style des vues anciennes (legacy_style.gd) ne doit rien repeindre.
static func _marquer(noeud: Node) -> void:
	if noeud is Control: (noeud as Control).set_meta("immersive_style_applied", true)
	for enfant in noeud.get_children(): _marquer(enfant)

## Toile des petites fenêtres : une page à l'échelle du gabarit (2248 × 1230), centrée au-dessus de toute la fenêtre.
static func _preparer(ctx: Dictionary) -> void:
	var hote: Variant = ctx.get("hote")
	if is_instance_valid(hote) and (hote as Node).is_inside_tree():
		ctx.page = (hote as Node).get_meta("toile")
		return
	var conteneur: Control = ctx.app.root_content if is_instance_valid(ctx.app.root_content) else ctx.app
	var nouvel := Control.new()
	nouvel.name = "CentreCompactFenetres"
	nouvel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	conteneur.add_child(nouvel)
	nouvel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var toile := Control.new()
	toile.name = "CentreCompactToile"
	toile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nouvel.add_child(toile)
	toile.size = Vector2(2248, 1230) * C.density
	var centrer := func():
		if is_instance_valid(toile) and is_instance_valid(nouvel): toile.position = ((nouvel.size - toile.size) / 2.0).round()
	nouvel.resized.connect(centrer)
	centrer.call()
	nouvel.set_meta("toile", toile)
	ctx.hote = nouvel
	ctx.page = toile

## Ouvre une petite fenêtre de la grande page : `ouvrir` reçoit le contexte dont `page` est la toile.
static func _fenetre(ctx: Dictionary, ouvrir: Callable) -> Callable:
	return func():
		_preparer(ctx)
		ouvrir.call()

# --- Pièces ----------------------------------------------------------------------------------------------------------

static func _ignorer(noeud: Node) -> void:
	if noeud is Control: (noeud as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE

static func _mesure(texte: String, taille: int, police: Font = null) -> float:
	return (police if police != null else C.BODY).get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x

static func _txt(parent: Node, valeur: Variant, taille: int = CORPS, couleur: Color = Charte.IVOIRE, police: Font = null, alignement: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, coupe: bool = false) -> Label:
	var l := Label.new()
	l.text = str(valeur)
	l.add_theme_font_override("font", police if police != null else C.BODY)
	l.add_theme_font_size_override("font_size", maxi(PETIT, taille))
	l.add_theme_color_override("font_color", couleur)
	l.horizontal_alignment = alignement
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.set_meta("immersive_style_applied", true)
	if coupe:
		l.clip_text = true
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if parent != null: parent.add_child(l)
	return l

## Légende en capitales (Barlow gras), couleur faible.
static func _legende(parent: Node, texte: String, couleur: Color = Charte.IVOIRE_3, taille: int = PETIT) -> Label:
	return _txt(parent, texte.to_upper(), taille, couleur, C.BOLD)

## Chiffre en Barlow extra-gras de la couleur de sa donnée.
static func _chiffre(parent: Node, valeur: Variant, taille: int, couleur: Color = Charte.IVOIRE, alignement: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	return _txt(parent, valeur, taille, couleur, Charte.TITRE_EXTRA, alignement)

static func _icone(parent: Node, id: String, cote: int, couleur: Color) -> TextureRect:
	var i := C.icon(id, roundi(cote / C.density), couleur)
	i.custom_minimum_size = Vector2(cote, cote)
	i.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if parent != null: parent.add_child(i)
	return i

static func _espace(parent: Node) -> Control:
	var e := Control.new()
	e.mouse_filter = Control.MOUSE_FILTER_IGNORE
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(e)
	return e

static func _rangee(parent: Node, ecart: int = ECART) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", ecart)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if parent != null: parent.add_child(h)
	return h

static func _flux(parent: Node, ecart: int = ECART) -> HFlowContainer:
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", ecart)
	f.add_theme_constant_override("v_separation", ecart)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	f.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if parent != null: parent.add_child(f)
	return f

## Pastille d'état (voile de la couleur, icône et texte de la couleur) : jamais un bouton.
static func _pastille(parent: Node, texte: String, couleur: Color, icone: String = "") -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := V.plat(Color(couleur, .15), Color.TRANSPARENT, 0, 8)
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 3
	s.content_margin_bottom = 3
	p.add_theme_stylebox_override("panel", s)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var h := _rangee(p, 5)
	if not icone.is_empty(): _icone(h, icone, 14, couleur)
	_txt(h, texte, PETIT, couleur, C.BOLD)
	if parent != null: parent.add_child(p)
	return p

## Bouton plat qui couvre sa place : voile clair au survol, main, focus. Les enfants ne reçoivent pas la souris.
static func _zone(action: Callable, id: String, aide: String, rayon: int = 8, haut: float = HAUT_COMMANDE, fond: Color = Color.TRANSPARENT, bord: Color = Color.TRANSPARENT) -> Button:
	var b := Button.new()
	b.name = id
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.accessibility_name = aide
	b.custom_minimum_size.y = haut
	for etat: String in ["normal", "hover", "pressed", "focus"]:
		var s: StyleBoxFlat
		if etat == "focus": s = V.plat(Color.TRANSPARENT, Charte.IVOIRE, 1, rayon)
		elif etat == "normal": s = V.plat(fond, bord, 1 if bord.a > 0 else 0, rayon)
		else: s = V.plat(fond.lerp(Charte.IVOIRE, .08 if etat == "hover" else .14) if fond.a > 0 else Color(Charte.IVOIRE, .08 if etat == "hover" else .14), bord, 1 if bord.a > 0 else 0, rayon)
		b.add_theme_stylebox_override(etat, s)
	if action.is_valid(): b.pressed.connect(action)
	return b

## Rangée posée DANS un bouton (marges et centrage vertical) ; renvoie la rangée où poser les éléments.
static func _dans(bouton: Button, marge: int = 8, ecart: int = ECART) -> HBoxContainer:
	var m := MarginContainer.new()
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_theme_constant_override("margin_left", marge)
	m.add_theme_constant_override("margin_right", marge)
	bouton.add_child(m)
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var h := _rangee(m, ecart)
	return h

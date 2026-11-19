extends RefCounted
## Petits éléments dessinés de la Composition (design/ux/10-composition.md, maquette 10-composition-1 du 19/11/2026) :
## ovale de joueur, marqueur incliné, bouton ivoire, titres de section, étiquettes, liens, touches, barre de condition.
## Coordonnées en unités du gabarit (2248 de large), couleurs uniquement depuis ui/charte.gd.
## Exemple : `Kit.titre(bloc, 22, 34, "Banc 8/8")` puis `Kit.etiquette(bloc, 578, 32, "1re ligne 6/6", 300, true)`.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const Charte = preload("res://ui/charte.gd")
const Link = preload("res://ui/entity_link.gd")
static var _gras: FontVariation

## Ovale de joueur (charte §3) : nous = plein aux couleurs du club et liseré clair ; adversaire = anneau seul.
class Ovale extends Control:
	var numero := ""
	var fond := Charte.CLUB
	var bordure := Charte.CLUB_TRAIT
	var plein := true
	var texte := Charte.IVOIRE
	var police: Font = Charte.TEXTE
	func _draw() -> void:
		var centre := size / 2.0
		var points := PackedVector2Array()
		for i in 48:
			var angle := TAU * i / 48.0
			points.append(centre + Vector2(cos(angle) * (size.x / 2.0 - 1.0), sin(angle) * (size.y / 2.0 - 1.0)))
		if plein: draw_colored_polygon(points, fond)
		var bord := points.duplicate()
		bord.append(points[0])
		draw_polyline(bord, bordure, maxf(1.5, size.y * .07), true)
		var taille := maxi(12, roundi(size.y * .56))
		var largeur := police.get_string_size(numero, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x
		var ligne := centre.y + (police.get_ascent(taille) - police.get_descent(taille)) / 2.0
		draw_string(police, Vector2(centre.x - largeur / 2.0, ligne), numero, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, texte)

## Marqueur de sélection : trait plein incliné de 10° (comme les fûts du logo).
class Marqueur extends Control:
	var couleur := Charte.IVOIRE
	func _draw() -> void:
		var decalage := size.y * tan(deg_to_rad(Charte.INCLINAISON_DEGRES))
		draw_colored_polygon(PackedVector2Array([Vector2(decalage, 0), Vector2(size.x + decalage, 0), Vector2(size.x, size.y), Vector2(0, size.y)]), couleur)

## Fond d'un bouton plein dont le bord droit est incliné de 10° (dessiné derrière le bouton).
class FondIncline extends Control:
	var couleur := Charte.IVOIRE
	func _draw() -> void:
		var decalage := size.y * tan(deg_to_rad(Charte.INCLINAISON_DEGRES))
		draw_colored_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), Vector2(size.x - decalage, size.y), Vector2(0, size.y)]), couleur)

## DM Sans graisse 700 (chiffres des ovales, notes au poste).
static func texte_gras() -> Font:
	if _gras == null:
		_gras = FontVariation.new()
		_gras.base_font = Charte.TEXTE
		_gras.variation_opentype = {"wght": 700}
	return _gras

## Ovale « nous » aux couleurs du club (`accent` = couleur réelle du club).
static func ovale(parent: Control, zone: Rect2, numero: String, accent: Color) -> Ovale:
	var forme := Ovale.new()
	forme.numero = numero
	forme.police = texte_gras()
	forme.fond = C.readable_primary_fill(accent if accent.a > 0 else Charte.CLUB)
	forme.bordure = Charte.club_trait(accent)
	forme.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(forme)
	D.place(forme, zone)
	return forme

static func marqueur(parent: Control, zone: Rect2, couleur: Color = Charte.IVOIRE) -> Marqueur:
	var barre := Marqueur.new()
	barre.couleur = couleur
	barre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(barre)
	D.place(barre, zone)
	return barre

## Titre de section en capitales italiques (Barlow Condensed, vraie italique).
static func titre(parent: Control, x: float, ligne: float, texte: String, taille: int = 24, largeur: float = 900) -> Label:
	var label := D.text(parent, x, ligne, texte.to_upper(), taille, Charte.IVOIRE, 700, largeur)
	label.add_theme_font_override("font", Charte.TITRE_GRAS_ITALIQUE)
	label.name = "CardTitle"
	return label

## Étiquette en petites capitales (ivoire-2), alignée à droite si `droite`.
static func etiquette(parent: Control, x: float, ligne: float, texte: String, largeur: float, droite: bool = false, couleur: Color = Charte.IVOIRE_2) -> Label:
	return D.text(parent, x, ligne, texte.to_upper(), 16, couleur, 600, largeur, HORIZONTAL_ALIGNMENT_RIGHT if droite else HORIZONTAL_ALIGNMENT_LEFT)

## Texte courant DM Sans (13 px à 1920 = 18 unités).
static func texte(parent: Control, x: float, ligne: float, valeur: String, couleur: Color = Charte.IVOIRE, largeur: float = 0, taille: int = 18, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	return D.text(parent, x, ligne, valeur, taille, couleur, 500, largeur, align, true)

## Largeur (unités) d'un texte en DM Sans 500.
static func largeur(valeur: String, taille: int = 18) -> float:
	return Charte.texte_moyen().get_string_size(valeur, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(12, C.px(taille))).x / C.density

## Lien texte (« Proposition du staff → ») : bouton plat DM Sans, focus visible. Largeur 0 = celle du texte.
static func lien(parent: Control, zone: Rect2, valeur: String, action: Callable, id: String, taille: int = 18, droite: bool = false) -> Button:
	if zone.size.x <= 0:
		zone.size.x = largeur(valeur, taille) + 12
		if droite: zone.position.x -= zone.size.x
	var bouton := Link.styled_button(parent, zone, valeur, taille, Charte.IVOIRE, id)
	bouton.add_theme_font_override("font", Charte.texte_moyen())
	bouton.add_theme_color_override("font_disabled_color", Charte.IVOIRE_3)
	bouton.pressed.connect(action)
	bouton.tooltip_text = valeur
	return bouton

## Touche de clavier dessinée (« Ctrl Entrée ») ; renvoie sa largeur.
static func touche(parent: Control, x: float, ligne: float, valeur: String, droite: bool = false) -> float:
	var large := Charte.TEXTE.get_string_size(valeur, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(12, C.px(16))).x / C.density + 16
	var gauche := x - large if droite else x
	D.rect(parent, Rect2(gauche, ligne - 20, large, 27), Charte.PANNEAU_3, 2)
	D.text(parent, gauche + 8, ligne - 1, valeur, 16, Charte.IVOIRE_2, 600, large - 10, HORIZONTAL_ALIGNMENT_LEFT, true)
	return large

## Barre de condition (remplissage ivoire-2, repère à 80 %) et valeur ; « ! 78 % » en rouge sous 80 %.
static func condition(parent: Control, x: float, ligne: float, valeur: Variant, barre: float = 76) -> Label:
	if not (valeur is int or valeur is float):
		return texte(parent, x + barre + 64, ligne, "—", Charte.IVOIRE_3, 60, 18, HORIZONTAL_ALIGNMENT_RIGHT)
	var v := clampf(float(valeur), 0, 100)
	D.rect(parent, Rect2(x, ligne - 10, barre, 8), Charte.PANNEAU_3, 0)
	if v > 0: D.rect(parent, Rect2(x, ligne - 10, barre * v / 100.0, 8), Charte.IVOIRE_2, 0)
	D.rect(parent, Rect2(x + barre * .8, ligne - 14, 1.4, 16), Charte.IVOIRE_3, 0)
	var bas := v < 80
	var label := texte(parent, x + barre + 64, ligne, ("! " if bas else "") + "%d %%" % roundi(v), Charte.D if bas else Charte.IVOIRE, 74, 18, HORIZONTAL_ALIGNMENT_RIGHT)
	if bas: label.add_theme_font_override("font", texte_gras())
	return label

## Bouton ivoire plein (un seul par écran : l'action principale), bord droit incliné, libellé italique en capitales.
static func bouton_ivoire(parent: Control, zone: Rect2, valeur: String, action: Callable, id: String) -> Button:
	var bouton := Button.new()
	bouton.name = id
	bouton.text = valeur.to_upper()
	bouton.focus_mode = Control.FOCUS_ALL
	bouton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	bouton.alignment = HORIZONTAL_ALIGNMENT_LEFT
	bouton.add_theme_font_override("font", Charte.TITRE_GRAS_ITALIQUE)
	bouton.add_theme_font_size_override("font_size", maxi(12, C.px(22)))
	for etat in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		bouton.add_theme_color_override(etat, Charte.NUIT)
	bouton.add_theme_color_override("font_disabled_color", Charte.IVOIRE_2)
	var vide := StyleBoxEmpty.new()
	vide.content_margin_left = C.px(18)
	vide.content_margin_right = C.px(26)
	for etat in ["normal", "hover", "pressed", "disabled", "hover_pressed"]: bouton.add_theme_stylebox_override(etat, vide)
	var focus := C.box(Color.TRANSPARENT, Charte.IVOIRE, 0, 0)
	focus.set_border_width_all(2)
	focus.set_expand_margin_all(C.px(4))
	bouton.add_theme_stylebox_override("focus", focus)
	var fond := FondIncline.new()
	fond.name = "FondIvoire"
	fond.show_behind_parent = true
	fond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bouton.add_child(fond)
	fond.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var teinte := func():
		fond.couleur = Charte.PANNEAU_2 if bouton.disabled else (Charte.IVOIRE.lightened(.35) if bouton.is_hovered() else Charte.IVOIRE)
		fond.queue_redraw()
	bouton.mouse_entered.connect(teinte)
	bouton.mouse_exited.connect(func(): teinte.call_deferred())
	bouton.ready.connect(teinte)
	bouton.pressed.connect(action)
	parent.add_child(bouton)
	D.place(bouton, zone)
	return bouton

## Rangée cliquable d'un tableau ou carte de poste : fond plat (zébrure, survol, choisi), focus = contour ivoire 2 px
## distinct de la sélection (fond + marqueur).
static func styler_ligne(bouton: Button, fond: Color, choisi: bool = false) -> void:
	var normal := C.box(Charte.PANNEAU_3 if choisi else fond, Color.TRANSPARENT, 0, 0)
	var survol := C.box(Charte.PANNEAU_3, Color.TRANSPARENT, 0, 0)
	var focus := C.box(Color.TRANSPARENT, Charte.IVOIRE, 0, 0)
	focus.set_border_width_all(2)
	for etat in ["normal", "pressed", "disabled"]: bouton.add_theme_stylebox_override(etat, normal)
	bouton.add_theme_stylebox_override("hover", survol)
	bouton.add_theme_stylebox_override("hover_pressed", survol)
	bouton.add_theme_stylebox_override("focus", focus)
	bouton.focus_mode = Control.FOCUS_ALL
	bouton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

## Nom de joueur cliquable : clic = fiche complète, survol (ou focus + I) = mini-fiche. Laisse passer le glisser
## vers la carte ou la ligne qui le porte.
static func nom(app: Control, parent: Control, zone: Rect2, valeur: String, player_id: String, id: String, couleur: Color = Charte.IVOIRE, taille: int = 18) -> Button:
	var MiniFiche: Script = load("res://ui/immersive08/mini_fiche.gd")
	var bouton := Link.styled_button(parent, zone, valeur, taille, couleur, id)
	bouton.add_theme_font_override("font", Charte.texte_moyen())
	var plat := C.box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0)
	plat.content_margin_left = 0
	plat.content_margin_right = 0
	bouton.add_theme_stylebox_override("normal", plat)
	var souligne := plat.duplicate() as StyleBoxFlat
	souligne.border_color = Charte.IVOIRE_2
	souligne.border_width_bottom = 1
	bouton.add_theme_stylebox_override("hover", souligne)
	bouton.add_theme_stylebox_override("pressed", souligne)
	bouton.focus_mode = Control.FOCUS_NONE
	bouton.mouse_filter = Control.MOUSE_FILTER_PASS
	bouton.accessibility_name = valeur + " · fiche joueur"
	bouton.pressed.connect(func(): app.navigation_controller.open_entity({"kind":"player", "id":player_id}))
	MiniFiche.lier(app, bouton, player_id, "squad")
	return bouton

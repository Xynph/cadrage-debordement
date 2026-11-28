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

## DM Sans graisse 700 (chiffres des ovales).
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
	label.add_theme_font_override("font", Charte.TITRE_GRAS)
	label.name = "CardTitle"
	return label

## Grand titre de page : Anton droite (Charte.TITRE_FICHE), comme la fiche joueur, Carrière et Vestiaire.
static func titre_page(parent: Control, x: float, ligne: float, texte: String, taille: int = 38, largeur: float = 900) -> Label:
	var label := titre(parent, x, ligne, texte, taille, largeur)
	label.add_theme_font_override("font", Charte.TITRE_FICHE)
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
## Point unique de l'écran pour le style des liens : quand components.gd aura le style « lien » commun (branche
## Réception : souligné au survol, flèche, focus), seul `_bouton_lien` changera.
static func lien(parent: Control, zone: Rect2, valeur: String, action: Callable, id: String, taille: int = 18, droite: bool = false) -> Button:
	if zone.size.x <= 0:
		zone.size.x = largeur(valeur, taille) + 12
		if droite: zone.position.x -= zone.size.x
	var bouton := _bouton_lien(parent, zone, valeur, taille, id)
	bouton.pressed.connect(action)
	# Pas d'info-bulle qui répète le libellé (une info-bulle est une fenêtre système).
	bouton.tooltip_text = ""
	return bouton

static func _bouton_lien(parent: Control, zone: Rect2, valeur: String, taille: int, id: String) -> Button:
	var bouton := Link.styled_button(parent, zone, valeur, taille, Charte.IVOIRE, id)
	bouton.add_theme_font_override("font", Charte.texte_moyen())
	bouton.add_theme_color_override("font_disabled_color", Charte.IVOIRE_3)
	return bouton

## Nom en casse normale comme la maquette : « Angus FORBES » → « Angus Forbes » ; `court` : « A. Forbes ».
## Les mots écrits en capitales dans les données passent en minuscules, initiale (et lettre après - ou ') en capitale.
static func casse(nom_complet: String, court: bool = false) -> String:
	var mots: Array[String] = []
	for mot: String in nom_complet.strip_edges().split(" ", false):
		if mot.length() > 1 and mot == mot.to_upper() and mot != mot.to_lower():
			var bas := mot.to_lower()
			var sortie := ""
			var majuscule := true
			for i in bas.length():
				var lettre := bas[i]
				sortie += lettre.to_upper() if majuscule else lettre
				majuscule = lettre in ["-", "'", "’"]
			mot = sortie
		mots.append(mot)
	if mots.is_empty(): return ""
	if not court or mots.size() == 1: return " ".join(mots)
	return mots[0].left(1) + ". " + " ".join(mots.slice(1))

## Texte courant qui passe à la ligne, avec des morceaux cliquables : {texte} (texte simple), {texte, joueur} (nom :
## fiche + mini-fiche), {texte, action} (lien). Rend le nombre de lignes utilisées (au plus `max_lignes`) ; ce qui
## dépasse n'est jamais coupé en « … » : les morceaux restants sont simplement omis et comptés dans `reste`.
static func flux(app: Control, parent: Control, x: float, ligne: float, largeur_max: float, morceaux: Array, taille: int = 17, interligne: float = 24, max_lignes: int = 2, id: String = "") -> Dictionary:
	interligne = maxf(interligne, hauteur_ligne(taille) + 2)
	var curseur := 0.0
	var rang := 0
	var poses := 0
	var espace := largeur(" ", taille)
	var omis := 0
	for i in morceaux.size():
		var morceau: Dictionary = morceaux[i]
		var mots: Array = [str(morceau.texte)]
		if not (morceau.has("joueur") or morceau.has("action")): mots = Array(str(morceau.texte).split(" ", false))
		for mot: String in mots:
			var w := largeur(mot, taille)
			if curseur > 0 and curseur + espace + w > largeur_max:
				rang += 1
				curseur = 0.0
			if rang >= max_lignes:
				omis += 1
				continue
			var gauche := x + curseur + (espace if curseur > 0 else 0.0)
			var y := ligne + rang * interligne
			if morceau.has("joueur"):
				nom(app, parent, Rect2(gauche, y - taille - 1, w + 2, taille + 7), mot, str(morceau.joueur), "%sNom%d" % [id, i], Charte.IVOIRE, taille)
			elif morceau.has("action"):
				lien(parent, Rect2(gauche - 4, y - taille - 1, w + 10, taille + 7), mot, morceau.action, "%sLien%d" % [id, i], taille)
			else:
				texte(parent, gauche, y, mot, morceau.get("couleur", Charte.IVOIRE), w + 4, taille)
			curseur = gauche - x + w
			# Le bouton (i) de la carte joueur se pose à droite du nom : on lui laisse sa place pour qu'il ne couvre pas le mot suivant.
			if morceau.has("joueur"): curseur += 22.0
			poses += 1
	return {"lignes": mini(rang + 1, max_lignes) if poses > 0 else 0, "omis": omis}

## Hauteur d'une ligne de texte DM Sans (unités), plancher de 12 px compris (petites fenêtres).
static func hauteur_ligne(taille: int) -> float:
	return Charte.TEXTE.get_height(maxi(12, C.px(taille))) / C.density

## Puce pleine (charte §3 : rayon 6, aucun cadre) : « ! » de l'avis du staff, « 33 » des Bleus, « DERBY ».
static func puce(parent: Control, zone: Rect2, valeur: String, fond: Color, encre: Color, id: String = "") -> Panel:
	var cadre := D.rect(parent, zone, fond, Charte.RAYON_PETIT)
	if not id.is_empty(): cadre.name = id
	D.text(cadre, zone.size.x / 2.0, zone.size.y / 2.0 + 6, valeur, 16, encre, 700, zone.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	return cadre

## Case à cocher ou bouton radio de la charte : carré, trait ivoire, plein si
## coché ; libellé DM Sans ivoire-2 ; focus = contour ivoire 2 px.
static func styler_case(case_: CheckBox) -> void:
	var cote := maxi(12, C.px(20))
	case_.add_theme_icon_override("unchecked", _case(cote, false))
	case_.add_theme_icon_override("checked", _case(cote, true))
	case_.add_theme_icon_override("radio_unchecked", _case(cote, false))
	case_.add_theme_icon_override("radio_checked", _case(cote, true))
	case_.add_theme_icon_override("unchecked_disabled", _case(cote, false))
	case_.add_theme_icon_override("checked_disabled", _case(cote, true))
	case_.add_theme_font_override("font", Charte.TEXTE)
	case_.add_theme_font_size_override("font_size", maxi(12, C.px(18)))
	for couleur in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]: case_.add_theme_color_override(couleur, Charte.IVOIRE_2)
	var vide := StyleBoxEmpty.new()
	for etat in ["normal", "hover", "pressed", "hover_pressed", "disabled"]: case_.add_theme_stylebox_override(etat, vide)
	var focus := C.box(Color.TRANSPARENT, Charte.IVOIRE, Charte.RAYON_PETIT, 2)
	focus.set_border_width_all(2)
	case_.add_theme_stylebox_override("focus", focus)
	case_.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

static func _case(cote: int, coche: bool) -> ImageTexture:
	var image := Image.create(cote, cote, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var epaisseur := maxi(1, roundi(cote / 10.0))
	for x in cote:
		for y in cote:
			var bord := x < epaisseur or y < epaisseur or x >= cote - epaisseur or y >= cote - epaisseur
			var interieur := x >= epaisseur * 3 and y >= epaisseur * 3 and x < cote - epaisseur * 3 and y < cote - epaisseur * 3
			if bord or (coche and interieur): image.set_pixel(x, y, Charte.IVOIRE)
	return ImageTexture.create_from_image(image)

## Liste déroulante de la charte (menu déroulant autorisé) : fond panneau-3, pilule, filet ivoire-3, focus ivoire.
static func styler_liste(liste: OptionButton) -> void:
	liste.add_theme_font_override("font", Charte.TEXTE)
	liste.add_theme_font_size_override("font_size", maxi(12, C.px(18)))
	for couleur in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]: liste.add_theme_color_override(couleur, Charte.IVOIRE)
	liste.add_theme_color_override("font_disabled_color", Charte.IVOIRE_3)
	var fond := C.box(Charte.PANNEAU_3, Charte.IVOIRE_3, Charte.RAYON_PILULE, 10)
	var survol := C.box(Charte.PANNEAU_2, Charte.IVOIRE_2, Charte.RAYON_PILULE, 10)
	var focus := C.box(Color.TRANSPARENT, Charte.IVOIRE, Charte.RAYON_PILULE, 10)
	focus.set_border_width_all(2)
	for etat in ["normal", "pressed", "disabled"]: liste.add_theme_stylebox_override(etat, fond)
	liste.add_theme_stylebox_override("hover", survol)
	liste.add_theme_stylebox_override("focus", focus)
	var menu := liste.get_popup()
	menu.add_theme_stylebox_override("panel", Charte.sans_ombre(C.box(Charte.PANNEAU_3, Charte.FILET, Charte.RAYON_CARTE, 6)))
	menu.add_theme_stylebox_override("hover", C.box(Charte.PANNEAU_2, Color.TRANSPARENT, Charte.RAYON_PETIT, 4))
	menu.add_theme_font_override("font", Charte.TEXTE)
	menu.add_theme_font_size_override("font_size", maxi(12, C.px(18)))
	menu.add_theme_color_override("font_color", Charte.IVOIRE)
	menu.add_theme_color_override("font_hover_color", Charte.IVOIRE)

## Touche de clavier dessinée (« Ctrl Entrée ») ; renvoie sa largeur.
static func touche(parent: Control, x: float, ligne: float, valeur: String, droite: bool = false) -> float:
	var large := Charte.TEXTE.get_string_size(valeur, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(12, C.px(16))).x / C.density + 16
	var gauche := x - large if droite else x
	D.rect(parent, Rect2(gauche, ligne - 20, large, 27), Charte.PANNEAU_3, Charte.RAYON_PETIT)
	D.text(parent, gauche + 8, ligne - 1, valeur, 16, Charte.IVOIRE_2, 600, large - 10, HORIZONTAL_ALIGNMENT_LEFT, true)
	return large

## Barre de condition (remplissage ivoire-2, repère à 80 %) et valeur ; « ! 78 % » en rouge sous 80 %.
static func condition(parent: Control, x: float, ligne: float, valeur: Variant, barre: float = 76) -> Label:
	if not (valeur is int or valeur is float):
		return texte(parent, x + barre + 64, ligne, "—", Charte.IVOIRE_3, 60, 18, HORIZONTAL_ALIGNMENT_RIGHT)
	var v := clampf(float(valeur), 0, 100)
	D.rect(parent, Rect2(x, ligne - 10, barre, 8), Charte.PANNEAU_3, Charte.RAYON_PILULE)
	if v > 0: D.rect(parent, Rect2(x, ligne - 10, barre * v / 100.0, 8), Charte.IVOIRE_2, Charte.RAYON_PILULE)
	D.rect(parent, Rect2(x + barre * .8, ligne - 14, 1.4, 16), Charte.IVOIRE_3, 0)
	var bas := v < 80
	var label := texte(parent, x + barre + 64, ligne, ("! " if bas else "") + "%d %%" % roundi(v), Charte.D if bas else Charte.IVOIRE, 74, 18, HORIZONTAL_ALIGNMENT_RIGHT)
	if bas: label.add_theme_font_override("font", texte_gras())
	return label

## Action d'un écran de la coque (charte finale §7.1) : pilule à contour FILET, texte crème (`C.style_bouton_contour`).
## Plus d'aplat clair : Continuer porte déjà l'unique aplat doré, et un aplat crème hors onglet/menu volerait la vedette.
## Le nom est gardé pour les appelants ; focus = contour ivoire 2 px, comme le reste du kit.
static func bouton_ivoire(parent: Control, zone: Rect2, valeur: String, action: Callable, id: String) -> Button:
	var bouton := Button.new()
	bouton.name = id
	bouton.text = valeur.to_upper()
	bouton.focus_mode = Control.FOCUS_ALL
	bouton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	C.style_bouton_contour(bouton, 21)
	bouton.alignment = HORIZONTAL_ALIGNMENT_CENTER
	bouton.clip_text = true
	var focus := C.box(Color.TRANSPARENT, Charte.IVOIRE, Charte.RAYON_PILULE, 18)
	focus.set_border_width_all(2)
	focus.set_expand_margin_all(2)
	bouton.add_theme_stylebox_override("focus", focus)
	bouton.add_theme_stylebox_override("hover_pressed", bouton.get_theme_stylebox("pressed"))
	bouton.pressed.connect(action)
	parent.add_child(bouton)
	D.place(bouton, zone)
	return bouton

## Rangée cliquable d'un tableau ou carte de poste : fond plat (zébrure, survol, choisi), focus = contour ivoire 2 px
## distinct de la sélection (fond + marqueur).
static func styler_ligne(bouton: Button, fond: Color, choisi: bool = false, couleur_choisie: Color = Charte.PANNEAU_3) -> void:
	var normal := C.box(couleur_choisie if choisi else fond, Color.TRANSPARENT, Charte.RAYON_PETIT, 0)
	var survol := C.box(Charte.PANNEAU_3, Color.TRANSPARENT, Charte.RAYON_PETIT, 0)
	var focus := C.box(Color.TRANSPARENT, Charte.IVOIRE, Charte.RAYON_PETIT, 0)
	focus.set_border_width_all(2)
	for etat in ["normal", "pressed", "disabled"]: bouton.add_theme_stylebox_override(etat, normal)
	bouton.add_theme_stylebox_override("hover", survol)
	bouton.add_theme_stylebox_override("hover_pressed", survol)
	bouton.add_theme_stylebox_override("focus", focus)
	bouton.focus_mode = Control.FOCUS_ALL
	bouton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

## Nom de joueur cliquable : clic = fiche complète, survol (ou focus + I) = carte joueur. Laisse passer le glisser
## vers la carte ou la ligne qui le porte.
static func nom(app: Control, parent: Control, zone: Rect2, valeur: String, player_id: String, id: String, couleur: Color = Charte.IVOIRE, taille: int = 18) -> Button:
	var Carte: Script = load("res://ui/carte_joueur_survol.gd")
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
	Carte.lier_info(app, bouton, player_id, "squad")
	return bouton

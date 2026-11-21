extends RefCounted
## Petites pièces des écrans sans phrase d'aide (règle du 21/11/2026) : tuile (gros chiffre + légende courte), pastille
## (icône + un mot) et petit « i » / « ? » qui porte l'explication en infobulle. Coordonnées en unités du gabarit (2248).
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const Charte = preload("res://ui/charte.gd")
## Couleurs de sens (retour de Léo du 21/11/2026) : jamais seules, toujours avec un mot, un chiffre ou une forme.
const VERT := Color("7fbf7a")      ## bon, recettes, gain
const ORANGE := Color("e0a04a")    ## vigilance
const ROUGE := Color("d9634f")     ## danger, charges, perte
const BLEU := Color("5b9bd5")      ## information
const VIOLET := Color("a88bd6")
const TURQUOISE := Color("4fb3a9")

## Tuile de chiffre : carte rayon 12 à ombre de la charte, valeur en grand, légende en capitales dessous.
## `bulle` : explication au survol (la tuile ne reçoit alors plus le clic de ce qu'elle recouvre).
static func tuile(parent: Node, zone: Rect2, valeur: String, legende: String, couleur: Color = Charte.IVOIRE, id: String = "", taille: int = 30, bulle: String = "", icone: String = "", teinte: bool = false, action: Callable = Callable()) -> Panel:
	# Tuile d alerte : léger fond teinté de la couleur du chiffre.
	var carte := D.rect(parent, zone, Charte.PANNEAU_2.lerp(couleur, .16) if teinte and couleur != Charte.IVOIRE else Charte.PANNEAU_2, Charte.RAYON_CARTE)
	carte.name = id if not id.is_empty() else "Tuile_" + legende.validate_node_name()
	carte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var chiffre := D.text(carte, 12, zone.size.y - 28, valeur, taille, couleur, 800, zone.size.x - 20)
	chiffre.add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
	chiffre.name = carte.name + "Valeur"
	chiffre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var texte := D.text(carte, 12, zone.size.y - 9, legende.to_upper(), 14, Charte.IVOIRE_2, 600, zone.size.x - 20)
	texte.name = carte.name + "Legende"
	texte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not icone.is_empty():
		var image := TextureRect.new()
		image.texture = C.icon_texture(icone, couleur if couleur != Charte.IVOIRE else Charte.IVOIRE_2)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		carte.add_child(image)
		D.place(image, Rect2(zone.size.x - 28, 8, 18, 18))
	if not bulle.is_empty():
		carte.mouse_filter = Control.MOUSE_FILTER_STOP
		carte.tooltip_text = bulle
		carte.accessibility_name = "%s %s. %s" % [valeur, legende, bulle]
	if action.is_valid(): rendre_cliquable(carte, zone.size, action, carte.name + "Lien", "%s %s" % [valeur, legende], bulle, Charte.RAYON_CARTE)
	return carte

## Pose sur une tuile ou une pastille un bouton plat qui mène à l'écran pertinent (jamais de fenêtre).
static func rendre_cliquable(cadre: Control, taille: Vector2, action: Callable, id: String, libelle: String, bulle: String, rayon: int) -> Button:
	var bouton := Button.new()
	bouton.name = id
	bouton.flat = true
	bouton.focus_mode = Control.FOCUS_ALL
	bouton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var survol := StyleBoxFlat.new()
	survol.bg_color = Color(Charte.IVOIRE, .10)
	survol.set_corner_radius_all(maxi(3, C.px(rayon)) if rayon < Charte.RAYON_PILULE else 999)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = Charte.IVOIRE
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(survol.corner_radius_top_left)
	bouton.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	bouton.add_theme_stylebox_override("hover", survol)
	bouton.add_theme_stylebox_override("pressed", survol)
	bouton.add_theme_stylebox_override("focus", focus)
	bouton.accessibility_name = libelle
	bouton.tooltip_text = bulle
	bouton.pressed.connect(action)
	cadre.add_child(bouton)
	D.place(bouton, Rect2(Vector2.ZERO, taille))
	return bouton

## Largeur (unités) d'une pastille portant ce mot.
static func largeur_pastille(texte: String, icone: String = "") -> float:
	return C.BODY.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(12, C.px(18))).x / C.density + 32.0 + (26.0 if not icone.is_empty() else 0.0)

## Pastille d'état : pilule, icône (forme) puis un mot. Renvoie sa largeur.
static func pastille(parent: Node, x: float, y: float, texte: String, icone: String = "", id: String = "", bulle: String = "", couleur: Color = Charte.IVOIRE, fond: Color = Charte.PANNEAU_3, action: Callable = Callable()) -> float:
	var largeur := largeur_pastille(texte, icone)
	var pilule := D.rect(parent, Rect2(x, y, largeur, 34), fond.lerp(couleur, .16) if couleur != Charte.IVOIRE and fond == Charte.PANNEAU_3 else fond, Charte.RAYON_PILULE)
	pilule.name = id if not id.is_empty() else "Pastille_" + texte.validate_node_name()
	pilule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gauche := 13.0
	if not icone.is_empty():
		var image := TextureRect.new()
		image.texture = C.icon_texture(icone, couleur)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pilule.add_child(image)
		D.place(image, Rect2(11, 8, 18, 18))
		gauche = 37.0
	var mot := D.text(pilule, gauche, 24, texte, 18, couleur, 600, largeur - gauche - 6, HORIZONTAL_ALIGNMENT_LEFT, true)
	mot.name = pilule.name + "Texte"
	mot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not bulle.is_empty():
		pilule.mouse_filter = Control.MOUSE_FILTER_STOP
		pilule.tooltip_text = bulle
	if action.is_valid(): rendre_cliquable(pilule, Vector2(largeur, 34), action, pilule.name + "Lien", texte, bulle, Charte.RAYON_PILULE)
	return largeur

## Petit « i » rond : explication en infobulle (jamais de fenêtre). `glyphe` « ? » pour les raccourcis clavier.
static func info(parent: Node, x: float, y: float, bulle: String, id: String = "", glyphe: String = "i") -> Panel:
	var rond := D.rect(parent, Rect2(x, y, 26, 26), Color.TRANSPARENT, Charte.RAYON_PILULE, Charte.IVOIRE_3)
	rond.name = ("Info_" + id) if not id.is_empty() else "Info_" + glyphe
	rond.mouse_filter = Control.MOUSE_FILTER_STOP
	rond.mouse_default_cursor_shape = Control.CURSOR_HELP
	rond.tooltip_text = bulle
	rond.accessibility_name = bulle
	var lettre := D.text(rond, 13, 20, glyphe, 17, Charte.IVOIRE_2, 700, 0, HORIZONTAL_ALIGNMENT_CENTER)
	lettre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lettre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lettre.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lettre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rond

## Largeur (unités) d'un texte en police titre (pour poser un « i » juste après un titre de panneau).
static func largeur_titre(texte: String, taille: int) -> float:
	return Charte.TITRE_GRAS_ITALIQUE.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(12, C.px(taille))).x / C.density

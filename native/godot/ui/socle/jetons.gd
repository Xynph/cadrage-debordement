extends RefCounted
## Jetons de design du socle des menus : la seule source des couleurs, des
## tailles et des espacements des écrans construits sur le socle.
## Toutes les mesures sont données pour une fenêtre de 1920×1080 puis mises à
## l'échelle par `px()`. L'échelle ne descend pas sous 0,8 : en 1280×720 on
## retire des colonnes plutôt que de rendre le texte illisible.

## Couleurs : alias des jetons de la charte (ui/charte.gd), une seule direction artistique.
## OR reste le nom de l'accent historique du socle ; il vaut la crème (le doré marque l'action et l'attention).
const Charte = preload("res://ui/charte.gd")
const FOND := Charte.FOND
const PANNEAU := Charte.PANNEAU
const PANNEAU_HAUT := Charte.PANNEAU_2
const TRAIT := Charte.FILET
const TEXTE := Charte.IVOIRE
const TEXTE_DOUX := Charte.IVOIRE_2
const TEXTE_FAIBLE := Charte.IVOIRE_3
const OR := Charte.IVOIRE
const VERT := Charte.V
const JAUNE := Charte.N
const ALERTE := Charte.D
const SURVOL := Charte.PANNEAU_2
const CHOIX := Charte.PANNEAU_3
## Ligne de tableau choisie (charte §7.1 : SELECTION sur toute la ligne, rayon 6).
const SELECTION := Charte.SELECTION
## Focus clavier : anneau ou trait doré (charte §7.1, États).
const FOCUS := Charte.OR
const RAIL := Charte.PANNEAU_3
const RESERVE := Charte.IVOIRE_3

const TITRE = preload("res://fonts/BarlowCondensed-SemiBold.ttf")
const TITRE_GRAS = preload("res://ui/immersive08/fonts/BarlowCondensed-Bold.ttf")
const CORPS = preload("res://fonts/DMSans.ttf")

## Tailles de texte, en pixels de maquette.
const T_PETIT := 13.0
const T_CELLULE := 13.0  ## cellule de tableau (charte §7.1 : DM Sans 13, ligne 26)
const T_CORPS := 15.0
const T_FORT := 16.0
const T_CHIFFRE := 22.0
const T_TITRE := 24.0
const T_GEANT := 46.0

## Espacements et rayons.
const E1 := 4.0
const E2 := 8.0
const E3 := 12.0
const E4 := 16.0
const E5 := 24.0
const RAYON := 18.0  ## panneaux arrondis de la charte (Charte.RAYON_PANNEAU)
const RAYON_PETIT := 6.0  ## ligne choisie, pastilles, cases (Charte.RAYON_PETIT)
const LIGNE_H := 26.0  ## densité FM de la charte : lignes de 26 px
const ENTETE_H := 32.0
const GROUPE_H := 46.0

static var echelle := 1.0
static var _corps_gras: FontVariation

static func regler(fenetre: Vector2) -> void:
	echelle = clampf(minf(fenetre.y / 1080.0, fenetre.x / 1920.0), 0.8, 1.6)

static func px(valeur: float) -> int:
	return roundi(valeur * echelle)

static func corps_gras() -> Font:
	if _corps_gras == null:
		_corps_gras = FontVariation.new()
		_corps_gras.base_font = CORPS
		_corps_gras.variation_opentype = {"wght": 650}
	return _corps_gras

static func boite(fond: Color, rayon := RAYON, marge := 0.0, bord := Color.TRANSPARENT) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fond
	style.set_corner_radius_all(px(rayon))
	style.set_content_margin_all(px(marge))
	style.anti_aliasing = true
	if bord.a > 0.0:
		style.border_color = bord
		style.set_border_width_all(maxi(1, px(1)))
	return Charte.ombrer(style, rayon)

static func texte(contenu: String, taille := T_CORPS, couleur := TEXTE, police: Font = null) -> Label:
	var label := Label.new()
	label.text = contenu
	label.add_theme_font_override("font", police if police != null else CORPS)
	label.add_theme_font_size_override("font_size", px(taille))
	label.add_theme_color_override("font_color", couleur)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

static func plier(valeur: Variant) -> String:
	## Texte comparable : minuscules, sans accents ni ligatures.
	var source := str(valeur).to_lower()
	if source.to_utf8_buffer().size() == source.length(): return source
	var remplacements := {"à":"a","â":"a","ä":"a","á":"a","ã":"a","ç":"c","é":"e","è":"e","ê":"e","ë":"e","í":"i","î":"i","ï":"i","ñ":"n","ó":"o","ô":"o","ö":"o","ú":"u","ù":"u","û":"u","ü":"u","ÿ":"y","œ":"oe","æ":"ae","’":"'"}
	for lettre: String in remplacements:
		source = source.replace(lettre, remplacements[lettre])
	return source

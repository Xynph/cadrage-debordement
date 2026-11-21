extends RefCounted
## Jetons de la charte (design/art/art-bible.md) : la seule source des couleurs, polices et formes de l'interface.
## Charte finale de la graphiste (20/11/2026), validée par Léo avec deux exceptions : pas de fiche à droite, pas de
## fenêtre qui s'ouvre. Nuancier de sept teintes ; les nuances de service sont ces teintes posées en transparence
## sur PANNEAU, figées ici en couleurs opaques. Les palettes plus anciennes (ui/immersive08/components.gd,
## ui/socle/jetons.gd, ui/game_skin.gd) pointent sur ces jetons.
## Exemple : `var trait := Charte.club_trait(app.accent)` donne le liseré du club lisible sur `PANNEAU`.

## Nuancier (7 teintes).
const ARDOISE := Color("202d2d")      ## 1/7 fond de l'écran, derrière tout
const NOIR_PANNEAU := Color("0b1517") ## 2/7 panneaux, tableaux, barre latérale
const CREME := Color("f2ecdc")        ## 3/7 texte principal, titres, chiffres ; onglet et menu actifs (aplat)
const GRIS_VERT := Color("abb7b1")    ## 4/7 texte secondaire, valeurs, icônes au repos
const VERT_FRANC := Color("32644b")   ## 5/7 surface (jauges, écusson « nous », terrain) ; jamais en texte ni trait fin
const DORE := Color("d7aa5a")         ## 6/7 action principale, attention, surtitres, focus, l'adversaire
const VERT_CLAIR := Color("b6d6b6")   ## 7/7 bon état, chiffres favorables, notre équipe ; jamais en paragraphe

## Fonds, du plus profond au plus haut (noms historiques conservés).
const NUIT := Color("000000")       ## écran titre plein cadre seulement ; jamais un panneau
const FOND := ARDOISE               ## fond de la coque : aplat ardoise, sans photo
const PANNEAU := NOIR_PANNEAU       ## panneaux : se détachent du fond par la clarté et l'ombre portée, sans bordure
const PANNEAU_2 := Color("192223")  ## survol (crème 6 %)
const PANNEAU_3 := Color("222a2b")  ## choisi, champ de saisie, rail de jauge (crème 10 %)
const FILET := Color("272f2f")      ## trait : séparations, contour des boutons secondaires et des champs (crème 12 %)
const SELECTION := Color("1d392e")  ## ligne de tableau sélectionnée (vert franc 45 %)
const VOILE_DORE := Color("2c2d22") ## fond d'une pastille « à traiter » (doré 16 %), toujours avec texte doré
const VOILE_VERT := Color("252f2c") ## fond d'une pastille de bon état (vert clair 14 %), avec texte vert clair
## Textes.
const IVOIRE := CREME               ## texte principal
const IVOIRE_2 := GRIS_VERT         ## texte secondaire, étiquettes
const IVOIRE_3 := Color("96968d")   ## texte faible (crème 60 %) : en-têtes de colonnes, légendes ; jamais sous 12 px
## Doré : action principale (un seul aplat doré par écran : Continuer, ou le bouton principal d'une page sans
## Continuer), attention (avec un mot ou un pictogramme), surtitres, focus clavier, l'adversaire dans une comparaison.
const OR := DORE
const OR_VIF := Color("e2bc77")     ## survol / pression du bouton doré
## Papier : le seul document ouvert d'un écran (lettre, contrat, carnet, une de journal) ; jamais un tableau.
const PAPIER := CREME
const ENCRE := Color("0b1517")
const ENCRE_2 := Color("4d5853")
const OR_ENCRE := Color("7d5b10")
const V_PAPIER := VERT_FRANC
const D_PAPIER := Color("8a5a12")
## Nuances de service du papier : encre posée en transparence sur PAPIER, figées en opaque (feuilles du carnet).
const PAPIER_CLAIR := Color("faf6ec")   ## commande ou carte sur la feuille (blanc 45 %)
const PAPIER_SURVOL := Color("e0dbcc")  ## survol d'une commande (encre 8 %)
const PAPIER_PRESSE := Color("d2cec0")  ## commande pressée, choix courant (encre 14 %)
const FILET_PAPIER := Color("c4c1b5")   ## trait sur papier : contour des commandes et des champs (encre 20 %)
## Club : couleur réelle du club, seulement sur écusson, maillot et liseré ; les dérivés se calculent.
const CLUB := Color("71322f")
const CLUB_TRAIT := Color("b5524a")
const CLUB_TEXTE := Color("d0756c")
## Sens : favorable (vert clair), neutre, à surveiller (doré). Une couleur n'est jamais seule : mot ou pictogramme.
const V := VERT_CLAIR
const N := GRIS_VERT
const D := DORE
const V_DALTONIEN := Color("5aa9e6")
## Rouge : hors nuancier, réservé aux cartons rouges et aux vraies erreurs (échec de sauvegarde, connexion).
const ROUGE := Color("d9534a")

## Palette des données du groupe (décision de Léo du 21/11/2026, écrans Staff et Entraînement : « plus en couleurs ») :
## une couleur par donnée, toujours doublée d'un chiffre, d'un mot ou d'un motif (jamais la couleur seule). Jamais de doré.
const CONDITION := Color("7fbf7a")    ## condition physique
const MORAL := Color("5b9bd5")        ## moral du groupe
const CONFIANCE := Color("a88bd6")    ## confiance du conseil
const REPOS := Color("4fb3a9")        ## repos / récupération
const RECUPERATION := REPOS
const NORMAL := Color("7fbf7a")       ## séance normale
const INTENSIF := Color("e0a04a")     ## séance intensive
const GAIN := Color("7fbf7a")         ## écart favorable ▲
const PERTE := Color("d9634f")        ## écart défavorable ▼
## Terrain (page Équipe du match) : pelouse en bandes à plat, deux verts sourds alternés, et son liseré.
const PELOUSE := Color("1d4631")
const PELOUSE_2 := Color("214e37")
const PELOUSE_BORD := Color("53625e")

## Formes : panneaux arrondis sans bordure, avec ombre portée ; boutons, onglets, champs et jauges en pilule ; pastilles à 6 px.
const RAYON_PANNEAU := 18
const RAYON_CARTE := 12     ## carte dans un panneau (tuile de chiffre, carte « à décider »)
const RAYON_PETIT := 6      ## pastilles d'état, cases, vignettes, ligne sélectionnée (choix de Léo du 20/11/2026)
const RAYON_PILULE := 999   ## Godot ramène le rayon à la demi-hauteur : pilule à toute taille

## Ombre portée des panneaux, cartes et tuiles (choix de Léo du 20/11/2026, d'après la graphiste qui proposait 10 px) :
## noir 50 %, sans décalage, étendue 4 px. Jamais sur pilules, boutons, champs, pastilles, cases, lignes ni menus.
const OMBRE_COULEUR := Color(0, 0, 0, 0.5)
const OMBRE_TAILLE := 4
const OMBRE_DECALAGE := Vector2.ZERO

## Une forme de ce rayon (rayon de la charte, avant mise à l'échelle) porte-t-elle l'ombre ? Panneau (18) et carte (12) :
## oui ; case, pastille (6) et pilule : non.
static func rayon_ombre(rayon: float) -> bool:
	return rayon >= RAYON_CARTE and rayon < RAYON_PILULE

## Pose l'ombre de la charte sur un fond plein de panneau, carte ou tuile. `rayon` : rayon de la charte quand le style
## a été mis à l'échelle (sinon le plus grand rayon du style). Sans effet sur une pilule, une case, un contour seul.
## Exemple : `cadre.add_theme_stylebox_override("panel", Charte.ombrer(style, Charte.RAYON_CARTE))`.
static func ombrer(style: StyleBoxFlat, rayon: float = -1.0) -> StyleBoxFlat:
	if style == null: return style
	var r := rayon if rayon >= 0.0 else float(maxi(maxi(style.corner_radius_top_left, style.corner_radius_top_right),
		maxi(style.corner_radius_bottom_left, style.corner_radius_bottom_right)))
	if not rayon_ombre(r) or not style.draw_center or style.bg_color.a <= 0.0: return style
	style.shadow_color = OMBRE_COULEUR
	style.shadow_size = OMBRE_TAILLE
	style.shadow_offset = OMBRE_DECALAGE
	return style

## Même ombre sur une colonne ou un bandeau à angles droits posé sur le fond (Réception, Presse : Léo veut l'ombre sur
## tous les panneaux, arrondis ou non). Mêmes jetons, quel que soit le rayon ; sans effet sur un fond transparent.
static func ombrer_droit(style: StyleBoxFlat) -> StyleBoxFlat:
	if style == null or not style.draw_center or style.bg_color.a <= 0.0: return style
	style.shadow_color = OMBRE_COULEUR
	style.shadow_size = OMBRE_TAILLE
	style.shadow_offset = OMBRE_DECALAGE
	return style

## Retire l'ombre (menu déroulant ou bouton construit avec un style de panneau).
static func sans_ombre(style: StyleBoxFlat) -> StyleBoxFlat:
	if style != null: style.shadow_size = 0
	return style

## Le style porte-t-il exactement l'ombre de la charte ?
static func porte_ombre(style: StyleBox) -> bool:
	var plat := style as StyleBoxFlat
	return plat != null and plat.shadow_size == OMBRE_TAILLE and plat.shadow_color == OMBRE_COULEUR and plat.shadow_offset == OMBRE_DECALAGE

## Panneau qui rogne son contenu (clip_contents) : Godot rogne aussi l'ombre qu'il dessine. L'ombre passe à un calque
## frère posé juste derrière lui, qui suit sa place, sa taille et sa visibilité ; le panneau garde son fond, sans ombre.
## Parent à placement libre seulement (un conteneur rangerait le calque) ; renvoie le calque, ou null.
## Exemple : `panneau.clip_contents = true; Charte.ombre_derriere(panneau)` une fois le panneau posé dans sa page.
static func ombre_derriere(panneau: Control) -> Control:
	var style := panneau.get_theme_stylebox("panel") as StyleBoxFlat if panneau != null else null
	var parent := panneau.get_parent() as Control if panneau != null else null
	if style == null or parent == null or parent is Container or not porte_ombre(style): return null
	var ombre := Panel.new()
	ombre.name = str(panneau.name) + "Ombre"
	ombre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ombre.add_theme_stylebox_override("panel", style.duplicate())
	panneau.add_theme_stylebox_override("panel", sans_ombre(style.duplicate()))
	parent.add_child(ombre)
	parent.move_child(ombre, panneau.get_index())
	var suivre := func() -> void:
		if not is_instance_valid(ombre) or not is_instance_valid(panneau): return
		ombre.position = panneau.position
		ombre.size = panneau.size
		ombre.scale = panneau.scale
		ombre.visible = panneau.visible
	panneau.item_rect_changed.connect(suivre)
	panneau.visibility_changed.connect(suivre)
	panneau.tree_exiting.connect(func() -> void: if is_instance_valid(ombre): ombre.queue_free())
	suivre.call()
	return ombre

## Fond de panneau : PANNEAU arrondi, sans bordure, avec l'ombre portée de la charte.
static func style_panneau(couleur: Color = PANNEAU, rayon: int = RAYON_PANNEAU, marge: int = 18) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = couleur
	style.set_corner_radius_all(rayon)
	style.set_content_margin_all(marge)
	style.anti_aliasing = true
	return ombrer(style, rayon)

## Pilule (bouton, onglet, pastille) : aplat `fond`, contour facultatif.
static func style_pilule(fond: Color, contour: Color = Color.TRANSPARENT, marge_x: int = 14, marge_y: int = 5) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fond
	style.set_corner_radius_all(RAYON_PILULE)
	style.border_color = contour
	style.set_border_width_all(1 if contour.a > 0 else 0)
	style.content_margin_left = marge_x
	style.content_margin_right = marge_x
	style.content_margin_top = marge_y
	style.content_margin_bottom = marge_y
	style.anti_aliasing = true
	return style

## Barème des attributs (fiche joueur, mini-fiche ; décision de Léo du 19/11/2026) : le chiffre est toujours
## écrit, la couleur dit le palier. Une légende accompagne chaque grille (BAREME_ATTRIBUTS).
const ATTRIBUT_0 := Color("ee6f5f")   ## 0-39
const ATTRIBUT_40 := Color("f2a04a")  ## 40-54
const ATTRIBUT_55 := Color("d4e35c")  ## 55-64, citron (décision de Léo 20/11/2026) : jamais confondu avec le doré
const ATTRIBUT_65 := Color("a8d878")  ## 65-74
const ATTRIBUT_75 := Color("4fcb78")  ## 75-84
const ATTRIBUT_85 := Color("3debb4")  ## 85 et plus
## [seuil bas, couleur, libellé de légende], du plus faible au plus fort.
const BAREME_ATTRIBUTS := [
	[0, ATTRIBUT_0, "0-39"], [40, ATTRIBUT_40, "40-54"], [55, ATTRIBUT_55, "55-64"],
	[65, ATTRIBUT_65, "65-74"], [75, ATTRIBUT_75, "75-84"], [85, ATTRIBUT_85, "85+"],
]

## Couleur d'un attribut (ou d'une moyenne de famille) ; valeur inconnue : IVOIRE_3.
static func couleur_attribut(valeur: Variant) -> Color:
	if not (valeur is int or valeur is float) or not is_finite(float(valeur)): return IVOIRE_3
	var couleur: Color = ATTRIBUT_0
	for palier: Array in BAREME_ATTRIBUTS:
		if float(valeur) >= float(palier[0]): couleur = palier[1]
	return couleur

## Inclinaison des titres et marqueurs : 0° depuis la charte finale (titres droits, décision de Léo du 20/11/2026).
## Les dessins qui passent par `decalage` se redressent tous seuls.
const INCLINAISON_DEGRES := 0.0
## Décalage horizontal d'un bord incliné pour une hauteur donnée (0 avec la charte actuelle).
static func decalage(hauteur: float) -> float:
	return hauteur * tan(deg_to_rad(INCLINAISON_DEGRES))

## Polices : Barlow Condensed (sous-titres, cartes, chiffres, droits) et DM Sans (texte). Pas de troisième famille, sauf Anton (TITRE_FICHE) : fiche joueur et grands titres de tous les écrans (titre de page en haut, bandeau de héros).
## Les anciens noms *_ITALIQUE pointent sur les coupes droites : titres droits partout sans toucher aux écrans.
const TITRE = preload("res://fonts/BarlowCondensed-SemiBold.ttf")
const TITRE_GRAS = preload("res://ui/immersive08/fonts/BarlowCondensed-Bold.ttf")
const TITRE_EXTRA = preload("res://ui/immersive08/fonts/BarlowCondensed-ExtraBold.ttf")
const TITRE_ITALIQUE = TITRE
const TITRE_GRAS_ITALIQUE = TITRE_GRAS
const TITRE_EXTRA_ITALIQUE = TITRE_EXTRA
## Anton, choix de Léo du 20/11/2026 (fiche joueur : nom, numéro, niveau, potentiel, titres de blocs), élargi le 21/11/2026 aux grands titres de tous les écrans (« LE BUREAU », « RÉGLAGES », « SÉLECTIONS »…) ; droite, jamais inclinée. Titres de cartes, noms de club et chiffres restent en Barlow Condensed.
const TITRE_FICHE = preload("res://ui/immersive08/fonts/Anton-Regular.ttf")
const TEXTE = preload("res://fonts/DMSans.ttf")
static var _texte_moyen: FontVariation

## DM Sans graisse 500 (dernier morceau du fil d'Ariane, entrée active du rail).
static func texte_moyen() -> Font:
	if _texte_moyen == null:
		_texte_moyen = FontVariation.new()
		_texte_moyen.base_font = TEXTE
		_texte_moyen.variation_opentype = {"wght": 500}
	return _texte_moyen

## Contraste WCAG 2.x entre deux couleurs opaques.
static func contraste(a: Color, b: Color) -> float:
	var la := a.srgb_to_linear().get_luminance()
	var lb := b.srgb_to_linear().get_luminance()
	return (maxf(la, lb) + .05) / (minf(la, lb) + .05)

## Un club jaune ou or ne doit jamais se confondre avec le doré de l'action : il passe à la crème.
static func _proche_de_l_or(couleur: Color) -> bool:
	if couleur.s < .35 or couleur.v < .45: return false
	var ecart := absf(couleur.h - OR.h)
	return minf(ecart, 1.0 - ecart) < .07

## Éclaircit la vraie couleur du club jusqu'au seuil de contraste voulu sur `fond`.
static func _eclaircir(couleur: Color, fond: Color, seuil: float) -> Color:
	if couleur.a <= 0.0: couleur = CLUB
	if _proche_de_l_or(couleur): return IVOIRE
	var resultat := Color(couleur, 1.0)
	var pas := 0
	while contraste(resultat, fond) < seuil and pas < 40:
		resultat = resultat.lightened(.06)
		pas += 1
	return resultat if contraste(resultat, fond) >= seuil else IVOIRE

## Liseré, marqueur « nous » : ≥ 3:1 sur PANNEAU.
static func club_trait(couleur: Color = CLUB) -> Color:
	return _eclaircir(couleur, PANNEAU, 3.0)

## Nom du club en texte coloré : ≥ 4,5:1 sur PANNEAU_3 (donc aussi sur PANNEAU et PANNEAU_2).
static func club_texte(couleur: Color = CLUB) -> Color:
	return _eclaircir(couleur, PANNEAU_3, 4.5)

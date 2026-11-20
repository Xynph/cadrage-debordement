extends RefCounted
## Jetons de la charte (design/art/art-bible.md §3, §4.2, §7) : la seule source des couleurs, polices et formes
## de la direction artistique du logo. Les palettes plus anciennes (ui/immersive08/components.gd, ui/socle/jetons.gd)
## pointent sur ces jetons : tous les écrans partagent le même noir chaud et le même ivoire.
## Exemple : `var trait := Charte.club_trait(app.accent)` donne le liseré du club lisible sur `PANNEAU`.

## Fonds, du plus profond au plus haut.
const NUIT := Color("000000")       ## noir du logo : écran titre, plein cadre ; jamais un panneau
const FOND := Color("0e0d0b")       ## fond de la coque (noir chaud)
const PANNEAU := Color("171512")    ## rail, barre haute, surfaces de contenu
const PANNEAU_2 := Color("201d19")  ## survol, ligne zébrée
const PANNEAU_3 := Color("2b2721")  ## choisi, onglet actif, champ de saisie
const FILET := Color("3d372e")      ## filets 1 px (décoratif)
## Textes.
const IVOIRE := Color("f6eedc")     ## texte principal, marqueur de sélection
const IVOIRE_2 := Color("bdb4a2")   ## texte secondaire, étiquettes
const IVOIRE_3 := Color("8c8474")   ## désactivé, filigrane ; jamais sur PANNEAU_3
## Or : uniquement « Continuer » (l'action qui fait avancer le temps) et l'héritage (trophée, record, titre).
const OR := Color("e9c062")
const OR_VIF := Color("f1c970")     ## survol / pression du bouton or
## Papier : le seul document ouvert d'un écran (lettre d'un courrier, contrat, carnet, une de journal) ; jamais un tableau.
const PAPIER := Color("f6eedc")
const ENCRE := Color("14120f")
const ENCRE_2 := Color("5a5244")
const OR_ENCRE := Color("7d5b10")
const V_PAPIER := Color("2b6a43")
const D_PAPIER := Color("a3342c")
## Club : couleur réelle du club ; les dérivés se calculent (club_trait, club_texte).
const CLUB := Color("71322f")
const CLUB_TRAIT := Color("b5524a")
const CLUB_TEXTE := Color("d0756c")
## Sens : victoire / disponible, nul (neutre), défaite / blessure / alerte.
const V := Color("6cc48a")
const N := Color("ada597")
const D := Color("ee6f5f")
const V_DALTONIEN := Color("5aa9e6")

## Barème des attributs (fiche joueur, mini-fiche ; décision de Léo du 19/11/2026) : le chiffre est toujours
## écrit, la couleur dit le palier. Une légende accompagne chaque grille (BAREME_ATTRIBUTS).
const ATTRIBUT_0 := Color("ee6f5f")   ## 0-39
const ATTRIBUT_40 := Color("f2a04a")  ## 40-54
const ATTRIBUT_55 := Color("eadb55")  ## 55-64
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

## Inclinaison du logo (fûts du R et du L) : marqueurs, bord droit des boutons or, titres en italique.
const INCLINAISON_DEGRES := 10.0
## Décalage horizontal d'un bord incliné de 10° pour une hauteur donnée (32 px → 6 px).
static func decalage(hauteur: float) -> float:
	return hauteur * tan(deg_to_rad(INCLINAISON_DEGRES))

## Polices : Barlow Condensed (titres, vraies italiques) et DM Sans (texte). Pas de troisième famille.
const TITRE = preload("res://fonts/BarlowCondensed-SemiBold.ttf")
const TITRE_GRAS = preload("res://ui/immersive08/fonts/BarlowCondensed-Bold.ttf")
const TITRE_ITALIQUE = preload("res://ui/immersive08/fonts/BarlowCondensed-SemiBoldItalic.ttf")
const TITRE_GRAS_ITALIQUE = preload("res://ui/immersive08/fonts/BarlowCondensed-BoldItalic.ttf")
const TITRE_EXTRA_ITALIQUE = preload("res://ui/immersive08/fonts/BarlowCondensed-ExtraBoldItalic.ttf")
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

## Un club jaune ou or ne doit jamais se confondre avec l'or de Continuer : il passe à l'ivoire.
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

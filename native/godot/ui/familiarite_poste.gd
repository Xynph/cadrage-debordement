extends RefCounted
## Familiarité au poste + note au poste (revue FM27, remplace les étoiles de capacité au poste ; option B choisie par
## Léo le 23/11/2026 : barres de signal 5 crans + mot en petit). Deux informations séparées :
## - familiarité : 5 niveaux (mot + couleur franche de la charte), lue dans le moteur (positionFamiliarityLevels,
##   15 entiers 0-4, indice 0 = maillot 1) ; à défaut, déduite des postes du joueur (règle ci-dessous) ;
## - note au poste sur 100 (positionRatings du moteur), colorée avec le barème des attributs, la même pour tous les clubs.
## Règle de repli de la familiarité au maillot n (1-15) :
##   Naturel   = poste principal (primaryPositions) ;
##   Confirmé  = autre poste maîtrisé (secondaryPositions : même famille, famille voisine maîtrisée, 1re ligne qualifiée) ;
##   Correct   = famille voisine non maîtrisée (2e ligne ↔ 3e ligne, charnière ↔ centre, centre ↔ ailier/arrière…) ;
##   Dépanne   = même ligne (avants entre eux, trois-quarts entre eux) ;
##   Inadapté  = autre ligne, ou 1re ligne (1-3) sans qualification.
## Ce sont les catégories du moteur : il applique déjà au poste une efficacité (note au poste / note de la famille).
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const Charte = preload("res://ui/charte.gd")
const R = preload("res://ui/immersive08/reperes.gd")

const NATUREL := 4
const CONFIRME := 3
const CORRECT := 2
const DEPANNE := 1
const INADAPTE := 0

const MOTS := ["Inadapté", "Dépanne", "Correct", "Confirmé", "Naturel"]
## Couleurs franches de la charte (barème des attributs + perte) : rouge, orange, citron, vert clair, vert.
const COULEURS := [Charte.PERTE, Charte.ATTRIBUT_40, Charte.ATTRIBUT_55, Charte.ATTRIBUT_65, Charte.ATTRIBUT_75]

## Famille du moteur pour chaque maillot (dist/game.js FAMILIES) et familles voisines (position-aptitudes.cjs).
const FAMILLES := [0, 1, 0, 2, 2, 3, 3, 3, 4, 5, 6, 7, 7, 6, 8]
const VOISINES := [[], [], [3], [2], [5, 6], [4, 8, 7], [7, 8], [6, 8, 5], [6, 5, 7]]

static func _numeros(joueur: Dictionary, cle: String) -> Array[int]:
	var sortie: Array[int] = []
	var source: Variant = joueur.get(cle)
	if cle == "primaryPositions" and not source is Array: source = [joueur.get("primaryPosition")]
	if not source is Array: return sortie
	for v: Variant in source:
		if (v is int or v is float) and int(v) >= 1 and int(v) <= 15 and not int(v) in sortie: sortie.append(int(v))
	return sortie

## Niveau de familiarité (0 Inadapté … 4 Naturel) au maillot `numero` ; -1 si le poste du joueur est inconnu.
static func niveau(joueur: Dictionary, numero: int) -> int:
	if numero < 1 or numero > 15: return -1
	var moteur: Variant = joueur.get("positionFamiliarityLevels")
	if moteur is Array and (moteur as Array).size() == 15:
		var v: Variant = moteur[numero - 1]
		if (v is int or v is float) and is_finite(float(v)): return clampi(int(v), INADAPTE, NATUREL)
	var principaux := _numeros(joueur, "primaryPositions")
	if principaux.is_empty(): return -1
	if numero in principaux: return NATUREL
	if numero in _numeros(joueur, "secondaryPositions"): return CONFIRME
	if numero <= 3: return INADAPTE
	var sienne: int = FAMILLES[principaux[0] - 1]
	var cible: int = FAMILLES[numero - 1]
	if cible == sienne: return CONFIRME
	if cible in VOISINES[sienne]: return CORRECT
	return DEPANNE if (sienne <= 3) == (cible <= 3) else INADAPTE

static func mot(n: int) -> String:
	return str(MOTS[n]) if n >= 0 and n <= 4 else "?"

static func couleur(n: int) -> Color:
	return COULEURS[n] if n >= 0 and n <= 4 else Charte.IVOIRE_3

## Note au poste (0-100) écrite et colorée (barème des attributs) ; « ? » si inconnue.
static func poser_note(parent: Control, x: float, base: float, note: float, taille: int, largeur: float, nom: String) -> Label:
	var connue := note >= 0.0
	var l := D.text(parent, x + largeur, base, str(int(roundf(note))) if connue else "?", taille, Charte.couleur_attribut(note) if connue else Charte.IVOIRE_3, 800, largeur, HORIZONTAL_ALIGNMENT_RIGHT)
	l.name = nom
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	return l

## Barres de signal 5 crans : `niveau + 1` crans pleins à la couleur du niveau. Renvoie la largeur posée.
static func poser_barres(parent: Control, x: float, bas: float, n: int, hauteur: float, nom: String) -> float:
	var cran := maxf(4.0, roundf(hauteur * .26))
	var ecart := maxf(2.0, roundf(cran * .45))
	var fond := Control.new()
	fond.name = nom
	fond.mouse_filter = Control.MOUSE_FILTER_PASS
	fond.set_meta("familiarite", n)
	parent.add_child(fond)
	var largeur := 5.0 * cran + 4.0 * ecart
	D.place(fond, Rect2(x, bas - hauteur, largeur, hauteur))
	for i in 5:
		var h := hauteur * (.36 + .16 * float(i))
		var plein := n >= 0 and i <= n
		var barre := D.rect(fond, Rect2(float(i) * (cran + ecart), hauteur - h, cran, h), couleur(n) if plein else Color(Charte.CREME, .14), 2)
		barre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return largeur

## Marque de familiarité : barres 5 crans + mot en petit (si `mot_petit`), infobulle « Familiarité au poste · mot ».
## `base` : ligne de base du texte de la rangée. Renvoie la largeur posée.
static func poser(parent: Control, x: float, base: float, n: int, taille: int, nom: String, mot_petit := true) -> float:
	if n < 0:
		D.text(parent, x, base, "—", taille, Charte.IVOIRE_3, 600, 30).name = nom
		return 30.0
	var hauteur := float(taille) * 1.05
	var l := poser_barres(parent, x, base + 2.0, n, hauteur, nom)
	(parent.get_node(NodePath(nom)) as Control).tooltip_text = "Familiarité au poste · " + mot(n)
	if not mot_petit: return l
	var petit := maxi(13, taille - 3)
	var m := D.text(parent, x + l + 8.0, base, mot(n), petit, couleur(n), 700, R.largeur(mot(n), petit) + 4.0)
	m.name = nom + "Mot"
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l + 8.0 + R.largeur(mot(n), petit) + 4.0

## Largeur que prend `poser` (pour aligner les colonnes).
static func largeur(n: int, taille: int, mot_petit := true) -> float:
	if n < 0: return 30.0
	var hauteur := float(taille) * 1.05
	var cran := maxf(4.0, roundf(hauteur * .26))
	var l := 5.0 * cran + 4.0 * maxf(2.0, roundf(cran * .45))
	return l + (8.0 + R.largeur(mot(n), maxi(13, taille - 3)) + 4.0 if mot_petit else 0.0)

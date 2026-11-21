extends RefCounted
## Repères courts qui remplacent les phrases d'explication (règle de Léo du 21/11/2026) :
## pastille d'état (icône ou symbole + un mot), tuile (gros chiffre + légende courte) et rond « i » / « ? »
## dont le contenu passe dans l'infobulle. Coordonnées du gabarit 2560 (comme primitives.gd).
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const Charte = preload("res://ui/charte.gd")

## Couleurs franches selon le sens (demande de Léo du 21/11 : écrans moins fades) ; jamais seules (icône ou mot).
const VERT := Color("7fbf7a")       ## bon état, gain
const ORANGE := Color("e0a04a")     ## vigilance
const ROUGE := Color("d9634f")      ## danger, blessure
const BLEU := Color("5b9bd5")       ## information, moral
const VIOLET := Color("a88bd6")     ## confiance
const TURQUOISE := Color("4fb3a9")  ## repos

static func largeur(texte: String, taille: int, poids: int = 700) -> float:
	return C.font(poids).get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(12, C.px(taille))).x / C.density

## Pastille d'état : voile de la couleur, coins 6 px, icône (id de icon-paths.json) ou symbole en tête, texte de la
## couleur. `baseline` : ligne de base du texte. Le libellé porte le nom `id` (lisible par les tests), le fond `id + "Fond"`.
static func pastille(parent: Control, x: float, baseline: float, texte: String, couleur: Color, icone: String = "", id: String = "", taille: int = 20) -> Panel:
	var h := float(taille) + 13.0
	var icone_w := float(taille) + 2.0 if not icone.is_empty() else 0.0
	var texte_w := largeur(texte, taille) + 2.0
	var w := 12.0 + (icone_w + 7.0 if icone_w > 0 else 0.0) + texte_w + 12.0
	var fond := D.rect(parent, Rect2(x, baseline - float(taille) * .78 - 6.5, w, h), Color(couleur, .15), 8)
	fond.name = (id + "Fond") if not id.is_empty() else "Pastille"
	fond.mouse_filter = Control.MOUSE_FILTER_PASS
	fond.tooltip_text = texte
	if icone_w > 0:
		var image := C.icon(icone, int(icone_w), couleur)
		fond.add_child(image)
		D.place(image, Rect2(12, (h - icone_w) / 2.0, icone_w, icone_w))
	var libelle := D.text(fond, 12.0 + (icone_w + 7.0 if icone_w > 0 else 0.0), h / 2.0 + float(taille) * .36, texte, taille, couleur, 700, texte_w)
	if not id.is_empty(): libelle.name = id
	libelle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return fond

## Tuile de chiffre : gros chiffre + légende courte en capitales, carte rayon 12, voile neutre.
## `taille` : corps du chiffre (la tuile tient dans `zone`, hauteur comprise).
## `alerte` : léger fond teinté de la couleur (tuile d'alerte).
static func tuile(parent: Control, zone: Rect2, valeur: String, legende: String, couleur: Color = Charte.IVOIRE, id: String = "", taille: int = 40, alerte: bool = false) -> Panel:
	var fond := D.rect(parent, zone, Charte.PANNEAU_3.lerp(couleur, .16) if alerte else Charte.PANNEAU_3, 16)
	fond.name = id if not id.is_empty() else "Tuile"
	fond.mouse_filter = Control.MOUSE_FILTER_PASS
	fond.tooltip_text = valeur + " " + legende
	var base := zone.size.y / 2.0 + float(taille) * .36
	var chiffre := D.text(fond, 14, base, valeur, taille, couleur, 800, largeur(valeur, taille, 800) + 4)
	chiffre.add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
	chiffre.name = "TuileValeur"
	chiffre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var x := 14.0 + largeur(valeur, taille, 800) + 12.0
	var cap := D.text(fond, x, zone.size.y / 2.0 + 6, legende.to_upper(), 17, Charte.IVOIRE_2, 700, maxf(20.0, zone.size.x - x - 10))
	cap.name = "TuileLegende"
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return fond

## Rond « i » (ou « ? » pour les raccourcis) : le texte d'aide n'est plus à l'écran, il est dans l'infobulle.
static func rond(parent: Control, x: float, centre_y: float, aide: String, symbole: String = "i", id: String = "", cote: float = 26.0) -> Panel:
	var fond := D.rect(parent, Rect2(x, centre_y - cote / 2.0, cote, cote), Color.TRANSPARENT, Charte.RAYON_PILULE, Charte.IVOIRE_2)
	(fond.get_theme_stylebox("panel") as StyleBoxFlat).set_border_width_all(maxi(1, C.px(1.5)))
	fond.name = id if not id.is_empty() else "Aide"
	fond.mouse_filter = Control.MOUSE_FILTER_STOP
	fond.tooltip_text = aide
	fond.accessibility_name = aide
	var lettre := D.text(fond, cote / 2.0, cote / 2.0 + 6, symbole, 17, Charte.IVOIRE_2, 700, cote, HORIZONTAL_ALIGNMENT_CENTER)
	lettre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if symbole == "i": lettre.add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
	return fond

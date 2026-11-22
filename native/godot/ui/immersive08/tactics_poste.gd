extends RefCounted
## Valeur d'un joueur au poste (Tactique : cartes du terrain, liste des candidats) : la note au poste en chiffre, colorée
## par paliers (barème des attributs de la charte), et sa familiarité avec le poste (naturel, 2e poste, dépanne).
## Choix de Léo (21/11/2026) : chiffre dans une pastille colorée par paliers + petite pastille « 2e poste » (bleu) /
## « Dépanne » (rouge), mot + couleur, seulement hors poste naturel.
## Exemple : `Poste.poser(bouton, Rect2(60, 30, 138, 18), 72, 3, "TacticsPositionRating01")`.
const D = preload("res://ui/immersive08/primitives.gd")
const Charte = preload("res://ui/charte.gd")
const Kit = preload("res://ui/immersive08/tactics_kit.gd")

const MOTS := {2: "2e poste", 1: "Dépanne"}
const MOTS_COURTS := {2: "2e", 1: "Dép."}

## Couleur de la familiarité : vert clair au poste naturel, bleu au 2e poste, rouge en dépanne (toujours avec un mot).
static func couleur_familiarite(familiarite: int) -> Color:
	return Charte.V if familiarite >= 3 else Charte.V_DALTONIEN if familiarite == 2 else Charte.PERTE

static func mot(familiarite: int) -> String:
	return str(MOTS.get(familiarite, ""))

## Largeur (unités du gabarit) que prend la valeur au poste ; `court` = mots abrégés (carte du terrain encombrée).
static func largeur(note: Variant, familiarite: int, hauteur: float, court: bool = false) -> float:
	var l := _pastille(hauteur)
	if familiarite in [1, 2]: l += 5.0 + _largeur_marque(familiarite, court)
	return l

static func _pastille(hauteur: float) -> float:
	return maxf(36.0, hauteur * 2.0)

static func _largeur_marque(familiarite: int, court: bool) -> float:
	return Kit.largeur(str((MOTS_COURTS if court else MOTS).get(familiarite, "")), 13) + 12.0

## Pose la valeur au poste dans `zone` (alignée à gauche, ou à droite si `droite`). Le conteneur porte les méta
## « note » et « familiarite » ; le chiffre est un Label enfant. Note inconnue : « — » seul.
static func poser(parent: Control, zone: Rect2, note: Variant, familiarite: int, nom: String, droite: bool = false, court: bool = false, attenue: bool = false) -> Control:
	var boite := Control.new()
	boite.name = nom
	boite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(boite)
	var connue := (note is int or note is float) and is_finite(float(note))
	boite.set_meta("familiarite", familiarite)
	if connue: boite.set_meta("note", roundi(float(note)))
	if not connue:
		D.place(boite, zone)
		boite.set_meta("largeur", 30.0)
		var tiret := D.text(boite, zone.size.x if droite else 0.0, zone.size.y / 2.0 + 6, "—", 18, Charte.IVOIRE_3, 700, 30, HORIZONTAL_ALIGNMENT_RIGHT if droite else HORIZONTAL_ALIGNMENT_LEFT, true)
		tiret.name = "Chiffre"
		return boite
	var h := zone.size.y
	var chiffre := str(roundi(float(note)))
	var palier := Charte.couleur_attribut(note)
	# Pastille chiffrée + marque hors poste naturel.
	var p := _pastille(h)
	var avec_marque := familiarite in [1, 2]
	var lm := _largeur_marque(familiarite, court) if avec_marque else 0.0
	var l2 := p + ((5.0 + lm) if avec_marque else 0.0)
	var x1 := zone.size.x - l2 if droite else 0.0
	D.place(boite, Rect2(zone.position.x + x1, zone.position.y, l2, h))
	boite.set_meta("largeur", l2)
	# En liste (à droite) la pastille ferme la colonne pour aligner les chiffres ; sur le terrain elle ouvre la ligne.
	var xp := l2 - p if droite else 0.0
	var fond := D.rect(boite, Rect2(xp, 0, p, h), palier, Charte.RAYON_PILULE)
	fond.name = "Pastille"
	var nombre_a := D.text(boite, xp + p / 2.0, h / 2.0 + 6, chiffre, 17, Charte.ENCRE, 700, p, HORIZONTAL_ALIGNMENT_CENTER, true)
	nombre_a.add_theme_font_override("font", Kit.texte_gras())
	nombre_a.name = "Chiffre"
	if avec_marque:
		var couleur_m := couleur_familiarite(familiarite)
		var xm := 0.0 if droite else p + 5.0
		var marque := D.rect(boite, Rect2(xm, 1, lm, h - 2), Color(couleur_m, 0.16), Charte.RAYON_PILULE)
		marque.name = "Marque"
		var texte := D.text(marque, lm / 2.0, (h - 2) / 2.0 + 5, str((MOTS_COURTS if court else MOTS).get(familiarite, "")), 13, couleur_m, 700, lm, HORIZONTAL_ALIGNMENT_CENTER, true)
		texte.name = "MarqueMot"
	if attenue: boite.modulate = Color(1, 1, 1, .45)
	return boite

## Texte lu par l'accessibilité : « 72 au poste · dépanne ».
static func accessible(note: Variant, familiarite: int) -> String:
	var t := ("%d au poste" % roundi(float(note))) if (note is int or note is float) else "— au poste"
	if familiarite == 3: t += " · poste naturel"
	elif familiarite in [1, 2]: t += " · " + mot(familiarite).to_lower()
	return t

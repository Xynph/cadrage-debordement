extends RefCounted
## Valeur d'un joueur au poste (Tactique : cartes du terrain, liste des candidats) : la note au poste en LETTRE E- à S+
## (décision de Léo du 24/11/2026 : même échelle, même palette et même pastille ronde que le Niveau, double « B/A » quand
## le staff n'est pas sûr ; jamais de chiffre), et sa familiarité avec le poste (naturel, 2e poste, dépanne).
## Choix de Léo (21/11/2026) : petite pastille « 2e poste » (bleu) / « Dépanne » (rouge), mot + couleur, seulement hors
## poste naturel.
## Exemple : `Poste.poser(bouton, Rect2(60, 30, 138, 18), Selection.lettre(model, joueur, 0), 3, "TacticsPositionRating01")`.
const D = preload("res://ui/immersive08/primitives.gd")
const Charte = preload("res://ui/charte.gd")
const Kit = preload("res://ui/immersive08/tactics_kit.gd")
const Notation = preload("res://ui/notation_staff.gd")

const MOTS := {2: "2e poste", 1: "Dépanne"}
const MOTS_COURTS := {2: "2e", 1: "Dép."}

## Couleur de la familiarité : vert clair au poste naturel, bleu au 2e poste, rouge en dépanne (toujours avec un mot).
static func couleur_familiarite(familiarite: int) -> Color:
	return Charte.V if familiarite >= 3 else Charte.V_DALTONIEN if familiarite == 2 else Charte.PERTE

static func mot(familiarite: int) -> String:
	return str(MOTS.get(familiarite, ""))

static func _connue(lettre: Dictionary) -> bool:
	return int(lettre.get("bas", -1)) >= 0

## Largeur (unités du gabarit) que prend la valeur au poste ; `court` = mots abrégés (carte du terrain encombrée).
static func largeur(lettre: Dictionary, familiarite: int, hauteur: float, court: bool = false) -> float:
	var l := Notation.largeur_note(lettre, _diametre(hauteur)) if _connue(lettre) else 30.0
	if familiarite in [1, 2]: l += 5.0 + _largeur_marque(familiarite, court)
	return l

## Pastille un peu plus haute que la ligne : la lettre garde la taille de l'ancien chiffre (17).
static func _diametre(hauteur: float) -> float:
	# Lisible en 1920 (revue du 24/11 : ~14 px trop petit) : au moins 32 unités, 1,6 × la ligne.
	return maxf(32.0, hauteur * 1.6)

static func _largeur_marque(familiarite: int, court: bool) -> float:
	return Kit.largeur(str((MOTS_COURTS if court else MOTS).get(familiarite, "")), 13) + 12.0

## Pose la valeur au poste dans `zone` (alignée à gauche, ou à droite si `droite`). Le conteneur porte les méta
## « lettre » (texte de la pastille : « B », « B/A ») et « familiarite » ; la pastille est l'enfant « Pastille ».
## Note inconnue (non qualifié, place hors XV) : « — » seul.
static func poser(parent: Control, zone: Rect2, lettre: Dictionary, familiarite: int, nom: String, droite: bool = false, court: bool = false, attenue: bool = false) -> Control:
	var boite := Control.new()
	boite.name = nom
	boite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(boite)
	boite.set_meta("familiarite", familiarite)
	if not _connue(lettre):
		boite.set_meta("lettre", "—")
		D.place(boite, zone)
		boite.set_meta("largeur", 30.0)
		var tiret := D.text(boite, zone.size.x if droite else 0.0, zone.size.y / 2.0 + 6, "—", 18, Charte.IVOIRE_3, 700, 30, HORIZONTAL_ALIGNMENT_RIGHT if droite else HORIZONTAL_ALIGNMENT_LEFT, true)
		tiret.name = "Lettre"
		if attenue: boite.modulate = Color(1, 1, 1, .45)
		return boite
	boite.set_meta("lettre", Notation.texte_note(lettre))
	var h := zone.size.y
	var d := _diametre(h)
	# Pastille lettre + marque hors poste naturel.
	var p := Notation.largeur_note(lettre, d)
	var avec_marque := familiarite in [1, 2]
	var lm := _largeur_marque(familiarite, court) if avec_marque else 0.0
	var l2 := p + ((5.0 + lm) if avec_marque else 0.0)
	var x1 := zone.size.x - l2 if droite else 0.0
	D.place(boite, Rect2(zone.position.x + x1, zone.position.y, l2, h))
	boite.set_meta("largeur", l2)
	# En liste (à droite) la pastille ferme la colonne pour aligner les lettres ; sur le terrain elle ouvre la ligne.
	var xp := l2 - p if droite else 0.0
	Notation.pastille_note(boite, xp, h / 2.0, lettre, d, "Pastille")
	if avec_marque:
		var couleur_m := couleur_familiarite(familiarite)
		var xm := 0.0 if droite else p + 5.0
		var marque := D.rect(boite, Rect2(xm, 1, lm, h - 2), Color(couleur_m, 0.16), Charte.RAYON_PILULE)
		marque.name = "Marque"
		var texte := D.text(marque, lm / 2.0, (h - 2) / 2.0 + 5, str((MOTS_COURTS if court else MOTS).get(familiarite, "")), 13, couleur_m, 700, lm, HORIZONTAL_ALIGNMENT_CENTER, true)
		texte.name = "MarqueMot"
	if attenue: boite.modulate = Color(1, 1, 1, .45)
	return boite

## Texte lu par l'accessibilité : « B au poste · dépanne » (jamais de chiffre).
static func accessible(lettre: Dictionary, familiarite: int) -> String:
	var t := (Notation.texte_note(lettre) + " au poste") if _connue(lettre) else "— au poste"
	if familiarite == 3: t += " · poste naturel"
	elif familiarite in [1, 2]: t += " · " + mot(familiarite).to_lower()
	return t

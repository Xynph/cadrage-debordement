extends RefCounted
## Barème commun des étoiles de capacité (décision de Léo, 22/11/2026) : une note sur 100 (moyenne des qualités d'un
## rôle, note au poste du moteur…) devient 0 à 5 étoiles par demi-étoile, sur une échelle ABSOLUE, la même pour
## tous les joueurs : un joueur correct (60-65) tourne autour de 3 étoiles, 5 étoiles à partir de 80.
## Repères : 35 → 0 · 44 → 1 · 53 → 2 · 62 → 3 · 71 → 4 · 80 → 5.
## Étoiles = capacité au rôle ou au poste uniquement, jamais le niveau ni le potentiel.
const NOTE_ZERO := 35.0
const PAS_PAR_ETOILE := 9.0

## Étoiles (0 à 5, par demi) pour une note sur 100 ; -1 si la note est inconnue.
static func etoiles_sur_100(note: Variant) -> float:
	if not (note is int or note is float) or not is_finite(float(note)) or float(note) < 0.0: return -1.0
	return clampf(roundf((float(note) - NOTE_ZERO) / PAS_PAR_ETOILE * 2.0) / 2.0, 0.0, 5.0)

## Étoiles RELATIVES à notre effectif (choix de Léo du 22/11/2026, « solution 2 ») : `reference` = meilleure note du
## groupe à ce poste ou ce rôle ; elle vaut 5 étoiles, les autres en proportion (part de la référence), lisible en
## toute division. Repères : 100 % → 5 · 94 % → 4 · 88 % → 3 · 82 % → 2 · 76 % → 1 · 70 % et moins → 0.
## Au-dessus de la référence (recrue meilleure que notre n° 1) : 5. -1 si la note ou la référence est inconnue.
const PART_ZERO := 0.70
const PART_PAR_ETOILE := 0.06

static func etoiles_relatives(note: Variant, reference: Variant) -> float:
	if etoiles_sur_100(note) < 0.0 or etoiles_sur_100(reference) < 0.0 or float(reference) <= 0.0: return -1.0
	var part := float(note) / float(reference)
	return clampf(roundf((part - PART_ZERO) / PART_PAR_ETOILE * 2.0) / 2.0, 0.0, 5.0)

## Meilleure note d'une liste (valeurs inconnues ignorées) ; -1 si aucune.
static func meilleure_note(notes: Array) -> float:
	var meilleure := -1.0
	for n: Variant in notes:
		if etoiles_sur_100(n) >= 0.0: meilleure = maxf(meilleure, float(n))
	return meilleure

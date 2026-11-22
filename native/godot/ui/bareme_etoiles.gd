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

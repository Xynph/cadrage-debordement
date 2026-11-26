# Consignes données en direct (lot K1, 26/11/2026)

Demande de Léo : « changer joueurs/tactique DOIT changer le match ». Une consigne posée en cours de match (fenêtre
Équipe) doit changer la suite de la rencontre de façon visible, sans écraser le hasard, sans jamais montrer l'effet
exact au joueur, et sans dérégler le calage réel des championnats (favori, matchs serrés).

## Constat de départ (main 903d723e2)

Posées à la 50e, « Jeu au pied », « Relance », « Touche », « Ballon porté » et « Mêlée » laissaient la suite du match
identique dans 60 à 95 % des cas ; « Fin de match » ne changeait ni le temps de jeu ni le score. Elles ne jouaient que
sur des probabilités déjà minuscules (jeu au pied libre, touche près de leur ligne, dix dernières minutes).

## Ce qui change (dist/match-pilotage.js, table `CONSIGNES_POIDS`)

Aucun tirage ajouté ; chaque consigne agit là où le manager l'attend et reste sous l'effet d'un changement de plan.

- **Jeu au pied** : « Occuper » rapproche la probabilité de taper de celle du plan « occupation » (part 0,4) ;
  « Garder » la multiplie par 0,4, et une part des coups de pied perdus devient un porteur poussé en touche.
- **Relance** (dans notre camp) : « Dégager » rapproche de l'occupation (0,4), « Relancer » ×0,5.
- **Fin de match** : dès la 60e (70e avant, aide mise à jour) ; « Jouer la montre » : +12 s par action ballon en main,
  « Tout tenter » : −6 s et avantage d'attaque 0,04 (0,025 avant).
- **Touche** : « Sûre » +0,08 de touches gagnées (0,06) mais ballon lent (−0,06 d'avantage sur l'action suivante) ;
  « Risquée » : plateforme 0,1 (0,05) et 5 m de plus au porteur suivant (fond d'alignement).
- **Ballon porté** : « Souvent » +0,25 de pénaltouche et ballon porté tenté dès 30 m ; « Jamais » ×0,3 de pénaltouche,
  ballon porté seulement à 15 m (23 m sans consigne).
- **Mêlée** : fréquence des pénalités ×1,75 (« Pousser », 1,5 avant) ou ×0,5 (« Sortir vite », 0,65).

Branchements : `tactical-plans.js` (probabilité de taper, pénaltouche), `restarts.js` (coups de pied perdus),
`rugby.js` (zone du ballon porté), `matchflow.js` (durée des actions).

## Retenue de l'ordinateur (Premiership)

Les bancs de l'ordinateur suivent les mêmes règles que le staff : « Occuper » devant de 10 points au plus dès la 65e,
« Garder » menés dès la 55e, « Jouer la montre » / « Tout tenter » dès la 70e. Avec la pleine force du manager, les
matchs IA contre IA de Premiership perdaient des matchs serrés (écart ≤ 7) : 40,2 → 37,0 % sur 6 graines × 600 matchs
(4242, 7, 2026, 11, 99, 31 ; baisse sur 5 graines sur 6, réelle). Moitié jeu au pied, moitié fin de match.

Choix : `CONSIGNES_POIDS.ordinateur` garde chez l'ordinateur la force d'avant le lot pour ces deux axes (ancien
facteur de jeu au pied, fin de match dès la 70e sans changement de durée, avantage 0,025). Le manager humain (et son
staff en délégation) garde la pleine force. Après correctif : 39,1 % (main 40,2 %, réel 36 %), favori 63,3 % (64,1 %).

## Mesure avant / après (200 matchs, club 102, consigne posée à la 50e, même graine avec et sans consigne)

| Consigne | Suite changée main → branche | Effet branche après la 50e (main) |
| --- | --- | --- |
| Jeu au pied Garder | 23 → 64 % | coups de pied −1,05 (−0,26) |
| Jeu au pied Occuper | 19 → 52 % | coups de pied +0,79 (+0,23 ; plan occupation +2,1) |
| Relance Dégager | 14 → 36 % | coups de pied +0,43 (+0,15) |
| Relance Relancer | 37 → 56 % | coups de pied −0,33 (−0,18) |
| Fin de match montre | 50 → 100 % | actions −1,6, points encaissés −1,1 (≈ 0) |
| Fin de match tout | 53 → 100 % | actions +1,2 (+0,2) |
| Touche sûre | 12 → 22 % | touches gagnées 73 → 79 % |
| Touche risquée | 24 → 57 % | touches gagnées 73 → 68 %, marge +0,7 |
| Ballon porté jamais | 5 → 38 % | tirs au but +0,12, essais sur porté −0,09 |
| Ballon porté souvent | 7 → 37 % | tirs au but −0,10, essais sur porté +0,06 |
| Mêlée vite | 21 → 36 % | pénalités −0,24 (−0,04) |
| Mêlée pousser | 40 → 50 % | pénalités +0,51 (+0,43) |
| Rythme, rucks, discipline, coups d'envoi, cible | 58-99 % | inchangés |

Marge (points pour − contre après la 50e) toujours sous 2 points : le hasard garde sa place.

## Test

`tests/match-consignes-direct.cjs` (24 matchs × 24 variantes, ~1 min) : part minimale de matchs dont la suite change
par consigne, sens de l'effet (coups de pied, actions, touches, tirs, ballon porté, pénalités), marge bornée. Vert sur
la branche, rouge sur main (« Garder » : suite changée dans 21 % des matchs).

## Calage 6 saisons Monde

`scripts/mesure-essais-monde.cjs`, graines 4242, 7, 2026, 11, 99, 31, club 102, main (903d723e2) → branche, réel
(docs/realite-matchs-20261125.md). Favori : écart d'effectif ≥ 2, ~100 matchs par graine en Top 14 (± 2,7 points
d'échantillonnage sur la différence), ~40 à 80 ailleurs (± 3 à 5).

| Championnat | Points (réel) | Essais (réel) | Écart ≤ 7 (réel) | Favori gagne |
| --- | --- | --- | --- | --- |
| Top 14 | 50,1 → 50,8 (51) | 6,05 → 6,13 (5,2) | 37,6 → 38,9 % (40) | 63,8 → 60,5 % |
| Pro D2 | 48,5 → 48,5 (48) | 6,16 → 6,15 (5,5) | 40,1 → 39,9 % (42) | 62,6 → 63,0 % |
| Premiership | 56,8 → 57,0 (55) | 7,35 → 7,30 (7,1) | 38,5 → 38,2 % (36) | 71,3 → 72,3 % |
| URC | 51,2 → 50,8 (49) | 6,51 → 6,42 (6,3) | 36,9 → 37,3 % (41) | 74,2 → 73,8 % |
| Super Rugby | 57,0 → 57,7 (57) | 7,49 → 7,57 (7,8) | 36,3 → 34,7 % (35) | 77,0 → 81,8 % |
| Japon D1 | 60,3 → 60,9 (61) | 8,24 → 8,32 (8,5) | 32,3 → 34,9 % (30) | 76,9 → 80,5 % |
| Tous | 53,4 → 53,4 | 7,02 → 6,99 | 38,4 → 38,2 % | 69,3 → 69,3 % |

Aucun écart hors du bruit d'échantillonnage : points et essais à ±1, matchs serrés et favori dans les ±3 points de
main, sans sens commun (Top 14 et Super Rugby en sens opposés). Calage IA contre IA Premiership (calage.cjs, 600
matchs × 6 graines) : écart ≤ 7 40,2 % (main) → 39,1 %, favori 64,1 → 63,3 %.

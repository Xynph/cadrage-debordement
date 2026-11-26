# Conquête réaliste : mêlées et touches gardées sur son lancer (26 novembre 2026)

Constat (audit du moteur de match, anomalie n° 4) : sur son propre lancer, une équipe gardait sa mêlée 79-80 % du
temps et sa touche 76-77 % (réel, hors pénalités : 90-95 % et 85-88 %), du Top 14 à la Nationale. Cause : une base fixe
de 0,80 dans `contestSetPiece` (`dist/rugby.js`) pour deux packs égaux, mêlée et touche confondues. Le joueur voyait
environ 4 touches et 1,5 mêlée de trop perdues par match, quel que soit le niveau.

## Réglage (`CONQUETE`, `dist/rugby.js`)

Probabilité de garder le ballon sur son introduction ou son lancer, avant les termes déjà présents (combinaisons et
lecture adverse, consignes du direct, préparation collective, lanceur désigné, sang-froid, pénaltouche dans le camp
adverse) :

| | Base (packs égaux) | Par point d'écart des avants qui disputent | Par niveau de pluie | Plafond |
| --- | --- | --- | --- | --- |
| Mêlée | 0,925 (0,80) | 0,005 (0,004) | −0,015 (0) | 0,98 (0,97) |
| Touche | 0,905 (0,80) | 0,004 (0,004) | −0,03 (0) | 0,97 (0,97) |

Entre parenthèses : l'ancien calcul. Les avants qui disputent sont ceux d'avant : piliers, talonneur et deuxième
ligne en mêlée (note de mêlée), talonneur et piliers lifteurs plus deuxième ligne en touche (note de touche). La pluie
(0, 1 ou 2, météo de la rencontre) rend le ballon glissant au lancer et les appuis moins sûrs en mêlée.
`CONQUETE_RULES = 0` rend l'ancien calcul (comparaison sur les mêmes graines). Les rencontres sans `balanceVersion: 2`
gardent l'ancien calcul. Aucun tirage ajouté, règles du jeu inchangées : la pénalité de mêlée ou de touche est tirée
avant (inchangée), le lancer pas droit reste une part des touches perdues, la mêlée non disputée reste sans contest.

La touche reste moins sûre que la mêlée : la pénaltouche dans le camp adverse garde son risque (`PENALTOUCHE`,
docs/penaltouche-20261125.md), d'où ~83 % sur pénaltouche contre ~90 % ailleurs.

## Mesure (600 matchs par championnat, carrière Monde, mêmes graines, main / branche)

Conquête gardée hors pénalités :

| Championnat | Mêlée | Touche | Mêlées perdues / match | Touches perdues / match |
| --- | --- | --- | --- | --- |
| Top 14 | 79,6 / 91,1 % | 77,1 / 86,7 % | 1,50 / 0,66 | 4,15 / 2,39 |
| Premiership | 78,4 / 92,1 % | 76,8 / 85,9 % | 1,51 / 0,56 | 4,63 / 2,87 |
| URC | 79,4 / 91,8 % | 77,1 / 85,8 % | 1,54 / 0,62 | 4,62 / 2,84 |

Gros pack contre pack faible (écart des avants ≥ 8 points de note / ≤ −8), branche : mêlée 95-97 % contre 84-88 %,
touche 95-96 % contre 75-76 % (main : 81-89 % contre 73-75 % en mêlée, 88 % contre 65-67 % en touche). Pluie forte :
touche 80-81 % contre 87-88 % au sec.

Inchangés (main / branche) : pénalités sur mêlée 2,5-2,8 par match ; essais sur ballon porté ou mêlée près de la
ligne 0,70 / 0,65 (Top 14), 0,97 / 0,98 (Premiership), 0,89 / 0,98 (URC) touche, 0,29-0,31 / 0,33-0,36 mêlée.
Points, essais et matchs serrés : voir la description de la PR (3 championnats × 600 matchs et saisons Monde 4242,
7 et 2026).

## Tests

`tests/match-conquete.cjs` (carrière world-champ, graine fixe, 240 matchs complets Top 14 et URC) : moyenne gardée
(mêlée 89-95 %, touche 84-89,5 %), pertes par match, écart gros pack / pack faible, pénalités de mêlée, pluie.
Rouge sur main (80 % / 77 %).

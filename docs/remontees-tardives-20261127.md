# Remontées tardives (27/11/2026, branche `claude/remontees-tardives`)

Constat (réserve de #1314, ANOMALIES.md) : une équipe menée de 11 à 14 points à la 75e revenait à 7 points ou moins de
l'adversaire dans environ un tiers des matchs (Top 14, Premiership, URC) ; réel Top 14 : 20-25 %.

## Cause

Mesure de main sur 16 saisons Monde (club 102), matchs menés de 11-14 à la 75e : l'équipe menée marque 2,7 points après
la 75e (0,40 essai), deux essais sur trois en jeu courant (le reste après une pénaltouche, déjà couverte par la défense
regroupée de #1314). Aucune pénalité tentée au but (il faut un essai) ; les remplacements (K3, #1350) n'y sont pour rien.
La poussée de fin de match (`GESTION_SCORE.poursuit`, +0,3 en attaque à la 80e pour une équipe menée de 4 à 15 points)
jouait aussi fort à deux scores qu'à un score, et rien ne freinait l'équipe menée en jeu courant.

## Réglage (aucun tirage ajouté, rien de nouveau à l'écran)

- `DEFENSE_REGROUPEE.deuxScores` (dist/tactical-plans.js) : devant d'au moins 11 points (plus qu'un essai transformé et une
  pénalité), l'équipe qui mène défend regroupée sur TOUTE action adverse à partir de la 72e (plein effet à la 77e) : ballon
  porté plus souvent arrêté, finition dans les 22 plus dure. Force 1,3 (×0,95 en Top 14, ×0,6 en URC, plus sensible).
  Sur pénaltouche, la règle de #1314 reste.
- `GESTION_SCORE.unScore` (dist/rugby.js) : menée de 4 à 10 points, l'équipe pousse plus fort (+0,42 au lieu de +0,3 à la
  80e), bonus défensif ou victoire à portée. Compense une partie des fins serrées perdues.

## Mesures

Saisons Monde complètes (club 102), main / branche, mêmes 8 graines (12, 13, 808, 1234, 5150, 77, 3141, 9001) :

| Championnat | Remontées 11-14 à la 75e | Écart ≤ 7 (réel) | Points | Essais |
| --- | --- | --- | --- | --- |
| Top 14 | 35,9 / 20,3 % (n 181 / 153) | 40,0 / 37,0 % (40) | 50,4 / 49,9 | 6,12 / 6,04 |
| Premiership | 30,1 / 19,2 % (n 93 / 104) | 37,8 / 33,5 % (36) | 56,7 / 55,8 | 7,31 / 7,24 |
| URC | 36,8 / 23,5 % (n 133 / 153) | 38,3 / 36,7 % (41) | 50,8 / 50,6 | 6,47 / 6,37 |

Matchs IA contre IA (2 × 600 par championnat, graines 4242 et 7, main / branche) : écart ≤ 7 Top 14 38,5 / 35,8 %,
Premiership 40,3 / 38,5 %, URC 37,8 / 39,3 % ; favori (niveau +1) Top 14 64,9 / 66,4 %, Premiership 62,4 / 62,0 %, URC
71,7 / 70,2 % ; bonus défensif par match 0,27 / 0,24, 0,37 / 0,35, 0,34 / 0,35 ; points à 1,4 près.

Bruit des saisons : deux séries de 8 graines au même réglage s'écartent jusqu'à 3 points sur l'écart ≤ 7 et 6 points sur
les remontées. Les sondes à tirages communs (match IA contre IA figé à la 60e, écarts pondérés comme en saison) donnent
une perte d'écart ≤ 7 de 0,5 à 1 point, inévitable : les remontées de 11-14 points SONT des fins serrées (≈ 10 % des
matchs à la 75e).

Banc du test `tests/match-remontees-tardives.cjs` (IA contre IA, 40 matchs figés à la 75e × 40 rejeux, Top 14 graines 7 et
4242, URC graine 7, mêmes tirages avec et sans la défense regroupée à deux scores) : 27,0 % sur main, 18,3 % sur la
branche (échelle plus basse que la saison Monde). Menée de 3 à 9 à la 75e : fins serrées inchangées (à un point près).

## Restes

- Matchs serrés en baisse en Top 14 (−2 à −3 points en saison comme en IA contre IA ; une 2e série de 8 graines au réglage voisin donnait −1,3) et en Premiership : le moteur tirait une partie de ses fins serrées de remontées trop fréquentes. Il manque une autre source de fins serrées (pénalités et drops de fin de match, gestion du score des matchs à un score) ; à traiter dans un lot suivant, sans revenir sur les remontées.
- `match-consignes-direct` (24 matchs) et `fatigue-phases-arretees` (compétence du buteur en fin de match) sont au bord
  de leurs seuils sur main aussi (« montre : moins de points encaissés » −0,04 ; buteur −1,8 pour un seuil de 2) : de
  nombreux réglages voisins les font passer au rouge sans rapport avec ce qu'ils vérifient. Réglage retenu vert sur les
  deux ; à élargir leur échantillon (accord de Léo requis).

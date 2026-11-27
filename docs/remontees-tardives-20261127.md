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
  porté plus souvent arrêté, finition dans les 22 plus dure. Force 1,3 (×0,85 en Top 14, ×0,7 en URC). Sur pénaltouche,
  la règle de #1314 reste.
- `GESTION_SCORE.unScore` (dist/rugby.js) : menée de 4 à 10 points, l'équipe pousse plus fort (+0,45 au lieu de +0,3 à la
  80e), bonus défensif ou victoire à portée : rend une partie des fins serrées que fournissaient les remontées.
- Essai écarté : faire « tenir le score » à l'équipe qui mène de 1 à 7 points (attaque réduite) rendait des fins serrées
  mais écrasait la hiérarchie et le domicile (vérificateur : pente URC 0,206 pour 0,30, meneur à la 75e battu 21-27 %).

## Mesures

Matchs IA contre IA comme en carrière (3 graines × 600 matchs par championnat, graines 4242, 7 et 2026), main / branche :

| Championnat | Remontées 11-14 à la 75e | Écart ≤ 7 | Favori (niveau +1) | Domicile | Points | Essais | Bonus déf. |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Top 14 | 25,0 / 17,0 % | 37,0 / 38,3 % | 64,7 / 63,3 % | 72,3 / 69,6 % | 50,6 / 50,7 | 6,15 / 6,17 | 0,26 / 0,27 |
| Premiership | 31,9 / 21,6 % | 39,7 / 38,2 % | 62,7 / 63,1 % | 66,4 / 65,3 % | 57,7 / 57,0 | 7,38 / 7,30 | 0,36 / 0,33 |
| URC | 29,7 / 21,4 % | 37,4 / 37,8 % | 72,0 / 71,3 % | 60,2 / 61,3 % | 51,2 / 50,9 | 6,46 / 6,39 | 0,34 / 0,34 |

Erreur type d'une différence sur 1 800 matchs : ≈ 1,6 point. En saison Monde complète (fatigue, rotations), les remontées
sont plus hautes que sur ce banc (main : 34 % dans les trois championnats sur 16 graines).

Banc courbe (`tests/match-realite-championnats.cjs`, moteur complet) : domicile à niveau égal Top 14 79,4 %, Premiership
72,4 %, URC 68,7 % ; pente 0,168 / 0,227 / 0,295 (visées 0,19 / 0,23 / 0,30) : vert.

Banc du test `tests/match-remontees-tardives.cjs` (IA contre IA, 40 matchs figés à la 75e × 40 rejeux, Top 14 graines 7 et
4242, URC graine 7, mêmes tirages avec et sans la défense regroupée à deux scores) : 26,7 % sans, 18,8 % avec.

## Restes

- Top 14 : 17 % de remontées sur le banc IA contre IA (cible 20-25 %, plus haut en saison Monde). Les réglages voisins
  font échouer `match-consignes-direct` : ce test (24 matchs, une semaine du Monde simulée entre ses moments) change
  d'issue sur l'une de ses 40 assertions au moindre changement de tirages. Élargir son échantillon demande l'accord de Léo.
- `fatigue-phases-arretees` (compétence du buteur en fin de match) est au bord de son seuil sur main aussi (−1,8 pour 2).
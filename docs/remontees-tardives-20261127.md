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
  porté plus souvent arrêté, finition dans les 22 plus dure. Force 1,3 (×0,95 en Top 14, ×0,85 en URC). Sur pénaltouche,
  la règle de #1314 reste.
- `GESTION_SCORE.unScore` (dist/rugby.js) : menée de 4 à 10 points, l'équipe pousse plus fort (+0,42 au lieu de +0,3 à la
  80e), bonus défensif ou victoire à portée.
- `GESTION_SCORE.tenir` (dist/rugby.js) : devant de 1 à 7 points, l'équipe qui mène joue la sécurité (attaque −0,12 à la
  80e, rampe depuis la 55e, effet dès la 60e) : elle garde le score plutôt que de creuser. Rend les fins à un score que les
  remontées trop fréquentes fournissaient à tort.

## Mesures

Saisons Monde complètes (club 102), 16 graines (4242, 7, 2026, 11, 99, 31, 2027, 555, 12, 13, 808, 1234, 5150, 77, 3141,
9001), main / branche :

| Championnat | Remontées 11-14 à la 75e | Écart ≤ 7 (réel) | Points | Essais |
| --- | --- | --- | --- | --- |
| Top 14 | 34,1 / 15,5 % (n 346 / 283) | 40,0 / 41,0 % (40) | 50,7 / 49,9 | 6,14 / 6,01 |
| Premiership | 34,0 / 24,0 % (n 194 / 167) | 38,2 / 40,0 % (36) | 57,0 / 56,0 | 7,34 / 7,18 |
| URC | 34,3 / 20,3 % (n 268 / 286) | 38,0 / 39,7 % (41) | 50,8 / 50,2 | 6,45 / 6,32 |

Top 14 au même réglage sur deux autres séries de 16 graines (URC ×0,6 et ×0,72) : 16,8 et 18,8 % de remontées, 41,5 et
41,8 % d'écarts ≤ 7. Bruit d'une série de 16 graines : ±2 points sur les remontées.

Banc du test `tests/match-remontees-tardives.cjs` (IA contre IA, 40 matchs figés à la 75e × 40 rejeux, Top 14 graines 7 et
4242, URC graine 7, mêmes tirages avec et sans la défense regroupée à deux scores) : 27,2 % sans, 17,4 % avec (échelle plus
basse que la saison Monde). Menée de 3 à 9 à la 75e : fins serrées inchangées (à un point près).

## Restes

- Top 14 : remontées à 16-19 % (cible 20-25 %). Un Top 14 moins fort (×0,8 à ×0,92) les ramènerait vers 20-22 %, mais
  rend rouge `match-consignes-direct` dans 24 essais sur 24. Ce test (24 matchs du club 102 en Championship, avec une
  semaine du Monde simulée entre ses trois moments) change d'issue sur l'une de ses 40 assertions dès que n'importe quel
  championnat consomme d'autres tirages. Il faut élargir son échantillon (accord de Léo) avant d'affiner ce réglage.
- `fatigue-phases-arretees` (compétence du buteur en fin de match) est lui aussi au bord de son seuil sur main (−1,8 pour
  2) et varie avec les mêmes réglages.

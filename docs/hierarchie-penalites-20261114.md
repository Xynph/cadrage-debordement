# Hiérarchie et pénalités du moteur de match (14 novembre 2026)

Suite de `docs/essais-realistes-20261114.md` (#710) et de la courbe de niveau (#709, `docs/courbe-niveau-moteur-20261114.md`).
Carrière Monde uniquement (world-champ, 116 clubs, tous les championnats au moteur complet).

## 1. Pénalités : diagnostic

Mesure (`scripts/mesure-essais-monde.cjs`, saison complète, graine 4242, club 102 ; le script compte
désormais les pénalités sifflées par phase et la hiérarchie détaillée) : **10,2 pénalités sifflées par match
en Top 14** (8,6 jouées, le reste sous l'avantage), réel ~20. Cause, dans `advanceCausalPlay` :

- le moteur joue ~83 temps de jeu par match (un par minute) et ne siffle **qu'une seule sorte de faute** :
  celle du défenseur dans le jeu courant (~12 % par temps de jeu, selon la discipline et la défense) ;
- **aucune pénalité en mêlée** (~10 mêlées par match, réel ~3 pénalités ou coups francs sur ~12 mêlées) ;
- **aucune pénalité en touche ou sur ballon porté** ;
- **aucune faute de l'attaquant au sol** (ballon non libéré, scellement : en réalité ~30-40 % des pénalités
  vont à l'équipe qui défend).

D'où ~8 points au pied par match en Top 14 (17 % des points, réel ~25 %) et 47 points au lieu de 51.

## 2. Pénalités : correction (à la source, rencontres créées avec `penalitesVersion: 1`)

`dist/tactical-plans.js` (`PENALITES`, `PENALITES_RULES`, `penaliteConquete`, `pretereTouche`), `dist/rugby.js`,
`dist/restarts.js`, `dist/match-actions.js` (causes), `dist/saves.js` (drapeau validé). `PENALITES_RULES=0` rend
l'ancien moteur ; un match en cours d'une ancienne sauvegarde garde ses règles.

- **Mêlée** : 30 % des mêlées disputées s'arrêtent sur une pénalité, donnée au pack qui introduit à 55 %
  ± 1,5 point par point d'écart de mêlée (première ligne et deuxième ligne) : la mêlée dominante en obtient
  davantage (« faute en mêlée »). Les mêlées non disputées ne sont pas sifflées.
- **Touche et ballon porté** : 7 % des touches, 65 % pour l'équipe qui lance (« faute en touche ou sur ballon porté »).
- **Attaquant au sol** : 3,5 % des temps de jeu (± discipline de l'équipe en possession, 2 à 8 %), pénalité et
  ballon pour la défense (« ballon non libéré au sol », « scellement du ballon dans le ruck »), pris sur la part
  des courses et du jeu au pied ; les fautes de main, touches et pénalités du défenseur gardent leurs seuils.
- **Défenseur dans le jeu courant** : +1 point de probabilité (0,12 → 0,13 de base).
- **Culture du championnat** (consigne automatique seulement) : une partie des tirs au but devient pénaltouche
  en URC (40 %), Premiership (45 %), Super Rugby (45 %), Championship (40 %), League One (40 %), Champions Cup
  (15 %), Challenge Cup (25 %) ; Top 14, PRO D2 et Nationale inchangés. Réel 2024-25 : les pénalités font ~25 %
  des points en Top 14, ~13-15 % en Premiership et en URC.
- **Finition** dans les 26 derniers mètres 0,47 → 0,51 (`ESSAIS.finition`) : les arrêts de jeu supplémentaires
  (fautes de l'attaquant surtout) coûtaient ~8 % des essais.
- La pénalité donnée à l'équipe qui n'a pas le ballon lui rend la possession avant le choix (aucun avantage
  sur une faute de l'équipe en possession, comme en vrai).

Coefficients calés sur un banc (paires réelles de clubs, 1 000 matchs par réglage, ~80 s) puis vérifiés sur
saison complète ; ce sont des coefficients de jeu, pas des probabilités mesurées.

## 3. Pénalités : avant / après (saison complète, graine 4242, club 102)

| Championnat | Pénalités sifflées avant → après | Essais avant → après | Points avant → après | Part des points sur pénalité avant → après (%) | Réussite pénalités avant → après (%) | Réel essais / points / part pén. |
|---|---|---|---|---|---|---|
| Top 14 | 10,2 → 18,4 | 5,92 → 5,9 | 46,7 → 52,5 | 16,6 → 26,5 | 75,7 → 76,9 | 5,9 / 51,1 / ~25 % |
| Pro D2 | 10,7 → 18,8 | 5,58 → 5,4 | 44,2 → 48,1 | 18,1 → 27 | 73,5 → 72,2 | ~5,2 / 50,9 / — |
| Nationale | 11,2 → 20,3 | 5,98 → 5,42 | 46,8 → 48,7 | 17,6 → 28,3 | 71,6 → 70 | — / ~45 / — |
| URC | 10,4 → 18 | 6,46 → 6,76 | 49,2 → 50,8 | 14,5 → 13,5 | 71,4 → 69,8 | 6,6 / 48,3 / ~14 % |
| Premiership | 10 → 18,5 | 8,17 → 8,42 | 59 → 62,2 | 10,7 → 11,7 | 73 → 71,7 | 8,0 / 56,3 / ~13 % |
| Championship | 10,7 → 19,4 | 8,21 → 8,55 | 60,5 → 63,3 | 11,9 → 12,7 | 70,8 → 71,8 | 8,6 / 59,0 / — |
| Super Rugby | 10,9 → 18,5 | 7,8 → 8,93 | 59,1 → 64,5 | 14,4 → 10,7 | 73,5 → 70,4 | 8,3 / 57,8 / — |
| League One D1 | 9,9 → 18,1 | 8,64 → 8,75 | 63,2 → 64,4 | 11,2 → 11,4 | 72,5 → 70,1 | 8,6 / 61,7 / — |
| League One D2 | 10,9 → 18,6 | 8,04 → 8,39 | 59,5 → 59,9 | 12,5 → 9,9 | 68,1 → 60,7 | — / — / — |
| Tous (y c. coupes) | 10,6 → 18,8 | 6,82 → 6,98 | 52 → 55,6 | 14,7 → 18,4 | 72,7 → 71,9 |  |

Origine (après, tous) : melee 3, jeu 11.2, attaque 3.3, touche 1.4 ; choix (après) : 32.2 % au but, 61.2 % en touche ; ailier titulaire 0.48 → 0.47 ; avants 34.3 → 36.9 %, ailiers 28.2 → 27.1 %

Lecture : Top 14 à 52,5 points (réel 51,1), 5,9 essais (5,9), 26,5 % des points au pied (~25 %), 76,9 % de
réussite. Premiership et Super Rugby un peu au-dessus du réel (62 et 64 points pour 56 et 58) ; League One D2
à 61 % de réussite (buteurs plus faibles). Les marqueurs restent étalonnés (talonneur 7,3 → 8,4 % des essais par
plus de ballons portés après pénaltouche).

## 4. Hiérarchie : diagnostic

Mesures (championnats, saison régulière ; « effectif » = moyenne des 23 meilleures notes au poste en début
de saison). Banc des vrais effectifs (paires de clubs d'un même championnat, condition 100, 2 000 matchs) :
la pente du moteur sur l'écart de niveau réel (`teamLevel` du XV aligné) est de **0,16 ± 0,04 par point**
avec les effectifs du barème V2 (#716), pour une cible de 0,183 (courbe de #709) : **le moteur suit la courbe**.

La hiérarchie faible de `main` vient surtout des **effectifs trop resserrés** : dans un même championnat,
l'écart de niveau entre deux clubs a un écart type de **1,1 point** sur `main` (PRO D2 : 0,3 point
d'écart type entre effectifs) contre 2,7 points avec le barème V2 ; 85 % des matchs de championnat opposent
des effectifs à moins de 2 points, où le favori ne peut gagner que 52-57 % de ses matchs avec la courbe
cible. Une pente plus forte du moteur ne créerait pas de hiérarchie réaliste à partir d'écarts de 1 point
sans rendre les grands écarts déterministes (c'était le cas de `ESSAIS.ecart = 2` cumulé avec #709 :
92-100 % à 16 points d'écart) : **la source est le barème des notes (#716)**, pas le moteur. Le bruit
tactique (plan d'attaque de l'IA tiré au hasard, météo) pèse autant que le niveau sur un match (même écart
type de logit), ce qui garde l'incertitude.

Ce que le moteur corrige ici : les nouvelles pénalités récompensent la mêlée dominante et la discipline,
deux qualités liées au niveau. Effet mesuré (graine 4242) :

| Tranche d’écart d’effectif | Matchs (main) | Favori main avant → après (%) | dont à domicile | dont à l’extérieur | Barème V2 (#716), moteur actuel : favori (dom / ext) |
|---|---|---|---|---|---|
| 0-1 | 773 | 52,2 → 53 | 68,6 → 68,9 | 37 → 39,3 | 54,3 (78,2 / 31) sur 368 |
| 1-2 | 300 | 49,7 → 57,3 | 62,3 → 71,3 | 37 → 43,3 | 57 (73,1 / 40,9) sur 341 |
| 2-3 | 125 | 48 → 66,8 | 66,1 → 71 | 30,2 → 62,7 | 58,3 (75 / 40,9) sur 259 |
| 3-5 | 55 | 68,2 → 71,8 | 83,3 → 90,7 | 53,6 → 53,6 | 67,7 (86,3 / 48,2) sur 229 |
| 5-+ | 11 | 54,5 → 68,2 | 66,7 → 66,7 | 40 → 70 | 76,9 (79 / 75) sur 67 |

avant : favori toutes tranches 52,3 % ; surprises (écart ≥ 3 perdu) 22 ; corrélation de rang moyenne 0.16 (effectif) ; domicile 63,7 %
apres : favori toutes tranches 57,1 % ; surprises (écart ≥ 3 perdu) 18 ; corrélation de rang moyenne 0.34 (effectif) ; domicile 63 %
v2 : favori toutes tranches 59,5 % ; surprises (écart ≥ 3 perdu) 85 ; corrélation de rang moyenne 0.46 (effectif) ; domicile 66,4 %

| Championnat | 1er – dernier (pts) main avant → après | Rang du mieux armé avant → après | Corrélation rang / effectif avant → après | V2 : 1er – dernier, rang du mieux armé, corrélation |
|---|---|---|---|---|
| elite | 86–35 (51) → 82–28 (54) | 5 → 1 | 0,03 → 0,64 | 106–31 (75), 1, 0,73 |
| accession | 101–33 (68) → 93–42 (51) | 1 → 2 | 0,34 → 0,44 | 112–30 (82), 2, 0,6 |
| prem | 60–26 (34) → 68–28 (40) | 5 → 1 | 0,18 → 0,35 | 71–31 (40), 3, 0,22 |
| urc | 66–13 (53) → 75–18 (57) | 8 → 2 | -0,04 → 0,31 | 76–17 (59), 1, 0,29 |
| srp | 63–27 (36) → 68–29 (39) | 4 → 4 | 0,26 → 0,2 | 60–20 (40), 1, 0,87 |
| jlo-d1 | 70–19 (51) → 79–13 (66) | 10 → 5 | 0,44 → 0,61 | 67–21 (46), 6, 0,31 |
| jlo-d2 | 52–21 (31) → 61–26 (35) | 7 → 6 | 0,21 → 0,07 | 55–25 (30), 4, 0,29 |
| nationale | 86–27 (59) → 87–25 (62) | 2 → 3 | 0,47 → 0,6 | 80–38 (42), 6, 0,52 |
| champ | 97–23 (74) → 108–33 (75) | 10 → 4 | -0,42 → -0,14 | 102–34 (68), 11, 0,33 |

Seconde graine (7, même club) : favori toutes tranches 54,0 → 52,3 %, corrélation rang / effectif 0,18 → 0,23,
mieux armé du Top 14 14e → 1er, de la Premiership 3e → 1er, mais de l'URC 6e → 14e. Pénalités identiques à la
graine 4242 (Top 14 : 9,9 → 18,7 sifflées, 5,95 → 5,93 essais, 46,7 → 52,2 points, 16,4 → 25,9 % au pied).
**Sur deux graines, le gain de hiérarchie est faible et en partie du bruit** (favori 53,2 → 54,7 %, corrélation
0,17 → 0,29) : il ne remplace pas le barème V2.

Comparaison au réel (Top 14, Premiership, URC) : le favori à domicile gagne ~70-75 %, le leader finit
rarement hors du top 4, des surprises existent. Sur `main` après ce lot, le favori à domicile gagne 69-91 %
selon l'écart (mais l'écart est presque toujours < 2 points), à l'extérieur 39-70 % ; le mieux armé du
Top 14 finit 1er sur les deux graines ; ailleurs il reste souvent hors du top 4. Avec le barème V2, la saison d'avant ce lot donnait déjà 0,46 et le
mieux armé 1er dans 4 championnats sur 9 ; l'effet cumulé V2 + pénalités n'est pas mesuré ici (voir limites).

## 5. Tests

- Nouveau `tests/hierarchie-penalites-monde.cjs` (carrière Monde, graine fixe, ~40 s) : 200 matchs Top 14 contre
  Top 14 et 120 Top 14 contre Nationale avec les vrais effectifs. Bornes larges : 15-25 pénalités sifflées,
  quatre origines présentes, 40-62 points, 4,6-7,2 essais, 17-36 % des points au pied, réussite 62-86 %,
  mêlée dominante > 55 % des pénalités de mêlée, domicile 52-80 %, favori à grand écart 75-99,5 %
  (≥ 60 % à l'extérieur, au moins une surprise), pente logistique 0,08-0,45 par point.
- Mesuré en local : 17,9 sifflées (jeu 10,5, attaque 3, mêlée 3, touche 1,3), 51,7 points, 5,67 essais,
  27,6 % au pied, 78,8 % de réussite ; favori à 15 points d'écart 91,3 % (84,2 % à l'extérieur, 12 surprises) ;
  domicile 65,8 % ; pente 0,172.
- Tests unitaires à tirage fixe adaptés : `playbook`, `match-actions` (pénalités de conquête coupées : ils fixent
  l'issue de la conquête), `match-structured-facts` (nouvelles causes), `match-penalite-main` (les pénalités
  jouées se comptent sur le match : une pénalité de mêlée peut suivre une pénalité jouée dans le même temps de jeu).
- Données figées régénérées avec leurs scripts : `tools/animation-replay/fixture.js` (tirage fixe 0,6 → 0,64 :
  une course sans essai) et `tests/fixtures/match-gestes-sequence.json` (le générateur écarte un préambule
  sifflé ou une seconde touche : séquence au club 4, même forme touche → ballon porté → essai → renvoi).

## 6. Limites

- Deux graines en saison complète (4242, 7) ; la hiérarchie par championnat varie beaucoup d'une graine à
  l'autre (10 à 16 clubs).
- Les coups francs ne sont pas modélisés (le réel « ~20 » mêle souvent pénalités et coups francs).
- Premiership et Super Rugby restent ~5 points au-dessus du réel.
- Hiérarchie : la vraie correction est le barème V2 (#716) ; après sa fusion, remesurer une saison
  (et l'avantage du terrain du moteur complet, que #716 mesure à 69-74 % à niveau égal).

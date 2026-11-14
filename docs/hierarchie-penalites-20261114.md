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
- Pas de pénalité de conquête à la minute d'un coup d'envoi (une pénalité réussie fermerait sans durée une
  prolongation à mort subite) ; la culture de pénaltouche ne joue qu'en temps réglementaire.
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

- **Notes par maillot à réétalonner** : `homme-du-match-postes` (CI) donne un écart type général de 1,32 (borne 1,3) et
  un talonneur à 6,02 de moyenne : deux fois plus de pénalités concédées, attribuées par `match-notes.cjs` au
  plaqueur déduit de la place défensive quelle que soit la cause. Voir la passation de la PR.

- Deux graines en saison complète (4242, 7) ; la hiérarchie par championnat varie beaucoup d'une graine à
  l'autre (10 à 16 clubs).
- Les coups francs ne sont pas modélisés (le réel « ~20 » mêle souvent pénalités et coups francs).
- Premiership et Super Rugby restent ~5 points au-dessus du réel.
- Hiérarchie : la vraie correction est le barème V2 (#716) ; après sa fusion, remesurer une saison
  (et l'avantage du terrain du moteur complet, que #716 mesure à 69-74 % à niveau égal).

## 7. État au 14/11 soir (main avec barème V2 #716, essais #710, stats #709, pénalités #721)

Mesure du moteur complet sur `origin/main` (10b5b90e), carrière Monde, saison complète de 46 semaines
(1 425 matchs au moteur complet), club 102, **deux graines : 4242 et 7** (`scripts/mesure-essais-monde.cjs`,
Node `--max-old-space-size=2000`, ~8 min par graine). Aucun coefficient du moteur n'a été changé dans ce lot.

### 7.1 Essais, points, pénalités (graine 4242 / graine 7)

| Championnat | Essais / match | Points / match | Pénalités sifflées / match | Part des points sur pénalité (%) | Réussite au but (%) | Réel essais / points / part pén. (%) |
|---|---|---|---|---|---|---|
| Top 14 | 6 / 6,3 | 50,5 / 52,2 | 17,5 / 17,5 | 22,3 / 21,1 | 74,3 / 69,9 | 5,9 / 51,1 / ~25 (pénalités ~20) |
| Pro D2 | 5,79 / 5,61 | 50 / 47,8 | 18,1 / 18,1 | 24,9 / 23,9 | 73,9 / 72,3 | ~5,2 / 50,9 / — |
| Nationale | 5,44 / 5,85 | 48,3 / 49,8 | 19,9 / 19,9 | 27,6 / 24,8 | 70,1 / 68,8 | 5-6 plausible / ~45 / — |
| Premiership | 8,95 / 9,06 | 65,2 / 66 | 16,3 / 16 | 9,7 / 10,3 | 75,2 / 75,5 | 8,0 / 56,3 / ~13 |
| URC | 6,81 / 7,04 | 52,1 / 53,4 | 16,8 / 17,1 | 14,8 / 14 | 74,6 / 74,9 | 6,6 / 48,3 / ~14 |
| Championship | 8,08 / 8,07 | 59,3 / 59,4 | 20,2 / 20,3 | 13,2 / 13,1 | 67,2 / 68,8 | 8,6 / 59,0 / — |
| Super Rugby | 9,28 / 9,02 | 66,7 / 64,7 | 16,2 / 16,7 | 8,7 / 9,1 | 75,2 / 72,9 | 8,3 / 57,8 / — |
| League One D1 | 9,09 / 9,13 | 65,7 / 65,9 | 17 / 17,2 | 10,4 / 10,5 | 70,7 / 73,7 | 8,6 / 61,7 / — |
| League One D2 | 8,39 / 7,98 | 61,5 / 58,6 | 18,9 / 19,5 | 12 / 13,1 | 61,9 / 69,4 | 7-9 plausible / — / — |
| Tous (y c. coupes) | 7,03 / 7,14 | 55,2 / 55,5 | 18 / 18,1 | 17,4 / 16,7 | 72 / — | — |

Lecture : les élites françaises sont sur la cible (Top 14 6,0-6,3 essais pour 5,9 ; 50-52 points pour 51 ;
17,5 pénalités sifflées pour ~20 avec les coups francs non modélisés ; 21-22 % des points au pied pour ~25 %).
Premiership, Super Rugby et League One D1 restent **de 8 à 10 points au-dessus** du réel (65 contre 56-58 ;
~9 essais contre 8-8,6), déjà noté en #721 : ce n'est pas un effet du barème V2. Marqueurs : ailiers 27-28 % des
essais, 0,47-0,49 essai par match pour un ailier titulaire (cible 0,3-0,5), avants 37 %.

### 7.2 Hiérarchie (saison régulière des championnats, 1 264 matchs ; « effectif » = moyenne des 23 meilleures notes au poste en début de saison)

| Tranche d'écart d'effectif | Matchs (4242 / 7) | Favori (%) | dont à domicile (%) | dont à l'extérieur (%) |
|---|---|---|---|---|
| 0-1 | 368 / 381 | 52,4 / 50,1 | 65,6 / 64,8 | 38,7 / 35,9 |
| 1-2 | 341 / 310 | 57,5 / 57,7 | 64,9 / 72,5 | 50 / 43,3 |
| 2-3 | 259 / 254 | 62,9 / 60 | 76,1 / 72,6 | 49,2 / 47,7 |
| 3-5 | 229 / 244 | 69 / 69,7 | 79,1 / 85 | 58,5 / 53 |
| 5 et plus | 67 / 75 | 74,6 / 87,3 | 87,1 / 91,7 | 63,9 / 83,3 |

Favori toutes tranches 60,1 / 60,1 % ; surprises (écart de 3 points ou plus perdu) 83 / 80 sur 1 264 matchs ;
victoire de l'équipe qui reçoit 60,8 / 63,8 % (tous matchs) ; corrélation de rang final / effectif 0,58 / 0,52
(moyenne des championnats de 8 clubs ou plus ; 0,46 avant les pénalités).

| Championnat | 1er – dernier (points de classement), 4242 / 7 | Meilleur effectif : rang final | Corrélation rang / effectif |
|---|---|---|---|
| Top 14 | 93-31 / 102-25 | 1er / 1er | 0,75 / 0,51 |
| Pro D2 | 103-37 / 97-27 | 4e / 4e | 0,69 / 0,79 |
| Nationale | 86-40 / 93-20 | 5e / 3e | 0,56 / 0,81 |
| Premiership | 71-25 / 76-22 | 1er / 2e | 0,22 / 0,15 |
| URC | 71-29 / 72-26 | 1er / 1er | 0,62 / 0,84 |
| Championship | 94-31 / 99-27 | 5e / 9e | 0,24 / 0,32 |
| Super Rugby | 71-24 / 67-20 | 3e / 1er | 0,77 / 0,81 |
| League One D1 | 74-21 / 74-11 | 4e / 2e | 0,59 / 0,83 |
| League One D2 | 56-26 / 54-23 | 1er / 5e | 0,79 / -0,40 |

Lecture : le favori à domicile gagne **65-76 % dès 0-3 points d'écart et 79-92 % au-delà** (cible réelle
~70-75 %, qui mêle tous les écarts : sur le mix du calendrier on est dans la cible côté domicile). À
l'extérieur, le favori gagne 36-50 % aux petits écarts, 53-83 % aux grands : l'avantage du terrain est
encore marqué, mais proche de la réalité. Le meilleur effectif finit dans le top 3 dans 5 championnats sur 9 sur
les deux graines, les surprises existent (champion n° 6 et n° 8 de l'effectif en Premiership et League One D2).

**Écart restant (non corrigé, le moteur n'est pas modifié ici)** : la corrélation reste faible là où les effectifs
sont resserrés ou à peu de clubs : **Premiership (0,15-0,22 ; 10 clubs)**, **Championship (0,24-0,32 ; meilleur
effectif 5e et 9e)**, League One D2 (8 clubs, -0,40 sur la graine 7). L'écart type d'effectif entre clubs y est
petit (Championship : têtes d'affiche à 54-55 de niveau pour un plafond de 56 ; Premiership : 68-70) alors que
la pente du moteur est correcte (0,16 par point, cible 0,183, voir §4). La piste est donc **dans le barème des
notes (#716)** : élargir l'écart de niveau entre clubs de ces trois championnats (les tranches 3-5 et 5+
y sont presque vides), pas dans le moteur de match. À décider.

### 7.3 Notes par maillot (POSTES_NOTE ré-étalonné)

Depuis le barème V2 les moyennes par maillot s'étalaient de 6,42 à 6,83. Ré-étalonnage avec
`scripts/etalonner-notes-postes.cjs` (capture en deux fois : semaines 1-8 puis 9-15, 399 matchs fusionnés, la capture
de 14 semaines d'un coup dépasse la mémoire ; le script accepte désormais une semaine de départ et plusieurs captures).
Moyennes par maillot après : 6,60 à 6,62 sur l'échantillon d'étalonnage, **6,51 à 6,69** sur les 164 premiers matchs du
test `homme-du-match-postes` (moyenne générale inchangée, 6,61), parts d'homme du match 2,5 à 13,3 % par maillot
(cible du document 2,5 à 13). Bornes des tests inchangées.

| Maillot | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Avant | [0,29 ; 1,32] | [-0,1 ; 0,91] | [0,15 ; 1,04] | [1,29 ; 0,93] | [1,61 ; 1,2] | [2,6 ; 1,09] | [2,53 ; 1,15] | [2,6 ; 1,08] | [0,81 ; 1,06] | [1,78 ; 1,36] | [1,56 ; 0,79] | [0,85 ; 1,03] | [0,9 ; 0,78] | [1,37 ; 0,81] | [0,4 ; 0,86] |
| Après | [0,48 ; 1,09] | [0,17 ; 0,92] | [0,26 ; 1,01] | [1,53 ; 0,97] | [1,83 ; 1,1] | [2,48 ; 1,02] | [2,57 ; 0,99] | [2,51 ; 1,07] | [0,47 ; 1,14] | [1,55 ; 1,33] | [1,44 ; 0,86] | [0,82 ; 0,98] | [0,86 ; 0,85] | [1,27 ; 0,92] | [0,34 ; 1,02] |

Limites : un seul club (102) et une seule graine pour les captures (les matchs de toute la planète sont notés, pas
seulement ceux du club) ; l'échantillon du test varie de ±0,1 sur la moyenne d'un maillot.

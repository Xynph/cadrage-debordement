# Courbe de niveau du moteur (14 novembre 2026)

Lot 0 du chantier « notes et potentiels réalistes par joueur, club et championnat » (décision de
Léo du 14/11, étude `notes-clubs-championnats-20261114`). Avant d'étirer les notes, le moteur doit
rendre l'écart de niveau plus déterminant et donner un vrai avantage du terrain, **de la même façon**
au moteur complet et au résultat rapide (championnats en « résultats rapides », #643).

## Formule (dist/rugby.js, `MATCH_LEVEL_CURVE`, version 1)

- Niveau d'une équipe = moyenne, sur les joueurs alignés, de `note × (0,57 + 0,0043 × condition)`
  (1,00 à 100 % de condition, 0,91 à 80 %). C'est la puissance déjà utilisée par le résultat rapide
  (`native/engine/league-detail.cjs`), désormais définie une seule fois (`teamLevel`).
- Cible commune : `logit P(victoire) = 0,183 × écart de niveau + 0,64 à domicile`, soit sur terrain
  neutre +3 → 63 %, +6 → 75 %, +10 → 86 %, +15 → 94 %, −10 → 14 %, et 65 % à domicile à niveau égal
  (+6 à domicile → 85 %, à l'extérieur → 62 %).
- Moteur complet : `teamEdge` (réussite des temps de jeu et finition) reçoit
  `0,005 × (niveau du camp − niveau adverse)` (`matchLevelEdge`, recalculé chaque minute : la fatigue,
  les cartons et les remplacements comptent) et ±0,045 à domicile (auparavant ±0,018).
- Résultat rapide : `avantage = (Δpuissance + 3,3 à domicile) / 7,5` (auparavant `(Δ + 2,5) / 8`),
  essais tirés selon une loi de Poisson de moyenne `2,75 × e^(±0,42 × avantage)` (inchangé).
- Terrain neutre : plus d'avantage du terrain pour une rencontre Monde marquée `neutral`
  (moteur complet via `l.worldContext.neutral`, résultat rapide via `fixture.neutral`). Avant, une
  finale sur terrain neutre du Monde donnait l'avantage au premier nommé.
- Coefficients de jeu calés par mesure, pas des probabilités réelles. Les anciennes sauvegardes
  n'ont rien à migrer : aucun champ nouveau n'est enregistré.

## Banc (tests/match-rating-curve.cjs, tests/helpers/courbe-niveau.cjs)

Carrière world-champ (club humain 102), deux copies d'un même club décalées de k points (note, base,
11 compétences, 36 attributs), domicile alterné à chaque match et emplacement du plus fort alterné
tous les deux matchs. Ajustement logistique commun à toutes les séries.

- CI : club de base 4 (Top 14), moteur complet 3 écarts × 240 matchs, résultat rapide 4 × 1 000 ;
  ~70 s en local. Bornes : pente, domicile, +6, +10, −10, points, essais et écart moyen, et
  écart entre les deux moteurs (pente ≤ 0,05, domicile ≤ 8 points).
- Version longue (manuelle, sous verrou) : `CD_COURBE_LONGUE=1 node --test tests/match-rating-curve.cjs`,
  9 écarts, 600 matchs complets et 4 000 rapides par écart, clubs de base 4 (Top 14), 20 (PRO D2)
  et 44 (URC), bornes resserrées.

## Mesures avant / après (club de base 4, Top 14 ; domicile alterné)

Avant : `origin/main` c1f52043, 500 matchs complets et 6 000 rapides par écart. Après : version
longue du banc, 600 matchs complets et 4 000 rapides par écart. Victoires du plus fort (nul = ½).

| Écart | Complet avant | Complet après | Rapide avant | Rapide après | Cible (neutre) |
| ---: | ---: | ---: | ---: | ---: | ---: |
| −10 | 23,8 % | 13,6 % | 15,1 % | 15,4 % | 14 % |
| 0 | 57,0 %* | 49,3 % | 50,1 % | 49,8 % | 50 % |
| +3 | 57,7 % | 67,1 % | 61,8 % | 62,6 % | 63 % |
| +6 | 65,8 % | 75,8 % | 73,0 % | 73,7 % | 75 % |
| +10 | 78,6 % | 86,5 % | 84,6 % | 85,2 % | 86 % |
| +15 | 85,0 % | 93,7 % | 93,2 % | 93,6 % | 94 % |
| Pente logistique / point | 0,120 | 0,209 | 0,177 | 0,185 | 0,183 |
| Domicile à niveau égal | 56,6 % | 66,6 % | 60,5 % | 64,7 % | 63–68 % |

\* Avant, le plus fort restait toujours sur le même emplacement de club : le banc alterne désormais
l'emplacement (le staff d'un club joue).

Autres clubs de base (après) : PRO D2 (club 20) +6 → 75,5 %, +10 → 86,6 %, domicile 68,3 % (ajusté
69,7 %) ; URC (club 44) +6 → 78,1 %, +10 → 85,5 %, domicile 67,2 % (ajusté 68,8 %) ; résultat rapide
identique d'un club à l'autre (+10 → 85,6-85,7 %, domicile 64-65 %). Version longue : PASS. Le moteur complet est un peu plus raide dans les queues
(+15 → 94-97 %) : sa pente ajustée (0,21-0,22) dépasse la cible, alors que les points +3 à +10
sont dans la cible.

Scores à niveau égal (inchangés à l'échantillonnage près) :

| | Points / match | Essais / match | Écart moyen |
| --- | ---: | ---: | ---: |
| Complet avant / après | 29,5 / 29,2 | 3,30 / 3,34 | 8,1 / 8,5 |
| Rapide avant / après | 48,9 / 50,0 | 5,51 / 5,63 | 13,5 / 14,2 |

Les grands écarts (+10, +15) font monter les points du plus fort (complet : 29 → 32-35 à +10/+15),
ce qui est voulu. L'écart de niveau entre moteur complet (≈ 30 points, 3,3 essais) et résultat
rapide (≈ 50 points, 5,6 essais) existait avant ce lot ; il relève du chantier « essais réalistes ».

## Saison Monde complète (club humain 102, Top 14 et URC au moteur complet, le reste en rapide)

Corrélation de Pearson entre le XV de départ (note moyenne du XV du sélecteur) et le % de victoires
en saison régulière, deux graines (827381, 4242), avant → après :

| Championnat | Moteur | 827381 | 4242 |
| --- | --- | --- | --- |
| Top 14 | complet | 0,22 → 0,26 | 0,40 → 0,19 |
| URC | complet | −0,14 → 0,09 | −0,18 → 0,05 |
| PRO D2 | rapide | −0,06 → 0,32 | 0,42 → 0,13 |
| Premiership | rapide | −0,20 → 0,60 | −0,51 → 0,42 |
| SRP | rapide | 0,81 → 0,36 | 0,45 → 0,62 |
| Japon D1 | rapide | 0,60 → 0,72 | 0,77 → 0,62 |
| Japon D2 | rapide | 0,50 → 0,19 | 0,47 → 0,17 |
| Nationale | rapide | 0,21 → 0,19 | 0,48 → 0,39 |
| Championship | complet | −0,39 → 0,04 | 0,39 → 0,30 |
| Moyenne | | 0,17 → 0,31 | 0,32 → 0,32 |

Victoires à domicile en saison : moteur complet 54-57 % → 60-64 %, résultat rapide 60-61 % →
63-67 %. Points par match inchangés (complet 30,6-32,0 → 30,6-31,1 ; rapide 49,6 → 49,8-50,1).
Poules européennes entre ligues : Top 14 16 et 18 victoires sur 32 → 19 et 23 sur 32.

Lecture : la courbe est en place, mais **la hiérarchie interne des championnats reste faible** tant que
les XV d'un même championnat tiennent en 1,6 à 4,3 points (étude, 1.2) : un écart de 2 points ne
vaut que 57 % de victoires. Elle doit venir des lots suivants (échelle des notes par club et par
championnat). Le XV de départ ne mesure pas non plus l'équipe réellement alignée (rotation,
internationaux libérés, blessures). Note : en carrière de test, le club humain non géré (club 0 de
l'étude) est pénalisé ; d'où le choix d'un club humain hors des championnats mesurés au moteur complet.

## Effets de bord corrigés

- `tests/opposition.cjs` : à 16 points d'écart, le plus fort gagnait 79 %, il gagne 95 % ; la borne
  haute passe de 95 % à 98,5 % et le test exige désormais des surprises à domicile **et** à l'extérieur.
- `native/engine/match-stats.cjs` : une mêlée non disputée (préparation puis introduction non
  disputée du même camp) était comptée deux fois dans la feuille de statistiques ; révélé par les
  nouveaux tirages (`tests/match-stats-realistes.cjs`).
- `tests/fixtures/match-gestes-sequence.json` (séquence touche-ballon porté-essai rejouée par Godot)
  régénérée par `node tests/godot-match-gestes-scenes.cjs` ; `tools/animation-replay/fixture.js`
  régénérée, avec un tirage fixe de 0,5 au lieu de 0,43 (à 0,43, la course franchit désormais et
  marque : la fixture veut une course sans essai, puis l'essai).

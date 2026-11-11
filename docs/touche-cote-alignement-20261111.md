# Touche : côté des alignements dans la scène 3D (11 novembre 2026)

Périmètre : la scène `lineout` produite par `matchScene` (`dist/match2d.js`) et
transmise telle quelle à la vue 3D par `dist/match3d/scene-adapter.js` et par le
moteur natif (`native/engine/worker.cjs` charge `match2d.js`). Référence :
[loi 18, touche](rugby-rules-reference.md), saison simulée 2025/26.

## Constat chiffré (sonde hors dépôt, 48 matchs, 758 scènes de touche)

Matchs simulés avec le vrai moteur (12 graines × 4 clubs, deux tactiques), toutes
les scènes `lineout` distinctes collectées, mi-temps 1 et 2, les deux équipes.
Le moteur n'inverse pas les sens d'attaque à la mi-temps : l'équipe 0 attaque
toujours vers x croissant, l'équipe 1 vers x décroissant ; la touche est toujours
du côté y = 0.

| Mesure | Avant correction |
| --- | --- |
| Équipe qui lance = équipe 0 (356 scènes, 2 mi-temps) | alignement en `x = touche − 2`, du côté de son propre en-but : conforme |
| Équipe qui lance = équipe 1 (402 scènes, 2 mi-temps) | alignement en `x = touche − 2`, donc du côté de l'en-but adverse : non conforme |
| Alignement de l'équipe qui ne lance pas | toujours en `x = touche + 2` : non conforme quand l'équipe 1 lance (les deux alignements étaient échangés) |
| Non-participants (slots 8 à 14) | restaient du côté de leur propre en-but, donc en contradiction avec leur alignement quand l'équipe 1 lançait |

Le défaut est donc réel et se produit dans 402 scènes sur 758 (toutes celles où
l'équipe 1 lance), dans les deux mi-temps.

## Règle appliquée

Chaque équipe se place du côté de son propre en-but par rapport à la ligne de
touche : `x = touche − 2` pour l'équipe 0, `x = touche + 2` pour l'équipe 1,
quelle que soit l'équipe qui lance. La correction tient en une ligne
(`side===team` devient `side===0`) et ne touche qu'au placement de la scène.
Elle ne lit ni n'écrit l'état du match et n'appelle pas le générateur aléatoire.

## Ce qui reste conforme ou non, mesuré et non modifié

- Conforme : les non-participants sont au moins à 13 m de la ligne de touche
  (exigence : 10 m), sauf quand la touche est à moins de 11,5 m environ d'une ligne
  d'en-but : la scène borne alors les joueurs à 1,5 m du bord (minimum mesuré
  3,5 m, 84 scènes sur 758). Ce bornage est une abstraction de la scène.
- Non conforme, non modifié : l'écart entre les deux alignements est de 4 m
  (attendu : un couloir d'un mètre).
- Non conforme, non modifié : la profondeur des alignements va de 9 m à 32,1 m de
  la ligne de touche (attendu : entre 5 m et 15 m) ; un seul des sept joueurs par
  alignement (hors lanceur) est dans la fourchette.
- Non conforme, non modifié : le lanceur (slot 1, y = 2) n'est pas sur la ligne de
  touche (décalé de 2 m) et le ballon est à y = 4 ; le slot 1 adverse est placé
  au même y = 2. Aucun lanceur nominal n'est désigné par le moteur.
- Les huit joueurs de devant de chaque équipe sont tous placés dans l'alignement :
  simplification de la scène, sans lien avec le nombre réel de sauteurs.

Ces écarts relèvent du dessin de la scène (profondeurs et espacements) et touchent
au rendu ; ils n'ont pas été traités ici pour ne pas mêler une décision visuelle
à une correction de côté.

## Preuve de non-régression sportive

80 matchs (20 graines × 4 clubs) rejoués avant et après avec `matchScene`
appelée à chaque tick : score, essais, statistiques, journal complet d'événements
(empreinte), état du match et prochain tirage aléatoire sont identiques.
Sur les 758 scènes de la sonde, seules les positions x des joueurs d'alignement
(slots 0 à 7) de l'équipe 1 qui lance ont changé ; aucune scène de l'équipe 0 n'a
changé.

## Test

`tests/lineout-side.cjs` : scènes réelles (4 graines × 3 clubs) plus scènes
construites pour les deux équipes aux deux extrémités du terrain ; vérifie, pour
chaque touche, les deux sens d'attaque et les deux mi-temps (au moins cinq scènes
chacun), le côté des alignements et des non-participants, la séparation des deux
alignements, la conservation des positions par l'adaptateur 3D et l'absence de
mutation de l'état. Le test échoue sur l'ancien code (équipe 1 lançant).

## Non vérifié

- Le rendu Godot de la touche n'a pas été regardé à l'écran ; seules les suites
  Godot automatisées citées dans la PR ont été exécutées.
- La couche optionnelle de la PR #554 (`native/godot/match_gestes.gd`) n'a pas été
  lue ni exécutée ici. Si elle compense déjà le côté, elle fera un double
  retournement avec cette correction : à vérifier à son intégration.
- La loi 18 n'impose pas de côté par équipe pour l'alignement : la règle appliquée
  (chaque équipe du côté de son propre en-but) est la convention retenue pour la
  scène, cohérente avec les non-participants, et n'a pas été confrontée au texte
  officiel de la loi dans cette tâche.

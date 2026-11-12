# Temps forts déclenchés par le moteur : l'importance d'une action — 12 novembre 2026

Demande de Léo : « l'idée est que le moteur de match détermine quand une action est
suffisamment importante pour être montrée et donc passer au temps fort ». Comme dans Football
Manager : le match se déroule en continu (entracte 2D) et, au moment où une action devient
importante, le moteur déclenche la 3D, avant que l'issue soit connue.

Branche `claude/match-importance-20261112` (part de `claude/match-entracte-2d-20261112`, PR 596).
Mesure : `node tools/qa/match-importance-mesure.cjs 200`. Code : `native/engine/match-highlights.cjs` (`importance`, `debutAction`, `finAction`,
`en_direct_importance`), `native/engine/match-direct.cjs` (`borneEntracte`, `camp`),
`native/godot/ui/contextual/match_temps_forts.gd` (bascule 2D → 3D). Tests :
`tests/match-importance.cjs`.

## 1. Règles de Léo et comment elles sont tenues

| Règle | Mise en œuvre |
| --- | --- |
| On ne sait pas à l'avance ce qui va se passer | L'importance d'un fait se calcule sur la situation au **début** de ce fait ; elle ne lit ni sa fin (`to`), ni le score d'après, ni sa nature quand elle dit l'issue (un tir au but compte comme « tir au but », réussi ou manqué). Test : essai remplacé par un plaquage, tir réussi par un tir manqué → même importance. |
| Des grosses actions sans point (35 à 50 %) | Le seuil est atteint par le danger, pas par le score : la plupart des actions montrées ne marquent pas. Régulateur d'issue (dynamique) aveugle à l'action en cours. |
| Un essai n'est annoncé que s'il est vu | Filet : un essai (ou un rouge) que l'importance n'a pas fait monter est montré depuis le début de son action (`rattrapage`). Tous les essais sont montrés. |
| On coupe le trajet, pas la phase | Le temps fort s'ouvre sur la touche ou la mêlée déjà formée, le ballon récupéré, le coup de sifflet d'un tir au but ; le coup de pied de pénaltouche n'est pas montré. |
| Temps forts jusqu'à 50 s | `DUREE_MAX = 50` s d'action, suites comprises (sauf pour ne pas couper un essai). |
| Le chrono défile entre deux temps forts | Après un temps fort, le seuil monte de 8 pendant deux minutes de jeu ; l'entracte reste d'au moins 8 s réelles (inchangé). |

## 2. Signaux de l'importance (0 à 100)

Équipe en attaque : celle qui a le ballon au début du fait (lanceur en touche, introducteur en
mêlée, buteur). Distance : de l'endroit où le fait commence jusqu'à la ligne adverse.

| Signal | Valeur |
| --- | --- |
| Danger (position) | 5 m : 60 ; 10 m : 54 ; 22 m : 46 ; 35 m : 36 ; 50 m : 20 ; au-delà : 8 |
| Phase formée dans les 22 adverses | touche ou mêlée : +8 (+16 à 10 m ou moins) |
| Tir au but | 66 (à la place du danger) |
| Franchissement en cours | la course précédente de la même équipe a gagné 22 m ou plus : +20 ; 12 m ou plus : +8 |
| Temps de jeu enchaînés | dans le camp adverse, +4 par temps au-delà du premier, 16 au plus |
| Surnombre | ballon récupéré à l'instant : +8 ; adversaire en infériorité (jaune actif, rouge) : +8 par joueur |
| Contexte | × (0,8 + 0,4 × tension) ; fin de match serrée (72e et plus, 7 points ou moins) : +8 ; mi-temps proche (37e et plus) : +4 ; club du manager en attaque : +3 |

La tension (0 match plié, 1 tout se joue) est celle de la sélection précédente : écart avant le
fait, minute, bonus, phase finale.

## 3. Seuils par niveau

`seuil = base − pente × tension`, plus les régulateurs.

| Niveau | Base | Pente | Seuil (match plié → tout se joue) | Amorce |
| --- | --- | --- | --- | --- |
| Clés | 74 | 6 | 74 → 68 | 2 plans |
| Dynamique (défaut) | 76 | 14 | 76 → 62 | 3 plans |
| Étendus | 56 | 6 | 56 → 50 | 4 plans |

- Période réfractaire : +8 pendant deux minutes de jeu après la fin d'un temps fort.
- Régulateur de rythme : toutes les cinq minutes, ±4 selon la durée d'action visée du niveau
  (borné à ±12).
- Régulateur d'issue (dynamique, après quatre temps forts) : plus de 50 % ont marqué → −6 ;
  moins de 30 % → +6. Il ne lit que les temps forts déjà montrés.
- Résumé, match complet et commentaire seul gardent leur règle (`en_direct_retrospectif`).

## 4. Ouverture et fermeture

- **Ouverture** au premier fait dont l'importance passe le seuil : on remonte au début de
  l'action (lancement, ballon récupéré, coup de sifflet d'un tir au but), au plus l'amorce du
  niveau, jamais au-delà d'un ballon mort ni de plus d'une minute.
- **Fermeture** à la fin naturelle : ballon mort, coup de sifflet, ballon perdu. Une pénalité
  suivie d'un tir au but garde son tir. Une action qui continue à la minute suivante est une
  suite (pas d'entracte). 50 s au plus.

## 5. Vue : 2D qui continue, puis bascule en 3D

- L'entracte 2D déroule tout le jeu terminé sans avoir monté ; il s'arrête au début de l'action
  en cours (même règle `debutAction`). Il ne montre jamais le début d'un temps fort à venir
  (test sur toutes les rafales de trois matchs, trois niveaux).
- Quand le moteur déclenche : si l'entracte minimal (8 s) n'est pas écoulé, le temps fort
  attend (**courte retenue**, déjà en place : le moteur ne simule plus, l'action reste figée à
  son début, rien n'est révélé). Puis, si le terrain 2D n'a pas fini de dérouler ce qui précède
  la borne, la 3D attend encore au plus `BASCULE` = 3 s : la 3D reprend là où la 2D s'arrête.
- Pourquoi pas « attendre la séquence suivante » : ce serait jeter une action jugée importante
  (et c'est impossible pour un essai) ; la période réfractaire rend déjà ces retenues moins
  fréquentes.

## 6. Exemples

- Touche formée à 8 m de la ligne adverse, 3 points d'écart, 65e : 54 + 16 = 70 ; × 1,2 = 84 ;
  seuil dynamique ≈ 62 → le temps fort s'ouvre sur l'alignement formé. Ballon porté, essai ou
  ballon perdu : on le découvre à l'image (test « exemple écrit à la main »).
- Course de 25 m de mon équipe jusqu'aux 30 m adverses : le temps suivant vaut 36 + 20 + 3,
  environ 70 avec la tension → bascule en 3D sur cette action.
- Mêlée au milieu du terrain à 30 points d'écart : 20 × 0,85 ≈ 17 → le match continue en 2D.

## 7. Mesures (200 matchs du harnais, avant → après)

Corpus : 200 journaux du harnais (`tests/harness.cjs`, graine `k × 7919`, club `k mod 10`,
k = 0 à 199), mêmes journaux avant et après. « Avant » : `en_direct` précédent (option
`retrospectif`). Entracte : max(8 s, minutes sautées × 1,5 s) en horloge normale.

| Niveau | | Temps forts / match | Avec point | Sans point | Quarts 0-20 / 20-40 / 40-60 / 60-80 | Action / match | Entracte moyen | Retenus par l'entracte | Essais montrés |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Clés | avant | 13,5 (8–23) | 47,2 % | 52,8 % | 28 / 22 / 21 / 29 % | 131 s | 11,2 s | 65,5 % | 856 / 856 |
| Clés | après | 13,2 (6–22) | 44,9 % | 55,1 % | 26 / 23 / 24 / 27 % | 133 s | 10,8 s | 68,6 % | 856 / 856 |
| Dynamique | avant | 17,5 (8–26) | 33,7 % | 66,3 % | 29 / 23 / 22 / 27 % | 180 s | 9,5 s | 78,2 % | 856 / 856 |
| Dynamique | après | 15,4 (7–24) | 38,5 % | 61,5 % | 28 / 23 / 23 / 26 % | 157 s | 10,0 s | 72,9 % | 856 / 856 |
| Étendus | avant | 22,0 (15–29) | 26,0 % | 74,0 % | 24 / 23 / 25 / 28 % | 216 s | 8,7 s | 86,1 % | 856 / 856 |
| Étendus | après | 22,6 (15–31) | 24,7 % | 75,3 % | 25 / 24 / 26 / 26 % | 216 s | 8,5 s | 88,6 % | 856 / 856 |

Après : 100 % des temps forts déclenchés par l'importance ont leur déclencheur avant ou sur
le dernier fait montré (l'issue) ; épisode le plus long 42 s. Rattrapages (essai sans
importance montée avant) : 18 % des temps forts en dynamique (63 % des essais), 24 % en clés,
6 % en étendus.

**Limite constatée** : dans le journal du moteur, un essai est souvent un seul fait qui part de
20 à 40 m (la course entière) ; le danger n'a donc pas le temps de monter avant lui. Ces essais
restent montrés depuis le début de leur action (le joueur ne voit pas la différence), mais ils
pèsent dans la part « avec point ». Pour aller plus loin : un moteur qui découpe davantage les
courses (hors de ce chantier).

## 8. Vérifications non faites

- Vitesse réelle sur le PC de Léo ; ressenti de la bascule sur plusieurs matchs.
- Réglage fin des poids par Léo (valeurs de départ, non issues d'une source).

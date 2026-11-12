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
| Le chrono défile entre deux temps forts ; pas de pause minimale (décision de Léo : « que le match défile en 2D et qu'on choisisse cette vitesse ») | Plus de pause minimale de 8 s, aucune retenue, plus de « Passer » : le match défile en 2D à l'horloge choisie, le temps fort part dès que le moteur le déclenche, même juste après le précédent. Le manager règle en pause ou en ouvrant Tactique / Banc (pause posée). |
| Des temps forts aléatoires (retour de Léo sur la note : « parfois 2 à la suite, parfois très peu ») | Ni période de calme après un temps fort, ni régulateur de rythme : les temps forts suivent le match (dispersion mesurée au § 7). |

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

- Pas de période de calme ni de régulateur de rythme (prévus dans la note de 16 h, retirés à la
  demande de Léo) : deux temps forts peuvent se suivre si le jeu le justifie, et un match fermé
  peut rester longtemps sans rien.
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
- Quand le moteur déclenche, la 3D part aussitôt au début de l'action (décision de Léo, 12
  novembre 2026, après la note de 16 h) : plus de pause minimale de 8 s, plus de retenue, plus de
  « Passer ». Deux temps forts peuvent s'enchaîner directement si l'action suivante est chaude ;
  s'il ne se passe rien, le match défile en 2D à la vitesse de l'horloge choisie (Paramètres).
- Une suite de la même séquence part sans transition ; une causerie (mi-temps, débrief) attend
  la fin du temps fort, comme avant.

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
`retrospectif`).

Entracte : minutes de jeu sautées × 1,5 s (horloge normale), sans minimum ; « enchaînés » : le
temps fort part à la minute qui suit le précédent, sans minute en 2D.

| Niveau | | Temps forts / match | Avec point | Sans point | Quarts 0-20 / 20-40 / 40-60 / 60-80 | Action / match | Entracte moyen (médiane ; p90) | Enchaînés | Essais montrés |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Clés | avant | 13,5 | 47,2 % | 52,8 % | 28 / 22 / 21 / 29 % | 131 s | 8,0 s (4,5 ; 19,5) | 11,9 % | 856 / 856 |
| Clés | après | 13,6 | 44,6 % | 55,4 % | 26 / 23 / 24 / 27 % | 134 s | 7,2 s (4,5 ; 18) | 12,8 % | 856 / 856 |
| Dynamique | avant | 17,5 | 33,7 % | 66,3 % | 29 / 23 / 22 / 27 % | 180 s | 5,4 s (3 ; 13,5) | 18,5 % | 856 / 856 |
| Dynamique | après | 15,5 | 38,3 % | 61,7 % | 28 / 23 / 23 / 26 % | 156 s | 6,3 s (4,5 ; 15) | 14,5 % | 856 / 856 |
| Étendus | avant | 22,0 | 26,0 % | 74,0 % | 24 / 23 / 25 / 28 % | 216 s | 4,0 s (3 ; 10,5) | 22,8 % | 856 / 856 |
| Étendus | après | 21,5 | 26,2 % | 73,8 % | 27 / 24 / 24 / 25 % | 205 s | 3,9 s (3 ; 9) | 19,9 % | 856 / 856 |

À l'horloge normale (1,5 s par minute), la 2D dure en moyenne 6 s entre deux temps forts en
dynamique ; l'horloge « lente » (3 s par minute) la double. C'est désormais ce réglage, et la
pause, qui donnent au manager le temps d'ajuster.

**Dispersion** (demande de Léo : des temps forts aléatoires). Écart : minutes de jeu entre la
fin d'un temps fort et le début du suivant, dans la même période ; « consécutifs » : écart
d'une minute au plus.

| Niveau | | Temps forts / match : min – médiane – max (p10 – p90) | Écart médian | Écart p10 / p90 / max | Consécutifs |
| --- | --- | --- | --- | --- | --- |
| Clés | avant | 8 – 14 – 23 (10 – 17) | 3 min | 1 / 12 / 31 min | 25,6 % |
| Clés | après | 6 – 13 – 23 (9 – 18) | 3 min | 1 / 11 / 33 min | 22,3 % |
| Dynamique | avant | 8 – 17 – 26 (12 – 23) | 2 min | 1 / 8 / 31 min | 35,3 % |
| Dynamique | après | 8 – 15 – 23 (11 – 20) | 3 min | 1 / 9 / 27 min | 25,1 % |
| Étendus | avant | 15 – 22 – 29 (18 – 26) | 2 min | 0 / 7 / 28 min | 41,0 % |
| Étendus | après | 12 – 22 – 30 (16 – 27) | 2 min | 1 / 6 / 31 min | 33,8 % |

Après : 100 % des temps forts déclenchés par l'importance ont leur déclencheur avant ou sur
le dernier fait montré (l'issue) ; épisode le plus long 41 s. Rattrapages (essai sans
importance montée avant) : 18 % des temps forts en dynamique (62 % des essais), 23 % en clés,
7 % en étendus. Ni la mi-temps ni la fin du match n'entrent dans un temps fort déclenché.
Un temps fort sur quatre en dynamique suit le précédent à une minute au plus ; les longues
périodes sans temps fort dépassent 9 minutes de jeu une fois sur dix.

**Limite constatée** : dans le journal du moteur, un essai est souvent un seul fait qui part de
20 à 40 m (la course entière) ; le danger n'a donc pas le temps de monter avant lui. Ces essais
restent montrés depuis le début de leur action (le joueur ne voit pas la différence), mais ils
pèsent dans la part « avec point ». Pour aller plus loin : un moteur qui découpe davantage les
courses (hors de ce chantier).

## 8. Vérifications non faites

- Vitesse réelle sur le PC de Léo ; ressenti de la bascule sur plusieurs matchs.
- Réglage fin des poids par Léo (valeurs de départ, non issues d'une source).

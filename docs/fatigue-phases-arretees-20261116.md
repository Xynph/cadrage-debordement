# Fatigue des phases arrêtées (16/11/2026)

## Constat

`skill(p,k,true)` appliquait la même fatigue à tous les gestes : compétence × (0,5 + condition × 0,005).
Un buteur à 97 tombait à 54 à condition 11, à 82 à condition 70. Or un coup de pied au but se prépare
(temps de mise en place, aucun effort au moment du tir) : la réussite d'élite est à peu près stable sur
le match, avec au plus une légère baisse en fin de rencontre. Ordre de grandeur réel : environ 70 à 80 %
de réussite au but au plus haut niveau. Une étude sur trois buteurs expérimentés a mesuré une baisse de
précision sous fatigue provoquée, mais sur un protocole bien plus dur qu'un match (Lida, « Effects of
fatigue on rugby place kicking technique and performance »). Le résumé de Quarrie et Hopkins (2015,
« Evaluation of goal kicking performance in international rugby union matches ») n'a pas pu être lu :
la page était bloquée par une vérification du navigateur.

## Règle

Les rencontres créées avec `setPieceFatigueVersion: 1` (posé par `initializeMatchFlow`, interrupteur
`SET_PIECE_FATIGUE_RULES`) multiplient la perte due à la fatigue par `FATIGUE_ARRETE[compétence]`
(`dist/matchflow.js`) :

| Compétence | Poids | Raison |
| --- | --- | --- |
| `goal` (pénalités, transformations, tirs au but des phases finales) | 0,2 | geste préparé, sans effort |
| `lineout` (touche) | 0,5 | lancer sans effort, mais sauteurs et lifteurs dans l'effort |
| autres (plaquage, vitesse, puissance, mêlée, passe, pied d'occupation…) | 1 | jeu courant inchangé |

Ce sont des réglages de jeu, choisis d'après ces ordres de grandeur et non mesurés sur des données réelles.

`fitArrete(l)` rend `'arrete'` pour ces rencontres, `true` sinon. Une rencontre commencée avant garde
donc la fatigue d'origine. Points d'appel : `goalChance`, `chooseScorer` (choix du buteur,
`l` en option), `executePenaltyChoice`, `unit` (dist et la surcharge native de `position-aptitudes.cjs`),
le remplacement du buteur par l'IA (`opposition.js`) et les tirs au but (champ, nationale, japan, srp,
world-knockout). Sauvegarde : `validateFlowState` refuse une autre valeur que 1.

| Condition | 100 | 70 | 50 | 30 | 11 | 0 |
| --- | --- | --- | --- | --- | --- | --- |
| But 97, avant | 97 | 82,5 | 72,8 | 63,1 | 53,8 | 48,5 |
| But 97, après | 97 | 94,1 | 92,1 | 90,2 | 88,4 | 87,3 |

## Mesure (tests/fatigue-phases-arretees.cjs, carrière Monde, 300 matchs IA contre IA)

Probabilité moyenne de réussite au but, minutes 0-19 puis 60-89 : avant 73,1 → 70,7 % (−2,4 points),
après 73,8 → 72,9 % (−0,9). Réussite tirée : 71,4 → 73,9 %. Points par match et touches gagnées
inchangés (écart inférieur à 1 point). La condition moyenne du buteur au moment du tir descend vers
75 : l'IA remplace souvent le buteur fatigué. Le cas signalé (condition 11) concerne surtout un buteur
qui joue les 80 minutes.

Après la fusion de #796/#803 : `goalKicker`, `staffRolePlayer('lanceur')` et `lineoutRoleEdge`
appellent `skill(…,'goal'|'lineout',true)`. Il faudra passer `fitArrete(l)` pour garder un même
classement des buteurs.

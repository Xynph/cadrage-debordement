# V12 — profondeur d'effectif et sensibilité native (expérience isolée)

## Campagne GitHub exécutée le 07/11/2026

Run Actions : https://github.com/Xynph/cadrage-debordement/actions/runs/42320368700 (job native-calibration SUCCESS, artefact rugby-real-v12-depth-calibration). **1 920 matchs natifs** : 64 graines × deux domiciles × cinq scénarios × trois coefficients. Même noyau `createRugbyMatch → advanceRugby → applyMatchInjuries`, mêmes clubs, mêmes joueurs, mêmes IDs de mouvements, feuilles complètes 15+8. `dist/**` et master inchangés. Coefficient de `tacticalEdge` remplacé **uniquement dans le contexte du harness**. Les valeurs sont des réglages de jeu, pas des taux historiques.

| Scénario — victoires de l'équipe citée | coefficient natif actuel 0,004 | candidat 0,008 | test 0,012 |
|---|---:|---:|---:|
| Promu Provence Rugby vs Toulouse | 40,63 % (−4,30 pts) | **21,09 % (−7,77 pts)** | 11,72 % (−12,66 pts) |
| Promu sans recrue vs TOP 14 médian | 29,69 % (−5,34 pts) | **22,66 % (−8,18 pts)** | 16,41 % (−10,53 pts) |
| Promu avec cinq recrues vs TOP 14 médian | 31,25 % (−3,34 pts) | **32,03 % (−4,74 pts)** | 22,66 % (−7,41 pts) |
| Relégué conservé vs PRO D2 médiane | 62,50 % (+5,50 pts) | **75,78 % (+7,94 pts)** | 84,38 % (+11,52 pts) |
| Relégué après cinq départs vs PRO D2 médiane | 65,63 % (+5,47 pts) | **76,56 % (+8,57 pts)** | 84,38 % (+10,41 pts) |

**Recrutement réellement visible :** à 0,008, cinq recrues font gagner **+9,37 points de pourcentage** de victoires et **+3,44 points** de marge moyenne face à l'adversaire médian. À 0,004 : **+1,56 point** de victoire et **+2,00 points** de marge. Les recrues remplacent bien cinq titulaires : la moyenne des 15 titulaires augmente de **+2,67**, la moyenne du banc de **+0,38**.

**Départs toujours mal valorisés :** les cinq titulaires perdus sont automatiquement remplacés, sans déficit numérique. Leur départ abaisse la moyenne des titulaires de seulement **−0,53 point**, celle du banc de **−1,00 point**. Les nouveaux titulaires ont des notes au poste **77, 78, 79, 77, 75**, très proches des cinq joueurs sortants **82, 78, 78, 78, 78**. Le nouveau coefficient seul **ne résout pas** la profondeur : à 0,008, le relégué après départs gagne même 76,56 % contre 75,78 % avant départs ; l'écart de score s'améliore de +0,63. Aucun succès fictif n'est revendiqué.

**Essais/fatigue :** promu contre Toulouse, à 0,004 : 1,80 / 2,38 essais, fatigue 23,61 / 21,71 ; à 0,008 : 1,59 / 2,76 essais, fatigue 23,78 / 21,66. Promu contre médian à 0,008 : 1,57 / 2,91 essais (sans recrue), 1,77 / 2,63 (avec cinq recrues), fatigue 23,46 / 22,70 puis 23,34 / 22,69. Les indicateurs complets (discipline, cartons, blessures, mètres, fatigues, intervalles de victoire) sont dans l'artefact JSON, pas écartés de la mesure.

## Proposition de raccordement à l'intégrateur unique

1. **Raccordement LNR** : `dist/lnr-career.js:lnrGamePlayers` doit lire les 36 attributs V12 puis en dériver les 11 compétences via `review.cjs:project`, sans conserver une projection héritée incohérente. Vérifier explicitement l'échelle entre `ratingV12` (capacité au poste) et `rating/skillBase/dev.potential` historiques : `skill(p,k)` additionne `p.rating-p.skillBase` ; un changement naïf de l'un sans l'autre crée un bonus permanent. Ne pas écraser le potentiel d'origine.
2. **Sensibilité** : en environnement isolé, `tacticalEdge` de `dist/tactical-plans.js` passe de `(attack-defence)*.004` à `*.008` ; les matchs restent natifs. Le coefficient **0,008 est un candidat pour tests d'intégration, pas une valeur validée pour production**. Il rend l'élite plus difficile et les recrutements utiles ; toutefois un relégué conservé devient fort (75,78 %) et le départ de cinq cadres est paradoxal. **0,012 est rejeté comme trop polarisant** sur ces scénarios. Tester davantage de clubs, d'adversaires, de plans tactiques, de fatigue et de conditions avant toute activation.
3. **Profondeur** : revoir dans l'intégration réservée l'écart entre véritables cadres, titulaires, jeunes et rotation ; utiliser les minutes réellement observées quand disponibles pour informer les estimations, sans inventer de minutes ni donner une prime de club. Tester des départs remplacés par des joueurs plus faibles mais poste-compatible ; surveiller séparément le déficit de 15+8 et la baisse des notes des remplaçants. La réalité du recrutement/départ ne se résume pas à cinq IDs retirés : évaluer la saison avec fatigue, blessures, exposition et profondeur.
4. **Âge** : réutiliser les courbes de PR #373 dans la progression existante `dist/development.js`, jamais en parallèle : `ensureDevelopment`, `ageGrowth`, `growPlayer`, `recordDevelopmentMatch`. Initialisation V12 contient déjà la maturité de départ ; pas de double vieillissement, pas de potentiel réécrit, pas de mutation des six traits. Tester import/export, génération LNR, saison 2 et défaut historique des 15 ans isolé dans #373 avant tout raccordement.

**Périmètre réel** : ni les championnats à deux divisions ni les montées/descentes en carrière ne sont simulés ici ; seuls des effectifs contrôlés jouent dans le vrai moteur. Pas de promesse de maintien saisonnier. Aucun changement de moteur de production ni de sauvegarde. Ce rapport conserve les échecs et les incertitudes, y compris les variations dues aux graines.

# CI V2 — mutualisation Chromium Matchday et déduplication Node

## Base et périmètre
Baseline : `main 4308920814f230350809636bf69fa45d7f32c099` après PR #205 ; branche de travail `ci/v2-chromium-consolidation-20261102`.
Les 23 workflows GitHub Actions étaient déjà présents, dont 14 Chromium. Les trois workflows
`matchday-center-browser`, `matchday-lineup-browser` et `matchday-matchplan-browser`
installaient chacun Playwright==1.57.0 et Chromium de façon indépendante.

## Avant / après (structure démontrable, pas un chronométrage)
| Scénario PR | Avant | Après ce lot |
| --- | --- | --- |
| Modification commune `dist/index.html` ou workflow Matchday | 3 jobs Chromium, 3 installations | 1 job, 1 installation, 3 scripts réels |
| Changement d'un test Centre seul | 1 job, 1 installation, 1 script | 1 job, 1 installation, 1 script |
| Changement de Composition | 1 job Composition | 1 job regroupé, Composition + Plan (dépendance couverte) |
| Changement Plan | 1 job Plan + test Node redondant | 1 job regroupé, Plan ; test Node géré par CI principale |
| PR LNR-01 | 2 jobs Node déjà couverts par la CI principale + 1 Chromium | 2 jobs Node `skipped` sur PR, Chromium conservé |
| PR LNR-02 | jobs Node ordinaires et import réel dupliqués + 8 variantes de 4 saisons + Chromium | deux jobs Node `skipped` sur PR ; **8 variantes et Chromium conservés** |

Cela supprime **deux installations Chromium sur trois** (67 %) pour un changement commun,
et retire **jusqu'à quatre jobs Node dupliqués** des campagnes LNR concernées. Ce sont des
comptes structuraux de jobs/installations, pas une baisse mesurée de minutes facturables.
Les jobs marqués `skipped` n'exécutent pas leurs scripts mais apparaissent dans les checks.

## Couverture et sécurité
- Les trois scripts Python sont conservés, sélectionnés explicitement à partir de
  `git diff` du vrai SHA de base PR ; `workflow_dispatch`, diff inexploitable, chemin
  inconnu ou changement transversal => **exécution des trois**.
- Le changement `dist/matchday-lineup.*` exécute Composition **et Plan**,
  car la planification en dépend. Pour un changement `dist/index.html` ou `dist/game.js`,
  les trois scripts sont exécutés.
- Chaque script retourne son statut ; toute erreur fait échouer le job regroupé. La
  suite Node `tests/ci-matchday-browser-selector.cjs` couvre la logique et est aussi
  incluse automatiquement dans `Tests JavaScript`.
- Les anciens workflows restent disponibles en `workflow_dispatch` individuel. Aucune
  suppression de script Python ou Node. Les scénarios LNR-02 paramétrés par mode/graine
  restent distincts et actifs ; leur couverture ne peut pas être remplacée par un test
  avec les paramètres par défaut.
- Aucune modification de `tests.yml`, du release gate, des permissions de fusion,
  des moteurs `dist/`, des sauvegardes, de DATA/Business. Pas de fusion de cette PR sans
  décision explicite.
- **Risque à vérifier avant fusion :** les contrôles obligatoires configurés côté
  GitHub (branch protection/rulesets) ne sont pas exposés par l'API publique non
  authentifiée. Si l'un des noms d'anciens jobs Matchday est requis, il faudra adapter
  les protections côté propriétaire **sans relâcher l'exigence de validation**, ou
  conserver les événements automatiques historiques ; ne pas fusionner tant que
  cette compatibilité n'a pas été vérifiée.
- Les changements de Node 24 vers Node 22 pour la couverture PR LNR sont un écart de
  runtime à surveiller ; les validations spécialisées Node 24 restent accessibles
  manuellement.

## Réception attendue
Exécuter la suite déterministe du sélecteur, vérifier la CI complète `Tests JavaScript`
sur le HEAD exact, puis la CI `Matchday Chromium regroupé` sur le même HEAD. Les
changements portant uniquement sur les workflows LNR doivent ensuite être audités lors
des prochains travaux LNR ; ce lot n'affirme aucun test Windows natif ni une preuve de
réduction chronométrée des facturations.

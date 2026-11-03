# CI — mesure des performances, lot 3

## Mesures reproductibles
Workflow manuel `Audit performances CI — mesure avant apres` : lire deux runs **Tests JavaScript**, exiger 7 jobs terminaux SUCCESS, collecter les durées exactes des jobs et les lignes PASS des logs, calculer le P90 des suites et des shards, le chemin critique et le temps total écoulé. Aucune écriture GitHub, aucune permission de fusion.

Commande locale avec un jeton lecture seule : `GH_TOKEN=... node ci/ci-run-metrics.cjs 41696152014 41700883176`.

**Base observée** : run main #41696152014, 313 s ; après #41700883176, 236 s, soit -77 s (-24,6 %) sur deux runs ; les changements de composition/charges ne permettent pas d'inférer une baisse durable. Les durées agrégées `runnerSeconds` sont des sommes de durées de jobs, **pas les minutes GitHub facturées** (arrondis et runner différents).

## Chromium
Le cache `~/.cache/pip` et `~/.cache/ms-playwright` ajouté par #275 reste en place. Les durées d'installation sont tracées dans le résumé du workflow Chromium, avec preuve `cache-hit`. L'installation et les dépendances système continuent sur chaque exécution ; aucune réception n'est retirée. Comparer run froid et run chaud avant toute affirmation de gain.

## Audit des workflows dits redondants
`ui01-integration.yml`, `ui02-browser.yml`, `ui-native-centers-browser.yml` et `premium-v4.yml` sont déjà limités à `workflow_dispatch`. Les parcours PR/UI sont mutualisés par `ui-browser-consolidated.yml`. Les supprimer ne supprime **aucun run automatique actuel** et ferait disparaître des outils de diagnostic. Aucune suppression effectuée sans preuve des protections et des appels manuels.

## Sécurité et réservations
Aucune modification de `auto-release` #272/#274, de leurs variables, des gates, contrôles requis, DATA/LNR, V62, MATCH 3D, moteur, sauvegardes et fichiers du PRODUCTEUR. Les mesures sont informatives et ne remplacent pas la CI obligatoire 7/7, `/cd-check` puis `/cd-merge` ou CI post-fusion.

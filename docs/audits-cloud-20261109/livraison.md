# Audit de livraison — 9 novembre 2026

Lecture seule : aucune PR modifiée, aucune fusion, aucun message GitHub. Main vérifié : `e2f111a2330462aa6545866441289346ac92f2d0` (#412). Les statuts ci-dessous sont un relevé unique, pas une surveillance.

| PR | HEAD | État technique | CI exacte | Diff réel |
| --- | --- | --- | --- | --- |
| #410 | `40aeb9cf5cac4705bf2bf2354a00648c96e3fe7a` | CLEAN | 7/7 contrôles JS observés réussis | `native/engine/press.cjs`, `tests/world-press-projection.cjs` |
| #413 | `6a587fc7fce3acc0db750205da47e96c46bc2d74` | BEHIND | 7/7 contrôles JS observés réussis | `ci/shard-tests.cjs` |
| #414 | `d61cd3bba3af16352648210c16277f2aa244ceb5` | CLEAN | 7/7 contrôles JS observés réussis | `docs/champ-donnees-depart-2026-27.md`, `native/engine/world-initial-contracts.json`, `tests/world-initial-contracts.cjs` |
| #416 | `616a608a1d46eebb845e43c9a734fea78c17ac28` | BLOCKED | 3/6 contrôles JS observés réussis | `DEVELOPPEMENT.md`, `tests/godot-native06-integration.gd` |

Les quatre PR sont ouvertes et en brouillon. #410, #413 et #414 ont leur workflow Tests JavaScript terminé avec classification + cinq suites + Validation CI réussis (7/7), et leurs deux contrôles annexes réussis. #416 a trois suites encore inachevées au relevé (1/5, 2/5 et 3/5 ; le résultat du gate n'est pas un verdict CI futur). Ne pas présenter #416 comme validée à distance.

## Gates exécutés sans fusion

`node ci/release-gate.cjs 410`, `414`, `416`, chacun avec son `CD_EXPECTED_HEAD_SHA` exact : sortie 1, `ready:false`, raison générique « PR non fusionnable, base invalide ou etat incertain ». Les brouillons suffisent à provoquer ce refus. Le CLI court-circuite sur ce critère : `runUrl:null` ne veut pas dire absence de run. Aucun `--merge` passé.

## Protections serveur établies

Ruleset actif [main-ci-et-pr-obligatoires](https://github.com/Xynph/cadrage-debordement/rules/26326518), ID 26326518, condition `refs/heads/main` : PR obligatoire, suppression et force-push interdits, `Validation CI` de l'intégration GitHub Actions 15368 obligatoire avec branche à jour (`strict_required_status_checks_policy:true`). Zéro approbation humaine obligatoire. `bypass_actors:[]`, `current_user_can_bypass:"never"`. GET des règles effectives de main confirme le même jeu de règles.

L'ancien endpoint `/branches/main/protection` renvoie 403 `Resource not accessible by integration`. On peut attester les rulesets ci-dessus ; pas la totalité d'une éventuelle protection classique cachée. Les droits d'administration n'ont pas été testés par mutation.

## Dépendances et reprises

- **#410 : projection presse uniquement**. Le diff ajoute les noms du registre et les barrages Japon D1/D2 et Pro D2/Nationale. Test ajouté : `tests/world-press-projection.cjs` (démarrage des neuf ligues et invariance export/snapshot ; historique conservé). Compatible avec #414/#416, aucun fichier partagé. Tests de reprise ciblés : ce nouveau test, `tests/native-press-personalities-worker.cjs`, `tests/native-press-followups06-worker.cjs`. Son base SHA exposé par REST est déjà le main actuel.
- **#414 : données de départ Champ**. Trois aliases opaques supplémentaires, un transfert interclubs 113→109, total initial 5 878 actifs pour 5 884 fiches de catalogue. Aucun format de sauvegarde modifié. Tests de reprise : `tests/world-initial-contracts.cjs` et validation explicite d'ancien export/réimport sur fixtures jetables (la preuve de rétrocompatibilité décrite dans la PR vient d'une recette externe ; son ajout n'apparaît pas dans le diff de test). Compatible avec presse et Godot ; réserver ses trois chemins tant que réception non close. Toute future modification de contrats ou effectifs au même fichier requiert intégration préalable ou raccordement.
- **#413 : CI seule**. Ajoute les poids 199/180/159 secondes pour trois suites longues. Base historique `af62a983377e00998e08c43817523f31148c967a`, état BEHIND ; ne pas réutiliser sa CI comme preuve sur main actuel. Créer une branche de raccordement depuis dernier main et appliquer le commit sans réécrire la branche historique. Tests ciblés : `tests/ci-sharding.cjs`, `tests/ci-shard-balancing.cjs`, `tests/ci-shard-profiles.cjs`, puis CI complète exacte. Aucun délai, cinq suites et gate ne doivent être retirés. Compatible fichiers avec les autres lots, mais toutes les intégrations doivent être sérialisées car main avancera.
- **#416 : test Godot + journal**. Ne modifie pas le jeu. Remplace le plafond de 720 px par géométrie réelle aux quatre définitions, 237 contrôles locaux Godot 4.7.2 documentés. Fichiers : `tests/godot-native06-integration.gd`, `DEVELOPPEMENT.md`. Le journal est partagé avec les futures passations : centraliser les nouvelles entrées côté intégrateur ou utiliser docs dédiées disjointes. Réception locale à reprendre avec Node22 et `CD_GODOT_EXECUTABLE=/workspace/.cloud-setup/tools/godot472/Godot_v4.7.2-stable_linux.x86_64`, jamais le Godot4.6.3 par défaut.

## Lots parallèles proposés

1. Producteur EPCR : d'abord audit règles/édition ; tests nouveaux ciblés sous `tests/world-epcr-eligibility.cjs`, module propre `native/engine/epcr-eligibility.cjs` seulement après définition du contrat. Ne pas écrire en même temps dans `worker.cjs`, `world-career.cjs` ou `world-validation.cjs` avec l'autre producteur ; raccordement centralisé.
2. Producteur URC/Pacifique : audit règles et corrections prouvées sous module dédié à chaque compétition, tests `tests/world-urc-shootout-v5.cjs` / tests Super Rugby existants selon défaut trouvé ; réserver exactement les chemins après audit. Le plan ne constitue pas une preuve d'écart.
3. Intégrateur : réception sérialisée des petits lots, CI, tests de combinaison, gate officiel et contrôle post-fusion. Les recherches peuvent avancer pendant CI ; pas de polling actif. Pas d'implémentation de règle de rugby sans source de la saison applicable.

## Limites de cet audit

Aucun test local rejoué : demande d'audit lecture seule. Aucun contenu privé utilisé. Statuts et fichiers reposent sur lectures GitHub et patches complets sauvegardés sous `/workspace/work/pr*-audit.*` ; gates sous `/workspace/work/delivery-gates.json`.

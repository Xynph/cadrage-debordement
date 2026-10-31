# Optimisation du budget GitHub Actions — 31 octobre 2026

## Pourquoi

Le dépôt déclenchait simultanément six workflows sur presque chaque PR (sept pour les travaux UI-05) : `Tests JavaScript` (5 jobs), UI01 (4), économie native (8), carrières longues (4), mobilité V58 (1), observatoire V58 (1), plus éventuellement l'acceptation UI05 (1). Les trois shards natifs UI01 exécutaient `tests/*.cjs` hors harness, déjà couverts par les trois shards du workflow central. Les campagnes sur 15 saisons étaient lancées même pour des composants de présentation sans impact sur les finances ni le moteur.

Une alerte 90 % / 1 800 sur 2 000 minutes a déclenché cet audit. Les *jobs* et les minutes facturées ne sont pas la même métrique : le calcul ci-dessous est une comparaison de déclenchements attendus, pas une économie de minutes déjà observée.

## Invariants de sécurité (inchangés)

- `.github/workflows/tests.yml` **inchangé** : classification, vérification de syntaxe des JS modifiés, trois shards de toutes les suites `tests/*.cjs` hors `harness.cjs`, puis `Validation CI` ; `tests/saves.cjs`, carrières, règles et finances restent couverts sur chaque PR de code et chaque push main.
- `ci/release-gate.cjs` **inchangé** : pour fusionner, exiger une PR ouverte/non brouillon, la tête exacte, `Tests JavaScript` et le job `Validation CI` en succès ; l'intégrateur contrôle les validations spécialisées pertinentes.
- Aucune modification de `dist/**`, `tests/**`, `ci/**`, des données, des sauvegardes, des règles rugby, des paramètres de facturation ni des branches du producteur.
- Les cinq workflows spécialisés conservent `workflow_dispatch` pour lancer explicitement des campagnes complètes, même sans fichier déclencheur modifié.
- Les campagnes et réceptions de PR rendues obsolètes par un nouveau commit s'annulent automatiquement (économie, UI01, observatoire V58 ; carrières, tests centraux et mobilité disposaient déjà de ce mécanisme). Les validations sur `main` ne sont jamais annulées par cette règle.
- Les workflows de carrières longues et de finances gardent leurs **3 scénarios × 15 saisons** et **3 profils × 2 graines × 15 saisons**, respectivement, avec leurs rapports et validations de complétude. Les déclencheurs ciblent les modules de moteur, carrière, finances, sauvegarde et tests de ces campagnes ; la présentation seule n'entraîne plus de campagne.
- Le workflow UI01 conserve sa **réception Chromium réelle** (navigation, contraste, captures), lorsque la navigation, le style, les UI, le jeu ou les tests UI01 changent. Les trois duplications de tous les tests natifs ont été retirées : la preuve native fait autorité dans `Tests JavaScript`.
- La mobilité et l'observatoire V58 ne tournent automatiquement que lorsque leurs modules, leur état de carrière, les sauvegardes ou leurs tests changent.

## Déclenchement attendu (PR vers main)

| Changement représentatif | Tests JavaScript / Validation CI | UI01 Chromium | Carrières 15 saisons | Économie 90 saisons | V58 mobilité / observatoire |
| --- | --- | --- | --- | --- | --- |
| `dist/ui02-player-components.js` seulement | Oui | Oui | Non | Non | Non |
| `dist/style.css` seulement | Oui | Oui | Non | Non | Non |
| `dist/saves.js` | Oui | Non | Oui | Oui | Oui |
| `dist/game.js` | Oui | Oui | Oui | Oui | Oui |
| `dist/economy.js` | Oui | Non | Oui | Oui | Non |
| `tests/economy-audit.cjs` | Oui | Non | Non | Oui | Non |
| `docs/…` seulement | Classification + validation seule (pas de shards) | Non | Non | Non | Non |

Exemple UI-only : avant, 23 jobs (5 + 4 + 4 + 8 + 1 + 1) pouvaient s'exécuter ; maintenant 6 (5 + 1) restent, soit **17 jobs évités / environ 74 %** sur ce scénario. Les durées et minutes facturées réelles dépendent des jobs et de GitHub Actions, et doivent être comparées sur de nouvelles PR. Les modifications du cœur du jeu conservent volontairement les campagnes lourdes.

## Exploitation / limites

1. Ne jamais sélectionner seulement des tests ciblés pour autoriser une fusion : garder le verdict complet `Tests JavaScript` sur le SHA exact et vérifier le `push` post-fusion sur `main`.
2. Les workflows spécialisés sont filtrés par chemins. Une nouvelle fonctionnalité de moteur doit être ajoutée aux listes des campagnes pertinentes lors de son introduction ; lancer entre-temps ces workflows par `workflow_dispatch`. En cas de doute sur l'impact d'un changement, déclencher manuellement les campagnes.
3. Avant fusion, consulter les contrôles réellement déclenchés et leur succès ; une absence de workflow spécialisé est acceptable seulement si ses chemins ne sont pas concernés. Ne pas contourner un statut requis par une règle de protection : celle-ci doit être vérifiée par un administrateur si les contrôles requis ne sont pas accessibles à l'intégration.
4. Les changements dans `dist/match-preparation.js`, même purement visuels, déclenchent par prudence les campagnes de moteur : ce module contient aussi des comportements natifs.
5. La réduction de fréquence ne garantit pas de plafond de coûts. Surveiller les minutes facturées dans GitHub Billing ; aucun réglage de facturation n'est modifié ici.

## Vérifications de ce chantier

- Comparaison des `on.pull_request.paths` et `on.push.paths` des cinq workflows : le workflow central et les contrôles importants de sauvegarde restent intacts.
- Diff de PR et conclusion `Tests JavaScript` / `Validation CI` sur le dernier SHA ; réception Chromium UI01 sur changement de son propre workflow.
- Les campagnes spécialisées complètes de validation de leurs nouveaux YAML peuvent être déclenchées manuellement si GitHub ne les démarre pas automatiquement ; ne pas déclarer ces campagnes vertes sans leur verdict.

## V2 — équilibrage et déduplication (31 octobre 2026)

- Base mesurée : 81 suites uniques sur le workflow post-fusion [Tests JavaScript #41195460951](https://github.com/Xynph/cadrage-debordement/actions/runs/41195460951). Durées des jobs des trois groupes : **78 / 121 / 153 secondes** ; sommation des durées PASS arrondies : 73 / 115 / 146 secondes.
- Nouveau `ci/shard-tests.cjs` : attribution des **toutes les suites** (hors harness) aux trois jobs par équilibrage glouton et ordre lexical déterministe ; 23 suites de 2 s ou plus pondérées par le maximum observé sur deux CI distinctes, les autres et les futures suites à 1 unité conservatrice. Aucun filtrage selon le diff ; `tests/saves.cjs` reste toujours exécuté.
- Sur l'inventaire initial de 81 suites, charges théoriques prudentes équilibrées ~139/139/139 unités, à confronter aux durées réelles post-fusion. **Pas** une mesure de minutes facturées.
- Nouveau `tests/ci-sharding.cjs` : exactitude de couverture, déterminisme, nouvelles suites, sauvegardes, rejets d'entrées incohérentes ; le test est automatiquement compris dans le workflow JS complet.
- `career-resilience.yml` conserve **3 × 15 saisons** et les rapports ; `tests/career-resilience.cjs` est exécuté **une fois**, dans le job de validation finale des carrières, au lieu de 3 fois dans la matrice ; le lancement manuel garde ce test.
- `v58-manager-mobility.yml` garde les vérifications propres à la mobilité à chaque déclenchement. Ses vérifications `tests/saves.cjs` et `tests/ci-selection.cjs` restent disponibles en lancement manuel `workflow_dispatch`, mais ne sont pas répétées sur PR/push où elles sont déjà exécutées par le workflow central.
- `economy-audit.yml` reste **inchangé** : les tests transactionnels spécifiques fournissent les rapports au diagnostic complet et les 6 campagnes × 15 saisons restent obligatoires.
- Avant publication d'une PR, tests ciblés et `node tests/ci-sharding.cjs` / `node tests/ci-selection.cjs` localement ; un seul commit final ; CI de PR **complète** sur HEAD exact, puis `Validation CI`, puis contrôle unique du `push` post-fusion. Pas d'abaissement du gate, pas de modification du format des sauvegardes ni de la facturation.

**Réajustement après première CI de V2 :** la première attribution de 82 suites a bien été exhaustive, mais les durées réelles 72 / 159 / 125 s ont montré une volatilité marquée : `ai-roster-cycle` 59→81 s et `world-career` 66→38 s. Les poids utilisent donc le maximum des mesures des runs #41195460951 et #41196473550. Cette correction est publiée avant la décision de fusion, puis revalidée sur le nouveau SHA de PR ; le gain n'est pas supposé avant ce résultat.

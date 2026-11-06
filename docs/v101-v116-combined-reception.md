# Réception combinée V101–V116 — composition DRAFT (06/11/2026)

## Origine et gouvernance

Cette branche **depuis main** raccorde les trois lots non fusionnés : #325 (V101–V104, Espoirs), #326 (V105–V110, direction sportive), #327 (V111–V116, expérience supporters). Les **neuf fichiers sources module/test/doc sont des copies au blob SHA Git identique** à leurs PR sources ; elles restent DRAFT, non modifiées et non fusionnées. Cette composition ne ferme aucune PR source ni ne remplace sa réservation dans #73. GitHub est la source de vérité ; ne jamais intégrer les trois PR sources *en plus* du lot combiné sans stratégie explicite de déduplication.

## Raccordement

Dans `dist/index.html`, insertion dans cet ordre après les quatre modules V82–V100 et avant les overlays du bureau : `espoirs-coaching-v101-v104.js`, `sporting-director-v105-v110.js`, `fan-experience-v111-v116.js`. Chacun installe ses wrappers de `start`, `render` et `advanceSeason` à son chargement. Les versions V101–V104 apparaissent sous `view==='formation'`, les deux autres sous `view==='bureau'`. Les modules ne modifient ni les lois ni les données des matchs.

Le raccordement **ne modifie pas les sources** : le test combiné protège le choix du gestionnaire de rester sur les branches sources intactes. Les effets économiques V105 et V111 s'appliquent à la trésorerie fictive dans la sauvegarde du club. Il faut vérifier la cohérence de l'expérience d'interface avec les pages actives de `V17`.

## Preuves demandées

- `node tests/v101-v116-combined.cjs` : ordre de sept scripts (quatre dépendances antérieures et trois nouveaux), installation simultanée, panneaux formation/bureau, clics des dix commandes `onclick` sous VM, export/import JSON, sauvegarde refusée et rollback, bilan par saison sur 17 saisons, historique borné.
- `python tests/v101-v116-chromium.py` : navigateur Chromium réel avec scripts chargés depuis `dist/index.html`, rendu des trois panneaux de réception, **10 clics réels Playwright** et contrôle du JSON après clic. Le test utilise une **fixture synthétique isolée** afin de ne pas détourner la carrière existante ; ne prouve pas un parcours complet de carrière en interface.
- `.github/workflows/v101-v116-chromium.yml` : workflow de test indépendant déclenché sur PR, sans aucun accès d'écriture ni commande de gate.
- Suites JavaScript du dépôt et autres workflows obligatoires sur le **HEAD exact de composition**. Corriger tout échec sur cette branche, ne jamais reprendre les résultats d'un SHA précédent.

## Limites de réception et intégration

Les tests synthétiques du module n'ont pas vocation à devenir des recettes officielles, des ventes réelles ou un nouveau calendrier de compétition. Une validation UX de l'écran V17 complet, des éventuels changements de club et du cycle de carrière 2026–2027 réel doit rester explicite avant toute fusion si non prouvée par la CI.

**Aucun merge, aucun bypass, aucune commande /cd-check ou /cd-merge** dans cette phase PRODUCTEUR. Un intégrateur décidera plus tard de l'ordre et de la déduplication des PR #325/#326/#327 et de cette PR de composition. Les réservations MATCH 3D, R&D, DATA/LNR et calendrier sont intactes.

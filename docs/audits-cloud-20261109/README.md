# Reprise des développements parallèles dans Cloud

Audit du 9 novembre 2026, base `e2f111a2330462aa6545866441289346ac92f2d0`. Ce dossier prépare les chantiers ; il ne modifie ni le jeu ni les règles et ne livre pas de nouvelle fonctionnalité jouable. Trois agents ont audité en parallèle EPCR, URC/Pacifique et les petites PR. Aucun message GitHub ni ordre de fusion envoyé.

## Conclusions et accès vérifiés

- GitHub fonctionne via `gh` ; le dépôt et les rulesets main sont lisibles. Voir [réception des PR](livraison.md).
- Firecrawl a réellement lu les sites EPCR, URC et Super Rugby. Cet accès du plugin ne signifie pas que ces domaines sont autorisés directement depuis le shell : le réseau Cloud reste filtré et la seule règle personnalisée est `api.github.com`.
- L’EPCR publie des résumés explicites 2026/27 sur les inscriptions et feuilles. Le jeu n'a pas encore de liste de joueurs inscrits EPCR. Voir [preuves et écarts](epcr.md).
- Les sources URC publiques ne permettent pas de remplacer automatiquement le règlement 2025/26 de référence par un texte consolidé 2026/27. Le détail SRP 2027 doit rester distinct de la référence réglementaire 2026. Voir [audit URC/Pacifique et sources](urc-pacifique.md). Aucun nouvel écart certain n’a été démontré dans ces deux compétitions.
- Ne pas transformer les paramètres estimés du jeu en faits officiels, ni appliquer de nouveaux blocages aux anciennes sauvegardes sans politique explicite.

## Lots et chemins indépendants

| Lot | Résultat attendu | Chemins réservables | Dépendances |
| --- | --- | --- | --- |
| EPCR A | Validateur pur de liste et de feuille, profil 2026/27 et raisons structurées | nouveaux `native/engine/epcr-eligibility.cjs`, `tests/epcr-eligibility.cjs`, `docs/epcr-eligibility-2026-27.md` | sources des §3.1–3.5 ; aucune mutation des sauvegardes |
| URC/Pacifique A | Vérifier chaque règle par édition et protéger les comportements attestés | nouveaux `tests/urc-pacific-rules-boundary.cjs` et `docs/urc-pacific-qualification-20261109.md`, seulement pour combler un manque précis des suites existantes | aucun changement de règle sur seule page sans millésime fiable |
| Livraison | Recevoir #410/#414, raccorder #413 si retenue, vérifier #416 | chemins exacts détaillés dans livraison.md | une seule intégration à la fois, dernier HEAD et CI exacts |
| EPCR B | Inscription jouable, API, liste persistante, IA et écran de gestion | raccordements partagés `worker.cjs`, `world-career.cjs`, `world-model.cjs`, `world-editions.cjs` et UI | EPCR A, modèle d'heure/date, historique contractuel et apparitions, politique d'édition/sauvegarde |
| Effectifs/finances | Mesures sur dix saisons, plusieurs graines et points de reprise | futur banc dédié et rapports anonymisés | d'abord établir les mesures ; aucun coefficient économique modifié par cet audit |

Les producteurs restent sur branches isolées. L’intégrateur prend seul les fichiers partagés, les commandes publiques et les validations de sauvegarde. Les modules et tests indépendants peuvent avancer en parallèle ; les fusions restent sérialisées. `DEVELOPPEMENT.md` n'est pas édité dans ce lot pour éviter son chevauchement avec #416.

## Critères de réception EPCR

EPCR A couvre limites 41/42/43 inscrits, 9/10 premières lignes, 18/19/23/24 sur feuille, doublons, présence sur liste et couverture qualifiée PG/T/PD ; entrées inchangées, saison explicite, information manquante distinguée du refus certain. Un effectif de 23 reste un choix compatible avec la plage réglementaire 19–23.

EPCR B vérifie les deux équipes au vrai coup d'envoi, les refus atomiques, le disque et le RNG inchangés, création, export/import/réouverture, fin de saison et éditions antérieures. Les cinq remplacements en poule ne sont pas cinq ajouts libres. Le contrat de trois mois n'est pas une ancienneté minimale acquise. Le plafond après seconde inscription et les exceptions demandent le handbook complet : ne pas inventer 45 inscrits permanents.

## Tests réellement exécutés par l'intégrateur pendant cet audit

Sous Node **22.23.4**, sur le moteur identique au main de référence :

- `node --test tests/world-epcr-published-2026-27.cjs tests/world-urc-shootout-v5.cjs tests/world-competitions.cjs tests/world-save.cjs` : **38 tests réussis**, aucun échec ni ignoré.
- `node --test tests/srp-world-calendar.cjs tests/world-pacific-registry.cjs` : **3 tests réussis**, aucun échec ni ignoré.

Cela vérifie les comportements couverts, pas la conformité exhaustive des règlements ni dix saisons d'équilibrage. Les tests Godot de #416 ont été reçus séparément : 237 contrôles locaux Linux sous Godot 4.7.2 ; ne pas utiliser le `godot` 4.6.3 par défaut. Windows, pack privé, profils et installation restent sur le poste personnel.

## Ordre de développement

1. Développer EPCR A en parallèle du travail de preuve URC/Pacifique et de la réception des PR existantes.
2. Raccorder EPCR B en un lot jouable cohérent, après résolution des points réglementaires restants et tests de sauvegarde renforcés.
3. Couvrir staff et contrats avec provenance, puis mesurer les dérives de carrière sur dix saisons avant toute calibration.

Ce plan ne programme aucun travail après la fin de la tâche active et n'autorise aucune publication Steam ni transfert de ressources privées. L'effort conseillé pour le développement du validateur EPCR est GPT 6.1 Sol **high** ; le raccordement persistant mérite **xhigh**.

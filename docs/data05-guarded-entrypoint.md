# DATA-05 — point d'entrée gardé du pipeline existant

Commande disponible après intégration de cette PR d'ensemble : `node tools/data05-guarded-entrypoint.cjs`. Ce point d'entrée, regroupé avec le précontrôle #139 sur une branche d'intégration indépendante, **réutilise** `data05-unified.cjs`, `data05-preflight.cjs` (#139), `data05-pipeline.cjs` (#138), `data05-transport.cjs` (#137) et `data05-resilience.cjs` (#134, intégrée). Aucune nouvelle logique de collecte ou nouveau fournisseur.

Avant d'exécuter le pipeline, la validation locale inspecte les 15 JSON DATA-05 déjà présents (exactement 240 identifiants sans doublon), recoupe ID/club/URL avec les 1592 profils DATA-03, puis appelle `validatePlan`. Par défaut limite = 0, budget = 0 : import hors ligne uniquement. Sans les dépendances, échec explicite (fail closed). Aucun accès externe n'a été autorisé ni effectué dans cette PR.

Une collecte future exige simultanément `--limit N --ack-lnr-access --authorized-http` et **une vérification externe effective et préalable des permissions et restrictions LNR**. Ces options ne constituent pas à elles seules une permission. Firecrawl est impossible sans budget positif et clé ; les tentatives et non les crédits facturés sont plafonnées. Aucune clé n'est fournie à budget nul.

Tests dédiés : `node --test tests/data05-guarded-entrypoint.cjs`. Import réel du corpus déjà intégré : `node --test tests/lnr05-real-import.cjs` (tests du collecteur unifié, 240/240, zéro réseau). Cette dernière commande doit être relancée sur un checkout réunissant les dépendances. CI sur HEAD de cette PR à contrôler, et la CI ne constitue pas une autorisation de pilote HTTP.

**Ordre :** intégrer séparément #137, #138, #139 après contrôles puis rebaser et tester la présente PR ; aucune fusion automatique. Sauvegardes historiques et `dist/**` intacts ; pas de preuve d'effectifs historiques au 01/07/2026.

Le précontrôle et le pipeline unifié exigent tous deux la concurrence **strictement égale à 1** ; un lancement à 2 est rejeté avant exécution, y compris par le point d'entrée. Le mode import hors ligne ne permet aucun budget payant positif.

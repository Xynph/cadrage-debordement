# V86–V89 — Suivi durable des jeunes (lot complementaire)

## Périmètre
- **V86 :** fixer à un joueur un objectif de 80 à 2 400 minutes Espoirs, contrôler l'écart aux minutes enregistrées par V73, détecter retard, impossibilité ou objectif atteint.
- **V87 :** liste des titulaires professionnels et des trois meilleurs jeunes successeurs par poste, avec alertes de poste vacant, manque de profondeur et retraite à anticiper à partir de 32 ans.
- **V88 :** comparaison des clubs professionnels d'accueil pour un prêt V78 ; estimation déterministe du temps de jeu en fonction de la concurrence au poste et du niveau du joueur. Aucune sélection garantie et aucune mutation automatique d'effectif.
- **V89 :** chronologie individuelle issue des promotions V77, des prêts V78 et des événements suivis explicitement, avec un historique borné.

## Architecture et compatibilité
Module autonome `dist/espoirs-followup-v86-v89.js` avec API `CDEspoirsFollowupV86V89`. État optionnel `s.v86to89`, version 1, sans transformation de l'ancien schéma ; créations d'objectifs et d'événements atomiques avec rollback si la sauvegarde échoue. Historique limité à cinq saisons, événements limités à 150, validation au chargement.

**Le module est publié mais non inclus dans `dist/index.html`** : ce fichier est réservé à la branche parallèle V82–V85. Après sa libération, l'intégrateur devra ajouter le script après V82–V85 pour activer l'interface de formation et les wrappers. L'API de lecture reste accessible sans cela dans les tests Node. Les destinations de prêt sont des estimations, pas des engagements contractuels.

## Tests
`node tests/v86-v89-espoirs-followup.cjs` : alertes, objectifs, succession, classement des prêts, chronologie, rollback et ancien état de sauvegarde. Compléter par CI complète GitHub, test Chromium, sauvegarde/import et saisons longues **après raccordement**.

## Hors périmètre
MATCH 3D #300, R&D #315, DATA/LNR, calendrier LNR, moteur sportif, gates, finances et schémas centraux de sauvegarde. Aucune fusion par PRODUCTEUR.

# MATCHDAY-02 — Assistant de composition jouable

En tête du menu **Préparation**, sous MATCHDAY-01 : sélection comparative de 15 titulaires et 8 remplaçants.

## Fonctionnement
Trois approches indicatives : **Équilibrée** (fonction native \`buildSheet\`), **Fraîcheur** (condition et charge priorisées) et **Performance** (note au poste priorisée). Les deux dernières ordonnent les préférences par rareté et utilisent ensuite \`buildSheet(club(),preferred,preferredBench)\` pour les réparations natives. Les contraintes effectives de poste et de banc restent \`slotEligible\` et \`benchEligible\`.

Aucun affichage ni changement d'onglet n'enregistre un état ; une comparaison montre pour chaque place l'ancien et le nouveau joueur, ainsi que les indices de condition et de charge. Une empreinte du contexte et de l'effectif est vérifiée lors du clic **Appliquer cette composition** ; tout changement invalide l'aperçu. La validation vérifie 15 + 8, unicité, blessures, postes et banc avant **une seule** mise à jour de \`S.lineup\`, \`S.reserves\`, suivie d'un seul \`save()\`.

Une composition incomplète reste non applicable ; aucune promotion, nouvelle fiche de joueur ou simulation parallèle. En match ou en saison achevée, commande bloquée. Les scores de stratégies sont des heuristiques de jeu et ne garantissent pas de résultat sportif.

## Compatibilité et validations
Aucun nouveau champ de sauvegarde, \`dist/saves.js\` et \`dist/rugby.js\` inchangés. Les fichiers DATA-03/04/05 du producteur Business sont exclus.
Tests : \`node tests/matchday-lineup.cjs\` (23 places, 3 modes, mutations, éligibilité, sauvegardes, verrou de match et d'ancien aperçu), puis \`python tests/matchday-lineup-browser.py\` en Chromium Linux à 1280/768/390/320 px.
Les cas de joueurs polyvalents et les restrictions de première ligne reposent sur les gardes **déjà présents** dans le moteur \`fr-pro-2025\` ; ce lot ne change aucune loi du rugby. Aucune certification Windows native.

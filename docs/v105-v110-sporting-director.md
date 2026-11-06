# V105–V110 — Direction sportive, lot groupé en attente d'intégration

**V105** : priorité annuelle (performance, stabilité, finances, effectif), mesurée à la revue de fin de saison. **V106** : affectation de quatre missions distinctes aux services sportif, physique, recrutement et administratif ; une mission par service et par saison. **V107** : investissements fictifs vidéo/médical/logistique, déduits de la trésorerie du club, persistants et comptés dans le score de direction à clôture. **V108** : registre de quatre risques, mesures préventives facultatives et coût fictif borné. **V109** : indicateurs en lecture seule, notamment joueurs disponibles, condition et trésorerie, sans déformer le moteur de match. **V110** : compte rendu annuel noté de 0 à 100, confiance de la direction, archive bornée à 12 saisons.

Ces versions sont **distinctes de V101–V104**, centrées sur les Espoirs. La présente PR ne touche pas les fichiers de #325.

## Périmètre, migration et limites

Nouveau module optionnel `dist/sporting-director-v105-v110.js` dans son propre espace `v105to110`, sans changement de sauvegarde centrale. Anciennes carrières sans état V105 restent compatibles via initialisation à la demande. Les états présents invalides sont refusés, jamais écrasés silencieusement. Transactions avec rollback pour tout coût et rapport annuel ; déductions fictives uniquement sur `clubs[club].cash`. Aucun effet caché sur l'efficacité des joueurs, blessures, tactiques ou résultat de match.

Les projets sont facturés une seule fois ; les missions sont limitées par saison ; aucun nouveau scénario n'utilise de noms, clubs ou calendriers réels. L'interface est préparée sous `install(window)` et le panneau conditionnel du bureau, mais **`dist/index.html` n'est volontairement pas modifié** : pas d'activation dans le jeu tant que la réception intégrée et Chromium PC ne sont pas faits.

Test ajouté : `node tests/v105-v110-sporting-director.cjs` (choix, dépenses, rollback, sauvegardes anciennes, 17 saisons, contrôles adaptateurs). Réception CI sur HEAD exact requise. DRAFT uniquement, aucune fusion, gate ou bypass ; MATCH 3D, R&D, DATA/LNR et calendrier exclus.

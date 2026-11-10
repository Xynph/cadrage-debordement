# Potentiel évolutif — plan de réalisation

**But :** le plafond réel peut évoluer selon les opportunités, les performances, le travail et la personnalité ; il ne garantit jamais le niveau atteint.

**Architecture :** factory native autonome, hooks sur entraînement, fin de match et vieillissement annuel. État optionnel compact, validé avant import, données publiques limitées à un bilan qualitatif pour notre club. Le potentiel source de référence reste intact ; le plafond global `dev.potential` est réévalué.

**Choix de réalisation :** bilan annuel plutôt que hausse après chaque match, +1 en général et +2 exceptionnellement chez les moins de22 ans ; plafond dynamique net −4/+8 depuis activation, toujours ≤99 et ≥niveau actuel. Une stagnation prolongée peut réduire le plafond de1 ; une blessure ou un manque d’opportunités seuls ne le réduisent pas. Professionnalisme, ambition et adaptabilité influencent les chances, jamais une garantie. Les choix chiffrés sont ceux du développeur, ouverts à l’équilibrage.

**Signaux disponibles :** semaines réelles d’entraînement et charge/condition ; minutes effectives et résultat ajusté à la force adverse ; contributions individuelles seulement quand un acteur structuré est enregistré, sans inventer des actions pour les autres joueurs. Les mêmes calculs concernent les clubs AI, avec les faits de match disponibles.

**Compatibilité :** les anciennes carrières démarrent leur suivi au premier événement réel, sans reconstitution ni nouveau tirage initial. Lecture/export/reprise n’ajoutent rien. Revue annuelle idempotente et sans consommation RNG. La connaissance étrangère reste gelée jusqu’à une nouvelle observation, toujours en fourchette.

## Tâches

- [ ] Factory `native/engine/potential-evolution.cjs`, tests purs des contextes, personnalités, stagnation, bornes, idempotence et absence RNG.
- [ ] Hooks worker et harness, validation stricte et budget dédié limité dans `dist/saves.js`, sans augmenter les plafonds UTF8.
- [ ] Tests réels entraînement/match/import/reprise et refus atomiques, y compris ancienne carrière et IA.
- [ ] Bilan qualitatif propre dans le modèle et infobulles de potentiel ; aucun plafond exact révélé.
- [ ] Réception graphique1440, tests ciblés puis revue indépendante ; documentation et PR empilée sur536.

## Points de contrôle

Pas de gain automatique pour tout jeune ; aucune influence des seules consultations ; pas d’avantage réservé au club humain ; pas de seconde récompense après import ; pas d’augmentation actuelle du niveau lors d’une révision de plafond ; pas de régression liée aux blessures seules ; source et traits inchangés ; fourchettes toujours de5 valeurs pour notre club et l’observation approfondie.

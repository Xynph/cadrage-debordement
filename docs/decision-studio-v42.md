# V4.2 — Studio de décisions du manager

**Branche de revue non fusionnée.** Base GitHub `main d11906751b1f44346d2b5a5230610690020e1c4a`, après V4.1 complète. Coordination et réservations : issue #73.

## Cinq nouvelles expériences métier, pas une simple palette

| Vue | Nouveau parcours visible | Source native et limites |
| --- | --- | --- |
| Bureau | **Centre de décisions** en quatre axes, avec accès directs : prochain match, disponibilité, classement et trésorerie | Snapshot natif déjà disponible. Chaque action ouvre l'écran correspondant, sans automatiser une décision |
| Préparation | **Lecture des conditions du XV** avec moyenne calculée et trois plages de condition, tableau de données accessible | Conditions enregistrées des titulaires sélectionnés, aucune inférence médicale ni changement de composition |
| Finances | **Variations hebdomadaires** en barres divergentes et tableau de solde semaine par semaine | Différences entre points successifs du modèle financier fictif, pas des transactions passées ni des résultats garantis |
| Formation | **Écarts actuel/plafond** des espoirs, huit premiers profils mis en perspective par une visualisation double ; tableau complet | Attributs natifs sur copies ; ordre décroissant d'écart et plafond non garanti |
| Recrutement | **Synthèse des coûts publics** : profils exploitables, prime minimale, salaire médian hebdomadaire et nombre de primes nulles | Exclusivement `price` et `salary` des profils déjà publics ; aucune note ou aptitude cachée |

Les graphiques V4/V4.1 existants restent conservés. L'écran championnat et les fiches joueur gardent leurs compositions de la V4.1 ; le bureau introduit des accès directs vers ces vues, sans les réécrire.

## Contrats de sûreté

- Module de présentation `dist/art-direction-v4.js`, styles `dist/art-direction-v4.css` ; aucun changement à `dist/game.js`, moteurs, sauvegardes, transactions ou DATA-06.
- Les nouvelles vues calculent depuis `snapshot()` / états de lecture de l'équipe et utilisent de simples copies/filtrages. L'API exporte des fonctions pures et n'écrit jamais une sauvegarde.
- États vides explicites, plafonds non garantis, monnaie fictive, listes et tableaux de valeurs accessibles.
- Boutons de pilotage natifs avec destination claire ; aucun réseau ni donnée artificielle à l'exécution.
- Les couleurs forêt/cuivre, l'affiche sportive et le ballon légèrement boueux du menu sont conservés. Compositions responsives et bordures de focus maintenues.

## Validation attendue

Suite dédiée `tests/decision-studio-v42.cjs` : plages de condition, variation positive/négative, absence de données, classement des écarts de formation, filtrage des coûts publics, liens du bureau et absence de mutation. Les suites existantes de Node, V4 Premium Chromium et CI finale sur la tête exacte de la PR restent obligatoires. Aucun test de lecture d'écran NVDA/VoiceOver ou de navigateur Windows/Safari/Firefox n'est annoncé. Aucune capture Playwright n'est revendiquée sans exécution réelle.

**Différencier :** les tests déjà publiés dans V4/V4.1, les tests lancés dans cette intervention, les CI distantes et les contrôles non exécutés. Aucune fusion sans autorisation explicite.

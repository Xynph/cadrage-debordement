# V58.2 — Consolidation des contrats d'entraîneurs

Nouvel adaptateur autonome `dist/coach-contract-cycle.js` au-dessus de V58 (`coach-career.js`) et V58.1 (`coach-negotiations.js`).

Fonctions : `audit` (unicité du contrat actif et bornes des contrats), `transition` (expiration des offres et fins de contrat en fin de période, idempotentes), `negotiate` (contre-offre plafonnée, acceptée ou refusée), `sign` (signature avec vérification d'expiration), `dismiss`, `resign`, `apply`. Les fonctions renvoient des **copies**, ne changent ni les sauvegardes ni les effectifs du jeu.

Dépendances d'intégration : PR #60 puis PR #61, puis cette PR. Ne pas fusionner directement les snapshots de branches empilées ; l'intégrateur doit reprendre les fichiers complémentaires au-dessus du `main` pertinent.

**Limites à traiter avant toute activation :** les montants représentent des unités abstraites de salaire, pas des versements annuels réels. Aucun lien au ledger du club ; démission/rupture sans indemnité ; mise à jour d'un statut de candidature non répercutée aux offres ; pas de fenêtre d'emploi selon compétition ; pas de migration de sauvegarde réelle. L'expiration d'un contrat se produit quand `season >= until`, ce qui doit correspondre au calendrier du jeu.

Les 11 tests V58.2 vérifient expiration, idempotence, négociations, refus, licenciements, démissions, double emploi, intégrité contractuelle, 15 saisons déterministes et reprise JSON. La CI rejoue aussi les 10 tests V58 et les 10 tests V58.1.

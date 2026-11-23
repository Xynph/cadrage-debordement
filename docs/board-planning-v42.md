# V42 — Direction et sponsoring : moteur de règles fictives

Module isolé, sans intégration UI ni sauvegarde : `dist/board-planning.js`.

- **Objectifs** : mesure transparente de l'atteinte d'un seuil minimal ou maximal.
- **Confiance de la direction** : score explicable selon résultats (55 %), finances (30 %) et jeunes (15 %), avec lissage de 70 % de la confiance précédente (réglages par défaut de `boardConfidence`). Carrière intégrée (22/11/2026) : bilan tous les 3 matchs, résultats 70 % (taux de victoires), finances 20 %, formation 10 %, le bilan tire la confiance aux 7/10 vers la note (±15 au plus). Les coefficients sont fictifs.
- **Sponsoring** : rémunération fixe, prime à la signature, primes par victoire et classement, sans encaissement implicite.
- **Pas d'effet caché** sur l'effectif, les matchs ou la carrière. Les montants et critères doivent être reliés explicitement par un futur écran de gestion.
- Tests ciblés : `node tests/board-planning.cjs`.

Ce module ne change aucune loi de rugby ni n'ajoute de données financières réelles. Conflits V40 évités par création exclusive de nouveaux fichiers.

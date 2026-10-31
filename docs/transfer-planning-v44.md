# V44 — Planification du recrutement

Module autonome et sans effet de bord : `dist/transfer-planning.js`.

- `transferCost` : indemnité, prime de signature, commission et salaire sur une durée explicite.
- `affordability` : teste indépendamment la trésorerie, l'enveloppe de transferts et la marge salariale.
- `rankCandidates` : comparaison déterministe de candidats selon coût projeté et note de jeu, avec pondérations configurables.
- Modèle fictif : l'échelle financière et les notes sont les données de l'appelant ; ne pas interpréter comme salaires, valeurs ou prix du rugby réel.
- Aucune mutation, aucune transaction, aucune modification du match, de l'interface ou de sauvegardes.
- Exécution : `node tests/transfer-planning.cjs`.

**À intégrer ultérieurement** : utiliser les budgets et profils réels de la carrière simulée avec vérification des unités. Les coefficients de classement sont arbitraires.

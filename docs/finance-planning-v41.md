# V41 — Projection financière (module indépendant)

Ce module ajoute un calculateur déterministe de trésorerie **fictive**, sans toucher au moteur de match, à l'interface V40 ou aux sauvegardes.

- `CDFinancePlanning.forecast({...})` : calcule jusqu'à 104 semaines, le solde par semaine, le solde final, la première semaine déficitaire et le ratio salaires/recettes.
- `CDFinancePlanning.compare(base, scenarios)` : compare jusqu'à 12 scénarios de recettes, masse salariale et frais ponctuels à une trajectoire de référence.
- Les données proviennent de l'appelant : le module **ne lit ni ne modifie automatiquement** l'état de carrière.
- Aucune donnée réelle de budget ou d'effectif n'est introduite.

**Limite de cette PR** : moteur de projection et tests seulement. Une future intégration à un écran financier devra attendre la coordination avec V40 et reprendre les unités financières exactes de l'économie existante.

Exécuter les vérifications ciblées avec `node tests/finance-planning.cjs` et `node --check dist/finance-planning.js`.

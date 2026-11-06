# Économie V2 — E2.1 : traçage natif des variations de trésorerie

**R&D uniquement, empilée sur PR #338 et #337, aucun chargement dans `dist/index.html`.** Pas de changement au moteur, à l'IA, au gameplay, aux règles de compétition ni aux sauvegardes.

## Méthode

- Le test appelle réellement `N.fresh`, `finishRound`, `advanceSeason`, `N.verified` et `N.reload` dans le VM natif.
- Pendant chaque appel seulement, les propriétés `cash` des 14 clubs sont observées par des descripteurs configurables ; chaque écriture changeant la valeur enregistre son delta, son club et son site de pile JavaScript. Le descripteur de donnée original est ensuite restauré avant la vérification ou l'export de sauvegarde.
- **Invariant bloquant :** pour chaque club et chaque étape, la somme des deltas interceptés doit égaler `cash_after - cash_before`. Si une écriture échappe au traceur (objet remplacé, mutation non instrumentée, valeur anormale), échec explicite, jamais allocation d'un reliquat artificiel.
- Les écritures sont de vraies mutations du moteur, même lors des intersaisons ; aucune compensation, ajustement salarial, aide financière, pseudo-facture ou crédit nouveau.
- Chaque site est conservé comme **provenance technique** exacte du JS exécuté. Il ne prouve pas à lui seul le **motif économique** d'une écriture ; sa catégorie métier doit être auditée séparément avant rapprochement E2.2. Un transfert entre deux clubs peut produire plusieurs écritures : pas de déduction automatique de causalité entre lignes.

## Campagnes et artefacts

3 profils de clubs × 2 graines, quinze saisons et vingt-neuf tours par saison ; trois imports natifs par campagne. Les fichiers JSON incluent les vrais cash de chaque fin de saison, la distribution des écritures par site et le nombre d'écritures non attribuées et d'écarts de conservation. Ne pas annoncer de résultat CI sans validation terminale sur le HEAD exact.

## Cockpit consultatif préparé

Utiliser les soldes réels de `seasonSeries` pour un graphique de trésorerie par saison et la fréquence des mouvements classés par site comme **traces techniques** distinctes du journal de comptes. Les rubriques revenus, charges, dette, salaires, engagements et investissements restent **non certifiées** pour les clubs IA tant que les mutations ne sont pas catégorisées par leur source métier. Interdire des courbes mensuelles déduites des tours ou un « résultat comptable IA » fabriqué.

## Sécurité du test

Le traceur est un outil de test seulement ; il restaure les descripteurs avant tout `N.verified` / import. Aucune donnée supplémentaire n'est persistée. Les tests natifs peuvent identifier une variation de cash mais pas rendre des événements historiquement absents du jeu. Une couverture de 100 % des **deltas mesurés** ne signifie donc pas 100 % de reconnaissance des **recettes et charges**.

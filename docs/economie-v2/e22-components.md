# E2.2 — décomposition des écritures financières natives (audit)

**Statut DRAFT non connecté** : branche empilée sur #339, #338, #337 ; aucune modification de `dist/` ni des sauvegardes, aucun gate ni fusion.

## Sources natives auditées

- `worldWeeklyEconomy` : contrat de base +160 000€, salaires du club IA, billetterie domicile fictive +360 000€, prime de victoire +80 000€, entretien calculé par `worldUpkeep`. Le match réellement archivé dans `S.worldManagement.matches` détermine domicile et victoire ; le salaire et le niveau d'entretien viennent de la capture native d'avant tour.
- `aiRosterContracts` : indemnité de renouvellement payée, charge de cash.
- `aiRosterRecruitmentWeek` : indemnité de recrutement, charge de cash.
- `worldNewSeason` : trésorerie négative convertie en dette explicite ; allocation 2 500 000€, remboursement nominal selon `CDFinancialRecovery.annual` ; achats d'installations distincts. Les intérêts de 4% font évoluer la dette, pas directement le cash.
- Écritures du manager : rapprochement une à une avec le journal `S.ledger` du tour, sans deviner le cash ; les catégories déduites du libellé sont **des étiquettes legacy**, pas une comptabilité certifiée au sens strict.
- Toute source inconnue reste `unknown` : pas de catégorie inventée. La somme des composantes d'une écriture doit être égale à son delta natif, et la somme des écritures doit être égale au delta total de trésorerie.

## Qualification

Six campagnes de 15 saisons, 29 tours par saison et trois imports/campagne. Le workflow dédié exécute tests unitaires, parité native sans observer / avec observateur, et la matrice 6×15 ; une CI non terminale n'est jamais VERT. Toutes les écritures non catégorisées sont explicitement quantifiées ; une conservation de cash à 100% n'implique pas certification de 100% des catégories métier ou des balances non liquides.

## Cockpit PC (préparation, aucun écran ajouté)

Les objets `years` fournissent des séries issues du vrai moteur : trésorerie et dette à l'ouverture et à la clôture de chaque saison, et une ventilation de **flux de cash de la saison**. La dette est un solde observé, pas un résultat économique. Ne jamais afficher `cashComponents.revenue` comme « chiffre d'affaires comptable certifié » : c'est un encaissement du modèle fictif. Les données non classées doivent être clairement signalées, avec une note méthodologique. Aucun mois fictif : les tours de championnat ne sont pas des mois.

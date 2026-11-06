# Économie V2 — interface PC premium et contrat visuel (E0)

> Spécification, non réalisée. Conserver l'architecture PC actuelle et le cockpit plein écran, sans scroll global ni modale permanente ; ajouter des sous-vues par navigation native et scroll local dans les tableaux seulement. Aucun écran intégré au jeu dans ce lot.

## Intention joueur

La finance doit raconter : « Pourquoi ai-je gagné/perdu cet argent ? », « Que pourrai-je engager sans risquer la crise ? », « Quelle décision renforce mon projet sportif ? » et « Que font mes adversaires ? ». Les graphiques doivent être utiles à une décision, pas seulement décoratifs. Toutes les valeurs fictionnelles sont étiquetées « € fictifs », règles et date de simulation disponibles par infobulle.

## Navigation PC cible

Bureau > Finances :
1. **Tableau de bord** : situation et alertes ;
2. **Revenus & charges** : activité par mois, saison, catégorie ;
3. **Trésorerie & engagements** : cash projeté et paiements déjà signés ;
4. **Salaires & marché** : masse salariale, plafond financier, salary cap réglementaire, expirations ;
5. **Sponsors & stade** : contrats, abonnements, affluence, politique de prix, projet stade ;
6. **Investissements & dette** : coûts complets, ROI incertain, prêts, échéances ;
7. **Régulation & conseil** : rapports, risques, mesures, décisions ;
8. **Comparatif Ligue** : distributions / tendances des 14 clubs, avec données visibles selon règles de connaissance du manager.

Le sous-onglet Finances doit exister sans casser les 17 sous-pages historiques, 1920x1080 et 1440x900. Aucun scroll de document global. Support clavier, focus, contraste, tableaux accessibles.

## Wireframe illustratif (données fictives de démonstration)

+--------------------------------------------------------------------------------------+
| BUREAU / FINANCES                       Saison 2028-29      [Mon club] [Comparateur] |
| Tableau de bord | Revenus | Cash | Salaires | Sponsors | Dette | Régulation | Ligue |
+--------------------------------------------------------------------------------------+
| CASH : 4,8 M€  | RÉSULTAT : -0,8 M€ | CASH PRÉVU : 2,1 M€ | SALAIRES : 9,2 / 11 M€ |
| [Alerte : deux contrats arrivent à échéance / projection sous seuil prudent]        |
+-------------------------------------------+------------------------------------------+
| Courbe : Cash réel + prévisions 36 mois     | Revenus vs dépenses : 12 derniers mois   |
| historique trait plein, scénarios pointillés| barres empilées, détail au survol         |
+-------------------------------------------+------------------------------------------+
| Répartition revenus (légende+table accessible) | Salaire / CA, dette / CA, fonds propres |
+-------------------------------------------+------------------------------------------+
| Décisions du conseil : négocier sponsor, différer stade, prolonger joueur           |
+--------------------------------------------------------------------------------------+

### Catalogue des composants visuels

| Vue | Visuel | Interaction | Justification |
|---|---|---|---|
| Résumé | 4 KPI avec delta N-1 et infobulle | période/club | garder cash, résultat, engagements et paie distincts |
| Cash | courbe historique et éventail 3/12/36 mois | survol point, clic événement, central/prudent/stress | éviter les promesses de projection certaine |
| Flux | barres empilées produits/charges, drilldown | période 1/3/12 mois, catégorie | montrer prix, volume, coûts variables et chocs |
| Revenus | donut avec table de valeurs et pourcentages | filtre clubs, liens sponsor/stade | comprendre diversification et dépendance |
| Salaires | barre plafond légal vs budget autorisé vs engagé | poste, statut, contrat, évolution | cap sportif ≠ budget financier |
| Contrats | tableau filtrable salaire annuel/coût restant/prime/échéance | tri, comparaison et action | coût total plutôt que seul salaire actuel |
| Stade | jauge capacité / occupation + graphe demande-prix | proposition de prix puis confirmation | arbitrage recette vs fidélité |
| Dette | échéancier principal/intérêts et reste à payer | examen d'emprunt, alerte de covenant | dette n'est pas un « déficit » |
| Ligue | nuage salaires/points, histogrammes cash, boîte à moustaches selon données | groupes, année, club, filtres | repérer riches inefficaces et challengers |
| Board | scénario et arbitrages, liste de décisions justifiées | confirmer, refuser, demander révision | lien causal action -> budget -> équipe |
| Régulation | indicateurs de conformité et calendrier des contrôles | détails par règle datée | aucune sanction mystérieuse |

Ne jamais encoder l'unique signification par la couleur : valeur texte, signe, motif, axe et tooltips. Les résultats historiques sont des données réalisées ; les projections doivent être visuellement distinctes et porter leur hypothèse.

## Langage graphique et animations

- Continuité avec le PC premium actuel : surfaces sombres, accents de couleurs sobres, chiffres tabulaires, très forte lisibilité 1080p/900p.
- Comparaison N-1 avec flèche + valeur ; un produit qui diminue n'est pas toujours « mauvais » et une dépense qui augmente n'est pas toujours « mauvaise ».
- Graphiques SVG/Canvas locaux sans appels payants, accessibles en tableau parallèle ; pas de graphes raster d'une capture factice.
- Modales d'action seulement pour un vrai arbitrage, sous-onglets stables, filtres mémorisés au niveau UI sans affecter save métier.
- Performances : 14 clubs x 15 saisons, 180 points mensuels par club et au plus 3 horizons de projection ; agrégations mises en cache par (saveVersion, season, month, club, filters), calculées hors rendu.
- 1440x900 : cartes KPI compactées, graphes deux colonnes sans débordement, tableau en zone scrollable interne. Contrôles clavier et lecteur d'écran.

## Contrats des données UI

FinancesSnapshot : clubId, fiscalYear, month, balanceCash, operatingRevenue, operatingExpense, operatingResult, interest, debtPrincipal, liabilities, equity, salaryExpenseFull, salaryCapEligible, salaryCapLimit, committedWages, boardWageBudget, transferBudget, liquidityReserve, dataProfileVersion.

CashSeries : {month, actualCash, central?, low?, high?, assumptions, lastReconciledEvent}. Observations exactes ; projection min/max accompagnée des hypothèses, jamais garanties.

IncomeStatementRow : {category, amount, period, counterpartyType, contractId?, cashStatus, recognitionMethod, eventId}; même catégorie pour UI et rapport auditeur, sans « non classé » permanent.

ClubComparator : {clubId, fiscalYear, revenue, payrollRatio, debtRatio, operatingMargin, cashRunwayMonths, availableDataLabel}; si donnée non observable, afficher « non disponible » plutôt que l'inventer.

RegulationStatus : {edition, capLimit, eligibleCommitted, exceptions, nextReview, warnings, sanctions, reportLink}, avec règles versionnées.

## Exemples d'actions lisibles

- « Renouveler le demi d'ouverture » : coût 3 ans, nouvelle paie, effet budget restant, alerte de conformité, statut de conseil ; confirmation obligatoire.
- « Rénover 1 000 sièges » : investissement, coût annuel d'entretien, apport éventuel, capacité, affluence attendue avec incertitude, date de mise en service ; pas de gain immédiat sans demande.
- « Négocier sponsor » : offres alternatives, durée, pénalités, conditions sportives, trésorerie mensuelle, probabilité/risque explicite.
- « Refuser soutien actionnaire » : coûts de dette ou scénario de redressement visibles, sans suppression silencieuse du passif.

## Preuves UX exigées avant mise en production

- Captures Chromium réelles 1920x1080 et 1440x900 pour tous les sous-onglets (normal, déficit, dette, après quinze saisons).
- Vérifier clics onglets, filtres, tri, tooltips, clavier, affichage tableaux et courbes ; aucun scroll global, aucun overflow, aucun élément hors écran.
- Vérifier que les chiffres du graphe sont EXACTEMENT les mêmes que les valeurs du ledger/contrat et qu'une sauvegarde importée restitue les graphiques.
- Stress tests 14 clubs, historique 15 saisons, données manquantes, valeurs négatives, longues dénominations, zéro revenus, cash extrême.
- Deux captures de comparaison avant/après pour toute évolution majeure, et éventuel essai utilisateur : « peux-tu identifier pourquoi le club est déficitaire et la meilleure action ? ».

## UX jeu, et non logiciel de comptabilité : divulgation progressive

**Écran d'accueil Finances, mode accompagné :** 3 réponses prioritaires seulement, visibles sans scroll : « Combien puis-je engager ? », « Est-ce que je vais manquer d'argent ? », « Qu'est-ce qui a changé ? ». Afficher d'abord budget recrutement, solde de saison prévu et statut (sain / vigilance / pression). Cash, dettes et comptes détaillés restent accessibles par clic. Le joueur doit pouvoir retourner à sa tactique ou son match en une action.

### Carte d'arbitrage intuitive

Exemple purement illustratif : **Signer un troisième-ligne** → « 180 k€/an pendant 2 ans ; laisse 0,6 M€ de marge annuelle ; limite les travaux de stade à l'été suivant ; conseil favorable ». Sous « Voir le détail », déplier charges sociales estimées, prime de signature, salaire cap éligible, engagements et scénarios.

Les suggestions du directeur financier doivent être produites par les **mêmes calculs** que les simulateurs et le budget ; aucune carte rassurante si les contrats imposent une crise de trésorerie.

### Mode de consultation

| Accompagné | Manager | Expert |
|---|---|---|
| 3 KPI et 1 conseil prioritaire | 4-6 KPI et scénarios | reporting complet + variations |
| opérations administratives déléguées | choix hebdomadaires optionnels | choix détaillés |
| alertes pédagogiques avec remèdes | avertissements contextualisés | conformité et engagements contractuels |
| aucun micromanagement obligatoire | commande sur demande | instruments complets |

Le moteur financier est le même dans les trois modes. Changer de mode est réversible et ne crée aucune monnaie ni ne supprime des coûts.

### Éviter les écrans décourageants

- Ne pas présenter « 12 000 000 € de dette » comme un échec automatique : montrer échéances, intérêts, capacité de remboursement et marge disponible.
- Fournir un bouton « Recommandation du directeur financier » qui propose un plan viable (avec coûts et hypothèses), jamais un bouton qui ajoute des fonds.
- Les événements positifs sont aussi narrés : sponsor renouvelé, guichets fermés, promotion d'un espoir économe, prêt remboursé, réserve reconstruite.
- Les sanctions et crises ne surgissent pas sans avertissement et horizon de correction, sauf scénario de défi explicite ou événement imprévisible bien expliqué.
- Conserver un rythme de jeu fluide : interventions majeures mensuelles, synthèses intermédiaires, pas de popup finance à chaque match.
- Les graphiques détaillés et tableaux comparatifs enrichissent la profondeur mais ne deviennent pas une condition pour avancer la saison.

### Critères de validation UX supplémentaires

- Un testeur en mode accompagné explique la différence entre « argent disponible » et « argent en banque » après une explication contextuelle.
- Il peut signer un joueur et comprendre immédiatement le coût annuel et l'impact sur sa capacité de recrutement.
- Pas plus d'une alerte financière prioritaire non demandée dans une séquence de match, et aucune modalité bloquante lors d'un match en direct.
- La vue avancée conserve toutes les tables et graphes, sans les cacher aux joueurs qui aiment optimiser.

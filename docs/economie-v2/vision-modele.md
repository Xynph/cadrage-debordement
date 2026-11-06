# Économie V2 — vision produit et modèle économique (E0, 06/11/2026)

> Statut : DESIGN / NON INTÉGRÉ. Sources publiques 2024/25, redistribution 2025/26 et règlement 2026/27 ; le simulateur actuel a un profil rugby fr-pro-2025. Ne pas réécrire ses règles sportives ou appliquer rétroactivement une réglementation récente. Tous les euros du mode fiction sont **fictifs**. Aucun coefficient de ce document n'est déjà exécuté.

## Décision de conception

Remplacer une économie à flux constants par quatre systèmes reliés : marché sportif et public, compte d'exploitation, financement/bilan, décisions du conseil et de l'IA. Ne **jamais** régler le solde d'un club par une subvention résiduelle destinée à atteindre un montant cible. Le modèle doit générer des gagnants, perdants, investisseurs, crises, redressements et effets sportifs persistants. Calibration sur distributions réelles plutôt que sur une trésorerie absolue.

## Constat mesuré

Run de référence GitHub Actions #42233255733 sur PR #333, HEAD c2b9ff20 : 25/25 jobs, 24 campagnes, 360 saisons, 67 320 matchs, 72 imports. Témoin : 1 568,99 M€ de cash final cumulés pour 14 clubs ; masse salariale finale 1,391 M€ par période ; qualité finale 70,36. Variante B : 611,47 M€, salaires 3,046 M€, qualité 70,42 ; cette amélioration est contre-factuelle car un plancher salarial modifie artificiellement la VM. **Ne pas intégrer A/B/C comme économie de production.**

Faits LNR/A2R exercice 2024/25 : TOP 14 464,1 M€ de produits d'exploitation, résultat d'exploitation -49,8 M€ ; TOP 14 74,8 M€ recettes de matchs, 206,9 M€ partenariats, 88,1 M€ versements LNR ; charges salariales et sociales 54 % des charges d'exploitation. Ces statistiques agrégées ne sont ni des budgets-clubs individuels ni des objectifs comptables exacts à imposer. La redistribution 2025/26 repose sur solidarité, mérite et incitations formation/stade ; la somme distribuée n'est pas une « injection magique ». Voir sources-reference.md.

## 1. Calendrier et conventions

1. Conserver les 29 tours *sportifs* historiques ; ajouter une horloge financière indépendante : 12 périodes comptables et 52 semaines de paie/contrats par exercice, avec mapping explicite des dates simulées et calendrier de trésorerie. Jusqu'à migration qualifiée, profil LEGACY_29 conserve les anciens prélèvements par tour, sans double débit.
2. Définir exercice, saisons sportives, bornes de contrats, versements mensuels/trimestriels, hors-saison et phases finales. Les 52 semaines ne signifient pas ajouter des 52 « journées » au moteur de rugby.
3. Trois couches : résultat (produits/charges), cashflow (encaissements/décaissements), bilan simplifié (dette, fonds propres, créances et engagements). Différence cash ≠ profit et apport actionnaire ≠ chiffre d'affaires.
4. Unité en euros entiers; opérations idempotentes par (season, month, clubId, eventId). Tout paiement est contrepartie d'une créance, d'une charge ou d'un transfert vérifiable. Reconciliation agrégée et club par club.
5. Modes : fiction native (coefficients plausibles calibrés sans données privées), dataset réel optionnel opt-in, legacy migré de manière déterministe. Pas de mélange silencieux ; sauvegarde native versionnée avec plan de migration et export/import testés.

## 2. Recettes endogènes

| Flux | Principaux facteurs | Déclencheur | Gardes |
|---|---|---|---|
| Abonnements | base de supporters, capacité, prix, fidélité, réputation, résultats N-1 | saison | pas plus que capacité |
| Billets | demande, prix, stade, qualité adversaire, calendrier, accessibilité, dynamique sportive | domicile | spectateurs <= capacité ; pas de billetterie domicile fictive terrain neutre |
| Hospitalités | places premium, affluence entreprises, prix, partenaires | match | capacités et contrats |
| Sponsors | audience, territoire, marque, durée, activation, résultats, stabilité | mensuel + renégociation | contrat daté, clause, risque de non-renouvellement |
| Merchandising | fanbase, vedettes, résultats, stock/canaux | mensuel | coûts variables associés |
| Droits / distribution | enveloppe ligue, solidarité, mérite, formation/stade, compétitions accessibles | calendrier ligue | somme reçue = somme distribuée ; règles versionnées |
| Primes sportives | classement, coupe, qualification, résultats | événement | financement ligue contractuel, pas double crédit |
| Mutations | indemnité de transfert, primes, clauses, prêts | signature/échéances | virement traçable, amortissement/engagement contractuel |
| Autres revenus | locations, événements non-sportifs du stade, projets locaux | calendrier | capacité et coûts associés |

Illustration (à calibrer) : attendance = clamp(capacity * supporterDemand(reputation, population, form, opponent, kickoff, price, fanLoyalty), 0, capacity). Revenue = paidAttendance * effectiveTicketPrice + VIP + concessions. La demande décroît avec prix mais l'élasticité dépend du club. Une victoire **ne verse pas directement 80 k€** sans contrat ou distribution.

Les phases finales en terrain neutre sont organisées par la ligue : billetterie et coûts sont imputés au compte de l'organisateur, puis rétrocession éventuelle aux clubs via une règle de compétition explicite. Les compétitions/promotions non modélisées restent exclues et signalées, jamais inventées.

## 3. Dépenses et engagements

Joueurs (fixes, charges employeur, variables, primes, blessures et jokers), staff sportif/administratif, formation/espoirs, médical/réathlétisation, déplacements/logistique, entretien stade, amortissement / investissement, prospection et médias, dette/intérêts, frais d'organisation, fiscalité simplifiée explicitement fictive. Séparer charge P&L de sortie de cash, et mensualiser les engagements. Coût d'investissement au moment de l'achat, bénéfice sportif étalé, coût de maintenance récurrent.

Éviter la double charge salaires lors d'un passage de calendrier LEGACY_29 à V2_52 ; frais de staff et sociaux ne sont pas inclus dans le salary cap sportif si les règles pertinentes l'excluent.

## 4. Marché salarial et transferts dynamiques

La paie n'est plus « salaire_initial × coefficient fixé » ; le prix d'un joueur est issu de sa rareté poste/niveau, réputation, âge, historique, performance, rôle, longueur de contrat, offre des clubs, alternatives, ambition et risque d'emploi. Demande agent et capacité d'acceptation du club sont deux côtés indépendants.
- Joueur : demander un salaire cohérent avec ses alternatives, refuser une baisse illogique dans un club enrichi, préférer projet sportif/temps de jeu, pouvoir accepter compromis pour des raisons explicites.
- Conseil : fixer plafond de paie réellement finançable selon revenus récurrents, charges, cash minimum, dettes et risque ; maximum légal du cap calculé séparément.
- IA : conserver cadres utiles, proposer prolongations à temps, recruter selon besoins/compétition, promouvoir espoirs quand logique, arbitrer entre jouer court et investir.
- Contrats : valeur annuelle et à courir, indemnités, primes conditionnelles, clauses, charges, renouvellement ; pas de progression salariale universelle forcée.

Attention : le règlement TOP 14 2026/27 annonce 11 M€ de plafond principal et crédits internationaux ; le mode fr-pro-2025 doit conserver son régime historique jusqu'à mise en place explicite d'un profile réglementaire daté et source documentée. Ne pas confondre salaire hebdomadaire des seules simulations, masse salariale sportive réglementée et coût salarial complet.

## 5. IA des clubs (agents à budget et stratégie)

Chaque club reçoit une identité stable : territoire/fanbase, richesse actionnariale, réputation, patience conseil, préférence formation, ambition sportive, risque accepté, niveau infrastructures, politique de prix, profil de sponsor. Traits déterministes et reproductibles par graine.

Boucle mensuelle :
1. Prévoir à 3, 12 et 36 mois : cash et résultat dans scénario central, prudent et stress.
2. Définir les réserves de liquidité nécessaires pour engagements déjà signés, et l'enveloppe encore engagable.
3. Estimer l'écart sportif entre effectif actuel et objectif, puis classer les interventions par valeur marginale / risque : prolonger, acheter, promouvoir, staff, formation, stade, vendre, attendre.
4. Approuver les décisions en tenant compte de restrictions, du coût total sur la durée, du risque sportif, des finances, du salary cap.
5. Après événement sportif, résultat financier ou choc de marché, réévaluer au prochain cycle ; une dégradation peut conduire à vente, gel de primes, recherche de sponsors, négociation actionnaire, remboursement ou restructuration.
6. Comptabiliser et raconter les motifs de chaque décision (pour UI, replays, audits).

**Pas de règle « cash > 5 M€ => dépenser X » ni salaire plancher uniforme.** L'IA qui ne dépense pas peut être correcte si elle a un projet prudent ; une ligue entière qui thésaurise indéfiniment est un échec.

## 6. Gouvernance, actionnaires et dette

| Objet | Règle |
|---|---|
| Résultat | produits d'exploitation - charges d'exploitation - éléments financiers |
| Trésorerie | cash initial + encaissements - décaissements, indépendamment du résultat comptable |
| Budget | droit de dépenser approuvé par le conseil, contraint par prévision et engagements |
| Dette | contrat de financement avec nominal, échéances, intérêts et covenants simplifiés |
| Capital | injection exceptionnelle de l'actionnaire + variation des fonds propres, séparée du chiffre d'affaires |
| Déficit | peut être couvert par capital, dette, réserves ou réduction des coûts, mais pas effacé |
| Redressement | plan daté et objectifs mesurables, vérification aux échéances |
| Régulateur | contrôle d'attestation préalable, avertissement/restriction/sanction graduée selon profil et décision |

L'aide actionnaire n'est **ni automatique ni certaine** : probabilité/volonté liée à stratégie, capacité, historique et besoin, mais décision stable et auditable, jamais hasard non reproductible. Un mécène peut sortir ; les clubs dépendants subissent alors un risque majeur.

## 7. Régulation versionnée

Créer une couche de règles de finances indépendante de la simulation sportive. Salary cap sportif, crédits internationaux et exceptions datées, contrôle financier de solvabilité, dates de dépôt, sanctions graduées, traitement des dettes et des budgets futurs. Référence 2025/26 pour le mode existant, 2026/27 pour profil nouveau seulement après lecture de la réglementation en vigueur et tests dédiés. Aucune sanction rétroactive silencieuse des sauvegardes.

## 8. Cas limites indispensables

- 3 saisons sans qualification, hausse/baisse du remplissage et sponsors ;
- champion jeune et riche versus champion endetté, actions différentes ;
- trois blessures majeures, remplacement joker et plafond réglementaire cohérent ;
- perte du sponsor principal et actionnaire qui refuse ;
- stade saturé mais investissement non finançable ;
- saison déficitaire malgré bonne affluence, gestion de la paie et de la dette ;
- club promu/relégué uniquement si le moteur de compétition prend réellement en charge ces mouvements ; autrement fixture de test R&D identifiée comme hypothétique ;
- concurrence réelle pour un demi d'ouverture rare et renégociation dynamique ;
- 15 ans de renégociations IA sans effondrement de la qualité sportive ;
- import d'une carrière legacy avec 29 tours payés, zéro double charge ou perte du cash.

## 9. Non-objectifs du premier déploiement

Pas de comptabilité fiscale exhaustive, pas de simulation bancaire réglementaire, pas de collecte payante de comptes privés, pas de valeurs de clubs réels présentées comme factuelles sans provenance, pas de dynamique d'inflation visant un chiffre final arbitraire. L'impact sur les lois de rugby et le calendrier sportif est hors périmètre.

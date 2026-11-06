# E2.4 — engagements observables et cockpit de qualité des preuves

Statut **R&D DRAFT** empilé sur PR #342. Aucun usage dans le jeu : ne charge ni la bibliothèque de test ni la page HTML dans dist/index.html.

## Trois classes de données à ne pas mélanger

1. **Terme présent au registre natif** : `S.clubs[].players[].salary` est un taux de rémunération par semaine ; `contractEnd` est l'année de fin indiquée. Ces valeurs attestent d'un état de jeu et d'un terme enregistré, pas de la naissance d'un compte fournisseur exigible ni d'un traitement juridique de contrat réel. L'identifiant du joueur et son club propriétaire sont uniques dans les effectifs observés.
2. **Prévision volontairement illustrative** : `weeklyWage × 29` est un budget théorique *à effectif et salaires inchangés*, **ni engagement certain ni passif**, et ne sert jamais à modifier `cash`. La durée des saisons, les transferts et les signatures réelles ne sont pas présumés fixes.
3. **Information indisponible** : montants des salaires garantis restants, primes à payer, fournisseurs, clauses de rupture et comptes de charges à payer non reconstructibles avec exhaustivité. Ils restent `null`, affichés « Non disponible », jamais zéro.

Offre du marché (`S.economy.offers`) et négociation (`S.economy.talks`) ne valent pas signature : seule `confirmContract` change réellement la paie et l'échéance; seul `acceptSale` déclenche réellement le flux interclubs. Les propositions ne sont pas valorisées en dette.

## Contrôles sportifs et financiers

- Le test contrôlé réalise une **vraie vente acceptée** via `acceptSale` sur une carrière native isolée ; vérifie débit du club acheteur, crédit du vendeur, solde total conservé et propriétaire unique du joueur. Ce n'est pas une vente naturelle issue des 90 saisons : distinction explicite.
- Les changements de propriétaires et d'effectifs dans les six campagnes sont observés sans prix inféré si le registre d'origine ne permet pas d'attribuer le prix individuellement.
- Rejouer 3 profils × 2 graines × 15 saisons, 29 tours/saison et trois imports natifs/campagne ; audit dette et conservation hérités de #342 et test de parité sauvegarde/témoin. Les 14 clubs sont vérifiés avec taux salariaux et échéances exacts, aucun passif fabriqué.
- Un choc dette et déficit est testé dans E2.3 ; pas de crise naturelle revendiquée si les campagnes n'en comportent pas.

## Cockpit PC — vrai prototype hors jeu

La page autonome E2.4 reprend le tableau de bord E2.3 et ajoute les termes observés, les contrats arrivant à échéance, un **budget prévisionnel clairement étiqueté** et « Non disponible » pour les dettes non enregistrées. Quinze saisons de données natives, un sélecteur de quatorze clubs, zéro donnée mensuelle fabriquée. Chromium 1920×1080 et 1440×900 exécute deux captures et vérifie filtres, tableau, graphiques et absence de débordement.

**Limite d'acceptation :** une CI verte prouve la cohérence des états observés, pas l'exhaustivité d'un passif comptable absent du jeu. Les captures automatiques ne sont pas une inspection humaine détaillée.

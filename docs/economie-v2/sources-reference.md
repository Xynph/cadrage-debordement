# Économie V2 — sources, dates, limites d'utilisation (E0)

Consultation des sources officielles publiques le 06/11/2026. Le mode de simulation courant reste `fr-pro-2025`; **ne pas appliquer rétroactivement** les changements règlementaires 2026/27. Les données de jeu en fiction sont inventées, pas les comptes des clubs réels.

## Rugby français : sources primaires

1. LNR / A2R, **rapport publié 16/04/2026 portant sur 2024/25** :
   https://www.lnr.fr/actualite/economie-des-clubs-des-revenus-records-des-equilibres-a-renforcer
   https://www.lnr.fr/documentation/rapports-dnacg
   - Total 30 clubs : produits d'exploitation 635 M€ ; perte d'exploitation cumulée -63,7 M€.
   - TOP 14 : produits 464,1 M€, perte d'exploitation -49,8 M€, recettes matchs 74,8 M€, partenariats 206,9 M€, versements LNR 88,1 M€.
   - La part spectateurs/partenaires/merchandising est de 66 % des produits pour les 30 clubs ; la redistribution LNR représente environ 20 %. Les agrégats ne doivent jamais être imposés identiquement à chaque club fictif.
   - Retenir la distinction ***résultat d'exploitation déficitaire ≠ trésorerie nécessairement négative*** : la couverture par capitaux propres, dette ou apport du propriétaire change le bilan mais ne crée pas de revenu commercial.

2. LNR, **redistribution saison 2025/26**, publiée après l'AG du 8 juillet 2026 :
   https://top14.lnr.fr/actualite/solidarite-merite-investissement-1265-meur-redistribues-aux-clubs-a-lissue-de-la-saison-20252026
   - 126,5 M€ redistribués nets aux clubs ; principes : socle égalitaire/solidarité, mérite sportif, formation/JIFF et infrastructures, contribution internationaux.
   - Clé inter-divisions 70 % TOP 14 / 30 % PRO D2 ; socle moyen TOP 14 3,2 M€, PRO D2 1,4 M€, variables conditionnelles.
   - Ne pas ajouter des droits TV aux clubs puis les redistribuer une seconde fois. Le modèle doit comptabiliser l'enveloppe de ligue et ses contreparties.

3. TOP 14 / LNR, **réforme Salary Cap 2026/27** :
   https://top14.lnr.fr/actualite/salary-cap-evolution-2026-2027
   - Plafond principal fixé à 11 M€ en 2026/27, trajectoire vers 11,3 M€ en 2029/30. Crédits liés aux internationaux et cas spécifiques à versionner selon l'édition.
   - Un plafond règlementaire autorise un maximum, mais **ne finance pas automatiquement le budget du club**.

4. TOP 14 / LNR, **publication des plafonds par club 2026/27** :
   https://top14.lnr.fr/actualite/salary-cap-la-lnr-publie-pour-la-premiere-fois-le-plafond-applicable-a-chaque-club-de-top-14
   - Variations par crédits internationaux et conditions d'éligibilité. Ne pas coder des crédits à partir d'une simple réputation.

## Benchmark de jeu de gestion

5. Sports Interactive, manuel de **Football Manager 2024** — finances :
   https://community.sports-interactive.com/sigames-manual/football-manager-2024/finances-r4964/
   - Écrans produit/charges, salaires, dette, sponsors, projections 3 saisons, conformité et ajustements de budgets par le board.
   - Les écrans de chiffres existent pour rendre les décisions compréhensibles ; ne pas recopier les règles de football dans un simulateur de rugby.

6. Sports Interactive, présentation de la logique financière et sportive introduite pour FM24 :
   https://www.footballmanager.com/fr/features/finances-constructions-deffectif-et-transferts-plus-affutes
   - Recrutement IA sensible aux besoins et potentiel, budgets pouvant devenir négatifs, interventions de direction, sanctions, droits TV, sponsors et billetterie dynamiques.
   - Ce sont des principes de conception, pas des coefficients publics reproductibles.

## Contraintes et non-objectifs de données

- Ne pas scraper de bases de contrats, comptes privés ou effectifs non redistribuables. Pas de service payant.
- Pour chaque chiffre réel : indiquer saison/exercice/périmètre (TOP14, PRO D2 ou 30 clubs), agrégat ou par club, source primaire et date.
- Aucun modèle produit ne doit prétendre être « validé par la LNR ».
- Faire cohabiter le choix joueur (économie fictionnelle accessible) et les règles de ligue vérifiées lorsque la saison et le championnat sont explicitement sélectionnés.
- Toute extrapolation (ex. ratios de masse salariale ou coûts fixes) doit être étiquetée « hypothèse à calibrer » avec intervalle, pas « règle officielle ».

## État du cycle

E0 est documentaire. Le banc expérimental PR #333, run GitHub 42233255733, a 25/25 jobs réussis, 360 saisons testées ; le résultat B est contrefactuel avec plancher salarial VM, pas une économie de production. Aucune modification du moteur ni du gameplay issue d'E0.

# Économie V2 E3.3 — contrats de preuve des investissements sportifs facultatifs

**Périmètre :** R&D isolée, aucun code de gameplay modifié et aucune liaison aux sauvegardes utilisateur. PR empilée sur #354, tous les modules E1–E3.2 inchangés.

## Audit des deux actions natives

### Installations — `dist/world-career.js`

L'action `worldUpgradeFacility()` est un choix volontaire du club piloté, pendant `phase=league`, hors match, avant l'entraînement, une fois maximum par saison. `worldFacilityQuote()` produit un **devis instantané conditionnel** basé sur le niveau en vigueur : coût direct `450000+150000×niveau` (euros fictifs), réserve fictive de 500 000 et contrôle d'une projection de douze semaines d'entretien. Le devis **ne crée aucune facture ni décision automatique**. Si l'action est réellement exécutée, une ligne de registre `Investissement dans les installations du club` débite immédiatement le club, le niveau augmente, `worldManagement.upgrades` enregistre seulement **saison**, club, nouveau niveau et coût, sans date civile ou échéance. L'historique des travaux est limité à 30 événements ; il n'est pas exhaustif.

Le code de `worldFacilityTraining()` ajoute à l'entrée de progression hebdomadaire des jeunes de 22 ans ou moins et non blessés un facteur `max(0,niveau-2)×0,012×ageGrowth`. C'est une **règle métier vérifiable**, pas une garantie de gain de note, de score de match, de revenus ou de temps de jeu. L'entretien hebdomadaire d'un niveau supérieur à 2 est appliqué dans l'économie native, mais ne peut être transformé en engagements futurs signés dans E3.3.

### Formation — `dist/career-integration.js`

`careerSetAcademyInvestment(amount)` accepte **0, 4 000, 12 000** euros fictifs par semaine lorsque la gestion intégrée est activée, hors match et avant l'entraînement. Ce choix est un **niveau de dépense**, pas une dette accumulée. `careerAcademyTraining()` prélève seulement si la trésorerie couvre la somme, au plus une fois par période native `season:economy.week`, puis met à jour `academySpent`, `academyWeeks` et le registre `Investissement formation`. Sans argent, la séance n'est pas payée et aucun débit ne se crée. Les progrès des espoirs reçoivent les entrées `0,055×ageGrowth` pour 4 000 et `0,15×ageGrowth` pour 12 000 ; aucun résultat sportif chiffré ne peut être garanti sans simulation appariée.

Les valeurs `academySpent` et `academyWeeks` couvrent la saison courante et sont réinitialisées à la saison suivante. `S.ledger` est borné aux 100 derniers mouvements. Les champs `lastAcademyWeek` enregistrent une période, **pas une facture datée**.

## Contrat et interface

`ci/economy-v2-e33-investments.cjs` lit sur un état natif réel la période, le club piloté, les modules actifs, le devis d'installations, les investissements réalisés dans la limite de l'historique, la dépense formation courante et les écritures actuellement visibles. Aucun relevé ne tente de compléter les périodes manquantes. Le contrat conserve `futureScheduledInvestment=null`, `confirmedFutureRevenue=null` et `accruedLiability=null`. Même chose pour les effets sportifs futurs `measuredFutureSportResult=null`.

L'écran HTML E3.3 montre un **état ponctuel natif**, distinct des quinze saisons natives E3.2 et des quatre **scénarios SYNTHÉTIQUES E3.1**. Une action non exécutée n'y apparaît jamais comme un paiement. Aucune comparaison avant/après de niveau sportif n'est revendiquée.

## Qualification

Tests Node : source native, non-mutation de la carrière observée et parité état/checksum, devis et débit d'installations réellement actionnés **sur une copie de test**, sélection hebdomadaire et débit formation **sur une autre copie**, puis contrôle de l'original intact. Six campagnes trois profils × deux graines × quinze saisons, vérification E3.2 et compatibilité des sauvegardes. Deux captures Chromium réelles 1920×1080 et 1440×900, interactions et contrôle de débordement/erreurs. **Ces validations ne deviennent garanties que si le run final du HEAD exact est SUCCESS.**

## Limites et prochaine décision

L'absence d'une date complète, d'un calendrier de recettes futures confirmées et de la mesure contrefactuelle du développement interdit encore un simulateur natif de redressement. L'autorité anti-rollback offline E2.9 ne reçoit aucun ajout. Garder le cockpit consultatif et toute PR DRAFT ; pas de READY, gate, fusion ni raccord gameplay.

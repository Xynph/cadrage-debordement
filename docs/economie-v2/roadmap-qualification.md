# Économie V2 — roadmap et protocole de qualification (E0)

Statut : projet de cycle, PAS de correctif intégré. Source de vérité GitHub. Les PR de ce plan sont indicatives ; leurs numéros réels ne sont attribués qu'à la création. Toutes les réservations seront revérifiées avant chaque implémentation ; les chemins ci-dessous ne sont pas réservés par E0.

## Règles d'exécution

- Branches isolées, petits commits, contrôle main/AGENTS.md/#73 et conflits avant chaque PR. Une seule fusion à la fois, gate officiel strict, pas de bypass.
- Ne pas modifier PR #333 (diagnostic de 360 saisons), ni les chemins de MATCH 3D/R&D, DATA/LNR, V117–V123, #332 ou réservations de l'autre compte sans coordination.
- Aucun remplacement du moteur par une imitation pure : validations contre le vrai start/finishRound/advanceSeason, sources native et vraies sauvegardes. Migrations versionnées, rollback et compatibilité anciennes carrières.
- Toutes les nouvelles fonctions métier doivent avoir tests unitaires purs, puis tests intégration natifs et Chromium réels si UI. Aucune CI en cours n'est « verte ».
- Les valeurs réelles servent de distribution et de cohérence, jamais d'exact salaire d'un club fictif ; réglementation date/profile vérifiés.

## Séquence de lots / PR indépendantes

| Lot | Priorité | Objet | Dépendances | Sortie vérifiable |
|---|---|---|---|---|
| E0 | maintenant | benchmark officiel, modèle conceptuel, UX et protocole (ces 4 docs) | aucune | PR DRAFT documentaire, revue humaine des hypothèses |
| E1 | P0 | calendrier financier, modèle comptable événements, double entrée simplifiée et invariants purs | E0 | fonctions isolées sans branchement jeu, tests conservation cash/créances |
| E2 | P0 | couche adaptatrice LEGACY_29 / V2_52, migrations et portefeuille de sauvegardes | E1 | import V16 et carrières actuelles, absence double paie, rollback |
| E3 | P0 | revenus endogènes stade/public/sponsor/merchandising + coûts associés | E1/E2 | matchs domicile/extérieur/terrain neutre réconciliés, scénarios demande |
| E4 | P0 | redistribution ligue en enveloppe fermée, calendrier et règles datées | E1/E2/E3 | somme clubs = enveloppe ligue, 3 leviers transparents |
| E5 | P0 | dépenses récurrentes staff, médical, déplacements, formation, infrastructure | E1/E2 | charges mensuelles, investissements sans trésorerie magique |
| E6 | P0 | salaires négociés et marché concurrentiel, contrats et primes | E1/E2/E5 | 15 saisons sans paie forcée ni fuite du talent |
| E7 | P0 | conseil et profils IA, budgets et arbitrages annuels/trimestriels | E3/E4/E5/E6 | décisions traçables et contre-factuels reproductibles |
| E8 | P1 | dette, actionnaire, solvabilité, régulation datée et redressements | E1/E2/E7 | cas stress, embargo défendable et rémission calculée |
| E9 | P1 | cockpit PC Finances, huit sous-vues, graphes et interactions | E1 à E8 selon vues | Chromium 2 résolutions, exactitude des valeurs et actions |
| E10 | P0 transverse | validation long terme, benchmark distributions, recherche de paramètres et compatibilité | tous incrémentalement | 6 graines x 3 profils x 15 saisons ; stress et KPI ligue |
| E11 | P1 | contrôles finaux performance/offline/anciens saves et documentation des limites | E9/E10 | VERT validé sans régression ni manipulation du gate |

E1 à E11 = futurs lots, NON entrepris dans E0. Ne pas précipiter E9 : une courbe inventée ou calculée sur un registre incomplet ne sert pas le joueur. Des panneaux pilotes E9 peuvent accompagner E3/E6 une fois les sources réelles prêtes.

## Articulation des profils et baseline

Témoin : run GitHub 42228409254 (90 saisons sur main historique) et 42233255733 (24 campagnes A/B/C/témoin sur PR #333). Rejouer le témoin sur le HEAD courant pour éviter comparaison entre versions différentes. Fixer 3 profils : reference, modeste, deficitFormation ; graines 827381 et 99173 ; 15 saisons × 29 matchs/tours de simulation native par saison (187 matchs par saison dans l'audit, 2 805 par campagne). Un jeu avec calendrier économique V2 doit aussi couvrir 12 mois/52 paies sans rajouter de matchs.

Scénarios nouveaux à employer en complément (au moins un de chaque) : sponsor majeur rompu, stade fermé partiellement, année sans qualification, dette et taux d'intérêt, actionnaire qui cesse son soutien, blessures importantes/joker, explosion des demandes salariales, vente obligée, promu/relégué uniquement si cette fonction existe dans la compétition, saison européenne seulement si simulée réellement. Identifier explicitement « hypothèse expérimentale » les cas de ligue non implémentés.

## Observabilité et invariants bloquants

À chaque événement : clubId, counterpartyId, fiscalPeriod, sportSeason, eventId unique, category, cashMovement, revenueExpenseRecognition, debtChange, commitmentChange, sourceRuleVersion. Tracer dépense et recette sans fuite, deux écritures si transferts interclubs.

### Bloquants absolus
- Cash de chaque club = ouverture + somme entrées cash ; dette initiale + tirages + intérêts capitalisés - remboursements = dette finale ; solde cash jamais modifié par une simple écriture non liquide.
- Enveloppe redistribuée égale au total reçu, compte de ligue neutre et audité ; pas d'argent imprimé par un transfert entre clubs.
- Aucun doublon de paiement à cause d'une reprise de sauvegarde, du refresh ou d'une saison terminée ; idempotence des événements.
- 100 % validations schéma, export-import natif, opérations correctes sur ancienne sauvegarde, pas de dépassement des limites de registre.
- Régime Salary Cap daté et stable pendant l'exercice ; contrôle de conformité distinct du budget conseil ; aucune sanction fantôme.
- Règles terrain neutre : recettes organisateur identifiées ; aucune recette domicile du club involontaire.
- Chaque mutation de cash doit être attribuable à une catégorie traçable ; manque de catégorisation est défaut de qualification.

### KPI de qualité et distributions à calibrer, **pas assertions universelles**
- Cash 3, 5, 10 et 15 ans : distribution, médiane, p10/p90, clubs négatifs, cash/revenue, réserves en mois, liquidités/engagements.
- Exploitation : résultat, marge, charges/produits, paie totale/produits, frais staff et formation, recettes stade / capacité, recettes par supporter.
- Marché : salaire moyen et p10/p90 par niveau/poste, ratio valorisation et salaire au talent, proportion renouvelée, départs, effectif, qualité, composition académies, concurrent bids.
- Régulation : salaire admissible par club/profile, nombre d'alertes, redressements, durée, interdictions et dérogations motivées.
- Sportif : classement, diversité champions, points vs coût salarial, qualité, blessures, compétitivité.
- Gouvernance : nombre de refus conseil, décisions de crise, aide actionnaire décorrélée de revenu, fonds propres, cas de défaut.
- Reproductibilité : mêmes graines → mêmes résultats, trois imports dans une campagne longue, anciennes sauvegardes et profils fiction/réel opt-in.

Ne PAS exiger « tous les clubs ont un certain cash » ni une médiane forcée. Les références A2R sont des **ordres de grandeur/contrôles de plausibilité** ; documenter tout écart modèle avant de conclure.

## Stratégie de comparaison scientifique

1. A (baseline exacte HEAD), B (module testé seul), C (combinaison), avec seeds et décisions identiques lorsque possible.
2. Tester les distributions, événements, causalité des écarts. Décomposer effets pour ne pas cacher une faille sous un net final raisonnable.
3. Journaux événements mensuels, 14 clubs × 15 ans, regroupements annualisés ; artefacts CSV/JSON + rapports HTML/Markdown avec courbes et tableaux (réels, pas captures simulées).
4. Générer l'interface PC et snapshots Chromium réels aux 2 résolutions, inspecter visuellement état normal, pertes, emprunt, club riche, ligue.
5. En cas d'échec de tests d'un lot, revenir au HEAD précédent qualifié, pas ajouter un subside automatique ; conserver artefacts, empreintes et SHA.
6. FEU VERT seulement si critères bloquants + CI terminale sur HEAD exact, puis décision de fusion au gate ; autrement ORANGE/ROUGE explicité.

## Jalons humanisables

- J0 : documents validés, architecture choisie, interfaces décidées, tâches minimales prêtes.
- J1 : registre financier autonome avec conservation et compatibilité d'identifiants.
- J2 : une saison en 12 mois économiquement réconciliée et 29 tours sportivement inchangés.
- J3 : un club IA qui change réellement sa stratégie après changement de résultats/sponsor.
- J4 : quinze saisons où la richesse n'augmente pas systématiquement malgré des finances plausibles ; aucun plafond artificiel de cash.
- J5 : cockpit finances où le joueur peut expliquer une crise, comparer deux choix et retrouver les mêmes chiffres après rechargement.

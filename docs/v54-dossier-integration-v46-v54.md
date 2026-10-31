# Dossier d'intégration V46–V54 — état vérifié au 31 octobre 2026

## Preuves
- `main` vérifié : `37a45928e5c4e30afc03e5a5010b9fb204badb0f` (intégration V41–V45).
- Intégration V46–V51 encore en PR [#51](https://github.com/Xynph/cadrage-debordement/pull/51). Aucune fusion réalisée ici.
- PR laboratoires : [#50](https://github.com/Xynph/cadrage-debordement/pull/50), [#52](https://github.com/Xynph/cadrage-debordement/pull/52), [#53](https://github.com/Xynph/cadrage-debordement/pull/53), [#54](https://github.com/Xynph/cadrage-debordement/pull/54).
- V54 commit `02d34ae54bbbdb3e4200b53fe79d61055c42981d` : six workflows réussis dont [V54 #41152406486](https://github.com/Xynph/cadrage-debordement/actions/runs/41152406486).
- 9 scénarios × 32 graines × 15 saisons = **4320 saisons**, **60480 clubs-saisons**, **288 reprises** comparées à la simulation continue.

## Résultats vérifiés du stress-test V54

| Profil | Force réputation | Part des titres du dominant | Champions distincts moyens | Déficit | Restrictions | Investissements payés | Changements entraîneurs |
|---|---:|---:|---:|---:|---:|---:|---:|
| Normal | 15 % | 48,54 % | 5,09 | 0 % | 2,28 % | 262 572 000 | 178 |
| Normal | 25 % | 58,96 % | 3,94 | 0,15 % | 3,65 % | 257 940 000 | 201 |
| Normal | 100 % | 89,58 % | 2,00 | 8,94 % | 13,17 % | 236 148 000 | 240 |
| Crise | 15 % | 44,17 % | 4,59 | 6,29 % | 17,51 % | 183 240 000 | 205 |
| Crise | 25 % | 54,38 % | 4,03 | 7,08 % | 21,09 % | 179 172 000 | 213 |
| Crise | 100 % | 84,58 % | 2,00 | 26,76 % | 37,14 % | 174 096 000 | 236 |
| Aisés | 15 % | 46,46 % | 5,31 | 0 % | 1,32 % | 404 472 000 | 162 |
| Aisés | 25 % | 55,42 % | 4,28 | 0,18 % | 2,31 % | 387 756 000 | 190 |
| Aisés | 100 % | 86,04 % | 2,09 | 9,82 % | 13,01 % | 331 776 000 | 235 |

Montants purement **fictifs** du moteur de laboratoire ; ne pas les assimiler à des budgets de clubs réels. Réglages testés au niveau de l'adaptateur expérimental, pas dans le jeu jouable.

## Ordre de transfert proposé

| Priorité | Module ou capacité | Prérequis | Preuve disponible | Risque avant production |
|---|---|---|---|---|
| P0 | Fondation V46–V51 : contrats d'API, snapshots, sim monde | Examiner PR #51 contre `main`, éviter toute duplication de modules | Tests de contrats et CI PR #51 à confirmer séparément | Conflits avec l'intégration, absence de test de sauvegarde réelle |
| P1 | Intégrité des finances, checkpoints et audits annuels | Modèle de données effectif + migrations éventuelles, mapping des identifiants de club | V51/V53/V54 en CI sur banc fictif | Reprises reproductibles en laboratoire ≠ compatibilité des anciennes sauvegardes |
| P2 | Reputation `CDReputation.update` : amortissement configurable à 25 %, alternative 15 % | Validation par saison jouable, matchs réels, changement contrôlé et réversible | V50–V54 : la concentration baisse nettement sur plusieurs jeux de graines | Perturbation de l'économie, difficulté de carrière, effet sur la progression individuelle |
| P3 | Installation `CDFacilities` et contrôles de paiement/événements | Brancher aux véritables budgets et dépenses, vérifier les transactions atomiques | Couverture des événements et des montants dans V52–V54 | Double-débit, faux revenus, progression non plafonnée |
| P4 | IA des clubs `CDClubAI` et recrutement | Journal de transactions signées, budget, effectifs, contrats | Décisions générées, **zéro transfert signé** sur V54 | Affirmer à tort que les décisions sont des transferts réels |
| P5 | Entraîneurs `CDCoachMarket` | Vraies offres, renvois, contrats, postes vacants et logique de remplacement | Événements internes cohérents sur V53–V54 | `coachChange` fictif ≠ licenciement de manager du joueur |
| P6 | Hiérarchie, distinctions et statistiques `CDRugbyWorld` | Connexion aux classements et rencontres réels | Mesures multi-graines, mais aucune saison de matchs complets | Palmarès artificiels si classement synthétique utilisé comme vérité |

## Critères d'acceptation pour l'intégrateur
1. Pas de changement de règle de rugby ni de fichier en match dans ce laboratoire ; consulter `docs/rugby-rules-reference.md` si une future intégration touche à la compétition.
2. Rejouer au moins une saison sportive réelle et une carrière avec sauvegarde ancienne sur une copie, comparer les états et les événements après reprise.
3. Tout transfert **effectif** doit créer une transaction traçable et réconcilier budget, salaires, contrats et effectif ; aucune décision IA ne vaut signature par elle-même.
4. Tout changement d'entraîneur doit être rattaché à un véritable mouvement de personnel et à un poste clairement défini.
5. Tout investissement payé doit correspondre à un seul événement et modifier les bonnes données après paiement ; aucun investissement en régime de restriction financière si le modèle l'interdit.
6. Coefficient de réputation fixé via paramètre de simulation, avec comparaison 15 %/25 %/100 %, sans changer silencieusement le comportement d'anciennes sauvegardes.
7. Valider les tests unitaires, d'intégration, CI, puis un test manuel de carrière. Conserver le rapport avant/après.

## Décision

**Le laboratoire V54 a réussi, mais aucune nouvelle mécanique n'est prête à être qualifiée de fonction jouable à elle seule.** 25 % est un candidat de prototype, pas une valeur de production décidée. La PR #51 d'intégration est un prérequis. Ne pas fusionner les PR de tests V50–V54 directement : leur héritage de snapshots de modules peut créer des doublons/conflits.

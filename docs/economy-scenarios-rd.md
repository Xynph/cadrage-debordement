# R&D — comparaison économique sur le vrai moteur (tests seuls)

## Périmètre
Branche isolée research/economy-scenarios-20261106 depuis main fd1727ef7fa55d473a4d77ef527ace9d469303d0. Test-only : `tests/economy-scenarios.cjs` et workflow distinct ; aucun changement de `dist/`, des sauvegardes utilisateur ni du moteur. Cette PR n'est pas une proposition de fusion.

## Scénarios
| Essai | Billetterie conservée hors terrain neutre | Apport annuel conservé | Plancher de masse salariale totale des 14 clubs / période |
|---|---:|---:|---:|
| control | 100 % | 100 % | Aucun |
| A | 80 % | 75 % | 2 700 000 € |
| B | 60 % | 50 % | 3 000 000 € |
| C | 50 % | 25 % | 3 400 000 € |

Dans A/B/C, la billetterie des demi-finales et finales considérées neutres est retirée. La compensation est appliquée après la fonction économique native. Le plancher revalorise proportionnellement les salaires des joueurs déjà présents en début de saison, si la masse salariale globale est inférieure à la cible ; **ce n'est pas un véritable modèle de négociation IA**. Les effets sportifs et financiers indirects sont conservés par le vrai moteur. Le témoin ne reçoit aucune intervention.

## Qualification
Pour chaque scénario : `reference`, `modeste`, `deficitFormation` avec graines 827381 et 99173 = 6 campagnes de 15 saisons. Total attendu 24 campagnes, 360 saisons, 67 320 matchs. Mesurer par saison : trésorerie, dette, masse salariale, effectif, qualité moyenne, clubs négatifs, recrutements/libérations/promotions IA et frais. Vérifier 15 sauvegardes natives et trois vrais imports confirmés par campagne, puis agréger strictement 24/24. Aucun échec n'est exclu.

## Critique méthodologique
Le plancher salarial est un contre-factuel artificiel, pas une preuve que l'IA négociera ces contrats. Les recettes modifiées après la comptabilisation native sont une intervention expérimentale, tracée `__TRIAL__` dans le registre du manager ; elles ne sont pas une simulation de ventes réelles de billets. Les montants sont fictifs. Comparer les politiques seulement à profil/graine identiques et vérifier que le témoin reste cohérent avec le précédent run économique 42228409254 (HEAD différent à cause de #328). Les résultats sont non qualifiés tant que les 25 jobs GitHub Actions (24 campagnes + agrégation) ne sont pas COMPLETED/SUCCESS. Ne pas inférer un bon équilibre sportif de la seule réduction de la trésorerie.

Aucun changement PR #328/#332, MATCH 3D, R&D, DATA/LNR, règles de rugby, auto-release, AGENTS.md, DEVELOPPEMENT.md ou fichiers d'un autre producteur. Aucun gate ni fusion.

# Progression avant et après le renouvellement

Deux matrices ont été reçues séparément sous Node 22 : trois graines, deux politiques publiques et deux saisons par bras. Les douze reçus passent le même analyseur ; mélanger leurs sources est refusé. Le runner et les politiques sont identiques. Le moteur et les trajectoires aléatoires diffèrent : cette comparaison est descriptive, sans attribuer chaque écart aux seuls regens.

La nouvelle matrice porte sur le commit gelé `2c96b06f6382e051ce1b80734ad2594138597456`, avant le durcissement des cibles de staff lors d’imports falsifiés. Elle ne prétend pas exécuter une tête ultérieure. Les coûts et bonus sportifs du staff sont nuls. Aucun coefficient économique n’a été modifié. Les mesures et empreintes des douze reçus figurent dans `progression-pre-post-20261109.json`.

## Résultats observés

Les écarts représentent la politique de renouvellements sélectifs moins la politique minimale. Les trois valeurs suivent les graines 827381, 318 et 52602. Les médianes standard sont recalculées depuis les joueurs bruts ; les p50 nearest-rank du runner restent distinctes.

| Mesure | Ancienne population | Population renouvelée |
| --- | --- | --- |
| Écart de points, fin S2 | −15 / +37 / +13 | +23 / −12 / +4 |
| Écart de trésorerie, ouverture S3, médiane | −3,813 M€ | −2,213 M€ |
| Écart de note naturelle du XV, fin S2 | +1,40 / +4,87 / +1,60 | −2,67 / −3,53 / +1,60 |
| Même mesure, ouverture S3 | +3,20 / +3,87 / +3,40 | +4,33 / +4,47 / +3,60 |
| Joueurs initiaux encore au club, minimal / sélectif | 16 / 22 sur 61 | 16 / 22 sur 61 |
| Joueurs initiaux retrouvés, minimal / sélectif | 16 / 22 sur 61 | 61 / 61 dans chaque bras |

Le résultat sportif diverge : la politique sélective ne gagne pas partout. Présenter seulement l’ouverture S3 cacherait que son XV est moins bien noté en fin S2 dans deux nouvelles graines. Conserver davantage de bons joueurs ne démontre pas une progression individuelle générale : le changement médian de rating des joueurs initiaux suivis reste nul. Les différences de données manquantes avant/après interdisent une comparaison naïve des seuls survivants ; aucune note zéro n’est imputée aux inconnus.

Chaque nouveau bras sélectif signe réellement douze prolongations pour 163 000 € fictifs de primes. Le surcoût comprend aussi les salaires : à S3, 176 140–176 540 € hebdomadaires contre 128 140–130 640 € sous la politique minimale. Les trésoreries finales restent comprises entre 7,867 et 11,696 M€.

## Limites pour l’équilibrage

Chaque bras part de 7,5 M€ et reçoit 5 M€ d’apports annuels pendant les deux transitions. Le cash est un stock, pas un bénéfice ; les flux calculés hors apports sont négatifs dans les six nouveaux bras. Aucune semaine négative n’est observée, donc aucun redressement financier n’est éprouvé. Les douze périodes financières ont un résidu nul et les dix-huit réouvertures de la nouvelle matrice sont exactes, profils privés et RNG compris.

Ce banc n’autorise ni à durcir automatiquement l’économie ni à déclarer tous les clubs équilibrés sur dix ans. L’objectif reste un jeu équilibré avec progression visible. Modifier les salaires du staff ou les apports annuels serait une nouvelle règle à qualifier séparément. Les nouveaux chantiers de détection et de progression ne sont pas inclus dans ces résultats.

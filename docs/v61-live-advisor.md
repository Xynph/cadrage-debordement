# V61 — Conseiller tactique en match (PRODUCTEUR)

## Valeur joueur

Le cockpit du match affiche deux propositions lisibles : attaque et défense. Le score, la minute, la possession, l'occupation et l'écart de pénalités proviennent directement des compteurs natifs. En cas de retard au score en fin de rencontre, de difficultés à occuper le terrain ou de sanctions répétées, les recommandations changent avec des explications et des compromis.

Les boutons appliquent les consignes **uniquement quand le match est en pause**, en réutilisant les fonctions officielles `setLiveTactic` et `setLiveDefence`, qui enregistrent les changements et préservent les validations existantes. Aucune exécution automatique, aucun changement du moteur, des probabilités, de l'IA adverse ni du format des sauvegardes. Les recommandations recalculées rejettent les clics périmés.

Les statistiques manquantes sont affichées comme non mesurées. Pour un ancien match sans règles défensives tactiques disponibles, le changement de défense est désactivé. Les anciens fichiers de carrière ne nécessitent aucune migration.

## Vérifications

`node tests/v61-match-advisor.cjs` : lecture seule et RNG, état sauvegardé, recommandations, application pendant pause seulement, anti-doublon, compatibilité ancienne sauvegarde synthétique. Tests Chromium et CI GitHub à réceptionner sur HEAD exact ; aucun fichier V16 historique authentique disponible à la rédaction.

## Limites

Aide heuristique explicable, **pas une nouvelle IA de simulation**. Les positions 2D sont schématiques, ne prouvent pas une supériorité tactique de collision. La pertinence stratégique ne garantit pas le résultat sportif.

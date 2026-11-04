# CI — rééquilibrage conservateur de la carrière longue (4 novembre 2026)

## Contexte vérifié
Main de départ : `a4f22d48985fee3d23b9ef389d1b31fe6b144595`, PR #280 fusionnée via gate officiel, post-fusion #41771166403 **7/7 SUCCESS**. L'audit de dix exécutions CI terminées (#41707029672, #41708215803, #41709297149, #41709949759, #41710895258, #41715682628, #41716839980, #41720921522, #41723237679, #41724378510) montre V63.1 P90 **80,1 s**, V63.2 P90 **109,1 s** et pic des sommes par shard P90 **188,1 s**. Mesures descriptives : code, runners et charges varient.

## Coût CPU observé dans la PR #280
- V63.1 : **62,08 s écoulées**, **69,35 s de CPU** (111 % affiché).
- V63.2 : **62,27 s écoulées**, **73,43 s de CPU** (117 % affiché).
- Dernière CI pré-instrumentation : pic somme des suites **174 s** ; CI PR instrumentée : **178 s**. Aucun gain de vitesse causale démontré.
Les deux suites ne sont pas nécessairement sur le shard critique : les durées d'autres carrières IA et du monde fluctuent également. Une valeur CPU supérieure au temps réel peut venir de plusieurs threads ; elle n'établit pas à elle seule une contention.

## Modification minimale
La seule pondération modifiée est `tests/lnr-career-long.cjs` : **40 → 55** dans `ci/shard-tests.cjs`. Ce nombre est une *réserve de planification*, jamais un temps d'exécution mesuré. On conserve exactement cinq shards, toute la découverte automatique des fichiers `tests/*.cjs`, un processus Node par test, les mêmes timeouts, la classification et Validation CI. Aucun scénario, assertion ni code de test V63 n'est réduit.

## Comparaison contrefactuelle reproductible
Avec les **trois traces complètes** présentes dans `tests/ci-shard-profiles.cjs` (220 suites historiques), mêmes fichiers et mêmes durées dans les deux plans :

| Trace | Pic avant (s) | Pic après (s) | Gain simulé |
| --- | ---: | ---: | ---: |
| 1 | 151 | 148 | 3 s / 2,0 % |
| 2 | 156 | 156 | 0 s |
| 3 | 165 | 161 | 4 s / 2,4 % |

**Aucune de ces simulations ne prouve un gain causal sur la CI réelle.** La sélection du candidat sur ces traces peut surajuster l'historique. Le test `tests/ci-long-career-balance.cjs` conserve le rejeu et refuse toute régression historique, tout doublon/perte de suite ou déséquilibre imprévu.

## Contrôles requis
Tests ciblés : `node tests/ci-sharding.cjs`, `node tests/ci-shard-balancing.cjs`, `node tests/ci-shard-profiles.cjs`, `node tests/ci-p90-stress-guard.cjs`, `node tests/ci-long-career-balance.cjs` ; puis CI GitHub sur HEAD exact avec sept jobs complets et V60/V61 applicables, `/cd-check` puis `/cd-merge` exclusivement si verts, sept jobs post-fusion sur main. Comparer les sommes de suites, la variance, la mémoire et le CPU aux nouveaux logs ; ne revendiquer de gain observé qu'après collecte. PRODUCTEUR, DATA/LNR, V62, MATCH 3D, moteur, sauvegardes, auto-release et gate exclus.

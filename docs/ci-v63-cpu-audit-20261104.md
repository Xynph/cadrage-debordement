# Audit V63.1 / V63.2 — 10 CI et sonde CPU (4 novembre 2026)

## Portée et source
Dix workflows **Tests JavaScript**, chacun avec classification + cinq shards + Validation CI en SUCCESS :
41707029672, 41708215803, 41709297149, 41709949759, 41710895258, 41715682628, 41716839980, 41720921522, 41723237679, 41724378510.
Données en secondes arrondies extraites du texte `PASS tests/... (N s)` des 50 logs de shards GitHub Actions.
Les versions de code et répartitions varient dans cette série ; ne pas présenter cette série comme un A/B causal.

| Run | V63.1 | V63.2 | Pic somme des suites/shard |
|---|---:|---:|---:|
| 41707029672 | 47 | 110 | 186 |
| 41708215803 | 43 | 67 | 169 |
| 41709297149 | 79 | 62 | 170 |
| 41709949759 | 80 | 106 | 180 |
| 41710895258 | 79 | 108 | 183 |
| 41715682628 | 45 | 109 | 207 |
| 41716839980 | 43 | 82 | 168 |
| 41720921522 | 45 | 100 | 155 |
| 41723237679 | 47 | 106 | 173 |
| 41724378510 | 81 | 109 | 174 |

| Métrique (10 échantillons) | V63.1 | V63.2 | Pic shard |
|---|---:|---:|---:|
| Moyenne | 58,9 | 95,9 | 176,5 |
| Médiane | 47 | 106 | 173,5 |
| P90 interpolé | 80,1 | 109,1 | 188,1 |
| Écart-type population | 17,08 | 17,57 | 13,14 |
| Variance population (s²) | 291,69 | 308,69 | 172,65 |
| Minimum / maximum | 43 / 81 | 62 / 110 | 155 / 207 |

Le pic est le **maximum des sommes des durées `PASS`** sur cinq shards, pas le délai complet GitHub Actions (qui comprend attente, checkout, Node, validation). Les runs ne sont pas matériellement contrôlés. V63.1 réalise 12 saisons avec reprises ; V63.2 réalise trois scénarios et 16 saisons avec reprises. Aucune preuve directe de contention CPU dans l'ancienne télémétrie.

## Changement non invasif
Dans `.github/workflows/tests.yml`, envelopper uniquement l'exécution déjà présente de chaque `node "$test"` par GNU `/usr/bin/time` **à l'intérieur** du même `timeout` (180 secondes, TERM puis kill après 10 secondes). La même commande passe ou échoue suivant le même code de retour ; scénarios, assertions, nombre de shards, suites, durée limite, Validation CI et gates identiques. Chaque test conserve un processus Node isolé.

Nouvelles lignes `CD_CPU_PROFILE suite=... user_s=... system_s=... wall_s=... cpu_pct=... max_rss_kb=...` dans les logs, permettant de comparer le rapport CPU/temps écoulé et le pic de mémoire par suite. Ces chiffres documentent la **charge du processus Node**, pas la contention des autres processus ni une causalité complète. `/usr/bin/time` doit être disponible sur les runners Ubuntu ; un runner privé dépourvu du binaire échouerait explicitement plutôt que supprimer les contrôles.

## Décision technique et limites
La précédente PR #279 avait obtenu un avantage **simulé** de 155 à 133 s sur une trace, mais la CI post-fusion mesurée était à 174 s contre 155 s pour le run antérieur : **aucune accélération réelle démontrée**. Ne pas modifier de nouveau les poids de shards ni réduire V63 sur ce seul argument.

La présente PR est un **lot de diagnostic préalable**, et non une accélération mesurée. Elle n'améliore pas a priori le temps des tests, et peut ajouter un surcoût minime. Avant d'envisager une optimisation CPU : CI complète sur HEAD exact, comparaison de plusieurs runs après instrumentation, contrôle de la couverture (toutes suites conservées), rapport CPU/elapsed, puis comparaison avant/après à charge comparable. Laisser le moteur, les sauvegardes, DATA/LNR, V62, MATCH 3D, auto-release et PRODUCTEUR intacts.

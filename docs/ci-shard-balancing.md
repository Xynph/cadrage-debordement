# Accélération CI — équilibrage des cinq shards (2 novembre 2026)

## Constats mesurés

Source : logs GitHub Actions réels des workflows **Tests JavaScript** PR [#41359113513](https://github.com/Xynph/cadrage-debordement/actions/runs/41359113513) et push main [#41359554302](https://github.com/Xynph/cadrage-debordement/actions/runs/41359554302). **171 suites** distinctes exécutées sur chacun des deux runs, sans tests perdus. Durées des commandes Node affichées par les jobs (en secondes entières, sans provisioning/checkout), pas de mesures du temps total du workflow.

| Mesure | Avant, poids historiques | Répartition simulée, poids recalibrés |
| --- | --- | --- |
| Main : charges de tests par shard | 63 / 110 / 105 / 222 / 79 s | 94 / 126 / 117 / 122 / 120 s |
| Main : shard critique | **222 s** | **126 s** |
| PR : charges de tests par shard | 113 / 85 / 57 / 159 / 106 s | 120 / 106 / 88 / 104 / 102 s |
| PR : shard critique | **159 s** | **120 s** |

Le déséquilibre venait notamment des suites LNR longues absentes des poids historiques (continuité multiclubs, preuves longues, carrière longue, rotation). Les nouveaux poids prennent le maximum observé dans **les deux** runs, majoré de 15 % et arrondi au-dessus, seulement pour les suites ayant dépassé 3 s ; toutes les autres reçoivent le poids 1. L'algorithme d'affectation reste inchangé et **les cinq shards conservent la couverture complète**.

## Validation et limites

- Test déterministe `tests/ci-shard-balancing.cjs` : partition sans omission ni doublon, stabilité, prise en compte des suites lentes, équilibre des poids et refus des entrées invalides.
- La baisse affichée est une **relecture/simulation sur les mêmes durées mesurées**, et **pas** un gain observé après déploiement. La CI complète sur la nouvelle PR puis un run main post-fusion permettront de mesurer les gains réels. Les temps de démarrage des runners, la variabilité et les autres workflows ne sont pas inclus.
- Aucun test désactivé, aucune sélection au diff, aucun changement des workflows, release gate, permissions, scripts du moteur, sauvegardes ou données. Les nouveaux tests `.cjs` sont découverts automatiquement par `ci/shard-tests.cjs`.
- Prochaine optimisation éventuelle après mesures : cibler les workflows spécialisés redondants et leurs déclencheurs, sans modifier les checks requis ni la CI push. Ne pas supprimer les contrôles post-fusion.

# CI — historique et goulets d’étranglement (lot 4)

## Objectif
Comparer 2 à 30 exécutions terminées et vertes du workflow **Tests JavaScript**, classer les suites les plus lentes sur leur P90, et publier un rapport descriptif reproductible. Le calcul refuse les runs rouges/en cours, les jobs manquants, les logs absents et les suites dupliquées. Les suites présentes seulement dans certains runs sont exclues du classement, avec leur nombre affiché.

## Utilisation
```bash
GH_TOKEN=<jeton-lecture-actions> node ci/ci-history-metrics.cjs 41696152014 41700883176 41705441852
node tests/ci-history-metrics.cjs
```
Le jeton doit avoir le droit de lecture Actions. Aucun appel API d’écriture, aucune commande de fusion. L’outil ne sélectionne pas implicitement des workflows différents et ne se substitue ni aux 7 jobs de CI ni au gate officiel. Les temps sont arrondis à la seconde par les logs existants. La comparaison doit privilégier des SHA, environnement et workload similaires ; la médiane/P90 ne prouvent pas la causalité d'un changement.

## Mesures déjà établies par le lot 3
313 s (run #41696152014) → 233 s (run #41705441852), soit −25,6 % observés, sans garantie de stabilité. Le lot 4 fournit un outil pour accumuler des mesures ; **aucun gain de vitesse supplémentaire n’est revendiqué à la création de cette PR**.

## Exclusions
Aucune modification auto-release #272/#274, gates, variables, workflows requis, Chromium, DATA/LNR, V62, MATCH3D, moteur, sauvegardes et fichiers du PRODUCTEUR. Le chantier ne supprime aucun contrôle CI.

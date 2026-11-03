# Performance CI — lot 2 (3 novembre 2026)

## Fonctionnel
- Retour rapide manuel via `Feedback rapide de developpement (non bloquant)` et `ci/quick-check.cjs`, sélection conservatrice basée sur `ci/select-tests.cjs`.
- Repli automatique vers l'ensemble des suites en cas de fichier inconnu ; aucune modification des 7 checks obligatoires sur PR et main.
- Cache des téléchargements pip/Chromium dans le workflow mutualisé, sans omettre `playwright install --with-deps chromium` ni ses vérifications.

## Mesure de départ
GitHub Actions JavaScript #41694849000 : durées des jobs shards 1=221 s, 2=233 s, 3=142 s, 4=96 s, 5=98 s. Cela démontre un déséquilibre mais ne renseigne pas directement les durées par suite. Les poids historiques de `ci/shard-tests.cjs` sont datés du 1er novembre : ne pas inventer de nouveaux poids sans profilage complet.

## Prochaine mesure
Comparer le temps de préparation Chromium, le P90 de CI, les minutes runner et les échecs sur plusieurs exécutions avant/après, en distinguant première exécution sans cache et exécutions avec cache chaud.

## Exclusions
Aucun changement du gate officiel, d'auto-release, de `CD_AUTO_RELEASE_ENABLED`, du moteur, des sauvegardes, DATA/LNR, V60/V61/V62, MATCH 3D ou de la branche principale. Ne pas fusionner sans CI terminale, /cd-check puis /cd-merge officiels.

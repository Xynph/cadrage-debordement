# Performance CI — lot 2 (3 novembre 2026)

## Fonctionnel
- Retour rapide manuel via `Feedback rapide de developpement (non bloquant)` et `ci/quick-check.cjs`, sélection conservatrice basée sur `ci/select-tests.cjs`.
- Repli automatique vers l'ensemble des suites en cas de fichier inconnu ; aucune modification des 7 checks obligatoires sur PR et main.
- Cache des téléchargements pip/Chromium dans le workflow mutualisé, sans omettre `playwright install --with-deps chromium` ni ses vérifications.

## Mesure de départ
GitHub Actions JavaScript #41694849000 : durées des jobs shards 1=221 s, 2=233 s, 3=142 s, 4=96 s, 5=98 s. Cela démontre un déséquilibre mais ne renseigne pas directement les durées par suite. Deux nouvelles suites longues V63 ont été identifiées directement dans les logs : `v63-2-stress-native` 92 s et `v63-1-long-career` 80 s. Elles sont désormais pondérées avec marge (106 et 92) pour rééquilibrer les cinq shards. Relecture déterministe des 217 durées de suites du run #41694849000 avec le même algorithme : chemin critique de tests estimé de 212 s à 171 s, soit **-19,3 %** sur ce rejeu. Ce n'est pas encore une mesure réelle du temps global CI après changement ; à confirmer avec des runs neufs.

## Prochaine mesure
Comparer le temps de préparation Chromium, le P90 de CI, les minutes runner et les échecs sur plusieurs exécutions avant/après, en distinguant première exécution sans cache et exécutions avec cache chaud.

## Exclusions
Aucun changement du gate officiel, d'auto-release, de `CD_AUTO_RELEASE_ENABLED`, du moteur, des sauvegardes, DATA/LNR, V60/V61/V62, MATCH 3D ou de la branche principale. Ne pas fusionner sans CI terminale, /cd-check puis /cd-merge officiels.

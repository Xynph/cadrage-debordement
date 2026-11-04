# Essai auto-release : couverture CI du témoin #281

Le témoin isolé #281 ne modifie que `docs/ci-auto-release-trial.md`. Les PR documentaires ordinaires continuent à sauter les cinq shards pour éviter un coût inutile. **Exception fermée :** uniquement la PR numéro 281, uniquement si son diff GitHub contient exactement ce fichier unique, et uniquement sur l'événement `pull_request`, le classificateur retourne `documentation_only=false`.

Les cinq shards de tests JavaScript et la Validation CI sont alors réellement exécutés : aucune validation synthétique, aucun statut forcé et aucune règle de protection modifiée. Toute autre PR documentaire conserve son traitement existant. Sur `push` et `workflow_dispatch`, la couverture complète reste obligatoire.

Cette PR technique ne change pas `ci/auto-release.cjs`, `ci/chat-release.cjs`, le gate, les variables GitHub Actions, le moteur de jeu ou les sauvegardes. Elle **ne lance pas** l'essai réel. L'essai reste interdit tant que les variables Actions ne peuvent pas être lues, vérifiées et restaurées, et tant que la PR #281 n'a pas un HEAD à jour et les sept jobs terminaux SUCCESS.

Tests ciblés : `node --test tests/ci-auto-release-witness.cjs`. Après intégration éventuelle de cette PR par le gate officiel, il faudra réaligner #281 sur main, revalider son HEAD et ses CI avant tout essai trial.

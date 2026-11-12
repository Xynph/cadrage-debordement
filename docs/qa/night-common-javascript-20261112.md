# JavaScript commun — reçu strict S du 12 novembre 2026

Le run [43129066843](https://github.com/Xynph/cadrage-debordement/actions/runs/43129066843), tentative 1, est **terminé avec succès : sept jobs verts**, sur le SHA exact `37e085b687b4e9a603085beaa50fecf9d6cace22`, branche `cloud/rg27-night-common-20261111`, événement `workflow_dispatch`, couverture `full`. Root a déclenché cette campagne une fois. Ce reçu est propre à S ; il ne donne pas un contrôle vert à un futur HEAD corrigé.

| Job | ID | Suites CJS annoncées PASS | Verdict |
| --- | ---: | ---: | --- |
| classification | 130888410883 | — | success |
| Suites 1/5 | 130888765029 | 128 | success |
| Suites 2/5 | 130888765221 | 130 | success |
| Suites 3/5 | 130888764981 | 129 | success |
| Suites 4/5 | 130888765183 | 129 | success |
| Suites 5/5 | 130888765005 | 129 | success |
| Validation CI | 130916444746 | — | success |

Les **645 lignes PASS correspondent exactement aux 645 fichiers CJS distincts à la racine de `tests/`, hors `harness.cjs`**, inventoriés depuis l’objet Git S, sans suite manquante ou dupliquée. Cette comparaison contrôle la découverte complète du contrôleur JavaScript. Elle ne change pas les conditions internes des recettes : les wrappers Godot ou graphiques peuvent être SKIP dans cette campagne sans SDK/opt-in. Leur PASS Node ne vaut pas une exécution SDK réelle ; le [SDK initial reste rouge à 71/75](night-common-sdk-initial-20261112.md).

Le [gate terminé](evidence/night-common-javascript-20261112/gate.log) conserve les variables `CLASSIFICATION=success`, `COVERAGE=full`, `SHARDS=success`, le SHA exact et l’avis de succès. Les [métadonnées des sept jobs](evidence/night-common-javascript-20261112/run.json) conservent leurs débuts/fins et étapes. Les cinq fichiers `js-*-passes.log` sont les lignes PASS originales horodatées des logs terminés, récupérées par le connecteur GitHub en lecture seule. La [provenance](evidence/night-common-javascript-20261112/provenance.json) contient la vérification d’inventaire et les hashes du workflow/classificateur/sharder lus depuis S ; [SHA256SUMS](evidence/night-common-javascript-20261112/SHA256SUMS) contrôle les huit fichiers légers.

La création du run à 00:41 UTC ne marque pas le début simultané des cinq suites : les jobs commencent respectivement à 00:57:12, 01:03:24, 00:42:25, 01:04:10 et 00:59:11. L’attente en queue est distincte du temps d’exécution ; la limite de job de 60 minutes est conservée. Aucun délai, seed, classification, workflow, permission ou budget n’est modifié par ce reçu.

La future qualification d’un correctif doit identifier son propre HEAD et ses contrôles. Aucun succès du main, de S ou d’une reprise ciblée ne doit être renommé en succès global du futur HEAD.

# Qualification finale — JavaScript complet reçu le 12 novembre 2026

Le run [43157653421](https://github.com/Xynph/cadrage-debordement/actions/runs/43157653421), tentative **1**, est **terminé avec succès : sept jobs verts**, sur le SHA exact `ec0044ea99e22aeaad29751ccde1279c1699b577`, branche `cloud/rg27-night-qualification-20261112`, événement `workflow_dispatch`, couverture **full**. Root a demandé cette campagne une fois à 04:52 UTC ; aucune relance ni annulation n’est effectuée pour ce reçu.

| Job | ID | Suites annoncées PASS | Conclusion |
| --- | ---: | ---: | --- |
| classification | 130981223761 | — | success |
| Suites 1/5 | 130981517818 | 128 | success |
| Suites 2/5 | 130981517874 | 130 | success |
| Suites 3/5 | 130981517846 | 130 | success |
| Suites 4/5 | 130981517872 | 129 | success |
| Suites 5/5 | 130981517887 | 129 | success |
| Validation CI | 131001971040 | — | success |

Les **646 PASS correspondent à 646 suites distinctes**, exactement égales au multiensemble `tests/*.cjs` à la racine lu par `git ls-tree` depuis ce SHA, hors `harness.cjs`. Aucun doublon, manque ni suite supplémentaire. Le [gate original terminé](evidence/night-qualification-javascript-20261112/gate.log) confirme couverture full, classification/shards success et SHA exact.

## Deux campagnes complètes sur la même source

Les conditions internes SDK/graphisme restent applicables : un wrapper Node annoncé PASS peut contenir un test SKIP sans SDK ou opt-in. Trois [exemples originaux](evidence/night-qualification-javascript-20261112/sdk-skips-original.log) sont conservés. Le présent reçu ne transforme pas ces skips en exécutions Godot.

La qualification SDK réelle est celle du [run complet séparé 43157636998](night-qualification-sdk-full-20261112.md), **76 résultats sur 76 réussis**, sur **le même SHA exact ec0044ea**. Cette source possède donc deux campagnes complètes vertes dans leurs périmètres respectifs, sans emprunter le résultat d’un autre HEAD. Les comptes de tests locaux restent séparés de ceux des campagnes CI.

L’ancien SDK `1a7b083b` demeure rouge 74/76 et son JavaScript demeure un vert distinct. Les campagnes S37 et `76077ed3` restent elles aussi inchangées. Ce succès ne qualifie aucune fusion, future source, recette Windows, animation/FPS ou cause unique des échecs précédents.

## Provenance et limites

Les [métadonnées des sept jobs et étapes](evidence/night-qualification-javascript-20261112/run.json) conservent SHA, événement, statut et débuts/fins. L’âge du run créé à 04:52 UTC inclut la queue ; il n’est pas la durée d’exécution de chaque suite. Les cinq fichiers `job-*-passes.log` sont des extraits originaux horodatés de logs terminés, récupérés en lecture seule par le connecteur GitHub.

La [provenance](evidence/night-qualification-javascript-20261112/provenance.json) documente l’égalité d’inventaire, l’arbre Git des tests et les empreintes workflow/classificateur/sharder lues depuis les objets Git exacts. [SHA256SUMS](evidence/night-qualification-javascript-20261112/SHA256SUMS) couvre les fichiers légers. Aucun profil, export, PNG ou log intégral publié ; aucun worker, SDK local, import, changement de source, registre, délai, classification, workflow, budget ou permission. Aucune fusion ni publication vers main.

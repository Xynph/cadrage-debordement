# Clôture commune — JavaScript complet reçu le 12 novembre 2026

Le run [43152477147](https://github.com/Xynph/cadrage-debordement/actions/runs/43152477147), tentative **1**, est **terminé avec succès : sept jobs verts**, sur le SHA exact `1a7b083b8a090d735ef1b08245b5f4faf430f76b`, branche `cloud/rg27-night-closeout-20261112`, événement `workflow_dispatch`, couverture **full**. La campagne a été demandée une fois par root à 04:05 UTC ; aucune relance ni annulation n’est effectuée pour ce reçu.

| Job | ID | Suites annoncées PASS | Conclusion |
| --- | ---: | ---: | --- |
| classification | 130964700470 | — | success |
| Suites 1/5 | 130964912652 | 128 | success |
| Suites 2/5 | 130964912643 | 130 | success |
| Suites 3/5 | 130964912577 | 130 | success |
| Suites 4/5 | 130964912654 | 129 | success |
| Suites 5/5 | 130964912599 | 129 | success |
| Validation CI | 130987746953 | — | success |

Les **646 PASS correspondent à 646 suites distinctes**, exactement égales au multiensemble `tests/*.cjs` à la racine lu par `git ls-tree` depuis ce SHA, hors `harness.cjs`. Aucun doublon, manque ni suite supplémentaire n’est substitué à cet inventaire. Le [gate original terminé](evidence/night-closeout-javascript-20261112/gate.log) confirme `COVERAGE: full`, classification/shards success et le SHA exact.

## Portée Node et SDK distincte

Les conditions internes SDK/graphisme restent applicables : un wrapper CJS annoncé PASS peut contenir un test SKIP sans SDK ou opt-in. Trois [exemples originaux](evidence/night-closeout-javascript-20261112/sdk-skips-original.log) sont conservés. Ce reçu ne transforme pas ces skips en exécutions Godot.

La campagne SDK réelle du **même SHA**, [43152464850](night-closeout-sdk-full-20261112.md), reste **rouge : 74 réussites sur 76 résultats**, avec Carnet et Night guards en échec. Le succès JavaScript n’efface pas ces deux rouges et ne qualifie pas ce candidat comme globalement vert. Les campagnes ultérieures sur `ec0044ea` constituent d’autres reçus, sans verdict emprunté ici. Les campagnes historiques S37 et `76077ed3` restent inchangées.

## Provenance et limites

Les [métadonnées complètes des sept jobs et étapes](evidence/night-closeout-javascript-20261112/run.json) conservent SHA, événement, statut et débuts/fins. L’âge du run créé à 04:05 UTC inclut la queue : les shards ont commencé à des heures différentes et les durées PASS décrivent seulement chaque suite. Les cinq fichiers `job-*-passes.log` sont des extraits originaux horodatés de logs terminés, récupérés en lecture seule par le connecteur GitHub.

La [provenance](evidence/night-closeout-javascript-20261112/provenance.json) documente l’égalité d’inventaire, l’arbre Git des tests et les empreintes workflow/classificateur/sharder calculées depuis les objets Git exacts. [SHA256SUMS](evidence/night-closeout-javascript-20261112/SHA256SUMS) couvre les fichiers légers. Aucun profil, export, PNG ou log intégral n’est publié ; aucun worker, SDK local, import, changement de source, registre, délai, classification, workflow, budget ou permission. Aucune recette Windows, fusion ni publication vers main.

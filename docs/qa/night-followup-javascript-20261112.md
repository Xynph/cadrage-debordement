# Correctif commun — JavaScript complet reçu le 12 novembre 2026

Le run [43138359860](https://github.com/Xynph/cadrage-debordement/actions/runs/43138359860), tentative 1, est **terminé avec succès : sept jobs verts**, sur le SHA exact `76077ed3f2af0ff029c8a413fc26451a25ac647f`, branche `cloud/rg27-night-followup-20261112`, événement `workflow_dispatch`, couverture `full`. Root a demandé cette campagne une fois ; aucune relance ni annulation n’est effectuée pour ce reçu.

| Job | ID | Suites annoncées PASS | Verdict |
| --- | ---: | ---: | --- |
| classification | 130919061852 | — | success |
| Suites 1/5 | 130924484039 | 128 | success |
| Suites 2/5 | 130924484003 | 130 | success |
| Suites 3/5 | 130924484036 | 129 | success |
| Suites 4/5 | 130924484001 | 129 | success |
| Suites 5/5 | 130924484073 | 129 | success |
| Validation CI | 130946563545 | — | success |

Les **645 PASS sont 645 suites distinctes** et correspondent exactement à l’inventaire `tests/*.cjs` à la racine lu par `git ls-tree` depuis ce SHA, hors `harness.cjs`. Les conditions internes SDK/graphisme sont conservées : un wrapper Node annoncé PASS peut avoir un test SKIP sans SDK ou opt-in. La qualification SDK réelle vient du [run complet séparé 43138356742, 75/75](night-followup-sdk-full-20261112.md), exécuté sur **le même SHA exact**. Le candidat 7607 possède donc deux campagnes complètes vertes, sans emprunter le succès d’un autre HEAD.

Le [gate terminé](evidence/night-followup-javascript-20261112/gate.log) conserve couverture full, succès des shards et SHA exact. Les [métadonnées](evidence/night-followup-javascript-20261112/run.json) identifient les sept jobs et leurs débuts/fins ; l’âge du run créé à 02:00 UTC n’est pas la durée d’exécution de chaque suite, démarrée après sa queue. Les cinq fichiers `job-*-passes.log` contiennent les lignes PASS originales horodatées des logs terminés du connecteur GitHub. La [provenance](evidence/night-followup-javascript-20261112/provenance.json) documente la comparaison d’inventaire et les hashes workflow/classificateur/sharder lus depuis les objets Git 7607. [SHA256SUMS](evidence/night-followup-javascript-20261112/SHA256SUMS) vérifie les huit fichiers légers.

Ce reçu ne qualifie aucun nouveau wrapper de séance, produit ultérieur ou fusion de main. Les verts JavaScript de S37 et du main f9c restent des reçus historiques distincts. Aucun changement de source, registre, classification, limite, workflow, permission ou budget n’est effectué ; aucune fusion ou publication vers main n’est réalisée.

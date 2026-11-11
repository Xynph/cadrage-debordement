# Réception PR553 — à corriger

Réception indépendante du 11 novembre 2026, base `96f537040bf9f2e37bf10b0a9b09518b732244a2`, candidat `feee1891f3ffbea2b32afa65dc289251724b0b65` (deux commits `1e77b8e` puis `feee189`). Description et commentaires lus : aucun commentaire ; description obsolète, car le second commit fournit déjà la rubrique presse des packs et le test de migration annoncés comme non faits. La base de PR est `integration/oval-cloud-complet-20261110`, pas main ; seul le patch des deux commits a été appliqué dans une copie jetable de main96, sans conflit. Aucun fichier produit modifié dans la branche de réception.

## Bloquant : citations historiques réécrites à l’affichage

`native/engine/media-packs.cjs:198` ajoute les noms de presse au remplacement textuel global ; `:206` applique ensuite ce remplacement récursivement à toutes les chaînes, sauf quelques clés. Les champs historiques `question`, `answer`, `questionText`, `answerText`, `quote` et les textes de mémoire ne sont pas protégés.

Reproduction Node22 dans le worker réel, à partir de `tests/press-identity-pack.cjs` : créer une carrière commune avec conférence archivée, importer un export valide dont une question archivée contient le nom de base du journaliste (nom du jeu fictif), activer le pack presse de test. Attendu : même question mot pour mot. Observé : la sous-chaîne portant le nom du journaliste est remplacée par le nom du pack. Assertion `mot pour mot question archivée sous pack` en échec. Le même chemin traite les réponses et les citations de relance. La sauvegarde originale peut rester intacte tandis que sa présentation modifie la citation ; les deux garanties doivent être vérifiées séparément.

Correction attendue chez le producteur : projeter les identités structurées par ID, préserver intégralement les textes de question/réponse/citation/mémoire archivés et ajouter un test dont la citation contient explicitement un nom de journaliste et un nom de rédaction. Ne pas corriger ce sujet réservé dans la branche de réception.

## Vérifications positives exécutées

- `git apply --check` du patch des deux commits sur main96 : rc0, aucun conflit.
- `tests/press-identity-pack.cjs` sur main96 + patch : PASS, rubrique facultative, contrôles d’import, projection, bascule base/pack, reprise, ancienne sauvegarde et signature d’époque conservée.
- `tests/v60-question-bank.cjs` : PASS, 25 thèmes, 500 questions, 1 500 variantes, cinq réponses, exclusion de douze semaines.
- `tests/native-press-followups06.cjs` : PASS, relance littérale Unicode/date, isolation journaliste/club/saison, anti-répétition, archive exacte, anciennes données.
- Comparaison indépendante des banques avant les deux commits et après : les 500 objets question/réponses et les thèmes sont strictement égaux ; dix correspondances anciennes identités → IDs stables vérifiées en mémoire, styles et spécialités conservés. SHA256 JSON banque questions : `038af9ba3e6f91183154a483c1cf83428fbc8ccfa868a9d36639ac6ab0062c47`. Aucun ancien nom ou identifiant privé reproduit dans ce rapport.
- Le changement `dist/saves.js:435` contrôle l’empreinte du fichier avant migration puis calcule celle de l’état validé pour la confirmation : l’import ancien est couvert par le test worker, il n’est pas refusé par principe.

## Limites et verdict

**À corriger**, pour la réécriture des citations au rendu. Réception de migration positive sous les cas testés ; pas de refus général de migration. Tests purs Node `v22.23.4`, pas de SDK/Godot ni de Windows exécutés. Noms commerciaux des médias inventés non recherchés, pack privé réel non ouvert ni publié, tests navigateur non exécutés. L’immersion de la vue de presse existante et les collisions entre noms de pack restent hors de cette preuve ciblée.

## Reproduction durable, isolée

Le [patch de sonde](../qa/pr553-archive-quotes-repro.patch) ajoute un seul scénario au test officiel du candidat : importer une archive dont la question cite un journaliste de base et la réponse cite sa rédaction, puis vérifier les deux textes sous pack. Les noms proviennent de la banque courante du candidat, aucun ancien ID/nom privé n’est inscrit dans la preuve. Appliquer uniquement à une copie jetable :

```bash
repro_root=$(mktemp -d /tmp/rg27-pr553-quotes.XXXXXX)
repro_patch="$(pwd)/docs/qa/pr553-archive-quotes-repro.patch"
git archive feee1891f3ffbea2b32afa65dc289251724b0b65 | tar -x -C "$repro_root"
(cd "$repro_root" && git apply "$repro_patch")
(cd "$repro_root" && /workspace/.cloud-setup/tools/node-v22.23.4-linux-x64/bin/node tests/press-identity-pack.cjs)
```

Résultat attendu pour reproduire le défaut : rc1 à l’assertion `mot pour mot question et réponse archivées sous pack`. Le patch ne modifie pas la production du candidat.

Relance de la sonde combinée le11novembre à13:58UTC : rc1 confirmé. La différence d’assertion porte sur **les deux champs** : question avec nom de journaliste de base transformé en `Journaliste Test Zéro`, réponse avec nom de rédaction de base transformé en `Rédaction Test 1`. Le test officiel sans sonde était vert ; ce scénario isole donc la lacune de couverture.

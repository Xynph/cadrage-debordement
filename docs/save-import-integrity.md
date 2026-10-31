# SAVE-INT-01 — Intégrité différée de l'import

L'aperçu d'une sauvegarde prouve que le document était valide lors de sa sélection, mais le contenu en mémoire peut évoluer avant le clic « Remplacer et reprendre la carrière ». Avant ce correctif, `confirmSaveImport()` contrôlait la forme du nouvel état, **pas** sa somme de contrôle déjà validée ; une modification numériquement valide après l'aperçu pouvait être enregistrée.

La confirmation refuse désormais tout écart entre `saveChecksum(pendingSave.state)` et `pendingSave.checksum` **avant** de toucher aux clés `bdt-before-import` et `bdt-v1`. Elle conserve ensuite la validation de structure et les protections existantes face aux erreurs d'écriture. Le cas nominal reste compatible avec les exports V1 et les carrières V2. Aucun nouveau champ de sauvegarde ni migration.

`node tests/saves.cjs` couvre l'import normal, la sauvegarde de secours et les manipulations post-aperçu de trésorerie, morale et empreinte, en vérifiant l'absence de mutation de la carrière et du stockage après rejet. La CI GitHub complète du dernier HEAD doit également réussir avant toute proposition de fusion.

Limite : le checksum FNV-1a historique est un détecteur d'altération non cryptographique ; il n'authentifie pas l'auteur du fichier. Ce lot ne prétend pas résoudre la falsification délibérée d'un export recalculé.

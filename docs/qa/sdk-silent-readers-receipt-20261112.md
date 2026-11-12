# Réception ciblée : cinq lecteurs avec silence renforcé

Root a reçu les cinq wrappers sur la source exacte `4dde99149ae63503cb0bb414aafb3542124105b8`. Les cinq sorties sont 0. Source des relevés : `/workspace/work/night-followup-receipts/silent-readers/results.json` et les cinq logs associés. Cette réception ciblée ne constitue pas une nouvelle campagne SDK complète.

| Wrapper (`tests/godot-…cjs`) | Contrôles / échecs | Sous-test TAP, ms exactes | TAP total, ms exactes | Enveloppe root, ms | Extrait |
|---|---:|---:|---:|---:|---|
| finance-ledger-links | 38 / 0 | 11016.095198 | 11086.372225 | 11157 | [finance-ledger-links.log](receipts/silent-readers-20261112/finance-ledger-links.log) |
| training-identity-links | 55 / 0 | 16005.705872 | 16052.97343 | 16128 | [training-identity-links.log](receipts/silent-readers-20261112/training-identity-links.log) |
| analysis-club-links | 56 / 0 | 25227.204785 | 25274.73572 | 25326 | [analysis-club-links.log](receipts/silent-readers-20261112/analysis-club-links.log) |
| profile-reading | 40 / 0 | 17844.874118 | 17885.118224 | 17925 | [profile-reading.log](receipts/silent-readers-20261112/profile-reading.log) |
| reader-history | 115 / 0 | 115580.593792 | 115631.853027 | 115680 | [reader-history.log](receipts/silent-readers-20261112/reader-history.log) |

## Périmètre reçu et assertions de silence

Le candidat QA `cdb80c788e13533531dfec2995bd9e7c9ca0f1e0` mute le coach immédiatement après `root.add_child(app)`, puis branche les signaux `requested` et `started` avant toute attente de projection pour chacun des cinq clients. Les assertions finales vérifient les deux compteurs à zéro et `int(app.coach.speech._id) == 0`. Finance, training et analysis conservaient déjà cette assertion à trois termes ; reader-history et profile-reading l’ont complétée avec `_id`. Ces cinq recettes ne recréent pas un second client. Le pilote Dummy est explicite dans leurs wrappers. Tous les contrôles fonctionnels ont été conservés ; aucune commande supplémentaire ni modification produit/moteur.

Finance est reçu en **headless : 38 contrôles / 0**, sans les deux captures réservées à sa variante graphique. Il ne faut donc pas annoncer deux PNG sur ce reçu. Training reçoit 55/0, analysis 56/0, profile 40/0 et reader-history 115/0. Les preuves concernent le silence et les parcours effectivement exécutés, sans extrapolation aux autres lecteurs ou aux variantes graphiques non exécutées.

Les anciennes preuves de l’[audit statique](sdk-new-readers-silence-audit-20261112.md) gardent leurs limites : branchement tardif ou absence de `_id` n’est pas rétroactivement corrigé dans un ancien reçu. Le présent reçu qualifie le nouveau candidat assemblé à la source 4dde9914 seulement. Le complément documentaire d’audit est `be32ff091de28fa304c41610d8f76a7de0ec8bb1`.

## Publication minimale

Les cinq extraits publiés contiennent exclusivement résumé de contrôles/échecs, nom et succès du sous-test, durée sous-test et durée TAP totale. Aucun profil complet, commande métier, export de carrière, identité ni chemin de sauvegarde temporaire n’est copié. SHA-256 des logs sources complets pour rattachement :

- `finance-ledger-links.log` : `4d5c73bd688b279fbd8f059d6eab9ff1b6215a6f0aa990eb549839bc094000b5`
- `training-identity-links.log` : `aa522e784b7cfbc4af4f70e99c76099e90ce68a4fe3e688d2f562d1780800c1f`
- `analysis-club-links.log` : `45bd80227d93080a5771322c4527f6d4bb69f6ae62963feb70a88d7277e1c004`
- `profile-reading.log` : `9322b2716a5aee77fed184ebc0eeb6b2b55ce9459be1dd58839c45704522fa2c`
- `reader-history.log` : `9d22f9df8d98fac92c8a2eaf08426a2066cafd61309ecb721783adfd1d9b1c1a`

Aucun SDK, import, collecte ni changement de la branche followup effectué pour produire ce document ; lecture des reçus root et filtrage seulement.

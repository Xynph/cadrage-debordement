# DATA-06 — Catalogue exhaustif des identifiants (pas enrichissement exhaustif)

Le fichier `modding/data06/all-players-2026-2027.json` regroupe **1 592 fiches de joueurs référencées pour 30 clubs**, reconstruites depuis les quatre fichiers DATA-03 officiels du projet et les quinze exports de profils DATA-05 déjà collectés. Le contrôle réel des sources a confirmé 1 592 identifiants distincts, 240 profils enrichis, 1 352 fiches d'effectif avec identité et URL mais sans enrichissement personnel vérifié, et 0 anomalie d'association ID/club/URL parmi les 240.

Chaque joueur dispose du nom, club, ligue, ID stable et URL publique LNR déjà enregistrés. Les 240 profils possèdent des informations individuelles complémentaires lorsqu'elles sont publiées. Les champs non vérifiés (naissance exacte, JIFF, contrat, salaire, budget, performances, notes estimées) valent `null` ; aucune information supposée n'est présentée comme un fait. La photographie des effectifs date du 31 octobre 2026 et ne prouve **pas** leur composition au 1er juillet 2026.

Génération reproductible : `node tools/data06-all-players.cjs` ; audit : `node --test tests/data06-all-players.cjs`. Cette sortie n'est pas encore raccordée automatiquement à la carrière. Elle complète la PR #142, qui couvre séparément les annonces de mutation (98 dans la révision auditée, non équivalentes à des profils enrichis).

**Restant à faire pour une base réellement complète** : 1 352 fiches individuelles à vérifier/enrichir depuis des sources autorisées, statut JIFF, postes précis, staffs et finances officielles. Le projet ne doit jamais afficher « 1 592 profils complets » avant ces contrôles. Pas d'HTTP live ni d'appel Firecrawl payant dans cette livraison. Aucune modification `dist/**`, anciens effectifs ou sauvegardes.

Le générateur décode les entités HTML des noms provenant de DATA-03 et refuse toute discordance de nom individuel après normalisation (sans association automatique par nom). Un test compare octet par octet le fichier JSON versionné au résultat déterministe de `build()`. Exemple contrôlé : `lnr:2219` (`MA&#039;AFU` → `MA'AFU`).

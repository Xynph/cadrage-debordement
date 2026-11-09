# Compter les médias Rugby Réel sans partager les identités

Le catalogue le plus large est **Monde + Champ v5** :116clubs dont114jouables,5884fiches joueurs dont5878actifs initiaux après exclusion de6aliases,2160fiches staff dont3historiques. France30 est une autre édition. « Rugby Réel » est une présentation par pack compatible avec l’édition choisie ; le code et ses statistiques ne prouvent pas la disponibilité des photos privées.

Ces volumes de catalogue sont le **snapshot de la base `9011537`**, pas une promesse sur les versions suivantes. Le lot de dédoublonnage `93b3d0e` ramène le catalogue actif à5878fiches en isolant le lecteur legacy ; d’anciens packs à5884IDs restent acceptés. Pour lire une couverture active depuis un reçu local, confronter anonymement les références du pack au registre des6aliases : ne déduire que ceux effectivement présents dans ce pack. SixIDs legacy possibles ne prouvent pas sixpersonnes ou sixportraits nouveaux, et un pack partiel ne contient pas forcément les6. L’outil compte des IDs distincts, sans certifier leur nombre de personnes réelles distinctes. Aucune vérification privée sur le PC n’est acquise ici.

## État connu au9novembre2026

| Périmètre | Compte établi | Preuve |
| --- | --- | --- |
| Catalogue Monde + Champ |116/114clubs,5884/5878joueurs,2160staff | [Audit des cinq éditions](staff-contract-quality-20261109.md), tableau de résultats ; builders production de `ci/staff-contract-quality-audit.cjs` |
| Atlas territorial embarqué |30photos de ville+30de stade pour30clubs français ;60fichiers et SHA vérifiés | `dist/assets/club-atlas/manifest.json` et fichiers correspondants |
| Pack privé Atlas Sayama |86photos de ville+86de stade **documentées par une recette**, sans inventaire privé ouvert dans ce cloud | [Réception immersive](immersive08-coverage.md), paragraphe « Atlas Sayama exact » |
| Ancien pack privé Monde58, version illustrée complète |58logos ; joueurs3103photos déclarées officielles+105illustrations IA ; staff678photos déclarées officielles+130illustrations IA | [Archives Monde privées](world-identity-pack-20261109.md), reçus et SHA des deux ZIP ; [pack français initial](rugby-real-native-packs-20261107.md) |
| Bases locales des portraits fictifs |48bases IA (32joueurs/16staff), compositions réutilisables | [Portraits composés](regen-portraits-20261109.md), `native/godot/art/regen-portraits-manifest.json` |

Les105/130illustrations du ZIPMonde58 comprennent les43joueurs/104staff français préexistants et les62joueurs/26staff ajoutés. Le nom « Illustrations88 » désigne ces88ajouts, pas le total des images IA. Les48bases locales sont un fallback de visages fictifs ; elles ne se comptent pas comme48portraits individuels du pack.

**La répartition exacte des images du pack privé116clubs reste inconnue.** Les reçus d’un autre ZIP ou d’une autre édition ne permettent pas de l’extrapoler. Aucun pack privé ni profil du PC n’a été transféré pour ce travail ; aucune installation actuelle sur le PC n’est certifiée.

## Audit local sur le PC

Le script utilise uniquement Python3 et sa bibliothèque standard. Il lit le ZIP ouvert en lecture seule ; aucune extraction, installation, requête réseau, lecture de profil ou écriture de média. Il n’a pas besoin de lancer le jeu.

```text
python scripts/audit-identity-pack.py "CHEMIN_DU_PACK.zip" --verify-assets
```

La sortie stdout est un unique objet JSON. Pour la conserver, rediriger stdout dans un **nouveau fichier de résumé hors du profil du jeu**. Seul ce résumé agrégé doit être partagé ; conserver le ZIP et ses médias sur le PC. Une commande Windows peut utiliser `py -3` à la place de `python`.

Sans `--verify-assets`, le script calcule les empreintes de l’archive et du manifeste, lit `pack.json` et la table du ZIP. Avec cette option, il lit chaque asset déclaré par blocs pour calculer sa taille réelle et son SHA256. Le ZIP entier n’est jamais chargé en mémoire. Les images ne sont ni décodées ni examinées visuellement.

Formats acceptés : `cd-identity-pack-v1`, `v2`, `v3` avec `pack.json` à la racine ; six databaseId natives connues de France30 à Champv5. Le format historique brut `inventaire.json` et les manifestes d’un dossier déjà installé ne sont pas traités : fournir l’archive native correspondante. Une nouvelle édition inconnue est refusée explicitement, sans prétendre être compatible.

## Lire les comptes

- `clubs.records`, `players.records`, `staff.records` comptent les **lignes présentes dans le manifeste**. `uniqueProfiles` distingue les IDs distincts ; les duplications sont signalées. Cela ne valide pas l’appartenance au catalogue du jeu. Une fiche absente du pack n’est pas silencieusement ajoutée à ces comptes : comparer le `databaseId` et les volumes à l’édition prévue. Le script ne certifie aucune couverture exhaustive116clubs.
- Pour portraits, `byDeclaredStatus.official` signifie `synthetic:false`, `synthetic` signifie `true`, `indeterminate` signifie statut absent ou d’un autre type. C’est la déclaration du pack, **pas une vérification de l’identité réelle ni de l’origine photographique du visage**. `missing` compte les fiches présentes sans référence portrait. Un portrait référencé mais introuvable reste distingué par les compteurs d’incohérence et sa couverture `filePresent:0`.
- `declared` compte les références annoncées ; `filePresent` leur présence dans la table du ZIP. `verified` vaut `null` sans l’option, puis compte les références dont les octets ont une taille et un SHA conformes. La vérification d’octets n’est pas un décodage d’image ni une validation par le moteur.
- `venues.city` et `venues.stadium` comptent les références par club, avec les mêmes trois niveaux. `clubs.logos` distingue les logos référencés, présents et vérifiés.
- `assets.declared` et `uniqueFilesDeclared` comptent les assets et fichiers déclarés ; `totalReferences`, `uniqueAssetsReferenced` et `sharedReferenceSurplus` montrent les réutilisations. Deux joueurs utilisant le même asset donnent2fiches couvertes et1asset unique. `declaredDigestValues` compte des empreintes annoncées distinctes ; `verifiedDigestValues` les empreintes distinctes réellement vérifiées, ou `null`. Plusieurs fichiers identiques ne deviennent pas plusieurs photos uniques.
- `issues` donne seulement des nombres : références non déclarées, fichiers absents, erreurs de taille/empreinte/lecture, statut absent, déclaration IA sans portrait, profils dupliqués ou métadonnées invalides. Aucun nom, ID individuel, URL, chemin de photo, nom du pack ni chemin d’entrée n’est imprimé. Seuls le `databaseId` reconnu et les empreintes agrégées identifient le lot.

Codes de sortie :0rapport obtenu sans incohérence constatée ;2rapport obtenu avec incohérences quantifiées ;1audit impossible (JSON d’erreur à code constant, sans exception ni chemin). Une sortie0 sans vérification des assets ne signifie pas que les images sont vérifiées. Un pack partiel peut être lisible sans incohérence :0n’est pas une certification d’exhaustivité.

## Bornes et tests

Les bornes reprennent les plafonds natifs Monde : ZIP1Gio,9000entrées,1,5Gio décompressé total, manifeste4Mio, asset16Mio. Le répertoire central est borné avant son chargement par `zipfile` ; le manifeste est lu avec une borne explicite. ZIP64, chiffrement, liens symboliques, chemins non normalisables, entrées dupliquées ou schémas non pris en charge sont refusés. Il s’agit d’un inventaire, pas d’un remplacement de l’analyseur d’installation natif (`native/engine/media-packs.cjs`, `venue-media.cjs`).

```text
python tests/audit-identity-pack.py
node --test tests/audit-identity-pack.cjs
```

Les tests produisent uniquement des mini-ZIP fictifs en répertoire temporaire : réel/IA/statut absent/trous, images partagées, fichier et référence manquants, taille et SHA corrompus, versions1/2/3, profils dupliqués, entrée/manifeste bornés, données sensibles sentinelles absentes du JSON et ZIP inchangé. Le wrapper Node utilise `python3` (ou `python` sous Windows) ; `CD_PYTHON_EXECUTABLE` permet de fournir un binaire Python précis. Aucune donnée privée réelle n’est nécessaire pour ces tests.

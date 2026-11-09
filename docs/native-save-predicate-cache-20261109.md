# Cache des prédicats natifs de sauvegarde — 9 novembre 2026

Le test intégré d’académie dépasse de nouveau ses 180 secondes en CI sur `66d6225f6a9d648a8c06929ffc35dfdb7375436f`. Le job 129218532587 du run 42634292026 atteint S2/semaine20 à 149,397 s, puis le plafond avant le dernier checkpoint. Le correctif réduit le coût des validations sans relever le plafond, changer les deux saisons ou retirer les six imports/exports/reprises.

## Changement

`dist/saves.js` mémorise les références de **Number.isFinite**, **Number.isInteger** et **Array.isArray**, puis les réutilise dans `saveNumber`, `saveInt`, `saveObject` et `saveArray`. Ce sont les mêmes fonctions natives, avec les mêmes opérateurs, bornes, types admis, erreurs et ordre d’évaluation. Les intrinsèques du moteur chargé sont capturées une fois ; aucun code exécutable utilisateur n’est chargé dans cette VM. Aucun cache de résultat, confiance dans un import précédent ou raccourci sur les données n’est introduit.

Le schéma, les contrôles de texte/références, les plafonds de taille/nœuds et les gardes du worker restent identiques. Le cache n’est ni sauvegardé ni exposé dans les DTO. Aucun score, population, staff, RNG ou horloge n’est modifié. Aucun paramètre mémoire Node ni seuil CI n’est changé.

## Contrat des prédicats et régressions

Le nouveau témoin conserve les corps précédents des quatre helpers depuis 66d comme références indépendantes. Il compare notamment 840 combinaisons numériques : NaN, infinis avec bornes infinies, −0, limites de précision, fractions, chaînes, objets Number, symboles, bigint, limites invalides et coercitions. Les tests d’objets/tableaux couvrent les tableaux ordinaires/creux, objets sans prototype, tableaux typés, proxies y compris révoqués, ainsi que l’ordre des getters et le court-circuitage.

La fixture de comparaison historique `native-save-hotpaths06` charge désormais aussi la déclaration des intrinsèques lorsqu’elle compile isolément les helpers actuels. Ses corps historiques, cas hostiles et limites restent inchangés.

Les 21 tests ciblés passent sous Node 22.23.4 en 32,1 s : contrat des prédicats, safeTree/checksums historiques, sauvegardes générales, gardes d’intégrité LNR, stress import/rollback et sauvegardes France. Zéro test ignoré.

## Mesure complète, même scénario

Trois exécutions séquentielles de la vraie campagne intégrée utilisent seed 13, horloge 1700000000000, deux saisons complètes et six checkpoints 10/20/34. La borne externe reste 180 s. Le témoin original emploie une copie jetable des fichiers core, dont `saves.js` provient exactement de 66d ; seules les options distDir du runner jetable sont dirigées vers cette copie. Le fichier de test, ses commandes et assertions restent intacts dans le dépôt. Une seule simulation longue de cette lane tourne à la fois.

| Variante | Durée murale s | CPU utilisateur+système s | RSS maximale KiB |
| --- | ---: | ---: | ---: |
| Témoin original 66d | 118,247 | 135,176 | 2 275 168 |
| Cache numérique seul | 108,262 | 125,316 | 1 968 900 |
| Cache numérique + tableau retenu | 98,364 | 115,518 | 1 576 648 |

Gain retenu : **16,81 % de durée murale et 14,54 % de CPU** face au témoin original fraîchement rejoué. Le reçu root précédent passait en 114,689 s ; il reste un repère distinct, pas une mesure remplacée. Ces observations ne constituent pas une garantie sur tous les runners ; la CI distante du dernier SHA reste nécessaire au même plafond 180 s.

## Parité exacte

Les deux saisons et toutes leurs vérifications passent, maximum 5 631 605 octets/352 227 nœuds. La comparaison avec le témoin fraîchement rejoué **et** le profil de référence root `/tmp/native-academy-integrated-xg3JWK` constate une égalité octet pour octet :

| Preuve | Octets | SHA256 |
| --- | ---: | --- |
| Export de fin S2 | 5 631 605 | e701e62c63ae432df1c80c949b8fd8ee05d25f5bb433a9f1bd9465a131880550 |
| Six lignes de checkpoints | 568 | e136e25909873c044b1efe91e0d4325956f171c5f75c3c0b030fe725d08bc099 |
| Profil privé final | 13 234 014 | 34c61b1f8e9a785a054d03f71a6bd932be8a5914fbeecc9abbdb54bb379e3e51 |
| Copie de secours privée | 12 793 947 | 74f81eea0905af6ed3c2875186fc6c0d0ac60e2a748a9b76daa316f0be9ed412 |

Le profil final conserve exactement seed 439148576, horloge 1700000000000 et les stores `bdt-v1`/`bdt-before-import`. Les six checkpoints continuent chacun de vérifier import/export et fermeture/réouverture exacts. Ni leur fréquence ni leurs assertions ne sont réduites.

Reçus de travail : `/workspace/work/save-predicates-{control,candidate,array}-two-season.log`, `save-predicates-parity-receipt.json` et `save-predicates-regressions.log`. Aucun succès de CI distante ni fusion n’est revendiqué par cette réception locale.

# MATCH 3D lot 24 — reprise par étapes courtes

Objectif : publier des personnages anatomiques habillés, animés pour le rugby, avec trois LOD et réception des 30 joueurs offline. PR #300 reste DRAFT jusqu’à qualification complète. Aucun substitut cosmétique.

Chaque étape se termine par un commit publié et vérifié, des tests ciblés et une passation #73. Ne pas relancer une étape déjà acquise. Pas de fusion intermédiaire du lot incomplet.

| Étape | Livrable et contrôle de sortie | État |
| --- | --- | --- |
| 1 — Sources | Quatre GLB, notices CC0, SHA-256 / blobs upstream, audit structurel et ordre des joints | Vérifié localement ; vérifier le commit publié |
| 2 — Assemblage et LOD | Joueur adulte athlétique habillé, géométrie cachée retirée, trois LOD ≤30k / ≤10k / ≤3k triangles, rig et déformations vérifiés | À faire |
| 3 — Animations et intégration | Gestes rugby originaux redistribuables ; 30 squelettes indépendants ; sélecteur LOD et couleurs équipes ; aucun changement moteur/sauvegardes | À faire |
| 4 — Réception | Chromium offline, captures TV/zoom réellement inspectées, non-mutation moteur/sauvegardes, benchmark comparé à lot 23 dans le même environnement | À faire |
| 5 — Intégration finale | Réalignement sur main, CI complète du SHA final, protections, /cd-check puis /cd-merge officiels si VERT, post-fusion 7/7 | À faire |

## Étape 1 — preuve d’acquisition du 5 novembre 2026

Dossier : `dist/match3d/assets/charactercreator-v24/`. Le manifeste contient les SHA-256, les blobs Git et les résultats du parseur existant. Les six blobs (quatre GLB et deux notices) sont identiques à l’arbre GitHub upstream vérifié au commit `852e48f316b90a0937234886630e4fb4cdfd1f78` de `kblood/CharacterCreator`. Les octets ont été retrouvés dans une tentative locale antérieure puis vérifiés, pas supposés acquis à partir d’une annonce.

| Source | Octets | Triangles | Joints | Clips |
| --- | ---: | ---: | ---: | ---: |
| Corps animé | 8 212 156 | 36 924 | 53 | 12 génériques |
| T-shirt | 388 104 | 1 528 | 53 | 0 |
| Short | 242 008 | 862 | 53 | 0 |
| Chaussures | 847 684 | 3 320 | 53 | 0 |
| Total | 9 689 952 | 42 634 | — | — |

Contrôles : GLB 2.0, longueur déclarée, présence de skins et poids, comptage des triangles, absence de dépendances URI externes, mêmes noms et ordre des 53 joints. Le parseur ne constitue pas une certification glTF complète et ne prouve ni l’habillage visuel ni les déformations animées. Test existant : `node tests/match3d-v24-glb-audit.cjs`, huit contrôles synthétiques PASS. Les quatre fichiers réels passent aussi `node tools/match3d-v24-glb-audit.cjs <fichier.glb>`.

Licence : `LICENSE-NOTES.md` upstream distingue explicitement les sorties GLB et animations CC0-1.0 du générateur GPL-3.0-or-later. Notice et `asset_licenses.json` copiés à l’identique ; aucun code du générateur importé. Les douze clips sont génériques, aucun n’est présenté comme un geste rugby dédié. La morphologie de base doit encore être adaptée et inspectée. Les 42 634 triangles sources dépassent la cible LOD0 ; aucune performance en jeu n’est déduite de cet audit.

Aucun changement runtime, aucune nouvelle capture, aucun benchmark, aucun résultat GPU Windows et aucune fusion à cette étape. Préserver PRODUCTEUR/V62, DATA/LNR, moteur, sauvegardes et auto-release. Le main observé au départ est `9ed7a0140755407c988dcee77826d8ab56c85be0` ; la branche #300 demeure fondée sur son ancienne base et devra être réalignée avant la réception finale.

## Jalon 2a — assemblage isolé d’un joueur

Choix : réutiliser les quatre sources publiées via une page de qualification offline, sans modifier le runtime du jeu. `dist/match3d/assets/rugby-v24/assembly.html` charge les quatre GLB, applique aux positions la même morphologie masculine athlétique, puis relie les vêtements aux os du corps par nom (rejet d’un os manquant). Les normales sont recalculées après déformation. Aucun code du générateur GPL importé.

Plan borné : test Node des correspondances d’os ; assemblage ; contrôle Chromium des trois vêtements/53 os et déformations à trois poses ; captures face/dos/profil/course ; publication et vérification sur PR #300. Aperçu à rendu fixe à la demande pour réception logicielle. Les clips restent génériques : le sélecteur fixe une pose, il ne simule pas un match.

Ce jalon ne valide pas la suppression des surfaces cachées, les trois LOD, les gestes rugby, les trente joueurs ni les performances. L’étape 2 globale reste ouverte. Aucun gate ni fusion.

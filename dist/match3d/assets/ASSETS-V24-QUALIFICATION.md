# MATCH 3D Premium — lot 24 : qualification des personnages anatomiques

État au 2026-11-04 : **qualification préalable, intégration refusée tant que les critères ci-dessous ne sont pas satisfaits**. Ce fichier n'est ni une preuve de remplacement 3D ni un benchmark.

## Référence technique vérifiée

- Base `main` : `672b2abcd8d03e5e440ddfd76426ad240236346b`.
- Lot 23 (#299) fusionné, CI post-fusion 7/7, 30 rigs et 11 clips génériques. Rendu toujours low-poly.
- Baseline lot 23, **Linux SwiftShader logiciel** : 13 FPS, 49 géométries, 36 textures. Aucun nombre d'octets VRAM ni résultat sur GPU Windows.
- `dist/match3d/rugby-player-v22.js` est l'adaptateur des joueurs actuel ; ne pas le modifier avant qu'un nouvel asset ait passé le contrôle d'admissibilité.

## Matrice d'actifs et licences (sources des éditeurs)

| Solution | Preuve de licence | Avantage | Lacune bloquante à lever |
| --- | --- | --- | --- |
| MakeHuman / MPFB, core + skins et vêtements **des packs CC0 explicitement étiquetés** | https://www.makehumancommunity.org/about/license.html ; https://www.makehumancommunity.org/assets/assetpacks/index.html | Humains anatomiquement paramétrables, vêtements Shirts 01 / Pants 01, morphologies et exports | Assemblage et habillage réels, rig, export glTF/GLB, triangulation, contrôle des matériaux et clips rugby. Les assets communautaires tiers ont chacun leur licence et ne sont **pas** automatiquement CC0. Les logiciels sources ont des licences AGPL/GPL, distinctes des assets. |
| Quaternius Universal Base Characters, pack daté août 2025, CC0 sur sa fiche | https://quaternius.com/packs/universalbasecharacters.html | 6 humains riggés, ~13k triangles par personnage, glTF/FBX, retarget possible | Anatomie stylisée : **non admissible comme substitution au saut anatomique promis** ; utile comme témoin technique seulement. Confirmer la licence de l'archive précise. |
| Quaternius Universal Animation Library, fiche CC0 | https://quaternius.itch.io/universal-animation-library | 120+ clips humains (course, sprint, poussée, chute), root motion disponible | Ni passe/plaquage rugby ni mêlée certifiés ; clips à retargeter et contrôler sur le rig retenu. |
| Diesel (THEUNSEENVULGA), fiche CC0, GLB annoncé 10 MB | https://theunseenvulga.itch.io/3d-charater-riggeddiesel | Rigged et habillé, ~18.5–19k triangles, meilleur candidat de prototype immédiat | Anatomie et qualité du rig à inspecter dans l'archive, aucune animation rugby dédiée, 30 joueurs non benchmarkés ; fiche CC0 comportant également un avertissement sur la revente du fichier brut, à éclaircir si redistribution libre de l'asset envisagée. |
| Innerscene male base mesh CC0 (lot 23) | voir `ASSETS-V23-LICENSES.md` | Anatomie détaillée, ~109k triangles | Nu, sans tenue/clips ; 30 exemplaires sans LOD non qualifiés. |
| Adobe Mixamo | FAQ éditeur, voir lot 23 | Animations génériques | Ne pas redistribuer des fichiers bruts séparément ; non retenu pour un mod d'assets librement redistribuables. |

**Aucun package complet rugbyman habillé + rig + passe/plaquage/chute/récupération sous licence documentée n'est encore validé.** Aucun modèle externe nouveau n'a été importé dans ce lot.

## Chaîne de production requise (offline et redistribuable)

1. Archiver source, auteur, URL, date, licence exacte et SHA-256 de **chaque fichier** (maillage, textures, vêtements, clips). Refuser les fichiers sans droits de redistribution établis. Versionner la notice de licence.
2. Générer un joueur adulte athlétique **habillé** (maillot manches courtes, short, chaussettes, chaussures), sans géométrie sous les vêtements non visible, avec variations corporelles. Nettoyer les normales, matériaux, UV et squelettes. Export glTF 2.0 / GLB et vérifier hors réseau.
3. Construire des clips distincts : idle, marche, sprint, changement de direction, passe gauche/droite avec ballon, réception, plaquage et plaqué, chute, relevé. Animation sans déplacement direct du moteur sportif : la simulation existante reste la source des évènements et positions.
4. Retargeter les clips avec mapping d'os documenté, vérifier mains/ballon/contact au sol en slow-motion. Les clips de mêlée ou ruck doivent être spécifiques, pas renommage d'une animation de combat générique.
5. Produire trois LOD mesurés et testés : **cibles initiales, non benchmarks** : LOD0 <= 30k triangles / joueur pour cadrage rapproché ; LOD1 <= 10k pour TV moyenne ; LOD2 <= 3k pour plan large. Conserver les déformations, éviter disparition des maillots et popping. Instanciation efficace du rig ou partage des buffers mesh/texture sans partage accidentel de pose/squelette entre joueurs. Pool de matériel par équipe.
6. Vérifier les 30 joueurs hors ligne : 30/30 skinned meshes, aucune requête externe, aucune exception JS, palettes équipes, clips obligatoires et synchronisation évènementielle. Conserver fallback stable si GPU/WebGL absent.
7. Tests ciblés Node de la présence/structure/manifest/licences, puis Chromium réel TV + cadrage zoomé + transitions + sauvegardes et non-mutation du moteur. Vérifier les screenshots manuellement.
8. Benchmark **GPU Windows natif** si runner disponible : au moins 30 s après warmup pour plan TV et zoom, résolution et GPU/driver consignés ; P50/P90 frametime, FPS médian et 1% low, mémoire GPU en octets via outil adéquat, triangles, draw calls, géométries et textures, comparaison stricte lot 23 vs 24. Les compteurs `renderer.info.memory` ne sont PAS de la VRAM. SwiftShader Linux = contrôle fonctionnel, jamais preuve de FPS Windows.
9. Réception seulement si une **différence anatomique nette sur captures zoomées** est démontrée, les animations rugby ne sont pas trompeuses, le benchmark est publié et les tests ne régressent pas. Sinon STOP, aucune fusion.

## Budget prévisionnel (pas une mesure)

30 joueurs * 30k triangles = 900k triangles au pire en vue proche ; avec une distribution indicative de 6 LOD0, 12 LOD1 et 12 LOD2 : 6*30k + 12*10k + 12*3k = **336k triangles**. Cette répartition n'est ni un relevé de scène ni une garantie FPS. La performance sera établie sur les vrais assets par Chrome/GPU Windows.

## Coordination et interdits

Réservation initiale #73 : uniquement ce fichier. Ne pas toucher PRODUCTEUR, V62, DATA/LNR, moteur, sauvegardes, auto-release ni fichiers tiers. Pas de PR de remplacement graphique avant acquisition, vérification des licences de redistribution, examen du modèle habillé et preuve d'animations dédiées. Aucun `/cd-check` ou `/cd-merge` sans PR intégrable et CI terminale verte.

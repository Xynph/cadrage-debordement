# Rugby Réel — Monde, packs privés

Les deux archives appliquent les identités réelles aux mêmes IDs du registre `rugby-world-2026-11-08-v1`. Le contenu d’une carrière, les compétences, le potentiel et les calendriers sont fournis par le registre mondial. Le mod change la présentation. Le registre public des staffs garde les 428 fiches françaises à l’identique et ajoute 380 pseudonymes avec leurs rôles et IDs. Chaque club étranger dispose d’un encadrement documenté, avec des profondeurs de liste différentes selon les publications.

| Archive | Contenu | Octets |
| --- | --- | ---: |
| `Rugby-Reel-Monde-20261109.zip` | 58 logos, 3 208 noms de joueurs, 808 noms de staff et 3 986 médias | 454 165 377 |
| `Rugby-Reel-Monde-20261109-Illustrations-88.zip` | Les mêmes identités et médias, plus 62 illustrations de joueurs et 26 de staff | 455 475 543 |

Le premier ZIP reprend les 2 050 médias français à l’octet près, dont les 104 illustrations de staff déjà signalées. Il ajoute les 28 logos étrangers, 1 554 portraits officiels de joueurs et 354 portraits officiels de staff. 62 joueurs et 26 membres des staffs n’ont pas de photo utilisable dans cette archive. Les emplacements manquants sont listés par ID et source dans le rapport privé. Un fichier officiel dont le SHA256 était correct a été exclu car son image était tronquée. Les portraits étrangers sont convertis en WebP et les logos en PNG, avec une dimension maximale de 512 pixels. Les SVG sont rasterisés dans un navigateur local hors ligne ; le fichier d’origine et son empreinte sont conservés dans les références privées.

Le second ZIP conserve les **3 986 médias du premier à l’octet près**. Il ajoute 88 illustrations d’adultes fictifs et porte l’ensemble à 4 074 médias. Les six planches originales 4 × 4 ont été générées avec l’outil imagegen intégré, sans nom, marque, photo de référence ou ressemblance recherchée. Les 88 tuiles de 307 × 307 pixels ont été examinées sur planches de revue et contrôlées au décodage et par empreinte. Une illustration n’est associée qu’à un ID sans photo. Les 88 nouveaux médias ont `synthetic: true` ; les mentions du pack français sont conservées. Les illustrations ne prétendent pas représenter les personnes dont les fiches portent le nom.

## Compilation privée

`scripts/build-world-identity-pack.py` prend des entrées locales explicites : l’inventaire privé des identités, le ZIP français validé, les racines des médias autorisées, le ZIP de sortie et le chemin de rapport. La conversion nécessite Python avec Pillow ; les badges SVG utilisent un Python avec Playwright et un navigateur déjà disponible, passés en arguments. La commande ne contacte aucun site et n’installe pas le mod dans un profil. Les entrées sont vérifiées par SHA256 ; les archives sont validées avant publication dans le dossier de sortie. `--staff-only` produit le JSON anonyme sans conversion d’image. `--check-staff` le compare au contenu calculé.

Pour créer l’archive illustrée, fournir `--base-world-pack`, `--synthetic-manifest`, `--approved-asset-root`, `--output` et `--report`. Le manifeste des tuiles fixe le SHA256 du premier ZIP, les IDs sans portrait, les empreintes des planches et les coordonnées de découpe. Le compilateur refuse une illustration sur une fiche qui a déjà un portrait, une tuile réutilisée, un fichier modifié ou un ID hors registre. Le ZIP illustré est un fichier distinct. Aucun atlas, média réel ou manifeste nominatif n’est publié dans Git.

Les artefacts privés se trouvent sous `E:/Cadrage-Debordement/mods/` et `E:/Cadrage-Debordement/artefacts/database-europe-20261108/`. Le reçu des sources officielles est `prem/compiler-design/world-identity-pack-report.json` ; `world-identity-pack-source-urls.json` relie les 1 936 médias étrangers officiels à leurs URL d’origine par empreinte. Le dossier `world-illustrations/` contient `generation-plan.json`, les six originaux, les planches de revue, `synthetic-manifest.json` et `archive-receipt.json`.

## Vérification

`node tests/world-identity-build.cjs` compare le registre des staffs à sa base française et vérifie la présence des 58 clubs, l’unicité des IDs et l’absence d’URL ou de chemin privé. Avec le chemin absolu d’un ZIP, le test passe l’archive à l’analyseur du moteur sans l’installer. Ajouter `--complete` pour vérifier que toutes les fiches du ZIP illustré ont une image, que les 88 nouvelles illustrations sont signalées et que les 104 mentions françaises restent présentes.

- SHA256 du ZIP de sources : `24952fa626d3d3005031c18841f3894981b5fb76bfb2d1d6c90c4f05338cf5fa`
- SHA256 du ZIP illustré : `7c52965b7079d62c0e88be56a498ebaf8db35a0928f99f4f28ffa3e0fdf8bc4b`

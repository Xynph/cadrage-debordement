# Silhouettes et tenues de rugby natives — 8 novembre 2026

Le modèle CC0 Quaternius utilisé par le match présentait un pantalon long, une carrure fine et une répétition de cheveux blonds. La nouvelle présentation lui donne un jersey original sobre, un short, des jambes nues et des chaussettes hautes, avec des sections plus athlétiques et des variations déterministes de carnation et de cheveux. Elle conserve son style à facettes : les visages et la forme de coiffure restent ceux du modèle source. Elle ne constitue pas un nouveau modèle photoréaliste.

## Maillage et tenue attachée aux animations

Le fichier GLB et sa licence restent inchangés. Le mesh source `BaseHuman` possède neuf surfaces : Shirt2, Shirt, Skin, Pants, Shoes, Socks, Hair2, Hair et Eyes. La surface Socks ne couvrait que la cheville ; une simple recoloration ne pouvait pas produire une chaussette haute. Le mesh source est Z-up local, sous une rotation et une échelle 100. Ses inverse-bind représentent les bras en T, tandis que les rests du Skeleton montrent déjà les bras baissés.

`native/godot/match_athlete.gd` prépare une copie commune du mesh, autour des axes des inverse-bind. Il élargit les sections du torse, des bras, des cuisses et des mollets avec des raccords progressifs. Les normales sont corrigées par la Jacobienne de cette déformation. Les bones, leurs rests, les clips, les poids et les indices de skinning restent identiques. Le Z des sommets de jambe, les longueurs du squelette, les chaussures, les cheveux et les yeux sont conservés. La calibration d'origine à 1,90 m précède cette préparation.

Les UV/UV2 inutilisés du modèle transportent sa position originale et l'identifiant de sa surface. Le shader `native/godot/shaders/athlete_kit.gdshader` utilise ces attributs de repos interpolés pour placer les limites entre short, peau et chaussette : elles suivent donc les genoux et les hanches animés. Elles ne dépendent ni de la hauteur mondiale, ni d'un instant d'animation. Les panneaux des épaules/flancs et le fin accent de poitrine sont originaux, sans équipement ni logo réel. La couleur principale du club, le détail extérieur et la logique de contraste existante sont préservés par `match_kit.gd`. Les shorts ont désormais une palette explicite, anthracite à domicile et ivoire à l'extérieur.

Le choix parmi six carnations et huit entrées de cheveux sobres utilise un hash explicite de l'id de présentation. Aucun tirage aléatoire, identité de joueur, capacité, position, possession ou contact ne change. Le cache de matériaux est vidé lors d'un changement de palette. Le moteur, les règles, les sauvegardes, `match_motion.gd` et `match_presentation.gd` ne sont pas modifiés par ce lot.

## Budget et limites mesurées

La copie conserve 3 981 sommets et 1 854 triangles, en une seule surface partagée par les trente acteurs. Le shader n'utilise ni texture, ni transparence, ni effet de temps. La fusion ne conserve pas les LOD importés ; le budget des trente athlètes est borné à 55 620 triangles avant les passes d'ombre.

Le prototype externe a été reçu graphiquement sur Windows avec Godot 4.7.2 / OpenGL 3.3 et une GeForce RTX 4080 SUPER. Les captures `motion-060.png`, `action.png` et `tv.png` ont été examinées : le short, les jambes nues, les chaussettes et les variations sont visibles en gardant les caméras précédentes. Les mesures de la même fixture de trente acteurs donnent :

| Profil | Draw calls avant → prototype | Primitives avant → prototype | CPU de projection médian du prototype |
| --- | ---: | ---: | ---: |
| economy | 373 →133 | 352550 →383720 | 0,977ms |
| balanced | 830 →222 | 455684 →526848 | 0,928ms |
| detail | 830 →222 | 462044 →526848 | 0,896ms |

La baisse des appels s'accompagne de 8,8 à 15,6 % de primitives supplémentaires, cohérentes avec la perte des LOD. Les durées d'image restent plafonnées autour de 16,67 ms sur cette carte puissante : elles ne prouvent ni gain de temps GPU, ni compatibilité avec un PC modeste. Cette réception concerne le prototype graphique ; elle ne vaut pas recette d'un nouvel EXE distribué. Les preuves se trouvent hors dépôt dans `E:/Cadrage-Debordement/artefacts/native06-20261108/athlete-study/`.

## Vérifications de l'intégration source

Quatre suites ont été exécutées successivement sous Node 22.23.4 puis Node 26.13.0, en pilotant le même SDK Windows Godot 4.7.2 en mode headless : **4/4 réussies sur chaque version, aucun échec ni test ignoré**.

- `godot-match-silhouettes` vérifie le vrai GLB : source immuable, topologie/poids identiques, 31 bones et 11 clips conservés, poses identiques, normales finies/unitaires, Z des jambes inchangé, attributs de repos précis, mesh partagé, apparences stables et invalidation du cache de palette. L'échantillon de trente ids produit 23 combinaisons. La préparation du mesh commun a pris environ 15 ms sur ces passages ; ce n'est pas un benchmark GPU.
- `godot-match-motion` conserve 150 couples d'appuis mesurables et un glissement maximal de 3,74 mm par image. La première image de réception parcourt 18,9 cm sans téléportation.
- `godot-match-presentation` traverse 180 images de contact : écart maximal poignet/ballon de 21,5 cm et étirement relatif maximal inférieur à 4,1e-7. Les profils d'ombres restent testés.
- `godot-match-framing` conserve les vues/cadrages aux trois tailles, le contraste des jerseys, les détails de club, les marqueurs, la recoloration après changement de pack et les shorts/chaussettes. Il inspecte les uniformes réels du ShaderMaterial, puisque les anciennes surfaces de matériau ont été fusionnées.

Les logs d'intégration sont sous `athlete-integration-node22/` et `athlete-integration-node26/` dans le même dossier d'artefacts. Commande ciblée, avec `CD_GODOT_EXE` défini vers le SDK disponible :

```powershell
node --test --test-concurrency=1 tests/godot-match-silhouettes.cjs tests/godot-match-motion.cjs tests/godot-match-presentation.cjs tests/godot-match-framing.cjs
```

Le mode headless établit ces invariants et le parsing GDScript ; les captures graphiques du prototype établissent l'apparence et la compilation du shader sur la machine citée. Aucun changement de loi de rugby, de format/import de sauvegarde ou d'équilibrage économique n'est inclus.

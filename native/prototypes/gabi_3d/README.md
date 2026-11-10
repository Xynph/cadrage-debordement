# Atelier Gabi 3D · Studio Carnet

L’atelier Studio Carnet part de la [V8](https://github.com/Xynph/cadrage-debordement/tree/prototype/gabi-articulation-v8-20261110/native/prototypes/gabi_3d), témoin de l’articulation. V8 part de la [V7](https://github.com/Xynph/cadrage-debordement/tree/prototype/gabi-nuque-v7-20261110/native/prototypes/gabi_3d). V8 ajoute trois formes de lèvres calées à la main sur « Continue à construire. ». L’arrondi se distingue de face et de trois quarts, jusqu’au portrait de 104 px. La saillie des lèvres se remarque surtout au profil en gros plan.

## Essayer l’atelier

Importer ce dossier dans Godot 4.7.2 puis lancer avec **F5**. L’atelier s’ouvre à 1440 × 900.

- **1 · Repos** lance la boucle bras baissés avec un clignement.
- **2 · Approbation** joue le geste et le hochement puis revient au repos.
- **3 · Parole** joue « Continue à construire. » avec le WAV du jeu, la mâchoire, les trois formes de lèvres et un clignement. **1** interrompt la réplique et remet le visage au neutre.
- **4 · Carnet** cadre le buste et lance la respiration de 5,37 s, carnet en main gauche et bras droit libre. Les trois autres clips se jouent sans le carnet.
- **F**, **P** et **R** cadrent le visage, le profil et la silhouette entière. Dans **Carnet**, **P** montre le profil de la main gauche avec le buste entier. **Buste** recadre les épaules et les mains. Glisser ou utiliser les flèches pour tourner.

La bouche alterne arrondi, ouverture et étirement selon le calage de cette seule réplique. Le prototype utilise des courbes manuelles propres à ce WAV. La cavité sombre et l’absence de dents limitent encore l’expression en gros plan.

## Réception

Le maillage de la bouche comporte une lèvre supérieure, une lèvre inférieure et une cavité. Les poches orbitales suivent le volume balayé par les globes. Deux morphs de paupières se combinent avec celui de la mâchoire sur le même squelette de 20 os. Le GLB de 5 485 392 octets contient deux textures et quatre clips corporels. Le carnet de 354 132 octets est un GLB séparé de 1 488 triangles. Son origine centrale sert à l’attache osseuse de la main gauche.

Le contrôle de bouche échantillonne 59 états à 60 Hz dans les parties actives de la phrase. Huit poses, dont l’arrondi et le clignement simultanés, passent le contrôle Blender. Les 20 os, 180 pistes des trois clips, épaules, positions de repos et morphs hérités correspondent à V7. Les avertissements de proximité des surfaces internes subsistent.

Le correctif de manche s’active seulement dans **Carnet**. Le maillage, les poids, les 180 pistes héritées, les yeux et les 88 tableaux de morphs précédents correspondent à V8. Les 21 poses testées avec le vrai GLB carnet ont zéro paire de triangles corps–carnet en intersection. L’extrémité des doigts touche la couverture. La jonction poignet–manche se remarque encore en gros plan.

La recette Godot vérifie la voix, le repos, le geste, le clignement, le retour des trois formes à zéro et la stabilité de l’attache dans **Carnet**. La revue à l’aveugle compare le mouvement de face, de trois quarts et de profil, ainsi que les portraits natifs de 104 et 136 px.

```powershell
godot --headless --editor --path . --import --quit
godot --path . --script res://verify.gd
```

Ajouter `-- --capture-dir=<dossier existant>` en mode graphique pour écrire les captures et le JSON.

## Sources Blender

La reconstruction part de l’image A-pose et du GLB TRELLIS 1024 stockés sur D:. `build_gabi.py` produit le corps. `build_gabi_regard.py` ouvre les paupières et monte les globes. Les étapes suivantes se lancent dans l’ordre avec Blender 5.2.3 et écrivent leurs fichiers et leurs captures dans le dossier de sortie indiqué après `--`.

| Script sous `blender/` | Scène Blender en entrée | Résultat |
| --- | --- | --- |
| `build_gabi_orbites.py` | `gabi-v5.blend` | `gabi-orbites.blend` |
| `build_gabi_bouche.py` avec `--mode retopo` | `gabi-orbites.blend` | `gabi-bouche-retopo.blend` |
| `build_gabi_paupieres.py` | `gabi-bouche-retopo.blend` | `gabi-clignement-v2.blend` et `gabi.glb` |
| `build_gabi_nuque.py` | `gabi-clignement-v2.blend` | `gabi-nuque.blend` et `gabi_nuque.glb` |
| `build_gabi_articulation.py` | `gabi-nuque.blend` | `gabi-articulation.blend` et `gabi_articulation.glb` |
| `build_gabi_studio_carnet.py` | `gabi-articulation.blend` et poids géodésiques de la manche | `gabi-carnet-studio.blend` et `extraction_carnet.glb` |

Pour reconstruire la scène V8 depuis V7 avec Blender 5.2.3, passer un dossier de sortie existant après `--`. Le GLB V8, témoin avant la pose Carnet, a le SHA-256 `3fc10f16b84d65490796c18213dd7ad82140b77ace249ec8d80bfad54b7ea0d0`.

```powershell
blender -b "$sceneV7" --python-exit-code 1 --python blender/build_gabi_articulation.py -- "$sortie"
```

Le GLB se contrôle avec `verify_glb.py`. Le script de construction teste les poses de lèvres et publie `qa-lip-poses.json`. Les courbes de contrôle sont dans `blender/gabi-articulation-courbes.json`.


La manche géodésique provient de la scène éditable de l’ancien atelier Carnet, conservée localement dans `D:/OvalLegacy-gabi-3d/review/rig-v4-carnet-c/gabi-carnet.blend`. La scène V8 est dans `D:/OvalLegacy-gabi-3d/review/v7-articulation/reconstruction-branche/gabi-articulation.blend`. Blender 5.2.3 reconstruit le GLB Studio à l’octet près.

```powershell
blender -b "$sceneCarnetAncien" --python-exit-code 1 --python blender/extract_carnet_sleeve_weights.py -- "$sortie/poids-manche.npz"
blender -b "$sceneV8" --python-exit-code 1 --python blender/build_gabi_studio_carnet.py -- "$sortie" --sleeve "$sortie/poids-manche.npz"
blender -b "$sortie/gabi-carnet-studio.blend" --python-exit-code 1 --python blender/verify_notebook_contact.py -- "$sortie/contact.json" "./carnet.glb"
```

Copier `extraction_carnet.glb` sous le nom `gabi.glb`. Son SHA-256 est `586e13ed5ed87a67b0fb37021713a8463a795e430456588e6412698d9a9c5736`. Le script `verify_studio_parity.py` compare les GLB V8 et Studio, y compris les attributs glTF creux. La notice décrit la provenance du carnet et les fichiers Blender locaux.

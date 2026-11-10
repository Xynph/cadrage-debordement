# Atelier Gabi 3D · Articulation V8

L’atelier V8 part de la [V7](https://github.com/Xynph/cadrage-debordement/tree/prototype/gabi-nuque-v7-20261110/native/prototypes/gabi_3d). Il ajoute trois formes de lèvres calées à la main sur « Continue à construire. ». L’arrondi se distingue de face et de trois quarts, jusqu’au portrait de 104 px. La saillie des lèvres se remarque surtout au profil en gros plan.

## Essayer l’atelier

Importer ce dossier dans Godot 4.7.2 puis lancer avec **F5**. L’atelier s’ouvre à 1440 × 900.

- **1 · Repos** lance la boucle bras baissés avec un clignement.
- **2 · Approbation** joue le geste et le hochement puis revient au repos.
- **3 · Parole** joue « Continue à construire. » avec le WAV du jeu, la mâchoire, les trois formes de lèvres et un clignement. **1** interrompt la réplique et remet le visage au neutre.
- **F**, **P** et **R** cadrent le visage, le profil et la silhouette entière. Glisser ou utiliser les flèches pour tourner.

La bouche alterne arrondi, ouverture et étirement selon le calage de cette seule réplique. Le prototype utilise des courbes manuelles propres à ce WAV. La cavité sombre et l’absence de dents limitent encore l’expression en gros plan.

## Réception

Le maillage de la bouche comporte une lèvre supérieure, une lèvre inférieure et une cavité. Les poches orbitales suivent le volume balayé par les globes. Deux morphs de paupières se combinent avec celui de la mâchoire sur le même squelette de 20 os. Le GLB de 5 246 516 octets contient deux textures et les trois clips corporels.

Le contrôle de bouche échantillonne 59 états à 60 Hz dans les parties actives de la phrase. Huit poses, dont l’arrondi et le clignement simultanés, passent le contrôle Blender. Les 20 os, 180 pistes des trois clips, épaules, positions de repos et morphs hérités correspondent à V7. Les avertissements de proximité des surfaces internes subsistent.

La recette Godot vérifie la voix, le repos, le geste, le clignement et le retour des trois formes à zéro. La revue à l’aveugle compare le mouvement de face, de trois quarts et de profil, ainsi que les portraits natifs de 104 et 136 px.

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

Pour reconstruire V8 depuis la scène V7 avec Blender 5.2.3, passer un dossier de sortie existant après `--`, puis copier le GLB obtenu sous le nom `gabi.glb`. Deux exécutions ont donné le SHA-256 `3fc10f16b84d65490796c18213dd7ad82140b77ace249ec8d80bfad54b7ea0d0`.

```powershell
blender -b "$sceneV7" --python-exit-code 1 --python blender/build_gabi_articulation.py -- "$sortie"
```

Le GLB se contrôle avec `verify_glb.py`. Le script de construction teste les poses de lèvres et publie `qa-lip-poses.json`. Les courbes de contrôle sont dans `blender/gabi-articulation-courbes.json`.

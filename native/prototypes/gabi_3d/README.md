# Atelier Gabi 3D · Visage V7

L’atelier V7 part de la [V6](https://github.com/Xynph/cadrage-debordement/tree/prototype/gabi-visage-v6-20261110/native/prototypes/gabi_3d). Il affine deux mèches de la nuque qui ressortaient en profil. À 136 px, deux relectures à l’aveugle préfèrent la nouvelle silhouette. Les rendus de face, les épaules, les trois clips et le WAV de V6 sont préservés. L’atelier permet de juger Gabi sans lancer de carrière.

## Essayer l’atelier

Importer ce dossier dans Godot 4.7.2 puis lancer avec **F5**. L’atelier s’ouvre à 1440 × 900.

- **1 · Repos** lance la boucle bras baissés avec un clignement.
- **2 · Approbation** joue le geste et le hochement puis revient au repos.
- **3 · Parole** joue « Continue à construire. » avec le WAV du jeu, des accents de mâchoire et un clignement. **1** interrompt la réplique et remet le visage au neutre.
- **F**, **P** et **R** cadrent le visage, le profil et la silhouette entière. Glisser ou utiliser les flèches pour tourner.

La bouche suit le rythme d’une seule réplique. Le prototype ne forme pas de visèmes. Les commissures restent rigides et le profil de la barbe et du nez s’écarte de la planche validée en gros plan.

## Réception

Le maillage de la bouche comporte une lèvre supérieure, une lèvre inférieure et une cavité. Les poches orbitales suivent le volume balayé par les globes. Deux morphs de paupières se combinent avec celui de la mâchoire sur le même squelette de 20 os. Le GLB de 4 634 820 octets contient deux textures et les trois clips corporels.

Les trois poses de bouche, les 26 combinaisons de paupières et de mâchoire, et le retour après export ont été contrôlés. Le test BVH ne détecte aucune intersection des globes avec la peau ou les parois des poches sur ces poses. Blender signale des surfaces internes de normales opposées à moins d’un millimètre. Les coordonnées UV des deux matières texturées se chevauchent sur le maillage global et leurs images sont distinctes.

Sous Godot Windows, la recette de l’atelier passe 35 contrôles à 1440 × 900, dont la lecture de la voix, le clignement au repos et la coexistence des morphs en parole. La lecture indépendante a comparé la pose neutre et la pose animée à 104 × 104 et 136 × 136 pixels, puis inspecté les clignements image par image.

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

Pour reconstruire V7 depuis la scène V6 avec Blender 5.2.3, passer un dossier de sortie existant après `--`, puis copier le GLB obtenu sous le nom `gabi.glb`. Deux exécutions ont donné le SHA-256 `739f86bdda1322153fbf174daa5c9de0c2e6c2cf7e107bd4f01dbf0e8c066baa`.

```powershell
blender -b "$sceneV6" --python-exit-code 1 --python blender/build_gabi_nuque.py -- "$sortie"
```

Le GLB se contrôle avec `verify_glb.py`. `verify_globe_intersections.py` s’exécute sur `gabi-nuque.blend` et produit les comptages par pose.

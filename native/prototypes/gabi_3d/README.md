# Atelier Gabi 3D · Regard V5

La variante V5 ouvre les paupières et remplace le regard peint par deux globes en volume. L’atelier de référence garde sa [branche V3](https://github.com/Xynph/cadrage-debordement/tree/prototype/gabi-3d-20261110/native/prototypes/gabi_3d).

Ce projet Godot séparé permet de juger le prototype du coach sans lancer de carrière. Le personnage du jeu reste en 2D.

## Essai local

Ouvrir ce dossier comme projet dans Godot 4.7.2 puis lancer avec F5. Le projet s’ouvre en 1440 × 900, à la taille de référence du jeu.

- **1** joue la boucle de repos, bras baissés.
- **2** joue le geste d’approbation et le hochement, puis reprend le repos.
- **3** joue une réplique déjà présente dans Oval Legacy avec une gestuelle dédiée. La bouche reste fixe.
- **F**, **P** et **R** cadrent le visage, le profil et la silhouette entière. Glisser dans la scène ou utiliser les flèches pour tourner autour de Gabi.

En ligne de commande, importer avec `godot --headless --editor --path . --import --quit` puis lancer avec `godot --path .`. La recette s’exécute avec `godot --path . --script res://verify.gd`. En mode graphique, ajouter `-- --capture-dir=<dossier existant>` pour enregistrer les cinq vues et le rapport JSON.

## Réception du prototype

Le candidat TRELLIS.2 en 512 conservait le gabarit mais écrasait les yeux et la bouche. Le candidat 1024 local a servi de base au rig. La texture de l’image d’entrée en A-pose a été projetée sur la zone frontale du visage avec des bords progressifs. Le matériau mat et la correction localisée de la lèvre réduisent l’aspect cireux.

Le GLB pèse 3 518 360 octets. Il contient le corps de 70 474 triangles à 1,80 m, deux globes de 1 280 triangles, une texture, le squelette de 20 os et trois animations. Les globes suivent la tête et les iris sont formés par des anneaux de géométrie. Le nez et la barbe ont été adoucis de quelques millimètres, et la commissure remontée de manière asymétrique.

La recette Blender ne relève aucune erreur de maillage ni de scintillement potentiel et retrouve les 11 contacts internes du pull. Les contrôles Godot Windows couvrent les trois clips à 1440 × 900. Le balayage rapproché de part et d’autre vérifie les profils. Les deux versions ont aussi été comparées à 136 × 136 et 104 × 104 pixels, les tailles du portrait du guide.

La planche approuvée reste la cible d’identité. Le regard reste fixe. La chaleur de la planche, le profil nez–menton et les mèches demandent encore un travail de sculpture. La bouche fermée du maillage et ses boucles faciales ne permettent pas une articulation fiable. La réplique « Continue à construire. » utilise exactement le WAV existant du manifeste du jeu. Voir la notice de provenance de la voix.

## Reproduire le GLB

Les sources lourdes et la scène Blender éditable sont locales sur D:. Reconstruire d’abord le corps à partir de la variante 1024 et de l’image d’entrée.

```powershell
& 'E:/blender.exe' -b --factory-startup --python-exit-code 1 -P ./blender/build_gabi.py -- 'D:/OvalLegacy-outils-3d/trellis2/output/gabi-1024-review-20261110_00001.glb' 'D:/OvalLegacy-gabi-3d/review/rebuild' --review-only --mute-normal-map --reference 'D:/OvalLegacy-outils-3d/trellis2/input/gabi-reference-a-pose.png'
```

Le second script sculpte et ouvre les paupières, monte les yeux, puis écrit le GLB et les vues de contrôle.

~~~powershell
& 'E:/blender.exe' -b 'D:/OvalLegacy-gabi-3d/review/rebuild/gabi.blend' --python-exit-code 1 -P ./blender/build_gabi_regard.py -- 'D:/OvalLegacy-gabi-3d/review/rebuild-regard'
~~~

La reconstruction dépend de Blender 5.2.3 et du candidat 1024 dont le SHA-256 est `d9661d2f428c1ab5012e7676e2174d0d73990944a4a93ab6f5062a1d8fcd0160`.

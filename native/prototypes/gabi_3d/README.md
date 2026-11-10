# Atelier Gabi 3D

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

Le GLB embarque un maillage de 69 998 triangles à 1,80 m, une texture, un squelette de 20 os et trois animations. Il pèse 3 372 420 octets. Le retour Blender contrôle jusqu’à quatre influences normalisées par sommet. La recette Blender ne signale aucune erreur et relève 11 paires de faces internes dos à dos. Les poses bras baissés, bras ouverts, geste d’approbation, vue arrière et trois quarts ont été inspectées. La recette Godot Windows a passé 29 contrôles à 1440 × 900.

La planche approuvée reste la cible d’identité. Le regard, l’oreille et la découpe moustache-barbe gardent des approximations visibles au gros plan. La bouche fermée du maillage et ses boucles faciales ne permettent pas une articulation fiable. La réplique « Continue à construire. » utilise exactement le WAV existant du manifeste du jeu. Voir la notice de provenance de la voix.

## Reproduire le GLB

Les sources lourdes et la scène Blender éditable sont locales sur D:. Le script Blender accepte la variante 1024 et l’image d’entrée :

```powershell
& 'E:/blender.exe' -b --factory-startup --python-exit-code 1 -P ./blender/build_gabi.py -- 'D:/OvalLegacy-outils-3d/trellis2/output/gabi-1024-review-20261110_00001.glb' 'D:/OvalLegacy-gabi-3d/review/rebuild' --mute-normal-map --reference 'D:/OvalLegacy-outils-3d/trellis2/input/gabi-reference-a-pose.png'
```

Le script écrit le fichier Blender, le GLB et les vues de contrôle. La reconstruction dépend de Blender 5.2.3 et du candidat 1024 dont le SHA-256 est `d9661d2f428c1ab5012e7676e2174d0d73990944a4a93ab6f5062a1d8fcd0160`.

# Atelier Gabi 3D

Cette variante ajoute le carnet de la planche validée. L’atelier de référence sans carnet reste sur la branche [prototype/gabi-3d-20261110](https://github.com/Xynph/cadrage-debordement/tree/prototype/gabi-3d-20261110/native/prototypes/gabi_3d).

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

Le GLB embarque le maillage de 69 998 triangles à 1,80 m, un squelette de 20 os, trois animations, deux textures et le carnet de 648 triangles. Il pèse 3 445 364 octets. Le carnet en cuir texturé est attaché à la main gauche dans les trois clips. L’approbation laisse la main droite libre. La séparation géodésique des manches au niveau des aisselles réduit l’étirement du pull dans la pose avec carnet.

La recette Blender ne signale aucune erreur ni scintillement potentiel entre faces orientées dans le même sens. Les 10 contacts dos à dos du corps sont à l’intérieur des plis d’aisselle. Les 8 autres contacts correspondent aux deux faces des onglets en papier, épaisses de 0,9 mm. Le retour GLB contrôle jusqu’à quatre influences normalisées par sommet. La recette Godot Windows a passé 34 contrôles à 1440 × 900, dont l’attache à la main animée, le geste libre et la remise à zéro du cadrage.

La planche approuvée reste la cible d’identité. Le regard, l’oreille et la découpe moustache-barbe gardent des approximations visibles au gros plan. L’essai de paupières corrigées a été écarté après revue du regard fixe et de la projection des iris. La bouche fermée du maillage et ses boucles faciales ne permettent pas une articulation fiable. La réplique « Continue à construire. » utilise exactement le WAV existant du manifeste du jeu. Voir la notice de provenance de la voix.

## Reproduire le GLB

Les sources lourdes et la scène Blender éditable sont locales sur D:. Le script Blender accepte la variante 1024 et l’image d’entrée :

```powershell
& 'E:/blender.exe' -b --factory-startup --python-exit-code 1 -P ./blender/build_gabi.py -- 'D:/OvalLegacy-outils-3d/trellis2/output/gabi-1024-review-20261110_00001.glb' 'D:/OvalLegacy-gabi-3d/review/rebuild' --review-only --mute-normal-map --reference 'D:/OvalLegacy-outils-3d/trellis2/input/gabi-reference-a-pose.png'
```

Le premier script écrit la scène et les vues de contrôle du corps. Ajouter le carnet et produire le GLB avec cette scène Blender comme entrée.

~~~powershell
& 'E:/blender.exe' -b 'D:/OvalLegacy-gabi-3d/review/rebuild/gabi.blend' --python-exit-code 1 -P ./blender/build_carnet.py -- 'D:/OvalLegacy-gabi-3d/review/rebuild-carnet'
~~~

La reconstruction dépend de Blender 5.2.3 et du candidat 1024 dont le SHA-256 est `d9661d2f428c1ab5012e7676e2174d0d73990944a4a93ab6f5062a1d8fcd0160`.

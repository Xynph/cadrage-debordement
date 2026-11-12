# Animations de déplacement adaptées au joueur du match (11 novembre 2026)

## Ce que fait cette branche

Le joueur du match 3D (`assets/match3d/quaternius-rugby-athlete.glb`, 31 os) n'avait que trois clips utiles : repos, marche, course. Cette branche permet de lui brancher une bibliothèque d'animations venues d'un autre squelette (Mixamo, 65 os), converties hors jeu.

- **Éteint par défaut.** Sans la variable `CD_MATCH_ANIMATIONS`, rien n'est chargé et le match est identique.
- Sans variable, le jeu cherche aussi `animations/mixamo-match.res` à côté de son exécutable (voir `docs/gabi-mixamo-20261111.md`).
- `CD_MATCH_ANIMATIONS=<chemin absolu d'un .glb>` : la bibliothèque est lue au lancement du match et ajoutée au lecteur d'animation de chaque joueur (bibliothèque `mx`).
- **Première étape : les déplacements seulement.** Repos, puis quatre paliers selon la vitesse au sol (marche, trot, course, sprint) au lieu de deux, avec hystérésis. L'animation avance toujours à la distance parcourue.
- Les gestes (touche, passe, plaquage, essai) restent ceux de `match_gestes.gd`. Les autres clips de la bibliothèque (lancer, réception, plaqué, relevé, coup de pied, joie…) sont chargés mais pas encore joués : c'est l'étape suivante.
- Fichier introuvable, illisible ou incomplète (un palier manquant) : avertissement, clips d'origine conservés.

## Pourquoi la bibliothèque n'est pas dans le dépôt

Les animations d'origine viennent de Mixamo (compte Adobe de Léo). La licence autorise leur usage dans un jeu, pas la redistribution des fichiers. Le dépôt est public : ni les `.fbx` ni la bibliothèque convertie n'y entrent. Un test le vérifie (`tests/godot-match-animations.cjs`).

**Décision à prendre avant toute livraison** : où vit la bibliothèque convertie (dépôt privé `rugby-reel-donnees` récupéré à la construction, comme le pack, ou autre), et comment la chaîne de livraison Windows la récupère. Tant que ce n'est pas décidé, le drapeau reste un outil de développement et de capture.

## Conversion (hors jeu)

Outils dans `scripts/animations/`, à lancer avec Blender en module Python (`pip install bpy`, vérifié avec 5.3.0) :

| Script | Rôle |
| --- | --- |
| `analyser-animations.py` | Mesure chaque `.fbx` : os, durée, déplacement net, amplitude, écart de boucle. |
| `adapter-animations.py` | Convertit une liste de `.fbx` vers le squelette du joueur et écrit la bibliothèque `.glb` (squelette seul) et un fichier de mesures. |
| `bibliotheque-match.json` | Liste des 28 clips de la première bibliothèque (noms de fichiers Mixamo, relatifs au dossier donné par `--racine`). |
| `planche-contact.py`, `apercu-video.py` | Contrôle visuel hors jeu (planche d'images, vidéo d'aperçu) à partir de la sortie `.blend`. |
| `convertir-bibliotheque.gd` | Convertit la bibliothèque `.glb` en ressource Godot `.res`, forme conseillée pour `CD_MATCH_ANIMATIONS` (lecture directe, sans reconstruire de scène). |
| `exporter-personnage-mixamo.py` | Prépare un personnage du jeu (Gabi) pour « Upload Character » de Mixamo. |

```
python3 scripts/animations/adapter-animations.py -- \
  native/godot/assets/match3d/quaternius-rugby-athlete.glb \
  scripts/animations/bibliotheque-match.json \
  /chemin/hors-depot/mixamo-match.glb /chemin/hors-depot/mixamo-match.json \
  --racine /chemin/vers/les/fbx --sans-maillage
```

Méthode : les deux squelettes sont en pose T au repos. Pour chaque os, on prend la rotation monde de la source par rapport à son repos et on l'applique au repos du joueur. Le déplacement du bassin est mis à l'échelle des jambes (horizontal) et de la hauteur du bassin (vertical) ; il est retiré pour les boucles de déplacement (`sur_place`). Particularité du joueur : ses pieds sont des os libres sous la racine (ancien rig à cinématique inverse), ils sont donc recollés au bout du tibia à chaque image, et le corps est remonté si un pied passerait sous le sol.

## Vérifié

- `tests/godot-match-animations.cjs` (Godot 4.7.2 Linux, sans écran) : 78 contrôles. Sans variable, fichier absent, bibliothèque incomplète : joueurs inchangés. Bibliothèque complète (fabriquée par le test à partir des clips d'origine, aucun fichier tiers) : 30 joueurs équipés, toutes les pistes visent le squelette, repos / marche / trot / course / sprint selon la vitesse, retour au repos, hystérésis.
- Vraie bibliothèque de 28 clips chargée dans le match sous Linux sans écran : 868 pistes, aucune non résolue.
- Conversion relancée depuis les outils du dépôt : mesures identiques.
- Contrôle visuel hors jeu (planches et vidéo d'aperçu) : marche, trot, course, sprint, crochet, lancer en touche, réception, plaqué, relevé, coup de pied.

## Recette Windows du 11 novembre (PC de Léo)

- `godot-match-animations` : vert.
- Capture avant/après sur la séquence de gestes (touche, ballon porté, essai), rendu actuel (gl_compatibility) : 246 images de chaque côté, sans erreur.
- **Forward+ (rendu moderne) : plantage immédiat avec la bibliothèque `.glb`** (code Windows 0xC0000374, corruption du tas, aucun message de Godot). Sans bibliothèque, Forward+ fonctionne. Cause supposée, non démontrée : la reconstruction d'une scène glTF pendant l'exécution. Avec la ressource `.res` préparée hors jeu, Forward+ passe (lot « animations-res » : 246 images en gl_compatibility et 246 en Forward+ élevé, aucune erreur). Le `.glb` reste accepté mais n'est plus conseillé.
- Constat visuel : sur ces images, les joueurs liés au ballon porté sont posés par `match_gestes.gd` ; le reste se tient différemment (repos plus droit). La séquence ne contient presque pas de course : elle ne permet pas de juger les paliers de déplacement.

## Non vérifié / limites

- **Aucune image du match réel avec la bibliothèque** au moment de ce commit (ni Linux, ni Windows). L'interaction avec les couches existantes n'a pas été regardée : appuis au sol (`Presentation.support_feet`), crochets (`match_cut.gd`), tenue du ballon, gestes. C'est la première chose à capturer sur le PC.
- Les proportions diffèrent (cuisse courte du joueur) : les pieds flottent de quelques centimètres en course. La correction d'appuis du jeu devrait l'absorber, à constater.
- Les fondus entre paliers ne sont pas synchronisés sur la foulée (fondu simple de 0,18 s).
- « Run To Dive » de Mixamo est un plongeon vers le bas (dans l'eau) : inutilisable pour un essai. Le clip `mx_plongeon` vient d'un arrêt de gardien, à remplacer.
- Mixamo n'a aucun geste propre au rugby (passe à deux mains, mêlée, ruck, ascenseur) : à produire autrement.
- Cette branche part de #570 (rendu moderne), qui contient #554 (gestes).

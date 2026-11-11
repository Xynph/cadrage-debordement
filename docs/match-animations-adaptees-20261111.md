# Animations de déplacement adaptées au joueur du match (11 novembre 2026)

## Ce que fait cette branche

Le joueur du match 3D (`assets/match3d/quaternius-rugby-athlete.glb`, 31 os) n'avait que trois clips utiles : repos, marche, course. Cette branche permet de lui brancher une bibliothèque d'animations venues d'un autre squelette (Mixamo, 65 os), converties hors jeu.

- **Éteint par défaut.** Sans la variable `CD_MATCH_ANIMATIONS`, rien n'est chargé et le match est identique.
- `CD_MATCH_ANIMATIONS=<chemin absolu d'un .glb>` : la bibliothèque est lue au lancement du match et ajoutée au lecteur d'animation de chaque joueur (bibliothèque `mx`).
- **Déplacements.** Repos, puis quatre paliers selon la vitesse au sol (marche, trot, course, sprint) au lieu de deux, avec hystérésis. L'animation avance toujours à la distance parcourue.
- **Gestes (ajout du 11 novembre au soir, voir plus bas).** Lancer en touche, réception, plaqué puis relevé, plaquage, coup de pied et drop, joie et déception sont joués une fois sur les faits du moteur ; les poses procédurales de `match_gestes.gd` restent le repli quand un clip manque.
- Fichier introuvable, illisible ou incomplète (un palier manquant) : avertissement, clips d'origine conservés.

## Gestes joués avec la bibliothèque (11 novembre au soir)

Toujours sans effet sans `CD_MATCH_ANIMATIONS`. Interface de la vue : `NativeMatchView.jouer_geste(id, nom, début, fin, ancré, suite)` joue un clip une fois, au temps (et non à la distance), puis rend la main au déplacement ; `geste_adapte(id)` dit si un geste adapté est en cours (le geste procédural correspondant ne s'applique pas). Faux sans bibliothèque ou sans le clip : l'appelant garde sa pose procédurale.

| Fait du moteur | Qui | Clip | Calage |
| --- | --- | --- | --- |
| Touche (geste de `match_gestes.gd`) | lanceur | `mx_lancer_touche` | lâcher du clip (1,55 s) à l'instant du lancer du geste ; le ballon reste entre les paumes du clip jusque-là |
| `goal`, `miss` (pénalité, transformation), `kick` | joueur mis en avant | `mx_coup_de_pied` | contact du pied (0,75 s) au départ du ballon ; la course d'élan est coupée |
| `kickoff`, `drop22`, `goalLine` | botteur, seulement s'il est au ballon | `mx_drop` | contact (2,05 s) au départ du ballon |
| `reception` | receveur | `mx_reception_haute` après un jeu au pied, sinon `mx_reception` | prise ; le clip est coupé juste après (sa suite d'origine est une chute) |
| fin de course `carry` (régie des temps forts) | porteur, adversaire le plus proche à 4 m | `mx_plaque_cote` ou `mx_plaque_jambes`, puis `mx_se_relever` ; `mx_plaquage` | impact au sol 0,35 s après le contact ; le joueur au sol garde sa place, puis rejoint celle de la scène ; pas de plaquage avant l'essai du même temps fort, ni sans adversaire à 4 m dans la scène (le porteur ne tombe pas seul) |
| essai aplati | marqueur ; partenaires proches ; trois adversaires les plus proches | `mx_se_relever` puis `mx_joie_poing` ; `mx_joie` / `mx_joie_poing` ; `mx_deception` | 0,3 s après l'aplatissement ; le geste tient l'image 2,6 s au lieu de 1,6 s |

Les clips qui se déplacent (élan du lancer et du coup de pied, chute du plaqué) sont ramenés sur place au chargement (`_retirer_deplacement` : déplacement horizontal du bassin retiré, verticale gardée) : le joueur reste où la scène le place.

Ballon porté : la défense engage aussi les deux autres avants de son alignement, liés sur les flancs (cinq défenseurs liés au lieu de trois, les deux autres restaient debout à côté). Mesuré sur la séquence témoin : défenseurs liés penchés de 44 à 46° avec la bibliothèque, 28 à 43° sans (inclinaison tête-bassin). Le repos Mixamo n'écrase pas la pose de liaison : les liés gardent leur posture ; c'étaient les défenseurs non liés qui restaient droits.

Test : `tests/godot-match-gestes-adaptes.cjs` (bibliothèque fabriquée à partir des clips d'origine du joueur : contrôle de l'enchaînement, pas de l'allure des clips). Contrôle visuel avec la vraie bibliothèque : séquence témoin (Xvfb, rendu logiciel) et vidéos de la PR.

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
- « Run To Dive » de Mixamo est un plongeon vers le bas (dans l'eau) : inutilisable pour un essai. Le clip `mx_plongeon` vient d'un arrêt de gardien, à remplacer ; il n'est pas joué (le plongeon de l'essai reste procédural).
- Les clips de réception d'origine finissent par une chute : seule la prise est jouée. Le lancer de touche Mixamo est une remise en jeu de football (deux mains au-dessus de la tête), sans élan une fois ramené sur place.
- Mixamo n'a aucun geste propre au rugby (passe à deux mains, mêlée, ruck, ascenseur) : à produire autrement.
- Cette branche part de #570 (rendu moderne), qui contient #554 (gestes).

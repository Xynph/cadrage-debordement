# Gabi rigué par Mixamo, avec ses gestes (11 novembre 2026)

## Ce que fait cette branche

Léo a fait riguer Gabi par Mixamo (squelette Mixamo de 33 os, textures et formes de bouche conservées). Les gestes de Mixamo ont été adaptés à ce squelette (27 clips). Cette branche branche ce nouveau Gabi dans le guide, **sans rien changer quand ses fichiers sont absents**.

- Recherche du fichier (`native/godot/donnees_privees.gd`) : la variable `CD_GABI_MIXAMO` (chemin absolu), sinon `animations/gabi-mixamo.scn` à côté de l'exécutable du jeu. Rien trouvé, fichier illisible ou sans clip `repos` : Gabi d'origine (`guide/assets/gabi.glb`), avec un simple avertissement si un chemin était donné.
- Même règle pour le match : `CD_MATCH_ANIMATIONS`, sinon `animations/mixamo-match.res` à côté de l'exécutable (`match_animations.gd`, voir `docs/match-animations-adaptees-20261111.md`).
- Le fichier est une scène Godot `.scn` préparée hors jeu : le jeu ne reconstruit aucune scène glTF pendant l'exécution (cause supposée du plantage Forward+ sous Windows constaté avec la bibliothèque du match).

## Correspondance des clips (`coach_portrait_3d.gd`)

La logique de choix et de fondu est celle du Gabi d'origine (fondu 0,2 s, salut à la première ouverture, approbation sur la composition et le résultat, microgestes au minuteur, mouvement réduit, guide masqué). Le Gabi Mixamo est reconnu à son clip `repos`.

| Rôle | Gabi d'origine | Gabi Mixamo |
| --- | --- | --- |
| Repos (boucle) | Repos | repos |
| Salut | Salut | salut |
| Explication | Explication | explique, montre, insiste (au hasard, sans répétition immédiate) |
| Approbation | Approbation | approuve, approuve_fort (au hasard) |
| Microgestes | Ecoute, RegardCarnet | regarde_bas (≈ RegardCarnet), appui, reflechit (≈ Ecoute), repos_respire, puis la même série avec baille à la place de repos_respire |
| Pendant la parole | — (bouche seule) | parle, parle_2, parle_3, parle_4 enchaînés au hasard, sans répétition immédiate |
| Délai entre microgestes | 7 à 13 s | 3 à 6 s |

Demande de Léo : Gabi toujours en mouvement. D'où des pauses plus courtes et les gestes de parole. Un geste en cours (salut, approbation, explication) se termine avant le geste de parole. La bouche reste pilotée par le jeu (formes MouthOpen, MouthRound, MouthPress, MouthWide).

Avis : le bâillement est un geste fort pour un adjoint qui guide le manager. Il est gardé, comme demandé, mais une seule fois sur huit microgestes (environ une fois par minute et demie, guide ouvert et silencieux). À retirer de la liste si l'effet est mauvais à l'usage.

Clips présents mais pas encore joués : argumente, refuse, hausse, sceptique, remercie, decu, rit, surpris, content, tablette, applaudit. Ils pourront servir quand le guide connaîtra le ton de sa réplique (bonne ou mauvaise nouvelle).

## Fichiers privés et construction

Licence Mixamo : usage dans le jeu permis, redistribution des fichiers interdite. Rien d'issu de Mixamo n'entre dans ce dépôt public (un test le vérifie : `tests/godot-gabi-mixamo.cjs`). Les fichiers sont dans le dépôt privé `rugby-reel-donnees`, dossier `animations/` (branche `claude/animations-mixamo-20261111`).

Aujourd'hui, le jeu livré ne récupère aucune donnée privée : la chaîne Windows (`windows-release.yml`, `build-godot-prototype.py`, `ci/windows-package.py`) tourne dans le dépôt public, sans secret, et le pack Rugby Réel reste sur le PC de Léo, importé depuis le jeu.

**Proposition retenue ici : poser les fichiers après l'installation, pas à la construction.** Le ZIP produit par la chaîne Windows est publié dans les Releases d'un dépôt public : y ajouter les fichiers Mixamo serait une redistribution. Le jeu lit donc un emplacement fixe à côté de son exécutable, et une commande pose les fichiers sur le PC :

```
python3 scripts/animations/poser-animations-privees.py <clone de rugby-reel-donnees> <dossier du jeu>
```

Elle copie `gabi-mixamo.scn` et `mixamo-match.res` dans `<dossier du jeu>/animations/` et vérifie leur empreinte. Ni la chaîne de livraison ni ses secrets ne changent. Si un jour un paquet privé non publié est construit, la même étape s'y ajoute après l'export (copie dans `animations/` à côté de l'exécutable), avec un jeton de lecture du dépôt privé ; à décider avec Léo.

Pour désactiver le nouveau Gabi sur un PC : retirer `animations/gabi-mixamo.scn`.

## Régénération (hors jeu)

Outils dans `scripts/animations/` (Blender 5.3 en module Python, Godot 4.7.2) :

| Script | Rôle |
| --- | --- |
| `adapter-animations-gabi.py` | Adapte les gestes Mixamo (X Bot) au Gabi rigué ; sortie `.blend` avec une piste NLA par geste. Liste : `gestes-gabi.json` (chemins relatifs à `--racine`). |
| `exporter-gabi-mixamo.py` | `.blend` → `.glb` : carnet du Gabi d'origine réattaché à `mixamorig:LeftHand` au même placement (les deux modèles ont le même maillage au repos), matériaux d'origine remis (l'aller-retour FBX les avait simplifiés). |
| `convertir-gabi.gd` | `.glb` → scène `.scn` (textures intégrées, mipmaps générées). |
| `regenerer-gabi.py` | Les deux étapes précédentes en une commande. |
| `poser-animations-privees.py` | Pose les fichiers à côté du jeu installé. |

```
python3 scripts/animations/adapter-animations-gabi.py -- gabi-mixamo.fbx scripts/animations/gestes-gabi.json /hors-depot/gabi.blend --racine /dossier/des/fbx
python3 scripts/animations/regenerer-gabi.py /hors-depot/gabi.blend /hors-depot/sortie --godot /chemin/Godot_v4.7.2
```

## Vérifié (Linux, Godot 4.7.2, 11 novembre)

- `tests/godot-gabi-mixamo.cjs` : 46 contrôles. Sans fichier, fichier absent, scène sans clip `repos` : Gabi d'origine. Scène d'essai fabriquée par le test (aucun contenu Mixamo) chargée par la variable puis par le dossier fixe ; salut, explications variées, gestes de parole enchaînés sans répétition, bouche, microgestes (un bâillement sur huit), approbation, mouvement réduit, guide masqué. Le dépôt ne contient aucun fichier `gabi-mixamo*`.
- Suites existantes : `godot-gabi-composition`, `godot-guide-voice`, `godot-match-animations` vertes. `godot-guide-integration` échoue sur « Commande réelle advance_day » et dépasse son délai, comme avant cette branche (mêmes échecs dans les campagnes précédentes) : sans lien avec Gabi.
- Vrai Gabi Mixamo dans le jeu réel (Xvfb, carrière créée, guide ouvert) : modèle chargé depuis la `.scn`, 27 clips, textures et couleurs identiques au Gabi d'origine, carnet dans la main gauche, bouche qui s'ouvre, gestes de parole pendant la parole.

## Limites

- Le cadrage du portrait est celui du Gabi d'origine (même maillage, même taille) ; certains gestes larges peuvent sortir du cadre (voir captures).
- Les doigts : une chaîne par main, pas de pouce mobile dans le rig actuel.
- Aucune exécution sous Windows au moment de ce commit.


## Corrections du 11 novembre au soir (yeux, mains, manches, nouveaux gestes)

- **Yeux** (`corriger-yeux-gabi.py` pour le `.glb` d'origine, `corriger-yeux-gabi-blend.py` pour le `.blend` rigué) : les deux pupilles regardaient sur sa droite (≈ 10° pour l'œil droit) ; elles visent désormais un interlocuteur à 1,3 m. Les paupières, blanches (effet « lunettes »), sont couleur peau, et la paupière supérieure est abaissée de 10° (elle couvre le haut de l'iris, regard détendu). Appliqué aussi au Gabi d'origine `guide/assets/gabi.glb` : visible dans le jeu actuel, sans fichier privé.
- **Pouces** (`ajouter-pouces-gabi.py`) : Mixamo n'avait pas fait d'os de pouce ; trois phalanges ajoutées par main, pondérées sur la géométrie du pouce (distance le long de la surface depuis la pointe). Les gestes Mixamo contiennent déjà le mouvement du pouce.
- **Doigts** : une seule chaîne plie les quatre doigts collés ; flexion réduite de moitié pour ne pas ouvrir les fentes entre les doigts.
- **Revers des manches** : accrochés entièrement à l'avant-bras (ils glissaient entre bras et avant-bras).
- **Gestes** : 40 (liste `gestes-gabi.json`), dont 14 téléchargés avec Gabi sélectionné (marche, demi-tours, s'asseoir/se lever, assis qui parle, téléphone, pouce levé, parle), et `bras_croises` fabriqué (`bras-croises-gabi.py`, cinématique inverse sur la respiration de « repos »). Écartés : Drinking et Sitting Drinking (le bras traverse), les variantes où la source est assise ou accroupie.

Chaîne complète :
```
python3 scripts/animations/ajouter-pouces-gabi.py -- gabi-mixamo.fbx /hors-depot/gabi-rig.blend
python3 scripts/animations/adapter-animations-gabi.py -- /hors-depot/gabi-rig.blend scripts/animations/gestes-gabi.json /hors-depot/gabi.blend --racine /dossier/mixamo
python3 scripts/animations/corriger-yeux-gabi-blend.py -- /hors-depot/gabi.blend
python3 scripts/animations/bras-croises-gabi.py -- /hors-depot/gabi.blend
python3 scripts/animations/regenerer-gabi.py /hors-depot/gabi.blend /hors-depot/sortie --godot <Godot 4.7.2>
```

# Gabi rigué par Mixamo, avec ses gestes (11 novembre 2026)

## Ce que fait cette branche

Léo a fait riguer Gabi par Mixamo (squelette Mixamo de 33 os, textures et formes de bouche conservées). Les gestes de Mixamo ont été adaptés à ce squelette (27 clips). Cette branche branche ce nouveau Gabi dans le guide, **sans rien changer quand ses fichiers sont absents**.

- Recherche du fichier (`native/godot/donnees_privees.gd`) : la variable `CD_GABI_MIXAMO` (chemin absolu), sinon `animations/gabi-mixamo.scn` à côté de l'exécutable du jeu. Rien trouvé, fichier illisible ou sans clip `repos` : Gabi d'origine (`guide/assets/gabi.glb`), avec un simple avertissement si un chemin était donné.
- Même règle pour le match : `CD_MATCH_ANIMATIONS`, sinon `animations/mixamo-match.res` à côté de l'exécutable (`match_animations.gd`, voir `docs/match-animations-adaptees-20261111.md`).
- Le fichier est une scène Godot `.scn` préparée hors jeu : le jeu ne reconstruit aucune scène glTF pendant l'exécution (cause supposée du plantage Forward+ sous Windows constaté avec la bibliothèque du match).

## Correspondance des clips (`coach_portrait_3d.gd`)

Remplacée le 12 novembre par la table de cohérence (section « Gestes cohérents avec le moment » plus bas) : chaque geste dépend désormais de la bulle affichée, plus d'un tirage dans une liste fixe. Restent valables : fondu 0,2 s, salut à la première ouverture, mouvement réduit, guide masqué, gestes de parole enchaînés pendant la parole (un geste en cours se termine d'abord), petits gestes d'attente toutes les 3 à 6 s (Gabi Mixamo) ou 7 à 13 s (Gabi d'origine).

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


## Gestes cohérents avec le moment, regard, sourire, lumière (nuit du 11 au 12 novembre)

Demandes de Léo : « une cohérence entre ses gestes et ce qu'il se passe », « toujours en mouvement », « parfois un petit sourire », des yeux plus vivants, une lumière plus chaude et plus claire.

### Ce que le jeu sait du moment

Gabi n'apparaît que dans le guide (bulle + portrait, sur tous les écrans). Le contexte disponible : la page (écran), la bulle affichée (identifiant stable de `dialogues.json`, 74 bulles), les décisions signalées par le guide (`decision-contrat` = signature, `decision-tresorerie` = caisse dans le rouge, `decision-saison`) et, sur la page Résultat, le score du match terminé (`live.score`, `live.pair`, club du coach). Les rendez-vous, la conférence de presse, la causerie (vestiaire) ou la préparation (plan de jeu) ne font pas apparaître Gabi en personne : il y parle par les bulles de leur page (`presse`, `vestiaire`, `plan-jeu`…), qui ont donc leur catégorie.

`guide/gabi_moments.gd` range chaque bulle dans une catégorie (table `BULLES`, écrite à la main d'après le texte de la bulle) ; `coach_guide.gd` transmet au portrait le moment de la bulle affichée (`set_moment`). Une nouvelle bulle joue aussitôt un geste de sa catégorie ; la même bulle rafraîchie ne rejoue rien ; la première ouverture du guide reste un salut. Le hasard ne choisit qu'entre gestes équivalents d'une même catégorie, jamais deux fois de suite le même geste.

### Table de cohérence

| Catégorie | Exemples de bulles | Gabi Mixamo | Gabi d'origine | Ton |
| --- | --- | --- | --- | --- |
| accueil | première ouverture, « Adiu… Entre donc » | salut | Salut | positif |
| consigne (explication, conseil, tactique) | « Un plan, il faut pouvoir l'expliquer simplement… » | explique, montre, insiste, argumente | Explication | neutre |
| mise en garde | « Un banc, ce n'est pas une salle d'attente », presse | insiste, refuse, argumente | Explication | neutre |
| question au coach / choix | « Une piste te plaît ? », « Récupération, normal ou intensif » | sceptique, hausse | Ecoute | neutre |
| approbation / encouragement | composition, « Bon match, coach », « Continue à construire » | approuve, approuve_fort, pouce | Approbation | positif |
| bonne nouvelle | signature (`decision-contrat`), victoire | content, approuve_fort, pouce, applaudit | Approbation | positif |
| mauvaise nouvelle | caisse dans le rouge, défaite | decu, reflechit, regarde_bas | RegardCarnet | négatif |
| souvenir | l'atelier, le premier club, match nul | reflechit, hausse | Ecoute | neutre |
| regret | la demi-finale, le jeune laissé sur le banc | reflechit, regarde_bas | RegardCarnet | négatif |
| attente (le coach lit ou choisit) | entre deux gestes | repos_respire, appui, regarde_bas, reflechit ; rarement tablette ou baille (au plus un sur six, jamais au ton négatif) | Ecoute, RegardCarnet | — |
| parole | voix en cours | parle, parle_2, parle_3, parle_4, parle_5, parle_7, parle_8 | (bouche seule) | — |

Page Résultat : victoire → bonne nouvelle, défaite → mauvaise nouvelle (et ton grave pour toute la page), nul → souvenir (il réfléchit), score illisible → consigne. Auparavant, Gabi approuvait sur cette page même après une défaite.

Jamais joués : `bras_croises` (jugé raté par Léo), `assis_*`, `debout_assis`, `assis_debout` (le portrait n'a pas de chaise : il serait assis dans le vide), `marche`, `tourne_g`, `tourne_d`, `telephone`, `telephone_marche` (il sortirait du cadre ou téléphonerait en parlant au coach), `rit` (le personnage « sourit plutôt que de rire », `gabi_personality.json`), `surpris`, `remercie` (aucun moment du jeu ne les appelle encore). Ils restent dans le fichier privé.

Avis : la table est figée sur les 74 bulles actuelles. Une nouvelle bulle sans entrée prend la catégorie de sa page, sinon « consigne » ; un test vérifie que chaque bulle de `dialogues.json` a sa catégorie.

### Toujours en mouvement, regard, clignements, sourire (`guide/gabi_visage.gd`)

- **Regard** : les yeux sont des maillages séparés (`Gabi_Oeil_D`, `Gabi_Oeil_G`) dans les deux modèles. Au chargement, le portrait leur construit quatre formes (RegardGauche, RegardDroite : 14° ; RegardHaut : 9° ; RegardBas : 12°) en tournant le globe autour de son centre : aucun fichier modifié, donc aussi pour le Gabi d'origine. Petites saccades (≈ 0,1 s) autour du visage du joueur toutes les 0,7 à 2,6 s (plus espacées quand il parle, un peu plus bas au ton négatif) ; regard vers le carnet pendant regarde_bas, tablette, decu (RegardCarnet chez le Gabi d'origine) ; regard de côté pendant reflechit, sceptique (Ecoute).
- **Clignements** : les paupières n'ont ni os ni forme dans les modèles actuels. Un autre agent ajoute cette nuit la forme « Clignement » (sur Mesh_0 et les paupières) aux deux modèles, avec « SourireYeux » et « SourcilsDoux » ; je n'ai donc pas touché aux modèles pour éviter deux versions concurrentes. Le portrait pilote ces formes dès qu'elles existent (recherche par nom, absentes = rien) : clignement toutes les 3 à 6 s (5 à 9 s pendant une question au coach, écoute attentive), doublé une fois sur sept environ, souvent avec un grand déplacement du regard.
- **Sourire** : MouthPress 0,30 et MouthWide 0,75 à pleine intensité (calibré en rendu : au-delà, la bouche s'ouvre), en général 40 à 100 % de cela. De temps en temps au repos (toutes les 6 à 13 s au ton neutre, 3 à 8 s au ton positif), franc juste après une bonne nouvelle ou une approbation ; jamais au ton négatif ; jamais pendant la parole (la synchronisation labiale garde la bouche, le sourire repart de zéro à la fin de la phrase). Regard chaleureux : SourireYeux 0,3 au repos (+0,35 avec le sourire, 0 au ton négatif), SourcilsDoux 0,4.
- Mouvement réduit ou guide masqué : regard droit, yeux ouverts, sans sourire, rien n'est animé.

### Lumière du portrait

Gabi est rendu dans son propre studio (SubViewport du portrait) : la lumière du bureau ne l'éclaire pas. Avant : ambiance bleutée (0,83 ; 0,87 ; 0,89) × 0,81, principale (1 ; 0,95 ; 0,91) × 0,43, remplissage bleu (0,71 ; 0,84 ; 1) × 0,26, contre-jour (1 ; 0,92 ; 0,77) × 0,32, rendu linéaire. Après : ambiance blanc chaud (0,95 ; 0,93 ; 0,90) × 1,0, principale (1 ; 0,95 ; 0,88) × 0,8, remplissage presque neutre (0,94 ; 0,95 ; 1) × 0,34, contre-jour (1 ; 0,93 ; 0,80) × 0,36, courbe AgX, exposition 1,25. Essai sans courbe AgX écarté : en éclaircissant, le canal rouge de la peau sature et le visage vire à l'orange (plus rouge qu'avant). Textures et matériaux inchangés ; captures avant/après dans la PR.

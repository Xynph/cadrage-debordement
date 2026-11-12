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
python3 scripts/animations/ajouter-expressions-gabi.py /hors-depot/gabi.blend
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

### Vérifié et limites (nuit du 11 au 12 novembre)

- `tests/godot-gabi-mixamo.cjs` : 131 contrôles (table complète, gestes par moment, attente selon le ton, sourire, clignement, regard, mouvement réduit). Jeu réel sous Xvfb (gl_compatibility) : captures avant/après des deux Gabi au Bureau et vidéo de six moments.
- Paupière fermée trop sombre : `_apply_vertex_colors` multiplie la couleur peau des paupières par leurs couleurs de sommets (rouge sombre) ; pendant un clignement, l'œil fermé paraît rouge foncé (sans couleurs de sommets, il est trop pâle). À corriger dans le modèle (couleurs de sommets ou matériau des paupières). **Corrigé dans les deux modèles** : voir « Expressions » ci-dessous.
- Rien d'exécuté sous Windows ; courbe AgX vue seulement en rendu logiciel.

## Expressions : regard chaleureux, clignement (nuit du 11 au 12 novembre)

Demande de Léo : « Il faut qu'il ait un regard plus chaleureux. » Trois formes (blend shapes) ajoutées par `scripts/animations/ajouter-expressions-gabi.py`, au Gabi d'origine (`guide/assets/gabi.glb`, dépôt) et au Gabi Mixamo (`gabi.blend` privé, puis `gabi-mixamo.scn` régénérée) :

| Forme | Effet | Repos conseillé |
|---|---|---|
| `SourireYeux` | paupière inférieure et peau sous l'œil qui remontent (davantage côté tempe), coin externe plissé, joues qui montent et avancent, légères pattes d'oie | 0,3 (0,5 à 0,65 avec un sourire) |
| `SourcilsDoux` | sourcils (peints dans la texture du visage : on déplace les sommets de leur zone) relevés à l'intérieur (jusqu'à 7 mm), extérieur un peu abaissé, paupière supérieure relevée de 4° (regard moins fatigué) | 0,4 |
| `Clignement` | paupière supérieure qui descend jusqu'à fermer l'œil, la paupière inférieure monte de 20 % de l'ouverture | 0 (impulsion 0 → 1 → 0) |

Maillages et indices (le jeu les cherche par nom) :
- `Mesh_0` : 0 MouthOpen, 1 MouthRound, 2 MouthPress, 3 MouthWide (inchangées, mêmes données), 4 SourireYeux, 5 SourcilsDoux, 6 Clignement (nulle sur le visage, présente pour garder la même liste).
- `Gabi_Paupieres_D` et `Gabi_Paupieres_G` : 0 SourireYeux, 1 SourcilsDoux, 2 Clignement. Pas de formes de bouche sur les paupières : `coach_portrait_3d.gd` prend le premier maillage portant « MouthOpen », et les paupières viennent avant `Mesh_0` dans la scène.
- Poids par défaut enregistrés dans les modèles (glTF `weights`, valeurs des clés Blender) : SourireYeux 0,3, SourcilsDoux 0,4, Clignement 0. Godot les lit mais ses instances démarrent à 0 (vérifié sur `gabi-mixamo.scn`) : c'est `gabi_visage.gd` qui pose les valeurs de repos.

Méthode (détail dans l'en-tête du script) : champ de déplacement doux, identique pour la peau et les paupières (elles restent collées au visage) ; paupières tournées autour de l'axe horizontal du globe, le bord glissant sur sa surface ; projection : tout point visible des paupières (sommets, milieux d'arêtes, centres de triangles) reste devant le globe à 1/4, 1/2, 3/4 et 1 de chaque forme (un mélange de formes suit la corde, pas l'arc). Le clignement est aussi contrôlé pour de petits mouvements du regard (±10° de côté, ±6° en hauteur) ; la paupière fermée est donc un peu bombée (jusqu'à 7 mm devant le globe au centre).

Réparations du modèle faites au passage (géométrie de repos et couleurs des paupières, les deux modèles) :
- un croissant d'iris se voyait à travers la paupière supérieure (sa face avant passait sous la surface du globe depuis l'abaissement de 10°) : faces visibles ramenées 0,3 mm devant le globe ;
- quatre sommets de `Gabi_Paupieres_G` étaient 4,3 cm trop en avant (éclat sombre à côté du nez) : remis en symétrique de la paupière droite ;
- paupière fermée rouge foncé dans le jeu : couleurs de sommets des paupières ramenées au blanc et matériau `Gabi_Paupières` à la teinte de la peau voisine (moyenne de la texture du visage sous l'œil et vers la tempe, linéaire 0,394 ; 0,0625 ; 0,044). Le jeu (matériau × couleurs de sommets) et Blender donnent la même teinte.

Chaîne Mixamo : après `corriger-yeux-gabi-blend.py`, lancer `python3 scripts/animations/ajouter-expressions-gabi.py /hors-depot/gabi.blend`, puis `regenerer-gabi.py` avec `--origine` = le `gabi.glb` de la branche (matériaux). Le script refuse un `.glb` qui a déjà ces formes (repartir du `.glb` sans elles) ; sur un `.blend`, il remplace les formes existantes.

Vérifié (rendus Cycles en gros plan de face, trois quarts et profil, à 0 / 0,5 / 1 de chaque forme, et repos chaleureux + MouthWide 0,6) : pas de déchirure, pas d'iris à travers les paupières au regard droit. Import Godot 4.7.2 (`GLTFDocument` sur le `.glb`, chargement de `gabi-mixamo.scn` régénérée) : noms et indices ci-dessus, « MouthOpen » trouvé d'abord sur `Mesh_0`, couleurs de sommets des paupières blanches ; déplacements des formes de bouche identiques à l'avant.

Limites :
- Le regard de `gabi_visage.gd` va jusqu'à 9° vers le haut et 12° vers le bas : le globe est un ellipsoïde allongé vers l'avant, et la cornée traverse alors la paupière supérieure (en haut) ou inférieure (en bas, surtout avec SourireYeux). C'était déjà le cas, en pire, sur le modèle d'origine. Sans défaut visible : ≤ 5° vers le haut, ≤ 5° vers le bas (≤ 4° avec SourireYeux 0,65). Le clignement reste fermé avec le regard à 14° de côté, 9° en haut ou 12° en bas (essayés un par un).
- Maillage du visage grossier (≈ 5 mm entre sommets) : pattes d'oie seulement suggérées ; le bas de la paupière inférieure garde ses bords dentelés d'origine ; à SourireYeux 1, quelques points blancs du globe au coin externe inférieur (invisibles à 0,65 et au format du portrait).
- Vérification en rendu Blender, pas dans le jeu réel.



## Retouches du 12 novembre : paupières, carnet, bouche

Demandes de Léo : « Fais en sorte que Gabi ait les paupières plus relevées, on dirait qu'il plisse les yeux. Et fais aussi en sorte qu'il garde plus son carnet contre lui », puis « ouvre encore plus ses paupières » (validé : « les yeux c'est nickel ») et « maintenant retravaille sa bouche ».

### Paupières (`ajouter-expressions-gabi.py`, `gabi_visage.gd`)

- Le bord de la paupière supérieure couvrait le tiers haut de l'iris (abaissement de 10° du 11 novembre). Il est remonté de `RELEVE` = 10,5° au milieu de l'œil, 0 aux coins (`profil_releve` : plein sur la largeur de l'iris, nul aux commissures), en glissant sur le globe. Le bord dégage l'iris, avec une fine bande de blanc côté tempe. Essais : 7° (bord au ras de l'iris), 9°, 10,5° (retenu), 12° (regard qui s'écarquille).
- Le tableau des bords (`HAUT`) reste la mesure d'avant ; le bord effectif est `bord_haut(lat)`. Clignement, SourireYeux et SourcilsDoux sont recalculés sur ce bord : l'œil se ferme toujours entièrement, la cornée ne traverse pas, la paupière reste couleur peau.
- Dans un `.blend`, le relèvement déjà appliqué est mémorisé (`releve_paupiere` sur les paupières) : relancer le script n'applique que l'écart. Le `.glb` du dépôt se refait depuis le `.glb` sans formes d'expression (`git show edc903a2:native/godot/guide/assets/gabi.glb`).
- Regard vers le bas : la paupière supérieure suit (`LID_FOLLOW` = 0,12 de Clignement à RegardBas 1). Sans cela, l'iris descendait sous une paupière immobile et le blanc apparaissait au-dessus. `GAZE_ANGLES` inchangé (14°, 5°, 5°). SourireYeux (jusqu'à 0,65) et le sourire ne referment pas trop l'œil (vérifié en rendu).

### Carnet tenu contre lui (`tenir-carnet-gabi.py`, `gabi_moments.gd`)

Le carnet est attaché à `mixamorig:LeftHand` (export). Dans les gestes Mixamo, le bras gauche gesticulait : carnet tendu, levé à l'oreille (parle_5), balancé. Le script réécrit, dans chaque geste du `.blend`, le bras, l'avant-bras, la main et les doigts gauches :

- tenue : carnet à plat contre le ventre, côté gauche, haut penché comme le ventre, main posée dessus ; définie par rapport à `Spine1` (il suit le buste), cinématique inverse à deux os par image (coude dehors et en arrière), torsion de l'avant-bras qui plie le moins le poignet, doigts en prise ;
- vie : la main suit en petit (12 %, 2,5 cm au plus, jamais vers le corps) le mouvement du bras d'origine ;
- peau : la peau du ventre est recalculée par image (pondérations des os) et le carnet s'en écarte s'il s'en approche à moins de 6 mm (buste plié) ;
- lecture : pendant `regarde_bas` (mauvaise nouvelle, regret, attente), il lève le carnet devant la poitrine et le consulte (le regard suit déjà le carnet) ;
- `tablette` (rare) garde le geste d'origine au milieu, avec passage progressif depuis et vers la tenue.

Contrôle à la fin du script (distance carnet-corps, bras compris, sur six images par geste) : tous les gestes joués sont propres ; la main droite traverse le carnet dans `decu`, `baille`, `applaudit` (et dans des gestes jamais joués : `rit`, `assis_*`, `debout_assis`). Ces trois-là ne sont plus joués : mauvaise nouvelle = regarde_bas, reflechit ; bonne nouvelle = content, approuve_fort, pouce ; attente rare = tablette.

Chaîne complète (après les étapes de la section « Expressions ») :
```
python3 scripts/animations/ajouter-expressions-gabi.py /hors-depot/gabi.blend
python3 scripts/animations/tenir-carnet-gabi.py -- /hors-depot/gabi.blend native/godot/guide/assets/gabi.glb
python3 scripts/animations/regenerer-gabi.py /hors-depot/gabi.blend /hors-depot/sortie --godot <Godot 4.7.2>
```
`tenir-carnet-gabi.py` est à lancer une fois, sur des gestes d'origine : relancé sur des gestes déjà tenus, la tenue est la même mais la petite part de mouvement d'origine (« vie ») disparaît. Pour changer la tenue, repartir d'un `.blend` d'avant (sortie d'`adapter-animations-gabi.py` puis des étapes précédentes).

### Bouche (`ajouter-sourire-gabi.py`, `gabi_visage.gd`, `coach_portrait_3d.gd`, `coach_guide.gd`)

Constat : les lèvres sont une coque séparée (primitive `M_Gabi_V3_Levres` de `Mesh_0`, 110 sommets) posée sur le visage, au contour en dents de scie, avec une texture presque couleur de peau (sRGB moyen 155/99/96 contre 144/96/93 pour la peau voisine) ; la lèvre supérieure disparaissait sous la moustache ; le sourire (MouthWide 0,75 + MouthPress 0,3) ne bougeait les commissures que de 3 mm.

- Lèvres redessinées dans leur texture (projection de face : u suit x, v suit y) selon un contour lisse (`contour_levres` : fente, lèvre supérieure ≈ 13 mm avec arc de Cupidon, inférieure ≈ 15 mm) : rose soutenu, plus foncé près de la fente, liseré clair au bord de la lèvre supérieure. Hors du contour, la coque prend texel par texel la couleur de la peau qu'elle couvre et, au bord, ses normales : plus de dents de scie ni de halo rectangulaire. (Essai d'un bord transparent écarté : le visage est troué sous la coque.)
- Volume : chaque lèvre avance en arrondi (3,4 et 3,8 mm au milieu de sa hauteur) et s'étire de 1,5 mm depuis la fente ; même champ pour le visage, les lèvres et la cavité (rien ne se décolle). Dans un `.blend`, une seule fois (propriété `volume_levres` sur `Mesh_0`).
- Forme « Sourire » (indice 7 de `Mesh_0`, après Clignement) : commissures +7,5 mm vers le haut, 2,5 mm vers l'arrière, 2,4 mm vers l'extérieur ; joues qui montent et avancent ; lèvre supérieure à peine relevée ; côté gauche de Gabi 12 % plus haut (asymétrie légère). Le jeu la pilote si elle existe : `Sourire` = 0,12 au repos (et pendant la parole), jusqu'à 1 au sourire franc, 0 au ton négatif ; MouthWide n'ajoute plus que 0,25 × sourire, MouthPress plus rien. Sans la forme (modèles plus anciens) : comportement d'avant.
- Repos : lèvres entrouvertes (MouthOpen 0,06 ± 0,03 au rythme d'une respiration de 4,2 s), seulement avec la forme « Sourire ».
- Bulle sans voix (muet, mode texte, voix désactivée) : `coach_guide.gd` appelle `portrait.mime(texte)` quand aucune voix ne démarre ; la bouche s'ouvre légèrement (MouthOpen 0,16 à 0,40, parfois un peu arrondie) au rythme d'environ 4,5 syllabes par seconde, pendant 1,2 à 4 s selon la longueur du texte (16 caractères par seconde), puis se referme. Une vraie voix, le guide masqué ou le mouvement réduit l'arrêtent ; une nouvelle bulle relance.

Chaîne : `python3 scripts/animations/ajouter-sourire-gabi.py <gabi.glb sans « Sourire »> <sortie.glb>` pour le Gabi d'origine (le Gabi Mixamo reprend matériaux et texture à l'export), et `python3 scripts/animations/ajouter-sourire-gabi.py /hors-depot/gabi.blend` avant `regenerer-gabi.py`.

Retouches finales du 12 novembre (avis de Léo et du coordinateur) : lèvres v3 (modelé peint : supérieure épaisse au centre et effilée, philtrum et arc de Cupidon, inférieure charnue, bord fondu, reflet sur la lèvre inférieure, creux d'ombre aux commissures ; rose chaud un peu terne, sRGB 150/76/76, 104/44/48 près de la fente ; texture 512×256), sourire franc plus marqué (commissures +8,8 mm, joues +4,8 mm, lèvre supérieure qui s'amincit), intérieur de la bouche rouge sombre.

### Teint, paupières, dents (`retoucher-teint-gabi.py`)

- Peau : tons chair (teinte 0-40°) à 80 % de leur saturation (un peu moins encore pour les plus saturés), nez et joues glissés de 5° vers le rose ; chemise, jean, barbe inchangés.
- Paupières : couleur remesurée sur la nouvelle peau autour des yeux, assombrie de 10 % (plus de liseré clair).
- Dents : ivoire plus sombre (0,24 ; 0,19 ; 0,15).
- Material_0 affiché des deux côtés (faces intérieures entre les doigts).
- Le script compacte le tampon du `.glb` (anciennes textures retirées) : `gabi.glb` passe de 8,5 à 7,8 Mo.

### Pouces (`reparer-pouces-gabi.py`)

Demande de Léo : « y'a un souci avec les pouces qui ne sont pas complets ». `ajouter-pouces-gabi.py` pondérait chaque sommet du pouce à 100 % sur une phalange : le pouce se cassait en morceaux dès qu'il pliait. Le script (sur le `.blend`, une seule fois) : fondus entre phalanges (±9 mm) et vers la main ; pièces non soudées rattachées au pouce ; poids des sommets confondus mis en commun ; rotations des phalanges réduites (pouce droit 60 % / 50 % / 0) ; pouce gauche solidaire de la main (son bout, fait de pièces non soudées, se déchirait même à 25 % de flexion ; il tient le carnet presque tout le temps). Essai écarté : remplacer la main gauche par le miroir de la droite (elle ne raccorde pas à l'avant-bras de Mesh_0).

Chaîne complète du Gabi Mixamo au 12 novembre :
```
python3 scripts/animations/ajouter-expressions-gabi.py /hors-depot/gabi.blend
python3 scripts/animations/tenir-carnet-gabi.py -- /hors-depot/gabi.blend native/godot/guide/assets/gabi.glb
python3 scripts/animations/ajouter-sourire-gabi.py /hors-depot/gabi.blend
python3 scripts/animations/reparer-pouces-gabi.py -- /hors-depot/gabi.blend
python3 scripts/animations/regenerer-gabi.py /hors-depot/gabi.blend /hors-depot/sortie --godot <Godot 4.7.2>
```
Gabi d'origine (`gabi.glb`) : depuis `git show edc903a2:native/godot/guide/assets/gabi.glb`, `ajouter-expressions-gabi.py`, puis `ajouter-sourire-gabi.py`, puis `retoucher-teint-gabi.py`.

Reste à faire : fentes sombres entre les doigts (maillage des doigts collés, visibles de près) ; pouce gauche sans flexion ; quelques dents de scie au bord haut de la coque des lèvres, visibles seulement en très gros plan ; cassure de la lèvre inférieure dans la forme MouthOpen d'origine ; netteté des textures du visage et de la barbe : voir la section suivante.

## Netteté de la tête (12 novembre, après-midi) : `nettete-tete-gabi.py`

Demande de Léo : visage et barbe flous de près. Constat : la tête n'occupait qu'une petite zone de la texture 2K du corps (≈ 0,7 texel/mm au visage).

- **Texture dédiée** : les triangles de la tête (y > 1,30 m, hors chemise ; visage, barbe, moustache, sourcils, cheveux, oreilles) passent dans une nouvelle primitive de `Mesh_0`, matériau `Gabi_Tete` (mêmes sommets, poids et formes d'expression). Dépliage à part dans Blender (projection intelligente, 1,4 rad), îlots du visage agrandis de 80 % : ≈ 2,8 texels/mm au visage, 1,5 ailleurs, anisotropie 1,2. Couleur actuelle re-cuite texel par texel (yeux, bouche et teint validés inchangés).
- **Détail réel** (procédural, dans `cuire`) :
  - mèches directionnelles (bruit 3D étiré le long de la pousse, ±22 % de luminosité, plus marquées sur la moustache) : sourcils vers la tempe, moustache vers le bas et l'extérieur, barbe vers le bas, cheveux suivant les bandes de la texture d'origine ;
  - barbe continue sous la lèvre inférieure et au centre du menton (zone claire et rosée d'origine teintée vers la couleur de la barbe) ;
  - front et tempes lisses : pas de mèches hors de la chevelure et des sourcils (sourcils = zone sombre seulement) ;
  - peau : grain léger (pores) et variations de teinte douces ;
  - carte de normales 2K : relief des mèches et du grain, composé avec la carte d'origine ; occlusion 1K.
- **Coque des lèvres** : hors du contour des lèvres, elle prend la peau de la nouvelle texture (mèches de barbe jusqu'au bord, plus de plaque claire polygonale) ; texture 1024×512.
- **Poids** : textures en JPEG (couleur q90, normales q92, occlusion q88, lèvres q92) ; `gabi.glb` passe de 7,9 à 10,9 Mo. Scène Mixamo privée : 45 Mo (textures non compressées avec mipmaps, comme avant).
- **Contrôles** (`tests/godot-gabi-mixamo.gd`) : matériau `Gabi_Tete` présent, couleur et normales 2K, formes d'expression conservées.

Chaîne (le dossier de travail est hors dépôt ; `preparer` demande environ 2,7 Go de mémoire et 2 min 30) :
```
python3 scripts/animations/nettete-tete-gabi.py preparer <gabi.glb sans tête dédiée> /hors-depot/tete
python3 scripts/animations/nettete-tete-gabi.py appliquer /hors-depot/tete <gabi.glb sans tête dédiée> native/godot/guide/assets/gabi.glb
python3 scripts/animations/regenerer-gabi.py /hors-depot/gabi.blend /hors-depot/sortie --godot <Godot 4.7.2> --tete /hors-depot/tete
```
`<gabi.glb sans tête dédiée>` : `git show 6f395b6f:native/godot/guide/assets/gabi.glb` (sortie de `retoucher-teint-gabi.py`). Pour `regenerer-gabi.py`, `--origine` peut rester le `gabi.glb` du dépôt (matériaux repris) : `appliquer` refuse un `.glb` déjà traité. Le résultat est reproductible à l'octet près.

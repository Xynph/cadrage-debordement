# Chaîne d’animation — réception Cloud avant Windows

Lot du 9 novembre 2026, base main `e38a79f3c5ea2f7d48a362a96091ba466f70399f`.

## But

Contrôler notre athlète et son aller-retour Blender → Godot avant de remplacer un actif. Les outils de ce lot s’exécutent à la demande ; ils ne changent pas le lecteur du match, le modèle distribué, les sauvegardes ou la simulation sportive.

Plusieurs agents travaillent sur des chemins disjoints : inventaire binaire, comparaison de poses, lecteur existant, recette PC et relecture indépendante. Le coordinateur reçoit et publie le lot. Effort GPT‑6.1 Sol conseillé : Élevé pour intégration/diagnostic, Moyen pour rejouer une recette établie.

## Provenance

Les essais précédents ont employé Scenario Skills `b96506d77c8595a4fe9c66eddb0bf9b5953a1d45` (audit, imports et poses) et EL4CTEO Blender Skills `389f28addc79b87b28764898e38e7bf408d14b77` (preset godot). Les contrôles versionnés ici sont adaptés au projet ; installer tous les plugins ou connecter un service de génération n’est pas requis.

Le GLB candidat de l’essai précédent est produit avec le vrai preset amont sous Blender4.3.2. Ce n’est pas une validation de la famille complète ciblant5.2. Le candidat reste externe au jeu. La recette PC décrit sa régénération ; un résultat Cloud ne certifie pas un autre export.

## Lecture des verdicts

La réussite d’un chargement n’établit pas la conformité d’un asset. Lire les erreurs et mesures du rapport ; une liste d’avertissements non vide n’est jamais effacée par un champ `ok`. Une absence de RESET peut être une convention d’AnimationTree non applicable à notre lecteur personnalisé. Le format glTF ne fournit pas une politique de boucle universelle : contrôler le lecteur réel.

Un inventaire identique de bones et clips ne prouve pas des poses identiques. Une comparaison de bones ne prouve pas des poids, normales, coutures, matériaux ou déformations de mesh identiques. La scène habillée et ses trente joueurs doivent encore être observés sous Windows.

## Réception

Les commandes, résultats mesurés et limites sont complétés après exécution réelle des nouveaux outils. Voir aussi [recette Windows](animation-pipeline-windows.md).

## Premier reçu — état historique avant correction approfondie

- `tools/animation-pipeline/inventory.py` : inventaire autonome du GLB, hash, joints, clips, temps lus dans BIN, primitives et matériaux. Baseline `inventory-baseline.json` :31joints,11clips,9primitives,9matériaux. Huit tests Node22 passent, sans test ignoré : fichiers tronqués, références invalides, non-finis, erreurs disque, aliases et écritures atomiques notamment.
- `compare_poses.py` / `.gd` : projet Godot temporaire indépendant, scènes fraîches à chaque temps, évaluation manuelle. Onze clips ×9temps,99paires de poses,6336comparaisons de transforms. Source/source : écarts exactement nuls. Le témoin altéré est refusé. Dix-neuf sous-cas de garde CLI passent (un test unittest) : seuils non finis, sortie source/candidat, symlink/hardlink.
- **Candidat refusé** : position maximale0,269322872unité importée, rotation0,683556189rad, échelle0,001029968. Seuils respectifs0,0001/0,001/0,0001. Le pire écart position/rotation se situe dans Sitting à8,333333s sur les pouces droits. Les unités d’import ne sont pas les mètres du joueur en match. Voir `pose-results.json`.
- `export_roundtrip.py` : import du GLB puis appel au vrai preset godot amont épinglé, checkout propre et nouvelle destination exigés. Réexécuté sous Blender4.3.2 sur le main courant : même candidat SHA256 `c113121f2a0a92a10a2bffa4a22a7bd1ea0bff0a583c1f4166a762ab11137ee8`. Ce succès d’export ne constitue pas son acceptation ; Blender5.2 reste à recevoir.
- `check_match_reader.gd` :79vérifications réussies sur le vrai lecteur et l’asset actuel. Idle/Walk/Run bouclent,120pas en pause conservent le temps et les poses, les rotations de préparation au contact sont restaurées. Les onze clips sont échantillonnés mais seuls trois sont normalement sélectionnés. Trois tentatives de sortie destructive sont refusées avec empreintes conservées. `reader-results.json` archive ce reçu.
- Cinq suites existantes exécutées séquentiellement sous Node22.23.4/Godot4.7.2 : motion, silhouettes, presentation, framing et contact07,5/5réussies,0ignoré. Les fixtures de présentation ne prouvent ni une causalité sportive ni un plaquage complet.

La source **versionnée** est `dist/match3d/assets/quaternius-rugby-athlete.glb`, SHA256 `7fd28255c484e19ba5086d9cf815128e21dfcb677d262a88b237a5f5af081c5f`. `native/godot/assets/match3d` est un staging ignoré que le build prépare. Il doit contenir une copie identique avant import du projet natif. Ni source ni shader/runtime n’ont été modifiés.

## Commandes minimales depuis la racine

```sh
node --test tests/animation-pipeline.cjs
python tools/animation-pipeline/inventory.py dist/match3d/assets/quaternius-rugby-athlete.glb
python tools/animation-pipeline/test_compare_cli.py
python tools/animation-pipeline/compare_poses.py SOURCE.glb CANDIDAT.glb --godot CHEMIN_GODOT_4_7_2 --out NOUVEAU_RAPPORT.json --self-test
```

Les chemins SOURCE/CANDIDAT/Godot sont à renseigner. Le wrapper retourne1 lorsque le candidat échoue aux seuils même si les témoins fonctionnent : c’est un rejet d’asset, pas une suite de tests verte. Ne pas relever les seuils uniquement pour faire passer l’export.

Pour le lecteur, après staging/import du projet, définir `CD_ANIMATION_READER_RESULTS` vers un nouveau chemin absolu `.json`, puis lancer Godot avec `--headless --path native/godot --script ../../tools/animation-pipeline/check_match_reader.gd`. Le détail PowerShell figure dans la recette Windows.

## Revue et passation

La relecture indépendante a trouvé puis fait corriger une possible écriture sur source/candidat, les aliases de fichiers, les seuils NaN/inf et le risque de faux vert malgré SCRIPT ERROR Godot. Les gardes ont été réexécutées. L’échantillonnage initial des poses conservait un historique entre clips ; remplacé par des scènes fraîches, il produit maintenant une identité strictement nulle. Seules les mesures finales ci-dessus sont reçues.

Le réexport reste **hors du jeu**. Aucun défaut du lecteur actuel nécessitant une modification runtime n’a été démontré par ce lot. Les preuves compactes et les harnesses sont versionnés ; les logs volumineux, fichiers temporaires et candidat restent dans le workspace de test. Les scripts n’installent aucune compétence globalement et ne requièrent aucun compte Scenario.

Prochaine étape PC : régénérer avec Blender5.2, exécuter les mêmes comparaisons, puis inspecter la scène habillée et les transitions sous Windows. La beauté des mouvements, les sommets skinnés et les performances ne sont pas reçus ici. Pas de nouvelle recette Windows, de benchmarkGPU ou de CI distante revendiqué dans ces mesures locales. DEVELOPPEMENT.md étant réservé à la réception parallèle #424, cette page et la coordination#73 portent la passation.

## Approfondissement parallèle : causes établies et contrôles renforcés

La suite du chantier utilise la même PR#427. Les constats initiaux restent ci-dessus comme historique, associés au candidatSHA c113121f… ; ils ne décrivent pas le dernier candidat corrigé. Le maintien des noms de clips et de bones n’est pas une garantie suffisante de conformité.

Les expériences A/B isolées montrent que :

1. La déduction automatique de la pose de liaison à l’import Blender modifie surtout les pouces ; `guess_original_bind_pose=False` réduit fortement ces écarts.
2. L’optimisation des animations à l’export perturbe des clés ; désactivée, elle ramène les positions et rotations sous les seuils.
3. Blender introduit des pistes d’échelle presque constantes absentes de la source. Leur suppression et la préservation explicite des échelles statiques source sont limitées au mode aller-retour, jamais à des animations de squash-and-stretch. Aucune rotation ou translation d’origine n’est recopiée pour faire passer un candidat.
4. Quatre petits poids positifs de la source sont supprimés par un seuil interne de Blender4.3.2. Le contournement en mémoire est strictement lié à la version et à l’empreinte de la fonction inspectée ; aucune installation ou copie amont n’est modifiée. Une version inconnue doit être refusée, pas présumée compatible.
5. Blender rebake les sommets au repos. Pour cette source aux matrices de liaison atypiques, ce rebake pondéré ne commute pas avec la déformation animée ; des joints équivalents peuvent donc encore produire des sommets différents. L’inversion algébrique du blend de repos et le remappage des inversebinds source sont contrôlés séparément.
6. Les normales subissent une perte de précision et un triangle Shoes avec indice répété `[99,99,100]` disparaît à l’import. Toute restauration d’attribut source ou d’indice perdu est une étape de préservation explicite, associée à un mapping stable et à une vérification des faces ; cela ne valide pas une modification artistique.

Le comparateur de poses fournit désormais les maxima par clip et par bone ; `--clip` répétable permet un diagnostic ciblé. Une sélection partielle est signalée dans `validation_scope` et par `complete_clip_coverage=false` et ne permet pas l’acceptation globale des onze clips. Un temps juste avant la fin est contrôlé en plus de la fin exacte, qui pourrait boucler. Les mesures Idle/Walk/Run du candidat initial figurent dans `locomotion-results.json`.

Le contrôle du lecteur identifie le SHA256 du fichier effectivement stagé, vérifie l’empreinte du cache d’import et celle de la scène importée. Le lanceur exige que ce SHA corresponde au candidat demandé : comparer un candidat et lire par erreur l’ancien modèle ne peut pas donner un reçu global favorable. Les répertoires de données sont isolés, y compris APPDATA/LOCALAPPDATA pour la future exécution Windows.

Le lanceur `run_checks.py` crée un nouveau dossier de preuves extérieur au dépôt, conserve les logs et un `summary.json`, distingue pass/fail/not_run et refuse les suites ignorées. Les phases de comparaison de skin et de lecteur sont explicitement demandées et leurs reçus contrôlés ; un outil ou une dépendance absent est un échec, pas une réussite silencieuse.

La CI du HEAD historique `bd7c6da7c0c1f4f678a526696ba028172c46a091` est reçue : run42661056964, sept jobs SUCCESS dont ValidationCI. Ce verdict ne vaut pas pour les modifications ultérieures, dont la CI propre reste à recevoir.

## Correction finale et étendue exacte du reçu

Le dernier candidat reproductible est identifié par SHA256 `d9139eddc66f7c407107b4d68b3d1503ca07e4256432a9a9a1528fd0fe74afbb`. Deux exécutions du wrapper complet ont produit cette même empreinte. Le fichier reste extérieur au jeu et n’est pas distribué par cette PR.

La correction conserve les positions calculées depuis le maillage exporté, puis annule algébriquement le rebake ; elle ne copie pas les positions source. Les rotations et translations animées proviennent de l’export, sans recopie du mouvement original. En revanche, les échelles statiques, matrices inversebind remappées, normales par coin et l’indice de la face dégénérée perdue sont explicitement préservés depuis la source. C’est un pipeline d’aller-retour avec préservation d’attributs, pas une preuve que l’exporteur Blender brut est sans perte.

La gate skin reçoit sur ce candidat :1854/1854faces orientées et coins de normales correspondants ;110poses sur11clips ;3981points source et4031lignes de sommets candidat, avec couverture sémantique des deux côtés. Les splits/doublons d’export ne sont pas assimilés à une topologie identique par numéro de sommet. Écart maximal de positions déformées CPU :1,21960693463e-5unité glTFmonde, sous0,0001. Angle maximal des normales par coin au repos :2,58095682795e-8rad, sous0,001. Les normales GPU et l’apparence de la tenue restent à observer.

Les contre-exemples ont servi à corriger les contrôles : primitive dupliquée, maillage non skinné supplémentaire, normales permutées entre coins, orientation de triangle, coordonnées animées non finies. La correspondance des faces est fixe au repos, bijective entre faces orientées, liée au matériau, aux positions et influences ; elle ne recherche pas le meilleur appariement à chaque pose. Les morph targets et autres variantes hors du contrat étroit sont refusées.

Un témoin de cache d’import périmé a été réellement refusé par le lecteur avant chargement du runtime. Un autre témoin associait un candidat correct à un lecteur chargeant l’ancien modèle : le lanceur le refuse malgré les assertions de lecture réussies. Ces tests empêchent des reçus techniquement verts portant sur le mauvais fichier.

### Dépendances et reprise

`tools/animation-pipeline/requirements.txt` épingle le Python externe reçu (NumPy2.3.5, SciPy1.17.0). Les phases d’inventaire et de gardes standard fonctionnent sans ces bibliothèques ; les phases numériques demandées les exigent, sans installation automatique. Blender utilise son NumPy embarqué, sans SciPy. Le patch privé des petites influences est volontairement limité à Blender4.3.2 et à l’empreinte de la fonction revue ; il refuse une autre implémentation. Le parcours5.2 doit donc faire l’objet d’une qualification distincte, sans suppression du garde.

La procédure Windows propose d’abord la reproduction avec la version réellement reçue4.3.2, puis une qualification séparée5.2. Une réussite numérique n’est pas une réception visuelle de trente acteurs ni une validation de l’EXEWindows ou des performances GPU. Aucun nouveau plaquage, comportement sportif ou changement de sauvegarde n’est livré.

### Réception finale complète

Le lanceur final a été exécuté sur la source canonique, le candidat d9139edd… et une copie fraîche du projet chargeant **ce même candidat** : **10phases pass,0fail,0not_run**. Inventaires, tests Node/CLI/numériques, poses globales, peau, vrai lecteur et empreintes concordent. `corrected-results.json` archive le reçu détaillé ; `skin-results.json` est régénéré avec le dernier comparateur strict, et non le premier contrôle limité aux positions.

Les14tests Node22 ciblés passent sans test ignoré. Les gardes d’export comprennent4tests standard ; les tests numériques comprennent4tests de restauration des normales et7tests du contrat skin. Le lecteur réel effectue81contrôles, dont les empreintes du fichier stagé et de son cache. La base du lanceur a également été reçue dans un venv dépourvu de NumPy/SciPy :5phases reçues et5not_run explicitement signalées, statutpartial ; ce résultat n’est pas une réception complète.

Les mesures des joints sur le candidat final et les110poses CPU du skin respectent les seuils inchangés. La version brute refusée, la locomotion initialement défectueuse, les fauxverts corrigés et les reçus finaux restent distingués par leurs empreintes. Aucun modèle distribué, règle sportive, runtime ou sauvegarde n’a été modifié.

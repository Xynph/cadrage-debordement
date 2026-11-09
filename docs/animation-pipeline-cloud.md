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

## Outils livrés et résultats du lot

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

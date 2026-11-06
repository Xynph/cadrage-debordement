# Audit de réemploi open source — MATCH 3D V25 (06/11/2026)

## Statut et périmètre
Audit de sources réelles GitHub, expériences séparées du produit, **AUCUNE intégration**. Main vérifié au départ : `49fbfa20f96e1a5587eabec6734ef72f840656dd`. Branche R&D V25 existante et PR #300 laissées intactes. Réservations #73 : #6694113124, #6694124989. Les benchmarks locaux sur les **vrais** GLB n'ont pas été exécutés dans ce lot ; pas de qualification artistique.

## 1. Ekza Studio (MIT avec exclusions)
Sources auditées : `LICENSE`, `packages/rig/package.json`, `packages/rig/src/index.ts`, `packages/rig/src/ik/plantFeet.ts`, `packages/rig/src/ik/twoBone.ts`.
- La bibliothèque expose `plantFeetChannels` et `solveTwoBoneIk`, avec pins mondiaux, longueur de segments, pivot/pole, contrôle d'atteignabilité et traitement des jambes IK/FK.
- Ce sont des modules **TypeScript dans un workspace** dépendant de `@ekza-studio/anim-core`, `@ekza-studio/doc`, `@ekza-studio/mesh-core` : **pas un copier-coller isolé** pour Blender Python ou notre runtime.
- Le squelette de référence exige des correspondances de noms humanoïdes et une compilation de rig. La compatibilité avec nos **53 joints / rotations / sens d'axes / unités** et trois LOD n'est **pas démontrée**.
- Licence source MIT sauf `packages/anim-core/src/curve/animx/` Apache-2.0, fixtures sous licences propres, marque Ekza exclue ; vérifier fichier par fichier et conserver notices.

**Verdict ORANGE** : candidat à une transcription testée des principes de *foot pin*, pas à une intégration immédiate du produit. Expérience réelle IK sur rig canonique requise.

## 2. three-mesh-bvh (MIT)
Sources : `LICENSE`, `package.json` (version observée 0.9.18, `three >=0.159`), `src/index.js`, `README.md`.
- BVH optimisant raycasts et tests géométriques ; exports `MeshBVH`, `SkinnedMeshBVH`, `StaticGeometryGenerator`. Le repo fournit des démos skinnées.
- Notre script Blender V25 utilise déjà `mathutils.bvhtree.BVHTree` avec maillages *évalués en pose* ; remplacer par three-mesh-bvh ne démontre ni exactitude ni gain. À utiliser pour **probes Three.js indépendants** seulement jusqu'à réception appariée.
- Problème historique identifié en V14 : les croisements étaient des faux positifs dus aux sphères techniques `Icosphere` / `Icosphere.001` non skinnées, pas des collisions de peau. Il faut conserver leur exclusion par propriétés vérifiées et ne pas réduire un nombre de collisions en masquant la vraie géométrie.
- Microprobe inclus : 3 densités `BoxGeometry`, intersection / disjonction / exclusion d'auxiliaire. **Ce sont des boîtes statiques et non des maillages skinnés** ; ce test ne remplace pas les mesures V25 des vraies surfaces.

**Verdict ORANGE** : meilleur candidat de première expérimentation, mais pas encore de bénéfice mesuré ni de compatibilité runtime certifiée.

## 3. THREE.IK (MIT)
Sources : `LICENSE`, `README.md`, `package.json` (version déclarée 0.1.0).
- Solveur FABRIK multi-chaînes, effecteurs et contrainte boule.
- La documentation signale projet en cours, problèmes d'axes, contraintes et changements cassants envisagés. Les dépendances build sont anciennes.
- Aucun test exécuté contre nos os `thigh_l`/`calf_l`/`foot_l`, les 53 joints et la correction vraie semelle. Moins convaincant que l'IK anatomique à deux os d'Ekza.

**Verdict ROUGE pour intégration directe**, **ORANGE comme référence d'algorithme**.

## Compatibilité avec le R&D réel
- La PR #300 est DRAFT/non intégrée ; le lot 24 documente trois LOD sous plafonds 30k/10k/3k triangles, **53 joints**, 30 mixers/rigs indépendants, coût de rendu supérieur au lot 23. Ne jamais prétendre à un gain FPS produit.
- La branche V25 contient des scripts Blender basés sur `bpy`, `mathutils.BVHTree`, `evaluated_get` et `to_mesh`. Un module JavaScript/TypeScript ne se substitue pas à ces scripts sans pipeline de conversion vérifié.
- V14 a documenté la source technique de faux positifs ; ne pas la régresser.
- La qualification future devra inspecter **trois LOD**, vraies surfaces skinnées à toutes les frames d'appui et intermédiaires, pied libre, portée jambes, cadence, profil bien séparé et 3 vues, comparaison avant/après et SHA256 des ZIP.
- Aucun montage gameplay, sauvegarde, GLB original, PR #300, PRODUCTEUR, DATA/LNR, gate, main.

## Exécution et preuves
- Le code expérimental est publié dans `probe.mjs`, dépendances exactes épinglées, contrôle par `node:assert/strict`.
- Workflow `.github/workflows/match3d-oss-bvh-lab.yml` **workflow_dispatch uniquement** ; aucun lancement déclaré ni résultat CI inventé.
- Tests locaux avec npm dépendances réelles : **NON EXÉCUTÉS** lors de cette intervention (pas de réseau npm fonctionnel dans le conteneur d'exécution). Le HEAD publié ne constitue pas une preuve PASS.
- Prochain jalon : déclencher sur la branche R&D le workflow manuel, inspecter son succès réel et vérifier l'absence de régression, puis réaliser sur copies des GLB un test skinned apparié qui n'écrit pas au runtime.

## Verdict global
**ORANGE — audit utile, expérimentation statique publiée, qualification réelle encore absente.** Aucune fusion ni gate.

## Réception du 6 novembre — essais réels et réemploi source Ekza

### A/B Blender sur copies R&D : RUN 42287132476
- HEAD `a151d72e6afa35f307e7a28c7cd49aea7c1d034e`, job SUCCESS. Artefact #13538212527, 105441663 octets, ZIP SHA256 recalculé sur octets téléchargés `afba64d9c2885f25c310f1b91f940c3ade1624e2391ef7371ef43615feac7054` = digest GitHub.
- Rapports JSON téléchargés et inspectés : A (`baseline-three-bone`) et B (`two-bone-proxy`), 171 images par variante, 342 PNG originaux de l'étude A/B (le ZIP contient en plus 8 PNG sous ses répertoires de travail).
- 3 GLB sources authentiques, SHA256 par LOD `8ab6118d...`, `180adeaf...`, `81bebd11...` (octets exacts documentés dans run-summary.json).
- Baseline A : `denseTemporalFloorQualified=true` 3/3 LOD, 0 croisement strict aux 13 frames supplémentaires. Proxy B : `denseTemporalFloorQualified=false`, 7 mesures pied sous -1 cm (LOD0 frames 34,36 ; LOD1 24,34,36 ; LOD2 24,36), extrema -1.088 / -1.109 / -1.118 cm selon LOD. Ne jamais promouvoir ce proxy à « véritable Ekza ».
- Inspection visuelle réellement effectuée sur planches des 3 LOD, vues front/profile/threequarter, frames 24/34/40, 54 images sélectionnées. Anatomie encore raide, le profil partagé superpose souvent les deux joueurs, pas de vrai contact rugby, aucune approbation artistique (0/3 LOD). Les 342 images n'ont PAS toutes été inspectées individuellement.

### Réemploi de la vraie source Ekza : RUN 42289963938
- Upstream **réel et épinglé** : `ekza-space/ekza-studio` SHA `b7e3e92f25d2656caace50c0869aeef0d562dbf3` ; fonction `solveTwoBoneIk` appelée sans réécriture depuis `packages/rig/src/ik/twoBone.ts`. Workspace pnpm, licence originale MIT conservée.
- HEAD PR #350 `63c8bfb7ff6e26e8bc5d09107603f2a83d281488`. GitHub job `128140498205` COMPLETED/SUCCESS : 1 test Vitest effectif, contrôle additionnel obligatoire `REAL_EKZA_6_OF_6_ACTUALLY_EXECUTED`. Première tentative antérieure avait produit un faux vert (« No test files found »), résolu en plaçant le test dans `packages/rig/test/` et en exigeant la présence du JSON.
- ZIP artifact #13539795962, SHA256 recalculé `5c1363a22bdce01fd4e75ec41afb098e01d7c3ff86a8dc6713f0f904afbce883` identique GitHub ; quatre empreintes internes 4/4 concordantes.
- Les 3 GLB originaux ont été lus directement, 53 os ordonnés sur chaque LOD, mêmes cartes ; chaque côté a une cuisse tibia env. 0.394707 m et tibia-pied env. 0.407331 m. Six appels réels au solveur (LOD 0/1/2 × G/D) ont renvoyé `reached=true` et quaternions normalisés / finis.
- **Périmètre exact du test :** longueurs d'os tirées des vrais GLB, MAIS transformations rest/targets canoniques simplifiées ; aucune animation ni semelle skinnée issue d'Ekza et aucun résultat `plantFeetChannels` sur programme de rig compilé. Aucune équivalence Blender ↔ Ekza ni amélioration cinématique prouvée.

### Décision
**VERT uniquement** pour la CI BVH statique, le rendu A/B existant et l'exécution directe du vrai solveur Ekza sur les 6 dimensions de jambes ; **ROUGE pour le candidat proxy Blender B** sur la pénétration temporelle ; **ORANGE global R&D** pour la véritable intégration et qualification artistique. Prochain travail : pont de repères et quaternions Ekza ↔ Blender, foot pins réels sur copies de 53 os, mêmes 19 frames × 3 LOD, mesure des chaussures skinnées, images A/B et inspection exhaustive, sans changer baselines/jeu/PR #300.

## Extension qualifiée du 6 novembre — vrai pont et vrai Plant Feet Ekza

### 1. Exact-rest solver (vraies TRS glTF, pas seulement longueurs)
- Nouveau script `extract-real-rest-ik.py` : parse les 3 GLB originaux, refuse mismatch SHA256, 53 joints et hiérarchie, exporte les TRS de repos des articulations/ancêtres.
- Nouveau test `ekza-rest-world.test.ts` : appelle `solveTwoBoneIk` **original** depuis Ekza upstream SHA `b7e3e92f25d2656caace50c0869aeef0d562dbf3`; reconstruction FK de 6 positions monde.
- CI <https://github.com/Xynph/cadrage-debordement/actions/runs/42291347853> SUCCESS, run HEAD `aeceeca424cfbd5901c91e3e581d0aef36fccd09`; ZIP #13539023010 SHA256 recalculé = digest GitHub `8d74fee50c054dbf2b8a9cd5f566889dd1bd9ac755ced2bc7a6cef96eb7a0815`; 3/3 fichiers du manifeste, erreur max 8.461545×10⁻⁸ m. **Cibles synthétiques**, pas appuis du match.

### 2. Pont vrai Ekza → vraies armatures skinnées Blender
- Script R&D `ekza_blender_bridge.py` : lit les quaternions natifs du run ci-dessus, déduit et valide le repère rig Blender vs GLB (repos gauche/droite) sur trois LOD 53 os, convertit les matrices de chaque os, impose distance pied/cible <2 cm et déplacement de vrais sommets de pied >0.1 cm, génère images avant/après face/profil/3⁄4.
- CI <https://github.com/Xynph/cadrage-debordement/actions/runs/42292338534> SUCCESS au HEAD `4cf469de006a1dff81ffddef21f2f06a9da06f2d`. Première tentative 42292073643 échouée (HTTP 401 lecture API), corrigée par `actions/download-artifact@v4` sur run épinglé exact.
- ZIP #13539673940, **3 207 880 octets**, SHA256 recalculé sur octets téléchargés = GitHub `2432093cea3580c55ab0201f5f719809d2552ec7d1d46e7f06cdf0fc865ddc3f`, manifeste **19/19**.
- 3/3 LOD × 2 variantes × 3 vues = 18/18 PNG, **inspectées visuellement**. Alignement rest glTF/Blender 0 cm (arrondi de rapport) et erreur cible 0 cm. Vrais sommets pieds déformés, 850/837 (LOD0 G/D), 263/258 (LOD1), 57/52 (LOD2) ; déplacements moyens centroids 5.98–6.38 cm. **Semelles du corps après pose autour de 3.29 à 3.45 cm au-dessus de z=0 (pas au sol) : NON QUALIFIÉ ARTISTIQUEMENT**. Pas de chaussure GLB séparée. Ce run est une pose statique, pas 19 frames ni 342 vues temporelles.

### 3. VRAI `plantFeetChannels` compilé sur squelettes CD
- `extract-real-rest-ik.py` étendu pour construire un `SkeletonDesc` parent-before-child avec les 53 joints skin et ancêtres, noms originaux, humanoid map obligatoire, empreinte GLB. Nouveaux test/workflow `ekza-plant-feet-real.test.ts` / `match3d-oss-ekza-plant-feet.yml`.
- La chaîne utilisée est **authentiquement issue du code source upstream Ekza** : `registerBuiltinRigOps`, `autoRig({ik:{legs:true}})`, `compileRig`, `plantFeetChannels`, puis évaluation `RigProgram.evaluate`. Pas une imitation de pin. Résultat 3 LOD × 2 jambes, 53 joints originaux/LOD, 26 contrôles et 2 membres IK par programme ; six cibles de test déplacées de 6% vers la hanche par rapport au pied au repos.
- CI <https://github.com/Xynph/cadrage-debordement/actions/runs/42293410777> run HEAD `23b5c5f6f485ff7417c14d6a8e6d2e4c87af3e29`, **COMPLETED/SUCCESS**, Vitest 1 vrai test, garde-fou `ORIGINAL_EKZA_PLANTFEET_6_OF_6_PASS`. Artefact #13539249653 SHA256 octets téléchargés = digest GitHub `128ea3f254bd42b78052c50d810334ed469e54ce885e609a3bd4bab15db08e19`, 3/3 empreintes internes. Six positions atteintes, erreur max 1.28×10⁻¹⁵ m. **Ce sont des cibles synthétiques, pas encore des pins issus de la locomotion V25**.

### Limites explicites de qualification
- **Validé VERT techniquement** : code original `solveTwoBoneIk` exécuté sur vraies TRS/hierarchies ; matrices converties vers vrais os Blender et skinned mesh modifié sur 3 LOD ; vrai `plantFeetChannels` exécuté en rig compilé 53 os avec six cibles synthétiques.
- **NON QUALIFIÉ** : continuité des deux foulées 19 frames, cycle marche, vrai contact/sol lors des poses natives, glissement XY, genoux-hanches-épaules, mains/porteur, déformations chaussures, tri-croisements, 342 images temporelles générées par Ekza et approuvées. Ancienne campagne **342 images du proxy Blender 2 os** reste écartée et n'est pas un test d'Ekza.
- **Prochaine décision** : uniquement si un raccord temporel strictement apparié 19 frames × 3 LOD × 2 variantes produit rapport de vrais pieds skinnés (corps et chaussures), aucune pénétration ni perte de cadence, images entièrement inspectées et ZIP SHA256, sinon STOP. Aucune PR prête à merger pour ce lot. Pas de READY, gate, fusion ni modification de la PR #300 ou de la branche V25 existante.

## Grand essai temporel authentic V25 — STOP sur vraie impossibilité de reach

### Prévol chaussures source Blender (VERT)
- [Run 42294794354](https://github.com/Xynph/cadrage-debordement/actions/runs/42294794354), commit `03a4f421d34c981c7332b80c5c5b682c8ccd2abc`, SUCCESS. **3 GLB corps + 3 GLB chaussures originaux** identifiés par SHA du lock, armatures séparées de 53 os avec mêmes noms et matrices de repos (erreur max = 0), 3/3 LOD compatibilité anatomique de repos. Les chaussures ont de vrais sommets pondérés pied : 241/239 (LOD0 gauche/droite), 64/61 (LOD1), 30/31 (LOD2). Ce ne sont PAS encore des chaussures animées en V25. ZIP #13540559049, SHA256 local = GitHub `f76f4add5809f472e00ef9b32ea586647532724216dfe8d3215713639ee7ae40`, manifeste 1/1 vérifié.

### Extraction des vrais appuis et poses V25 (VERT acquisition)
- Le runner `export_original_19frame.py` n'altère pas le script original ; sa copie instrumentée réexécute le V25 SHA `065589001fbef9641070218b6f85bb597da96a6a`, avec 3 GLB corporels au SHA figé, 19 frames × 3 LOD, deux acteurs, 53 matrices d'os chacun, matrices originales des racines et **vrais objets cibles IK Blender**.
- [Run 42295487770](https://github.com/Xynph/cadrage-debordement/actions/runs/42295487770) au HEAD `b903331d31a6020ebd872265d91c64916eb03d6b` COMPLETED/SUCCESS ; **57/57 échantillons**, **171/171 images BASELINE seulement**. ZIP #13541832404 SHA256 recalculé = GitHub `3b6c3520aba842940e8de92bc4c2e19d5b815b2bb81cd614ae3c7f439cb72140`, manifeste 178/178 OK. Originale copie source JS/Blender et sources GLB inchangées.
- Particularité de notre **exporter R&D uniquement** : il sérialise les `mathutils.Matrix` avec indices `m[col][row]`, donc valeurs transposées par rapport au column-major glTF/Three.js. Le consommateur `ekza-v25-truepins.test.ts` détranspose explicitement les observations Blender ; les matrices Ekza restent lues en column-major natif. L'erreur initiale de convention a été diagnostiquée puis corrigée. Aucune donnée source modifiée ni colonne ignorée.
- Les cibles sont réellement celles des contraintes V25, conservées par frame ; les amplitudes d'influence échantillonnées ne sont pas des pins synthétiques. La vraie orientation cible du pin n'est pas entièrement verrouillée dans cette première adaptation (orientation de pied actuelle) : ne pas revendiquer de rotation de semelle fixée.

### VRAI Ekza sur les vrais pins : **ÉCHEC CORRECT ET STOP**
- Test `ekza-v25-truepins.test.ts` importe le vrai code Ekza upstream SHA `b7e3e92f25d2656caace50c0869aeef0d562dbf3` (`autoRig`, `compileRig`, `solveBoneChannels`, `plantFeetChannels`), reconstitue d'abord les vrais os et positions dans les repères glTF, puis applique les pins V25 source. Aucune modification racine ou terrain autorisée.
- [Run terminal 42297804769](https://github.com/Xynph/cadrage-debordement/actions/runs/42297804769), HEAD `9d3bf7b91916b58f2308bb1d8b3e1fbf5451b618`, CI FAILURE **attendue/fail-closed** parce que `plantFeetChannels.reached=false` lors du premier appui actif. Cas précis **LOD0 / acteur A / frame22 / pied gauche** ; warning upstream `Plant Feet: the L foot cannot reach its pin; the leg was straightened towards it`.
- Valeurs mesurées : distance hanche → pin source **0.805630074354069 m** ; portée anatomique des deux segments Ekza **0.8020380174703425 m** ; dépassement **0.0035920568837265 m**, soit **3.592 mm**. Reconstruction des vraies poses V25 vers `RigProgram` à cette frame : erreur max **0.00000163687433 m** (0.001637 mm). Repos glTF↔Blender : **0.00000026892165 m** (0.000269 mm). Le défaut n'est donc PAS le précédent problème de matrice ou un décalage de racines.
- L'ancienne IK Blender V25 utilise une chaîne à trois os, alors que le solveur natif Ekza ici est réellement limité à cuisse+tibia ; cela peut expliquer la divergence de portée, mais **cause mécanique définitive non établie**. Vérifier portée et véritable semelle avant de choisir une solution ; ne jamais étirer artificiellement les segments ni déplacer racine/pin.
- Artefact terminal #13542577267 SHA256 octets recalculé = GitHub `e8c1a638effef2cedc7f28ca3c0e6d620681d5c40eb142922fd27fbcdbf85752`; JSON de refus `real-ekza-truepins.json` syntaxiquement VALIDE avec état `STOP_V25_REAL_STANCE_PIN_UNREACHABLE`, rapport de diagnostic et manifeste **2/2** SHA vérifiés.
- Les runs précédents échoués : #42296185359 (capture pas encore disponible), #42296671979 (trièdre faussé par convention de matrice), #42297003703 (littéraux `\\n` commentant le décodage), #42297192896 (vrai warning sans diagnostic chiffré), #42297442935 (diagnostic valide mais JSON terminé par texte `\\n` non JSON), maintenant corrigés. Aucun de ces runs n'est comptabilisé comme PASS.
- **STOP respecté** : aucune nouvelle variante 342 captures par vrai Ekza générée ; 171 images sont **seulement la référence**. Une exécution qui se termine en SUCCESS sans satisfaire `reached` ne vaut rien. **0/342 images A/B Ekza produites**, **0/3 LOD Ekza animés qualifiés**, aucun FPS/contact/sol approuvé. La campagne antérieure 342 PNG du PROXY BLENDER refusé est distincte et ne doit jamais être vendue comme un run du vrai Ekza.

### Décision et prochaine expérience autorisée
- **FEU VERT** preuves de skin/body-shoes de repos et capture temporelle originale ; **FEU ROUGE** vrai pin de frame22 non atteignable avec chaîne Ekza deux segments inchangée ; **FEU GLOBAL ORANGE / STOP candidat** pour évolution R&D, **aucun READY/gate/fusion**.
- Prochaine phase : analyser géométrie exacte entre cible `foot_l` de l'IK Blender 3-link et end-effector `foot_l` de l'IK Ekza 2-link, longueur semelle vs cheville, et possibilité légitime d'IK two-bone avec cible anatomiquement atteignable *sans changer les positions d'origine des pieds*, puis nouvelle preuve A/B sur copies. Ne jamais corriger par plafonnement arbitraire ni raccourcissement des jambes/cible. Si impossible, conserver IK Blender 3-os existante.

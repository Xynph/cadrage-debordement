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

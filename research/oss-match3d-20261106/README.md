# MATCH 3D V25 — laboratoire open source isolé

Ce dossier ne modifie **aucun** fichier du jeu, GLB, script Blender, rig 53 os, baseline ou PR #300. Il exécute uniquement une preuve de fonctionnement **statique** de `three-mesh-bvh` sur trois densités synthétiques de boîtes : absence d'intersection, intersection et rejet d'auxiliaire non skinné.

Exécution facultative dans une copie de cette branche : `cd research/oss-match3d-20261106 && npm install --no-audit --no-fund && npm test`.

Limites : `userData.skinned` dans le test est une étiquette fictive ; les meshes ne sont **pas** des `THREE.SkinnedMesh`. Aucune animation, aucun GLB réel ni métrique de surface skinnée / animation humaine n'est testé. La compatibilité avec les 53 joints et les vrais trois LOD reste NON QUALIFIÉE. Ne pas appeler ceci un correctif des contacts rugby.

Sources : `https://github.com/gkjohnson/three-mesh-bvh` MIT ; `https://github.com/ekza-space/ekza-studio` MIT sauf exceptions ; `https://github.com/jsantell/THREE.IK` MIT.

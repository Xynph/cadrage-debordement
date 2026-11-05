# Jalon Work : ajustement réel du T-shirt, 5 novembre 2026

Base exacte : 2b14a92f4858ea1faa60e858f53244c4381f3142. Trois GLB dérivés modifiés, sources CharacterCreator CC0 intactes. Indices/topologie conservés à ce jalon ; aucune prétention de retopologie complète. Aucun élargissement du masque, changement de matériau ou remplacement du vêtement.

Méthode : bake du morph athlétique, projection de proximité sur les triangles du corps du même LOD, déplacement vers l'extérieur pour une marge de 12 mm et transfert barycentrique des quatre poids dominants, renormalisés. Les matrices de bind sont contrôlées identiques. Le vêtement conserve 53 joints et ses UV. Les morphs du vêtement sont retirés après bake pour éviter une double application ; ce dérivé est spécifique à la morphologie de qualification actuelle.

Résultat : LOD0 216/619 sommets déplacés (16,30 mm max), LOD1 82/222 (15,65 mm max), LOD2 128/378 (18,58 mm max). Joint dominant changé sur 64/20/55 sommets. Aucun triangle ajouté/supprimé. Les empreintes source/sortie sont dans lod/shirt-fit-report.json.

Réception : 15 captures avant puis 15 après réellement obtenues sur Chromium SwiftShader local ; 3 LOD × repos/passe face et profil/plaquage face et profil, inspectés en planche. Les deux grandes traversées du torse disparaissent sur ces vues. Le T-shirt reste continu au col dans les vues reçues. Les manches restent anguleuses et les mouvements de bras incorrects, surtout de profil ; ce jalon ne qualifie pas les gestes. LOD2 visage/chaussures restent grossiers. Pas de scène de contact entre deux joueurs ni benchmark apparié v23/v24.

Tests ciblés : assembly, shirt-fit, audit synthétique (8), rugby-clips, player-stage PASS. Chromium : 3 LOD / 15 images, aucune erreur JS ni requête externe. Aucun raccordement au match réel. CI complète du nouveau commit à recevoir. PR #300 DRAFT, aucun gate/fusion.

Reproduction : installer @gltf-transform/core et @gltf-transform/extensions 4.5.1 dans un répertoire isolé, définir NODE_PATH ; restaurer les trois T-shirts LOD de la base ci-dessus puis `node tools/match3d-v24-shirt-fit.cjs`. L'outil refuse un T-shirt déjà ajusté. Le générateur LOD actuel produit les versions non ajustées : réappliquer cet outil après toute régénération.

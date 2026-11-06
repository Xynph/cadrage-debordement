# Protocole apparié de réception des vrais pieds skinnés — PR #350

**PRÉPARÉ, NON EXÉCUTÉ sur GLB réel.** Ne rien modifier dans PR #300, main, baselines, rigs, GLB ou scripts V25. Comparaison en copies hors jeu seulement.

## Sources exactes
- Branche source V25 à verrouiller sur son HEAD réel avant le test, `tools/match3d-v25-lab/remote/lock.json` sur cette branche. Blender 4.5.3 épinglé, baseline source `d6fbcb38438609c0ca461f54717655223b438b09` référencée dans le lock. Ne jamais présumer que cette SHA est le HEAD V25 actuel.
- Par LOD, émettre SHA256 de chaque GLB corporel et chaussure originel + SHA256 de la liste **ordonnée** de 53 os. Comparer aux valeurs du `lock.json`. Le comparateur pairé exige le même SHA corps entre deux variantes, et la même carte d'os ; le pipeline doit vérifier les octets réels séparément.
- Squelette réel : `thigh_l`, `calf_l`, `foot_l`, `ball_l` et homologues droits. Remapper explicitement repères d'Ekza et de Blender (sens d'axes, pivot, quaternion local, longueur, rotules) ; ne pas copier tel quel un module TypeScript workspace dans le Python Blender.

## A/B strict
- A : copie de l'IK Blender actuel, immuable. B : candidat séparé inspiré des calculs `plantFeetChannels` / `solveTwoBoneIk` d'Ekza. **Un seul facteur** change : solveur jambes/foot pins. Ne pas déplacer artificiellement racines, terrain ou caméra ; conserver rig et poids des trois LOD, 30 rigs, mouvement du pied libre.
- Comparer les mêmes **19 frames** `[1,10,18,22,24,26,28,30,32,34,36,38,40,45,50,60,70,80,90]` sur LOD0/1/2, deux acteurs, deux pieds, avec `evaluated_get(...).to_mesh()` et vraies surfaces skinnées en coordonnées monde. Les semelles doivent rester dans [-1,+3] cm, dérive XY appui ≤5 cm, portée longueur jambe ≤100%; vérifier également cinématique des deux foulées et dégagement du pied libre.
- Intersections : broad-phase BVH puis croisements stricts de triangles et coplanaires non résolues **séparément**, classification de régions anatomiques, mêmes maillages filtrés. Historique V14 : les `Icosphere` techniques non skinnées ont été exclues sur preuve de provenance ; conserver cette exclusion exacte, ne pas masquer la peau.
- Rendus : trois vues (face / profil / trois-quarts), 19 frames et 3 LOD = **171 images par variante, 342 images par paire A/B**. Profil sans acteurs superposés ; inspecter réellement les captures, cadence, flexion genoux-hanches-épaules, pas de traversée de peau. Mesurer aussi distance mains/porteur ; aucun chiffre de collision ne vaut approbation artistique.
- ZIP et preuve : SHA256 du ZIP local contre GitHub, manifeste SHA256 par GLB/PNG/JSON, rapport Blender réel, head SHA exact, log runner. Une CI SUCCESS n'est pas une preuve visuelle à elle seule. Performance 30 rigs TV/zoom uniquement après conformité, sur scènes strictement appariées et sans proclamer les FPS SwiftShader comme FPS joueur.

## Vérificateur de rapports
`python compare-skinned-reports.py baseline.json candidate.json` attend :
- `schema: "cd-skinned-comparison-v1"`, `source: "actual-evaluated-skinned-vertices"`, `rig_bone_count: 53`, `frames` listées plus haut, `views: ["front","profile","threequarter"]`.
- `method` = `baseline-blender-ik` ou `ekza-derived-candidate` ; booléens `scene_root_motion_unchanged`, `auxiliary_excluded_by_provenance`, `glb_originals_untouched` tous vrais.
- `lods` exactement `lod0`, `lod1`, `lod2`. Chaque LOD porte `source_glb_sha256`, `bone_names_sha256` (64 caractères hexadécimaux), `skinned_foot_vertices: true`, `samples: 19`, `render_views: 57`, `visual_review: "approved"|"rejected"`, nombres `min_sole_z_cm`, `max_sole_z_cm`, `max_stance_xy_drift_cm`, `max_leg_reach_ratio`, `strict_non_coplanar_crossings`, `coplanar_unresolved`.
- La structure et les seuils sont vérifiés en refusant absence, non-finitude, non-parité ou régression. **Mais le comparateur ne vérifie ni les octets GLB/PNG, ni la réalité des mesures, ni la décision visuelle : il ne certifie pas la provenance des JSON.**
- Codes retour : 0 si critères déclarés conformes, 1 si non conforme, 2 si rapport invalide. Ne PAS conclure VERT sans artefacts Blender et inspection indépendante.

## Test du comparateur seulement (sans Blender)
Fixtures fictives construites dans un laboratoire externe : pair validé structurellement (code 0), SHA du LOD1 différent rejeté (code 2), `visual_review="rejected"` refusé (code 1). **Ces tests ne sont pas des mesures MATCH 3D**.

## Décision
Aucune intégration de bibliothèque tant que la vérification CI microprobe, les vraies surfaces skinnées 53 os sur 3 LOD et les captures appariées ne sont pas reçues. Aucun gate ni fusion.

# MATCH 3D V25 — réception du premier plaquage original (06/11/2026)

**Verdict officiel : REFUS VISUEL, 3/3 LOD.** Aucun branchement moteur, aucune animation + Kickback.

## Provenance et réception vérifiées

- Branche R&D : `research/match3d-v25-open-source-tools-20261105`.
- HEAD du run : `6697bc1908dd530aa126d95a258ba8fac26d8162`.
- Run GitHub [42187293618](https://github.com/Xynph/cadrage-debordement/actions/runs/42187293618) : `completed/success`, job `external-engines` SUCCESS, `reception` SKIPPED intentionnellement.
- Artefact ID `13487539963` ; archive ZIP 4 498 312 octets ; SHA256 GitHub **et ZIP récupéré** : `41b0d1180de09052c8bea0df9c790bfe94de7519a25acf8f6d342252714c4897`.
- Archive extraite et contrôlée : 33 entrées (30 images PNG, `original-tackle-report.json`, `runner-status.json`, `blender-original.log`). `errors=[]`, 3 LOD, 5 frames × 2 vues par LOD, toutes les images réellement produites. Pipeline et géométrie **techniquement exécutés**, sans validation artistique.
- Toutes les vues face/profil inspectées aux frames 1/22/40/60/90 sur LOD0/1/2. La caméra de profil superpose visuellement les personnages, le basculement à frame 60 ne montre aucune véritable prise, et l'appui des pieds est irréaliste. Aucun plaquage rugby crédible. `visualApproval=false`.

## Mesures de vraies peaux, sans proxy rigid-body

À la frame 40, quatre distances poignet → triangle skinné opposé (en centimètres) quasiment égales pour les 3 LOD :

| Acteur | Main gauche | Main droite |
| --- | ---: | ---: |
| A (plaqueur expérimental) | 38,9 | 71,8 |
| B (porteur) | 102,6 | 44,6 |

**0/4 ≤5cm** pour le contact de saisie. Loin de constituer un véritable enveloppement.

| LOD | Triangles par acteur | Croisements triangles non coplanaires frame 40 | Candidats BVH frame 40 |
| --- | ---: | ---: | ---: |
| 0 | 24 073 | 225 | 255 |
| 1 | 7 457 | 149 | 179 |
| 2 | 1 547 | 76 | 106 |

Méthode : intersection stricte segment-triangle sur candidats BVH, dans les deux sens. Les tangences et les contacts coplanaires sont explicitement `unresolved` : **ne pas présenter ce compte comme une détermination exhaustive des pénétrations**. Les nombres bruts ne sont pas comparables entre LOD car densités différentes.

La racine B−A vaut 2,30m/1,77m/1,48m/1,26m/1,43m aux frames 1/22/40/60/90, toutes en X ; c'est la **trajectoire originale écrite dans le script**, pas un alignement de surface. Point à diagnostiquer : déjà 109/78/31 croisements non coplanaires au frame 1 selon LOD malgré 2,30 m entre racines. La relation entre transforms des objets GLB, armature et sommets évalués doit être vérifiée avant tout nouveau mouvement.

Sol : plan de référence dérivé des véritables semelles au frame 1 (LOD0 z=0,38037m, LOD1 z=0,38266m, LOD2 z=0,38355m), **aucune simulation de terrain ni six contacts physiques validés**. Frame 60, quatre pieds évalués par LOD entre 7,4cm et 22,2cm au-dessus du sol (min/max selon LOD). Six régions anatomiques chest, pelvis, knee L/R, foot L/R mesurées sur les sommets dominants skinnés, et rapportées pour deux acteurs × trois LOD × cinq frames.

## Correction ciblée non cosmétique et suite

Au commit `111cf896676cdc3ef5855acdf261f55b5fe3ed45`, le script de test a été enrichi avec AABB des vrais triangles skinnés évalués, positions des racines mondiales et lacune X entre AABB. Ce diagnostic isole un éventuel problème de transform glTF/armature/mesh, sans déplacement artistique arbitraire. **Son nouveau run doit être réceptionné avant toute conclusion sur la cause.**

Suite obligatoire : réceptionner le nouveau run, comparer volumes et racines et corriger, si démontré, l'application réelle des transforms communes aux objets de chaque acteur, sur copies exclusivement ; créer ensuite une cinématique nouvelle anatomiquement plausible avec véritable prise, chute et récupération, puis inspecter vues et six appuis. Aucune comparaison Kickback sans validation visuelle de l'animation seule.

Non-modifications : PR #300, GLB sources, moteur, PRODUCTEUR, DATA/LNR, sauvegardes, main, gate, fusion et Work. CMU 18_03/19_03 refusé, Player Motion non acquis.

## Réception après correction de la hiérarchie glTF (complément)

- Run [42188844864](https://github.com/Xynph/cadrage-debordement/actions/runs/42188844864) au SHA `974acbba374317b5c1176229fc5c296d975bc966` : `completed/success`.
- Artefact GitHub `13489190339` : ZIP **4 441 668 octets**, SHA256 octets locaux = digest GitHub `06f92dc3b7f6e5be62fdd2a5d6a8cced3d6cfd602732c6c841e2cc533ddd47f2`.
- **33 entrées dont 30 nouveaux PNG** aux mêmes 5 frames × 2 vues × 3 LOD ; rapport `errors=[]`. Toutes les vues inspectées.
- À frame 1 : écart racine A/B X inchangé **2,30 m**, écart des AABB skinnées X **0,30 m** sur LOD0/1/2, croisements non coplanaires **0/0/0** (contre 109/78/31 avant correction). **Correction structurelle mesurée**, sans translation ajoutée pour faire correspondre les mains.
- Frame 40 : mains A gauche/droite **99,6/83,1 cm**, B **90,5/103,2 cm** sur LOD0 (valeurs des LOD1/2 très voisines) ; 0/4 à ≤5cm. Croisements stricts **30/30/30** LOD0/1/2 ; les comptes coplanaires/tangents restent non déterminés, et le volume de pénétration n'est pas résolu.
- Frame 60 : minima des pieds à +7,4 à +22,2 cm environ au-dessus du plan calibré selon acteur/LOD ; aucun contact sol physique. Le clip montre des personnages suspendus et une bascule sans plaquage. **REFUS VISUEL maintenu 3/3 LOD**.
- **Kickback non exécuté**, puisque la qualité cinématique initiale est insuffisante. Cette correction constitue une fiabilisation du banc de test, non une animation rugby livrable.

Suite : concevoir sur les copies des animations locomotion/pose et appuis réalistes, y compris une saisie anatomique chronométrée, en conservant le parent d'acteur glTF désormais cohérent. Vérifier chaque frame et les intersections de vraie peau avant toute comparaison physique.

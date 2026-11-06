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

## Nouvelle tentative cinématique R&D : jalon 49953471

Commit `499534718ad4e606879d7ac3b337b3a7350eb6d6` : remplacement des premières poses trop rudimentaires par des phases originales synchronisées approche / plant / tentative de contact / tentative de chute / récupération, avec mouvements keyframés des os de bassin, torse, bras, cuisses, mollets et pieds sur les mêmes deux racines spatiales documentées. Les copies des trois LOD utilisent toujours le parent actor_root corrigé au commit `974acbba`. Les nouveaux comptes rendus distinguent les distances réelles des deux épaules et des quatre poignets aux peaux opposées, tests stricts segment-triangle non coplanaires, minima des six régions de peau et écarts à la hauteur sol calibrée. La qualification automatique est intentionnellement conservatrice, et `visualApproval=false` jusqu'à inspection humaine de chaque capture.

Run [42189938627](https://github.com/Xynph/cadrage-debordement/actions/runs/42189938627) lié au commit source. **Ne pas déclarer qualification/rendus/SHA256 du nouveau run sans en vérifier la conclusion et les octets.** Conserver le REFUS précédent tant que l'essai n'a pas été inspecté. Aucune comparaison Kickback exécutée ou autorisée avant qualification.

## Deuxième itération cinématique — réception réelle et refus (06/11/2026)

- Commit `499534718ad4e606879d7ac3b337b3a7350eb6d6`, run GitHub [42189938627](https://github.com/Xynph/cadrage-debordement/actions/runs/42189938627) **SUCCESS**. Artefact `13489221731`, ZIP **4 493 092 octets**, SHA256 GitHub et octets téléchargés vérifiés : `4441f683dcd1afe68d476cdf0963b43cebd4cde79813143aec6bbd3b866c528c`. **33 entrées : 30 vraies captures PNG** (3 LOD × 5 instants × face/profil), rapport `errors=[]`, 3 LOD complets.
- Inspection réelle de **30/30 PNG** par contact sheets LOD0/1/2 : approche face à face, mais bras n'entourant pas le porteur, pas de contact épaule crédible, et à frame60 les deux corps basculent séparément **en l'air**, sans chute avec appui au sol ; récupération instantanée artificielle. **REFUS VISUEL 3/3 LOD.**
- Frame 40, distances poignet à la vraie peau adverse LOD0 (centimètres), A gauche/droit **102,5 / 75,4** ; B gauche/droit **87,7 / 110,8**. Même ordre de grandeur sur LOD1/2, **0/4 mains ≤5cm**. Distances des épaules 87,2 à 115,5 cm sur LOD0, **0/4 ≤8cm**. Le passage dramatique « prise » n'existe pas réellement.
- Croisements segment-triangle **stricts non coplanaires** frame40 : **30/30/30** sur LOD0/1/2 ; frame1 **0/0/0**. Cas coplanaires et tangences non comptés ; pas de prétention à un test exhaustif des pénétrations.
- Frame60, écarts semelles au plan de sol (LOD0) : A gauche/droit **+50,6/+36,7cm**, B gauche/droit **+14,1/+12,1cm**, les autres LOD quasi identiques. Aucun appui réel suffisant pendant la chute. Les six régions poitrine, bassin, genoux G/D, pieds G/D de chacun des acteurs sont numériquement présentes dans le rapport chaque frame ; **il ne s'agit pas de six contacts valides**.
- **Bug de verdict identifié** : le rapport original indiquait `floorStageQualified=true` alors qu'il ne vérifiait que l'absence de pénétration : un acteur flottant passe cette vérification. Commit `63746d42c30b208cdd2abcde41a403c3187c4953` corrige ce faux positif en imposant, pour chaque acteur et instant, au moins une des six régions à ≤5 cm du sol, ainsi qu'aucune pénétration ; il publie aussi la liste `groundedRegionsByActor`. Run de correction [42190314649](https://github.com/Xynph/cadrage-debordement/actions/runs/42190314649) à réceptionner avant de revendiquer sa preuve runtime.
- **Décision** : aucune animation rugby validée, aucune comparaison animation+Kickback, aucune intégration. Conservation de la correction glTF et des contrôles de vraie peau sur copies R&D. Reprendre par recalibrage anatomique et locomotion réellement solidaire du sol, puis reconstruction source du geste (pas d'optimisation cosmétique de décalage racines).

## Réception finale du correctif de validation des appuis

Run [42190314649](https://github.com/Xynph/cadrage-debordement/actions/runs/42190314649) au commit `63746d42c30b208cdd2abcde41a403c3187c4953` : `completed/success` pour l'exécution, laboratoire Blender `external-engines` réussi. Artefact `13490205004` ZIP **4 493 478 octets**, SHA256 GitHub identique aux octets réellement téléchargés : `98f9521ff504f5117a1bf7ff144057e2a016b2cbde638036d58f37d6f0be5a55`, 33 fichiers dont **30 PNG**, rapport avec `errors=[]`, 3 LOD mesurés.

**Contrôle maintenant correct** : `contactStageQualified=false`, `floorStageQualified=false`. À frame 60, sur **chacun des trois LOD**, `groundedRegionsByActor.A=[]` et `groundedRegionsByActor.B=[]` : aucune des six régions poitrine/bassin/genoux G-D/pieds G-D n'est à ≤5 cm du plan calibré pour les deux acteurs. Cela confirme le défaut de flottement. Le run est techniquement vert, mais la cinématique reste **refusée**. La comparaison Kickback demeure non exécutée.

Les nouvelles captures ne corrigent pas la prise ; la prochaine itération ne doit pas multiplier les rotations isolées : elle exige un nouveau mouvement de référence spatialement cohérent avec prise et six appuis, tout en préservant cette baseline expérimentale et la correction du parent glTF.

## Troisième essai indépendant — interaction à deux acteurs avec IK (06/11/2026)

**Source conservée et essais comparables** : l'ancien `original_tackle_probe.py` et ses trajectoires racines restent inchangés (baseline formellement refusée). Le commit `ccddadb0981fb58e352f3cfabc9d3e17f954e86f` ajoute uniquement `original_tackle_interaction_probe.py`, nouvelle source auteur originale : trajectoire d'approche A/B en X (-1,50/+0,80 au départ, -0,35/+0,38 au premier contact), deux IK natifs d'épaule/coude par acteur, cibles extraites des **véritables sommets évalués skinnés du torse adverse**, mesure explicite de la longueur osseuse disponible et des quatre cibles. Aucun clip CMU, achat ni correction cosmétique des racines après calcul de l'IK. Commit `deb41b24f164ad262fcba3db4047eaa17b11430c` sélectionne uniquement ce nouveau script dans le runner Blender épinglé ; la branche, les GLB de jeu, leur moteur et la PR #300 restent intacts.

**Réception vérifiée du run** [42191447793](https://github.com/Xynph/cadrage-debordement/actions/runs/42191447793) au SHA `deb41b24f164ad262fcba3db4047eaa17b11430c`, artefact `13490112080` de **4 460 458 octets**, SHA256 **GitHub = ZIP téléchargé** `4caab4ef27c6ec46cef6822d7460131bada55daa97ba29a7694a342d05bc0e32`. 33 entrées, 30 véritables PNG Blender Cycles CPU sur les trois LOD et cinq phases face/profil, `errors=[]`, `imagesProduced=30`, aucun asset de jeu modifié. Les 30 vues ont été inspectées dans trois montages réels.

**Diagnostic frame 40 :**
- Les quatre distances poignet → peau adverse deviennent **0,0/0,0/4,2/4,1 cm** sur LOD0 ; LOD1 **0,0/0,0/4,2/3,8 cm** ; LOD2 **0,0/0,0/4,7/4,0 cm**. Un contact apparent « à zéro » ne prouve **pas** une préhension anatomique, il peut résulter d'une interpénétration.
- **1971 / 1187 / 467** croisements stricts non coplanaires à frame40 pour LOD0/1/2 ; **2440 / 1306 / 696** à frame60. Ce sont des intersections des triangles de peau, **pas** des simples candidats BVH ; coplanaires/tangences encore non résolus. Les comptes bruts sont sensibles au maillage et non comparables entre LOD.
- Portée osseuse des bras : A gauche/droit **atteignables**, B gauche/droit **hors de portée** à frames40 et60, sur 3/3 LOD. Longueur anatomique bras ≈0,48049m ; distance B-épaule à surface A ≈0,55971m à frame40 LOD0, donc force irréaliste. `authoredArmTargetsReachable=false`.
- Contact épaule-vraie peau frame40 : A ≈10,8–13,8cm, B ≈15,5–17,1cm suivant LOD, **0/4 à ≤8cm**. Les poignets ne constituent donc pas un vrai plaquage épaule/torse.
- Sol à frame40 : A un seul pied reconnu en appui, B les deux ; à frame60 **0 région skinnée sur 6 pour A, 0/6 pour B** sur chacun des trois LOD, et `floorStageQualified=false`. Les vues montrent les deux silhouettes en suspension, leurs jambes étirées vers l'arrière et une pseudo-chute impossible. L'absence d'intersection avec le terrain n'est pas un appui.
- `contactStageQualified=false`, `visualApproval=false`, `physicsComparisonExecuted=false` : **REFUS VISUEL 3/3 LOD**, malgré le passage technique du runner.

**Décision** : cet essai améliore la *mesure* de la localisation de la peau et l'introduction de contraintes IK, mais l'animation reste NON QUALIFIÉE. Les quatre poignets artificiellement proches sont obtenus avec une interpénétration forte et une portée incorrecte. Ne pas brancher ce clip, ni masquer les défauts avec des translations ou PinJoint. Ne pas lancer Kickback. Étape suivante : séparer cinématique de contact (sans chute) et chute avec poses d'appui éprouvées, revoir l'approche selon les envelopes des triangles et la portée des deux acteurs, limiter les IK à des prises réalisables et contrôler les captures à haute fréquence avant de reconstruire la chute.

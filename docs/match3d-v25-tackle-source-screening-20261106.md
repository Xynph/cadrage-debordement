# MATCH 3D V25 — sélection d'une source de plaquage deux acteurs (06/11/2026)

Statut : **AUCUNE SOURCE LIBRE DE PLAQUAGE QUALIFIÉE**. Ce document ne valide ni clip ni animation de jeu.

## Référence et interdits

Branche R&D `research/match3d-v25-open-source-tools-20261105`, point de départ `40ea95725dfe34f47097a5f6571405c58eb5494e`, passation #73 commentaire 6680342892. CMU `18_03/19_03` est formellement **REFUSÉ** comme plaquage : transfert de deux clips et 18 rendus réussi, mais corps croisés, racines ~0,20–0,23 m, mains droites ~0,107–0,176 m de la vraie peau, appuis non calibrés. Ne pas convertir cette réussite de retarget en validation artistique. Kickback `strip_root_motion=false` reste uniquement qualifié pour stabilité debout, pas pour interaction.

Interdits : pas de translation arbitraire pour faire coïncider les mains, pas de PinJoint masquant un clip erroné, pas de reprise de CMU comme tackle, aucun asset commercial non acquis, pas de modification moteur/GLB/PR #300/PRODUCTEUR/DATA-LNR/sauvegardes/main, ni gate/fusion.

## Prospection vérifiable et verdict par source

| Source | Licence constatée | Intérêt | Verdict |
| --- | --- | --- | --- |
| [CMU Graphics Lab](https://mocap.cs.cmu.edu/) | Site annonce « free for all uses » | Mouvements humains réutilisables | Le duo 18_03/19_03 échoue anatomiquement ; **exclu comme plaquage**. Aucune autre séquence authentique tackle à deux acteurs démontrée à ce stade. |
| [RAI HOLD](https://github.com/rai-opensource/hold) | CC BY 4.0 dans le dépôt | BVH, locomotion et appuis sol calibrés dans le traitement | Pas de paire de plaquage attestée ; possible **référence technique pour l'appui** seulement, sans inventer une interaction. |
| [InterAct retarget](https://github.com/orangeduck/interact-retarget) | Explicitement non commercial | Multi conserve l'espace relatif des acteurs | **Exclu du jeu commercial**. Approche d'analyse « multi » documentable, aucun asset réutilisé. |
| [Ubisoft LAFAN1](https://github.com/ubisoft/ubisoft-laforge-animation-dataset) | CC BY-NC-ND 4.0 | BVH | **Exclu**, restriction commerciale et dérivés. |
| [SFU Mocap](https://mocap.cs.sfu.ca/) | Recherche uniquement, produit commercial interdit | Sports | **Exclu**. |
| [KTH Multiview Football II](https://www.csc.kth.se/cvap/cvg/?page=footballdataset2) | Recherche académique uniquement | Séquence sliding tackle de football, pas rugby ni vrai duo | **Exclu**. |

**Aucune licence de code open source ne confère automatiquement des droits sur les animations ou scans fournis avec un logiciel.** Pour une nouvelle source, conserver URL de téléchargement, titulaire, texte de licence applicable au fichier précis, SHA256 et horodatage de consultation, et vérifier les droits de modification/redistribution en jeu.

## Offre commerciale distincte : Player Motion — information uniquement

- [Catalogue rugby](https://playermotion.games/animations/rugby) : annonces de paires « Front-on tackle shoulder Right », « Pair/Group: Front tackle », « Double tackle » et autres; la page indique des FBX/GLB, 24/30/60 fps et preview gratuite.
- [Mouvements de contact](https://playermotion.games/answers/rugby-tackle-and-ruck-animations) : indique que les deux acteurs sont fournis comme une paire à démarrer même frame/point de placement. Ceci **ne prouve pas** les décalages racines, événements de contact ou la qualité sur nos meshes.
- [Conditions](https://playermotion.games/terms) et [pack](https://playermotion.games/packages/rugby) : usage commercial autorisé **après déverrouillage/paiement**, conditions sur redistribution des animations isolées ou extractibles ; licence Standard limitée selon revenu/financement et licence Studio possible au-delà. Non libre, non acquis, aucun téléchargement ni intégration. Prix affichés variables : consulter le vendeur le jour d'un achat éventuel.

## Décision R&D : produire un clip original plutôt que détourner une source

Comme aucune paire de **plaquage rugby** réunissant droits, root offsets, vrais contacts synchronisés et qualité vérifiable n'a été identifiée, prochaine voie gratuite : fabriquer sous Blender (déjà disponible dans le labo Chat/Actions) **une interaction originale à deux rig copies**. Ce n'est pas une animation validée par le simple fait d'être synthétisée.

Contrat de données exigé avant retarget :
1. Deux acteurs A (plaqueur), B (porteur), même fps, durée, temps `t=0` et repère global. Conserver les transforms racines animées et le décalage relatif 3D **mesuré** par frame, sans repositionnement après génération.
2. Chronologie déclarée : approche, premier contact épaule/torse, prise des deux bras autour du porteur, déséquilibre, chute contrôlée, relâchement, récupération ; événements horodatés et inspectables. Pas de création de contact par liaison physique avant qualité cinématique.
3. Plan du sol calibré, unité mètre, proportions canoniques 53 os. Au minimum six régions d'appui skinnées par acteur : poitrine, bassin, genou G/D, pied G/D. Coordonnées os et surfaces évaluées doivent être comparées.
4. Sur copies LOD0/1/2, vrais rendus Blender face/profil à approche/prise/chute/récupération. Quatre mains distantes <= 0,05 m de la **surface vraie** seulement pendant la phase de prise déclarée, sans exigence absurde pendant l'approche. Contrôle de contact épaule/torse et séparation après relâchement.
5. Mesurer les intersections **triangle-triangle exactes** sur maillages skinnés avec exclusion adéquate des triangles coplanaires et une tolérance numérique documentée ; les chevauchements de BVH ne sont **pas** des intersections. Rapport d'interpénétration par région et instant, normalisé par LOD.
6. Vérifier appuis sol, glissement des pieds et pénétration terrain sur la chronologie. Les seuils d'appui doivent être définis sur un sol calibré et sur les vraies semelles, pas l'origine non étalonnée de Blender.
7. **Gate visuel initial** : aucune torsion impossible du torse, traversement de corps, bras désarticulés, flottement ou prise dans le vide sur captures inspectées. Un seul défaut majeur = refus, même si les scripts passent.
8. **Seulement ensuite** lancer témoins appariés « animation seule » et « animation + Kickback », même échantillonnage/LOD/sol, comparer hauteurs, surfaces et appuis. SHA256 pour ZIP, sources, manifests, images et rapports ; HEAD exact des runs Actions.

## Statut d'exécution à la rédaction

Recherche et vérification de licences/catalogues effectuées ; **aucun clip de tackle original généré ni fichier d'animation retargeté lors de ce jalon**. Aucun nouveau rendu Blender, contact peau, intersection exacte, six appuis ni comparaison avec Kickback n'est revendiqué. Cette étape évite de gaspiller un run 3D sur une fausse source. Les futurs rendus/CI doivent être réceptionnés au SHA qui les a produits.

Références : sources liées ci-dessus ; passation #73 commentaire 6680342892.

# MATCH 3D V25 — J1/J2 : audit de licences et squelette des vrais GLB

Date : 2026-11-05. Statut : **réception partielle en lecture seule, NON QUALIFIÉ VISUELLEMENT**.

## États GitHub vérifiés

- `main`: `cc24f8ab3a28705eb79a6ae9efb265f279bb5fad`.
- Lot 24 : PR #300, **DRAFT / NON FUSIONNÉE**, HEAD vérifié `f2a4fcd0cba9f23f4c372e847658b2cb8750394e`.
- R&D V25 : branche `research/match3d-v25-open-source-tools-20261105` depuis main ; J0 `4ca754f4dad3c3f588ef766e6f94a76ebfd0090c`.
- Coordination #73 : réservation J1/J2 commentaire `6664062007`.
- Aucune écriture `dist/`, `tests/`, moteurs, PROD V62–V72, DATA/LNR, sauvegardes ou gate.

## Sources externes, identifiants figés à la consultation (ne pas confondre branche mouvante et version installée)

| Projet | Commit main observé | Release la plus récente accessible | Licence principale et réserves |
| --- | --- | --- | --- |
| [Ara 3D Gen](https://github.com/olatunde85/3d-gen) | `fbf8a590a3c085bdb18a5ecd27554e5d0156bd4f` | `v0.2.0` (2026-10-25) | MIT déclaré dans README ; MakeHuman CC0. Données de mocap CMU : autorisées commercialement mais interdiction de revente indépendante des enregistrements. Contrôler chaque bundle. |
| [Mesh2Motion](https://github.com/Mesh2Motion/mesh2motion-app) | `4f1316296660f2b9827ff46b4db10fb241ec2147` | Aucune release latest accessible (404) | MIT code, CC0 3D/animations selon README et LICENSE-CC0.MD ; ne pas supposer qualité du retarget. |
| [Rigger](https://github.com/asu37/Rigger) | `c8f1d1b9a8729582c61fa0ffa9a658ec4f4f6e77` | Aucune release latest accessible (404) | GPL v3 ou ultérieure selon README et LICENSE ; documente `dist/rigger-1.2.0.zip` construit avec `python build.py`, **pas une release vérifiée** ; nécessite Blender >=4.2. |
| [AssetFurnace](https://github.com/Bingeljell/image-to-3dlab) | `b91b03fa2115cd3035c8514d610faeefe95de7d5` | `v0.5.7` (2026-11-03) | Apache-2.0 code uniquement. Modèles et poids séparément licenciés ; Hunyuan exclu UE, Pixal3D/TRELLIS.2 soumis au cas DINOv3. **Aucun backend IA autorisé sans audit des poids.** |
| [Ekza Studio](https://github.com/ekza-space/ekza-studio) | `b7e3e92f25d2656caace50c0869aeef0d562dbf3` | Aucune release latest accessible (404) | MIT avec composants AnimX Apache-2.0 et fixtures CC0/VRM Public License ; pas de transfert automatique de licence aux assets importés. |
| [Blender](https://github.com/blender/blender) | `dbdad68c65c88e6f1dab23cf6051be1698fa8015` | Aucune release GitHub latest accessible | GNU GPL pour l'application, les GLB créés ne sont pas automatiquement GPL. Version locale non installée. |

**Précision** : les empreintes ci-dessus sont des commits observés via API GitHub, pas des versions installées ni des essais d'exécution. Les sorties des générateurs doivent être auditées indépendamment des licences du code.

## J2 — acquisition de lecture des vrais GLB

Les fichiers de PR #300 ont été consultés **au HEAD exact** via l'interface GitHub en mode base64, sans écriture dans le dépôt. Le téléchargement local sur cette machine a échoué au DNS (`raw.githubusercontent.com`) ; les binaires ne sont pas disponibles comme fichiers locaux. Un décodage mémoire de la partie JSON du conteneur GLB 2.0 a néanmoins permis **12 inspections directes** :

- Sources : `clothing_tshirt.glb`, `clothing_shorts.glb`, `clothing_shoes.glb` (3).
- LOD0, LOD1, LOD2 : `clothing_tshirt`, `clothing_shorts`, `clothing_shoes` (9).
- **12/12** : un skin, 53 joints ; les 9 dérivés LOD présentent le même ordre de noms de joints et la même hiérarchie parentale. Les sources ont le même ordre de noms (hiérarchie source non comparée dans cet essai).
- Aucun script n'a altéré les fichiers ; les identifiants Git blob renvoyés par GitHub sont listés ci-dessous comme références d'objet, **et non des SHA-256 du contenu**.
- Les **3 corps** `base_body_anim-lod{0,1,2}.glb` : récupération base64 a renvoyé une chaîne vide pour ces objets volumineux ; **impossibilité de revalider directement le JSON**, même si le rapport `lod/report.json` annonce 53 joints et 12 animations par corps.

| GLB dérivé | Git blob LOD0 | Git blob LOD1 | Git blob LOD2 |
| --- | --- | --- | --- |
| T-shirt | `4355dc83452aae90042ea2634eb1883fe18d8762` | `c91f7d4641d558ebcf7559e5b509140c7af33b70` | `7adb627cd7d65ed6e563de4eee00df4b49f9d4b0` |
| Short | `03631548ea0beed74be0fce0a388b6a5305ff236` | `0b2b9772f37bb09058aa60086cfdea5e9313e47c` | `bedc7a4eb906d79cb6aa32a3dd6c9cb59ab0b4dc` |
| Chaussures | `673eebf0d90dec31693f6d8a659de0e9e80daae6` | `7cbb47b08af22a89e2bd9d9c3b93febd13b8d12d` | `094eeb01bd4dcceb43e83dd9520de9c60325e0b1` |

**Ordre canonique inspecté** : Root, pelvis, spine_01, spine_02, spine_03, clavicle_l, upperarm_l, lowerarm_l, hand_l, doigts gauche, clavicle_r, upperarm_r, lowerarm_r, hand_r, doigts droite, neck_01, head, thigh_l, calf_l, foot_l, ball_l, thigh_r, calf_r, foot_r, ball_r. L'égalité des noms/parents ne garantit **pas** l'égalité des matrices de bind, poids, positions de repos ou déformations.

## Baseline de rapports (non remesurée par l'audit binaire)

Les données du HEAD #300 dans `dist/match3d/assets/rugby-v24/lod/report.json` indiquent :

| Niveau | Triangles par joueur | T-shirt corrigé | Plafond |
| --- | ---: | ---: | ---: |
| LOD0 | 27 906 | 1 195 | 30 000 |
| LOD1 | 8 643 | 429 | 10 000 |
| LOD2 | 2 557 | 542 | 3 000 |

Le manifeste source donne corps 8 212 156 octets, 36 924 triangles, 53 articulations. Ces chiffres sont **déclarations des rapports publiés** vérifiés à ce SHA, pas calculs indépendants sur tous les binaires.

## Script reproductible autonome

`tools/match3d-v25-lab/audit-glb.cjs` : analyse hors ligne sans dépendance, lecture seule, GLB 2.0, SHA-256 réel, hiérarchie joints (noms/parents), nombre de vertices/triangles, clips, ressources externes. Comparaison stricte nom+parent avec `--reference`. Exemple (après acquisition réelle des GLB localement) :

```sh
node tools/match3d-v25-lab/audit-glb.cjs --reference /tmp/v24/base_body_anim-lod0.glb /tmp/v24/clothing_tshirt-lod0.glb /tmp/v24/clothing_shorts-lod0.glb /tmp/v24/clothing_shoes-lod0.glb
```

Les tests locaux de syntaxes et un GLB synthétique **ont été réalisés sur un prototype équivalent** du script ; ne pas présenter ces tests comme validation des vrais GLB, ni comme preuve CI du fichier final publié. Ce script reste un auditeur **structurel** : il ne valide ni la normalisation des poids, ni les inverse-bind matrices, ni la topologie manifold, ni les collisions / poses dynamiques, ni les captures Chromium.

## Suites et limites

- J1 vérifié : versions/commits upstream, licences déclarées et restrictions d'assets. Aucun outil installé.
- J2 vérifié directement : **12 vêtements GLB** : 53 joints et noms compatibles ; **9/9 hiérarchies LOD identiques**. Les corps et surfaces animées restent non vérifiés directement.
- Tests non effectués : import/export Ara, Mesh2Motion ou Rigger, comparaison des inverse-bind matrices, optimisation/skin weights, animations rugby, Chromium, 30 joueurs en match réel, FPS et sauvegardes.
- Pour poursuivre : acquisition locale contrôlée des 4 sources + 12 LOD au SHA exact, script sur tous les objets, trois exports tests candidats, Chromium 3 LOD avant/après, runtime 30 joueurs et benchmark apparié. Toute modification des assets du lot 24 exige une PR et une réservation séparées, jamais sur la branche R&D.
- **Verdict : étude technique et outils reproductibles partiellement établis, RENDU NON QUALIFIÉ, aucune fusion ni gate.**

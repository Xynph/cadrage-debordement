# Lot 24 — réception Work du 5 novembre 2026

## Verdict

**NON QUALIFIÉ pour intégration au match. PR #300 reste DRAFT. Aucun gate ni fusion.**

La correction est effective sur les trois vrais GLB dérivés du T-shirt ; elle ne remplace pas le vêtement par une primitive, ne change pas son matériau et n'élargit pas le masque de peau. Le corps et les sources CC0 restent intacts. Le contact à deux rigs reste une expérience statique insuffisante ; ni plaquage complet, ni chute/récupération, ni prise du ballon ne sont qualifiés.

## Maillage et poids

Après le premier ajustement publié dans 599db575, les grandes faces du vêtement sont subdivisées par insertion d'un centre, avec UV interpolés et frontières de chaque face conservées. Les points sont ajustés à 12 mm au moins des triangles corporels correspondants en pose de bind ; les poids sont transférés par interpolation barycentrique puis limités aux quatre influences principales et renormalisés. Les normales sont recalculées et écrites dans le GLB. Le vêtement est un dérivé athlétique fixé : ses morph targets sont retirés après bake, pour éviter une seconde application.

| LOD | Triangles T-shirt avant → après | Sommets après | Sommets déplacés | Déplacement max | Joint dominant changé |
| --- | --- | --- | --- | --- | --- |
| 0 | 993 → 1 195 | 720 | 236 | 16,30 mm | 78 |
| 1 | 305 → 429 | 284 | 93 | 15,65 mm | 44 |
| 2 | 534 → 542 | 382 | 128 | 18,58 mm | 57 |

Totaux par joueur, avant masquage corporel : 27 906 / 8 643 / 2 557 triangles, sous les plafonds 30 000 / 10 000 / 3 000. Les 53 joints, UV et poids normalisés sont vérifiés sur les vrais binaires. Empreintes exactes dans `../../lod/shirt-fit-report.json`.

Le workflow de génération avait rétabli les anciens T-shirts dans son commit automatique 71d883af après le premier jalon. Le générateur `tools/match3d-v24-lod-build.cjs` applique désormais l'ajustement après simplification, recalcule son rapport et revérifie les plafonds. Reconstruction locale complète avec glTF-Transform 4.5.1 réussie : les trois empreintes corrigées sont identiques à l'essai avant reconstruction. Le masque AABB n'a pas été modifié.

## Gestes et captures

Les rotations de bras sont calculées par une chaîne épaule/coude à deux segments visant les poignets en coordonnées monde, puis converties en quaternions locaux. Les longueurs des os sont conservées. Les poses de plaquage visent un côté du porteur ; une piste de translation du bassin maintient le pied d'appui à sa hauteur source aux poses clés. Cela ne constitue pas une simulation de contact.

- `before/` : les 15 captures Chromium du HEAD exact 2b14a92f, reproduites localement avant changement.
- `lod*-*.jpg` : 15 captures finales sur les trois LOD ; repos et passe/plaquage face/profil.
- `lod*-contact-*.jpg` : six captures de contact statique entre deux vrais rigs indépendants.
- `stage-tv.jpg`, `stage-zoom.jpg` : 30 rigs avec trois LOD dynamiques ; 30 racines d'os et 30 mixers indépendants, 16 clips par LOD.

Ces 23 captures finales ont été inspectées, en plus du comparatif initial et des vues de benchmark. Les grandes traversées du torse ont disparu ; col et torse restent continus dans les vues reçues. Les mains de la passe vont devant le buste ; les assertions Chromium exigent >20 cm devant le centre des épaules sur la pose finale et une séparation <50 cm. Les bras/membres sont conservés. Les emmanchures sont encore anguleuses, avec peau visible au bord pendant la flexion ; la continuité sur tout le mouvement reste à qualifier. Les mains ouvertes se chevauchent à certains instants. Le plaquage à deux joueurs ne montre pas encore un enroulement crédible et complet. Des traversées du short et les chaussures LOD2 restent visibles, hors correction T-shirt de ce jalon.

Les captures sont des contrôles de poses, pas une validation de séquence animée continue. Aucun raccordement au runtime du jeu.

## Benchmark apparié

`paired-benchmark.html` compare le vrai modèle v23, dont le module est identique à celui du commit 672b2abc, aux 30 rigs V24, dans la même scène : mêmes positions, caméra, éclairage, 960×540, pas d'antialiasing, même pas d'animation 1/60 et `gl.finish`. Le culling est désactivé dans les deux versions pour soumettre les 30 rigs. Trois paires par vue, ordre AB/BA/AB, 12 frames de chauffe puis 24 mesurées, pages neuves ; résultats bruts dans `paired-benchmark.json`. Un essai exploratoire avec culling différent a été écarté.

| Vue | Médiane v23 | Médiane v24 | Triangles soumis v23 / v24 |
| --- | --- | --- | --- |
| TV | 360,36 FPS | 179,37 FPS | 55 622 / 74 252 |
| Zoom | 373,83 FPS | 222,22 FPS | 55 622 / 349 422 |

**V24 est plus coûteuse. Aucun gain ni qualification de performance revendiqués.** Forte variance, trois paires seulement, rendu logiciel SwiftShader et scène sans match/foule. Ces FPS ne sont pas ceux du jeu réel et ne mesurent pas la VRAM. Le benchmark de runtime reste absent. Une régression d'environ moitié en TV sur ces médianes interdit de présenter ce jalon comme une optimisation.

## Tests et reprise

Rapports Chromium : `lod-browser.json`, `contact-browser.json`, `stage-browser.json` ; aucune erreur JavaScript ni requête externe dans ces trois réceptions et dans le benchmark. `node-tests.json` consigne les 245 suites complètes locales : 245 PASS, zéro échec, 282,504 secondes avec cinq processus, plafond de 180 secondes par suite. Les régressions nouvelles couvrent le transfert des poids, la subdivision/UV, les vrais GLB et l'IK de bras. Les CI du nouveau HEAD sont à vérifier, sans extrapoler depuis 2b14a92f (ancien HEAD 8/8, JS 7/7).

La suite peut être réceptionnée en Chat depuis les binaires et captures publiés : vérifier le dernier HEAD (y compris tout commit du générateur), les empreintes, les CI et les défauts résiduels. Work est encore utile pour de nouvelles retouches binaires et la qualification animée/contact. La mission globale n'est pas terminée : pas de runtime, pas de qualification de contact, pas de gate/fusion. PRODUCTEUR V62–V68, DATA/LNR, moteur sportif, sauvegardes et auto-release sont intacts.

# Laboratoire R&D MATCH 3D — outils 100 % gratuits / open source (V25 exploratoire)

Date : 5 novembre 2026. Statut : **audit statique et protocole de test, aucune qualification runtime ni adoption**.

## Isolation et gouvernance

- Base de branche : `main` vérifié `cc24f8ab3a28705eb79a6ae9efb265f279bb5fad`.
- Branche : `research/match3d-v25-open-source-tools-20261105`.
- Réservation #73 : commentaire `6663883971`.
- Ce document est le **seul fichier** modifié ; ni PR #300, ni GLB, ni code jeu, ni 30 rigs, ni V62–V72, DATA/LNR, moteur, sauvegardes ou auto-release touchés.
- Tout accès aux GLB du lot 24, leur adaptation et les benchmarks se feront dans un espace de travail distinct, **avec autorisation/réservation préalable**, sans pousser de binaire sur la branche du lot 24. Aucune fusion/gate de cette R&D.

## Candidats et provenance (déclarations des projets, pas résultats mesurés)

| Outil | Source | Droit logiciel annoncé | Droits des sorties / contraintes | Pertinence et limite |
|---|---|---|---|---|
| Ara 3D Gen | https://github.com/olatunde85/3d-gen | MIT | MakeHuman CC0 ; clips CMU motion capture avec restrictions de revente autonome ; vérifier manifeste exact et chaque ressource | Personnage alternatif, 77 clips annoncés, export GLB, trois niveaux de détail ; squelette Mixamo, **non identique par défaut aux 53 joints du lot 24** |
| Mesh2Motion | https://github.com/Mesh2Motion/mesh2motion-app | MIT | Animations et assets CC0 déclarés ; inspecter chaque source/bundle | Retargeting/auto-rig de référence ; peut changer hiérarchie et poids, ne corrige pas mécaniquement un contact |
| Rigger | https://github.com/asu37/Rigger | GPL-3.0-or-later | Add-on Blender ; exports et licence des assets sources à tracer séparément | Tests sur copie de rig pour IK, bind et retarget ; ne doit jamais modifier le squelette canonique distribué sans preuve |
| Blender + Rigify / poids | https://www.blender.org/ | GPL pour logiciel | Œuvres créées libres selon données d'entrée ; ne pas embarquer du code GPL dans le moteur propriétaire | Atelier de référence pour peau/maillots, collision visuelle, pose et correction humaine |
| AssetFurnace | https://github.com/Bingeljell/image-to-3dlab | Apache-2.0 pour application | Moteurs/poids séparés : Hunyuan 3D hors territoire UE selon licence ; TRELLIS.2 classé « commercial-conditional » par le projet à cause de DINOv3 ; sélectionner exclusivement chemin compatible après audit | Création expérimentale PBR, source potentielle de vêtements et accessoires, mais **non adoptable par défaut pour un asset commercial** |
| Ekza Studio | https://github.com/ekza-space/ekza-studio | MIT avec sous-modules Apache-2.0 | Fixtures sous licences séparées (CC0 ou VRM Public License) ; audit nécessaire | Éditeur navigateur compatible univers three.js ; tester import/export et conservation des clips, pas supposer la compatibilité exacte GLB |
| MakeHuman/MPFB (référence) | https://www.makehumancommunity.org/about/license.html | MakeHuman AGPL, MPFB GPL | Assets principaux CC0 | Source anatomique alternative déterministe et gratuite |
| FreeMoCap (complément) | https://github.com/freemocap/freemocap | AGPL-3.0 annoncé | Droits des vidéos d'origine à confirmer | Mocap sans abonnement ; faible fiabilité des contacts à deux corps occultés |

**Politique stricte :** pas d'API payante, pas d'essai nécessitant carte bancaire, pas de services cloud, pas de licence géographiquement interdite, pas de poids à droits commerciaux incertains. Installation et GPU locaux possibles ; électricité/temps machine non gratuits en pratique.

## Cas de test comparables aux vrais GLB du lot 24

1. **Référence immuable :** mesurer SHA256 du corps, T-shirt, short, chaussures, 3 LOD et clips ; conserver les 53 joints, les noms, parents, inverse-bind matrices et indices de skin.
2. **Audit des maillages :** nombre triangles/sommets par LOD ; nombre et distribution des joints par sommet ; topologie (manifold, triangles dégénérés), UV, normales, texture, taille GLB.
3. **Référence gestuelle :** passe devant buste, réception de ballon, plaquage à deux corps, impact, chute avec sol, récupération. Toujours mêmes échantillons temporels, mêmes caméras frontale et profil, mêmes morphs.
4. **Géométrie robuste :** distance au maillage *déformé* (surfaces triangles, pas seulement plus proche sommet) des mains/bras et vêtements ; quantifier pénétrations et écarts et inspecter visuellement les contacts. Suivre séparément LOD0, LOD1, LOD2 et main droite LOD2.
5. **Conservation canonique :** import/export de chaque candidat vers une **copie de travail**. Comparer noms/ordre/parents des 53 joints, coordonnées de rest pose, poids, et clips ; si incompatibilité, retargeter vers squelette canonique sans modifier l'original.
6. **30 joueurs offline :** 30 rigs/mixers indépendants, 3 LOD, sans requêtes externes ; scénario dynamique rigoureux dans Chromium et **runtime réel** avec fallback. Captures avant/après à temps déterministes.
7. **Benchmark apparié :** même version moteur et build, scène et comportement, résolution, navigateur, GPU, cache et warm-up ; au moins 3 répétitions, médiane FPS / p95 frametime / mémoire / draw calls / triangles / textures et calcul de delta ; déclarer distinctement rendu isolé et match réel.
8. **Critère d'acceptation :** amélioration anatomique perceptible et mesurée (absence de pénétration persistante, enroulement de bras, contact sol et reprise crédibles), aucune régression significative de performance ni des sauvegardes, licence attestée. Sans ces preuves : NON QUALIFIÉ.

## Plan en jalons courts

- **J0 — ce document** : sources, risques, critères et procédure seulement ; pas de comparaison empirique.
- **J1 — audit d'exports externes** : télécharger localement des versions épinglées, sauvegarder licences, checksums, lister assets et dépendances ; exclure moteurs risqués.
- **J2 — reproductibilité du baseline** : extraire copies GLB du HEAD PR #300 *sans aucune écriture dans ce chantier* et établir preuves triangulaires/skin/rig.
- **J3 — candidats isolés** : Ara puis Mesh2Motion, Rigger, Ekza ; mesurer import/export rig et clips ; AssetFurnace exclusivement si backend et poids compatibles UE/commercial.
- **J4 — réception anatomique** : comparer contacts véritables avant/après via Chromium, captures temps déterministes et diagnostics de surface.
- **J5 — banc 30 joueurs offline + runtime** : comparer paires v24/candidat et vérifier fallback.
- **J6 — décision** : poursuivre ou rejeter chaque candidat selon preuves ; toute future modification jeu dans une autre PR et réservation séparée.

## Vérification de la présente intervention

- Lecture de `main`, `AGENTS.md`, `DEVELOPPEMENT.md`, `docs/developpement-parallele.md`, PR #300, issue #73 et réservations récentes.
- Audit **descriptions et licences documentées** : effectué via dépôts officiels ; **pas** de lancement d'outil 3D, pas de GLB importé/exporté, pas de render Chromium, pas de benchmark, pas de CI déclarée verte.
- Cette branche documentaire ne doit **pas** être présentée comme qualification visuelle ni compatibilité établie.

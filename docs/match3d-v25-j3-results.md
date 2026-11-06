# MATCH 3D V25 — J3 : acquisition, essais et blocages vérifiés

Date : 2026-11-05. Branche R&D `research/match3d-v25-open-source-tools-20261105`. **NON QUALIFIÉ, aucun résultat de skinning ou de rendu revendiqué.**

## GitHub au démarrage

- `main` = `b585105767a11d2712a8f3c7e5fd8874387c23eb` (après fusion officielle V72 #313 ; passation #73).
- PR #300 DRAFT, non fusionnée, **HEAD exact `c46eaf60010bea30b4a3d7b82372b6ee565068d6`**.
- Branche R&D avant J3 : `fad2f9318f7f4304269bebd4bae074ea45dfe108`.
- `AGENTS.md` et commentaires de réservation #73 lus. Réservation J3 : commentaire `6664227096`. Fichier nouveau unique `docs/match3d-v25-j3-results.md`.

## Acquisition binaire et auditeur

**Accès direct aux vrais fichiers au HEAD PR #300 :**
- Tentative HTTP `raw.githubusercontent.com` depuis le conteneur Python `requests` : **ConnectionError DNS** (aucun fichier GLB local récupéré).
- GitHub `fetch_blob` sur le corps LOD2 : **UnicodeDecodeError** de la réponse binaire.
- `fetch_file(..., encoding=base64)` sur corps LOD2 (tentative précédente) : chaîne vide. Les trois corps complets restent impossibles à analyser localement dans cette session.

**Inspection directe réussie via mémoire du connecteur GitHub, au nouveau HEAD `c46eaf6` :** les neuf GLB dérivés de vêtements (T-shirts, shorts, chaussures en LOD0, LOD1, LOD2) renvoient un contenu base64, décodé en mémoire pour lire les entêtes et JSON glTF 2.0.

| Critère JSON des 9 GLB dérivés | Résultat réel |
| --- | --- |
| Header 2.0 et taille déclarée | 9 fichiers lus, tailles déclarées conformes aux métriques déjà publiées |
| Skins | 9/9 : 1 |
| Joints par skin | 9/9 : 53 |
| Ordre/noms des joints | 9/9 identiques |
| Relations parent/enfant par noms | 9/9 identiques |
| Translation, rotation, scale ou matrix des nœuds joints dans JSON | 9/9 identiques |
| Inverse-bind matrices | Accessor `0` annoncé sur chacun, **contenu binaire non comparé** |
| Attributs skinning de la primitive | `JOINTS_0` et `WEIGHTS_0` présents 9/9, **valeurs binaires non vérifiées** |

Git blobs identiques à ceux inventoriés dans `docs/match3d-v25-j1-j2-audit.md` (pas de changement de ces neuf objets entre les HEAD examinés). Ces contrôles ne constituent ni preuve de poids normalisés ni vérification de contact ou de déformation.

**Auditeur publié** : `tools/match3d-v25-lab/audit-glb.cjs` consulté sur GitHub, sans modification J3. Environnement local : Node `v22.16.0`, `/usr/bin/chromium` disponible, Blender et Playwright absents. Une copie de travail **préexistante et différente** de l'auditeur est présente dans `/mnt/data/cd-rd/tools/match3d-v25-lab/audit-glb.cjs` (4 720 octets, contre 3 477 pour le fichier publié) : **ce n'est pas la preuve d'exécution du fichier GitHub exact**.

Tests réellement exécutés avec cette copie locale sur un **GLB synthétique à 2 joints** seulement :
- `node --check` : 0 (syntaxe OK).
- analyse GLB synthétique 228 octets : exit 0 ; 2 joints ; mêmes noms/parents sur comparaison fichier contre lui-même ; SHA-256 `df8f59855170fef1240a5830b13026ed239749c2a58accfb8b282882d9e640b4`.
- en-tête `glTF` volontairement corrompu : exit 1 ; `Invalid GLB magic`.
- **Auditeur publié exact sur vrais GLB : NON EXÉCUTÉ** faute d'acquisition binaire locale.

## Essais externes

- **Mesh2Motion** `Mesh2Motion/mesh2motion-app` : README et `package.json` relus. Import/export GLB, installation locale `npm install`, `npm run dev` ; README suggère Node 24, environnement disponible Node 22. Sans code source et dépendances téléchargés, **aucun test d'import/export**. Une différence potentielle de version Node n'est pas un échec reproduit.
- **Ara 3D Gen** `olatunde85/3d-gen` : README et `package.json` relus, `engines.node >=20` ; notre Node 22 satisfait cette contrainte annoncée. CLI `npm run export` et tests `npm run test` documentés. README actuel annonce **88 animations** (J1 signalait 77 d'après une version plus ancienne) : valeur dynamique, pas comptage indépendant. Pas de dépôt/dépendances installés, donc **aucun export comparé**.
- **Rigger** `asu37/Rigger` : README relu ; requiert Blender 4.2+ (testé par l'auteur sur Blender 5.2). Blender absent (`which blender` vide), aucun essai de rigging, weight painting, IK ou retarget.
- **Chromium** disponible mais pas de vraie scène locale de match GLB à charger ; aucune capture utile revendiquée.

## Conditions précises de J3 effectif

1. Télécharger les GLB sources et les 12 LOD **à SHA exact** via un environnement ayant accès HTTPS GitHub et un espace binaire monté. Vérifier taille, SHA-256 et autorisations de réutilisation ; ne rien pousser dans PR #300.
2. Exécuter **le fichier GitHub exact** `node tools/match3d-v25-lab/audit-glb.cjs --reference ...`, conserver son JSON et comparaison des 53 noms/parents. Ajouter ensuite un contrôle distinct sur inverse-bind matrices et poids.
3. Installer localement Mesh2Motion (Node 24 si exigé par build), Ara (Node 22 suffisant d'après package) et Blender 4.2+ / Rigger depuis commits épinglés, sans cloud ni abonnement. Import/export sur **copies** et SHA-256 avant/après, sans changer le lot 24.
4. Mesurer animations rugby et peau au niveau des vraies surfaces skinnées ; ensuite seulement lancer Chromium, captures face/profil, 3 LOD et runtime 30 joueurs.

## Verdict et gouvernance

**J3 partiel : acquisition métadonnées JSON réelles 9/9 au nouveau HEAD et tests synthétiques locaux reproductibles ; installation/import/export Mesh2Motion, Ara, Rigger et contrôle des 3 corps NON EFFECTUÉS. Aucun benchmark, aucune capture, aucune métrique inventée.**

Aucun changement `dist/**`, PR #300, GLB, PRODUCTEUR V72, DATA/LNR, moteur, sauvegardes, fallback, auto-release, gate ni `main`. Aucun gate/fusion. Fichier de résultat uniquement sur la branche R&D.

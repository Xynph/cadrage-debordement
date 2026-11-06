# MATCH 3D V25 — J4 : audit binaire des 9 GLB et blocages de test

**Date** : 2026-11-05. **Verdict** : audit structurel binaire partiellement réussi ; **aucune comparaison visuelle avant/après des outils externes, aucun outil qualifié, aucun benchmark**.

## Références et protection

- `main` relevé au démarrage : `b585105767a11d2712a8f3c7e5fd8874387c23eb` (V72 #313 fusionnée séparément).
- PR #300 **DRAFT/non fusionnée**, HEAD exact fixé pour ce relevé : `2d8c8c7eee5aa0dad899aa6bb119e95bda0e7987`.
- Branche R&D : `research/match3d-v25-open-source-tools-20261105`, HEAD initial `273b8c9901996f6cbe8db3c2e6f458f45b4d0f88`.
- Réservation J4 #73 : commentaire `6664872655`, exclusivement ce nouveau rapport.
- Aucune modification sur PR #300, ses GLB, le moteur, PRODUCTEUR, DATA/LNR, sauvegardes, fallback, workflows, auto-release ou `main`.

## Méthode indépendante des rapports de génération

Une lecture GitHub de `fetch_file` avec `encoding=base64` sur chacun des neuf GLB de vêtements au HEAD #300 a fourni le **vrai contenu binaire complet**, décodé en mémoire dans l'environnement de l'action GitHub (pas dans le conteneur). Le parseur ad hoc JavaScript a lu :
- l'en-tête GLB et la taille déclarée ;
- le JSON glTF 2.0, `skins[0].joints`, la hiérarchie et les transformations des nœuds ;
- les accesseurs binaires réellement stockés de `JOINTS_0`, `WEIGHTS_0`, `inverseBindMatrices`, `indices`.
- Les sommes des poids doivent être dans ±0,001 de 1, toutes les valeurs finies et dans [0,1], et chaque indice doit être inférieur à 53. Les IBMs ont été comparées **numériquement** entre les neuf GLB.

**ATTENTION** : ce n'est pas l'exécution du script Node publié `audit-glb.cjs`. Le parseur direct et son relevé sont distincts, sans qualification des animations ni des skins déformés. La validation des valeurs d'IBM communes ne vérifie pas leur justesse anatomique ou leurs correspondances exactes aux os du corps, qui n'a pas été acquis.

| Fichier réel LOD | Taille octets | Sommets (primitive) | Triangles | Joints | Sommes de poids invalides | Poids invalides | Indices hors bornes |
|---|---:|---:|---:|---:|---:|---:|---:|
| tshirt 0 | 304044 | 720 | 1195 | 53 | 0 | 0 | 0 |
| tshirt 1 | 159708 | 284 | 429 | 53 | 0 | 0 | 0 |
| tshirt 2 | 210940 | 382 | 542 | 53 | 0 | 0 | 0 |
| shorts 0 | 185136 | 337 | 560 | 53 | 0 | 0 | 0 |
| shorts 1 | 122008 | 120 | 172 | 53 | 0 | 0 | 0 |
| shorts 2 | 132364 | 156 | 214 | 53 | 0 | 0 | 0 |
| shoes 0 | 647752 | 1257 | 2158 | 53 | 0 | 0 | 0 |
| shoes 1 | 425180 | 436 | 664 | 53 | 0 | 0 | 0 |
| shoes 2 | 380024 | 270 | 332 | 53 | 0 | 0 | 0 |

**Total : 3962 sommets examinés, zéro anomalie selon les critères ci-dessus, 9/9 jeux de 53 inverse-bind matrices numériquement identiques, 9/9 transformations de repos JSON identiques, 9/9 noms/parents identiques.** Les sommes min/max relevées : écart absolu inférieur à 0,00000012 de 1. Ces résultats valident la cohérence des attributs de skinning, **pas** la géométrie des interactions sportives, les collisions, les poids anatomiquement idéaux ni la pose des corps.

Empreintes Git blob de contrôle : T-shirt LOD 0/1/2 `4355dc83452aae90042ea2634eb1883fe18d8762`, `c91f7d4641d558ebcf7559e5b509140c7af33b70`, `7adb627cd7d65ed6e563de4eee00df4b49f9d4b0`; short `03631548ea0beed74be0fce0a388b6a5305ff236`, `0b2b9772f37bb09058aa60086cfdea5e9313e47c`, `bedc7a4eb906d79cb6aa32a3dd6c9cb59ab0b4dc`; chaussures `673eebf0d90dec31693f6d8a659de0e9e80daae6`, `7cbb47b08af22a89e2bd9d9c3b93febd13b8d12d`, `094eeb01bd4dcceb43e83dd9520de9c60325e0b1`. **Ces valeurs sont SHA-1 des blobs Git, non SHA-256.**

## Tentatives réelles d'acquisition locale / exécution des outils

Conteneur Chat : Node `v22.16.0`, npm `10.9.2`, Chromium présent, Blender absent.

- Requête Python `requests.get('https://raw.githubusercontent.com/...')` : `ConnectionError`, DNS temporairement indisponible.
- `git ls-remote https://github.com/Mesh2Motion/mesh2motion-app.git HEAD` : `Could not resolve host: github.com`. Pas de clone Mesh2Motion, Ara ou Rigger, ni installation de leurs dépendances.
- `find /mnt/data -name '*.glb'` ne trouve que `synthetic.glb` 228 octets et `bad-header.glb` (copies synthétiques locales J3), aucun GLB du lot 24.
- Le script **local préexistant** `/mnt/data/cd-rd/tools/match3d-v25-lab/audit-glb.cjs` (non identique au fichier GitHub) passe `node --check` et le test synthétique à 2 joints ; il n'a **pas été exécuté sur les vrais GLB**, les fichiers n'étant pas transférables dans le conteneur. Ce résultat ne démontre pas que le script GitHub exact passe.
- **Mesh2Motion : non exécuté** : clone/dépendances et GLB local indisponibles. README indique Node 24 utilisé par son auteur, Node 22 non garanti.
- **Ara 3D Gen : non exécuté** : clone/dépendances et GLB local indisponibles. Le README parle de 88 animations, chiffre déclaré, non benchmark.
- **Blender/Rigger : non exécutés** : Blender indisponible.
- **Chromium : non exécuté sur un modèle réel** ; aucune comparaison animée, capture avant/après ni contrôle de 30 joueurs.

## Décision et parcours minimal suivant

Aucune nouvelle animation ou retouche de maillage n'a été produite : il serait trompeur de fournir des captures « après » identiques à « avant » ou de prétendre à une amélioration.

**Blocage ponctuel qui motive Work ou une machine externe avec accès réseau et Blender** : obtenir les vrais GLB dans un environnement exécutable, cloner/télécharger les trois sources open source, installer Blender >= 4.2 et dépendances, lancer audit exact et tests import/export sur copies. Tant que Chat ne peut pas télécharger les binaires, aucune comparaison réelle d'animations/skin n'est techniquement réalisable ici.

Dans l'environnement adéquat : (1) checkout PR #300 au SHA explicite sans aucun push, (2) SHA-256 du corps et des 12 GLB puis audit exact et contrôle IBM/poids/corps, (3) essai Mesh2Motion import/export avant/après, (4) Ara personnage alternatif et retarget vers 53 joints, (5) Blender/Rigger correction skinning, (6) captures Chromium à instants déterministes face/profil 3 LOD, (7) 30 rigs offline et benchmark apparié. N'écrire que dans espace R&D, jamais PR #300.

**Aucun gate, aucune fusion.**

# MATCH 3D V25 — réception de l’environnement distant et reprise Chat

Date : 5 novembre 2026. Travail limité à l’acquisition, l’automatisation et la réception ; aucune correction de personnage ou d’animation.

## Références

- R&D : `research/match3d-v25-open-source-tools-20261105`.
- Socle initial : `eeefa3c9c5fc7cc711aa7c6fa41e782d1d70a6c9`.
- Plan publié : `debc6e3ac51802edd856717e2b3628c051ba7575`.
- Première réception : code `411cede9477c6a2d8a54cd5d3ce7ad1ca5d84efa`, [run 42078882889](https://github.com/Xynph/cadrage-debordement/actions/runs/42078882889), SUCCESS.
- Version renforcée : code `1591047dea43a53bdff686266b66bad4f99c46cf`, [run 42080196544](https://github.com/Xynph/cadrage-debordement/actions/runs/42080196544), résultat détaillé ci-dessous.
- Baseline immuable PR #300 : `2d8c8c7eee5aa0dad899aa6bb119e95bda0e7987`. Main initial contrôlé : `b585105767a11d2712a8f3c7e5fd8874387c23eb`. PRODUCTEUR V73 et tous les chemins jeu exclus.

## Première réception réellement récupérée et inspectée

Le connecteur GitHub accessible en Chat a listé l’artefact `13440580522`, puis l’a téléchargé sous forme de ZIP. Ce ZIP a été transféré via l’URL de fichier retournée par le connecteur, décompressé et inspecté sans interface graphique d’un outil 3D.

- ZIP : 36 618 593 octets ; SHA256 `2f40b0c47935fa26952318d65ac10f633fc6f245ad4ac6843c1ad719e3b1c6d4`, identique au digest GitHub.
- Les 179 fichiers du manifeste ont été vérifiés : zéro différence SHA256. L’artefact contient 114 captures JPEG originales ; plusieurs vues réelles passe/profil, impact, LOD2 et stage 30 ont été ouvertes et inspectées.
- Les 16 vrais GLB totalisent 23 256 792 octets. Ils ont chacun 53 joints ; zéro poids invalide, zéro somme de poids hors tolérance ±0,001, zéro indice de joint hors bornes. Noms/parents et inverse-bind matrices numériquement identiques sur les 16 fichiers. Corps : source 36 924 triangles, LOD0 23 993, LOD1 7 378, LOD2 1 469 ; 12 clips génériques dans chaque corps.
- L’auditeur Node **exactement publié** V25 a été exécuté sur les 16 GLB ; son `allMatch` vaut true. Le complément Python a lu les vrais buffers, sparse/normalisés, matrices et clips. La topologie est un diagnostic : les corps LOD1/LOD2 présentent respectivement 1/3 arêtes non manifold par indices ; les coutures et ouvertures sont comptées, aucune réparation ni qualification anatomique n’est présumée.
- Blender **4.5.3 LTS**, mode background, a importé/réexporté/réimporté les trois corps LOD : mêmes 53 noms de joints. Rigger s’est enregistré ; son test upstream de génération Human, Human simple, Quadruped, Horse et Bird a été réellement exécuté et a conclu OK. Ce test utilise des modèles synthétiques, pas un rugbyman ajusté.
- Ara a reconstruit les données MakeHuman et exporté `Athletic_man.glb` : 21 264 328 octets, 157 620 triangles d’après son CLI, 10 matériaux. C’est un personnage alternatif coûteux, **pas** une adoption pour 30 joueurs ni un retarget 53 joints validé.
- Mesh2Motion a été installé par `npm ci` et construit. La première réception ne testait pas son import/export ; la version renforcée ajoute cet essai et sa réimportation.
- Les tests Chromium LOD, contacts/impact/chute/récupération, surfaces, 30 rigs et benchmark apparié ont tous exécuté leurs scénarios et conclu PASS. Le stage possède 30 racines et 30 mixers distincts, trois LOD et zéro requête externe. Les vues ont été inspectées : le flottement et les autres limites visuelles du lot 24 restent visibles, sans fausse image « après ».

## Téléchargements verrouillés

Les commits upstream, SHA256 des 16 GLB, Node 24.11.0, Playwright 1.57.0 et Blender 4.5.3 sont dans `tools/match3d-v25-lab/remote/lock.json`. Les locks npm des sources figées sont utilisés par `npm ci` et leurs empreintes sont enregistrées dans `acquisition.json`.

| Ressource | Taille octets | SHA256 vérifié |
| --- | ---: | --- |
| Blender Linux x64 officiel | 377 397 328 | `975c58fcb244273838534bba771e64ad87739216b0f9b39a888531a49a72d845` |
| Fichier officiel de checksums Blender | 871 | `45ee01350376e7aa2fa141b5675d4a6576942f6a54e8fd0d5f0d021e873ab2dd` |
| Pack système MakeHuman CC0 officiel | 280 737 770 | `b542127a8e25547c7c29c19f2d1d2adb9a664c80396ecd694095dbc8028a0107` |

La première réception a établi ces empreintes ; la version renforcée les exige, sans acceptation silencieuse d’une nouvelle archive. Sources : Mesh2Motion `4f1316296660f2b9827ff46b4db10fb241ec2147`, Ara `fbf8a590a3c085bdb18a5ecd27554e5d0156bd4f`, Rigger `c8f1d1b9a8729582c61fa0ffa9a658ec4f4f6e77`, MakeHuman `a8bc2d54ff0ac92e78ff71431b1023eda42bf482`.

## Benchmark de contrôle — aucun gain revendiqué

Première réception : même scène isolée de 30 rigs, résolution 960×540, trois paires AB/BA/AB, 12 frames de chauffe et 24 mesurées, SwiftShader avec `gl.finish`. Médianes v23/v24 : TV **358,74 / 213,71 FPS**, zoom **376,18 / 181,41 FPS**. Ce contrôle montre un coût accru du lot 24 dans cette scène et une variance à examiner. Ce ne sont ni des FPS GPU matériel ni des FPS du match réel. Le runner observé possède 4 CPU et environ 16 Gio RAM ; les relevés bruts de ressources sont archivés.

## Réception renforcée et reprise

**🟢 CHAT AUTONOME POUR LES TESTS DISTANTS PRÉPARÉS.** La réception renforcée `42080196544` a terminé SUCCESS sur le code R&D exact `1591047dea43a53bdff686266b66bad4f99c46cf`. Le manifeste conclut `receipt.complete=true`, `missingOrFailed=[]` et **24/24 statuts PASS** (étapes et sous-tests, pas 24 suites indépendantes).

L’artefact `13440472034`, nommé `match3d-v25-rd-1591047dea43a53bdff686266b66bad4f99c46cf`, a été listé puis téléchargé par les mêmes interfaces GitHub accessibles en Chat. Taille : **40 005 367 octets**, digest ZIP SHA256 **`59c61f9c7fd5dc4e4971ea69a1f5316388a1a980360029ea2cdd8f6fb8da1cc2`** confirmé localement. **221/221 fichiers du manifeste revérifiés**, zéro différence ; **114 JPEG et 4 PNG**. Conservation annoncée par GitHub : jusqu’au **19 novembre 2026 à 18:08 UTC**, puis régénération possible par le pipeline.

- Acquisition reconstruite avec les SHA256 obligatoires : PASS ; 16 vrais GLB et auditeurs : PASS.
- Blender headless trois LOD, Rigger registration, build et test de génération upstream : PASS.
- Mesh2Motion : import du corps LOD2 réel via `StepLoadModel` en mode préservation, export via son `StepExportToFile.export_glb`, puis réimportation. **8 maillages skinnés de 53 os**, noms/parents et indices de peau conservés ; écart maximal mesuré sur poids/matrices inverse-bind **1,4901161193847656e-8**, sous tolérance 1e-5. Aucune erreur JS ni requête externe. Les animations sont volontairement absentes de ce test minimal et restent à comparer.
- Ara : données reconstruites et personnage exporté via son CLI : PASS ; aucun import/retarget d’un rugbyman canonique n’est prétendu.
- Cinq scénarios Chromium (LOD, contacts, surfaces, stage 30 et paires) : PASS, avec captures récupérées.
- Préparation du package offline et tests Node offline : PASS. Test du rendu existant dans un vrai match, 30 personnages, allers-retours 2D/3D, fallback sans WebGL et état/sauvegarde inchangés : PASS. **Zéro requête externe et zéro exception JS** dans ce test. Le stage V24 et le rendu de match existant restent deux scènes distinctes ; V24 n’est pas raccordé au match par cette intervention.
- Cinq tests locaux du nouvel auditeur et du verdict, plus compilation Python et syntaxe du module JS Mesh2Motion : PASS. Les tests du verdict ont reproduit les cas manquants/FAIL avant correction.

La relance depuis Chat a été effectivement démontrée : le second commit a été publié via le connecteur GitHub, déclenchant un nouveau run, puis son artefact a été reçu et vérifié par ce même connecteur et son URL de fichier. Aucun téléchargement manuel ni interface locale Blender/Mesh2Motion/Ara n’est nécessaire à ce circuit.

## Prochaine session Chat

Lire `tools/match3d-v25-lab/README.md`, les derniers commentaires #73 et le HEAD R&D. Modifier uniquement des scripts/copies R&D, puis créer une requête datée sous `remote/requests/` pour déclencher une réception au nouveau SHA. Lire le manifeste, les statuts par outil, les captures et les logs via le connecteur GitHub. Les ZIP expirent après 14 jours : relancer pour les régénérer, sans téléchargement manuel dans Work.

Travaux encore à faire : retarget Ara vers le rig canonique ; préservation et comparaison des animations dans Mesh2Motion ; essais Rigger de fitting/poids sur une copie réelle ; améliorations de contacts/sol et qualification artistique ; raccordement V24 au match réel séparément. Tous ces travaux par scripts peuvent être poursuivis en Chat avec le pipeline. Aucun de ces résultats n’est annoncé comme acquis.

Aucune opération graphique locale n’est indispensable aux tests préparés. Les retouches artistiques interactives restent une option humaine ; un benchmark GPU Windows natif nécessite un poste/runner GPU et reste hors de la réception SwiftShader. Aucun achat, service cloud propriétaire, abonnement ou modèle interdit en France/UE n’a été utilisé.

PR #300 et ses GLB, moteur, sauvegardes, fallback, PRODUCTEUR, DATA/LNR, main et auto-release inchangés par cette intervention. Les seuls fichiers de workflow écrits sont ceux du nouveau laboratoire R&D. Aucun gate, aucune fusion.

# Essais parallèles des sept dépôts — Oval Legacy 27

9 novembre 2026. Suite de l’étude documentaire PR #425. Six agents spécialisés ont travaillé en parallèle ; le coordinateur a testé Game Studios, relu les sept rapports et consolidé les résultats. Aucun verdict global « tout est vert » : les échecs et parties non reçues figurent ci-dessous.

## Résultat et effort GPT‑6.1 Sol

| Dépôt transmis | Essai réellement exécuté | Résultat principal | Effort pour la suite |
|---|---|---|---|
| [open-3d-skills](https://github.com/Moh4696/open-3d-skills) | Validation, module3D, serveur Range, captures canvas2D | 16 assertions module ; deux captures et vidéo12images réussies ; starter WebGL non reçu | Moyen pour rejouer ; Élevé pour diagnostic/intégration |
| [prompt2rig](https://github.com/blendi-remade/prompt2rig) | Vrai retargeting sur données synthétiques, serveur, export/import Godot | 10 contrôles ; GLB22bones/23pistes importé ; vidéo et HQ non exécutées | Élevé ; Très élevé si ballon/contact |
| [Scenario Skills](https://github.com/scenario-labs/skills) | Toolkit Godot, humanoïde procédural, copie athlète | 18tests réussis,1erreur rsync,3ignorés ; boucles import détectées puis réglées | Élevé pour intégrer ; Moyen pour rejouer |
| [Blender Skills](https://github.com/EL4CTEO/blender-skills) | QA et vrai preset godot sur copie athlète | 31bones/11clips conservés ; sommets3981→4029 ; suite export2succès/2échecs sous4.3.2 | Élevé ; Très élevé si changement rig |
| [Teardown](https://github.com/elvarofficial/teardown) | Trois builds, cinématique et capture navigateur | 3builds et5768échantillons reçus ; captureV8 inspectée ; autres contrôles graphiques incomplets | Moyen ; Élevé pour adaptation tactique |
| [Agent Sprite Forge](https://github.com/0x0funky/agent-sprite-forge) | Export sprites synthétiques, codecs et vrai import Godot | 26tests export et33contrôles codecs ; timing et alpha reçus ; identité Gabi non testée | Moyen pour export ; Élevé pour intégrer Gabi |
| [Game Studios](https://github.com/Donchitos/Claude-Code-Game-Studios) | Helpers réels et fixture défectueuse | Six familles de défauts détectées ; audit non adapté aux dossiers réels du jeu | Moyen pour helpers ; Élevé pour adaptation |

L’effort désigne le raisonnement conseillé au modèle GPT‑6.1 Sol, pas le coût GPU ou le temps machine. Ces recommandations ne prouvent pas une supériorité mesurée d’un niveau : les agents ont hérité de la configuration de la session, sans comparaison A/B des niveaux d’effort. Élevé convient à la coordination de cette campagne ; Très élevé est à réserver aux futurs changements croisés moteur/ballon/contact, pas nécessaire pour répéter un export établi.

## Décision produit après essais

1. Retenir d’abord les contrôles d’import/animation Scenario et le preset Blender testé. Refaire la famille Blender sous5.2 avant adoption générale ; vérifier les poses et la topologie avant de remplacer notre athlète.
2. Retenir PNG/SpriteFrames de Sprite Forge pour un futur essai Gabi, avec contrôle humain de l’identité et de la bouche audio.
3. Garder Open3D et Teardown pour démonstrateurs web ; leurs résultats n’améliorent pas directement le moteur Godot.
4. Prompt2rig a une chaîne retarget/export techniquement exploitable sur fixture, mais ses composants HQ restent à droits restrictifs et sa génération complète n’a pas été reçue.
5. Game Studios fournit des helpers utiles, à adapter à notre arborescence sans remplacer notre gouvernance.

**Prochaine réception sur Codex PC Windows :** versions compatibles, mêmes fichiers et instants, apparence source/export, appuis/mains/ballon, caméras et trente acteurs. Les captures Cloud logicielles ne sont pas des benchmarks matériels.

## Périmètre et intégrité

Essais isolés sous `/workspace/work/github-trials/`, sans installation globale des compétences, aucune modification du jeu, aucune sauvegarde personnelle ouverte, aucun service de génération payant appelé. Des packages locaux ont été téléchargés. Des médias de test ont été créés procéduralement ou à partir du modèle existant ; ils ne sont pas présentés comme des générations IA de production.

Référence GitHub vérifiée avant publication : main `e38a79f3c5ea2f7d48a362a96091ba466f70399f`. La copie de travail du jeu est au commit `26235845331964d233ee1cc0659883948954f542`, antérieur ; elle a servi uniquement de source en lecture. **Ces essais ne constituent pas une validation de toute la tête GitHub actuelle.** Son état Git était propre avant/après. Les chemins natif et dist du modèle local possèdent le même SHA256 `7fd28255c484e19ba5086d9cf815128e21dfcb677d262a88b237a5f5af081c5f`, inchangé pendant les tests.

Les rapports ci-dessous conservent versions, commandes, mesures et limites. Les harnesses personnalisés, JSON complets et médias sont conservés dans le workspace d’essai ; ils ne sont pas tous archivés dans cette PR documentaire. Les noms relatifs de preuves désignent le dossier de chaque chantier. Le rapport publié n’est donc pas une archive autonome de l’intégralité des essais. Aucune CI du jeu, recette Windows ou campagne complète amont n’est déclarée réussie sans preuve.


---

## Essai réel open-3d-skills — 9 novembre 2026

Révision : `53beb899e77f65d50160a3765f36f5ddb8b3c19b`.
Périmètre : copie isolée dans `/workspace/work/github-trials/open3d/repo`. Aucun fichier du jeu ni configuration globale d'agent modifié. Aucun média payant généré.

### Résultats

- **PASS** `npm install --cache ../npm-cache --no-save --no-package-lock yaml@2.6.1` puis `node tests/check.mjs` : 8 compétences chargées, 5 manifestes concordants, 20 scripts parsés. Cette suite vérifie la structure, pas la qualité visuelle.
- **PASS** `node runtime-trial.mjs` : 16 assertions exécutées sur le module amont réel `skills/exploded-view/assets/explode.js`, avec three0.169.0. Positions initiales/finales, étapes, bornage, idempotence et restauration, transparence/x-ray et plan de coupe contrôlés. Exploder/Xray/Section fonctionnent sur une fixture de deux meshes. Labels et picking DOM non testés.
- **PASS** serveur amont `serve.py` : requête Range `bytes=0-31` renvoie HTTP206, Content-Range `bytes 0-31/8634`, exactement32octets. Ceci valide une fonction nécessaire aux vidéos seekables.
- **PASS** `CHROME_PATH=/usr/bin/chromium python3 skills/site-check/scripts/check.py http://localhost:31460/open3d/fixture/canvas-test.html --out ../site-check-canvas --widths 640 --browser chromium --ready 'window.__ready === true' --wait 0.1` : deux captures normal/reduced-motion, zéro erreur, zéro canvas vide, zéro débordement. Fixture canvas2D créée pour cet essai, pas un résultat de production du dépôt. Fichiers `site-check-canvas/report.json`, `sheet.jpg` et PNG.
- **PARTIEL / NON REÇU** le starter pavillon three.js n'a pas satisfait les tentatives de navigation/readiness dans un délai raisonnable ; les essais ont été arrêtés. La fixture copie le starter et remplace uniquement l'import CDN par three0.169.0 local. La cause exacte n'est pas isolée. Une navigation diagnostique au stade `commit` réussit sur le serveur partagé. Cela ne prouve pas le rendu WebGL.
- **BLOQUÉ** navigateur Playwright embarqué absent. Téléchargement officiel tenté dans le dossier local : HTTP403 `Domain forbidden` pour cdn.playwright.dev. Fallback Chromium système utilisé. WebKit non testé.

Le fichier de politique Chromium contient des exceptions `http://*`/`https://*` : aucune attribution du problème de starter à une interdiction de cette politique n'est justifiée. Aucun FPS GPU revendiqué. La cadence du canvas2D ne mesure ni notre match Godot, ni un appareil cible.

### Utilité pour Oval Legacy27

Bon candidat pour diagnostics/captures des pages web et démos de présentation. Les modules three.js testés ne sont pas des composants Godot : portage requis. Aucun apport direct démontré au moteur rugby ou aux contacts squelettiques. Pour adopter site-check, exposer des états reproductibles et la disponibilité réelle de la scène, puis reprendre une réception WebGL sur environnement graphique fonctionnel.

### Effort GPT6.1 Sol conseillé

**Moyen** pour installation et validation structurelle ; **Élevé** pour adapter les checks au jeu ou diagnostiquer les problèmes de rendu. La réception visuelle Windows du jeu reste distincte et à faire sur PC.

**PASS frame-capture** : `record.py` sur la fixture canvas2D, 1seconde,12fps,640×360 : 12images encodées, aucune erreur de page. `canvas.mp4` conservé. Cet essai vérifie la chaîne horloge virtuelle/capture/ffmpeg ; il ne valide pas les performances3D.

---

## Essai réel prompt2rig — 9 novembre 2026

Révision testée : `218ce2adff35a7c04657768a85ff002ebd461c78` (blendi-remade/prompt2rig).
Périmètre isolé : `/workspace/work/github-trials/prompt2rig`. Aucun fichier du jeu modifié, aucun appel image/vidéo fal, aucun modèle HQ téléchargé, aucune clé utilisée.

### Verdict

**La bibliothèque de retargeting et son chemin d'export fonctionnent sur une fixture synthétique. Le GLB exporté est réellement importable dans Godot 4.7.2. La chaîne complète prompt → vidéo → pose → mouvement n'est pas reçue.** La prévisualisation navigateur reste partielle : interface chargée, mais scène noire sans personnage dans la capture examinée. Aucun résultat artistique ni mouvement de rugby n'est validé.

### Exécutions et preuves

- Clone shallow, SHA vérifié. Node disponible. Dépendances npm locales : `npm install --no-save --package-lock=false --cache /workspace/work/github-trials/prompt2rig/npm-cache three@0.169.0` ; version identique à l'importmap du produit. Le premier essai npm avec cache par défaut a échoué car `/home/agent/.npm` n'était pas inscriptible ; corrigé par cache local.
- `node smoke.mjs` dans `repo/` : **10 contrôles PASS** (détails `smoke-results.json`). Ils exécutent directement le vrai `public/retarget.js`, sans le recopier ni le modifier : rejet d'un squelette non Mixamo ; reconnaissance de 22 bones ; rotations SMPL identitaires puis non nulles, finies et normalisées ; snapshot/restauration/interpolation ; correction du plancher ; filtre One Euro ; retarget des 33 landmarks MediaPipe synthétiques ; AnimationClip de 23 pistes ; export réel par GLTFExporter.
- Sortie `synthetic-wave.glb` : **16 028 octets**, un skin, une animation et **23 channels** (22 rotations + translation Hips). Fixture géométrique simple et synthétique ; ce n'est pas un athlète du jeu ni un clip généré.
- `node server-smoke.mjs` : vrai serveur lancé localement sur 15377 puis arrêté. HTTP `/` et `/retarget.js` reçus 200 ; `/api/hq/health` renvoie explicitement `{ok:false,error:"worker offline"}` ; `/api/takes` sauvegarde les 16 028 octets exactement. Résultats `server-results.json`.
- Le même test révèle une limite : `/api/takes` accepte aussi `not-a-glb` et répond 200. Le stockage local ne valide donc pas la structure GLB. Aucun fichier invalide n'a été envoyé au jeu.
- Chromium headless via puppeteer-core : page locale et titre reçus, pas de `pageerror` pendant la fenêtre observée. Capture `app.png` examinée : contrôles présents, zone 3D noire, témoins personnage/modèle/worker encore non prêts. **Ce n'est pas une validation du rendu ou du suivi vidéo.** Aucun bouton de génération actionné.
- Godot 4.7.2 : projet dédié `godot/`, import effectif du GLB et script `check.gd` chargeant le PackedScene. Contrôle final **exit 0**, `godot-check.log` : `{"animations":["synthetic-wave"],"bones":22,"skeletons":1}`. Premier lancement éditeur sans répertoires XDG inscriptibles : erreurs de chemins utilisateur ; relance avec XDG_DATA_HOME/XDG_CACHE_HOME/XDG_CONFIG_HOME locaux. Les processus éditeur du test ont été arrêtés et le contrôle final est propre.

### Non reçu / obstacles

- `nvidia-smi` absent dans ce Cloud. Cela ne prouve pas seul l'absence de tout GPU, mais aucun environnement CUDA/NVIDIA HQ n'a été établi. Worker HQ non démarré.
- Pas de compte fal ni de dépense autorisée : endpoints `/api/video` et `/api/image` volontairement non appelés. Aucun temps ou coût de génération mesuré.
- Pas de modèle MediaPipe exécuté sur une vraie vidéo : seuls ses landmarks d'entrée synthétiques passent par le vrai retargeting.
- Aucun GVHMR, SMPL-X, WiLoR ou MANO téléchargé/exécuté ; leurs licences recherche/non commerciales restent un obstacle au flux HQ pour notre jeu commercial, indépendamment de l'Apache-2.0 du code prompt2rig.
- Pas de test des 31 bones/11 clips d'Oval Legacy 27, ni de contact, passe/ballon ou performance à trente joueurs.

### Recommandation et effort GPT-6.1 Sol

**Élevé** pour adapter proprement le retargeting au squelette réel et nettoyer un geste individuel. **Très élevé** si l'on essaie de raccorder un mouvement au ballon ou à un contact à deux acteurs, car moteur et présentation doivent rester cohérents. **Moyen** suffit pour refaire le smoke technique à l'identique.

Cloud convient au retargeting, aux tests d'export et d'import. PC Windows avec NVIDIA serait nécessaire pour évaluer le worker HQ dans son environnement annoncé, mais les droits doivent être réglés avant toute incorporation commerciale. Le meilleur prochain essai autorisable reste un clip individuel aux droits compatibles, nettoyé et importé sur une copie du personnage. Ne pas généraliser à partir de la fixture synthétique.

---

## Essais réels de Scenario Skills pour Oval Legacy 27

9 novembre 2026, Linux Cloud. Révision testée : `b96506d77c8595a4fe9c66eddb0bf9b5953a1d45`.

### Verdict

La famille Godot est utilisable pour construire, exporter, réimporter et analyser une animation locale sous Godot 4.7.2. Aucun compte Scenario ni génération payante n'a été utilisé. Elle mérite un essai d'intégration ciblé, avec contrôle explicite des drapeaux d'audit, pas une installation automatique de tous ses réglages.

**Effort GPT-6.1 Sol conseillé : Élevé pour l'intégration et le diagnostic, Moyen pour rejouer ces recettes établies.**

### Environnement et commandes

- Godot : `/workspace/.cloud-setup/tools/godot472/Godot_v4.7.2-stable_linux.x86_64`, version 4.7.2.stable officielle.
- Python 3.12, toolkit standard library, aucun paquet ajouté.
- Clone : `git clone --depth 1 https://github.com/scenario-labs/skills.git repo`.
- Consignes du dépôt et compétences `scenario-godot-expert`, `scenario-godot-animation` et référence traps consultées.
- Suite : `GODOT=<binaire ci-dessus> XDG_DATA_HOME=<dossier>/runtime/data XDG_CACHE_HOME=<dossier>/runtime/cache GD_LOCK_DIR=<dossier>/runtime/locks python -m unittest discover -s tests/scenario-godot-expert -v` depuis repo. Sortie conservée dans `unittest.log`.
- Recette propre : `python smoke.py` depuis le dossier d'essai. Résultats intégraux dans `smoke-results.json`.
- Recette de boucles et modèle du jeu : `python followup.py`. Le script fixe aussi XDG_CONFIG_HOME dans `runtime/config`, correction environnementale après le premier passage. Premier passage conservé dans `followup-first-results.json` et `followup-first.log`.

Les scripts sont adjacents à ce rapport. Ils créent uniquement le projet isolé `project/`, en renderer Compatibility et avec Jolt désactivé. Aucun fichier du jeu n'est modifié.

### Suite amont

22 tests exécutés : **18 réussis, 1 erreur, 3 ignorés**. Il ne s'agit pas d'une suite entièrement verte.

- Erreur : `test_role_clone_refresh_skips_agent_out`, car la commande système `rsync` est absente. L'appel de synchronisation du toolkit multiplayer ne peut donc pas fonctionner dans cet environnement sans cette dépendance.
- Deux ignorés : SDK Android absent.
- Un ignoré : capture fenêtrée, pas de DISPLAY dans le processus de test.
- Réussites : import des scripts de la famille, verrous entre processus, contrôle d'éditeur actif, création de scène réelle Godot, audit, Unicode, chargement de scripts et copie de projet pour le contrôle de typage.

Aucune élévation système n'a été engagée pour la dépendance facultative rsync. Les fonctions d'animation ciblées n'en ont pas besoin.

### Essai procédural réel

Le toolkit a construit un humanoïde Mixamo synthétique : **22 bones, 8 clips** (RESET, fall, idle, jump_up, land, run, walk, wave), taille 1,81 m. Il a exporté `project/assets/hero.glb`, puis Godot l'a réellement réimporté.

Les audits source et GLB ne signalent aucune piste non résolue. Les positions de Hips, LeftFoot et RightFoot ont été échantillonnées à 0, 0,25, 0,5 et 0,75 seconde de walk : elles varient réellement, ce n'est pas un simple contrôle de présence du fichier.

Attention : le contrôle `check_all` de ce petit projet retourne zéro script applicatif vérifié, car les scripts exécutés sont dans l'addon exclu par défaut. Il ne doit pas être compté comme preuve supplémentaire de la qualité d'une application.

### Défauts et précautions observés

1. Les boucles source fall/idle/run/walk deviennent `none` lors de l'import GLB par défaut. L'audit avec `expect_loops` le détecte dans quatre drapeaux. Le réglage explicite `settings/loop_mode=1` puis la réimportation rétablit ces boucles : aucun drapeau ensuite.
2. **L'audit retourne `ok=true` même avec des drapeaux non vides.** Le code consommateur doit examiner `result.flags`, comme le prescrit le guide, et ne pas assimiler `ok` à « asset prêt à livrer ».
3. Première réimportation éditeur : erreur de répertoire `/home/agent/.config/godot/feature_profiles` inaccessible, et messages de fuite de ressources à la fermeture. La réimportation a appliqué les boucles, mais son appel a correctement retourné faux. La reprise avec XDG_CONFIG_HOME isolé a réussi : set_loop_options et sa réimportation retournent vrai, audit final sans drapeau de boucle. Le premier échec reste conservé séparément dans les fichiers JSON.
4. L'export élimine certaines pistes immuables. Un nombre de pistes différent n'est donc pas automatiquement une corruption ; il faut comparer poses et mouvement attendus.

### Audit d'une copie du vrai modèle du jeu

Source lue : `/workspace/cadrage-debordement/dist/match3d/assets/quaternius-rugby-athlete.glb`. Copie vers `project/assets/athlete.glb`, import puis audit par le toolkit.

- **31 bones, 11 clips**, retrouvés dans le GLB et l'import Godot.
- SHA-256 source avant et après : `7fd28255c484e19ba5086d9cf815128e21dfcb677d262a88b237a5f5af081c5f`.
- Le toolkit signale l'absence d'une animation RESET. C'est un avertissement de sa convention d'AnimationTree/blending, **pas une régression démontrée de notre lecteur de match personnalisé**.
- Aucune animation du jeu n'a été modifiée, aucune carrière ouverte, aucune règle sportive testée ou changée.

### Portée de réception

Preuves obtenues : exécution réelle headless Linux, génération procédurale, export/réimport de GLB, audit squelettique et échantillonnage de poses. Les scripts et JSON permettent de reproduire les observations.

Non reçu : rendu visuel de cette fixture, appuis perçus en caméra de match, transitions de trente joueurs, tenue du ballon, coût CPU/GPU sur PC cible, exécutable Windows, service de génération Scenario ou droits/coût de ses modèles. Ces essais n'autorisent aucune substitution de l'athlète du jeu.

Prochain lot utile : intégrer uniquement les contrôles d'inventaire/import et une comparaison de poses sur une copie, puis recevoir les mêmes instants sous Windows. Garder la logique sportive et les trajectoires autoritaires dans notre moteur existant.

---

## Essai réel — EL4CTEO/blender-skills

9 novembre 2026. Effort GPT‑6.1 Sol recommandé : **Élevé** pour fabriquer/diagnostiquer le pipeline ; **Très élevé** si changement du squelette ou des contacts rugby. Aucun paiement, aucune installation globale, aucun fichier du jeu modifié.

### Verdict

**Utilisable de manière sélective, pas validé intégralement sur cet environnement.** Le preset amont `godot` a réellement réexporté une copie de l’athlète ; Godot 4.7.2 a chargé ce résultat et retrouvé les mêmes 31 bones nommés et 11 animations nommées. La suite amont filtrée export présente cependant 2 succès et 2 échecs sous Blender 4.3.2, version inférieure au prérequis 5.2. La QA fonctionne et signale des problèmes à examiner ; elle n’a pas été utilisée pour modifier l’original.

### Référence et outils

- Dépôt cloné `https://github.com/EL4CTEO/blender-skills` ; SHA `389f28addc79b87b28764898e38e7bf408d14b77`.
- Blender installé : 4.3.2, Python embarqué 3.13.5, mode background, backend GPU NONE.
- Godot employé explicitement : `/workspace/.cloud-setup/tools/godot472/Godot_v4.7.2-stable_linux.x86_64`.
- Asset lu : `/workspace/cadrage-debordement/dist/match3d/assets/quaternius-rugby-athlete.glb`.
- SHA256 avant/après identique : `7fd28255c484e19ba5086d9cf815128e21dfcb677d262a88b237a5f5af081c5f`.
- Tout le travail est isolé dans `/workspace/work/github-trials/blender/`.

### Exécutions et preuves

1. `python repo/tools/validate_skills.py` : **OK**, 28 skills, contraintes structurelles validées. Preuve `validate.log`.
2. `BLENDER_EXE=/usr/bin/blender python repo/skills/blender-core/scripts/run_in_blender.py repo/skills/blender-core/scripts/env_report.py` : **OK** ; version/API/GPU constatés, `env.log`.
3. `BLENDER_EXE=/usr/bin/blender BAS_SKIP_GPU=1 python repo/tools/run_tests.py export` : **2 PASS, 2 FAIL, 0 SKIP**. Le filtre inclut les noms de tests contenant export, y compris un cas animation.
   - PASS `test_export::test_batch_export_at_origin`.
   - PASS `test_scene::test_collection_exporter_snippet`.
   - FAIL `test_animation::test_bake_to_copy_with_root_motion_and_export` : usage `Action.layers`, absent du runtime 4.3.
   - FAIL `test_export::test_all_presets_roundtrip_scale` : appel opérateur glTF incompatible lors de la boucle des presets. L’échec arrête cette boucle : ne pas conclure que tous les presets échouent.
   - Preuve `export-tests.log`. L’extrait filtré du runner ne conserve pas toutes les dernières lignes d’exception ; aucune cause précise supplémentaire n’est inventée.
4. `blender -b --factory-startup --python-exit-code 1 -P trial.py` : **OK**. Import original, QA du mesh BaseHuman, export **via le vrai script amont** `export_asset.run(preset='godot',...)`, réimport du résultat. Preuves `trial.py`, `trial.json`, `trial.log`, `upstream.glb`.
5. Godot `--headless --path godot --script check.gd` : **OK**, code GLTFDocument source/export égal à 0, un mesh, mêmes 31 bones et 11 clips. Preuves `godot/check.gd`, `godot-report.json`, `godot.log`.
6. Un contrôle distinct utilise l’exporteur Blender natif 4.3 : `control43.glb`. **Ce contrôle n’est pas compté comme réussite de la compétence amont.** Le preset godot amont a néanmoins réussi indépendamment.

### Mesures du modèle

| Mesure BaseHuman | Import source | Réimport preset amont godot |
|---|---:|---:|
| Bones | 31 | 31 |
| Actions Blender / clips Godot | 11 / 11 | 11 / 11 |
| Triangles (fichier réellement lu) | 1 853 | 1 853 |
| Sommets Blender | 3 981 | 4 029 |
| Matériaux | 9 | 9 |

Les noms de bones et de clips Godot concordent exactement. Les sommets augmentent au réexport ; ne pas annoncer une topologie identique. Les dimensions du mesh évalué varient de moins de 0,000002 unité sur ce passage, mais cela ne prouve pas une déformation identique sur tout le clip. Les 1 853 triangles mesurés ici concernent le GLB source exact ; le rapport historique annonçait 1 854 pour un autre état de réception. Deux objets mesh sont observés côté Blender (BaseHuman et Icosphere), contre un seul mesh chargé par GLTFDocument dans Godot. Le rôle exact de l’Icosphere n’a pas été établi ; ne pas la supprimer automatiquement. La QA finale est limitée explicitement à BaseHuman.

La QA renvoie `ok:true`, **`pass:false`** : absence d’UV ; 2 faces dégénérées et 6 arêtes de longueur nulle. Avertissements : 1 990 doublons de sommets, une paire de faces dos-à-dos et point bas à −0,0044. Aucun sommet sans poids, aucun sommet à plus de quatre influences. L’absence d’UV n’est pas à corriger mécaniquement sur un personnage employant des couleurs/materials et un shader spécifique. La fusion de doublons risquerait de modifier les coutures, normales et déformations. Ces résultats sont des alertes de préparation, pas des défauts jouables démontrés.

### Installation et compatibilité

Pas de Blender 5.2 dans l’environnement inspecté. Une recherche `python -m pip index versions bpy` ne trouve aucune distribution pour le Python courant ; aucune version compatible n’a été installée. On ne conclut pas à une indisponibilité universelle de Blender 5.2. Le miroir Blender officiel n’est pas dans les domaines autorisés de l’environnement, donc aucun contournement ni long téléchargement n’a été tenté. La famille doit être reçue sous Blender 5.2 avant adoption globale, particulièrement animation/actions et rendu.

### Limites et prochaine étape

- Pas de QA Windows ni de benchmark de trente joueurs.
- Aucun test de skinning/poses à toutes les images ; même liste de clips ne prouve pas même animation.
- Aucun changement de squelette, de shader, de couleur de club, de simulation, de sauvegarde ou de règle sportive.
- Le rendu CPU de contrôle a rencontré deux particularités du build : monde absent dans une scène vide, puis denoiser OIDN non compilé. Le script de contrôle corrige le monde et désactive le débruitage ; ces ajustements ne touchent pas le code amont.
- Prochaine étape : Blender 5.2, mêmes tests, puis échantillonnage des poses source/export et contrôle dans la vraie scène Godot sur PC Windows.

Les captures CPU de cet essai représentent l’asset source générique et son export, sans le shader de tenue ni la scène finale du jeu.

Rendu CPU terminé avec succès : `athlete-preview.png` (512×512), ouvert et inspecté. Silhouette humanoïde complète, visage et membres visibles, sans déformation manifeste dans cette pose statique. Le vêtement générique reste visible ; cette image ne représente pas les tenues rugby finales.

---

## Essai réel — elvarofficial/teardown

9 novembre 2026. GPT‑6.1 Sol : effort **Moyen** pour construire et recevoir un exemple ; **Élevé** pour adapter une nouvelle explication tactique au jeu. Aucun intérêt à Très élevé pour simplement installer ce kit.

### Périmètre et version

Clone isolé `repo/`, SHA `a91262ac1109051e014662d42ecb0b7bc1f113b1` ; aucun fichier du jeu modifié, aucun push, aucun service payant. SKILL.md et paramètres de build lus. Node v24.22.1, Chromium système, Playwright1.58.2. Les essais ne font aucune génération d'assets.

### Essais exécutés

- `npm ci --ignore-scripts` a échoué sur le cache npm du home non accessible, avec des avertissements tarball secondaires. Reprise réussie par `npm ci --ignore-scripts --cache /workspace/work/github-trials/teardown/npm-cache` : sept packages installés. Aucun script lifecycle npm exécuté.
- `node sims/build.mjs v8-live` : **PASS**, HTML de825413octets (806Kio affichés), durée242ms lors de la première compilation.
- `node sims/build.mjs cessna-live strandbeest-live` : **PASS**, respectivement818256et817798octets, durées1433et642ms lors de cette exécution. Les trois HTML sont sous1Mio.
- `node ../test-kinematics.mjs` : **PASS**, 5768 échantillons (8cylindres ×721angles). Vérification longueur de bielle, positions finies, périodicité360°, pression positive, levées de soupapes dans[0,1], bornes piston100,5–189,5mm, volumes aux points morts1et10,2. Erreur maximale de longueur5,684341886080802e‑14mm. Ce test vérifie la cohérence mathématique du mécanisme fourni, pas l'exactitude physique du modèle thermodynamique.
- Chromium Playwright lancé avec succès. Navigation `file://` refusée par la politique navigateur (`ERR_BLOCKED_BY_ADMINISTRATOR`), ce qui ne permet pas de recevoir la promesse d'ouverture directe hors ligne dans cet environnement.
- Un serveur HTTP local répond200auHTML. La première tentative graphique1600×900via ce serveur n'atteint pas l'événementload en30s. Essais basse qualité et port partagé autorisé en cours lors de la première rédaction ; état terminal ajouté ci-dessous.

### Utilité pour Oval Legacy27

Le kit est opérationnel pour assembler de petits démonstrateurs mécaniques indépendants ; les maths se prêtent à des contrôles déterministes, et les panneaux/visites peuvent inspirer un tutoriel tactique. Le code de rendu reste three.js/DOM ; aucun import Godot, animation de joueur, contact de rugby ou raccordement au moteur de management n'a été testé. Ce dépôt ne fournit pas le jeu de destruction voxel homonyme.

Conserver cette piste pour une page de présentation ou une explication séparée, priorité faible derrière Blender et les compétences Godot. Le succès d'un build et des équations ne prouve ni un rendu sans défaut, ni60fps, ni une exécution Windows surGPUintégré. La vidéo et le son n'ont pas été produits ici.

### Preuves

`test-kinematics.mjs`, `kinematics-results.json`, `test-browser.cjs`, sortiesHTMLdans`repo/teardown-out/dist`. Les scripts de test sont extérieurs au clone. Les fichiers de dépendances amont restent inchangés.

### Résultat graphique terminal

L'essai basse qualité640×360sur le serveur local a atteint`SIM_SHOWN` et a produit`v8-desktop.png`(79277octets), puis a échoué lors de la seconde capture (portrait390×844), délai30s. La relance sur le serveur partagé autorisé31460a également atteint l'état affiché mais a dépassé30sà la capture. Les assertions pause/reprise et la recette portrait ne sont donc **pas reçues** ; aucun browser-results.json final n'a été produit. La capture disponible est inspectée séparément : cela ne constitue pas une validation des trois exemples ni une mesure de performance matérielle. Les essais utilisent SwiftShader explicitement : pas de benchmarkGPU.

Inspection visuelle effective de`v8-desktop.png` : moteurV8central visible, pistons/soupapes et vilebrequin distincts, panneaux et commandes présents ; aucun canvas vide. Le petit format réduit fortement les textes et le bas du moteur est très sombre : capture utile comme preuve de rendu, pas de lisibilité mobile acquise. Aucun jugement de fluide sur cette image fixe.

---

## Essai réel — Agent Sprite Forge

9 novembre 2026. Agent dédié, périmètre isolé `/workspace/work/github-trials/spriteforge`. Dépôt : https://github.com/0x0funky/agent-sprite-forge ; HEAD `6b3da5c444363378e20f3fce130ebecc22f343dd` (v0.5.0).

**Verdict : chaîne déterministe d’export 2D reçue dans un vrai Godot 4.7.2 Linux.** Utile à un petit lot Gabi en PNG/SpriteFrames. Cela ne valide pas la qualité de génération vidéo d’un visage ni l’intégration à notre bouche audio.

### Environnement et dépendances

Python 3.12, ffmpeg 7.1.5 ; `engine_export.py doctor` confirme VP9 alpha et H264 fonctionnels. Pytest absent à l’origine : installé dans `venv/` local avec accès aux bibliothèques système. Aucun outil de génération ni clé API utilisé. Coût de génération : zéro appel de fournisseur, sans estimation de coût matériel Cloud.

### Essais exécutés

1. Fixture synthétique explicitement marquée : six poses RGBA géométriques 40×48, deux animations. Création depuis les helpers de test du dépôt, sans utiliser l’identité ou les fichiers de Gabi.
2. `skills/generate2dsprite/scripts/export_engine.py --clips artifacts/built/animation-clips.json --target all --output-dir artifacts/engine --name trial` : **exit 0**, status pass, deux clips/six images/une page, export Aseprite JSON, SpriteFrames et Sprite3D ; 3,563 s observées dans cet environnement concurrent.
3. Douze images RGBA synthétiques en boucle 64×64 ; `skills/video2dsprite/scripts/engine_export.py package --clean-dir artifacts/clean --output-dir artifacts/package --name idle --fps 12 --loop --formats png,webm,packed --art-source code --placeholder` : **exit 0**, douze images, 1000 ms ; 18,103 s. Statut **needs-visual-review** conservé.
4. `engine_export.py verify --package artifacts/package` : **exit 0, pass, 33 contrôles**, transports packedAlpha et webm ; 9,840 s. Décodage offline, pas lecture Windows.
5. `validate_animation.py artifacts/package --require-states idle --require-verify` : **exit 0, pass**, aucun élément ignoré ; 5,777 s.
6. Réel import éditeur headless Godot **4.7.2.stable.ed1daf0bf**, puis scripts `receive.gd` et `alpha.gd` : **réussis**. XDG_DATA_HOME/CONFIG_HOME/CACHE_HOME redirigés dans le chantier pour les droits d’écriture.

### Réception Godot indépendante du parseur amont

`godot-receive2.log` :

- idle : quatre images de **100 ms**, loop=true ; lecture avance réellement à frame 2 après 250 ms.
- attack : **80 / 60 / 200 ms**, loop=false ; écarts flottants inférieurs à 0,001 ms ; lecture arrêtée à frame 2 après 500 ms.
- Chaque texture référencée est chargée.
- `GODOT_RECEIPT_PASS`.

`godot-alpha.log` : lecture de l’image de la première AtlasTexture importée, **1392 pixels transparents, 16 semi-transparents, 512 opaques** (total 1920 = 40×48). Assertion des trois catégories réussie. Scène AnimatedSprite3D exportée chargée et instanciée : `SPRITE3D_SCENE_INSTANTIATION_PASS`.

L’atlas PNG a été ouvert visuellement : six poses rectangulaires cohérentes, sans prétention artistique. Ce contrôle n’est pas une recette visuelle de Gabi ni un rendu graphique GPU du jeu.

### Poids mesurés

- Atlas Godot : 134×106, **482 octets** compressés ; **56 816 octets RGBA bruts** (largeur×hauteur×4), pas une mesure de mémoire GPU effective.
- Paquet vidéo : poster 525 octets ; atlas 5287 octets ; WebM 3736 octets ; MP4 packed 5006 octets.
- Ces chiffres concernent des formes simples ; ils ne prédisent pas le poids de Gabi HD.

### Échecs rencontrés et corrigés

Première tentative de tests : pytest absent. Corrigé par venv local.
Premier lancement Godot : répertoires utilisateur non inscriptibles et import pas encore prêt ; texture non chargée, assertion échouée. Reprise avec chemins XDG locaux puis import achevé avant exécution des assertions. Les preuves finales sont `godot-receive2.log` et `godot-alpha.log`, les premiers logs sont conservés pour traçabilité.

### Tests amont

Une première campagne `tests/test_engine_export_v3.py tests/test_export_engine.py tests/test_finish_frames.py` a été volontairement interrompue après plusieurs minutes pour borner le chantier : **44 points de progression sans échec affiché**, mais aucune synthèse finale ; elle ne compte donc pas comme une suite réussie. Le contrôle applicatif de packaging/verify/import ci-dessus est complet. La suite ciblée export seule est consignée dans `pytest-export.log` ; son résultat terminal est ajouté ci-dessous après sa fin.

### Limites et décision pour Oval Legacy 27

Aucune génération d’image/vidéo ni conservation de visage sur plusieurs prises évaluée. Aucun détourage de footage réel, aucune synchronisation labiale/audio de Gabi, aucun rendu Windows, mesure FPS GPU, Aseprite réel ou lecture navigateur validé. L’export vidéo reste `needs-visual-review` malgré la vérification technique pass : les seuils ne prouvent pas la qualité artistique.

Retenir **PNG + SpriteFrames** comme première voie d’essai, dans une scène séparée. Prochaine réception : un petit mouvement autorisé de Gabi, identité stable, alpha sur fond clair/sombre, timing relié au vrai lecteur, inspection Windows à taille réelle. Aucune raison démontrée de remplacer les seize poses existantes ou leur bouche audio. Le jeu et son dépôt n’ont pas été modifiés, aucun push, aucun accès payant.

**Effort GPT‑6.1 Sol conseillé : Moyen** pour emballer/valider un asset connu ; **Élevé** pour raccorder Gabi sans régression d’identité, de voix ou de timing. PC nécessaire ensuite pour la recette Windows visuelle ; Cloud suffit pour les contrôles déterministes démontrés ici.

### Reproduction et preuves

`trial.py`, `trial-results.json`, `trial.log`, `pytest.log`, `pytest-export.log`, `godot-import*.log`, `godot-receive*.log`, `godot-alpha.log`, ainsi que `artifacts/` et les scripts GDScript. Les chemins figurant dans les commandes sont relatifs au chantier ; exécuter les scripts Python via `venv/bin/python` et les scripts Godot avec le binaire 4.7.2 du dossier `/workspace/.cloud-setup/tools/godot472/`.

#### Résultat terminal de la suite export

`venv/bin/python -m pytest tests/test_export_engine.py -q --durations=3` : **26 passed, 1 warning in 30.43s**, exit 0. La mise en garde Pytest est détaillée dans le log ; aucun test ignoré ou échoué dans cette suite. Ces tests comprennent durée SpriteFrames, chemins Sprite3D, comparaisons RGBA, refus d’entrées invalides et déterminisme des octets.

---

## Essai réel Claude Code Game Studios

Révision : `abc0de79d6ceb0b5d7aa693945849b3937afbe6a`. Effort GPT6.1 Sol recommandé : **Moyen** pour les helpers, **Élevé** pour adaptation à notre dépôt.

### Exécuté

- `bash .claude/scripts/skill-lint.sh all` : 78/78 dossiers lus (75 compétences et trois alias). Le helper produit des observations, pas un verdict de qualité.
- `bash .claude/scripts/agent-check.sh` : 49 agents, 78 dossiers de skills, 209 fichiers, 122 blocs de délégation inspectés. Sortie conservée ; ce n'est pas une preuve de réussite des workflows.
- `bash .claude/scripts/asset-scan.sh --root /workspace/work/github-trials/studios-fixture --engine godot --budget all=1 --max-dim 16 --files` : fixture intentionnellement défectueuse. PNG 30×45 de 106 octets, nom avec majuscule/espace, budget artificiel1octet, référence manquante et fichier orphelin. Les six familles attendues NAMING/POT/SIZE/DIM/ORPHAN/MISSING sont effectivement détectées ; assertion Python réussie.
- Même scan en lecture sur `/workspace/cadrage-debordement/native/godot` : 0 asset scanné, 70 fichiers hors périmètre,63 fichiers .import exclus ; recherche manquants non exécutée faute de src/. Le script signale explicitement ces limites. **Ce résultat ne valide pas les assets du jeu.**

### Décision

Helpers fonctionnels Linux. Bonne séparation faits/verdicts et données absentes. Pour notre arborescence native, adapter le périmètre de scan et les références avant usage. Ne pas installer l'ensemble des hooks ou remplacer AGENTS.md. La condition puissance-de-deux doit être une politique choisie : ce n'est pas une règle universelle pour les illustrations d'interface.

### Preuves et limites

Sorties : studios-skill-lint.tsv, studios-agent-check.txt, studios-fixture-scan.tsv, studios-game-scan.tsv (dossier parent). Contrôles de fixture réussis ; aucun workflow LLM Claude, création de jeu end-to-end ou réception Windows exécuté. Aucun fichier du jeu modifié, ni installation globale, ni paiement. Code retour0 des helpers ne signifie jamais conformité.

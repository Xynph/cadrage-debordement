# Étude des sept dépôts GitHub pour Oval Legacy 27

Étude documentaire et technique du 9 novembre 2026. Référence du jeu : main `e38a79f3c5ea2f7d48a362a96091ba466f70399f`, après intégration de #423. La PR #424 est ouverte lors de cette étude : ses six parcours ne sont pas considérés comme intégrés.

## Décision recommandée

**Retenir en priorité Scenario pour les compétences Godot et EL4CTEO pour la fabrication/validation des assets Blender. Essayer Agent Sprite Forge sur un seul besoin 2D de Gabi. Garder open-3d-skills pour la communication web et les comparatifs. Étudier prompt2rig uniquement dans un cadre isolé tant que les droits de sa chaîne HQ ne sont pas réglés.**

Ces dépôts interviennent à des étages différents. Une compétence est un guide et parfois une boîte à outils pour l'agent ; elle ne devient pas automatiquement une dépendance du jeu. Un outil de génération doit produire un fichier final importable, dont les droits et le coût sont connus. Aucun de ces projets ne fournit à lui seul un moteur de rugby, un championnat, une économie de management ou un plaquage fiable à deux personnages.

| Dépôt | Rôle réel | Utilité pour le jeu actuel | Décision |
| --- | --- | --- | --- |
| scenario-labs/skills | Compétences de génération + familles expertes DCC/moteurs | Très forte pour Godot ; sélective pour l'art généré | Première piste côté Godot, petit ensemble maîtrisé |
| EL4CTEO/blender-skills | Fabrication, rigging, optimisation, export et QA Blender | Très forte pour modèles et animations du match | Première piste côté production 3D |
| 0x0funky/agent-sprite-forge | Images/vidéos vers sprites et paquets d'animation 2D | Moyenne, ciblée sur Gabi et effets 2D | Un essai isolé avant généralisation |
| Moh4696/open-3d-skills | Sites three.js, animation web, captures et vérifications | Moyenne pour présentation ; faible pour le moteur natif | Boîte à outils web séparée |
| blendi-remade/prompt2rig | Prompt → vidéo → mouvement → squelette Mixamo | Potentiel pour gestes individuels ; obstacles juridiques et techniques | Recherche uniquement pour la chaîne HQ |
| Donchitos/Claude-Code-Game-Studios | Méthode de production Claude Code | Quelques modèles utiles ; fort recouvrement avec notre gouvernance | Prélever des pratiques, sans remplacer l'organisation |
| elvarofficial/teardown | Simulateurs mécaniques pédagogiques three.js | Faible directement ; inspiration de présentation | Pas d'intégration prioritaire |

Le classement est un jugement d'adéquation au projet, pas une note de qualité universelle.

## 1. Contexte réellement vérifié dans notre dépôt

Le jeu est un management de rugby à XV en français, avec client Windows natif Godot et version web historique. Le moteur de carrière et la présentation graphique ont leurs responsabilités distinctes. Le README décrit encore certaines étapes historiques ; le journal le plus récent et les commits prévalent pour l'état courant.

La fusion #423 apporte notamment la banque de **200 bases de portraits hors ligne**, les parcours de population et de staff et le suivi des jeunes. Le journal annonce 5 878 joueurs actifs pour 116 clubs, dont 114 jouables. Il serait donc peu pertinent de recommencer une banque de portraits génériques à partir de zéro ou d'introduire une génération distante obligatoire à chaque naissance.

Le match possède déjà un athlète CC0 adapté, **31 bones et 11 clips**, une tenue recolorable, des variations d'apparence et des couches de présentation. Le rapport des silhouettes indique 1 854 triangles par athlète et 55 620 pour trente acteurs avant les passes d'ombre. Ces chiffres sont ceux de la réception existante, pas une mesure refaite ici. La réception sur RTX 4080 SUPER ne prouve pas les performances sur PC modeste.

La préparation visuelle au contact ne constitue pas un plaquage complet. Le rapport existant exige, pour aller plus loin, des participants et rôles explicites, un point/orientation de contact, une chronologie, des états debout/sol et la possession/libération du ballon. **Un meilleur clip ne comble pas l'absence de ces informations dans la simulation.**

Gabi possède déjà seize poses, 74 fragments et une voix finale enregistrée localement. Un nouvel outil 2D doit préserver son identité et la synchronisation existante, et apporter un bénéfice visible.

Sources internes : [README](../README.md), [journal](../DEVELOPPEMENT.md), [silhouettes](native06-silhouettes-20261108.md), [contacts](native07-contacts.md), [Gabi](native07-gabi-finalisation.md), [PR #423](https://github.com/Xynph/cadrage-debordement/pull/423), [PR #424](https://github.com/Xynph/cadrage-debordement/pull/424).

## 2. Moh4696/open-3d-skills

### Ce qu'il contient

Huit compétences : threejs-scene, scroll-film, motion-assets, alpha-cutout, cursor-rig, exploded-view, site-check et frame-capture. Le cœur vise les sites 3D et animés : scènes procédurales, films pilotés par le défilement, détourage vidéo compatible avec plusieurs navigateurs, personnages suivant le curseur et vues éclatées.

Le dépôt comporte du code réutilisable. Le module `skills/exploded-view/assets/explode.js` exporte Exploder, Labels, Xray, Section et Picker. L'explosion déplace des pièces depuis leur position de repos suivant des étapes ; les labels reposent sur HTML/SVG, le picking sur le raycaster three.js. Ce code est lié au DOM et à three.js : il faut une adaptation pour Godot.

### Apport possible

- Captures comparatives propres pour montrer une évolution de la scène de match web.
- Petite page de présentation d'Oval Legacy 27, visite du stade ou démonstrateur d'une tactique.
- Vérification Chromium/WebKit du site ou de la version web historique.
- Inspiration pour des réglages de qualité, la réduction des mouvements et les états explicites d'une démonstration.

`site-check` expose des contrôles concrets : erreurs de page et de requête, canvas vide, débordements, captures multi-tailles, comptage de draw calls/triangles si le renderer est exposé. Sa documentation prévient que les mesures sous SwiftShader/llvmpipe ne constituent pas des mesures GPU exploitables.

### Limites et décision

Le « 60 fps » des démonstrations n'est pas une garantie sur notre stade avec trente joueurs. Les fonctions alpha vidéo et cursor-rig ne remplacent ni une animation squelettique ni la bouche de Gabi pilotée par son audio. La capture à horloge virtuelle peut être très fluide tout en masquant un coût réel élevé : ne pas l'employer comme benchmark.

Exigences annoncées : Node 22.20+ pour installation/checks, Python 3.9+, Playwright, Pillow, NumPy, OpenCV et ffmpeg selon l'outil. Certains workflows nécessitent un fournisseur image/vidéo. Licence MIT du dépôt.

**Décision : conserver site-check et frame-capture pour les outils web ; ne pas porter le rendu natif vers three.js.**

Sources : [README](https://github.com/Moh4696/open-3d-skills/blob/main/README.md), [site-check](https://github.com/Moh4696/open-3d-skills/blob/main/skills/site-check/SKILL.md), [module inspecté](https://github.com/Moh4696/open-3d-skills/blob/main/skills/exploded-view/assets/explode.js).

## 3. blendi-remade/prompt2rig

### Fonctionnement réel

Le prompt génère une vidéo via fal. MediaPipe fournit une prévisualisation dans le navigateur. Un worker local récupère le mouvement corporel avec GVHMR et les doigts avec WiLoR, puis le transfère sur un personnage Mixamo. L'application exporte un GLB animé.

Le fichier `public/retarget.js` confirme une dépendance réelle au squelette Mixamo : noms Hips, Spine, LeftArm, RightArm et jambes exigés, table SMPL→Mixamo, pose de repos, conversion en quaternions locaux et correction de hauteur des pieds. « Any rigged character » doit donc se lire dans ce périmètre ; notre squelette existant n'est pas automatiquement compatible.

### Besoins du jeu auxquels il pourrait répondre

Gestes individuels lisibles : attente, échauffement, célébration, réaction de déception ou geste de coach. Pour une passe ou un coup de pied, il faudrait ensuite nettoyer le mouvement, caler l'instant de contact et contraindre le ballon. Le ballon doit suivre l'état autoritaire du match, jamais une trajectoire devinée dans la vidéo.

Un plaquage, une mêlée, un ruck ou une lutte au ballon combinent plusieurs personnes et des occultations. Le README annonce justement des difficultés sur les rotations, le travail au sol et les membres cachés ou croisés. Ce sont des situations centrales du rugby.

### Obstacle commercial majeur

Le code propre au dépôt est Apache-2.0, mais son README distingue explicitement :

| Composant HQ | Restriction annoncée |
| --- | --- |
| GVHMR | Éducation/recherche/non lucratif |
| SMPL-X | Non commercial ; licence commerciale à obtenir séparément |
| WiLoR | CC-BY-NC-ND |
| MANO | Non commercial |
| Ultralytics YOLO | AGPL-3.0 ou licence entreprise |

L'export GLB ne supprime pas ces contraintes. Les modèles vidéo fal et les personnages Mixamo gardent leurs propres conditions. Le parcours MediaPipe/three.js évite plusieurs composants HQ, mais n'autorise pas à déclarer tous les contenus générés commercialement sûrs sans vérifier les termes applicables.

Exigences : Node 18+, clé fal ; HQ documentée sur Windows avec GPU NVIDIA, uv, ffmpeg, environ 5 Go de checkpoints et modèles enregistrés séparément. Les temps de quelques secondes annoncés concernent une RTX 4090 et des clips déterminés ; ce ne sont pas nos performances mesurées.

**Décision : pas d'animation HQ issue de cette chaîne dans la distribution commerciale sans licence adaptée ou remplacement des composants. Ne pas en faire une dépendance du jeu.** Un essai éventuel doit rester dans un bac de recherche séparé avec provenance explicite.

Sources : [README et tableau de licences](https://github.com/blendi-remade/prompt2rig/blob/main/README.md#license), [retarget.js](https://github.com/blendi-remade/prompt2rig/blob/main/public/retarget.js), [NOTICE](https://github.com/blendi-remade/prompt2rig/blob/main/NOTICE).

## 4. scenario-labs/skills

### Deux familles à distinguer

La première pilote le service Scenario via MCP : images, variantes cohérentes, textures, skyboxes, assets 3D, animations, audio et entraînement de modèles. Elle demande un compte et une connexion au service.

La seconde rassemble des compétences expertes pour les logiciels locaux, dont **14 compétences Godot** et une famille Blender. Les familles expertes n'exigent pas le serveur Scenario pour leurs tâches locales. Les spécialistes importent les scripts de leur compétence principale : installer un fichier isolé sans cette dépendance peut casser l'exécution.

### Pourquoi c'est la piste la plus proche du jeu

La famille Godot cible 4.7.2, version déjà employée dans nos réceptions. Animation, UI, performance/export, éclairage, shaders et automatisation des imports répondent directement aux besoins du client natif.

La compétence animation donne des recommandations précises : gameplay propriétaire des états, animation en lecture ; vitesse mesurée des pieds ; BoneMap contrôlée ; RESET et pistes résolues ; filtres explicites des couches. Elle avertit que glTF peut remplir les pistes de tous les joints et qu'une couche partielle non filtrée peut perturber les autres bones.

C'est pertinent pour notre mélange de locomotion, tenue du ballon et préparation au contact. En revanche, son workflow comporte des choix de kit, renderer et physique : **ne pas importer automatiquement Forward+ ou Jolt dans notre projet**, dont la réception graphique existante mentionne OpenGL/Compatibility.

### Génération d'art

Scenario peut être utile pour quelques références de stade fictif, objets d'entraînement, illustrations éditoriales ou variations réellement absentes. La compétence game-assets décrit la découverte du modèle, lecture du schéma, estimation `dry_run`, génération, attente du job, inspection et téléchargement PNG. Elle conseille alpha natif et références propres avant des passes de détourage supplémentaires.

La banque de portraits existante réduit l'intérêt d'une grosse nouvelle campagne. Les futurs contenus doivent rester exportés et jouables hors ligne. Les identités de carrière ne doivent pas être réassignées à chaque changement de modèle.

### Niveau de preuve

Le README Godot annonce des suites locales, des contrôles de captures et un comparatif de réponses écrites. Il précise que le comparatif ne mesure pas des jeux finis, que certaines fonctions n'ont pas été exécutées et que les vraies générations Scenario ont été remplacées par des assets synthétiques pour une partie de la validation. Ces réserves rendent les preuves plus interprétables ; elles n'établissent pas notre compatibilité.

Licence MIT des compétences ; coûts et droits des services/modèles à vérifier séparément. Aucun tarif ni coût total n'a été mesuré ici.

**Décision : sélectionner d'abord expert + animation + UI + performance/export + pipeline-automation et leurs dépendances, après audit des scripts. Garder le service de génération facultatif.**

Sources : [README](https://github.com/scenario-labs/skills/blob/main/README.md), [famille Godot et preuves](https://github.com/scenario-labs/skills/blob/main/skills/game-engines/godot/README.md), [animation](https://github.com/scenario-labs/skills/blob/main/skills/game-engines/godot/scenario-godot-animation/SKILL.md), [game-assets](https://github.com/scenario-labs/skills/blob/main/skills/scenario-game-assets/SKILL.md), [famille Blender](https://github.com/scenario-labs/skills/blob/main/skills/dcc/blender/README.md).

## 5. EL4CTEO/blender-skills

### Contenu et intérêt

28 compétences orientées Blender 5.2+ : scène, modélisation, UV, PBR, baking, rigging, animation, vêtements, cheveux, optimisation, export et QA. Le dépôt comprend des scripts et des tests, pas uniquement des conseils.

Les besoins les plus proches sont : vérifier le modèle actuel, préparer une variante de gabarit, nettoyer des clips, optimiser un petit stade et garantir un export GLB réimportable. Le pipeline export prévoit le contrôle des transformations, des matériaux, des bones déformants et des animations.

Le test `tests/test_export.py` inspecté exporte puis réimporte les presets et contrôle notamment une boîte de deux mètres, la présence de meshes/skin et les échelles d'armature. C'est une vérification technique utile ; une fixture simple ne prouve pas que notre athlète et ses onze clips seront conservés.

### Application proposée

1. Copie indépendante du GLB actuel ; conserver l'original CC0 et sa provenance.
2. Inventaire des bones, clips, poids, matériaux et dimensions avant manipulation.
3. Un seul clip ou accessoire modifié, puis export `godot`/GLB.
4. Réimport dans un projet Godot de test, avec mesure des appuis, mains/ballon et transitions.
5. Comparaison des trente acteurs et des profils de qualité avant toute substitution.

Le rigging propose Rigify et un squelette de jeu nettoyé. **Ne pas re-rigger automatiquement l'athlète existant** : ses 31 bones, ses clips et les couches procédurales sont déjà un contrat d'intégration. Un nouveau squelette exige un mapping et une migration des ressources graphiques explicites.

### Limites

La QA géométrique ne juge pas la lisibilité télévisuelle d'une action de rugby. Des matériaux procéduraux Blender doivent être bakés ou reconstruits dans Godot ; un shader de lookdev n'est pas nécessairement exportable. Un modèle plus détaillé peut aussi augmenter matériaux, bones, draw calls et mémoire.

Le README annonce 67 tests headless et des scripts testés en vrai Blender ; ils n'ont pas été relancés dans cette étude. Licence MIT. Blender et éventuellement un serveur MCP doivent être disponibles ; le mode batch reste possible.

**Décision : retenir core, asset-qa, game-optimization, animation et export-pipelines. Utiliser cette famille comme chaîne Blender principale ; éviter de doubler les mêmes tâches avec la famille Scenario Blender.**

Sources : [README](https://github.com/EL4CTEO/blender-skills/blob/main/README.md), [rigging](https://github.com/EL4CTEO/blender-skills/blob/main/skills/blender-character-rigging/SKILL.md), [export](https://github.com/EL4CTEO/blender-skills/blob/main/skills/blender-export-pipelines/SKILL.md), [tests export inspectés](https://github.com/EL4CTEO/blender-skills/blob/main/tests/test_export.py), [asset QA](https://github.com/EL4CTEO/blender-skills/blob/main/skills/blender-asset-qa/SKILL.md).

## 6. elvarofficial/teardown

### Ce que c'est

Une compétence Claude Code et un kit three.js pour expliquer une machine dans une page HTML autonome : modèle animé, panneaux de mesures, démontage, caméra et visite automatique. Ce dépôt ne fournit pas le jeu commercial de destruction voxel appelé Teardown.

Le `package.json` fixe notamment three 0.186.1, esbuild 0.28.1 et Playwright 1.58.2. Le script `sims/build.mjs` assemble JS/CSS/polices et peut incorporer des GLB ; des options externalisent les modèles lourds. L'autonomie hors ligne dépend donc du mode de build et de la présence des fichiers compagnons.

### Intérêt et limites

Les idées de visite guidée, d'annotations attachées aux objets et de comparaison entre paramètres et visualisation pourraient inspirer un tutoriel tactique. Mais les exemples moteurs, avions et mécanismes n'apportent ni mouvement collectif crédible ni simulation de rugby.

Le builder utilise `legalComments: 'none'` : si l'on redistribue un bundle dérivé, prévoir explicitement les notices de dépendances. Le README crédite claude-motion, ainsi que des samples CC0 et leur fichier de sources ; conserver cette traçabilité plutôt que supposer que tout relève uniquement de la licence du dépôt.

Exigences : Node 20+, dépendances npm et Chromium ; ffmpeg pour vidéo, Python pour son. Licence MIT du projet.

**Décision : inspiration pour une démo pédagogique séparée, sans intégration au client natif à ce stade.**

Sources : [README](https://github.com/elvarofficial/teardown/blob/main/README.md), [package](https://github.com/elvarofficial/teardown/blob/main/package.json), [builder inspecté](https://github.com/elvarofficial/teardown/blob/main/sims/build.mjs).

## 7. 0x0funky/agent-sprite-forge

### Fonctionnement

Une image maître approuvée sert à générer les actions d'un personnage par vidéo. Les outils Python contrôlent les prises, détourent, recalent, choisissent les boucles, retiment et préparent les exports. Sorties annoncées : atlas PNG, manifestes, Godot SpriteFrames/Sprite3D, Aseprite et formats vidéo.

L'état consulté est v0.5.0, avec le style hibit ; le README conserve une longue présentation de la version 0.4. Hibit transforme une illustration plate en pixel art via palette, réduction, hystérésis et contours. **Ce style n'est pas cohérent par défaut avec notre direction photographique/carnet** ; le mode HD est plus pertinent pour Gabi.

### Ce que le code confirme

`engine_export.py` produit un atlas et des manifestes de provenance/QA ; il impose des contrôles de résidus de couleur de détourage et peut décoder les vidéos pour comparaison. Il distingue explicitement ce qui n'est pas prouvé : identité, qualité du contact, appuis, lecture sur appareils et débit de décodage. Les seuils techniques ne remplacent donc pas une inspection visuelle.

Le manifeste d'animation est un format intermédiaire : Godot ne consomme pas magiquement toutes ses propriétés. Il faut vérifier le vrai export SpriteFrames/Sprite3D et le raccorder à notre lecteur. Pour le natif, commencer par PNG/SpriteFrames plutôt que dépendre de VP9 alpha ou de MP4 à alpha empaqueté.

### Utilité concrète

Essai possible : un clignement ou une petite réaction de Gabi, depuis son image existante autorisée, sans modifier la voix ni ses répliques. Contrôler barbe, visage, mains, cadrage, stabilité et coût mémoire. Éviter de remplacer sa bouche audio par une bouche générée qui parlerait pendant les silences.

Les sprites ne résolvent pas les contacts squelettiques du match 3D. Des silhouettes de foule ou éléments d'ambiance pourraient suivre, mais uniquement si le rendu et les performances justifient leur ajout.

Exigences annoncées : Python, NumPy, Pillow, SciPy ; ffmpeg 5.1+ pour vidéo ; route fournisseur ou CLI connecté pour la génération. Le script local ne rend pas la génération gratuite : abonnements, quotas et API gardent leurs coûts et conditions. Licence MIT du code, termes distincts pour médias et fournisseurs.

**Décision : un micro-lot HD de Gabi ; abandonner l'essai si l'identité dérive ou si le gain reste inférieur au poids et à la complexité ajoutés.**

Sources : [README](https://github.com/0x0funky/agent-sprite-forge/blob/main/README.md), [export inspecté](https://github.com/0x0funky/agent-sprite-forge/blob/main/skills/video2dsprite/scripts/engine_export.py), [notices tierces](https://github.com/0x0funky/agent-sprite-forge/blob/main/THIRD_PARTY_NOTICES.md).

## 8. Donchitos/Claude-Code-Game-Studios

### Nature du projet

Un template de production Claude Code, avec 49 agents, 75 compétences, 15 hooks et 62 modèles documentaires annoncés. Il couvre prototypage, design, art, architecture, développement, QA et livraison. Ce n'est pas un moteur ni un pack de graphismes.

Il possède un parcours léger et un mode studio. Son README rapporte même un essai où la rigueur documentaire supérieure n'a pas produit le meilleur jeu ; ce résultat local n'est pas une étude généralisable, mais confirme que le nombre d'agents et de documents n'est pas un indicateur de qualité.

### Éléments à reprendre

- Critères d'acceptation orientés jeu réellement lancé et observé.
- Budget d'assets et inventaire de provenance.
- Distinction entre mesure absente et résultat favorable.
- Petites fiches de lot : problème, impact visible, preuve, limites.

La compétence asset-audit inspectée refuse de remplir un budget sans données et distingue références manquantes et absence de fichiers à analyser. Bonne pratique, mais ses conventions de dossiers Godot ne correspondent pas automatiquement à `native/godot` et à nos sources de données.

### Pourquoi ne pas l'installer intégralement

Notre dépôt possède déjà AGENTS.md, coordination #73, branches, tests, passation et release gate. Importer CLAUDE.md, hooks, permissions et arborescence du template ajouterait une gouvernance concurrente. Les slash commands et délégations Claude ne sont pas directement une configuration Codex.

**Décision : extraire deux ou trois modèles utiles en les adaptant à notre dépôt ; ne pas multiplier les agents ni remplacer les protections existantes.** La présente étude ne déclenche aucune orchestration issue de ce template. Licence MIT.

Sources : [README](https://github.com/Donchitos/Claude-Code-Game-Studios/blob/main/README.md), [asset-audit inspecté](https://github.com/Donchitos/Claude-Code-Game-Studios/blob/main/.claude/skills/asset-audit/SKILL.md).

## 9. Architecture d'adoption proposée

| Étage | Choix | Résultat attendu |
| --- | --- | --- |
| Référence sportive et carrière | Moteur existant | États autoritaires, règles, identités et sauvegardes |
| Compétences d'intégration Godot | Scenario Godot | Imports, couches d'animation, UI et diagnostics |
| Production 3D | EL4CTEO Blender | GLB et clips nettoyés, contrôlés et traçables |
| Production 2D ponctuelle | Sprite Forge, si essai reçu | PNG/SpriteFrames de Gabi |
| Art généré complémentaire | Scenario MCP, facultatif | Fichiers validés puis embarqués hors ligne |
| Présentation et comparatifs web | open-3d-skills | Démonstration et preuves distinctes du jeu natif |
| Méthode de travail | Gouvernance actuelle + modèles choisis | Traçabilité sans second système de contrôle |

Ne pas installer simultanément deux chaînes Blender concurrentes pour le même asset. Choisir un responsable par étape, un format d'échange et une recette d'import. Figer les révisions examinées ; une mise à jour de compétence est un changement d'outillage à revoir.

## 10. Essais à mener et critères de réception

Ces essais sont proposés, **pas exécutés dans ce rapport**. Les seuils existants servent de comparaison ; tout nouveau budget doit être mesuré sur le matériel cible.

| Ordre | Essai borné | Critères de réussite |
| --- | --- | --- |
| 1 | Audit en lecture du GLB et d'un clip avec EL4CTEO | Inventaire concordant, source intacte, défauts identifiés sans réécriture automatique |
| 2 | Réexport d'une copie GLB et réimport Godot | Bones/clips attendus, échelle correcte, pistes résolues, apparence conservée |
| 3 | Un clip individuel et couche Godot Scenario | Appuis et ballon comparés, pause/reprise cohérentes, aucun état sportif inventé |
| 4 | Un mouvement HD de Gabi | Identité stable, vrai alpha, pas de conflit avec la bouche audio, lisible à sa taille réelle |
| 5 | Mesure scène complète | Trente acteurs, trois qualités/caméras, mémoire, temps CPU/GPU et premier chargement sur Windows cible |
| 6 | Comparatif de présentation | Même scénario, mêmes instants et caméra ; vidéo de capture séparée des mesures de performance |

Priorité de mouvement suggérée : attente/course, passe ou célébration individuelle avant toute tentative de contact à deux corps. Avant un plaquage complet : spécifier les données du moteur et vérifier les lois applicables, puis seulement produire l'animation.

Pour chaque média final conserver : auteur/source, outil et révision, licence/termes applicables, modèle éventuel, date, référence du job et coût observé, prompt si disponible, empreinte SHA-256, dimensions/durée et verdict visuel. Ne pas inclure de clés, profils personnels ou médias privés dans le dépôt public.

Aucun prix exact n'est avancé : un coût de lot dépend du modèle, de la durée, de la résolution, des retakes, du détourage et des exports. Obtenir une estimation bornée avant un essai payant. Les joueurs doivent recevoir les fichiers finaux ; aucun abonnement de génération ne doit être requis pour jouer.

## 11. Méthode, versions et limites de l'étude

Lectures effectuées via GitHub : README et métadonnées des sept dépôts ; arborescences ; sélection de compétences et de code détaillée dans les liens ci-dessus. Lecture du contexte du jeu, du journal, des rapports de contact/silhouette, de match_motion.gd, des PR ouvertes et des commentaires récents de coordination. Une récupération Firecrawl a également corroboré la page prompt2rig.

| Dépôt | Révision main relevée |
| --- | --- |
| [Moh4696/open-3d-skills](https://github.com/Moh4696/open-3d-skills) | `53beb899e77f65d50160a3765f36f5ddb8b3c19b` |
| [blendi-remade/prompt2rig](https://github.com/blendi-remade/prompt2rig) | `218ce2adff35a7c04657768a85ff002ebd461c78` |
| [scenario-labs/skills](https://github.com/scenario-labs/skills) | `b96506d77c8595a4fe9c66eddb0bf9b5953a1d45` |
| [EL4CTEO/blender-skills](https://github.com/EL4CTEO/blender-skills) | `389f28addc79b87b28764898e38e7bf408d14b77` |
| [elvarofficial/teardown](https://github.com/elvarofficial/teardown) | `a91262ac1109051e014662d42ecb0b7bc1f113b1` |
| [0x0funky/agent-sprite-forge](https://github.com/0x0funky/agent-sprite-forge) | `6b3da5c444363378e20f3fce130ebecc22f343dd` |
| [Donchitos/Claude-Code-Game-Studios](https://github.com/Donchitos/Claude-Code-Game-Studios) | `abc0de79d6ceb0b5d7aa693945849b3937afbe6a` |

Les dates de création relevées indiquent plusieurs projets très récents : open-3d-skills le 31 octobre, teardown le 30 octobre, prompt2rig le 19 octobre et EL4CTEO le 14 octobre 2026. Leur activité est encourageante mais leur recul est limité. Les étoiles ne sont pas utilisées comme preuve de stabilité.

Les fichiers ont été consultés sur main et les têtes ont été relevées pendant la même étude ; il ne s'agit pas d'un téléchargement atomique complet de chaque dépôt. Les liens main peuvent évoluer : les SHA ci-dessus identifient les états de référence à reprendre avant un essai.

**Non exécuté ici :** installation de ces compétences, suites amont, build des démonstrateurs, génération payante, test du worker GPU, réexport de notre athlète, mesures de performances et recette Windows. Les compteurs de tests et mesures des auteurs sont attribués à leurs sources. La lecture de quelques scripts ne constitue pas un audit exhaustif de sécurité ou de toutes les dépendances. Le constat de licence prompt2rig reprend son tableau explicite ; les termes des fournisseurs et les autorisations commerciales restent à vérifier avant production.

## 12. État de livraison de cette étude

Lot documentaire uniquement, sur branche dédiée et PR. Aucun code, asset, règle de jeu, format de sauvegarde, configuration de compétences ou workflow modifié. Aucun outil installé ni service payant utilisé pour générer des médias. Le journal partagé DEVELOPPEMENT.md étant réservé au chantier #424, la passation est portée par la PR et la coordination #73.

Recommandation de prochaine étape : **recevoir un aller-retour GLB Blender → Godot sur une copie de l'athlète existant, avec inventaire des 31 bones/11 clips et comparaison visuelle, avant toute refonte de modèle.**

# Passation Rugby Legacy 27 : point d'entrée pour Claude Cloud

Écrit le 27/11/2026. Le créateur du jeu est absent plus de deux jours et n'a pas accès à son PC. Claude Cloud reprend seul. Ce dossier dit où on en est, comment on travaille, ce qu'il ne faut jamais faire et quoi faire ensuite.

À lire dans cet ordre (une quinzaine de minutes) :

1. Ce fichier (organisation, CI, validation, PR).
2. [regles-du-createur.md](regles-du-createur.md) : les règles et goûts du créateur. Elles priment sur tout le reste.
3. [etat-27-novembre.md](etat-27-novembre.md) : l'état exact au moment de la passation.
4. [a-faire.md](a-faire.md) : le backlog priorisé.
5. [decisions-a-valider.md](decisions-a-valider.md) : les questions qui attendent le créateur (ne pas les trancher à sa place sauf mention contraire).
6. Selon le chantier : [moteur-match.md](moteur-match.md) (réalisme du match) ou [solidite-ci.md](solidite-ci.md) (tests et CI).

Les anciens documents de passation (`docs/passation-*.md`, `docs/v58-passation-finale.md`) sont historiques. Ce dossier les remplace pour la reprise du 27/11.

## 1. Ce qu'est le jeu

Rugby Legacy 27 est un jeu de gestion de rugby à XV, en français, sous Godot 4.7 (GDScript, rendu GL Compatibility), préalpha Windows. Le joueur dirige un club : composition des 23, entraînement, recrutement, contrats, finances, presse, et des matchs simulés avec une mise en scène 2D et 3D. Seule la carrière **Monde** existe pour les tests (56 clubs jouables, coupes européennes). Les anciens modes (France 30 et autres) sont exclus de la CI.

Cap actuel : **consolider** (rendre l'existant fiable, beau, agréable) plutôt qu'ajouter des fonctions.

Le dépôt est **public** : jamais de vrais noms de joueurs ou de clubs, de photos, de logos, de jetons ni de chemins locaux. Des ressources privées existent hors dépôt : ne jamais les ajouter sans accord explicite du créateur.

## 2. Organisation du dépôt

| Dossier | Contenu |
| --- | --- |
| `native/godot/` | Le jeu Godot : scènes et scripts `.gd` (interface sous `ui/`, match 2D et 3D, coque `main*.gd`). |
| `native/engine/` | Moteur de jeu côté JavaScript embarqué (chorégraphe 3D `match-choregraphe.cjs`, etc.). |
| `dist/` | Moteur de simulation JS (match : `rugby.js`, `matchflow.js`, `restarts.js`, `opposition.js`, `tactical-plans.js` ; carrière, économie, développement). La base commune `dist/rugby-common-rosters.js` est générée. |
| `tests/` | Suites : `tests/*.cjs` (Node, sans Godot) et `tests/godot-*.cjs` (pilotent le SDK Godot). Aides dans `tests/helpers/`. |
| `ci/` | Répartition et lancement des suites (`shard-tests.cjs`, `select-tests.cjs`, `suite-weights.json`, `ci-jobs.cjs`, `run-godot-suites.sh`, `en-ligne.sh`). |
| `.github/workflows/` | Workflows (voir section 4). |
| `scripts/` | Outils (mesures, génération de la base commune, `carte-code.cjs`, films de match Windows). |
| `docs/` | Documentation. `docs/carte-code/ECRANS.md` est la carte des écrans. |
| `design/` | Charte graphique (`design/art/art-bible.md`), fiches UX. |
| `.claude/`, `AGENTS.md`, `CLAUDE.md` | Kit d'agents, règles de cycle de travail. Lire `AGENTS.md` et `CLAUDE.md` : ils complètent ce dossier. |

### Où sont les écrans

`docs/carte-code/ECRANS.md` liste chaque écran avec son fichier et ses fonctions d'entrée. Méthode économe, à suivre :

1. Lire `ECRANS.md` (une ligne par écran).
2. `node scripts/carte-code.cjs <fichier.gd>` donne les fonctions et leurs lignes. `--cherche <motif>` remplace un grep large.
3. Lire la plage utile seulement (certains `.gd` dépassent 200 Ko : ne jamais les lire en entier).
4. Chantier sur plusieurs écrans : lancer d'abord l'agent `eclaireur` (`.claude/agents/eclaireur.md`), qui écrit un rapport dans `temp/eclairage-*.md`.
5. Un écran absent de la carte : l'y ajouter.

Ne jamais lire en entier `DEVELOPPEMENT.md` ni `README.md` (très gros) : chercher la section. `.ignore` exclut des recherches les bases de données volumineuses ; les interroger avec `node -e` ou `jq`.

## 3. Lancer les tests

### Suites JavaScript (sans Godot)

```
node tests/<suite>.cjs
```

La plupart passent en quelques secondes à quelques minutes. Les suites de saisons (carrière Monde jouée) coûtent plusieurs minutes par graine. Pour les simulations, utiliser `tests/helpers/carriere-monde.cjs` (`ouvrir(...)`, `ouvrirSaison({ graine, saison })` pour repartir d'un point de reprise) plutôt que de rejouer depuis la création.

Retour rapide avant de pousser : lister les fichiers modifiés dans un fichier, puis `node ci/quick-check.cjs <fichier-liste>`.

Après tout changement sous `dist/` : `node scripts/build-rugby-common.cjs --check`, et régénérer sans `--check` si c'est périmé. Oublier cette étape fait échouer la CI et le staging Godot (« Base commune périmée »).

Quand on ajoute une suite dans `ci/select-tests.cjs`, mettre à jour `tests/ci-selection.cjs`. Une nouvelle suite lourde doit aussi avoir son poids dans `ci/suite-weights.json`.

### Suites Godot

Le SDK Godot 4.7.2 est requis. En CI, il est téléchargé et vérifié (SHA-256), avec un serveur X virtuel et le rendu logiciel Mesa. En local ou en cloud :

1. Préparer le projet : `python scripts/build-godot-prototype.py --stage-only --node <chemin de node>`.
2. Importer : `godot --headless --editor --import --path native/godot` (sans `--editor`, plantage). Ordre impératif : staging puis import, sinon faux rouges (« Identifier NativeEngineBridge not declared », polices introuvables, `clubs.json` absent).
3. Lancer : `bash ci/run-godot-suites.sh <fichier-liste>` ou `node tests/godot-<suite>.cjs` avec `CD_GODOT_EXECUTABLE` défini.
4. L'import modifie des fichiers `.import` suivis par Git (par exemple `ballon.glb.import`) : `git checkout -- native/godot/art` avant de commiter.

### Tests lourds sans machine locale

`bash ci/en-ligne.sh --ref <branche> --suites "a b"` (ou `--captures`, `--mesures`) lance le workflow `a-la-demande.yml`, attend la fin, lit les résultats publiés dans la branche `resultats-en-ligne` (`runs/<id>/`) et affiche les échecs. C'est la méthode normale quand aucune machine Godot n'est disponible. Pièges : ce script écrase `FETCH_HEAD` (toujours brancher depuis `origin/main` nommé) ; une suite opt-in affichée « OK 0 s » en ligne est **sautée**, pas verte.

### Outils réservés au PC Windows du créateur (inutilisables en cloud)

Le verrou de places Godot, le bureau Windows caché, le film de match (`scripts/match-filme.ps1`) et les scripts PowerShell associés n'existent que sur son PC. En cloud, remplacer par la CI et `ci/en-ligne.sh`. Si le PC est rallumé, ses limites s'appliquent (voir [regles-du-createur.md](regles-du-createur.md)).

## 4. La CI

### Workflows principaux

- `tests.yml` (« Tests JavaScript ») : le workflow qui décide des fusions. Jobs : `classification`, `Suites 1/10` à `10/10` (suites Node réparties par poids, au plus 3 en parallèle par runner, 2 si une suite « exclusive » tourne), `Godot 1/6` à `6/6` (suites Godot, SDK 4.7.2, xvfb, limite d'étape 45 min, job 55 min), puis `Validation CI` (l'agrégateur : seule sa conclusion autorise la fusion).
- Déclencheurs : PR (brouillon : classification seulement, `Validation CI` rouge exprès, ne pas le « réparer ») ; PR prête : mode rapide (suites courtes, de poids ≤ 60 s, et suites modifiées par la PR) ; étiquette `batterie-complete` pour tout lancer ; push sur `main` (batterie complète, non annulée par la fusion suivante depuis #1348) ; `schedule` (cron `41 * * * *`, que GitHub n'exécute en pratique que quelques fois par jour) : batterie complète JS et Godot sur `main` ; `workflow_dispatch`.
- Les jobs Godot sont bloquants seulement si le diff touche Godot (`native/godot/`, `tests/godot-*`, lanceurs) ; sinon ils sont sautés.
- `main-rouge.yml` : si la batterie programmée de `main` est rouge, relance une fois les jobs en échec, puis alerte sur le ticket de coordination et **ouvre une PR de retour arrière automatique si une seule PR est en cause**. Surveiller ces PR de retour arrière : ne pas les laisser fusionner sans comprendre le rouge.
- `a-la-demande.yml` : tests, captures et mesures à la demande (`ci/en-ligne.sh`).
- `godot-sdk.yml` : recette SDK ciblée (étiquette `godot-sdk`), cron toutes les deux heures mais exécuté environ toutes les dix heures.
- Autres : `windows-release.yml` (recette et EXE Windows), `economy-audit.yml`, `career-resilience.yml`, etc. Les anciens workflows sont archivés dans `ci/archives/`.

### Répartition et limites de temps

- Répartition : `ci/shard-tests.cjs` avec les poids de `ci/suite-weights.json` (section `godot` remesurée le 26/11 à partir de 13 exécutions programmées). Nombre de jobs : `ci/ci-jobs.cjs` (`SHARD_COUNT = 10`, `GODOT_SHARD_COUNT = 6` depuis #1328 : à cinq, les suites Godot durent 44 min par job, au bord de la coupure à 45 min ; à six, environ 36 min).
- Chaque suite a sa limite de temps : 180 s pour les suites Node par défaut, 300 s pour les suites Godot par défaut, avec des exceptions (`ci/run-godot-suites.sh` `suite_limits`, `ci/suite-weights.json`). Exemples : `godot-match-grands-moments` 600 s depuis #1341, `godot-planche-direct-2d` 900 s.
- Jamais relever une limite sans mesure : voir règles du créateur.

### Pièges connus

- **Rouges en cascade** : un rouge en cache souvent un autre. Lire tout le rapport (toutes les suites en échec), pas seulement la première, avant de corriger. Prévenir qu'un autre rouge peut apparaître derrière.
- **Faux verts** : une suite affichée « PASS (0 s) » en batterie est sautée ; une CI verte peut ne pas avoir lancé la suite concernée (mode rapide : vérifier que la suite visée figure dans le run) ; une suite verte seulement en fenêtre peut être rouge en mode CI ; un test qui mesure une maquette ne prouve rien sur le vrai match.
- **Runners lents** : les runners 4 vCPU partagent 2 cœurs physiques. Le rendu logiciel du direct tourne parfois à environ 1 image par seconde. Ne jamais comparer des temps absolus en CI : mesurer le meilleur de N passes ou un ratio. Les attentes d'un test se comptent en temps réel, pas en images.
- **Graine fixe** : certains tests dépendent d'une graine (liaison du monde, planches du direct). Un changement des tirages du moteur peut les remettre au rouge sans défaut du jeu ; vérifier sur plusieurs graines avant de conclure.
- **Carton à la 5e minute** : depuis #1315, la graine 3 prend un carton à la 5e minute et l'écran d'arrêt met le match en pause jusqu'au choix du manager (voulu). Toute suite qui joue cette graine au-delà de la 5e minute doit cliquer « Reprendre » (modèle : #1335, #1359), sinon elle perd 600 à 900 s.
- **403 à l'installation apt** : l'étape « Serveur X virtuel et rendu logiciel Mesa » des jobs Godot peut échouer sur une erreur 403 du miroir de paquets. Ce n'est pas un défaut du code : relancer le job en échec (`gh run rerun <id> --failed`).
- **Mise à jour d'une PR** : `gh pr update-branch <n>` fusionne `main` dans la PR et relance sa CI (utile quand « Suites 4/10 » est rouge pour une suite lente comme `match-lois-completes`).
- **Fixtures de référence** à régénérer par leur script quand une scène change : `tests/fixtures/match-gestes-sequence.json` (`tests/godot-match-gestes-scenes.cjs`) et `tools/animation-replay/fixture.js`.
- **Branches distantes** : le push est refusé si la branche ne commence pas par `claude/`. Les branches `en-ligne/*` et `tmp/*` sont supprimées automatiquement ; ne pas en créer d'autres de ce genre.
- **Tests Godot dans un worktree neuf** : toujours préparer (staging puis import) avant de déclarer une suite rouge sur `main`.

Détail complet des rouges et intermittents : [solidite-ci.md](solidite-ci.md).

## 5. Comment on valide (avant tout « c'est fait »)

1. **Vérificateur GO indépendant.** Avant d'annoncer qu'un chantier est fait, un agent en contexte vierge (`.claude/agents/verificateur.md`, modèle passé à l'appel) ouvre le **vrai résultat** (branche, jeu lancé, captures ou film, journal de CI), le compare aux choix du créateur et rend GO ou NO-GO. « Presque fait » = NO-GO. Il relance chaque suite dans le mode de la CI, rejoue la vraie situation (vraie saison, vrai match) et note `git status` au début et à la fin.
2. **Liste des faux « c'est fait » déjà attrapés** (leçons) : écrans fusionnés sans avoir été vus dans le vrai jeu ; seuils de test abaissés pour passer ; suites annoncées sans avoir été relancées ; test qui mesure une maquette ; correctif qui ne couvre qu'une partie des écrans (chercher tous les écrans concernés par grep, pas seulement ceux de la liste) ; donnée « cachée » qui fuit par un chiffre dérivé ; PR annoncée prête alors qu'elle est en conflit avec `main` (relire `mergeable` juste avant) ; refonte qui ramène un défaut déjà corrigé (relire les anciennes retouches du créateur sur le même élément) ; « CI verte » alors que la suite visée n'a pas tourné ; film non reproductible (même graine, matchs différents).
3. **Changement visuel** : PR en brouillon **sans** fusion auto ; passer en prête et armer la fusion auto seulement après le GO du vérificateur sur le vrai jeu (la fusion auto peut fusionner avant la fin d'une vérification).
4. **Films et captures de preuve** : uniquement l'état **après** (jamais d'avant/après). Les supprimer dès le GO, garder les rapports et une dizaine d'images. Jamais de capture ni de binaire dans le dépôt public sans nécessité.
5. **Tests** : un test qu'on n'a jamais vu rouge ne prouve rien. Pour un correctif, vérifier que le test échoue sans le correctif.

## 6. Conventions de PR et de travail

- **Un chantier = une PR courte = un worktree.** Créer le worktree : `git fetch origin main` puis `git worktree add -b claude/<nom> <dossier> origin/main`. Ne jamais écrire dans le checkout principal (il peut être sale).
- **Jamais de `git stash`** : la pile de stash est commune à tous les worktrees, deux chantiers s'y sont déjà mélangés. Utiliser des commits locaux.
- **Squash et fusion auto** : une PR prête reçoit `gh pr merge <n> --auto --squash`. GitHub fusionne seul quand « Validation CI » est verte. Pas de push direct sur `main`, pas de contournement d'un contrôle rouge. Exception : changement visuel (voir section 5) et changement de test à valider (voir [regles-du-createur.md](regles-du-createur.md)).
- **Commits** : Conventional Commits en français (`fix(match): …`, `test(direct): …`, `docs: …`), terminés par la ligne de coauteur de l'outil. Description de PR en français, courte : côté jeu d'abord (ce qui change à l'écran), puis cause, correctif, preuve (rouge vers vert).
- **Avant de commencer** : `gh pr list --state open` ; ne jamais toucher aux fichiers d'une PR ouverte d'un autre chantier. Le ticket de coordination du dépôt (numéro 591) est le tableau commun : y réserver et signaler un chantier.
- **Ménage disque** : supprimer son worktree et sa branche locale dès que la PR est fusionnée (`git worktree remove --force`), et ses films.
- **Réponses au créateur** : courtes, en français, côté jeu (voir règles). Les détails techniques vont dans la PR.
- **Sous-agents** : le créateur veut un découpage en sous-agents avec modèle et effort adaptés (tableau dans `CLAUDE.md`). Sonnet pour le cadré, les tests et les vérifications chiffrées ; Opus seulement pour le moteur, l'économie, la 3D et les refontes d'interface. Au-delà d'environ 60 tours, un agent rend la main avec un résumé. Une conversation de chantier qui grossit (plus de 6 à 8 rapports d'agents) écrit sa passation et repart d'une conversation neuve.
- **Identité de commit** : utiliser l'identité déjà configurée dans l'environnement ; ne jamais mettre de nom ni d'adresse personnels dans un fichier, un message ou une requête externe.

## 7. Ce qui ne se fait pas pendant l'absence

- Aucun paiement, abonnement ou service payant.
- Aucune donnée du projet envoyée à un site externe (pas d'adresse du dépôt ni de contact dans une requête web).
- Aucun ajout de ressource privée au dépôt public.
- Aucune modification de test qui abaisse un seuil ou affaiblit un contrôle.
- Aucun choix visuel nouveau intégré au jeu sans l'avoir présenté en options (voir [decisions-a-valider.md](decisions-a-valider.md) : préparer les options, ne pas trancher).

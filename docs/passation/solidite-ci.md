# Passation : chantier « solidité CI » (état au 27/11/2026)

Pour qui reprend depuis GitHub, sans accès au PC de Léo. Tout ce qui est utile est dans ce fichier et dans le dépôt.

## 1. Rôle du chantier et état au 27/11

**Rôle.** Rendre la batterie « Tests JavaScript » verte et fiable sur `main` : classer chaque rouge, puis soit corriger le jeu (vrai défaut), soit adapter un test périmé (avec décision tracée), soit stabiliser un hasard ou un chrono. Sans jamais affaiblir un test.

**Où on en est.**
- Depuis le 26/11, la batterie complète de `main` était rouge en série (cartons non repris, tests périmés, lenteur du rendu en ligne). Une grande partie est réglée ; il reste quelques rouges à surveiller (section 4).
- PR récentes (fusionnées sauf mention) :
  - #1354 : une carrière Monde exportée juste après un match se réimporte (vrai défaut du moteur).
  - #1355 : perf du direct, la 3D cachée sous l'écran 2D n'est plus rendue (de ~1 à ~4-12 images/s en rendu logiciel) ; a débloqué carte joueur, planche-direct-2d, planche-direct-tableau, match-direct-da.
  - #1356 : remontées tardives réalistes (moteur) ; a changé des tirages, d'où #1360 et #1363.
  - #1357 : mise en page de la Composition testée en mode Monde (le test était exclu de la CI).
  - #1358 : cris-banc et temps-forts attendent en temps réel au lieu de compter des images.
  - #1359 : reprise après le carton de la 5e minute dans trois suites du direct.
  - #1360 : les essais de pénalité (+7, sans marqueur) sont comptés par les tests.
  - #1361 : réinvestissement des clubs riches selon la marge prévue.
  - #1363 : feuille déléguée réparée après une blessure du jour de match (suite à #1356).
  - #1364 : le bandeau donne le ballon à l'équipe qui l'a à l'image.
  - #1362 (ouverte) : message d'échec clair pour planche-direct-2d (plus de code 1 muet).
  - #1365 (fusion automatique armée au moment de la passation) : chrono de vente-joueurs au meilleur de 3 mesures, même seuil de 1,5 s.
- Plus ancien mais utile à connaître : #1324 (préchauffage des portraits, meilleur de 3), #1326 (reprise exacte d'un ancien journal qui franchit une semaine), #1328 (six jobs Godot), #1341 (plafond des grands moments 300 à 600 s), #1349 (cartes du pack de la Composition qui se chevauchaient), #1352 (liaison du monde scriptée).

## 2. Comment marche la CI

Workflow : `.github/workflows/tests.yml` (« Tests JavaScript »). La batterie complète tourne sur `schedule` (cron `41 * * * *`, que GitHub exécute environ 3 fois par jour), sur `workflow_dispatch`, et sur une PR qui touche du Godot. Les PR touchant peu de fichiers passent en mode rapide (suites modifiées seulement, `CD_RAPIDE`). Les push sur `main` ne s'annulent plus entre eux (#1348). Le job final « Validation CI » agrège tout.

**Jobs « Suites n/10 »** (node pur).
- Dix lots équilibrés par `ci/shard-tests.cjs` selon les poids de `ci/suite-weights.json` (section `js`, médiane des durées de runs verts plus 15 %).
- Exécution par `ci/run-shard-suites.sh` : 3 suites en parallèle (`SHARD_PARALLEL` dans `ci/ci-jobs.cjs`), suites « exclusives » (longues) limitées à 2 au total, budget mémoire par suite (section `memory` des poids, 12 Go en tout), liste triée par poids décroissant.
- Chaque suite a son **budget** (fonction `budget()` de `ci/run-shard-suites.sh`, 180 s par défaut). Jamais relevé pour masquer une régression : seulement après mesure documentée en commentaire.
- Délai du job : 50 min. Journaux groupés par suite, lignes `PASS tests/x.cjs (N s)` et `CD_CPU_PROFILE`, tableau dans le résumé du run.

**Jobs « Godot n/6 »** (SDK Godot 4.7.2 réel).
- Sept jobs depuis le 28/11 (`GODOT_SHARD_COUNT` dans `ci/ci-jobs.cjs`, `node ci/shard-tests.cjs <i> godot 7`), poids de la section `godot` de `ci/suite-weights.json` (remesurés le 28/11 sur 4 batteries).
- Rendu logiciel (Mesa llvmpipe sous xvfb) : **environ 1 image par seconde** en 1920/2560 avant #1355. Toute attente comptée en images est donc piégeuse (voir section 3).
- Exécution par `ci/run-godot-suites.sh` : plafond par suite dans `suite_limits` (300 s par défaut, 600 à 1200 s pour les suites de rendu), SDK obligatoire (une suite qui se saute faute de moteur échoue).
- **Délai de 45 min** pour l'étape des suites (le job a 55 min). Une suite qui perd 600 à 900 s (bloquée, plafond atteint) fait couper le job entier : le rouge d'un shard peut venir d'une autre suite du même shard.
- Les suites marquées `CD_MODES_HERITES` (ancien mode France) ne tournent jamais en CI.
- Les tests Godot lancés en `--headless` (direct-da, temps-forts) sont moins touchés par la lenteur du rendu.

**Branche `resultats-en-ligne`.** Branche orpheline où les workflows « à la demande » et « mesure monde » publient leurs résultats sous `runs/<id_du_run>/` (par exemple `suites.log`). Pratique pour lire un essai en ligne d'une suite précise sans refaire tourner toute la batterie.

**Outil de rejeu** : `tests/ci-shard-replay.cjs` rejoue les durées réelles de huit runs verts (fixtures `tests/fixtures/ci/`) pour comparer des répartitions en shards. C'est une estimation contrefactuelle, pas une mesure. Il vérifie aussi que chaque suite a un poids cohérent avec la mesure : après avoir touché aux poids, relancer `node ci/suite-weights.cjs` comme indiqué dans son message d'échec.

**Commandes utiles** (avec `gh`) : `gh run list --workflow "Tests JavaScript" --branch main --event schedule`, `gh run view <id> --log-failed`, `gh pr checks <n>`, `gh pr update-branch <n>` (relance la CI d'une PR dont « Suites 4/10 » a été rouge pour cause de lois-completes), `gh pr merge <n> --auto --squash`.

## 3. Familles de tests et pièges connus

- **Graine 3 : carton à la 5e minute.** Depuis #1315, la graine 3 prend un carton à la 5e minute ; l'écran d'arrêt met le match en pause jusqu'au choix du manager (voulu). Toute suite qui joue la graine 3 au-delà de la 5e minute doit cliquer « Reprendre » (modèle : #1335, #1345, #1359), sinon elle perd 600 à 900 s et fait couper le job.
- **Essais de pénalité.** Ils valent +7 et n'ont pas de marqueur : un test qui compte les essais par marqueur doit les compter à part (#1360). Depuis #1356, les graines 7 et 1000 n'ont plus d'essai de pénalité : le plan « penalty-try » n'est plus exercé par ces graines.
- **Graines et hasard.** Une carrière sans `CD_GODOT_SEED` tire `Math.random()`. Certains tests dépendent d'une graine fixe et repassent au rouge quand le moteur change ses tirages (liaison-monde, planche-* en graine 3). Fixer une graine n'affaiblit rien, à condition de vérifier le test vert sur plusieurs graines et rouge si on casse la fonction.
- **Chronos.** Ne jamais comparer des temps absolus sur la CI : mesurer au **meilleur de N passes** (portraits : 3 passes, vente-joueurs : 3 mesures), garder le même seuil, ou comparer à **charge égale** (deux mesures dans la même exécution, rapport entre elles).
- **Attentes en images.** Sur un runner à ~1 image/s, une boucle « attendre 10 images » à vitesse ×16 laisse filer le match jusqu'à la mi-temps. Préférer des attentes en temps réel ou sur un état observable (#1358).
- **Rouges en cascade.** Un seul changement de moteur (tirages, durée du match) fait rougir plusieurs suites à la fois, et un shard coupé à 45 min masque ses voisines. Chercher d'abord la PR de moteur fusionnée juste avant le premier rouge (`git log <dernier vert>..<premier rouge>`).
- **Faux verts.** Une suite sautée (SDK absent, mode rapide, liste vide) est verte sans avoir rien contrôlé : lire les lignes `PASS ... (N s)` ; un « PASS 0 s » est un saut. Une PR dont les jobs Godot n'ont pas tourné n'a rien prouvé côté Godot.
- **Relancer pour un chrono : seulement les jobs échoués.** Relancer toute la batterie change la charge des runners et brouille la mesure ; `gh run rerun <id> --failed` suffit, et deux rouges identiques d'affilée sont un signal, un rouge isolé non.
- **Caches.** Portraits (`G.portrait_textures`, `Portrait._textures`) : le test du préchauffage contrôle aussi qu'aucun portrait n'est fabriqué à l'ouverture. La première Composition coûte 110 à 190 ms, dont seulement ~40 ms de portraits (le reste : 61 lignes de candidats).
- **Godot sous Windows.** Le test `godot-analysis-club-graphics` passe `--display-driver x11`, refusé par Godot sous Windows : en local, un fichier `--require` temporaire le remplace par `windows` (ne pas le commiter).

## 4. Rouges connus et à surveiller

- **Chronos des portraits (~250 ms).** Le préchauffage mesure 251 à 256 ms pour un seuil de 250 ms sur certains runs Godot. Seuil inchangé, meilleur de 3 passes déjà en place ; à surveiller, ne pas relever le seuil.
- **Shards lents `presse-rapide-monde` et `world-zones-classement`.** Les délais de ces suites node se frôlent sur les runners lents (`presse-rapide-monde` : budget 420 s). À remesurer sur les prochains runs verts avant toute décision ; aucun budget relevé sans mesure.
- **Autres intermittents rares** (à ne traiter que s'ils reviennent) : `survols-club-courbe-rebours` (l'ancre survolée est libérée pendant l'attente du test), `godot-match-temps-forts` (démarre parfois 0,1 à 2 min avant la coupure de 45 min du job), `deepen-analytics-real-ui`, `godot-equipe-type`, `godot-preparation-ecran`, `godot-centre-cartes`, `godot-phrases-lot10`, `godot-apres-match`, `world-nouvelle-saison-rapide` (lenteur du runner, rien à corriger).
- **`godot-match-temps-forts`** : « Les plans du temps fort se sont succédé » lit le plan juste après une pause ; sur machine lente le temps fort est déjà au dernier plan (course du test, antérieure à #1355, rythme adapté en #1358).
- **`godot-interface-layout`** tourne de nouveau en CI depuis #1357 (mode Monde, 1346 contrôles).

### Rouges après #1351

À diagnostiquer (rouges sur main depuis #1351 « le niveau de chaque joueur compte dans les phases de son poste », run 45983993853 ; reproduits en local sur main) :
- `tests/match-consignes-direct.cjs` sous-test 1 : « rucks=prudente : effet sur la marge trop fort (6.46) ».
- `tests/quota-formation.cjs` sous-test 6 : « rien à signaler quand la marge est confortable » ; le jeu renvoie maintenant une alerte.
À faire : vérifier qu'ils sont verts juste avant #1351, puis trancher jeu faux (corriger le jeu) ou test lisant une situation changée (adapter la situation de départ, mêmes contrôles, mêmes seuils), avec décision tracée.

#1365 (vente-joueurs, meilleur de 3 mesures) : budget CI de la suite porté à 1200 s (538 s en local, 600 s dépassées) ; fusion auto armée, à vérifier.

## 5. Règles de travail

- **Ne jamais affaiblir un test** : mêmes contrôles, mêmes seuils, ni plafond relevé, ni test sauté, ni « attendu rouge ». Un défaut ambigu (défaut du jeu ou choix de design de Léo ?) se classe « à trancher » et on ne touche à rien.
- **Classer chaque rouge** : (a) vrai défaut du jeu : corriger le jeu, le test existant doit passer sans modification (sinon ajouter un test vu rouge sans le correctif) ; (b) test périmé (changement voulu, PR citée) : modification du test seulement avec une **décision tracée de Léo ou du directeur**, citée dans le commit et la PR (« accord de Léo, jj/mm ») ; (c) hasard non figé : poser une graine, vérifier sur plusieurs graines.
- **Une PR courte par famille de tests**, en français, avec cause, correctif et preuve rouge puis vert.
- **Vérificateur GO/NO-GO** : avant d'annoncer « c'est fait », un relecteur indépendant relit le diff, rejoue le test sur le vrai code et rend GO ou NO-GO. Sans GO, pas de fusion automatique.
- **Fusion automatique squash** (`gh pr merge <n> --auto --squash`) une fois la PR prête et le GO obtenu.
- **Branches `claude/...` obligatoires** (sinon le push est refusé) ; travailler dans un worktree dédié créé depuis `origin/main`, jamais dans un checkout sale.
- **Jamais de `git stash`** : le stash est commun à tous les worktrees, ce qui a déjà mélangé des chantiers.
- **Ne pas toucher aux PR ouvertes des autres chantiers.**
- Supprimer son worktree et sa branche une fois la PR fusionnée.

## 6. Décisions encore ouvertes pour Léo

1. **Reprise de partie indécidable** : relance « Continuer » juste après un arrêt en début de semaine, deux programmes d'entraînement au même tirage. Aujourd'hui on garde le programme de la semaine précédente. D'accord ?
2. **Bureau avec un blessé** : la ligne « Blessés » garde sa place et le joueur surveillé se range à droite des pastilles d'alerte. D'accord ?
3. **Match plein écran très chargé** : le banc devient défilable (ses 8 lignes sont gardées). D'accord ?
4. **« Déléguer le match »** : un clic dans le quart de seconde qui suit l'ouverture de l'avant-match est ignoré sans retour (négligeable). D'accord ?
5. **Feuille déléguée après blessure du jour de match (#1363)** : la réparation déplace aussi 3 arrières au lieu de remplacer seulement le blessé. Est-ce voulu ?
6. **Dépendance à la graine** : `match-liaison-monde` repassera au rouge si le moteur change ses tirages ; faut-il le rendre indépendant du moteur de match ?
7. **Politique CI des push de `main`** (#1348) : confirmer que la batterie qui va jusqu'au bout à chaque fusion lui convient.

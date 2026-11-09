# Passation Codex local vers Codex Cloud

État de référence du 9 novembre 2026, heure de Paris. Oval Legacy 27 est le jeu livré par le dépôt `Xynph/cadrage-debordement`. Cette passation distingue le jeu Windows, le web de qualification et l’atelier graphique.

## Points de reprise

| Usage | Branche | HEAD distant vérifié |
| --- | --- | --- |
| Jeu et moteur | `main` | [`e2f111a2330462aa6545866441289346ac92f2d0`](https://github.com/Xynph/cadrage-debordement/commit/e2f111a2330462aa6545866441289346ac92f2d0) |
| Atelier Premium PC | `feature/studio-ui-premium-p2-20261107` | [`3b94e7ce746a317db60ca8604a48bb99e155719f`](https://github.com/Xynph/cadrage-debordement/pull/372) |
| Presse Monde | `feature/presse-titres-monde-20261109` | [`40aeb9cf5cac4705bf2bf2354a00648c96e3fe7a`](https://github.com/Xynph/cadrage-debordement/pull/410) |
| Répartition CI | `fix/ci-repartition-20261109` | [`6a587fc7fce3acc0db750205da47e96c46bc2d74`](https://github.com/Xynph/cadrage-debordement/pull/413) |
| Identités Champ | `fix/champ-aliases-20261109` | [`d61cd3bba3af16352648210c16277f2aa244ceb5`](https://github.com/Xynph/cadrage-debordement/pull/414) |

Les PR #410, #413 et #414 sont sauvegardées en brouillon. #413 a été testée sur l’ancienne base `af62a983377e00998e08c43817523f31148c967a`. Pour la reprendre sur le dernier `main` sans réécrire sa branche, créer une branche de raccordement et y appliquer son commit. #400 et #411 sont les anciennes propositions de menus, reprises par #412. [Coordination de l’équipe](https://github.com/Xynph/cadrage-debordement/issues/73) · [Réception #412](https://github.com/Xynph/cadrage-debordement/pull/412)

## État du produit et preuves

- Windows 0.7.8 installé depuis #412, avec la refonte immersive et les corrections de préparation. **455 contrôles Godot Windows**, **170 fichiers vérifiés** et **74 répliques de Gabi** embarquées. Import Monde et passage en saison 2 reçus. La vérification indépendante de reprise du moteur Windows passe 14 contrôles et retrouve **791 résultats** en deux démarrages. Le profil personnel a gardé son empreinte pendant l’installation.
- Monde + Champ ouvre **114 clubs jouables sur 116**, **neuf ligues** et **deux coupes européennes**. #409 ajoute 25 échéances et ramène à **5 881** les joueurs actifs au démarrage, pour **5 884** identifiants de catalogue. #414 retire trois doublons supplémentaires des nouvelles carrières sur sa branche, ce qui donne 5 878 actifs. Ses quatre tests locaux incluent une réouverture et un réimport sous les deux versions.
- #410 améliore les titres du journal et les barrages. Trois tests ciblés passent sous Node 22 sur sa tête exacte. #413 ajuste les poids de trois suites longues. La revue et le rejeu gardent cinq lots, toutes les suites et les délais d’origine.
- Les branches Studio [#362](https://github.com/Xynph/cadrage-debordement/pull/362), [#369](https://github.com/Xynph/cadrage-debordement/pull/369) et [#372](https://github.com/Xynph/cadrage-debordement/pull/372) forment une pile de démonstrateurs React. #372 est le point de reprise de l’atelier, avec des données de test fictives et sans dépendance au moteur du jeu.

| Contrôle GitHub | Verdict exact relevé |
| --- | --- |
| #409 avant fusion, `417f557f` | [7/7](https://github.com/Xynph/cadrage-debordement/actions/runs/42569342912) |
| #409 post-fusion, `af62a983` | [7/7, deuxième essai](https://github.com/Xynph/cadrage-debordement/actions/runs/42571373469) |
| #412 avant fusion, `9362b9f5` | [7/7, deuxième essai](https://github.com/Xynph/cadrage-debordement/actions/runs/42572996538) |
| #412 post-fusion, `e2f111a2` | [7/7](https://github.com/Xynph/cadrage-debordement/actions/runs/42577802500) |
| #410, `40aeb9cf` | [7/7](https://github.com/Xynph/cadrage-debordement/actions/runs/42578000435) |
| #413, `6a587fc7` | [7/7](https://github.com/Xynph/cadrage-debordement/actions/runs/42576812497) |
| #414, `d61cd3bb` | [7/7](https://github.com/Xynph/cadrage-debordement/actions/runs/42578427374) |
| Studio #362, #369 et #372 | [#362 vert](https://github.com/Xynph/cadrage-debordement/actions/runs/42308870974) · [#369 vert](https://github.com/Xynph/cadrage-debordement/actions/runs/42310894023) · [#372 vert](https://github.com/Xynph/cadrage-debordement/actions/runs/42322263509) |

Sur le clone de recette du HEAD exact, **20 sous-tests Node 22** passent. Sous
Chromium Windows, les quatre campagnes web passent **720 contrôles** sans
erreur, dont Bureau 75, éditorial 315, salle de match 284 et effectif 46. Les
captures 1920 × 1080 et 1440 × 900 sont conservées sur E:. Les trois CI Studio
ci-dessus apportent une preuve Linux distincte.

L’environnement Codex Cloud est déjà configuré en brouillon pour le dépôt.
Son chat de configuration rapporte un parcours Chromium réussi et des tests
du moteur natif réussis sous Linux. La plateforme a refusé l’enregistrement
du brouillon et l’environnement n’est pas lançable au relevé. Une fois
l’enregistrement rétabli, publier l’environnement puis ouvrir un chat de
recette et rejouer les commandes ci-dessous. Le chemin Windows et les
ressources privées ne sont pas requis pour ce contrôle.

## Architecture

| Couche | Fichiers et dossiers |
| --- | --- |
| Web de qualification | `dist/index.html`, `dist/manager.js`, `dist/premium-editorial.js` et ses styles. HTML, CSS et JavaScript statiques sur `main`. |
| Moteur natif | `native/engine/worker.cjs` et protocole JSON local. `world-model.cjs`, `world-editions.cjs`, `world-career.cjs` et `world-validation.cjs` décrivent les éditions et valident les carrières. |
| Client Windows | `native/godot/project.godot`, `native/godot/main.gd`, `native/godot/ui/`, `native/godot/engine_bridge.gd`. Le jeu empaquette Godot et Node pour Windows x64. |
| Identités et import | `native/engine/media-packs.cjs`, `native/godot/pack_manager.gd`, `modding/`, `world-data/`. Le jeu et les tests utilisent le catalogue anonymisé. |
| Atelier Premium | `studio-ui/` sur #372 uniquement. React 19, Vite 7, Tailwind 4, Lucide, Storybook 9 et Playwright, avec `package-lock.json`. |
| Qualification et export | `tests/`, `ci/`, `.github/workflows/`, `scripts/build-godot-prototype.py`. `offline/` documente le lanceur navigateur historique. |

## Reproduire le jeu et les tests dans Cloud

Choisir l’environnement `cadrage-debordement` et monter le dépôt sur `main`. Vérifier le SHA avant d’attribuer un résultat à la version livrée. Utiliser **Node 22** comme la CI et Python 3 pour le serveur et le staging. Le jeu sur `main` se teste sans dépendances npm d’application. [Configuration Codex Cloud](https://learn.chatgpt.com/docs/environments/cloud-environments)

```bash
git rev-parse HEAD
node --version
python3 --version
node --test tests/premium-manager-office.cjs tests/premium-editorial.cjs tests/premium-editorial-matchday.cjs
python3 -m http.server 8000 --bind 127.0.0.1 --directory dist
```

Les commandes ci-dessous reprennent le workflow du Bureau Premium. Installer Chromium dans la phase de configuration si la tâche a des restrictions réseau. En environnement doté d’un Chromium déjà approuvé, utiliser la configuration Playwright de l’environnement et relever le chemin et la version réellement exécutés. Le scénario démarre son propre serveur local et produit des captures 1920 × 1080 et 1440 × 900.

```bash
tool_dir="${TMPDIR:-/tmp}/cd-office-browser"
npm install --prefix "$tool_dir" --no-audit --no-fund playwright@1.58.0
"$tool_dir/node_modules/.bin/playwright" install --with-deps chromium
CD_PLAYWRIGHT_MODULE="$tool_dir/node_modules/playwright" node tests/premium-manager-office-browser.mjs
```

Sortie habituelle `premium-manager-office-report/`. Pour le staging source et un test natif sans fenêtre avec un SDK Godot déjà installé, lancer depuis un checkout de test isolé.

```bash
python3 scripts/build-godot-prototype.py --stage-only --node "$(command -v node)"
CD_GODOT_EXECUTABLE="$(command -v godot)" node tests/godot-native06-integration.cjs
```

Le test Godot ignore le cas si le SDK est absent. Vérifier le nombre de tests ignorés et consigner la plateforme. La recette Linux couvre le moteur et le client selon le scénario lancé. L’export `.exe` livré, son intégrité, le raccourci, les pilotes Windows et le rendu sur le GPU du PC demandent la recette locale. Blender sert à créer ou retoucher des modèles. Le modèle GLB embarqué est versionné, et le build courant le consomme directement.

## Reproduire le Studio UI Premium

Dans un worktree ou une tâche Cloud distincte, choisir la branche #372 et vérifier son HEAD. Le workflow Studio utilise Node 22. Le README de l’atelier demande npm 10 ou supérieur. Le verrou d’origine fixe les versions exactes.

```bash
cd studio-ui
npm ci --no-audit --no-fund
npm run check
npm run build
npm run build-storybook
npx playwright install chromium
npm run test:e2e
npm run dev
# Dans un autre terminal, pour les composants
npm run storybook
```

Playwright déclare `desktop-1920` en 1920 × 1080 et `desktop-1440` en 1440 × 900. Le test démarre Vite sur `127.0.0.1:4173`. Les preuves vont dans `test-results/` et `playwright-report/`. [README du Studio exact](https://github.com/Xynph/cadrage-debordement/blob/3b94e7ce746a317db60ca8604a48bb99e155719f/studio-ui/README.md)

## Ce qui reste sur le PC personnel

Les données de carrière, les clés, le pack Rugby Réel, les sources nominatives et les archives privées restent sur le disque E:. Les caches, les SDK installés, les exécutables et les captures de recette volumineuses sont conservés ou reconstruits sur le PC. Les extraits approuvés de la direction immersive et les données anonymisées utilisés par le build sont versionnés. Les maquettes originales complètes restent locales et servent à des recadrages futurs. Les reproductions Cloud doivent utiliser des fixtures synthétiques et des répertoires jetables.

L’inventaire de reprise a couvert 68 worktrees et 26 dépôts locaux, y compris les copies de recette et de migration. Les fichiers des 20 commits historiques hors des références distantes actives correspondent à des versions déjà publiées. Les variantes de recette et les archives de recherche sont conservées localement. Un inventaire séparé sur E: recense 37 sources et preuves de référence hors du build.

## Alterner entre les deux postes

1. Lire [AGENTS.md](../../AGENTS.md), [DEVELOPPEMENT.md](../../DEVELOPPEMENT.md), le [protocole parallèle](../developpement-parallele.md) et les commentaires récents de [l’issue #73](https://github.com/Xynph/cadrage-debordement/issues/73). Relever la tête distante et la branche réservée. Garder la branche Studio séparée du jeu.
2. Depuis Cloud ou Windows, créer une branche de travail isolée à partir du SHA utile. Avant d’écrire, réserver les chemins dans #73 et signaler les dépendances. Pour un lot repris depuis une autre branche, utiliser une nouvelle branche à nom unique et conserver l’ancienne comme point de retour. Les sauvegardes utilisateur ne participent jamais à cette synchronisation.
3. Exécuter les suites pertinentes, vérifier le diff et ses fichiers sensibles, commiter et pousser normalement la branche. Vérifier son SHA distant avec `git ls-remote origin refs/heads/<branche>`. Ouvrir ou actualiser la PR de cette branche et consigner l’ID de la CI de sa tête exacte.
4. Sur l’autre poste, exécuter `git fetch origin`, vérifier le SHA annoncé et ouvrir un worktree indépendant, par exemple `git worktree add --detach <dossier-de-recette> origin/<branche>`. Pour poursuivre le code, prendre une branche de suivi seulement si sa réservation est libre, ou créer une nouvelle branche. Une divergence se traite sur une branche de raccordement, avec contrôle des patches et des tests.
5. Toute future intégration relève de l’intégrateur unique et du gate officiel. Contrôler la CI après fusion sur le SHA exact. Pour installer une livraison Windows, vérifier l’archive, l’exécutable et le profil sauvegardé avant la bascule locale.

## Ordre de reprise

Terminer la réception des PR #410 et #414, et décider de la place de #413 après vérification de la dernière CI et de la base. Ensuite reprendre les inscriptions EPCR, les contraintes de feuille, les règles saisonnières URC et Pacifique, puis la couverture des contrats et du staff. Dater les règlements et distinguer les mesures vérifiées des estimations. Tester la création, le match, la sauvegarde, sa réouverture et le changement de saison selon l’impact. L’équilibrage des effectifs et des finances à dix saisons reste un lot distinct.

[Premier bilan de réception](https://github.com/Xynph/cadrage-debordement/issues/73#issuecomment-6734628533)

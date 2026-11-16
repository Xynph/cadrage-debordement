# Développer dans le vrai Godot

Le pont local [Fulviuus/godot-mcp](https://github.com/Fulviuus/godot-mcp)
est épinglé dans `pin.json` (MIT, 2.0.2). Le serveur, ses dépendances, son
autoload de débogage et les profils d'essai restent **hors du dépôt public et
du jeu livré**. L'interface est copiée ; le moteur Node est celui de la branche
en cours. Aucun modèle supplémentaire, abonnement ou clé d'API n'est requis.

## Codex et Claude

Prérequis : Node 22 ou plus, npm, Git et Python 3. Le premier chargement clone
le pont épinglé et compile ses dépendances ; prévoir quelques minutes.

Ouvrir le dépôt comme projet de confiance, depuis sa racine. Les fichiers
`.codex/config.toml` et `.mcp.json` déclarent `tools/godot-agent/stdio.cjs`.
Au prochain chargement des connexions MCP, il prépare une copie dans le dossier
temporaire, importe ses ressources et lance le pont. Les journaux de préparation
vont sur stderr ; stdout reste réservé au protocole MCP.

Sur Linux x64, l'archive Godot 4.7.2 est celle de `ci/godot-sdk.json`, vérifiée
par SHA-256. Sur les autres plateformes, définir `CD_GODOT_EXE` vers son SDK
4.7.2. `CD_GODOT_AGENT_WORKDIR` choisit le dossier externe de travail ;
`CD_GODOT_MCP_INSTALL` réutilise une installation du pont à la révision épinglée.
L'installation refuse de remplacer un dépôt contenant des modifications locales.

Une connexion déjà ouverte ne recharge pas automatiquement sa configuration.
Le client HTTP ci-dessous permet aussi d'utiliser le pont depuis la session
courante. Ne pas annoncer une connexion native active sur la seule présence du
fichier de configuration : vérifier la liste des outils puis un appel réel.

## Utilisation directe dans la session courante

Exemple Linux ; remplacer les trois dossiers externes par ses chemins locaux :

```sh
node tools/godot-agent/install.cjs /tmp/rugby-pont
node tools/godot-agent/preview.cjs /tmp/rugby-preview
node tools/godot-agent/serve.cjs /tmp/rugby-pont /tmp/rugby-preview /chemin/vers/Godot
```

Le serveur reste au premier plan sur `127.0.0.1:7878`. Dans un second terminal :

```sh
node tools/godot-agent/mcp.cjs list
node tools/godot-agent/mcp.cjs list godot_run
node tools/godot-agent/mcp.cjs call godot_project_info
node tools/godot-agent/mcp.cjs call godot_run
node tools/godot-agent/mcp.cjs call godot_eval --input tools/godot-agent/examples/monde.json
node tools/godot-agent/mcp.cjs call godot_eval --input tools/godot-agent/examples/etat.json
node tools/godot-agent/mcp.cjs call godot_eval --input tools/godot-agent/examples/bureau.json
node tools/godot-agent/mcp.cjs call godot_eval --input tools/godot-agent/examples/profil.json
node tools/godot-agent/mcp.cjs call godot_screenshot
node tools/godot-agent/mcp.cjs call godot_stop
```

Lire le schéma (`list outil`) pour les paramètres. `--input` lit un JSON ;
`--output` garde la réponse. Pour les captures, passer `output` (chemin PNG
externe) et `embed:false` ; le client n'imprime jamais de base64. Les erreurs
HTTP, JSON-RPC et les erreurs de compilation signalées par le pont donnent un
code de sortie non nul. Une erreur GDScript à l'exécution peut cependant
renvoyer `<null>` : lire aussi `godot_game_logs`, puis contrôler le résultat
attendu. Un appel accepté ne prouve pas que son script a abouti.

Un seul Godot à la fois : arrêter le jeu avant une importation ou une validation
qui lance un autre processus Godot. Pour une capture, utiliser un affichage réel
ou Xvfb et le rendu `gl_compatibility`. `--headless` ne prouve aucun rendu.
Le serveur peut démarrer avant que son pont de jeu soit prêt : vérifier l'arbre
de scène, les erreurs et l'état de la commande avant de conclure.
Après `monde.json`, attendre dans `etat.json` : `waiting:false`, `mode:"world"`,
`connection_error:false` et une erreur vide. Le retour « Création demandée »
ne suffit pas. Le jeu maximise sa fenêtre au démarrage : `resolution` seul
ne garantit pas la taille du viewport ; `examples/vue-compacte.json` permet
de la fixer et de la lire avant une capture.

Les scripts Godot peuvent être rechargés dans la copie ; vérifier leur effet
réel. Les références préchargées peuvent garder une ancienne version : un
redémarrage reste la référence de recette. Les modifications Node demandent
un redémarrage du moteur. Rafraîchir la copie avec `preview.cjs` après avoir
arrêté le jeu ; les profils de test restent dans son dossier `donnees`.

## Rejeu court et recette complète

```sh
node tools/qa/replay-choregraphe.cjs entree-monde.json --output pistes.json
node --test --test-skip-pattern='Moteur natif' tests/match-choregraphe.cjs
node tests/match-choregraphe.cjs
```

Le premier outil conserve le marqueur et les faits du moteur et mesure le coût
du rejeu. Le deuxième sert à itérer sur les contrôles de pistes ; le troisième
garde la preuve de bout en bout dans une carrière Monde. La CI conserve toutes
ses suites et ses bornes. Les producteurs des fixtures de gestes doivent eux
aussi créer une carrière `world-champ`.

La méthode de conception, les scénarios et les preuves à rendre sont dans
[la boucle courte](../../docs/developpement-jeu-boucle-courte.md).

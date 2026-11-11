# Suites ciblées avec un SDK réel

Proposition de contrôle supplémentaire, sans modification des protections ni des
paramètres GitHub. Le job utilise un runner Ubuntu standard du dépôt public,
sans service payant, cache ou stockage d'artefact Actions. Il complète les shards
Node existants ; il ne les remplace pas et n'affirme pas valider les suites qui
ne figurent pas dans sa liste.

`ci/godot-sdk.json` fixe le SDK Linux officiel, sa taille et son SHA256, puis la
liste explicite des suites qualifiées. Le workflow vérifie l'archive, prépare les
assets avec le constructeur officiel et importe le projet. Une erreur de script
ou de ressource à l'import fait échouer le job, même si Godot retourne zéro.

`ci/run-godot-sdk.cjs` refuse un SDK absent ou d'une autre version, les noms de
suite invalides et une liste vide ou dupliquée. Chaque suite ou cas explicite garde une limite
globale de180s, préparation Node comprise. Les quatre scénarios indépendants
du guide peuvent être déclinés sans augmenter cette limite ; une liste de cas
vide ou dupliquée est refusée. Le runner refuse les sorties SKIP,
les erreurs de script et les codes non nuls. Le résumé donne la durée réelle,
sans attente de verrou d'une autre recette locale. Les wrappers conservent leurs
assertions et leurs profils jetables existants. L'import emploie l'audio Dummy ;
les suites de la liste initiale sont exécutées en mode headless. Xvfb et Mesa
permettent aussi de qualifier explicitement les variantes graphiques, sans GPU.
Les recettes vocales ne sont pas ajoutées à la liste : les essais gardent Gabi
silencieux, et activer le SDK sur tous les shards déclencherait des tests de
parole qui ne font pas partie de cette réception.

Le contrôle se déclenche sur les changements de `native`, `dist`, `tests`, `ci`
et du constructeur : omettre `dist` masquerait des changements du moteur utilisé
par le projet stagé. Les actions et le SDK sont épinglés. Les permissions du job
restent en lecture seule ; il ne publie ni paquet ni commentaire.

Commande locale, après staging et import réels :

```sh
CD_GODOT_EXECUTABLE=/chemin/Godot_v4.7.2-stable_linux.x86_64 node ci/run-godot-sdk.cjs
```

Un résultat Linux/headless ne constitue ni une recette graphique Windows ni une
preuve de l'EXE exporté. Les suites non encore fiabilisées restent classées dans
le rapport d'audit ; elles ne sont pas ajoutées à cette liste pour obtenir une
couverture nominale.

Vérifications préalables : archive officielle Linux téléchargée et empreinte
vérifiée, syntaxe Node et YAML contrôlée, absence de SDK refusée en exécution.
Revue indépendante du contrôleur : version incorrecte, SKIP, erreurs, délai et
code non nul provoquent un échec dans les sondes isolées. Le rapport de recette
et la description de PR précisent séparément les suites réellement exécutées.

Le contrôleur a été reçu sur deux vrais parcours : journal351contrôles en53,683s
et textes de Réception en2,044s, code0, sansSKIP. Les autres suites ajoutées
au manifeste portent leurs propres reçus bornés et leurs empreintes dans le
rapport de reprise. Les14tests unitaires du contrôleur n’exécutent pas Godot :
ils isolent les refus (dont les erreurs/SKIP avec couleurs ANSI) et le lancement
de chaque cas explicite. Une erreur ANSI était initialement manquée ; la sonde
rouge puis verte couvre sa normalisation sans modifier le journal brut.

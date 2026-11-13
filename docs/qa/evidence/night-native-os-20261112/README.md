# Reçu natif Linux X11 — Return puis Alt+Left

Source commune figée `37e085b687b4e9a603085beaa50fecf9d6cace22` : **47 contrôles,
zéro échec, sortie 0 observée par root, 43,908 s**. Le probe charge la vraie scène
main et une copie privée du profil public Common 0 précédemment reçu. Les cinq
fichiers produit sont vérifiés par hash contre ce SHA et la copie common.
Les trois fichiers sources sauvegarde/guide sont inchangés ; seuls leurs hashes
et tailles sont publiés, jamais leur contenu.

## Entrées OS et résultat exact

Cua getState a échoué avec « the gaas-browser node_repl sandbox cannot be
disabled ». Le statut brut est conservé dans desktop-control-status.json.
Aucun paramètre de sandbox, navigateur ou bureau n’a été modifié pour ce test.
Le recours alternatif est Linux X11 via les bibliothèques libX11/libXtst déjà
présentes, sur DISPLAY=:91, sous le verrou Godot commun et audio Dummy.

Le Xvfb sans gestionnaire de fenêtres avait initialement le focus PointerRoot
(0x1). Root a explicitement focalisé **le seul Godot observé** (0x600003, titre
Oval Legacy 27 — Rugby Manager DEBUG), puis envoyé Return et Alt_L+Left au focus
X11 courant. L’opération initiale XSetInputFocus est journalisée séparément ;
le helper de touches ne change pas le focus. Ces faits ne sont pas présentés
comme une interaction Cua réussie ou une preuve Windows.

Le témoin Godot observe les événements root-window-input, modal-window-input
et scene-input, avec keycode/physical_keycode/pressed/alt/device. Il ne faut pas
compter leurs observations multiples comme plusieurs touches utilisateur. Le
probe n’injecte aucun événement, n’émet aucun pressed et n’appelle ni commande
métier ni historique privé. Return ouvre `s1-elite-league-0-0`, score 15–20 ;
Alt+Left masque/libère le dialogue et restitue Club/Histoire, la même instance
de score, son focus et son scroll exact. **Le scroll de ce probe vaut 0**, pas
une réception supplémentaire de scroll non nul.

La baseline et l’après sont strictement identiques dans le rapport brut :
profil SHA256, modèle SHA256, seed 425321206, horloge 1794443356698, bridge_next_id 1,
focus/score instance 165423353605 et parole requested 0 / started 0 / id 0. Le guide est
muté précocement dans la copie ; aucune demande ni démarrage de parole observé.
Ce probe ne vérifie pas une synthèse vocale ni les gestes du personnage.

## Trois captures qualifiées

- [Source focalisée avant Return](images/ready-2560.png).
- [Dialogue de la fixture exacte](images/modal-2560.png).
- [Source après Alt+Left](images/returned-2560.png).

PNG natifs 2560×1440 inspectés, sans retouche. Ready et returned ont exactement
le même hash ; ce sont deux phases du même parcours, pas deux couvertures
distinctes. La présentation claire d’archive Common 0 est préexistante.

## Premier essai rouge et diagnostic de harness

Le premier essai donne 47 contrôles/1 échec : seule l’égalité directe de l’Array
JSON `[15.0,20.0]` à l’Array littérale entière `[15,20]` échouait. Les vrais
retours OS et invariants passaient déjà. Le diagnostic isolé consigné dans
diagnostic/array-diagnostic.log reproduit array_equality=false alors que
element_equality=true. Le harness vérifie désormais taille/types numériques
puis éléments exacts ; aucun produit, score ou profil n’est modifié pour cela.
Le rapport rouge et les journaux sont conservés séparément, sans ses PNG.
Le code du probe publié est le script final réellement exécuté ; aucune copie
non conservée du script rouge n’est reconstruite.

Scripts exécutés exacts : scripts/probe.gd, scripts/oskeys.py et diagnostic/
array-diagnostic.gd. Le focus initial est attesté par le journal root ; aucun
script de focus non conservé n’est inventé. La note « Prepared only » de la
provenance brute concerne functional_qa, qui a préparé le probe ; root a ensuite
exécuté la recette et ajouté l’instrumentation/mute et le correctif de harness.
La commande de lancement utilisait --path /workspace/work/night-common/native/godot.

Le manifeste consigne toutes les copies exactes, leurs origines et leurs hashes.
Vérification : `sha256sum --check SHA256SUMS`. Aucun nouveau SDK, import, input
ou lancement de capture n’a été exécuté pour publier ce dossier.

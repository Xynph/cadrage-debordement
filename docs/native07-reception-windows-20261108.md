# Réception Windows — finition PC et voix complète

Le candidat final01 est construit depuis `e7ed132d9a594ff6d19dfc616f1aa662e5904b30`, après réempilement sur le main `f335fb76`. L'arbre de production est identique au commit de finition avant réempilement. La version du programme reste0.6.0.

## Résultat réellement exécuté

**1 450 contrôles, zéro échec**, sortie0, **103 captures** et **120 fichiers vérifiés par empreinte**. L'archive a été décompressée puis exécutée depuis un autre chemin avec espaces et accents, sous Windows, avec PATH limité à System32 et le Node embarqué. Aucun SDK n'est utilisé par l'exécutable. Zéro connexion TCP et zéro processus orphelin observés dans l'arbre du jeu.

Archive `OvalLegacy27-PrototypeGodot-Windows-x64.zip` :187 570 257octets, SHA-256 `554b836d48ea3690d22c3b7fda8497f06b24a9b568e0468bc8c96712fd4129ca`.

La réception couvre les vrais menus aux quatre tailles1280×720,1600×900,1920×1080 et2560×1440 ; plein écran initial, vrais boutons fenêtré/plein écran, navigation, décisions, sons et notes du carnet. Les captures du Bureau, de l'effectif, des classements et du staff à2560 ont été regardées par l'intégrateur. Les sources reçoivent aussi654contrôles de lisibilité sur Node22 et26, avec boutons de dossier entièrement contenus en1080p et minima de lignes conservés.

Les **74 WAV actifs sont tous décodés depuis le PCK exporté**, aucune réplique en attente. La lecture locale d'un vrai fragment est reçue jusqu'à son callback de fin ; le portrait change réellement de pose pendant la parole. Le volume est mis à zéro dans ce seul profil jetable : ce test ne certifie pas une écoute physique exhaustive de l'accent ou du mix. Les38archives historiques restent intactes et les anciens essais Free ne sont pas utilisés comme voix finale.

Les reprises v1/v2, la saison2 commune et neuf domaines de carrière sont contrôlés. Un redémarrage avec le runtime embarqué conserve les octets de la sauvegarde. L'export vers un vrai fichier en lecture seule est refusé visiblement ; destination et profil restent inchangés. Aucune carrière personnelle ni image privée n'entre dans cette recette.

## Démarrage et limites

Le premier worker est créé28 222ms après le lancement Windows dans ce nouveau chemin. La trace situe `main.init` à881ms du compteur Godot, puis le premier modèle à1 439ms : l'essentiel du délai précède ces étapes. La cause de ce délai initial n'est pas démontrée par ces seules mesures. Un autre candidat de diagnostic relancé dans le même chemin atteint son modèle en2 141ms ; ce résultat ne promet pas ce délai pour un premier lancement sur un autre PC. Aucune protection Windows n'a été modifiée.

Les contacts sont une préparation/protection debout suivant la proximité affichée ; plaquages et chutes complets restent absents. Le staff est un annuaire documenté, avec références historiques signalées ; il ne simule pas encore les mouvements complets de personnel. Les estimations initiales de postes/contrats et les abstractions de compétition restent celles de la documentation des données et des règles.

La réussite locale de ce paquet ne vaut pas CI distante ni fusion. Le dernier SHA publié, le gate officiel et les sept jobs post-fusion restent à contrôler avant l'installation utilisateur.

Preuves externes : `E:/Cadrage-Debordement/artefacts/godot-native-qa/native07-candidat-final-01-reception/` (`distribution-proof.json`, `captures/report.json`, `stdout.txt`) ; candidat sous `E:/Cadrage-Debordement/artefacts/native07-candidat-final-01/`.

# Raccordements natifs 0.6 — 8 novembre 2026

Le shell utilise désormais le gestionnaire de sons original et le carnet personnel des lots 4 et 5. Ces raccordements ne changent ni règles sportives, ni moteur, ni format de carrière. Les contrôles et la densité du carnet issus des autres lots sont conservés.

## Son et options

`main.gd` ajoute le gestionnaire sonore à l’arbre avant `setup(self)`, puis charge son profil au premier `meta.dataDir` réellement reçu du worker. Les résultats de ces deux opérations restent consultables (`soundscape_ready`, `sound_profile_loaded`). Une erreur locale est présentée dans les options ou une fenêtre dédiée et dans le statut, séparément d’une décision métier échouée.

La commande et le succès de la réponse sont capturés à l’entrée de `_receive_model`. Après le rendu, le gestionnaire observe le modèle, la route et la visibilité réelle du panneau Match avant tout envoi d’une action mémorisée. Les modèles hors Match et en pause sont aussi consommés. La navigation actualise la visibilité ; les refus confirmés signalent une erreur d’interface. La fermeture dispose le gestionnaire. Le signal de parole de Gabi atténue seulement les lecteurs de stade.

Les paramètres sont organisés en trois sous-onglets, sans défilement global :

- **Confort** : volume global historique, mouvement réduit, caméra, qualité et réinitialisation des préférences d’interface.
- **Son** : deux SpinBox entiers 0–100 pour les sons d’interface et le stade ; 0 coupe réellement le bus correspondant. Une saisie est enregistrée à la confirmation ou à la sortie du champ ; une flèche constitue un changement discret.
- **Affichage** : plein écran, fenêtre 1440×900, packs et aide du coach.

Les deux nouveaux volumes sont atomiquement conservés dans `sound.json`. Ils ne réécrivent pas `interface.json`, ne changent pas Master/Gabi et ne sont pas exportés dans la carrière. Un refus d’écriture restaure la valeur active et la valeur affichée, avec une raison visible. La fenêtre demandée fait 720×540 ; les trois onglets et leurs actions sont contrôlés à 1280×720, 1600×900 et 1920×1080, y compris la fermeture après un refus sonore. Les textes explicatifs statiques utilisent des lignes bornées afin d’éviter le minimum vertical initial excessif des labels auto-enveloppés.

## Carnet

Le bouton `OpenCoachNotebook` est placé dans le feuillet du Bureau. Le bouton `OpenPlayerCoachNote` est dans l’onglet Aperçu du dossier joueur et passe son ID courant au popup. Aucun nouveau chapitre principal n’est ajouté. Les filtres, la pagination et les autres actions du dossier restent en place.

Le refus d’une sauvegarde de note laisse le popup et son brouillon ouverts. Le reçu métier confirme l’enregistrement ; import et nouvelle carrière ferment l’ancien éditeur. Une nouvelle carrière du même club ne récupère aucune note de la précédente. La résolution des identités, les limites Unicode et la transaction de persistance restent celles du domaine carnet existant.

## Réception

Le nouveau témoin `tests/godot-native06-integration.cjs/.gd` lance le vrai shell et son worker sur un profil jetable, sous Godot Windows headless et audio Dummy. Il appelle également la réception 0.6 intégrée à `qa_runner.gd`, afin de recevoir les mêmes boutons et options que l’EXE.

Il vérifie les parcours clavier Bureau/joueur/enregistrement, les cibles par ID, les refus disque réels et réessais, le brouillon à l’import, les trois tailles/onglets, la frappe et la confirmation des volumes, le zéro muet et la relecture des réglages. Les octets de carrière et son curseur RNG, le modèle source, `interface.json`, Master et son mute sont comparés. Une fixture de réaction est produite par le vrai worker natif puis présentée à `_receive_model` pour contrôler la commande `tick` avant l’action mémorisée et la consommation silencieuse hors Match. Ce n’est pas une campagne de match jouée entièrement par le shell.

Les wrappers de lisibilité, disposition et composition copient aussi `audio/` dans leurs projets figés. Aucun contrôle existant n’est supprimé. Les recettes d’affichage choisissent maintenant Affichage avant d’utiliser les véritables boutons plein écran/fenêtré.

La QA embarquée attend désormais les neuf domaines, dont `coachNotebook`. Elle reçoit les six WAV depuis les ressources du PCK dans l’EXE et depuis les sources brutes dans le SDK, les boutons carnet au clavier et les réglages sonores indépendants. Elle conserve les vérifications antérieures de saison 2, imports v1/v2, RNG, export refusé, Gabi et captures.

Commandes ciblées (après chargement de `E:/Cadrage-Debordement/environnement.ps1`, avec `CD_GODOT_EXECUTABLE=CD_GODOT_EXE`) :

```text
node --test --test-concurrency=1 tests/godot-native06-integration.cjs tests/godot-readability06.cjs
node --test --test-concurrency=1 tests/godot-preferences.cjs tests/godot-coach-notes06-app.cjs tests/godot-default-display.cjs
```

Le rapport de sous-lot conserve les résultats et chemins de preuve réels. Ces contrôles headless ne prouvent pas le rendu GPU, le DPI Windows réel, l’écoute physique ou le chargement dans l’EXE exporté. La recette du candidat déplacé reste à exécuter par l’intégrateur ; aucun ancien enregistrement Gabi n’est substitué à un texte réécrit.

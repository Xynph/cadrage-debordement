# Réception Windows native 0.6 — premier candidat

## Périmètre reçu

Le candidat01 a été construit depuis `d7d3b7c7c074b30b33b5efe4b9bd878b4cf1ad36`, puis décompressé et lancé depuis un autre chemin contenant espaces et accents. Le contrôle a réellement utilisé Windows et le binaire exporté, sans SDK ni Node installé dans le PATH. Il n'a utilisé aucun profil personnel.

Résultat : **1 232 contrôles, zéro échec**, 83 captures et 119 empreintes vérifiées. Le processus a quitté avec le code0 ; aucune connexion TCP ni aucun processus orphelin n'a été observé dans l'arbre du jeu. Le chemin du worker correspond au Node embarqué. Un nouveau snapshot après réouverture par ce runtime conserve les octets de la sauvegarde.

Archive : `OvalLegacy27-PrototypeGodot-Windows-x64.zip`, 186 854 423octets, SHA-256 `f3b04891c70643c7c8cbf1e53cd13bc692012dcce000df1bb0fa92449482b9ea`.

## Fonctionnement vérifié

- Plein écran au lancement, puis vrais boutons clavier de passage en fenêtre1440×900 et de retour au plein écran.
- Parcours des menus aux trois tailles1280×720,1600×900 et1920×1080, navigation et présence des commandes.
- Chargement des six sons originaux depuis le PCK, préférences sonores indépendantes, trois onglets des paramètres.
- Notes du coach conservées et adressées par identifiant de contexte ; import, reprise et changement de carrière restent reçus par les scénarios dédiés.
- Reprises des formats historiques v1/v2, saison2, état et RNG ; neuf domaines de carrière contrôlés.
- Refus réel d'un export vers un fichier en lecture seule : destination originale et profil conservés. L'échec reste visible.

Le rapport embarqué confirme `native06.passed=true`, `notes_by_id=true`, `sound_independent=true` et les deux volumes relus36/26. Ce contrôle de chargement et de fonctionnement ne certifie pas une écoute physique du mix avec Gabi.

## Limites et décision de livraison

**Ce candidat n'est pas installé comme nouvelle version personnelle.** La CI398 est encore rouge sur une campagne longue ; la présentation a ensuite été jugée trop peu dense par Léo. Le travail suivant vise le1440p natif, des textes plus petits, un tableau plus dense et une fiche en plusieurs panneaux. Les captures de ce candidat ne prouvent pas cette nouvelle disposition.

Le premier worker a été observé **117 757ms** après la création du processus du jeu. Ce démarrage reste trop long et sa cause n'est pas isolée. Des copies source SDK démarrent rapidement, y compris en plein écran2560×1440 ; elles ne prouvent pas une correction du binaire exporté. Aucune modification des protections Windows n'a été faite.

La nouvelle voix finale n'est pas complète :15 anciens clips textuellement exacts restent actifs,59 fragments attendent leur enregistrement. Les essais privés ElevenLabs ne figurent pas dans cette distribution de base. Le pack privé et les données personnelles sont restés hors de la distribution et hors des profils de recette.

Les preuves locales sont conservées sous `E:/Cadrage-Debordement/artefacts/godot-native-qa/native06-candidat01-reception/`, dont `distribution-proof.json` et `captures/report.json`. Le lot suivant devra recevoir son propre candidat, sa CI exacte et sa validation après fusion.

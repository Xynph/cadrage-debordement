# Emplacement de GodotSteam (vide pour l'instant)

Ce dossier accueillera l'extension GodotSteam (GDExtension pour Godot 4.7, licence MIT)
qui donne accès au SDK Steamworks : succès et sauvegardes cloud.

Rien n'est installé tant que Léo n'a pas créé l'application Steam. Ensuite :

1. télécharger la version GDExtension de GodotSteam correspondant à Godot 4.7 et la
   copier ici (`godotsteam.gdextension` + `win64/`) ; ajouter sa licence à `docs/ressources-utiles.md` ;
2. renseigner `app_id` et passer `enabled` à `true` dans `res://steam/steam.json` ;
3. reconstruire avec `scripts/build-steam.py`, qui vérifie la cohérence avant de produire le dossier Steam.

Tant que ce dossier ne contient que ce fichier, le jeu ne charge aucune bibliothèque Steam.
Le SDK Steamworks lui-même (`steam_api64.dll`, licence Valve) n'est jamais versionné dans ce dépôt public.

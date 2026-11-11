# Réception dense : décisions et lecture — 10 novembre 2026

Base `272bd7f`, objectif 2560 × 1440. Le courrier existant reste la source : aucune décision sportive, échéance ou personne n'est créée par cette vue.

## En jeu

- **À faire** : conférences réellement disponibles, choix de préparation du calendrier encore en attente et rencontre internationale courante. Une urgence n'est affichée que pour une conférence requise ou le match courant.
- **En attente** : une invitation doit correspondre à la conférence actuelle, avec une indisponibilité et un motif explicites. Les états incomplets restent des informations.
- **Informations** : courriers sans décision encore vérifiable. Les dossiers Non lus, Favoris et Archives restent disponibles.
- Les messages d'une même rencontre, édition hôte ou conférence sont regroupés. Les éditions différentes restent séparées. Le groupe indique son sujet et sa saison/semaine quand elles sont fournies ; Entrée permet de le réduire ou de le déplier.
- Le graphique par sujet indique les vrais nombres de courriers du dossier actif. Cliquer une barre filtre sa catégorie, y compris Formation et Club.
- Le contexte présente la prochaine rencontre publiée et les courriers connexes. Sur un ancien courrier d'expiration, les portraits concernent explicitement **les échéances actuelles** de l'effectif. Un portrait ouvre le joueur par son identifiant ; l'infobulle conserve la provenance de l'image fournie par le pack ou de l'illustration fictive de base.
- L'ouverture d'une fiche ou de la conférence mémorise le courrier et le défilement. Le retour retrouve la même sélection, le même filtre et le focus. Les flèches haut/bas et Début/Fin parcourent les messages sans commande sportive.

La présentation est dense : lignes sur deux niveaux de 62 px, corps de 17–18 px, données de 18–20 px et titres de 22–28 px. La hauteur du texte détaillé suit son contenu ; les photos existantes sont recadrées et le contexte occupe l'espace disponible avec de vraies données.

## Vérifications observées

- Nouveau banc : **38 contrôles sans échec**, avec une carrière créée par le vrai moteur, filtres au clavier, aller-retour presse, ouverture d'un joueur par portrait, retour au courrier et groupe dépliable.
- Recette internationale existante : **34 contrôles sans échec**.
- L'empreinte du profil sportif et le compteur de commandes restent inchangés pendant le parcours de lecture.
- Les quatre captures du banc graphique portent sur une vraie carrière : Réception, décision de presse, informations, échéances et portraits. Le petit scénario de deux avis liés est une fixture UI déclarée, ajoutée après les captures et retirée avant la fin du test.

Node 22.23.4 et Godot 4.7.2, cache privé, profil jetable dans le dossier temporaire système. La réception graphique du cumul est centralisée par l'intégrateur ; ces résultats locaux ne constituent pas une validation Windows.

```sh
CD_GODOT_EXECUTABLE=/chemin/Godot node --test tests/godot-reception-decisions.cjs
```

Pour les captures sur un écran X11 2560 × 1440, ajouter `CD_RECEPTION_DECISIONS_GRAPHICS=1`, `CD_RECEPTION_DECISIONS_OUTPUT=/tmp/preuves-reception`, `DISPLAY=:99`, `LIBGL_ALWAYS_SOFTWARE=1` et `LP_NUM_THREADS=2`.

## Raccordement

Fichiers produit : `reception_canvas.gd` et `reception_reading.gd`. Les champs de lecture sont locaux à `management_ui.reception`. L'intégrateur réinitialise également `activity_filter`, `expanded_threads` et `return_focus` dans `_reset_reception` pour qu'un filtre ne masque pas un nouveau courrier prioritaire lors d'un changement de carrière.

Aucun moteur, règle, format de sauvegarde, élément financier ou stock n'est modifié par ce lot. La navigation et les commandes de calendrier/presse existantes gardent leurs conditions et leur confirmation explicite.

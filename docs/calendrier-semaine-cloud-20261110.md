# Calendrier de travail : semaine, mois et filtres

Lot 2 Cloud du 10 novembre 2026, base de réception `272bd7f` (#510).
[PR #517](https://github.com/Xynph/cadrage-debordement/pull/517), en brouillon.

## En jeu

Le calendrier reste raccordé à la route **Calendrier**. Les vues Mois et Semaine
partagent les mêmes dates publiées et le même programme du jour. La vue Semaine
montre sept jours de lundi à dimanche, même lorsqu’ils chevauchent une année.
Les boutons précédent/suivant avancent d’un mois ou d’exactement sept jours selon
la vue. Les flèches du clavier sélectionnent ±1 jour ou ±7 jours.

Cinq filtres de lecture sont disponibles : Tout, Matchs, Entraînements,
Absences/retours et Matchs à l’extérieur. La vue et le filtre restent en mémoire
pendant la session ; le jour sélectionné est repris tant que la date simulée ne
change pas. Après consultation de l’entraînement, le calendrier retrouve sa vue,
sa sélection et le focus sur l’action utilisée. Les boutons de jour et de filtre
conservent également leur focus après reconstruction.

Les absences viennent uniquement des convocations confirmées des joueurs du club.
La période `from`–`through` est inclusive et le retour est affiché exactement à
`returnDate`. Les retours déjà publiés restent visibles même lorsqu’une nouvelle
convocation concerne le même joueur. Les anciennes projections sans disponibilité
internationale restent acceptées. Les fenêtres futures sans liste de joueurs ne
créent pas de fausses absences.

« Match à l’extérieur » désigne la rencontre à sa date publiée : aucune date,
durée ou heure de voyage distincte n’est inventée. Le programme peut ouvrir la
préparation du prochain match, l’entraînement courant ou les disponibilités en
sélection. Les séances et les semaines types existantes restent celles du moteur.
Le filtre ne modifie ni leurs dates ni leur contenu.

## Densité de lecture à 2560×1440

Le bandeau utilise un titre de 28 px et une hauteur de 106 px. Les lignes et
repères sont compris entre 16 et 20 px. Les cellules du mois sont compactes
(96–110 px minimum), les journées de la semaine partent de 210 px et s’agrandissent
si leurs événements l’exigent. Les ateliers avants/trois-quarts sont détaillés dans
le programme du jour et dans l’infobulle complète plutôt que répétés partout.

Sous la grille, des panneaux donnent des informations réelles :

- Les trois prochains rendez-vous publiés dans le mois, ou cinq dans la semaine,
  avec date, adversaire, lieu et accès direct au jour.
- Un histogramme des sept jours de la semaine sélectionnée. Chaque barre compte
  exactement les créneaux de séance publiés ; un zéro reste zéro. Aucun effort,
  minute d’exercice ou charge physique n’est estimé à partir de ce comptage.

La vue Semaine ajoute une table de préparation : date, type de séance, ateliers
avants et trois-quarts réellement publiés. Ses lignes de 34 px exploitent la
hauteur disponible ; un tiret signifie que le détail n’est pas précisé dans la
séance source. Ce contexte reste visible indépendamment du filtre de la grille.

Un jour de semaine sans événement correspondant au filtre indique le prochain
match connu plutôt qu’un remplissage décoratif. La photo de stade déjà livrée
reste un fond discret du bandeau, sans remplacer les données.

## Réception locale

Node 22.23.4, Godot 4.7.2 Linux : **50 contrôles sans fenêtre réussis**, aucun ignoré
et aucune erreur de script. Le banc crée une vraie carrière, consulte le
calendrier à 2560×1440, teste le clavier et la restauration de focus, et vérifie
les sept valeurs du graphique contre les séances sources.

Il distingue des cas UI contrôlés d’absences/retours, les semaines à la jonction
d’année, les doublons de rencontre, une nouvelle convocation après un retour,
et les mandats sans club. Les données de ces cas ne sont pas écrites dans la
carrière. Les consultations et filtres n’envoient aucun ordre au moteur ; les
séances et l’empreinte du profil sportif restent identiques.

[Rapport headless conservé](calendrier-semaine-cloud-20261110-report.json).
La même version produit réussit **60 contrôles en rendu X11**, exclusivement en
2560×1440, avec cinq captures aux dimensions vérifiées. Le serveur privé :94 a
été arrêté après réception. Aucune capture du bureau partagé n’a été utilisée.

Captures inspectées : [mois dense](calendrier-semaine-cloud-20261110/calendrier-mois-1440.png)
et [semaine détaillée](calendrier-semaine-cloud-20261110/calendrier-semaine-1440.png).
[Rapport graphique](calendrier-semaine-cloud-20261110/report.json) et
[empreintes](calendrier-semaine-cloud-20261110/sha256.json).
Les suites `calendar-planning.cjs`, `calendar-worker.cjs` et `calendar-mail.cjs`
passent aussi : **7 tests Node réussis**, dont création/import/reprise des séances
et semaines types déjà en place. Aucun calcul de compétition ou règlement changé.

```sh
CD_GODOT_EXECUTABLE=/chemin/vers/Godot node --test tests/godot-calendar-agenda.cjs
```

Pour la réception graphique, ajouter `CD_CALENDAR_AGENDA_GRAPHICS=1` et
`CD_CALENDAR_AGENDA_OUTPUT=/tmp/oval-calendar-1440`. Le banc enregistre cinq captures
natives 2560×1440 : mois, semaine, absences, retours et matchs extérieurs.
Les profils sont jetables dans un autre dossier temporaire, hors de l’application.
Les cinq captures locales sont conservées dans le dossier de recette ; les
captures finales du cumul restent centralisées par l’intégrateur.

## Périmètre et reprise

Seuls `month_calendar.gd`, le module dédié `calendar_agenda.gd`, les deux fichiers
de test et cette documentation sont modifiés. Aucun moteur, format de sauvegarde,
état global de gestion, écran de préparation ou interface de fatigue n’est changé.

Prochaine action : intégrer le lot puis recevoir les cinq captures sur la branche
cumulative et inspecter les autres parcours raccordés au calendrier. Aucune recette
Windows, CI distante verte ou fusion n’est revendiquée dans ce lot.

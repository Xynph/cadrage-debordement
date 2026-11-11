# Entités consultables — tranche Cloud du 11 novembre 2026

Base de travail : `6648cd6338e1eb62cc4a8c014b23dd3ec20ba174`.
Réservation de coordination : brouillon #576. Cette tranche ne fusionne rien.

## Inventaire des points de lecture

| Information | État observé avant cette tranche | Destination de cette tranche |
| --- | --- | --- |
| Joueur de l’effectif | Ligne sélectionnable, dossier compact et bouton `OpenPlayerFull` existants | Nom et portrait ouvrent la fiche complète par ID ; les autres colonnes gardent la sélection compacte. |
| Salaire ou échéance dans l’effectif | Valeurs statiques de la ligne | Fiche complète du même joueur, onglet Contrat (`section: contract`). |
| Drapeau du joueur, origine et sélection XV | Deux drapeaux distincts, visuels | Sélection correspondante par le `flagCode` de l’équipe projetée, sans remplacer la nation gérée. |
| Sélections | Route surtout centrée sur la nation gérée | Répertoire consultable et dossier nation ciblé : rencontres, classement et convocations déjà projetés. Aucun poste ni feuille de match dans ce dossier. |
| Staff | Annuaire ; actions de carrière/contrat existantes mais pas de fiche de consultation | Nom et portrait ouvrent un profil de lecture précis par ID ; rôle, club, contrat et parcours déjà projetés. |
| Recherche du staff | Texte, page et défilement locaux perdus à la reconstruction | État de session `management_ui.staff` : recherche, onglet, page et défilement conservés. |
| Joueur de composition ou du banc | Composants de composition réservés à #574 | Pas de modification concurrente. |
| Club et rencontre | Détails déjà disponibles dans CompetitionCanvas | Périmètre de l’agent liens du monde, réutilisé par le contrôleur commun. |
| Rapport médical et fatigue | Écrans existants | Périmètre de l’intégrateur, pas de modification dans cette tranche. |

## Contextes où aucune destination n’est disponible

Une carrière qui n’expose pas `model.international.teams` ne permet pas de
résoudre une sélection depuis un drapeau. Le visuel existant est conservé sans
lien. Aucune équipe n’est déduite d’un nom traduit ni chargée hors projection.
Le test France → France doit donc utiliser une carrière dont la projection
internationale est disponible (par exemple le monde international), et gérer
une autre nation pour distinguer le ciblage du mandat sportif.

Les joueurs de convocations qui ne figurent ni dans l’effectif ni dans le
marché projetés restent du texte : cette tranche ne crée pas de fiche avec des
attributs adverses non connus. Les identifiants absents d’une projection sont
refusés sans préparation de cible.

## Contrats communs

- Liens : `app.navigation_controller.open_entity({kind, id, section?})` ; les gardes et l’historique appartiennent au contrôleur commun.
- Nations : `InternationalView.open_target(app, id)` prépare seulement `management_ui.international.navigation_id` ; `target_available` est une validation pure.
- Staff : `StaffView.open_target(app, id)` prépare seulement `management_ui.staff.navigation_id` ; `target_available` est une validation pure.
- Aucun de ces points d’entrée n’appelle le bridge, une candidature, un recrutement ou une prise de poste.
- Les fiches se rendent dans le corps existant ; aucune nouvelle fenêtre n’est ajoutée.

## Vérifications

`tests/godot-entity-projections.gd` et son lanceur Node vérifient les destinations
exactes, la résolution par ID projeté, les refus, la disponibilité clavier du
drapeau, l’absence de commandes et l’égalité de la projection avant/après.
Ce test isolé ne prouve pas à lui seul la pureté des sauvegardes/RNG du worker,
les gardes de scène obligatoire, la géométrie ni le retour arrière complet.
Ces points appartiennent à la recette commune sur le candidat intégré.

Résultats et SHA de réception sont ajoutés après exécution, sans substituer
cette vérification ciblée à une campagne globale ni à une recette Windows.

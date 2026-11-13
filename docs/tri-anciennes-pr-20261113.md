# Tri des anciennes PR ouvertes (10 et 11 novembre) — 13 novembre 2026

Léo a validé (13/11, 15h23) le tri des 46 PR ouvertes restées des 10 et 11 novembre : fermer celles qui sont déjà faites ou dépassées, recréer proprement sur `main` celles qui restent utiles. Une PR fermée est rouvrable ; **aucune branche n'a été supprimée**.

PR concernées : #472 à #504 (« Oval Legacy », 10/11), #545 à #548 (Claude), #556 à #569 (Codex Cloud, 11/11). Les PR plus récentes (#625 et suivantes) n'ont pas été touchées.

## Méthode

1. Pour chaque PR : description et diff lus (API REST). Les lignes ajoutées de chaque fichier ont été comparées à `origin/main` (même contenu, même sous une autre forme), puis les écarts relus à la main : code déplacé, réécrit, supprimé (mode France retiré par #637) ou remplacé.
2. **FAIT** : même effet déjà sur `main`. **DÉPASSÉ** : remplacé, réécrit ou sans objet. **UTILE** : encore à faire ; reprise en PR propre, adaptée au mode Monde.
3. Les PR FAIT / DÉPASSÉ sont fermées avec un commentaire ; les PR UTILE sont fermées avec un renvoi vers la reprise.

## Résultat : 38 FAIT, 4 DÉPASSÉ, 4 UTILE

Le constat est net : presque tout l'ancien lot est déjà passé dans `main` (par #539, #572 et les lots suivants), souvent sous une autre forme.

| PR | Titre | Catégorie | Raison | Reprise |
| --- | --- | --- | --- | --- |
| #472 | Oval Legacy — exporter les carrières Champ longues | FAIT | L’export des carrières longues (version 2 compacte, secours, plafond) est dans dist/saves.js ; tests/champ-portable-save.cjs existe et couvre aussi la version 3. | — |
| #473 | Afficher les mêlées non disputées dans les statistiques du match | FAIT | Les mêlées non disputées sont comptées dans native/engine/model.cjs ; tests/native-stats-melees.cjs présent. | — |
| #474 | Attendre des observations avant de conseiller un changement en match | FAIT | L’attente d’observations avant conseil est dans dist/match-v61-advisor.js et decision_views.gd ; tests/v61-match-advisor.cjs présent. | — |
| #475 | Expliquer le verrou des semaines types pendant le match | FAIT | Le verrou des semaines types pendant le match est expliqué dans month_calendar.gd (lignes identiques sur main). | — |
| #476 | Chiffrer les renforts avant de compléter la feuille | FAIT | Le devis de renfort avant de compléter la feuille existe (gestion.cjs, model.cjs, lineup_cover.gd), déjà adapté au salaire plancher du budget. | — |
| #477 | Identifier les équipes et le score du dernier débrief | FAIT | Équipes et score du dernier débrief identifiés dans decisions.cjs et decision_views.gd (lignes identiques). | — |
| #478 | Afficher les candidats autorisés en tête de composition | FAIT | Candidats autorisés en tête de composition présents dans squad_views.gd (17/17 lignes). | — |
| #479 | Retrouver la contre-offre et le retrait dans les contrats | FAIT | Le rappel de la contre-offre vit dans ui/contract_negotiation.gd (ContractCurrentNegotiation) ; l’écran de négociation a été refait depuis. | — |
| #480 | Diriger le Bureau vers le classement à la clôture | FAIT | « Consulter le classement final » est dans immersive08/office_priorities.gd (le Bureau a été restructuré). | — |
| #481 | Ouvrir le suivi individuel depuis la fiche joueur | FAIT | Suivi individuel ouvert depuis la fiche joueur : academy_canvas.gd, player_canvas.gd, squad_views.gd identiques. | — |
| #482 | Adapter le Bureau au match en cours et au résultat | FAIT | Bureau adapté au match en cours (office.gd, office_canvas.gd, projection.gd : 84/88 lignes, le reste reformulé). | — |
| #483 | Afficher les propositions possibles sur le marché entre clubs | FAIT | Disponibilité des propositions du marché entre clubs présente dans interclub_market_view.gd (13/13). | — |
| #484 | Focaliser Annuler dans le formulaire des offres de contrat | FAIT | Le focus sur Annuler existe : confirm(..., focus_cancel) dans main.gd et grab_focus dans contract_negotiation.gd. | — |
| #485 | Indiquer quand la séance peut compléter la feuille | FAIT | Indication « la séance peut compléter la feuille » présente (lineup_cover.gd, model.cjs). | — |
| #486 | Afficher le modèle de semaine déjà en place | FAIT | Modèle de semaine en place affiché : calendar-planning.cjs, month_calendar.gd et test identiques. | — |
| #487 | Garder la frise du Bureau sur les rencontres à venir | FAIT | Frise du Bureau sur les rencontres à venir présente (office.gd, office_canvas.gd). | — |
| #488 | Annuler par défaut avant de remplacer une carrière | FAIT | Annuler par défaut avant de remplacer une carrière : paramètre focus_cancel utilisé par l’import (main.gd) et « Une nouvelle histoire » (entry_screens.gd). | — |
| #489 | Ancrer la recette de création sur son identifiant stable | FAIT | Recette de création ancrée sur l’identifiant stable : lignes identiques dans tests/godot-review-regressions.gd. | — |
| #490 | Préserver les face-à-face des carrières mondiales longues | FAIT | Face-à-face des carrières mondiales longues et validation de sauvegarde présents (dist/saves.js, tests/native-save-hotpaths06.cjs, tests/world-native-domains.cjs). | — |
| #491 | Nommer le prochain adversaire en semaine exempte | FAIT | Prochain adversaire en semaine exempte : UpcomingOpponent / UpcomingWhen dans office.gd et competition_canvas.gd. | — |
| #492 | Afficher le verrou de la séance dans le panneau d’entraînement | FAIT | Verrou de la séance dans le panneau d’entraînement présent (training_canvas.gd, 9/9). | — |
| #493 | Afficher le contexte du direct dans les consignes | FAIT | Contexte du direct dans les consignes présent (preparation_match_context.gd, 38/38). | — |
| #494 | Entraînement : afficher le motif de vigilance physique | FAIT | Motif de vigilance physique fourni par management_state.watch_reason (entraînement reformulé). | — |
| #495 | Nommer le premier adversaire pendant la préparation anglaise | FAIT | Premier adversaire nommé pendant la préparation : office.gd, competition_canvas.gd, office_canvas.gd. | — |
| #496 | Accéder directement à une saison archivée | FAIT | Accès direct à une saison archivée présent dans club_views.gd (24/24). | — |
| #497 | Afficher les noms et logos de championnat au choix du club | FAIT | Noms et logos de championnat au choix du club : entry_screens.gd et tests world-native-ui identiques. | — |
| #498 | Montrer une transformation pendant les actions longues | DÉPASSÉ | L’indication d’attente a été réécrite (command_wait_overlay.gd actuel, panneau de chargement au-delà de 0,5 s, tests godot-chargement*) ; cette version divergerait. | — |
| #499 | Ouvrir le calendrier depuis la date du bandeau | FAIT | Calendrier ouvert depuis la date du bandeau : main.gd et shell.gd identiques. | — |
| #500 | Afficher les 36 attributs sur toutes les fiches joueur | FAIT | Les 36 attributs sont affichés sur les fiches (player-attributes.cjs, player_attributes.gd, player_canvas.gd, squad_views.gd) avec tests. | — |
| #501 | Distinguer les créneaux passés dans le calendrier | FAIT | Créneaux passés distingués dans month_calendar.gd (« Créneau passé », couleurs de créneau passé). | — |
| #502 | Oval Legacy - 40 professionnels par club | UTILE (partiel) | 40 professionnels par club déjà sur main (professional-depth.cjs, tests). Reste utile : indiquer qu’un joueur « depth- » est généré pour compléter l’effectif, absent de l’interface actuelle. | #667 |
| #503 | Oval Legacy - potentiels des jeunes de formation | FAIT | Potentiels des jeunes : academyPotential de dist/development.js garde les plafonds > 90 comme exception rare ; la formation a été refaite depuis (centre par club). | — |
| #504 | Oval Legacy - parcours quotidien, presse et barème senior | FAIT | Sa tête est ancêtre de main : tout son contenu est intégré. | — |
| #545 | Match : rendu Forward+, éclairage filmique et caméra de retransmission | DÉPASSÉ | Le rendu moderne du match est intégré autrement : module opt-in native/godot/match_rendu.gd (Forward+ seulement, gl_compatibility par défaut) et tests godot-match-rendu*. Cette PR changeait le moteur par défaut et la caméra TV ; conflits sur match_view.gd. | — |
| #546 | Renommer le jeu en Rugby Legacy 27 sans déplacer les carrières | UTILE | Le nom affiché reste « Oval Legacy 27 » (titre de fenêtre, accueil, crédits, bulle du logo, stade, packs, export). Repris en texte seulement ; le logo est une image, signalé. | #666 |
| #547 | Ajouter un kit épinglé de compétences Godot pour les agents | UTILE | Le kit de 14 compétences Godot épinglées n’est pas sur main ; fichiers nouveaux, sans collision. | #665 |
| #548 | Proposer la direction des menus et le plan d'un thème Godot unique | DÉPASSÉ | Document de direction artistique seul (maquettes) : la direction des menus est traitée par la graphiste dans la conversation graphisme ; le plan visait un état de l’interface qui a changé (Bureau, Effectif, Composition refaits). | — |
| #556 | Réception des candidats Claude et suivi autonome après main96 | DÉPASSÉ | 103 fichiers de rapports de réception de candidats Claude (#552 à #573) tous fusionnés ou fermés ; l’intégration finale est #572. Aucune production. | — |
| #557 | CI : sélectionner les régressions de touche avec match2d (dépend de #555) | UTILE | dist/match2d.js ne sélectionne pas encore les régressions d’alignement (lineout-side, -geometry, -approach) ; #555, dont elle dépendait, est fusionnée. | #664 |
| #559 | Tests Godot : installer les préchargements des neuf fixtures isolées | FAIT | Les neuf fixtures Godot préchargent le helper : lignes identiques sur main (#572). Le dixième test (godot-competition-editor) a été supprimé avec les anciens modes. | — |
| #561 | Tests Godot : recevoir les interfaces actuelles et garder le guide silencieux | FAIT | Recettes Godot actualisées présentes sur main ; godot-competition-editor supprimé avec les anciens modes. | — |
| #564 | SDK : vérifier le tri des intervalles de potentiel publiés | FAIT | Tri des intervalles de potentiel : tests/godot-squad-column-sort.gd identique sur main. | — |
| #565 | Petites fenêtres : contenir les pages et dialogues avec preuves géométriques | FAIT | Petites fenêtres : les six composants (director, dialogs, month_calendar, office, profile_safety_view, contract_negotiation) et tests/small-window-* sont déjà sur main via #572, preuves comprises. Rien à recréer. | — |
| #567 | SDK : recevoir les vrais portraits U18 et U21 après éviction du cache | FAIT | Recette des portraits U18/U21 et sa preuve JSON sont sur main (#572). | — |
| #568 | SDK : recevoir les portraits avec niveaux inconnus et piste Bureau vide | FAIT | Recette de continuité des portraits et sa preuve JSON sont sur main (#572). | — |
| #569 | SDK : négocier après les rendez-vous avec les vrais montants hebdomadaires | FAIT | Recette de négociation après rendez-vous et sa preuve JSON sont sur main (#572). | — |

## Nouvelles PR (brouillons prêts, rien n'est fusionné)

| PR | Thème | Reprend |
| --- | --- | --- |
| #664 | CI : sélection des régressions d'alignement, avec ce document | #557 |
| #665 | Outils agents : kit épinglé de compétences Godot | #547 |
| #666 | Renommage en Rugby Legacy 27 (textes) | #546 |
| #667 | Effectif : joueurs générés pour compléter l'effectif | #502 (partie utile) |

## Limites

- Le classement FAIT repose sur la comparaison des lignes ajoutées et sur une lecture des écarts ; il n'a pas été rejoué par l'exécution de chaque ancienne recette sur `main`.
- Le logo est une image : sa version « Rugby Legacy 27 » reste à produire par la direction artistique (voir #666).
- L'exécutable `OvalLegacy27.exe` et l'archive gardent leur nom : la chaîne Windows (`ci/`) l'attend ; à faire avec une recette Windows.
- #546 (logo provisoire), #545 (caméra TV sur rail, AgX) et #548 (maquettes) restent consultables sur leurs branches, conservées.

- Environnement de test Linux (Godot 4.7.2 headless) : `godot-immersive08` échoue à l'identique sur `main` et sur les branches de reprise (16 contrôles de l'Effectif et du direct) ; `godot-pack-ui` dépasse son délai ici. Les suites ciblées de chaque reprise sont vertes (voir leurs descriptions).

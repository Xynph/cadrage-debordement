# Lot Cloud de nuit — 11–12 novembre 2026

Objectif autorisé : terminer la réception de #572 puis améliorer les liens de consultation et la lisibilité de gestion. Arrêt propre le 12 novembre à 08 h 30 Europe/Paris.

Aucune fusion Cloud avant le 12 novembre à 09 h 00 Europe/Paris. Cette branche reste en brouillon. Aucun ZIP ni essai Windows : livraison et recette PC réservées à Claude.

Base : correctif Art `6648cd6338e1eb62cc4a8c014b23dd3ec20ba174`, descendant du candidat #572 `7b23f7af01938928b0e29f1a4676486421e89bbc`. Main observé au départ : `9c2ea18c87085ba8241b2527398f3c8482ea63af`.

## Réservation des fichiers

| Agent | Worktree | Périmètre exclusif |
| --- | --- | --- |
| Intégrateur | night-common | Assemblage, descriptions PR et coordination |
| CI | ci-closeout | QA Art, reçu ciblé et docs/qa/night-ci-20261111.md |
| Navigation | navigation-core | navigation_controller.gd, management_state.gd, main.gd (navigation), composant de lien commun et tests dédiés |
| Entités | entity-links | Liens UI joueurs, staff, sélections ; aucun composant commun |
| Monde | world-links | Liens UI CompetitionCanvas, calendrier, finances et courrier ; aucun moteur |
| Gestion | management-quality | Scénarios comparatifs, explication des conséquences ; fichiers UI précis à réserver avant écriture |
| Recette | functional-qa | Nouveaux tests et preuves, aucun fichier produit |

Les collisions UI sont arbitrées avant modification. Les agents ne publient pas de PR ni de branche eux-mêmes. Un verrou flock `/workspace/work/rg27-godot.lock` sérialise les processus Godot lourds. Audio Dummy et aucun déclenchement TTS.

## Réservations préservées

Aucune modification concurrente des moteurs, données, économie, calendriers, animations et 3D des lots Claude #550, #549, #553, #574, #571, #560, #575, #573 et #552. Les interfaces intégrées sont consultées avant raccordement. Mixamo et conversions exclus des publications. Gabi reste silencieux et conserve sa tenue. Aucune nouvelle direction artistique, configuration GitHub ou dépense.

## Réception

Ce document réserve le lot ; il ne constitue aucune preuve de test. Les SHA, résultats, captures et limites seront consignés après exécution. Une reprise ciblée verte ne vaut pas campagne globale verte. Les PR familiales restent ouvertes jusqu’à intégration et réception réelles.

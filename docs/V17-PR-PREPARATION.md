# V17 - lot PC consultatif pour integration native

Branche producteur issue de main 4fe1d8b6d5737b6ec343e726546a354ea8d24694. Six fichiers dans la livraison, aucune modification de la CI.

## Fichiers principaux
- dist/v17-v10-engine.js : calculs descriptifs sur calendrier (8 matchs), staff, scenario, objectifs individuels et tendances.
- dist/v17-unified-pc.js : bureau PC unifie en huit panneaux, lecture seule.
- dist/v17-unified-pc.css : styles PC uniquement.
- tests/v17-unified-pc.test.cjs : 5 tests Node cibles.

## Integration native restant a realiser
1. Charger d'abord v17-v10-engine.js, puis v17-unified-pc.js et la feuille CSS depuis dist/index.html, sans ajouter une deuxieme navigation manager.
2. Monter un conteneur v17-workspace dans le bureau existant, avec snapshot() sur S et club().players. Ne pas recopier les données de carriere.
3. Utiliser les sorties reelles de physicalLoadValue(), slotEligible(), sheetErrors(), matchDossier(), tactiques autorisees et calendrier. Pour les controles consultatifs, un resultat favorable ne dispense jamais de la validation native.
4. Rafraichir aux changements de semaine, d'equipe et de match. Les actions restent au moteur du jeu et ses interfaces.
5. Tests cibles Node, un parcours Chromium PC, une ancienne sauvegarde, puis CI unique sur HEAD final.

Ce lot est un bureau consultatif preparatoire. Les chaines de decisions et modules historiques V17 ne sont pas actifs ici. Aucun resultat sportif, bonus, moral ou sauvegarde de jeu n'est modifie. Aucune fusion sans autorisation de Léo.
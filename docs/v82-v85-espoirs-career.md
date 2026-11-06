# V82–V85 — Direction du centre de formation

## Fonctionnalités
- **V82 : objectifs individualisés** sur les minutes, la progression de la note et la régularité (maximum 3 plans par saison). Ils se concluent selon les minutes Espoirs V73 et l'état sportif du joueur.
- **V83 : mentorat** entre un Espoir et un professionnel du même poste, maximum 3 binômes. Bilan annuel : bonus maximal de 1 point par Espoir sans dépasser son potentiel.
- **V84 : rapports des prêts** V78, affichage des minutes suivies et de leur réussite au seuil fictif de 200 minutes. Aucune modification des résultats des matchs ou mutations automatiques.
- **V85 : objectif annuel du centre** (promotions, formation ou prêts) ; récompense de 24 000 € fictifs plafonnée à une attribution par saison dans le grand livre du jeu.

## Sauvegardes et cycle de saison
État optionnel `s.v82to85` version 1. Les carrières existantes chargent sans état V82 : l'état est initialisé lorsqu'il est utilisé. Les commandes de plans/mentors/objectifs utilisent un rollback complet sur échec de sauvegarde. La clôture annuelle est elle aussi transactionnelle : bonus de mentorat, rapports et prime sont annulés ensemble si `save()` échoue. Historique limité à quatre saisons. L'enveloppe du changement d'année bloque la transition en cas d'échec de ce premier enregistrement, sans réécrire le moteur de carrière.

## Interface
Le script `espoirs-career-v82-v85.js` est inclus **juste après** `espoirs-parcours-v78-v81.js` dans `dist/index.html`. Le panneau apparaît sur la page Formation. Les trois actions globales sont `v82Plan`, `v83Mentor`, `v85Goal`. Le script requiert les API V77/V78 déjà chargées ; aucun script V86–V100 n'est inclus dans cette PR.

## Tests
Exécuter `node tests/v82-v85-espoirs-career.cjs`, puis la CI JavaScript et les parcours Chromium du HEAD exact. Le test dédié couvre ancien état, état malformé, objectifs/mentors uniques, rapports de prêts, clôture annuelle idempotente, rollback de la prime et des bonus, absence de news/ledger, sérialisation JSON et huit saisons. Les contrôles Chromium génériques ne remplacent pas une validation directe du panneau Formation.

## Coordination
La réservation initiale des quatre chemins de V82–V85 reste active tant que les contrôles de la PR et la passation finale n'ont pas été publiés. Après vérification, transmettre explicitement la réservation de `dist/index.html` au raccordement ultérieur des modules V86–V100 ; ne pas fusionner par le compte PRODUCTEUR. Ne toucher ni MATCH 3D, ni R&D, ni DATA/LNR, ni calendrier officiel.

# Raccordement jouable UI-03B et UI-04B — 31 octobre 2026

Les écrans de **Recrutement** et **Formation** utilisent les projections et présentations des PR #86/#87, raccordées par `dist/ui-native-centers.js` au jeu courant, sans dupliquer le moteur.

- Recrutement : cinq onglets, recherche et tri, besoins du club, rapports et suivis ; confier une mission via `createScoutMission` (5 000 €, 2 journées), suivre via `watchPlayer`, consulter le joueur connu via `inspectCareerPlayer` ou rejoindre le mercato. Les estimations restent bornées par `recruitmentEvidence`, sans divulgation de notes secrètes.
- Formation : quatre onglets, espoirs et jeunes pros, fiches, suivi, archives ; promotion confirmée et effectuée uniquement avec `promoteYouth`, objectifs via `setDevelopmentFocus`, consultations par copie JSON pour empêcher les mutations silencieuses.
- Les préférences de filtres sont en mémoire UI uniquement ; pas de changement du format des sauvegardes. Le verrou de match et les autres contrôles métier restent appliqués par les fonctions natives.
- Le jeu utilise l'ancien affichage en secours uniquement si les modules UI03/UI04 ne sont pas chargés (harness et rétrocompatibilité).
- Tests : `node tests/ui-native-centers.cjs` et la CI complète, tests de sauvegardes inclus. Une réception Chromium sur la nouvelle UI est nécessaire avant déclaration de finition visuelle totale.

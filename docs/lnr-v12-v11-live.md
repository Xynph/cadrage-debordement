# Raccordement jouable V12 + profondeur douce + âge V11 — PR d'intégration

## Périmètre et provenance

Base empilée depuis PR #377 / #374. `main` vérifié à `8cfa697b6702f7183aa5b7a4790a7e7b9d399886`. PR #373 reste DRAFT et conflictuelle : son algorithme `tools/rugby-real-v11/aging.cjs` a été recopié à l'identique dans une fonction navigateur isolée ; **sa branche n'a pas été modifiée**. La PR #374 reste source de vérité V12 et doit être reçue avant cette intégration. Ruleset main 26326518 actif, aucune fusion ni bypass.

## Changements destinés exclusivement aux nouvelles carrières LNR

- `tools/lnr-v12-v11-preview/export-live.cjs` régénère `dist/lnr-ratings-v12.js` : **1 592 joueurs, 36 attributs, 11 compétences**, profil V12 + variante de profondeur douce (+4 cadres/+2 titulaires/−3 banc/−5 rotation). Asset de **500 398 octets** embarqué dans `dist/`, sans navigateur connecté. Les identifiants, clubs et effectifs du catalogue restent identiques. Révision sur master en mémoire et génération reproductible en CI ; aucune écriture sur le master.
- `dist/index.html` charge ce jeu de données et `dist/lnr-v11-aging.js` avant `lnr-career.js`.
- `dist/lnr-career.js:lnrGamePlayers` utilise les notes et attributs **uniquement lors de start(ci,'lnr')**. Chaque nouvelle fiche reçoit `lnrRatingsVersion=1`, un `skillBase=rating` prévenant tout bonus initial dans le moteur `skill()`, et un plafond `dev.potential` calculé depuis la marge relative historique (nouvelle note + max(0, potentiel historique − ancienne note)). Le champ `potential` historique et les six traits cachés restent inchangés. **Les postes natifs / qualifications première ligne sont conservés** : les postes plus précis du master V12 sont encore des estimations et leur substitution directe cassait six emplacements.
- `dist/development.js` suit une seule courbe annuelle V11 pour les profils `lnrRatingsVersion===1`, en lieu et place de l'ancien XP/decline `rating`. Le temps de jeu et l'entraînement existants alimentent l'exposition. L'attribut V11 évolue puis la projection V12 vers onze compétences s'exécute une seule fois ; `rating=skillBase` est maintenu. `dev.lastYear` interdit la répétition du même millésime. Les anciennes carrières fictives/LNR sans marqueur et les espoirs restent sur leur évolution native historique ; pas de transformation rétroactive.
- `dist/saves.js` adapte **seulement** la validation de `dev.history[].age` : 15 ans acceptés lorsque `s.lnrMode` existe, toujours au moins 16 ans en univers fictif, jamais 14 ans. Aucune exception globale, aucun nouveau format d'export.
- Ni MATCH3D, ni simulateur de match, ni calendrier, ni club, ni dossier `modding/data06`, ni effectif, ni transfert historique n'ont été touchés.

## Tests reproductibles et limites

`node tools/lnr-v12-v11-preview/export-live.cjs dist/lnr-ratings-v12.js`, puis `node --test tools/lnr-v12-v11-preview/live-seasons.cjs`. Le workflow GitHub régénère l'asset et compare ses octets à ceux versionnés.

Scénarios testés dans le **vrai harness natif** : nouvelle carrière Top 14 LNR (14 clubs), 1 592 profils de l'asset (dont 14 clubs effectivement joués), feuille 15+8, note initiale sans double gain, potentiel initial >= rating, validation des exports, **trois vrais matchs createRugbyMatch/advanceRugby/applyMatchInjuries**, **trois exécutions de `advanceSeason()`** et trois réimports validés après passage de saison, plus l'ancienne carrière fictive inchangée et les cas historiques LNR 15 / 14 / fictif 15.

**Attention :** les tests de saisons positionnent `S.phase='ended'` et `S.round=26` après un match natif par saison pour accélérer le parcours : ils testent véritablement la logique de transition, mais **ne simulent pas toutes les 26 journées** ni la compétition PRO D2. Le calendrier existant du jeu reste inchangé ; pas de promotion/relégation multi-division testée. Non testé : compilation Windows portable sur PC, carrière longue avec 26 matchs intégralement simulés, usages extrêmes des entrainements/fatigue, transactions de plusieurs années et certaines branches de spécialisations. Le coefficient de sensibilité 0,008 reste **hors production** et n'est pas activé. Le moteur de production conserve ses règles tactiques habituelles.

## Intégration / ordre

La PR est empilée sur **#377**, qui est empilée sur **#374** ; il faut réceptionner d'abord le master candidat #374 (après synchronisation sur main), puis le pré-raccordement #377 et cette PR, sans modifier les branches des producteurs sans coordination. #373 reste une proposition distincte ; ses courbes ont été portées dans ce lot sans fusionner ou modifier #373. Revalider la CI finale sur chaque HEAD, les protections et le release gate officiel avant toute fusion. Aucun bypass, aucune commande de gate exécutée ici.

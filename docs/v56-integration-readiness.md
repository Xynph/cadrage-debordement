# V46–V56 : préparation d'intégration sur main, sans fusion

**Constat GitHub :** la PR #51 est déjà fusionnée sur `main`, au commit `7d3be57468063f3d42db4daab22d9bae35478414`. Par conséquent, **ne pas réinjecter les snapshots** V46–V51 des PR de laboratoire #50–#57. Cette branche repart du vrai `main` et ne modifie aucun fichier `dist/`.

## Ce qui est utilisable
- Modules V46–V50 dans `dist/` et raccordement réel `dist/world-career.js`.
- Validation des sauvegardes par `dist/saves.js`, avec `createSaveDocument`, `parseSaveDocument`, `validateCareer`, `bootSavedCareer`.
- Tests natifs existants `tests/world-career.cjs`, `tests/v46-v51-contracts.cjs`, `tests/v51-world-finance.cjs`.
- Rapports V50–V54 utiles **comme mesures expérimentales**, pas comme patch à fusionner.
- V55–V56 fournissent des contrats de fixtures, pas de migrations validées sur d'anciennes sauvegardes réelles.

## Ordre et risques
1. **P0 CI** : exécuter les tests existants sur le `main` intégré, vérifier les contrats sauvegarde, code monde réel et exports des modules.
2. **P1 sauvegardes** : utiliser des exports de test v1 et v2 réels, sur copies, sans écriture automatique sur les sauvegardes de l'utilisateur. Le V56 précédent ne faisait qu'une inspection statique.
3. **P2 événements** : rapprocher dans le jeu réel les événements de recrutement, paiement d'investissement et changements de coach, sans déduire des transferts des simples décisions d'IA.
4. **P3 équilibrage** : comparer intensité de réputation 15/25/100 % à partir de matchs jouables, sans modifier le coefficient de production automatiquement.
5. **P4 intégration** : laisser l'intégrateur propriétaire des fichiers `dist/game.js`, `dist/saves.js` et `dist/world-career.js` ; revue et fusion uniquement après coordination.

## Portée réelle du lot
Un **audit en lecture seule**, pas une nouvelle version jouable. Aucune fusion, aucun changement de sauvegarde et aucun doublon de module. Le workflow exécute à la fois contrôles structurels et suites natives déjà présentes dans le dépôt.

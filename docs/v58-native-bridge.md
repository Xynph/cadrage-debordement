# V58 — raccordement consultatif au jeu natif

Le module `dist/v58-native-bridge.js` est chargé **après** `manager-mobility.js` et avant `game.js`.
Il expose `CDV58NativeBridge.snapshot(S)`, projection **en lecture seule** du club dirigé,
de la saison, du nombre d'offres de mobilité en cours et du changement de club en attente.

Il ne copie pas les contrats synthétiques de `coach-negotiations.js` dans le jeu, ne déduit
aucun salaire, ne touche pas à `dist/saves.js`, ni aux champs de `S`. Les actions réelles
restent sous le contrôle du moteur existant `manager-mobility.js`.
En cas de partie héritée sans mobilité native, la lecture signale `enabled:false`
sans créer de champ ni modifier la sauvegarde.

## Limites
Il s'agit d'un raccordement **de lecture/API**, non d'une interface joueur complète.
Les modules de contrats V58 provenant de #229 restent isolés pour éviter un double
système de carrière. Un futur lot doit prouver la valeur de chaque action avant tout
raccordement transactionnel : finances, migration des sauvegardes, transitions
annuelles et tests de reprise sur des sauvegardes historiques.

Test ciblé : `node tests/v58-native-bridge.cjs`.

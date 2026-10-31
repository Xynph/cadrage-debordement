# V45 — Historique et palmarès de carrière

Registre **indépendant** : `dist/career-history.js`. Conçu pour conserver ultérieurement les trophées, promotions, descentes, récompenses, records et événements de manager dans un journal historique à taille bornée.

- `append(history,event)` : produit un nouveau tableau, refuse les doublons selon un identifiant explicite ou déduit, et conserve un maximum paramétrable d'événements.
- `summary(history,{clubId})` : compte les événements, types et saisons.
- `leaderboard(history,type)` : palmarès des clubs, tri déterministe.

Ce module **n'enregistre rien automatiquement** dans la carrière actuelle et ne change aucune sauvegarde. L'intégration exige de définir les événements fiables d'une saison et leur identifiant persistant. Test : `node tests/career-history.cjs`.

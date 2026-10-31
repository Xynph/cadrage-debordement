# UI-02A — Fondations des fiches joueurs et tableaux

Ce lot crée seulement trois **nouveaux fichiers** sans modifier UI-01, le moteur, les sauvegardes ou le jeu affiché. Base GitHub vérifiée : d3afa283359b13d9e393eb90d305d7411bf638c7. La PR #79 UI-01 est toujours en réception par l'intégrateur unique.

## Périmètre
- `dist/ui02-player-data.js` : projection pure des profils natifs, tri et filtrage des tableaux avec colonnes configurables, comparaison de deux joueurs ; chargement facultatif uniquement dans une prochaine intégration UI-02.
- `tests/ui02-player-data.cjs` : tests natifs via `tests/harness.cjs` existant, sans modifier celui-ci. Vérifie les notes, attributs, potentiels, charge, colonnes, tri, filtres, comparaison, ancien joueur incomplet, sauvegardes et non-mutation.
- `docs/ui02-player-data.md` : cette fiche de raccordement.

## Principes techniques
Réutiliser exclusivement `roleNote`, `potentialAtRole`, `skill`, `physicalLoadValue` et `ATTR` du moteur rugby existant. Aucun coefficient inventé, aucun nouveau rating fictif. Les calculateurs initiaux pouvant compléter un joueur avec `skills` et `dev`, ils reçoivent une copie JSON pour préserver l'état de la carrière et les sauvegardes. Le modèle renvoie des données, jamais du HTML : aucune injection via nom de joueur. Le tri est stable et les colonnes inconnues sont rejetées.

Les quatre préréglages `overview`, `contracts`, `fitness` et `development` restent de simples choix de colonnes. Les données absentes ne sont pas fabriquées. Les chiffres financiers sont ceux, fictifs, du jeu.

## Dépendance
UI-02A ne sera pas ajoutée à `dist/index.html` et ne changera aucun écran tant que la PR #79 n'aura pas été fusionnée et validée. Le chantier de raccordement UI-02 devra réserver explicitement `dist/game.js`, `dist/manager-squad.js`, `dist/style.css`, et reprendre le nouveau `main`. Il devra aussi contrôler responsive, clavier, lecteurs d'écran, anciennes sauvegardes, V40, V58 et CI complète.

## Limites
Ce lot n'est **pas** une fiche joueur jouable. Les tableaux personnalisables sont des données projetées, pas encore des préférences sauvegardées ni un nouveau design. Aucun test graphique ou Windows natif revendiqué. Les données de scouting d'autres clubs ne sont pas dans ce périmètre ; l'usage prévu est l'effectif de son club.

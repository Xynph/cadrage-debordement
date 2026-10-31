# DATA-02 + MAPPING-01 — Réception et statut

## Livré dans cette PR
**30 correspondances explicites, toutes uniques**, entre les clubs alternatifs (PR #112, fusionnée) et les clubs réels inventoriés (PR #109, fusionnée). Choix **éditorial fondé sur les ancrages géographiques**, pas sur l'ordre des listes. Les noms et identifiants existants ont été vérifiés directement contre les JSON GitHub et les divisions concordent. Chaque correspondance conserve `review: requires-game-design-approval` : ces associations sont des propositions argumentées à approuver avant mise en service.

**30 arrivées réelles de joueurs** pour cinq clubs, avec poste, âge publié, nationalité, ancien club, URL de provenance ; source officielle LNR : https://top14.lnr.fr/actualite/le-tableau-des-transferts-pour-la-saison-20262027 . Il s'agit de lignes de **mercato**, NON des effectifs complets 2026-2027 ni de contrats vérifiés. Les champs salaire, durée contractuelle, mensurations, formation, staff restent absents ou `null`. Aucun joueur ou membre du staff n'a été inventé.

Références complémentaires pour le travail d'effectifs : https://top14.lnr.fr/joueurs ; pages d'équipes LNR https://top14.lnr.fr/clubs et https://prod2.lnr.fr/clubs ; sources économiques à vérifier contre les documents originaux de l'A2R et rapports publiés LNR. Les valeurs économiques 2025/26 ou les ressources estimées ne doivent pas être présentées comme budgets 2026/27.

## Contrôle réellement exécuté
Vérification exécutée directement sur le contenu GitHub de la branche : 30 correspondances ; aucun ID inconnu, nom incorrect, doublon ou divergence de division ; 30 joueurs ayant des identifiants de club réels, champs absents explicites ; **zéro erreur détectée**. `tests/data02-mapping01.cjs` permet la reprise dans la CI Node ; résultat de son exécution locale distinct de ce contrôle GitHub.

## Intégration
Départ de carrière `2026-07-01`, calendrier officiel des 422 matchs depuis PR #117 tant qu'elle est validée et fusionnée. Deux univers, calendrier sportif commun ; les noms du jeu de base et du mod réel sont résolus par correspondance *explicite*. Anciennes sauvegardes inchangées. Aucun `dist/**`, catalogue d'origine ni save modifié.

## Travail restant
Récupérer les listes complètes 2026-27 club par club, réconcilier les départs, prêts et espoirs avec la LNR, puis rechercher les staffs officiels, données économiques et contrats publics sans invention. Les photos et logos ne sont pas distribués sans droits. Le statut du présent lot est « fondation de données incomplète », **pas « DATA-02 terminé »**.

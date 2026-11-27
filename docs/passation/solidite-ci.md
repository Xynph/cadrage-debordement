# Solidité CI : passation du chantier (résumé)

Version résumée. Le fonctionnement général de la CI est dans [LISEZ-MOI.md](LISEZ-MOI.md) section 4 ; l'état des rouges dans [etat-27-novembre.md](etat-27-novembre.md).

## Règles du chantier
- Classer chaque échec : (a) vrai défaut du jeu : corriger le jeu, le test existant doit passer sans modification ; (b) test périmé : correctif de test aux mêmes contrôles et mêmes seuils, avec accord ; (c) hasard non figé : figer la graine après avoir vérifié 3 graines.
- Interdits : abaisser un seuil, relever un délai sans mesure, retirer un contrôle, sauter un test.
- Vérificateur GO avant toute PR en fusion auto ; une PR courte par famille.

## Familles
Faites : préchauffage des portraits, reprise de partie, poids et jobs CI, A (filmes, notation), B (carte joueur, cris-banc, direct 2D, menu joueur), C (coque, prolongations, gabi, direct-tableau, temps forts, grands moments), D (liaison-monde), E (intermittents), F (lois-complètes), G (grand Bureau), H (liaison scriptée), I (interface-layout en mode Monde). Restantes : voir a-faire.md P1-1 et P1-2.

## Vrais défauts du jeu trouvés
Reprise d'un ancien journal qui franchit une semaine (#1326) ; carrière Monde exportée après un match non réimportable (#1354) ; ombre sur les pastilles de lettre (#1344) ; cartes du pack de la Composition qui se chevauchent (#1349) ; débordements de l'avant-match (#1336) ; Mon XV hors écran à la 76e minute (#1345) ; dernier résultat non cliquable sur le grand Bureau (#1347).

## Pièges
- Graine : une carrière sans `CD_GODOT_SEED` tire au hasard ; liaison-monde et planches du direct dépendent de graines.
- Carton à la 5e minute (graine 3, depuis #1315) : cliquer « Reprendre » (modèle : #1335, #1359).
- Caches des portraits : ne jamais comparer des temps absolus en CI ; meilleur de N passes ou ratio.
- La première Composition coûte 110 à 190 ms dont environ 40 ms de portraits.
- L'option `--display-driver x11` d'un test est refusée par Godot sous Windows : fichier de remplacement temporaire (ne pas commiter).
- Un nettoyage « de tout le scratchpad » détruit les fichiers des autres agents.
- `gh pr update-branch <n>` relance la CI d'une PR.
- Runners lents : les 4 vCPU partagent 2 cœurs physiques ; cris-banc et planche-carte-joueur étaient saturés (rendu logiciel) avant #1355.

## Intermittents (analyse du 26/11)
Rouge puis vert sans changement de code : godot-analysis-club-graphics (carrière non figée, lien Bureau absent selon blessés ; résolu côté jeu par #1347), avant-match-bilan (#1336), meteo-vent (#1340), match-grands-moments (plafond relevé #1341), match-direct-da (#1342). Restent rares : survols-club-courbe-rebours, deepen-analytics-real-ui, godot-equipe-type, godot-preparation-ecran, godot-centre-cartes, godot-phrases-lot10, godot-apres-match.

## Commandes utiles
`gh pr view <n> --json state,mergeStateStatus,autoMergeRequest` ; `gh pr merge <n> --auto --squash` ; `gh run list --workflow "Tests JavaScript" --branch main --limit 25` ; `gh run view <id> --log-failed` ; `node ci/shard-tests.cjs <i> godot 6` (répartition).

## Lacunes de ce résumé
L'analyse détaillée des échecs (tableau de 12 suites avec les runs) et les fiches de correctifs de tests étaient hors dépôt et ne sont pas reprises ici. Si un rouge ancien revient, relire ses journaux par `gh run view <id> --log-failed`.

# V62 — Audit transversal, barrières de raccordement au jeu réel

Base vérifiée : `main` 7d3be574, V42 via `dist/career-integration.js`, V46–V51 via `dist/world-career.js`, V48 via `dist/coach-market.js` et sauvegardes via `dist/saves.js`. PR #65 : chantier V59 IA des clubs toujours en brouillon. Tous les changements de cette PR : uniquement test, workflow, documentation ; aucun code partagé, aucune sauvegarde utilisateur.

## Plan d'intégration priorisé

| Rang | Sources PR | Intégrer seulement | Risques et conditions |
| --- | --- | --- | --- |
| 1 | #60, #61, #62, #63 | Événements et propositions d'emplois du manager | V48 a déjà les décisions de coach IA; préserver un seul titulaire par club, garder les mouvements de carrière natifs et un seul moteur salarial |
| 2 | #64, #66, #67 | Interventions, promesses, chronologie idempotente | V42 gère déjà confiance et objectifs : ne pas dupliquer la pression de direction, brancher les résultats sportifs réels |
| 3 | #68 | Échéancier de rendez-vous, briefing et archives | V42 comporte déjà `boardHistory` et `lastBoardRound`; NE PAS créer un second registre de confiance |
| 4 | #65 | Reprise V59 par le responsable d'intégration | Contrats joueurs, budget et marché doivent conserver le comportement et les sauvegardes natifs |

## Risques vérifiés ou exposés
- Le vrai `career-integration.js` gère déjà la direction et le sponsoring : V61 doit être **un adaptateur d'échéances**, pas une nouvelle direction concurrente.
- Le vrai `world-career.js` gère les infrastructures et appelle `ledgerEntry` : les dépenses d'un laboratoire ne doivent pas être facturées une deuxième fois.
- Le vrai `coach-market.js` possède déjà postes et risques de licenciement : V58 ne peut pas activer un deuxième système de titulaires.
- Les fonctions de validation de `saves.js` contrôlent texte, identifiants et types. Toute évolution de format devra être testée sur **copies** d'anciennes sauvegardes, avec migration facultative et version explicite.
- V60–V60.2 utilisent un calendrier de laboratoire et des coefficients fictifs ; V59 agit sur les effectifs, hors de notre périmètre.

## Contrôles exécutables
`tests/v62-native-integration-gates.cjs` charge et exécute les vrais modules `club-ai`, `coach-market` de `main` ainsi que des validations natives de `saves.js` dans un `vm` isolé. Il inspecte aussi les fonctions d'intégration V42/V49 (contrats structurels), sans simuler de vraie partie. CI vérifie en plus `tests/v46-v51-contracts.cjs`.

## STOP avant toute fusion
Il reste à créer les adaptateurs vers la vraie carrière, exécuter les flux de sauvegarde import/export sur des fixtures natives, et tester l'équilibrage sur des saisons de matchs réels. Les PR empilées ne doivent pas être fusionnées telles quelles ; l'intégrateur reprend les seuls modules complémentaires sur un `main` actualisé.

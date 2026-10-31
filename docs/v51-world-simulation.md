# V51 — Simulateur indépendant de l'univers rugby (10 à 15 saisons)

Moteur de démonstration purement calculatoire, non connecté aux carrières existantes. Il combine **les fonctions injectées** de V46 (décision de recrutement), V47 (réputation), V48 (risque entraîneur), V49 (infrastructures) et V50 (récompenses), avec une économie fictive simplifiée pour 14 clubs et un tirage pseudo-aléatoire reproductible.

## Limites assumées

- Le classement des clubs est un **proxy de forme** et non une simulation de matchs. Aucun résultat réel ou calendrier n'est inventé.
- Le changement d'entraîneur est un événement simulé, pas un transfert de contrat.
- Le recrutement ne réalise aucune signature : le mécanisme V46 reçoit pour l'instant une liste de besoins/candidats vide. Toute transaction serait trompeuse avant une connexion à la carrière.
- Le capital est plafonné à zéro en cas de déficit : **ce modèle ne traite donc pas encore l'endettement ni les liquidations**. À auditer avant un usage jouable.
- Les revenus et coûts ainsi que les notes sont **fictifs**. Pas de données de vrais clubs.
- Aucun nouveau format de sauvegarde n'est créé ; aucune fonction de match ou UI modifiée.

## Dépendances pour test local

Le test `tests/v51-world-simulation.cjs` nécessite les fichiers des PR V46–V50 ; celles-ci ne sont **pas dans main**. Le test n'est donc exécutable qu'une fois les modules présents ensemble dans un checkout d'intégration.

Pour préserver l'indépendance, le module V51 lui-même reste importable seul, et le test de contrat autonome `tests/v51-contract.cjs` utilise des adaptateurs factices pour vérifier les invariants sans autre PR.

## Coordination

PR V41–V45 : #34, #36, #37, #38, #39 et intégration #45 (autre compte). PR V46–V50 : #40–#44. Cette V51 doit être intégrée **après** ces PR, en adaptant l'économie au modèle réel de carrière. Aucun fichier d'intégration partagé n'a été touché.

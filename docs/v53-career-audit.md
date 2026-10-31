# V53 — Audit d'intégrité des carrières fictives

## Périmètre

Branche `test/v53-career-integrity-audit` indépendante des modifications de l'intégrateur. Le test exécute **40 graines × 3 intensités de réputation (15 %, 25 %, 100 %) × 2 profils de départ × 15 saisons = 3 600 saisons**, soit 50 400 clubs-saisons, et **240 reprises** depuis la saison 8.

## Sept contrôles regroupés

- Réputation et hiérarchie : concentration des titres et nombre de champions distincts par carrière, plus profils annuels.
- Finances : dette non négative, montants définis, déficits et restrictions.
- Infrastructures : investissement positif uniquement en régime normal ; événement d'investissement présent pour chaque investissement payé.
- IA des clubs : audit du nombre de décisions de recrutement, **sans revendiquer de transferts signés**.
- Entraîneurs : événements `coachChange` et flags annuels concordants ; un événement n'implique pas nécessairement un licenciement réel dans le jeu.
- Carrières longues : reprise déterministe, événements et états finaux identiques après un checkpoint de huit saisons.
- Reporting : rapport JSON complet avec séries annuelles et synthèse par scénario, disponible en artefact CI.

## Limites

Les clubs, budgets, matchs et transactions sont synthétiques. Un vrai transfert nécessite un journal de signatures issu de la carrière réelle et ne peut pas être déduit de `recruitmentDecision`. Aucun moteur, sauvegarde ni interface partagé n'est modifié.

## Preuve de tests

Ne pas déclarer le résultat du test V53 réussi avant la conclusion de son workflow GitHub Actions sur le dernier SHA. La dernière CI de V52 est à consulter séparément.

# Rugby Réel — contrôle autonome des carrières longues, 07/11/2026

## Objet et limites
Le raccordement V12/V11 est **déjà fusionné** sur main par PR #379. Le présent lot est un **test d'acceptation indépendant et non destructif** : ne réécrit ni les 1 592 fiches, ni les 36 attributs, ni les transferts, ni le moteur, ni la simulation et ni les sauvegardes. Le producteur graphique dispose d'un périmètre réservé séparé.

## Nouvelle réception
`node --test tests/rugby-real-long-career-qa.cjs` utilise `tests/harness.cjs`, les vrais scripts `dist/`, `start(0,'lnr')`, `finishRound()`, les phases finales et `advanceSeason()`. Une carrière de 10 saisons joue intégralement les 26 journées de 14 clubs (1 820 matchs de phase régulière attendus, plus les phases finales), puis effectue dix exports/imports avec `createSaveDocument()` et `parseSaveDocument()`. Après chaque année, le contrôle vérifie le nombre de rencontres, les identifiants non dupliqués et l'intégrité des 36 attributs/11 compétences et du rating des joueurs V12 encore présents. Une deuxième réception vérifie qu'une sauvegarde fictive ne se convertit pas silencieusement à Rugby Réel.

Les traces synthétiques annuelles sont sorties sous `RUGBY_REAL_LONG_CAREER_QA` dans les logs CI. Les résultats ne sont pas préjugés : **aucune campagne nouvelle n'est revendiquée réussie avant le verdict GitHub sur le HEAD exact**.

## Couverture encore manquante
Ce test **n'est pas** un championnat à deux divisions. Le mode carrière actuel ne simule pas une promotion automatique TOP 14 ⇄ PRO D2 avec transfert budgétaire réaliste. Il serait trompeur d'annoncer des taux historiques de montée, maintien ou remontée sur ces 10 saisons. La simulation de duels V12 existante (5 888 matchs en scénarios contrôlés, voir `docs/rugby-real-v12/results.md`) identifie déjà plusieurs cibles manquées, notamment le promu face à un effectif TOP14 fort et le manque d'effet de cinq départs. Ces lacunes doivent être traitées dans **une PR gameplay distincte**, après contrôle des réservations. Aucun coefficient sportif n'est changé ici.

## Reproduction et passation
`node --check tests/rugby-real-long-career-qa.cjs`
`node --test tests/rugby-real-long-career-qa.cjs`

Le workflow `Rugby Reel - ten-season native career QA` réalise les vérifications en GitHub Actions. Si échec, conserver DRAFT, examiner les logs et corriger uniquement les trois nouveaux chemins réservés ; ne pas masquer les limites moteur. Aucun /cd-check, /cd-merge ou fusion en rôle producteur.

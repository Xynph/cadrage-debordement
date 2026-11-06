# Résultats natifs V11

Base 3014774ab4ca13d1d325756ed89f2bb029b1b99c. 8448 matchs comparatifs, 64 graines × deux domiciles par scénario. Propositions hors production.

| Scénario (victoires du premier effectif) | 11 notes héritées | Projection baseline | Notes consolidées | Notes + réponse ×2 | Écart score ×2 |
|---|---:|---:|---:|---:|---:|
|top14_peer|46.88 %|46.88 %|42.97 %|45.31 %|-0.65|
|prod2_peer|50 %|46.09 %|46.09 %|47.66 %|-0.27|
|prod2_mid_top14_mid|30.47 %|32.03 %|35.94 %|30.47 %|-5.25|
|promoted0_weak|30.47 %|25 %|25.78 %|16.41 %|-9.9|
|promoted0_mid|24.22 %|27.34 %|26.56 %|12.5 %|-11.09|
|promoted0_strong|25 %|23.44 %|25 %|13.28 %|-12.37|
|relegated_keep_weak|63.28 %|64.06 %|63.28 %|66.41 %|5.48|
|relegated_keep_mid|55.47 %|53.91 %|58.59 %|64.06 %|2.9|
|relegated_keep_best|64.84 %|71.88 %|71.88 %|80.47 %|9.9|
|promoted2_mid|21.09 %|29.69 %|25.78 %|17.19 %|-9.79|
|promoted3_mid|21.88 %|30.47 %|26.56 %|19.53 %|-9.28|
|promoted5_mid|28.13 %|21.88 %|24.22 %|25 %|-7.69|
|relegated_lose5_mid|53.91 %|53.91 %|56.25 %|57.03 %|1.65|

Les mêmes IDs sont recrutés ou retirés dans les quatre versions. La colonne « héritées » utilise les notes stockées dans le master, pas le générateur LNR actuel. Les colonnes projetées sont des expériences sur copies. Aucune probabilité de maintien/remontée sur une saison à deux divisions n’est mesurée.

## Cibles exploratoires

- kind : Exploratory game-design goals; NOT official historical statistics
- averagePromotedWinAtMost30 : false
- bestPromotedVsStrongAtMost25 : true
- bestPromotedVsWeakAtLeast15 : true
- fiveRecruitsImproveMargin : true
- relegatedAdvantageNotGuaranteed : true
- departuresReduceMargin : true

## Discipline, fatigue et tactiques

| Scénario ×2 | Essais pour/contre | Pénalités pour/contre | Jaunes pour/contre | Fatigue moyenne pour/contre | Victoires (IC par graine) |
|---|---:|---:|---:|---:|---:|
|promoted0_mid|1.3 / 2.9|5.41 / 5.31|0.88 / 0.8|20.11 / 23.79|12.5 % [7.15 ; 17.85]|
|promoted5_mid|1.66 / 2.72|5.02 / 5.34|0.84 / 0.91|20.19 / 23.7|25 % [17.76 ; 32.24]|
|promoted_tired_mid|0.93 / 3.92|6.73 / 4.73|1.28 / 0.74|19.1 / 24.26|1.56 % [0 ; 3.71]|
|promoted_equilibre_mid|1.24 / 2.98|5.38 / 5.18|0.89 / 0.79|19.99 / 23.82|6.25 % [2.17 ; 10.33]|
|promoted_conquete_mid|1.3 / 2.85|5.38 / 5.22|0.88 / 0.78|20.1 / 23.81|12.5 % [7.15 ; 17.85]|
|promoted_large_mid|1.32 / 2.95|5.37 / 5.43|0.83 / 0.83|20.19 / 23.78|10.94 % [4.97 ; 16.9]|
|promoted_occupation_mid|1.22 / 2.98|5.41 / 5.13|0.88 / 0.78|19.89 / 23.87|8.59 % [3.45 ; 13.74]|
|promoted_defence_pression|1.26 / 2.91|5.5 / 5.27|0.9 / 0.8|20.45 / 23.83|11.72 % [6.49 ; 16.95]|
|promoted_defence_prudente|1.33 / 2.88|5.23 / 5.27|0.89 / 0.79|19.98 / 23.8|13.28 % [7.41 ; 19.16]|

## Comparaisons appariées

| Scénario | Écart notes seules | Écart réponse moteur seule | Écart combiné (IC par graine) |
|---|---:|---:|---:|
|top14_peer|0|-0.02|-0.02 [-1.76 ; 1.72]|
|prod2_peer|0|-0.45|-0.45 [-1.54 ; 0.65]|
|prod2_mid_top14_mid|0.2|-1.47|-1.27 [-3.11 ; 0.57]|
|promoted0_weak|-0.6|-3.36|-3.96 [-5.51 ; -2.41]|
|promoted0_mid|0.29|-3.52|-3.23 [-5.21 ; -1.24]|
|promoted0_strong|0.44|-4.23|-3.8 [-5.98 ; -1.62]|
|relegated_keep_weak|-0.27|2.33|2.05 [0.07 ; 4.04]|
|relegated_keep_mid|0.38|0.86|1.23 [-0.76 ; 3.23]|
|relegated_keep_best|0.6|3.36|3.96 [2.41 ; 5.51]|
|promoted2_mid|-1.02|-1.78|-2.8 [-4.73 ; -0.88]|
|promoted3_mid|-0.93|-1.98|-2.91 [-4.53 ; -1.3]|
|promoted5_mid|0.43|-1.04|-0.61 [-2.46 ; 1.25]|
|relegated_lose5_mid|0.61|0.04|0.65 [-1.11 ; 2.4]|

## Limites

- Offline controlled rosters; no 2-division senior career exists on main
- Champion and relegated labels are roster-quality proxies, not historical champions or natural relegations
- No native salary/fee claim for controlled recruits; all salaries held neutral at 5000
- Position certainty still limited by master estimated roles
- Hidden traits and potential retained; not newly wired into match engine
- Wilson intervals are descriptive match-level intervals; home/away share seeds, clustered paired-margin intervals are the inferential comparison; design goals are not historical frequencies

Voir README.md, age-research.md et age-impact.json pour le volet âge, ainsi que seasons.json pour le blocage réel de sauvegarde et sa proposition isolée. Les intervalles sont exploratoires ; une direction moyenne ne garantit pas la monotonie de chaque taux de victoire.

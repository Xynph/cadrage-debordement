# Notes V12 — résultats du vrai moteur

5888 matchs, 64 graines et deux domiciles par scénario. Coefficient natif inchangé (0,004). Les mêmes IDs de recrues et de départs sont utilisés dans chaque variante.

| Scénario : victoires du premier effectif | 11 notes héritées | 36 notes actuelles projetées | 36 notes V12 | Écart V12 | Variation d’écart appariée [IC95] |
|---|---:|---:|---:|---:|---:|
|top14_peer|44.53 %|47.66 %|45.31 %|-0.34|0.12 [-1.15 ; 1.38]|
|prod2_peer|57.81 %|46.09 %|47.66 %|-0.49|-0.96 [-2.76 ; 0.83]|
|prod2_mid_top14_mid|32.03 %|31.25 %|24.22 %|-6.87|-2.41 [-4.53 ; -0.3]|
|promoted0_weak|35.94 %|41.41 %|31.25 %|-4.47|-2.13 [-3.86 ; -0.41]|
|promoted0_mid|35.16 %|32.03 %|29.69 %|-5.34|-0.86 [-2.7 ; 0.98]|
|promoted0_strong|32.81 %|32.81 %|40.63 %|-4.3|-0.53 [-3.1 ; 2.04]|
|relegated_keep_weak|55.47 %|62.5 %|59.38 %|4.73|0.94 [-1.3 ; 3.17]|
|relegated_keep_mid|53.91 %|50.78 %|62.5 %|5.5|3.94 [1.81 ; 6.06]|
|relegated_keep_best|60.94 %|50.78 %|63.28 %|4.47|2.13 [0.41 ; 3.86]|
|promoted2_mid|35.94 %|32.03 %|31.25 %|-4.01|0.38 [-1.89 ; 2.65]|
|promoted3_mid|35.94 %|32.03 %|30.47 %|-4.1|0.48 [-1.69 ; 2.64]|
|promoted5_mid|35.16 %|35.16 %|31.25 %|-3.34|0.23 [-1.57 ; 2.03]|
|relegated_lose5_mid|60.94 %|47.66 %|65.63 %|5.47|5.37 [3.01 ; 7.73]|

## Essais, discipline, fatigue et tactiques

| Scénario V12 | Essais pour/contre | Pénalités | Jaunes | Fatigue moyenne | Victoires [IC95] |
|---|---:|---:|---:|---:|---:|
|top14_peer|1.95 / 2.05|5.27 / 5.2|0.83 / 0.87|22.59 / 22.41|45.31 % [38.87 ; 51.76]|
|prod2_peer|2.12 / 2.18|5.49 / 5.34|0.95 / 1.02|23.71 / 23.53|47.66 % [43.61 ; 51.7]|
|prod2_mid_top14_mid|1.77 / 2.81|5.56 / 4.78|0.86 / 0.73|23.55 / 22.68|24.22 % [17.32 ; 31.12]|
|promoted0_weak|1.84 / 2.66|5.26 / 4.88|0.83 / 0.74|23.73 / 22.78|31.25 % [23.53 ; 38.97]|
|promoted0_mid|1.73 / 2.67|5.27 / 4.94|0.86 / 0.75|23.48 / 22.67|29.69 % [22.54 ; 36.83]|
|promoted0_strong|1.8 / 2.38|5.02 / 4.85|0.88 / 0.71|23.61 / 21.71|40.63 % [31.93 ; 49.32]|
|relegated_keep_weak|2.61 / 1.87|4.92 / 5.46|0.76 / 0.81|22.74 / 23.87|59.38 % [51.54 ; 67.21]|
|relegated_keep_mid|2.73 / 1.88|5.03 / 5.41|0.75 / 0.86|22.78 / 23.65|62.5 % [54.33 ; 70.67]|
|relegated_keep_best|2.66 / 1.84|4.88 / 5.26|0.74 / 0.83|22.78 / 23.73|63.28 % [55.04 ; 71.52]|
|promoted2_mid|1.8 / 2.52|5.18 / 4.69|0.86 / 0.64|23.31 / 22.72|31.25 % [22.94 ; 39.56]|
|promoted3_mid|1.79 / 2.52|5.45 / 4.8|0.88 / 0.69|23.79 / 22.7|30.47 % [22.12 ; 38.81]|
|promoted5_mid|1.8 / 2.38|5.36 / 4.85|0.89 / 0.69|23.39 / 22.6|31.25 % [24.18 ; 38.32]|
|relegated_lose5_mid|2.75 / 1.88|4.9 / 5.59|0.7 / 0.88|22.82 / 23.55|65.63 % [57.49 ; 73.76]|
|promoted_tired_mid|1.36 / 2.98|6.34 / 4.34|1.15 / 0.69|22.63 / 22.84|13.28 % [7.41 ; 19.16]|
|promoted_equilibre_mid|1.86 / 2.6|5.13 / 5.01|0.84 / 0.8|22.63 / 22.66|29.69 % [22.88 ; 36.49]|
|promoted_conquete_mid|1.88 / 2.38|5.34 / 5.03|0.85 / 0.83|23.35 / 22.74|35.16 % [27.38 ; 42.93]|
|promoted_large_mid|1.66 / 2.62|5.15 / 5.01|0.83 / 0.75|24.31 / 22.53|25 % [17.44 ; 32.56]|
|promoted_occupation_mid|1.4 / 2.84|5.19 / 4.52|0.92 / 0.86|21.99 / 22.56|18.75 % [12.77 ; 24.73]|
|promoted_defence_pression|1.52 / 2.45|6.05 / 5.21|1.07 / 0.84|25.53 / 22.48|25.78 % [18.88 ; 32.68]|
|promoted_defence_prudente|1.79 / 2.3|5.12 / 4.71|0.76 / 0.76|22.78 / 22.7|38.28 % [31.13 ; 45.43]|

## Cibles de game design exploratoires

Ces seuils sont des choix à calibrer, pas des fréquences historiques officielles. Un échec reste visible.
- averagePromotedWinAtMost30 : true
- bestPromotedVsStrongAtMost25 : false
- bestPromotedVsWeakAtLeast15 : true
- fiveRecruitsImproveMargin : true
- relegatedAdvantageNotGuaranteed : true
- departuresReduceMargin : true

## Portée

- Sélection limitée aux feuilles complètes 15+8 ; exclus : beziers (14+8), brive (14+8), aurillac (13+8), montauban (14+8), valence-romans (13+7). Chaque scénario est contrôlé avant simulation.
- Offline controlled rosters; no 2-division senior career exists on main
- Champion and relegated labels are roster-quality proxies, not historical champions or natural relegations
- No native salary/fee claim for controlled recruits; all salaries held neutral at 5000
- Position certainty still limited by master estimated roles
- Hidden traits and potential retained; not newly wired into match engine
- Win and paired-margin intervals are clustered by seed; exploratory design goals are not historical frequencies
- Les 36 attributs n’alimentent actuellement pas le générateur LNR du jeu : cette expérience injecte les effectifs dans le vrai moteur via le harness existant.
- La montée/descente à deux divisions n’existe pas encore dans la carrière senior de main. Aucun taux de maintien ou de remontée de saison complète n’est prétendu.
- Les intervalles regroupent les deux domiciles par graine ; cette campagne est exploratoire.

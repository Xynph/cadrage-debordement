# Rugby Réel — réception carrières longues et diagnostic sportif, 07/11/2026

## Gouvernance et périmètre
La PR #379 V12/V11 est **déjà fusionnée**. Le présent lot est de la QA autonome, sans modifier le moteur, les 1 592 joueurs, les 36 attributs, les clubs, les effectifs, les calendriers, les coefficients de production, les sauvegardes ni aucune interface Codex. Branche `qa/rugby-real-long-career-20261107`, trois fichiers nouveaux seulement, réservation #73 #6705934929.

## Tests natifs : carrière longue
`node --test tests/rugby-real-long-career-qa.cjs` utilise `tests/harness.cjs` et les scripts réels `dist/`. Une carrière de dix saisons joue les 26 journées de 14 clubs (1 820 rencontres régulières attendues), plus les finales, puis effectue dix sauvegardes et imports natifs signés avec `createSaveDocument()` / `parseSaveDocument()`. Chaque saison vérifie le nombre de matchs, les identifiants, les 36 attributs/11 compétences et les ratings conservés. Une ancienne carrière fictive ne doit pas être convertie silencieusement.

**Premier HEAD `f4230d041b24b88f298383284d7d4ee26952c085` :** workflow QA #42366326511 `COMPLETED/SUCCESS`, job de test `native-ten-seasons` réussi. JavaScript général #42366326579 était encore en cours au contrôle ; ne pas présenter son 7/7 comme terminal. Le nouveau HEAD, après élargissement de l'audit, nécessite **une nouvelle CI complète** ; aucun ancien résultat ne le qualifie.

## Tests comparatifs de recrutement et départs
Le workflow ajoute `tools/rugby-real-v12/calibration.cjs` sur 8 graines et les deux domiciles : 240 rencontres avec le vrai moteur de match sur cinq scénarios et trois coefficients **hors production** (0,004 existant, 0,008 et 0,012 exploratoires). Les cinq recrues et cinq départs sont des joueurs identifiés, avec contrôle des changements de titulaires. Les sorties comprennent les taux de victoire et écarts de points dans les logs `RUGBY_REAL_MOVEMENT_QA`. Ce sont des **scénarios de laboratoire**, non des transferts issus d'offres ou de budgets de carrière.

Le workflow réexécute aussi les contrats de maturité existants : vitesse/accélération en déclin plus précoce que la force, et variantes de profondeur. Il n'invente aucune trajectoire historique et ne modifie pas l'algorithme V11 de production.

## Conclusions connues avant cette campagne
Dans la précédente campagne V12 (5 888 matchs, 64 graines par scénario), l'équipe moyenne PRO D2 ne gagnait que 24,22 % contre l'équipe moyenne TOP14, et le relégué proxy conservé gagnait 62,50 % contre PRO D2 moyen. Mais le promu proxy gagnait encore 40,63 % contre le plus fort TOP14 de la grille, et la perte de cinq joueurs du relégué ne dégradait presque pas sa marge (+5,50 à +5,47). Les résultats du nouveau run doivent confirmer ou nuancer ces anomalies, pas être supposés identiques. Les coefficients alternatifs sont seulement des sensibilités exploratoires, jamais une recommandation automatique.

## Limite structurelle à ne pas masquer
Le jeu n'exécute pas encore une carrière senior native à deux divisions TOP 14 ⇄ PRO D2 avec promotion/relégation et transferts contractuels inter-divisions. Les dix saisons testées sont TOP14 ; elles ne prouvent **aucun taux de maintien ni de remontée**. Une correction du gameplay nécessitera une autre PR, une coordination et une réservation nouvelles.

## Reproduire
`node --check tests/rugby-real-long-career-qa.cjs`
`node --test tests/rugby-real-long-career-qa.cjs`
`node --test --test-name-pattern="maturité distincte|profondeur: trois variantes" tests/rugby-real-full-ratings-v12.cjs`

Le workflow déclenche aussi la calibration native. Si des résultats sont inattendus, STOP et diagnostic ; préserver les limites. La PR demeure DRAFT, **aucune fusion** en rôle producteur.

## Diagnostic chiffré — ce qui est acquis et ce qui reste exploratoire

**Preuve GitHub du premier HEAD `f4230d041b24b88f298383284d7d4ee26952c085` :** logs job `native-ten-seasons` du run #42366326511 : 2 tests PASS, 0 FAIL, 1 820 matchs de saison régulière, **50 rencontres de phases finales**, dix exports/imports réussis. Le nombre de profils marqués V12 dans les 14 clubs TOP14 évolue ainsi : saisons 1→10 = **805, 699, 608, 509, 441, 385, 353, 328, 310, 281**, soit 524 de moins (−65,1 %). **Cela ne démontre pas une perte de joueurs ou une erreur d'âge** : le renouvellement des effectifs, les retraites et les entrées de jeunes non V12 peuvent expliquer une partie du phénomène ; la distribution par cohortes et les départs individuels ne sont pas ici reconstitués.

La version élargie mesure maintenant, à chaque fin de saison, les moyennes de vitesse, force, endurance et décisions sur les profils V12 *encore présents*, dans les tranches 18–23, 24–29, 30–34 et 35+ ans. **Biais de survivants explicite** : comparer les moyennes transversales ne prouve pas la trajectoire d'un même joueur. Le vieillissement V11 a déjà ses tests de contrat spécifiques et le lot actuel ne change aucune de ses règles.

**Diagnostics issus de la campagne publiée V12 à 64 graines (avant PR #383)** :

| Mesure de laboratoire | V12 |
|---|---:|
| PRO D2 moyen contre TOP14 moyen : victoires | 24,22 % |
| Promu-proxy contre TOP14 moyen : victoires | 29,69 % |
| Promu-proxy contre TOP14 le plus fort : victoires | 40,63 % |
| Promu-proxy + 5 recrues contre TOP14 moyen | 31,25 % |
| Relégué-proxy conservé contre PRO D2 moyen | 62,50 % |
| Relégué-proxy avec 5 départs contre PRO D2 moyen | 65,63 % |
| Relégué conservé : marge moyenne contre PRO D2 | +5,50 points |
| Relégué après 5 départs : marge moyenne | +5,47 points |

Source reproductible : `docs/rugby-real-v12/results.md` et `tools/rugby-real-v12/campaign.cjs` sur main, moteur natif à coefficient 0,004. **Anomalies de design possibles** : la variante "fort" donne une victoire trop fréquente au promu-proxy et la perte de cinq joueurs améliore paradoxalement son taux de victoires en petit échantillon ; la marge ne baisse que de 0,03 point. Ces clubs sont choisis par qualité d'effectif et ne sont pas des promus/relégués historiques. Le test 240 matchs et les trois sensibilités doivent analyser cette incohérence, sans en faire une vérité statistique sur la compétition.

**Règles de lecture du nouveau test de 240 matchs :** 8 graines appariées, les deux domiciles, 5 scénarios, 3 coefficients hors production. Chaque taux par scénario et coefficient repose sur **16 matchs**, donc est très instable. Les variations de marge et les remplacements de titulaires doivent être lus en parallèle, jamais comme seuils définitifs de calibration ; une décision sportive exige une reproduction plus large à 64–128 graines et d'autres effectifs.

**Validation :** aucun résultat du nouveau HEAD n'est déclaré réussi avant son workflow GitHub exact. La PR reste DRAFT, sans fusion.

## Résultats vérifiés du workflow corrigé — SHA `6f25d6b2d86b7b007adbecf78f6b9b36d7a275f1`

Run GitHub [#42367202003](https://github.com/Xynph/cadrage-debordement/actions/runs/42367202003), job `native-ten-seasons` **COMPLETED/SUCCESS**, 3 tests Node PASS / 0 FAIL, tous les steps SUCCESS (dix saisons, calibration, contrats d'âge et invariant master). La première version du workflow avait une erreur YAML ligne 66, corrigée uniquement sur le fichier CI réservé ; les exécutions rejetées sans jobs ne sont pas des tests sportifs rouges.

**Carrière native :** 10 saisons TOP14, 1 820 matchs réguliers + 50 de finales, 10 imports réussis. Joueurs portant encore la marque V12 dans les 14 clubs : 805 en saison 1, 441 en saison 5, **281 en saison 10** (−65,09 %). Dans les profils V12 survivants, les 18–23 ans passent de 379 en saison 1 à **0** en saison 10 ; cela correspond à l'avancement des cohortes initiales, pas à une absence de nouveaux jeunes dans le jeu. Les effectifs V12 observés en saison 10 sont 181 joueurs de 24–29 ans, 91 de 30–34 ans, 9 de 35 ans et plus. Le petit groupe 35+ interdit toute conclusion populationnelle forte.

**Moyennes d'attributs selon l'âge — coupes transversales de saison 10 :**

| Âge | V12 survivants | Vitesse | Force | Endurance | Décisions |
|---|---:|---:|---:|---:|---:|
| 24–29 | 181 | 64,57 | 75,13 | 77,48 | 72,60 |
| 30–34 | 91 | 61,85 | 74,11 | 75,49 | 75,16 |
| 35+ | 9 | 48,65 | 73,37 | 68,89 | 70,43 |

Comparaison : les survivants de 35+ ont une vitesse moyenne inférieure de **15,92 points** aux 24–29 ans (48,65 contre 64,57), et une force inférieure de **1,76 point** (73,37 contre 75,13). Ce sont des **moyennes de groupes de survivants**, pas une mesure longitudinale du déclin individuel ; les vrais contrats V11 de maturité ont été également testés avec succès.

**Calibration native appariée :** 240 matchs, 8 graines × deux domiciles × 5 scénarios × 3 coefficients expérimentaux. Sélection figée de cinq recrutements et cinq départs, **10 titulaires conservés** dans chaque cas (5 remplacements).

| Coefficient du laboratoire | Promu vs TOP14 fort : victoires | Promu vs TOP14 moyen | Après 5 recrues vs moyen | Gain de marge après recrues | Relégué conservé vs PRO D2 moyen | Relégué après 5 départs | Variation de marge après départs |
|---|---:|---:|---:|---:|---:|---:|---:|
| **0,004 (production)** | 43,75 % | 25,00 % | 25,00 % | **+3,12 pts** | 68,75 % | 68,75 % | **−1,32 pt** |
| 0,008 (hors production) | 18,75 % | 25,00 % | 18,75 % | +1,38 pt | 75,00 % | 81,25 % | +1,81 pt |
| 0,012 (hors production) | 0,00 % | 25,00 % | 12,50 % | +4,69 pts | 75,00 % | 81,25 % | −0,32 pt |

**Explication quantitative :** les cinq recrues relèvent la moyenne de notes des 15 titulaires de **+2,67 points** et celle du banc de **+0,38**. À l'inverse, cinq départs ne dégradent la moyenne des titulaires que de **−0,53 point** et celle du banc de **−1,00**, malgré cinq remplacements de titulaires. L'effectif de relégué testé possède donc encore une profondeur capable de compenser une partie des pertes ; ce test ne démontre pas que le moteur ignore les départs. Le taux de victoire après recrutements reste identique (25,00 %) sur 16 rencontres à coefficient 0,004, **mais la marge moyenne s'améliore de 3,12 points** : ne pas conclure à zéro effet en se fondant sur la seule proportion de victoires.

La victoire du promu-proxy face au meilleur TOP14 (**43,75 %**) est incohérente avec l'intention de hiérarchie et renforce le signal déjà observé sur 64 graines (**40,63 %**) : étudier la composition des adversaires, la pondération qualitative et les effets tactiques avant toute modification. Les sensibilités `0,008` et `0,012` montrent de fortes variations parfois contradictoires sur 16 matchs par scénario, **elles ne justifient pas à elles seules un nouveau coefficient de production**.

### Priorités après cette réception

1. Répéter les scénarios avec au moins 64 graines par contexte et plusieurs effectifs complets, en gardant domiciles/graines appariés.
2. Distinguer **pertes de titulaires clés, pertes de rotation et couverture du banc** : une politique uniforme de cinq départs n'est pas une mesure suffisante de vulnérabilité.
3. Contrôler séparément les trajectoires longitudinales des mêmes joueurs V11 sur plusieurs saisons et le mécanisme de renouvellement de génération.
4. Concevoir la compétition à deux divisions et ses transferts dans une PR gameplay **réservée séparément**, jamais dans cette PR de tests.

L'ensemble est **QA**, non calibration déployée. Ne fusionner qu'après CI générale et gate validés par l'intégrateur.

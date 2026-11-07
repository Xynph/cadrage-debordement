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

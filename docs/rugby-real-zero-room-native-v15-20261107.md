# Rugby Réel V15 — 47 potentiels sans marge, observation native

## Objectif et méthode
La PR #388 a vérifié **47/1592** joueurs dont la marge de potentiel de carrière recalculé est nulle, sans conclure à une anomalie. Ce lot n'ajoute aucune note et n'abaisse aucun niveau : il observe une vraie carrière TOP14 du moteur existant et les sauvegardes natives.

Le test `tests/rugby-real-zero-room-native-v15-20261107.cjs` recalcule la liste exhaustive des 47 identifiants à partir du catalogue actif `dist/lnr-ratings-v12.js`. Il démarre une carrière réelle LNR dans `tests/harness.cjs`, vérifie `dev.potential` après initialisation, puis déroule **6 saisons natives**, 26 journées régulières et les phases finales par saison, avec export/import `createSaveDocument` / `parseSaveDocument` après chaque changement de saison (6 passages). Pour chacun des joueurs de la cohorte **instanciés dans le TOP14 jouable**, il enregistre individuellement âge, note, potentiel, vitesse, force, décisions, activité, présence/absence et club, en fin de saison et après reprise de sauvegarde. Les événements de changement de club et de sortie d'effectif sont mesurés ; les mécanismes de recrutement natifs restent inchangés.

## Limite fondamentale
Le jeu LNR ne simule actuellement que les **14 clubs TOP14** comme carrière active. Les joueurs de PRO D2 présents dans le catalogue mais non instanciés ne peuvent pas avoir de vraie trajectoire multi-saisons observée par ce banc sans modification du moteur ou des effectifs. Le test rapporte explicitement les 47 identifiants et le nombre absent de la carrière native plutôt que d'inventer des parcours.

La carrière conserve les mêmes équipes, paramètres et lois que le jeu : aucune modification de moteur, mutation du registre, recrutement forcé ou transfert factice. Les statistiques publiées dans les logs ne valent preuve de recrutement que lorsqu'un changement de club est réellement observé. Un départ d'effectif n'est pas automatiquement une retraite, ni une preuve d'erreur de potentiel. Les joueurs survivants sont affectés par le biais de sélection.

## Critères de décision
Ne proposer un ajustement individuel de potentiel que si le joueur présente une incohérence de progression **répétée et reproductible sur des saisons natives**, non expliquée par l'âge, l'absence de temps de jeu, l'évolution des 36 attributs, le départ du club ou la disparition à la retraite. Une marge de note nulle n'est pas un motif suffisant. Les 47 dossiers restent initialement `no-change / observation`. Les tests doivent être reçus sur le SHA final de la PR avant toute conclusion empirique.

## Gouvernance
Base `main` au démarrage : `044e83d2a9f860d59c2aeac2a22df94235bf04c9`. PR DRAFT strictement diagnostique. Fichiers nouveaux exclusivement : ce rapport, deux tests dédiés et le workflow. Aucun `dist/**`, master, DATA/LNR, effectif, identité, club, calendrier, interface, MATCH3D, moteur, sauvegarde ni autre PR modifié. Sans fusion.

## Exécution
`node --test tests/rugby-real-zero-room-native-v15-20261107.cjs tests/rugby-real-zero-room-calibration-v15-20261107.cjs`

Le workflow GitHub `Rugby Reel - zero-room native V15 QA` exécute la commande sur GitHub Actions. Ne pas revendiquer un résultat avant consultation des logs terminaux.

## Réception réelle — campagnes GitHub

**HEAD initial** `c4d984af5565026525b23b0939a12320f7dac269` : workflow spécialisé [#42371132248](https://github.com/Xynph/cadrage-debordement/actions/runs/42371132248) **SUCCESS (2 tests PASS)**, général [#42371132157](https://github.com/Xynph/cadrage-debordement/actions/runs/42371132157) **7/7 SUCCESS**. Exécution du vrai moteur de carrière, **6 saisons**, 6 cycles export/import. Cohorte initiale **22 joueurs TOP14** parmi 47 marges nulles, les **25 autres** PRO D2 ne sont pas instanciés dans les clubs de la carrière. Les présents fin de saison 1→6 : **22, 13, 10, 6, 6, 3**. **1 transfert de club observé** au sein de cette cohorte, **21 disparitions de l'effectif observé** après transitions (ne pas assimiler systématiquement aux retraites). L'âge initial des 22 présents s'étend de **29 à 39 ans** ; aucun n'a moins de 26 ans. La note globale reste constante dans les observations de ce banc, malgré le déclin d'attributs. Parmi les six suivis au moins trois années d'âge, la vitesse baisse en moyenne de **7,335 points** ; cette moyenne souffre d'un fort biais de survivants.

**HEAD expérimental** `5f6a74e2438f9cfca1fa1ea809dd05420a96976c` : QA dédié [#42371578862](https://github.com/Xynph/cadrage-debordement/actions/runs/42371578862) **SUCCESS, cinq tests PASS**. Nouveau banc `tests/rugby-real-zero-room-calibration-v15-20261107.cjs` utilisant **les attributs de départ réels et les âges 2026 de la BDD**, sans fabriquer une jeunesse à 18 ans. Les **47 profils** sont répartis en 22 TOP14 + 25 PRO D2 ; âges de **29 à 39 ans** en TOP14 et **29 à 36** en PRO D2. Les **1 592** âges se répartissent en 889 joueurs de 25 ans ou moins, 395 de 26–29 ans et 308 de 30 ans et plus. Ce classement montre que les 47 marges nulles concernent des joueurs expérimentés, non des jeunes à fort développement attendu.

### Comparaison de calibrations individuelles non destructives

`LNR_V11_AGE.step` et `lnrProjectV12` sont appelées **sans aucune duplication des formules de progression**. Sur 47 joueurs × 6 ans × 4 variantes = **1 128 transitions** :
- potentiel recalé **inchangé** vs bonus individuel **+2** vs **+4** ; exposition habituelle 1600 min/an, entraînement 100 %, sans blessure ni fatigue ;
- potentiel inchangé et exposition nulle pour isoler l'effet de l'activité ;
- **0/47 changement de note entière projetée** entre contrôle et +2, **0/47** entre contrôle et +4 ;
- gain moyen de la moyenne des 11 compétences : seulement **+0,007** point avec +2, **+0,012** avec +4. La modification est pratiquement sans effet sur ces joueurs âgés et ne mérite **aucune hausse de potentiel** ;
- perte de vitesse moyenne contrôlée sur six passages : **11,63 points**, également 11,63 avec zéro exposition. À cet âge, la courbe physique de déclin domine le développement par entraînement ;
- gain moyen des décisions : **+0,175** point ; maintien relatif du mental comparé au physique.

Le calcul de notation projetée ici est une **comparaison de scénarios sur copies**, et non une carrière native complète. Les joueurs ne sont pas maintenus artificiellement en activité dans la vraie carrière ; le banc contrôle ce que ferait le vieillissement *s'ils restaient* pendant six ans, sans simuler le marché ni les retraites.

### Cohorte complète — progression par tranche d'âge et division

Sur **1 592 × 4 ans × 3 scénarios = 19 104 transitions** (activité 1600 min, inactivité, potentiel candidat +3) :

| Âge au départ 2026 | Joueurs | Δ note projetée après 4 ans, actif | Δ vitesse, actif | Δ décisions, actif |
| --- | ---: | ---: | ---: | ---: |
| ≤25 | 889 | +2,431 | +0,920 | +2,508 |
| 26–29 | 395 | −0,190 | −3,716 | +1,067 |
| 30–34 | 279 | −1,355 | −6,701 | +0,304 |
| 35+ | 29 | −2,069 | −8,576 | −0,030 |

Sur les **805 TOP14**, note moyenne projetée +1,154 sur quatre ans, vitesse −1,475 ; **787 PRO D2**, +0,914 et −2,009. Les moyennes de progression sont influencées par la distribution d'âges et ne doivent pas être interprétées comme une convergence des deux divisions ; les niveaux de départ gardent leur différence. Avec un potentiel candidat **+3**, seulement **5 TOP14 + 9 PRO D2** changent d'une unité entière de note projetée : gonfler globalement le potentiel ne règle pas la progression du jeu. Les 11 postes sont tracés dans le log du run #42371578862 ; leurs Δ moyens de note varient ici de **+0,698 (ailier)** à **+1,378 (demi d'ouverture)** sur quatre ans, mélanges d'âges non ajustés.

### Problème structurel possible — note entière et variations cumulées

Le code moteur lu dans `dist/development.js` applique après chaque saison `p.rating=Math.round(old+skillAfter-skillBefore)` et met à jour la base des compétences. Cela **pourrait effacer les pertes annuelles inférieures à 0,5 point**, même lorsqu'elles s'accumulent sur plusieurs saisons. Les notes globales inchangées dans la première campagne native, malgré des baisses visibles de vitesse, justifient de vérifier directement la dérive de la moyenne des 11 compétences au sein de chaque joueur (extension native actuelle). Toute correction de ce calcul relève cependant de `dist/development.js` : **moteur explicitement réservé, aucune intervention de ce lot**.


### Confirmation native — perte de niveau masquée par l'arrondi

Sur HEAD `4392d015e6d9d930250cef4e012aaa0564a3d25d`, QA dédié [#42371670739](https://github.com/Xynph/cadrage-debordement/actions/runs/42371670739) **SUCCESS, 5/5 tests**. Le banc a suivi la **moyenne des 11 compétences natives** en parallèle de `rating`, ainsi que l'historique des départs, après sauvegardes natives. Parmi 21 sorties observées de la cohorte TOP14, **13 retraites confirmées** dans `S.development.retired` ; **8 autres sorties** non classées comme retraite (sans inventer transfert/fin de contrat lorsqu'on n'a pas le journal complet). **Un changement de club** est observé chez un joueur encore présent. La classification doit rester limitée au périmètre de cette cohorte, pas à toutes les transactions du jeu.

Sur les **13 joueurs suivis pendant au moins une transition d'âge**, la **note entière est inchangée (13/13)** malgré une **baisse de la moyenne des compétences projetées (13/13)** de −0,301 à **−2,247 points**. Exemple le plus net : `lnr:13735`, six ans de progression observée, vitesse **73 → 62,6**, moyenne des 11 compétences **−2,247**, note globale **76 → 76** et transfert Montpellier → Bordeaux dans la vraie carrière. `lnr:13598` : cinq ans, moyenne des compétences −1,805, note globale inchangée. Cela confirme que les baisses d'attributs existent en jeu, mais que l'arrondi saisonnier ne transmet pas intégralement leur **cumul** à la note entière.

Le mécanisme exact du code `p.rating = clamp(Math.round(old + skillAfter - skillBefore),20,97)` suivi du ré-ancrage `p.skillBase=p.rating` permet qu'une baisse inférieure à 0,5 par saison reste invisible indéfiniment dans la note globale. **Constat de cohérence à qualifier :** la note interne `rating` ne conserve pas les fractions saisonnières, mais le jeu utilise également `roleNote(p)`, calculée à partir des **compétences qui évoluent réellement**. Il faut vérifier cette note jouable avant de classer le phénomène comme défaut sportif ou d'en déduire une correction moteur. Ce n'est **pas une erreur des 47 potentiels** et ce producteur ne touche pas au moteur. Une correction de la BDD en augmentant/diminuant les notes initiales masquerait le défaut et ferait évoluer rétroactivement les niveaux de départ de joueurs corrects.

**Décision consolidée :** 0 hausse de potentiel et 0 retouche de note active ; conserver les 1592 fiches. Conserver un point de vigilance pour l'intégrateur sur la **conservation du résiduel fractionnaire** de la note interne, mais ne recommander une modification que si des conséquences négatives sur la note au poste, le recrutement ou les comparaisons d'effectif sont réellement reproduites, en préservant les sauvegardes anciennes.

## Décision de calibration

**47/47 potentiels inchangés, aucune hausse individuelle retenue.** La cohorte ne montre aucun cas de jeune joueur à marge nulle. Le bonus +2/+4 ne résout pas l'évolution des profils âgés et ne doit pas être appliqué à la BDD 2026–2027. Les écarts TOP14/PRO D2 doivent être jugés par des vrais scénarios d'effectifs et de matchs, non corrigés indirectement via les potentiels. Les **240 matchs natifs** et les scénarios avec cinq recrues/départs existants dans `tests/rugby-real-long-career-qa.cjs` restent la référence complémentaire ; ils ne modélisent pas une vraie promotion/relégation dans une ligue TOP14/PRO D2.

**Statut de la branche : DRAFT, aucun changement de données de production, aucune fusion.** Les résultats de l'extension finale devront être reçus sur son propre SHA : le vert des HEAD antérieurs ne qualifie pas rétroactivement un commit ultérieur.

### Réception décisive — la note jouable réagit au vieillissement

Le banc a été étendu à `roleNote(p)`, le score effectivement calculé à partir des compétences via `dist/rugby.js` (`skill()` et pondération de poste), qui détermine aussi `fitScore` et la sélection de la feuille de match. La QA dédiée [#42371836187](https://github.com/Xynph/cadrage-debordement/actions/runs/42371836187) sur HEAD `04c2a57c2f5e95edac011b44a271bcaa19499c80` a **réellement terminé avec 5 tests PASS**.

Sur les **13 profils** observés pendant une ou plusieurs intersaisons, `rating` interne reste constant mais la **note au poste diminue chez 8 joueurs**, les **5 autres restant stables** en note entière. Aucune progression de note au poste dans cette cohorte vieillissante. Exemple `lnr:13735` : `rating` 76→76, moyenne des 11 compétences −2,247, **note au poste −3**, vitesse −10,4 ; `lnr:603` : note au poste −2 en deux ans. **Le déclin influence donc réellement la force de l'équipe et les sélections** : le problème initial de « déclin absent » était une interprétation erronée de la seule variable `rating`. Reste uniquement un décalage numérique possible si un écran ou une évaluation exploite `rating` brut plutôt que `roleNote`. Aucune intervention du producteur BDD sur ce sujet réservé.

**Verdict scientifique du lot :** aucun des 47 dossiers ne mérite une hausse arbitraire ; les simulations d'âge corroborent un déclin rapide du physique après 30 ans, une meilleure conservation mentale et des notes de poste qui évoluent en carrière. Les écarts TOP14/PRO D2 sont conservés, aucune BDD active réécrite. Le moteur à deux divisions n'existant pas en carrière jouable, aucune assertion de taux réel de montée/descente n'est formulée.


---

## Extension approfondie : véritable BDD active, recrutement, départs et hiérarchie sportive

### Méthode distincte du candidat V12

Le nouveau banc `tests/rugby-real-division-roster-sensitivity-v15-20261107.cjs` recharge les **1 592 profils de la BDD ACTIVE** `dist/lnr-ratings-v12.js` dans le laboratoire existant `tools/rugby-real-v12/native.cjs`. Pour chaque ID, il substitue les 36 attributs, **les 11 compétences réellement actives** et la note entière de production ; il ne réutilise pas le JSON candidat pour calculer les niveaux des équipes. Les 30 clubs et leurs identifiants restent inchangés. La fonction de feuille à 23 `buildSheet`, la note au poste `roleNote` et les rencontres `createRugbyMatch/advanceRugby` sont celles du jeu. Les transferts sont des **copies de laboratoire**, jamais des transferts réels de carrière. Donneurs exclus de l'opposition pour éviter qu'un joueur se retrouve des deux côtés ; postes respectés et 15 titulaires + 8 remplaçants contrôlés.

**Premier run** [#42372718021](https://github.com/Xynph/cadrage-debordement/actions/runs/42372718021) : 7 tests PASS et **240 matchs** ; extension de robustesse [#42372855827](https://github.com/Xynph/cadrage-debordement/actions/runs/42372855827) : 7 tests PASS, **576 matchs**. Extension appariée [#42373101182](https://github.com/Xynph/cadrage-debordement/actions/runs/42373101182) : 8 tests PASS, **576 matchs de mouvements + 288 confrontations interdivision**. Ces essais sont des campagnes successives, pas 1 680 matchs indépendants ; les mêmes cas sont rejoués pour gagner en précision.

### Ce que mesurent les compositions réelles

| Cohorte de XV titulaires, calculée avec notes actives | Nombre de clubs complets | Moyenne | Minimum | Maximum |
| --- | ---: | ---: | ---: | ---: |
| TOP14 | 14 / 14 | **78,45** | 77,73 | 80,33 |
| PRO D2 | 11 / 16 | **70,31** | 70,00 | 70,87 |
| Écart des moyennes de XV | — | **8,14** | — | — |

Les **cinq feuilles PRO D2 non complètes dans ce laboratoire** sont un problème de disponibilité par *poste simulé* (15+8), non une preuve que cinq effectifs officiels LNR manquent de joueurs. Les groupes de poste historiques sont approximatifs et il ne faut pas en profiter pour réécrire le master. Le TOP14 a des XV beaucoup plus resserrés entre clubs qu'une hiérarchie sportive forte ne le supposerait (écart max/min **2,60**), et la PRO D2 encore davantage (**0,87**) : **piste de calibration à examiner par poste et preuves**, pas permission de rajouter arbitrairement un bonus de club.

### Recruter le bon niveau plutôt que gonfler toute la division

Référence : équipe complète de PRO D2 la mieux notée dans le banc (Provence Rugby), 70,87 de moyenne XV. Recrues **ordinaires** plafonnées au 75e percentile de la distribution TOP14 du **même poste** ; recrues « très fortes » sans ce plafond pour mesurer une stratégie plus coûteuse, **sans coût salarial simulé**. Les joueurs proposés sont identifiés dans les logs et ne sont pas appliqués.

| Composition du promu-proxy | Moyenne XV | Contre TOP14 médian : victoires | Marge |
| --- | ---: | ---: | ---: |
| Sans recrue | 70,87 | **20,83 %** | −6,02 |
| +2 recrues ordinaires | 71,87 | 27,08 % | −4,46 |
| +5 recrues ordinaires | 73,27 | 29,17 % | −4,27 |
| +2 recrues très fortes | 72,67 | 29,17 % | −4,60 |
| +5 recrues très fortes | 74,80 | 39,58 % | −1,08 |

**Effets appariés sur 24 graines × deux domiciles** (IC exploratoires à 95 % regroupés par graine) : cinq ordinaires **+1,75** point de marge [−0,83 ; +4,33] ; cinq très fortes **+4,94** [**+1,92 ; +7,96**]. Cela soutient le comportement visé : un promu peut améliorer ses chances sans gagner mécaniquement contre le TOP14 moyen. L'effet statistique des recrues ordinaires est incertain ; ne pas présenter ces intervalles comme des garanties sur une saison complète.

Le relégué-proxy (équipe TOP14 au XV le moins fort, Clermont) part de **77,73** points contre un adversaire médian PRO D2 : **70,83 % de victoires**, marge +6,33. Après cinq départs de titulaires : XV **76,00**, **60,42 % de victoires**, marge +4,21, soit delta apparié **−2,12** [−5,84 ; +1,59]. Après cinq départs de remplaçants : XV titulaire identique **77,73**, banc de 73,88 à 72,75, delta de marge **−0,23** [−1,02 ; +0,56]. Ce dernier scénario mesure une rencontre fraîche, **pas** les conséquences accumulées d'une rotation, fatigue ou blessure sur une saison entière ; les six saisons natives ci-dessous complètent mais ne remplacent pas un test de saison appariée après modification du banc.

### Robustesse : 9 oppositions croisées, 288 matchs supplémentaires

Trois PRO D2 de qualités distinctes (Agen, Angoulême, Provence) affrontent trois TOP14 (Clermont, Lyon, Toulouse) sur **16 graines × deux domiciles** chacune. Les neuf marges PRO D2 sont négatives (−2,59 à −6,97) : le niveau de division existe. Mais l'ordre des résultats n'est **pas monotone** selon la seule moyenne XV : face à ces trois adversaires, Toulouse (80,33) ne les écrase pas davantage que Lyon (78,33), malgré sa note de XV supérieure. Ce constat peut provenir des combinaisons d'attributs, postes, tactiques, hasard de graines et du poids du moteur ; **il ne prouve pas qu'un joueur toulousain ou lyonnais est mal noté**. Ce signal doit être étudié par un audit technique autorisé séparément du moteur ou par des échantillons plus vastes. Ne pas corriger des identités ou un club entier pour forcer le classement attendu.

### Vraie carrière TOP14 : six saisons, renouvellement de l'effectif et sauvegardes

Le test natif réutilise 26 journées × 7 rencontres × 6 saisons, soit **1 092 matchs réguliers**, plus phases finales ; six exports/imports de sauvegardes natives. Le jeu démarre déjà avec **`aiRosterActive()` actif** ; un test séparé qui le « réactivait » doublait inutilement la même campagne et a été retiré. Le test suit directement les rapports `S.aiRoster.reports` et les lectures **après l'intersaison**, étape pendant laquelle `settleContracts()` enregistre aussi les prolongations.

Parmi les **13 clubs contrôlés par l'IA** (hors club du manager laissé sans décision), la moyenne XV est **78,44 au début et 78,70 après six intersaisons** ; la profondeur de banc moyenne évolue elle aussi. Le club du manager laissé sans renouvellement ni intervention passe séparément de XV **76,40 à 70,93** et de **50 à 23 joueurs** : **ne surtout pas assimiler cet effet de non-gestion à une dérive automatique de toute la BDD**. Globalement les 14 clubs conservent des feuilles complètes dans ce scénario. Les profils initiaux LNR encore présents passent de **805 à 349** au début de la septième saison, par renouvellement des générations, contrats, retraites et transferts ; leur disparition de la première liste n'est pas une perte d'identité du catalogue source.

Les rapports IA comptent au moins sur les saisons suivies : **1 415 opérations de prolongation, 391 libérations, 35 retraites**, et les recrutements/promotions sont mesurés par saison. Ce sont des **événements**, pas autant de joueurs uniques. Les événements du début de S7 doivent être comptabilisés à part des six saisons achevées pour éviter toute incohérence. Le dernier run GitHub vérifie cette séparation.

### Arbitrages retenus

1. **Aucune augmentation de notes ou potentiels de production** : l'écart moyen entre divisions est déjà sensible ; ajouter un bonus TOP14/malus PRO D2 global serait arbitraire. Les cinq recrutements ordinaires renforcent le promu-proxy, les départs pénalisent le relégué-proxy dans le sens souhaité, mais les bandes de confiance limitent les conclusions causales.
2. **Piste BDD prioritaire : diversité intra-division**, notamment PRO D2 et entre XI/XV titulaires et banc ; recueillir des preuves individuelles/postes et éviter d'imposer un classement par des bonus collectifs à tous les joueurs.
3. **Piste gameplay distincte : concordance note XV / moteur** lorsque des équipes plus fortes sur le papier produisent des résultats non monotones. Hors du périmètre de ce producteur ; pas de modification moteur ni coefficient tactique.
4. **Conserver les 1 592 profils et les contrats existants**. Les propositions de mouvements sont des cas de laboratoire, non des engagements sportifs réels, et ne modifient pas la composition du mod.

Aucune carrière native senior à deux divisions avec montées/relégations n'existe sur la branche de référence ; aucune statistique de maintien ou remontée réelle n'est avancée. Le jeu repose sur des notes estimées, non des notations officielles. Les salaires et le coût des joueurs « recrutés » du laboratoire ne sont pas soumis aux règles de marché en carrière ; les rapports de recrutements IA natifs couvrent ce comportement séparément.

**Périmètre de la PR #389 inchangé** : trois tests nouveaux, ce rapport et le workflow dédié. Aucun `dist/**`, master, LNR, identité, effectif, calendrier, moteur, sauvegarde, interface, MATCH3D ni autre branche modifié. DRAFT exclusivement, **aucune fusion**. Les verdicts du dernier HEAD doivent être reçus indépendamment de ceux cités ci-dessus.


---

## Extension V15 — audit des écarts de clubs par poste et du lien 36 attributs → 11 compétences

### Analyse exhaustive sur la BDD active

Le nouveau test \`tests/rugby-real-role-contribution-v15-20261107.cjs\` utilise les **1592 joueurs actifs** issus de \`dist/lnr-ratings-v12.js\`, les 36 attributs et 11 compétences réellement chargés, puis le \`roleNote\` natif pour les joueurs titularisés. La QA GitHub [#42374364955](https://github.com/Xynph/cadrage-debordement/actions/runs/42374364955) est **SUCCESS**, **10/10 tests** (y compris les tests préexistants de la PR). Les 36 attributs ne sont **pas** directement tous pondérés dans la note au poste : \`roleNote\` utilise les 11 compétences du joueur et les pondérations par famille de poste.

**Compression statistique observée :**
- Écart entre les clubs en écart type de moyenne XV, pour les feuilles 15+8 complètes : **0,593** point TOP14 (14 clubs), **0,248** point PRO D2 (11 clubs). Les plages de moyennes sont TOP14 **77,733 à 80,333**, PRO D2 **70,000 à 70,867**.
- À l'intérieur d'un seul XV, écart-type des notes de poste des titulaires généralement **1,9 à 3,3** points (exception Toulouse **4,16**). Les variations entre joueurs existent et sont beaucoup plus larges que les moyennes *entre clubs* : composition poste par poste + sélection des meilleurs XV + moyenne arithmétique **lissent** les écarts collectifs.
- Écart TOP14 moins PRO D2 des compétences chargées : **+8,61** pour \`pass\`, **+8,33** pour \`tackle\`, **+7,56** pour \`power\`, **+6,79** pour \`speed\`, mais seulement **+2,34** pour \`goal\` et **+1,23** pour \`discipline\`. Ce profil est hétérogène et peut influencer les séquences de match au-delà de la seule moyenne XV. Il n'existe donc aucune justification à ajouter un malus identique à toutes les compétences des 787 joueurs PRO D2.
- Sur les 36 attributs, l'écart de division va de **+0,71 en leadership** à **+9,35 en ballCarry** ; l'incertitude sur les sources et la réalité de certaines notes exige de ne pas interpréter ces contrastes comme un étalonnage officiel.

### Expérience de corrections individuelles sur copies

Cinq titulaires de Provence Rugby, choisis parmi les notes de poste les plus basses et sur cinq rôles distincts : \`lnr:1415\` (centre), \`lnr:2058\` (deuxième ligne), \`lnr:13418\` (talonneur), \`lnr:13465\` (troisième ligne), \`lnr:1424\` (pilier gauche). Le scénario **purement expérimental** augmente de **+5** chacun de leurs cinq attributs dominants par poste, sans modifier les autres joueurs, sans transfert ni changer le moteur. Il compare (A) BDD active, (B) modification des seuls 36 attributs, (C) modification des 36 attributs **plus synchronisation des 11 compétences** par la différence de projection V12 du même individu.

| Cas face au TOP14 médian Lyon, graines appariées | Moyenne XV | Effet de marge sur le score |
| --- | ---: | ---: |
| BDD active | **70,867** | référence (−5,75) |
| +5 sur attributs seulement | **70,867** | **0,000** [0,000 ; 0,000] |
| +5 attributs et compétences synchronisées | **71,667** | **−0,344** [−1,905 ; +1,218] |

Cette preuve pratique montre qu'une *simple édition des attributs* sur un profil déjà chargé avec \`skills\` ne modifie **pas** les notes de poste et les résultats de cette expérience de matchs, mais qu'une calibration cohérente doit conserver l'alignement entre les deux représentations. La hausse synchronisée donne de vraies notes au poste plus élevées, mais **ne démontre pas encore un bénéfice statistique en match**. Ne surtout pas corriger 1592 joueurs en doublant leurs compétences à l'aveugle ; il faut comprendre d'abord les conventions et les traitements de projection déjà installés.

Les cinq cas ne prouvent **aucune sous-notation personnelle** : la correction est une sensibilité fictive, non une recommandation d'augmentation. Une dose plus élevée et plusieurs adversaires doivent être comparés avant conclusion ; la suite est dans le test spécialisé.

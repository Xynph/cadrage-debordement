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

# Idées GitHub à récupérer dans le jeu Windows Godot

Audit du 8 novembre 2026 — [main 3fe6d160](https://github.com/Xynph/cadrage-debordement/commit/3fe6d160a34a9bf3b19005eaef003ac4b1e4ec21). **18 familles et 31 candidats**, aucun candidat neuf qualifié prêt. Lecture seule du dépôt : aucun commit, push, commentaire ou test produit exécuté.

Les priorités explicites comprennent toute la presse, les rivalités et la formation. Le centre de 15 Espoirs est déjà actif mais caché ; la presse et plusieurs rivalités sont présentes dans le web mais exclues du worker. Le dossier adverse, les conseils/bilans tactiques, le recrutement et les décisions financières restent aussi des gains concrets. Le travail consiste surtout à donner à Godot un accès contrôlé à des fonctions éprouvées. Plusieurs anciennes PR ouvertes sont déjà reprises par d’autres intégrations : les fusionner à nouveau serait une erreur.

## Base de preuve

**120 PR ouvertes recensées avec pagination** : page1 100, page2 20 et page3 0. Les anciennes PR #40–#72 ont été prises en compte, en plus des derniers lots. Corps des PR demandées, issue [#365](https://github.com/Xynph/cadrage-debordement/issues/365), README/docs, états de fusion REST et fichiers des SHA exacts lus via objets Git locaux ont été comparés à main. Les corps peuvent conserver des indications DRAFT historiques ; le code et l’état merged actuel prévalent.

La chaîne Windows est [worker.cjs](https://github.com/Xynph/cadrage-debordement/blob/3fe6d160a34a9bf3b19005eaef003ac4b1e4ec21/native/engine/worker.cjs) → [model.cjs](https://github.com/Xynph/cadrage-debordement/blob/3fe6d160a34a9bf3b19005eaef003ac4b1e4ec21/native/engine/model.cjs) / [gestion.cjs](https://github.com/Xynph/cadrage-debordement/blob/3fe6d160a34a9bf3b19005eaef003ac4b1e4ec21/native/engine/gestion.cjs) → [vues Godot](https://github.com/Xynph/cadrage-debordement/tree/3fe6d160a34a9bf3b19005eaef003ac4b1e4ec21/native/godot/ui). [Le constructeur](https://github.com/Xynph/cadrage-debordement/blob/3fe6d160a34a9bf3b19005eaef003ac4b1e4ec21/scripts/build-godot-prototype.py) copie seulement CORE_FILES et les actifs choisis. La présence dans dist/index.html ne prouve donc pas une fonctionnalité Windows. Le parent vérifie le manifeste de livraison ; cet audit compare le main indiqué, sans désassembler ni recevoir à nouveau l’EXE.

Le modèle expose déjà effectif, attributs, contrats, charges, sélection, marché, tactiques principales, calendrier, classements, archives françaises, finance simple et direct. Les commandes comprennent set_tactics, set_player_load, recruit, extend_contract, next_season, substitute et promote_cover. Aucune commande ne permet dossier adverse, consigne de zone, scouting, budget académie, achat d’installation, mobilité manager, vestiaire ou billetterie.

## Synthèse

| Famille | État Windows | Bénéfice joueur | Priorité / coût |
|---|---|---|---|
| F01 BDD cohérente et qualifications | V12/V11 déjà actifs ; audit V16 isolé | Commencer une carrière avec des postes, contrats et écarts de niveau crédibles. | P1 / Moyen à élevé |
| F02 Préparation tactique et dossier adverse | Calculs moteur chargés, projections et commandes Godot absentes | Choisir un plan à partir des forces adverses et des matchs observés. | P1 / Moyen |
| F03 Analyse en direct et bilan des choix | Logique active, UI Godot partielle ; #269 supplantée | Comprendre ce qui marche et modifier ses consignes à la pause. | P1 / Moyen |
| F04 Recrutement et gestion à trois saisons | Moteur chargé, marchés/contrats simples déjà Godot ; outils avancés absents | Chercher un profil pour un besoin réel et anticiper les fins de contrats. | P1 / Moyen |
| F05 Formation, trajectoires et générations | 15 Espoirs/an actifs sans interface ; V72 et V73–V104 web exclus du worker | Faire progresser des jeunes avec une trajectoire lisible et retrouver les générations passées. | P2 / Élevé pour le tout ; moyen pour un dossier |
| F06 Staff sportif et médical ; identités réelles | Modules web exclus du worker ; staff réel/photos = nouveau chantier | Donner des rôles compréhensibles au staff et des conseils reliés à l’effectif. | P1/P2 / Moyen pour le conseil ; élevé pour staff réel complet |
| F07 Direction sportive et objectifs annuels | Déjà intégré web via #328, absent worker et Godot | Avoir un cap de saison et un bilan des décisions. | P2 / Moyen |
| F08 Finances utiles et investissements | Actions moteur chargées, cockpit web intégré #367 ; E3.7 R&D isolée | Voir les engagements réellement connus et financer formation/installations. | P2 / Moyen pour le portage ; très élevé pour noyau E1 |
| F09 Vestiaire vivant et engagements | Déjà intégré web #334 ; exclu du worker | Prendre quelques décisions humaines et suivre leurs conséquences. | P2 / Moyen à élevé |
| F10 Monde interclubs : événements, réactions et pression | Archives françaises Godot livrées ; mémoire narrative web #336 absente | Faire vivre les rivalités et retrouver l’histoire d’une longue carrière. | P2 / Moyen à élevé |
| F11 Carrière du manager et marché des entraîneurs | Mobilité native historique chargée mais inaccessible Godot ; prototypes V58 non raccordés | Changer de club sans recommencer l’univers et suivre un parcours d’entraîneur. | P3 / Élevé |
| F12 Supporters et activité commerciale | Déjà intégré web #328 ; module absent worker | Choisir une politique d’accueil et voir la fidélité évoluer. | P3 / Moyen |
| F13 Match 3D, corps et contacts | Prototypes V24/V25 non intégrés ; qualité non qualifiée | Rendre les joueurs, la passe et le contact plus lisibles et crédibles. | P3 — R&D bloquée / Très élevé |
| F14 Coach BD et voix | Déjà livré ; voix finale et conseil contextuel restent à produire | Comprendre les écrans et les décisions sans sortir du jeu. | P2 — amélioration / Faible à moyen |
| F15 Studio UI premium et concepts visuels | Atelier React isolé ; carnet Godot a déjà repris plusieurs concepts | Améliorer la hiérarchie des fiches et comparaisons. | P3 — sélectionner / Faible pour une idée ; élevé pour un remplacement |
| F16 Presse, conférences et journal rugby | Sept modules presse actifs web ; tous exclus du worker | Lire les faits du championnat et répondre aux journalistes avec des conséquences suivies. | P1/P2 / Moyen pour journal ; élevé pour conférence intégrale |
| F17 Sponsors et conseil de direction | Sponsor et revues actifs moteur ; inaccessibles Godot | Choisir entre revenu stable, avance et prime sportive, puis comprendre le bilan de direction. | P2 / Moyen |
| F18 Rivalités historiques, palmarès et records | H2H et historique chargés ; archives Godot partielles ; dynasties/records complets non attestés | Retrouver les confrontations, titres et grandes saisons sans inventer le passé absent. | P2 / Faible à moyen pour H2H ; élevé pour mémoire complète |

## PR anciennes : reprises, supplantées ou isolées

| Référence fusionnée vérifiée sur GitHub | Preuve de reprise | Conséquence |
|---|---|---|
| [#328](https://github.com/Xynph/cadrage-debordement/pull/328) · [fd1727ef](https://github.com/Xynph/cadrage-debordement/commit/fd1727ef7fa55d473a4d77ef527ace9d469303d0) | 325–327 repris par blobs identiques sur main ; anciens textes DRAFT conservés | Extraire depuis main ; ne pas refusionner la branche ancienne. |
| [#379](https://github.com/Xynph/cadrage-debordement/pull/379) · [48466bfa](https://github.com/Xynph/cadrage-debordement/commit/48466bfa45c34de1504f532e5802e2b88c35ee3e) | 374/377/378 déjà consolidées ; V12/V11 actifs et compilés dans base commune | Extraire depuis main ; ne pas refusionner la branche ancienne. |
| [#247](https://github.com/Xynph/cadrage-debordement/pull/247) · [7668da2b](https://github.com/Xynph/cadrage-debordement/commit/7668da2b58d2177a6c1f17de5331747becb9368d) | 229 repris comme modules isolés ; bridge234 écarté | Extraire depuis main ; ne pas refusionner la branche ancienne. |
| [#367](https://github.com/Xynph/cadrage-debordement/pull/367) · [512e2964](https://github.com/Xynph/cadrage-debordement/commit/512e296467985d95284e1c3c3959b23e569019d2) | Cockpit finances web et actions existantes ; pas noyau R&D E1 | Extraire depuis main ; ne pas refusionner la branche ancienne. |
| [#304](https://github.com/Xynph/cadrage-debordement/pull/304) · [2fe9b2fc](https://github.com/Xynph/cadrage-debordement/commit/2fe9b2fc095062c8576164e4a6d082bcf57fce75) | V63 adaptative active, #269 V62 supplantée | Extraire depuis main ; ne pas refusionner la branche ancienne. |
| [#334](https://github.com/Xynph/cadrage-debordement/pull/334) · [bd89594a](https://github.com/Xynph/cadrage-debordement/commit/bd89594a1f4303ba869fca0e82233c66c5bf7600) | Vestiaire V117–V123 web, hors worker | Extraire depuis main ; ne pas refusionner la branche ancienne. |
| [#336](https://github.com/Xynph/cadrage-debordement/pull/336) · [3014774a](https://github.com/Xynph/cadrage-debordement/commit/3014774ab4ca13d1d325756ed89f2bb029b1b99c) | Interclubs V124–V130 web, hors worker | Extraire depuis main ; ne pas refusionner la branche ancienne. |
| [#255](https://github.com/Xynph/cadrage-debordement/pull/255) · [249d4f7a](https://github.com/Xynph/cadrage-debordement/commit/249d4f7a403df1e0ba34a8428ef8aaf38c16a3e4) | Conférences persistantes simples moral/trust web ; hors worker | Reprise de concepts depuis main ; aucun succès futur impliqué. |
| [#256](https://github.com/Xynph/cadrage-debordement/pull/256) · [2cc9bec5](https://github.com/Xynph/cadrage-debordement/commit/2cc9bec5d23f25fbdd10a9bc38f830c0101f3663) | 500questions,conférence interactive,média factuel/chroniques sur main | Reprise de concepts depuis main ; aucun succès futur impliqué. |
| [#313](https://github.com/Xynph/cadrage-debordement/pull/313) · [b5851057](https://github.com/Xynph/cadrage-debordement/commit/b585105767a11d2712a8f3c7e5fd8874387c23eb) | 15Espoirs et plafond75 actifs development.js ; overlayV72 hors worker | Reprise de concepts depuis main ; aucun succès futur impliqué. |
| [#311](https://github.com/Xynph/cadrage-debordement/pull/311) · [493fbb54](https://github.com/Xynph/cadrage-debordement/commit/493fbb546d27cd5528443842c238c4c29de0dc01) | Duos/rivalités joueurs web avec effets sportifs ; hors worker | Reprise de concepts depuis main ; aucun succès futur impliqué. |

Les blobs des modules #325 / #326 / #327 sont **strictement identiques** dans le HEAD source et dans main : respectivement 2cda90e131ac7c162ab4878a3e42e2f4b957d9ee, 89910b7934688301282557490f1e96a260f14698 et 953b10792afa54cd8e92e79b341a89b2696387f6. [Le raccord combiné](https://github.com/Xynph/cadrage-debordement/blob/3fe6d160a34a9bf3b19005eaef003ac4b1e4ec21/docs/v101-v116-combined-reception.md) a ajouté leur chargement web après les modules Espoirs. Ils restent exclus de MODULES Windows. Les docs originales « non chargé » décrivent leurs anciennes PR, pas le web actuel.

V12/V11 des #374/#378 sont déjà actifs depuis #379 et compilés dans la base commune native. Les #388/#389 sont des audits sans activation des candidats. #229 est repris comme bibliothèque via #247, #234 reste un pont web consultatif et la mobilité native existante possède sa propre logique. #269 est supplantée par la défense V63 #304 déjà chargée.

## Candidats techniques exacts

### F01 — BDD cohérente et qualifications

**Sources :** [#379](https://github.com/Xynph/cadrage-debordement/pull/379), [#389](https://github.com/Xynph/cadrage-debordement/pull/389), [#388](https://github.com/Xynph/cadrage-debordement/pull/388), [#374](https://github.com/Xynph/cadrage-debordement/pull/374), [#378](https://github.com/Xynph/cadrage-debordement/pull/378). **État :** V12/V11 déjà actifs ; audit V16 isolé.

**Preuve :** scripts/build-rugby-common.cjs compile les données actives V12 ; worker charge rugby-common-rosters.js et lnr-v11-aging.js ; common-rosters.cjs applique le registre de postes v2. Les scénarios V16 restent dans data/scouting sur la branche #389.

**Coût et risque :** Moyen à élevé. Toucher les attributs ou migrer les carrières avant de lever les contradictions ; corriger plusieurs fois une anomalie déjà couverte par le registre v2.

**Prochaine action :** Réconcilier les 14 anomalies V16 avec les 67 changements de postes v2, puis corriger uniquement les références encore fausses.

- **C01 — Réconcilier postes v2 et anomalies V16.** Fichiers et fonctions : `data/roster-foundation/verified.json ; tools/rugby-real-v16/audit.cjs (#389) ; data/scouting/shadow-v16-20261107.json (#389)`.
  Action : Comparer les IDs et les deux couches pos/fam/gameplayPosition, conserver les quatre dossiers en quarantaine. Ne pas appliquer en bloc les 13 mappings anciens.
  Réception à exécuter : node --test tests/roster-foundation-data.cjs tests/roster-foundation-versions.cjs tests/godot-roster-foundation.cjs ; sauvegarde v1 saison2 et nouvelles carrières v2.

- **C02 — Exploiter la QA de notes et potentiel sans réactiver V12.** Fichiers et fonctions : `tests/rugby-real-position-calibration-v16-20261107.cjs (#389) ; potential-trajectory-v14-20261107.json (#388) ; dist/development.js`.
  Action : Adopter la méthode trainWeek + finishRound, mesurer dev.potential, pas seulement potential historique. Les 393 anciens écarts ne justifient pas une hausse globale.
  Réception à exécuter : Rejouer les neuf dossiers retenus sur le worker commun et les deux divisions ; matcher réellement les feuilles ; campagne longue sauvegarde/import sans sauter la préparation.

### F02 — Préparation tactique et dossier adverse

**Sources :** [#310](https://github.com/Xynph/cadrage-debordement/pull/310). **État :** Calculs moteur chargés, projections et commandes Godot absentes.

**Preuve :** worker charge match-preparation.js et tactical-plans.js ; matchDossier(), dossierScoutSignals(), setCollectiveFocus() existent. model.cjs expose seulement les listes attaque/défense ; preparation() Godot rend ces choix et la charge collective. briefing-strategique-v69.js est web seul : son choix explicite figé au coup d’envoi ajoute des effets tactiques bornés, exigeant une vraie réception moteur.

**Coût et risque :** Moyen. Confondre projection du XV adverse et observation ; modifier RNG ou sauvegarde en ouvrant le dossier.

**Prochaine action :** Ajouter une projection JSON du dossier et des faits observés, puis les boutons explicites de consignes.

- **C03 — Dossier adverse lisible avant match.** Fichiers et fonctions : `dist/match-preparation.js:matchDossier/dossierRecent/dossierScoutSignals ; native/engine/model.cjs ; native/godot/ui/squad_views.gd:preparation`.
  Action : Projection JSON sélective et anonymisable par ID, avec récent observé, menaces pressenties, comparatifs et raisons du conseil ; aucune insertion de HTML web.
  Réception à exécuter : Snapshot/lecture sans changement état/RNG/disque ; cas pas de match et historique incomplet ; 1280/1440/1920.

- **C04 — Consignes par zone et préparation collective.** Fichiers et fonctions : `dist/tactical-plans.js ; dist/playbook.js ; dist/match-preparation.js:setCollectiveFocus ; native/engine/gestion.cjs`.
  Action : Compléter les commandes bornées en réutilisant contrôleurs existants ; garder attaque/défense principales et montrer la priorité d’une consigne locale.
  Réception à exécuter : Tests de consignes existants + aller/retour d’export ; garde pendant direct ; vrai match comparant plan sauvegardé et plan effectif.

- **C30 — Briefing ciblé avec contrepartie.** Fichiers et fonctions : `briefing-strategique-v69.js:v69Evidence/v69Set et wrappers createRugbyMatch/tacticalEdge ; tests/v69-briefing-strategique.cjs`.
  Action : Porter séparément de la simple lecture du dossier ; neutre/pack/espaces/couverture sont de vrais modificateurs figés au coup d’envoi.
  Réception à exécuter : Contexte périmé refusé,pas en direct,pas bonus legacy/auto,contrepartie -0,008 et bonus bornés,export/import live,vrai moteur Godot.

### F03 — Analyse en direct et bilan des choix

**Sources :** [#269](https://github.com/Xynph/cadrage-debordement/pull/269), [#304](https://github.com/Xynph/cadrage-debordement/pull/304). **État :** Logique active, UI Godot partielle ; #269 supplantée.

**Preuve :** opponentDefenceDecision V63 est sur main et chargé ; matchV61Advice(), halftimeAdvice(), debriefNotes(), planUsage existent. model.live expose huit statsRows génériques, mais pas ces diagnostics ni les plans effectifs.

**Coût et risque :** Moyen. Présenter une corrélation comme une causalité ; refaire entrer la politique V62 plus ancienne de #269.

**Prochaine action :** Projeter les conseils V61 et le bilan archivé, conserver V63 et les gardes de pause.

- **C05 — Conseils de pause et infériorité numérique.** Fichiers et fonctions : `dist/match-v61-advisor.js:matchV61Advice ; dist/tactical-plans.js:halftimeAdvice/numericalStaffAdvice ; native/godot/ui/match_screen.gd`.
  Action : Exposer les explications et trois suggestions maximum ; appliquer uniquement une consigne explicitement choisie en pause.
  Réception à exécuter : Aucun RNG consommé par lecture ; gardes presentationPending ; mi-temps, carton, fatigue et match fini.

- **C06 — Bilan tactique après rencontre.** Fichiers et fonctions : `dist/match-preparation.js:debriefNotes/matchDebrief ; S.history[].preparation/planUsage/tacticalStats`.
  Action : Transformer les données déjà enregistrées en JSON puis en carnet natif ; expliquer que les plans ne sont pas comparés à situation égale.
  Réception à exécuter : Ancien résultat sans compteurs ; nouveau match avec changement de plan ; navigation sans mutation ; import/export.

### F04 — Recrutement et gestion à trois saisons

**Sources :** [#312](https://github.com/Xynph/cadrage-debordement/pull/312). **État :** Moteur chargé, marchés/contrats simples déjà Godot ; outils avancés absents.

**Preuve :** manager.js porte createScoutMission(), managerPool(), managerWeek() ; manager-squad.js possède couverture et plan à trois saisons ; transfer-planning.js est chargé. COMMANDS ne propose que recruit/extend_contract pour cette zone. bureau-agents-v71.js est web seul ; ses offres réutilisent negotiateContract mais les coûts annualisés supposent29semaines, à adapter aux34France30.

**Coût et risque :** Moyen. Élargir silencieusement les sources de recrutement ; doubler un suivi de session Godot et les rapports persistants.

**Prochaine action :** Exposer les besoins par poste et les missions, puis la mémoire persistante des suivis.

- **C07 — Besoins par poste et plan à trois saisons.** Fichiers et fonctions : `dist/manager-squad.js ; dist/transfer-planning.js ; dist/academy-planning.js`.
  Action : Montrer couverture, âges et échéances puis ouvrir le marché filtré. Garder distincts contrat initial sourcé et contrat vivant.
  Réception à exécuter : Comparaison des données effectif/contrats réelles ; blessure, mutation et intersaison ; profils anciens sans registre.

- **C08 — Missions de recrutement et rapports persistants.** Fichiers et fonctions : `dist/manager.js:createScoutMission/managerWeek/scoutingReportHTML ; native/godot/ui/management_state.gd`.
  Action : Utiliser les rapports moteur plutôt qu’un second stockage. Les suivis actuels Godot sont seulement de session ; définir le raccord de leur identité.
  Réception à exécuter : Coût exact et annulation/échec disque ; enregistrement/reprise ; disparition du joueur du marché ; plafond effectif 42 visible.

- **C29 — Bureau des agents et stratégies de contrat.** Fichiers et fonctions : `bureau-agents-v71.js:quote/perform ; tests/v71-bureau-agents.cjs ; economy.js:negotiateContract`.
  Action : Porter trois stratégies sur seul négociateur natif ; engagements29semaines à corriger pour34 ; archétypes simulés, pas vrais agents.
  Réception à exécuter : Contre-offre,trois refus,prime uniquement signature,coût34semaines,historique24,échec sauvegarde sans effacer tentatives moteur.

### F05 — Formation, trajectoires et générations

**Sources :** [#313](https://github.com/Xynph/cadrage-debordement/pull/313), [#314](https://github.com/Xynph/cadrage-debordement/pull/314), [#317](https://github.com/Xynph/cadrage-debordement/pull/317), [#325](https://github.com/Xynph/cadrage-debordement/pull/325), [#328](https://github.com/Xynph/cadrage-debordement/pull/328). **État :** 15 Espoirs/an actifs sans interface ; V72 et V73–V104 web exclus du worker.

**Preuve :** development.js est chargé : intakeYouth() ajoute 15 jeunes fictifs couvrant 15 postes, plafond défensif75 ; promoteYouth() existe mais pas dans COMMANDS, model ne projette pas S.development.academy. Le vieux texte formationView « quatre nouveaux » est périmé face à i<15. youth-pathways-v72.js (détection35k/mentorat8k) et V73–104 sont web seuls. V73/V75 simulent44 centres reliés, distincts des deux divisions seniors.

**Coût et risque :** Élevé pour le tout ; moyen pour un dossier. Dépendances V73/V82–V100 et nouvelles données de carrière ; confondre espoirs simulés et vrais jeunes collectés.

**Prochaine action :** Afficher les15 Espoirs natifs et la vraie promotion en premier ; qualifier V72 puis l’écosystème V73–104 séparément.

- **C09 — Dossier individuel de développement.** Fichiers et fonctions : `dist/development.js ; dist/espoirs-coaching-v101-v104.js:advice/path (déjà main #328)`.
  Action : Commencer avec minutes, historique et objectif explicable ; porter uniquement les dépendances nécessaires, sans activer le tournoi Espoirs entier.
  Réception à exécuter : V11 annuel une seule fois ; charge et entraînement ; validation de l’ancien export et absence de création d’état à la lecture.

- **C10 — Centre de formation et mémoire des générations.** Fichiers et fonctions : `dist/espoirs-league-v73.js ; dist/espoirs-career-v82-v85.js ; dist/espoirs-strategy-v95-v100.js ; dist/espoirs-coaching-v101-v104.js`.
  Action : Cartographier V73 à V104 puis sélectionner un parcours cohérent ; l’action promote_cover ne doit pas être rebaptisée centre complet.
  Réception à exécuter : Tests v101-v104/v101-v116 existants adaptés au worker ; 15 saisons réelles et checkpoints ; changements de club ; données/nœuds/5 Mio.

- **C28 — Rendre visibles les15 Espoirs natifs.** Fichiers et fonctions : `development.js:intakeYouth/setupDevelopment/promoteYouth ; ai-roster-cycle.js ; model.cjs`.
  Action : Projeter S.development.academy et ajouter vraie promotion d’un jeune existant. Garder promote_cover distinct : renfort de secours généré.
  Réception à exécuter : tests/development.cjs,ai-roster-cycle.cjs,godot-common-rosters.cjs ;15postes,plafond75,effectif42,contrat,promotion unique,anciennes générations/import/reprise.

### F06 — Staff sportif et médical ; identités réelles

**Sources :** [#326](https://github.com/Xynph/cadrage-debordement/pull/326), [#328](https://github.com/Xynph/cadrage-debordement/pull/328), [#391](https://github.com/Xynph/cadrage-debordement/pull/391). **État :** Modules web exclus du worker ; staff réel/photos = nouveau chantier.

**Preuve :** staff-meeting-v65.js, staff-advisor-v66.js, training-plans-v67.js et medical-decisions-v68.js sont chargés par le web, pas par le worker. Le schéma média v1 cible clubs/players, sans collection staff. #391 concerne les portraits joueurs. manager.js chargé possède déjà delegation.training/lineup et applyStaffPreparation/applyStaffSelection ; aucune commande Godot ne permet de choisir ces délégations.

**Coût et risque :** Moyen pour le conseil ; élevé pour staff réel complet. Attribuer une personnalité fictive à une personne réelle ; confondre mission administrative V106 et effet sportif ; évolution du format pack.

**Prochaine action :** Définir les postes de staff et une fiche sourcée, base anonyme et pack privé séparé ; réutiliser les diagnostics existants.

- **C11 — Conseiller staff et plan de travail.** Fichiers et fonctions : `dist/staff-meeting-v65.js:preview/perform ; dist/staff-advisor-v66.js:diagnostic ; dist/training-plans-v67.js:preview/apply ; dist/medical-decisions-v68.js`.
  Action : Extraire d’abord les diagnostics sans effets ; prévoir explicitement les charges et soins seulement dans un lot moteur reçu.
  Réception à exécuter : Non-mutation/RNG à la lecture ; séance déjà faite, blessé, retour et match en cours ; sauvegarde refusée.

- **C12 — Personnel réel, fonctions et portraits privés.** Fichiers et fonctions : `Nouveau besoin ; native/engine/media-packs.cjs ; native/godot/ui/pack_views.gd ; pack schema cd-identity-pack-v1 clubs/players`.
  Action : Aucun catalogue staff réel réutilisable attesté. Définir IDs stables, fonctions, dates et provenance ; base anonyme puis extension versionnée du pack privé.
  Réception à exécuter : Compatibilité pack v1 et anciennes carrières ; manifestes hostiles et images ; séparation des identités/effets et maintien du mode base.

- **C31 — Délégation entraînement et sélection.** Fichiers et fonctions : `manager.js:setDelegation/applyStaffPreparation/applyStaffSelection ; S.manager.delegation ; gestion.cjs`.
  Action : Permettre les deux responsabilités déjà connues du moteur avec aperçu et retour de l’adjoint ; sans attendre les photos du staff.
  Réception à exécuter : Ordre entraînement puis sélection,application unique,blessés/postes/23joueurs,mutation live refusée,reprise.

### F07 — Direction sportive et objectifs annuels

**Sources :** [#326](https://github.com/Xynph/cadrage-debordement/pull/326), [#328](https://github.com/Xynph/cadrage-debordement/pull/328), [#68](https://github.com/Xynph/cadrage-debordement/pull/68). **État :** Déjà intégré web via #328, absent worker et Godot.

**Preuve :** CDSportingDirectorV105V110 priority/delegate/invest/mitigate/readiness/closeSeason présent sur main ; module absent MODULES/model/COMMANDS. Ses investissements alimentent un score interne, pas le moteur de match. board-calendar.js V61 existe sur main mais ni dans index ni MODULES : objectifs datés et réunions restent un moteur pur isolé, distinct de la direction V42 active et de V105.

**Coût et risque :** Moyen. Vendre des améliorations médicales/vidéo comme bonus sportifs alors qu’ils n’existent pas ; répéter des dépenses annuelles.

**Prochaine action :** Porter priorité + disponibilité + bilan ; n’activer les projets qu’avec explication de leurs effets réels.

- **C13 — Priorité et bilan annuel de direction.** Fichiers et fonctions : `dist/sporting-director-v105-v110.js:priority/readiness/closeSeason ; blob 89910b7934688301282557490f1e96a260f14698`.
  Action : Porter la décision de priorité, l’état de disponibilité et le bilan. Les missions V106 ne sont ni contrats de coachs ni bonus de match.
  Réception à exécuter : Suites V105/V101 combinées adaptées ; une clôture annuelle ; deux divisions ; échec de stockage et reprise.

- **C27 — Échéances et réunions du conseil.** Fichiers et fonctions : `dist/board-calendar.js:create/objective/review/briefing ; tests/v61-board-calendar.cjs`.
  Action : Bibliothèque pure hors web/worker. Réutiliser les échéances après mapping métriques ; pas de second calcul de confiance au-dessus de careerBoardWeekReview.
  Réception à exécuter : Métrique absente=>unverified sans sanction,idempotence,France30,ancienne carrière ; test synthétique15saisons insuffisant comme parcours natif.

### F08 — Finances utiles et investissements

**Sources :** [#360](https://github.com/Xynph/cadrage-debordement/pull/360), [#367](https://github.com/Xynph/cadrage-debordement/pull/367). **État :** Actions moteur chargées, cockpit web intégré #367 ; E3.7 R&D isolée.

**Preuve :** finance-v2.js et ses graphiques sont web ; worker charge career-integration.js/world-career.js mais aucune commande careerSetAcademyInvestment/worldUpgradeFacility. model.finance expose cash/wage/ledger. E3.7 ne change que ci/tests/docs/workflow.

**Coût et risque :** Moyen pour le portage ; très élevé pour noyau E1. Fausse dette ou bilan annuel depuis un ledger de 100 lignes ; promettre un gain sportif de l’investissement ; double débit.

**Prochaine action :** Porter les deux actions natives, le devis et les flux conservés ; garder E1–E3.7 comme preuve de laboratoire.

- **C14 — Finances Godot avec décisions natives.** Fichiers et fonctions : `dist/career-integration.js:careerSetAcademyInvestment ; dist/world-career.js:worldUpgradeFacility ; dist/finance-v2.js ; native/godot/ui/club_views.gd:finance`.
  Action : Porter devis, investissement 0/4k/12k et achat installations avec les vrais contrôleurs. Réutiliser le journal plafonné, sans noyau comptable E1.
  Réception à exécuter : Tests finance-v2/godot-management/saves adaptés ; débit unique, reload et rollback ; aucune écriture sur simple vue.

### F09 — Vestiaire vivant et engagements

**Sources :** [#334](https://github.com/Xynph/cadrage-debordement/pull/334), [#311](https://github.com/Xynph/cadrage-debordement/pull/311). **État :** Déjà intégré web #334 ; exclu du worker.

**Preuve :** living-locker-room-v117-v123.js enveloppe managerWeek et rend le Bureau web ; champ livingLockerRoom créé seulement à la décision. Worker ne charge pas ce module ni vestiaire-v64/relations-duos-v70. Le socle economy.js V36/V37 (satisfaction, promesses, entretiens) est chargé mais non exposé. vestiaire-v64 et relations-duos-v70 sont web seuls : V64 affecte le moral, V70 les résolutions offensives quand les deux partenaires sont vraiment sur le terrain.

**Coût et risque :** Moyen à élevé. Nouvelles écritures optionnelles, échéances et rollback ; dépendances relationnelles et morale.

**Prochaine action :** Porter un seul événement hebdomadaire avec trois choix et retour explicable, puis tester les engagements et sauvegardes.

- **C15 — Un événement de vestiaire par semaine.** Fichiers et fonctions : `dist/living-locker-room-v117-v123.js:weeklyEvent/apply/settle ; PR334`.
  Action : Conserver les trois arbitrages et une conséquence lisible, avec échéance ; porter les dépendances de morale/promes déterminément.
  Réception à exécuter : Tests living-locker existants adaptés ; décision dupliquée refusée ; blessure et échéance ; rollback et anciennes carrières.

- **C26 — Duos, médiation, leadership et promesses.** Fichiers et fonctions : `economy.js:makePlayingPromise/coachConversation ; vestiaire-v64.js ; relations-duos-v70.js:relation/perform/matchSnapshot/matchBonus`.
  Action : Exposer promesses existantes puis qualifierV64/V70 ; séparer rivalités entre joueurs/interclubs ; liens simulés même sous pack réel.
  Réception à exécuter : tests/v36-satisfaction.cjs, tests/v37-relations.cjs, tests/v64-vestiaire.cjs, tests/v70-relations-duos.cjs ; partenaires actifs,blessure,échec stockage,promesse suspendue,effet borné -0,012/+0,018.

### F10 — Monde interclubs : événements, réactions et pression

**Sources :** [#336](https://github.com/Xynph/cadrage-debordement/pull/336). **État :** Archives françaises Godot livrées ; mémoire narrative web #336 absente.

**Preuve :** model.archives expose déjà jusqu’à 15 saisons du yearbook français ; interclub-world-v124-v130.js contient les paires persistantes et 20 bilans mais n’est pas chargé par le worker. history brute ne remplace pas ce registre.

**Coût et risque :** Moyen à élevé. Supposer le wrapper record/advanceSeason compatible France30 sans essai ; dépassement des bornes d’import en carrière longue.

**Prochaine action :** Porter les événements/réactions à partir des résultats France30 ; traiter la consultation des confrontations et palmarès dans F18.

- **C16 — Rivalités et résumé durable de carrière.** Fichiers et fonctions : `dist/interclub-world-v124-v130.js:accept/season/top ; model.archives existant ; PR336`.
  Action : Observer les résultats natifs France30 et conserver seulement les événements réels ; ne pas rejouer rétroactivement un passé incomplet comme certain.
  Réception à exécuter : Tests interclub adaptés aux deux divisions ; idempotence record ; 15 calendriers réels, reprise et limite 5 Mio ; archive sans points inventés.

### F11 — Carrière du manager et marché des entraîneurs

**Sources :** [#229](https://github.com/Xynph/cadrage-debordement/pull/229), [#234](https://github.com/Xynph/cadrage-debordement/pull/234), [#247](https://github.com/Xynph/cadrage-debordement/pull/247). **État :** Mobilité native historique chargée mais inaccessible Godot ; prototypes V58 non raccordés.

**Preuve :** manager-mobility.js est dans MODULES avec managerMobilityApply/Accept/Confirm ; aucune commande correspondante. coach-career/negotiations/contract-cycle sont présents via #247 mais hors MODULES/index. #234 n’est qu’une passerelle web consultative.

**Coût et risque :** Élevé. Deux registres de titulaires, double salaire/débit ; changement de club incompatible avec modules de formation et archives France30.

**Prochaine action :** Partir de S.club et de manager-mobility existant ; qualifier une mutation intersaison France30 avant tout contrat personnel.

- **C17 — Candidature intersaison et changement de club.** Fichiers et fonctions : `dist/manager-mobility.js:managerMobilityApply/Accept/Confirm/OnSeasonStart ; modules V58 #247 conservés en bibliothèque`.
  Action : Exposer le système de mobilité existant, qualifier S.club et les réinitialisations ; reporter salaire personnel et cycle contractuel pur.
  Réception à exécuter : Tests manager-mobility + France/common ; transfert Élite/Accession ; archivage, centre et finance ; sauvegarde corrompue ou écriture refusée.

### F12 — Supporters et activité commerciale

**Sources :** [#327](https://github.com/Xynph/cadrage-debordement/pull/327), [#328](https://github.com/Xynph/cadrage-debordement/pull/328). **État :** Déjà intégré web #328 ; module absent worker.

**Preuve :** CDFanExperienceV111V116 forecast/setPrice/campaign/community/service/record existe sur main, index le charge ; worker et model ne l’exposent pas. Les créneaux 1–26 sont commerciaux et manuels, pas des matchs.

**Coût et risque :** Moyen. Ajouter de fausses recettes à une compétition de 34 semaines ; donner un faux réalisme aux tarifs fictifs.

**Prochaine action :** Commencer par un indicateur et une politique ; redéfinir les créneaux sur le calendrier natif avant toute recette.

- **C18 — Politique supporters raccordée au calendrier réel.** Fichiers et fonctions : `dist/fan-experience-v111-v116.js ; blob 953b10792afa54cd8e92e79b341a89b2696387f6`.
  Action : Garder prévision/satisfaction en premier ; une spécification calendrier est requise avant de débiter/encaisser les créneaux 1–26.
  Réception à exécuter : Tests V111 adaptés ; plafond capacité et non-duplication ; déroulé 34 semaines ; sauvegarde/import.

### F13 — Match 3D, corps et contacts

**Sources :** [#300](https://github.com/Xynph/cadrage-debordement/pull/300), [#350](https://github.com/Xynph/cadrage-debordement/pull/350). **État :** Prototypes V24/V25 non intégrés ; qualité non qualifiée.

**Preuve :** build-godot-prototype.py embarque quaternius-rugby-athlete.glb ; #300 utilise rugby-v24 et #350 research/oss-match3d. Le rapport #350 arrête Ekza sur appui inaccessible de 3,592 mm ; 0 image candidate temporelle.

**Coût et risque :** Très élevé. Contact non qualifié, coût GPU accru, absence de benchmark Godot réel ; moteur Three.js incompatible comme remplacement direct.

**Prochaine action :** Lever le problème d’ancrage semelle/cheville sur une scène isolée ; qualifier un seul geste dans Godot avant tout remplacement.

- **C19 — Une animation de contact réellement qualifiée Godot.** Fichiers et fonctions : `PR300 rugby-v24 ; PR350 research/oss-match3d-20261106/audit.md ; native/godot/match_view.gd`.
  Action : Résoudre l’atteignabilité des cibles, puis convertir un seul geste et vérifier son rendu Godot avec les mêmes racines et sol. Aucune fusion globale.
  Réception à exécuter : Inspection de séquences continues, pieds/mains/ballon/contact ; trois LOD et 30 acteurs réels ; benchmark Godot Windows, pas SwiftShader Three.js.

### F14 — Coach BD et voix

**Sources :** [code sur main](https://github.com/Xynph/cadrage-debordement/blob/3fe6d160a34a9bf3b19005eaef003ac4b1e4ec21/native/godot/guide/guide_content.gd). **État :** Déjà livré ; voix finale et conseil contextuel restent à produire.

**Preuve :** native/godot/guide contient 15 étapes, sprites animés, bulle et guide_speech.gd TTS Windows. Le guide ne commande pas le moteur. La voix actuelle est provisoire.

**Coût et risque :** Faible à moyen. Coupler le conseil à une décision automatique ou masquer une erreur de préférence ; confondre TTS système et voix artistique finale.

**Prochaine action :** Écrire de courtes répliques à partir des dossiers tactiques portés, puis produire une voix définitive en conservant le mode texte.

- **C20 — Coach contextuel et voix définitive.** Fichiers et fonctions : `native/godot/guide/guide_content.gd ; guide_speech.gd ; coach_guide.gd`.
  Action : Le coach BD/voix provisoire existe déjà. Ajouter des répliques basées sur les nouvelles projections tactiques et une voix artistique reçue.
  Réception à exécuter : Guide texte/TTS, ancien réglage, arrêt au direct/dialogue, focus clavier et refus écriture ; invariants carrière/RNG.

### F15 — Studio UI premium et concepts visuels

**Sources :** [#362](https://github.com/Xynph/cadrage-debordement/pull/362), [#369](https://github.com/Xynph/cadrage-debordement/pull/369), [#372](https://github.com/Xynph/cadrage-debordement/pull/372). **État :** Atelier React isolé ; carnet Godot a déjà repris plusieurs concepts.

**Preuve :** studio-ui n’est pas le runtime Godot ; les fiches, comparaison de joueurs, filtres et photographies territoriales sont déjà livrés en GDScript. Les PR studio décrivent des fixtures et leur atelier isolé.

**Coût et risque :** Faible pour une idée ; élevé pour un remplacement. Réintroduire une seconde application React ou présenter des fixtures comme données de carrière.

**Prochaine action :** Extraire seulement un concept encore utile, par exemple les liens tactiques entre comparaison et sélection, dans les vues Godot existantes.

- **C21 — Réutilisation sélective des fiches du studio.** Fichiers et fonctions : `PR369/372 studio-ui ; native/godot/ui/squad_views.gd ; management_state.gd`.
  Action : Choisir une amélioration encore absente du carnet, la coder directement dans Godot et la brancher aux IDs réels.
  Réception à exécuter : Recette graphique trois tailles avec vrais dossiers longs ; clavier/recherche/comparaison ; aucun champ de fixture en production.

### F16 — Presse, conférences et journal rugby

**Sources :** [#254](https://github.com/Xynph/cadrage-debordement/pull/254), [#255](https://github.com/Xynph/cadrage-debordement/pull/255), [#256](https://github.com/Xynph/cadrage-debordement/pull/256). **État :** Sept modules presse actifs web ; tous exclus du worker.

**Preuve :** press-relations.js, office-career-press.js, press-question-bank.js, press-conference-interactive.js, media-evidence-v60.js, media-native-adapter-v60.js, media-world-v60.js figurent dans index.html, aucun dans MODULES. Banque500 questions/25thèmes,3variantes et4réponses ; conférence2–4questions historisée. Adapter collecte résultats/classement/blessures, sans inventer transferts/performance. holdConference et rich.apply changent réellement S.morale/S.trust et les états presse.

**Coût et risque :** Moyen pour journal ; élevé pour conférence intégrale. Cumul des conférences simple/riche ; pression média distincte de S.trust ; classement agrégé sur tous les clubs ; anti-répétition30semaines et validateur semaine<=26 incompatibles avec34 ; validation pressConference seulement dans API riche, pas reliée explicitement au validateur central.

**Prochaine action :** Porter journal factuel par division puis une seule conférence transactionnelle, calendrierFrance30 et validation complète ; chroniques génériques explicitement simulées.

- **C22 — Journal factuel et chroniques.** Fichiers et fonctions : `media-native-adapter-v60.js:collect ; media-evidence-v60.js:curate/special ; media-world-v60.js:issue/headlines`.
  Action : Projeter résultats/blessures par ID et division ; distinguer les7 chroniques génériques des faits calculés. Respecter packs et date native.
  Réception à exécuter : tests/v60-media-native-adapter.cjs, v60-media-evidence.cjs, v60-media-world.cjs ; invariants lecture, pas de faux transfert/performance, futur exclu, Élite/Accession séparés.

- **C23 — Conférences interactives persistantes.** Fichiers et fonctions : `press-relations.js:interview/nextSeason ; office-career-press.js:holdConference/validatePressCareer ; press-question-bank.js:pick/appendHistory ; press-conference-interactive.js:prepare/apply/validate`.
  Action : Choisir une seule voie conférence,2–4questions/4réponses, historique borné, vrais effets moral/confiance. Adapter semaine<=26 et période30 aux34 ; intégrer les validateurs au format natif.
  Réception à exécuter : tests/v60-question-bank.cjs, v60-interactive-conference.cjs, v60-press-persistent.cjs, office-career-press.cjs puis vrais exports/imports worker, club29,saison2,mobilité et échec disque ; global.S synthétique ne certifie pas Godot.

### F17 — Sponsors et conseil de direction

**Sources :** [#45](https://github.com/Xynph/cadrage-debordement/pull/45), [#367](https://github.com/Xynph/cadrage-debordement/pull/367). **État :** Sponsor et revues actifs moteur ; inaccessibles Godot.

**Preuve :** career-integration.js chargé : CAREER_SPONSORS, careerSponsorPick/Week, careerBoardWeekReview, careerBudgetModel. Trois contrats fictifs, un par saison avant la5e journée ; signature et recettes dans ledger. S.careerManagement contient sponsor/boardHistory ; model.finance et COMMANDS ne les exposent pas. CDBoardPlanning/CDFinancialRecovery restent calculatoires.

**Coût et risque :** Moyen. Doubler signature ou recettes, réutiliser26/29semaines historiques dans34, ou inventer une marque réelle ; second calcul de confiance.

**Prochaine action :** Porter devis et signature unique sur moteur existant ; exposer bilan et hypothèses sans comptabilité parallèle.

- **C24 — Sponsor et bilan du conseil.** Fichiers et fonctions : `career-integration.js:careerSponsorPick/careerSponsorWeek/careerBoardWeekReview ; board-planning.js ; native/engine/model.cjs`.
  Action : Projeter trois offres fictives et signer par commande avec devis, les160000€/semaine historiques restent distincts ; exposer confiance et bilan existants.
  Réception à exécuter : tests/career-integration.cjs, board-planning.cjs, world-career.cjs adaptés ; signature/recette unique,reprise,prime victoire,34semaines et mode historique.

### F18 — Rivalités historiques, palmarès et records

**Sources :** [#336](https://github.com/Xynph/cadrage-debordement/pull/336), [#45](https://github.com/Xynph/cadrage-debordement/pull/45). **État :** H2H et historique chargés ; archives Godot partielles ; dynasties/records complets non attestés.

**Preuve :** rugby-world.js rivalry/headToHeadTable et career-history.js append/summary/leaderboard sont chargés. world-career.js garde180matchs,15yearbooks/15distinctions ; careerManagement.history180événements. model.archives projette seulement le yearbookFrance30. interclubWorld hors worker garde les paires durables (F10). Aucun système complet explicite dynasties/records/calendrier narratif trouvé ; le type record de CareerHistory est un conteneur, pas un détecteur.

**Coût et risque :** Faible à moyen pour H2H ; élevé pour mémoire complète. Déduire le passé complet depuis une fenêtre tronquée, recompter titres ou inventer records de marqueurs non suivis ; confondre récit et fixture officielle.

**Prochaine action :** Projeter H2H et palmarès fiables ; dynasties/records et frise seulement depuis événements versionnés et datés.

- **C25 — Dossier des confrontations et palmarès.** Fichiers et fonctions : `rugby-world.js:rivalry/headToHeadTable ; career-history.js:summary/leaderboard ; world-career.js ; model.cjs:archives`.
  Action : Exposer H2H et titres fiables en lecture, annoncer fenêtre180matchs. Dynasties/records/frise sont des compléments nouveaux, aucun système complet attesté.
  Réception à exécuter : tests/rugby-world.cjs,career-history.cjs,world-career.cjs,godot-career-archives.cjs ; doublons,fenêtre tronquée,packs et absence explicite.

## Précisions qui évitent les mauvaises intégrations

- **BDD :** [le registre v2](https://github.com/Xynph/cadrage-debordement/blob/3fe6d160a34a9bf3b19005eaef003ac4b1e4ec21/docs/roster-foundation-lot2.md) contient 241 postes corroborés, 86 échéances et 9 statuts documentés ; 67 postes principaux changent réellement. Comparer #389 à ce résultat avant de corriger. Traini, Ez Zahouany, Tumania et González restent en quarantaine. Une publication de poste ne certifie pas une qualification réglementaire de première ligne. Les références v1 et v2 restent distinctes sans migration implicite.
- **Potentiel :** #388 explique que les 393 anciens écarts potential < rating ne sont pas 393 blocages : dev.potential n’est jamais sous la note active, 47 marges sont nulles. Ne pas appliquer une hausse globale. #389 rétablit la préparation/récupération dans les campagnes longues ; des rollovers sans trainWeek ne prouvent pas une panne générale.
- **Économie :** #360 ne change que ci/tests/docs/workflow. Les dépenses et observations appariées n’établissent pas une garantie de gain sportif, surtout après divergence RNG. L’issue [#365](https://github.com/Xynph/cadrage-debordement/issues/365) demande l’arrêt des microversions E3.x et une livraison depuis les actions natives ; #367 l’a déjà réalisée dans le web. C14 porte cette livraison vers Godot, sans noyau comptable E1, dette inventée ou double débit. Le ledger de 100 lignes n’est pas un bilan annuel complet.
- **3D :** #300 conserve contacts, mains et ballon non qualifiés. #350 documente le STOP d’un appui réel inaccessible de 3,592 mm, 171 images baseline et **0 candidate temporelle**. Les succès géométriques statiques ne lèvent pas ce STOP. Les FPS d’un atelier Three.js/SwiftShader ne prouvent pas la performance Godot Windows.
- **Déjà livré :** recherche et comparaison de joueurs, filtres, suivis de session, archives françaises, photos via pack privé et coach BD animé avec voix Windows provisoire. C08/C12/C20 ciblent la persistance avancée, le vrai personnel sourcé et la voix finale. #391 est une collecte joueurs/logos, pas staff. Aucun code attesté ne fournit le catalogue de staff réel, ses portraits ou une voix artistique définitive : ce sont de nouveaux besoins.
- **Carrière longue :** le yearbook français de 15 saisons existe ; mémoire interclubs et générations ajoutent une autre couche. Les quinze intersaisons de tests isolés ne valent pas quinze calendriers complets. Tester le mode commun France30, les deux divisions et les vrais checkpoints sous les bornes actuelles de 5 Mio.

## Ordre recommandé

1. **BDD et garde-fous C01–C02** : réconcilier les anomalies restantes avec le registre v2, préserver v1/v2 et les qualifications ; ne pas mêler recalibrage des notes et ajout du staff.
2. **Préparer → jouer → analyser C03–C06** : dossier adverse en lecture, conseil en pause, bilan des plans puis consignes de zone. C’est une boucle jouable cohérente qui réutilise beaucoup de code et peu de nouveau stockage.
3. **Recruter et développer C07–C11**, puis **décisions financières C14** : besoins par poste, historique et conseils avant les missions et parcours persistants. Le staff réel C12 se construit comme collecte sourcée et couche d’identité, sans bloquer les diagnostics utiles.

La presse factuelle C22, les conférences C23, le centre natif C28 et le dossier H2H C25 sont des priorités explicites à inscrire dans les lots jouables, avant les enrichissements plus lointains. Direction, vestiaire et mobilité viennent par lots bornés. Supporters et refonte du renderer restent moins prioritaires que la cohérence de l’effectif et la lecture du match. Réutiliser les concepts du studio dans Godot ; aucune recommandation de réintroduire React comme application.

## Presse : ce qui existe réellement et ce qu’il faut raccorder

[#255](https://github.com/Xynph/cadrage-debordement/pull/255) et [#256](https://github.com/Xynph/cadrage-debordement/pull/256) sont fusionnées (preuve REST), malgré les passages DRAFT conservés dans leurs corps. Leurs fichiers sont sur main et chargés par le web. Le système comprend **500 questions, 25 thèmes, trois formulations et quatre réponses**, sélection de 2 à 4 questions par conférence, journal des choix et exclusion des questions récentes pendant 12 semaines. Les fichiers actuels, pas le titre « socle isolé », établissent le raccord réel.

| Couche | API sur main | Effet actuel | Adaptation Windows |
|---|---|---|---|
| Relations presse pures | `CDPressRelations.create/interview/nextSeason/briefing/validate` | Opinions médias/supporters, pression, moral interne, stories40 ; copie pure | Charger le module et projeter uniquement les données nécessaires. |
| Conférence simple | `CDOfficeBridge.pressPreview/holdConference/validatePressCareer` | Écrit `S.pressRelations`, modifie `S.morale` et `S.trust`, sauvegarde et rollback | Commande dédiée, hors match, devis/conséquences et validation ; ne pas cumuler avec la conférence riche. |
| Questions | `CDPressQuestionBank.pick/appendHistory` | Déterministe ; historique500 et variantes, journalistes/intervenants simulés | JSON et boutons Godot, aucun HTML ni citation présentée réelle. |
| Conférence riche | `CDV60RichPress.prepare/apply/validate` | Écrit `S.pressConference`, opinions et vrai moral/confiance ; une conférence/semaine | Portage transactionnel et date France30, contrôle des anciennes sauvegardes. |
| Événements sourcés jeu | `CDMediaNativeAdapter.collect`, `CDMediaEvidence.curate/special` | Résultats conservés, classement et blessures ; zéro transfert/performance inventé | Séparer les divisions : l’adaptateur web trie actuellement tous les clubs ensemble. |
| Monde médiatique | `CDMediaWorld.issue/headlines` | Sept chroniques déterministes génériques par semaine, lecture seule | Présenter comme chroniques simulées, pas enquêtes ou observations tactiques nouvelles. |

**Dépendances et risque concret de sauvegarde :** `office-career-press` dépend de `CDPressRelations` et lit `CDCoachMarket/worldManagement` pour les risques de banc ; la conférence riche dépend de la banque et du module presse ; le monde médiatique lit l’adaptateur et l’éditeur d’événements. Aucun des sept scripts n’est dans MODULES. `saves.js` exige **CDPressRelations** pour importer un état `pressRelations` : un export web avec presse ne devient pas compatible Godot par simple ajout d’un panneau. Son garde `p.week<=26` et le calcul de répétition sur 30 semaines doivent être confrontés à la cadence native de 34 semaines. Le validateur `pressConference` reste dans l’API riche ; aucun appel explicite depuis le validateur central n’est présent sur ce main. Il faut fermer cette lacune avant une activation native, sans élargir silencieusement les imports.

**Preuves de tests inspectées, sans nouvelle exécution dans cet audit :** [v60-question-bank](https://github.com/Xynph/cadrage-debordement/blob/3fe6d160a34a9bf3b19005eaef003ac4b1e4ec21/tests/v60-question-bank.cjs) vérifie 500 questions, 1 500 variantes, 30 intervenants et 10 médias ; [v60-interactive-conference](https://github.com/Xynph/cadrage-debordement/blob/3fe6d160a34a9bf3b19005eaef003ac4b1e4ec21/tests/v60-interactive-conference.cjs) vérifie réponses, sauvegarde appelée, doublon et reprise JSON sur une fixture `global.S` ; [v60-press-persistent](https://github.com/Xynph/cadrage-debordement/blob/3fe6d160a34a9bf3b19005eaef003ac4b1e4ec21/tests/v60-press-persistent.cjs) vérifie effets, saison, ancienne sauvegarde et corruption ; [office-career-press](https://github.com/Xynph/cadrage-debordement/blob/3fe6d160a34a9bf3b19005eaef003ac4b1e4ec21/tests/office-career-press.cjs) vérifie non-mutation et rendu ; [adaptateur média](https://github.com/Xynph/cadrage-debordement/blob/3fe6d160a34a9bf3b19005eaef003ac4b1e4ec21/tests/v60-media-native-adapter.cjs) vérifie faits réels, futur exclu et absence de transfert inventé ; [media-evidence](https://github.com/Xynph/cadrage-debordement/blob/3fe6d160a34a9bf3b19005eaef003ac4b1e4ec21/tests/v60-media-evidence.cjs) et [media-world](https://github.com/Xynph/cadrage-debordement/blob/3fe6d160a34a9bf3b19005eaef003ac4b1e4ec21/tests/v60-media-world.cjs) protègent la curation et les sept chroniques. Ces tests ne sont pas une réception des vrais contrôles Godot ni du format de sauvegarde Windows actuel.

## Formation et rivalités : quatre distinctions indispensables

1. **Centre de base déjà actif.** `development.js:intakeYouth` crée bien **15 Espoirs fictifs par saison**, un par poste, et conserve au plus 75 jeunes. La progression, les minutes et la promotion native existent ; Godot cache actuellement la collection `S.development.academy` et ne propose pas `promoteYouth`. Le texte HTML « quatre nouveaux » est ancien : le code `i<15` fait foi. `promote_cover` est un secours qui crée des professionnels : il ne remplace pas la promotion d’un jeune du centre.
2. **V72 et V73–V104 sont une extension distincte.** V72 ajoute détection payante, mentorat et mémoire de promotions ; V73–V75 introduisent deux compétitions Espoirs et 44 centres ; V76–V104 ajoutent recrutement, parcours, mentorat, réseau, objectifs, potentiel et archives. Ces scripts sont web seuls. Les porter tous exigerait un raccord cohérent, des règles datées et une nouvelle réception de carrière ; aucun statut « prêt » global.
3. **Trois sens des rivalités.** H2H entre clubs : `CDRugbyWorld.rivalry` et les 180 matchs conservés, déjà chargés. Rivalité persistante et réactions des bancs : `interclubWorld` web (F10), paires durables et événements. Frictions entre deux joueurs : V70 web (C26), actions duo/médiation/mentorat et effet offensif borné si les deux jouent. Aucune n’est une biographie réelle sous un pack de noms.
4. **Palmarès, dynasties et records ne sont pas interchangeables.** Le yearbook France30, les 15 distinctions `worldManagement.awards` et l’historique de carrière sont réels, mais partiels. Le type `record` accepté par CareerHistory ne détecte aucun record. Aucun système complet de dynasties, records individuels ou calendrier narratif autonome n’a été attesté. Une frise peut réunir les événements fiables ; les trous du passé doivent rester visibles.

## Différence exhaustive entre le web et le worker

Le relevé est extrait de **tous les 116 `script src` de `dist/index.html`** et des **46 CORE_FILES** : **39 communs, 77 web seuls, sept natifs seuls**. Les sept fichiers .js de la racine dist non chargés par l’un ou l’autre sont aussi listés. Cette exhaustivité vise le chargement statique ; elle ne prétend pas inventorier tous les médias ni les imports dynamiques du renderer.

| Script web absent du worker | Famille / traitement |
|---|---|
| `match-tactical-visual.js` | F13 · Renderer web et présentation du match. Logique ou présentation web à adapter ; aucun chargement Godot attesté. |
| `press-relations.js` | F16 · Presse et média. Logique ou présentation web à adapter ; aucun chargement Godot attesté. |
| `ui02-player-data.js` | F15 · Rendu/ergonomie web ou projection PC. Écran/adaptateur web ; récupérer le concept utile dans Godot, sans charger HTML/CSS/DOM. |
| `ui02-player-components.js` | F15 · Rendu/ergonomie web ou projection PC. Écran/adaptateur web ; récupérer le concept utile dans Godot, sans charger HTML/CSS/DOM. |
| `ui02-player-controller.js` | F15 · Rendu/ergonomie web ou projection PC. Écran/adaptateur web ; récupérer le concept utile dans Godot, sans charger HTML/CSS/DOM. |
| `ui03-scout-data.js` | F15 · Rendu/ergonomie web ou projection PC. Écran/adaptateur web ; récupérer le concept utile dans Godot, sans charger HTML/CSS/DOM. |
| `ui03-scout-components.js` | F15 · Rendu/ergonomie web ou projection PC. Écran/adaptateur web ; récupérer le concept utile dans Godot, sans charger HTML/CSS/DOM. |
| `ui04-academy-data.js` | F05 · Formation et parcours. Écran/adaptateur web ; récupérer le concept utile dans Godot, sans charger HTML/CSS/DOM. |
| `ui04-academy-components.js` | F05 · Formation et parcours. Écran/adaptateur web ; récupérer le concept utile dans Godot, sans charger HTML/CSS/DOM. |
| `ui-native-centers.js` | F15 · Rendu/ergonomie web ou projection PC. Écran/adaptateur web ; récupérer le concept utile dans Godot, sans charger HTML/CSS/DOM. |
| `squad-health-center.js` | F15 · Rendu/ergonomie web ou projection PC. Logique ou présentation web à adapter ; aucun chargement Godot attesté. |
| `matchday-lineup.js` | F15 · Rendu/ergonomie web ou projection PC. Logique ou présentation web à adapter ; aucun chargement Godot attesté. |
| `matchday-matchplan.js` | F15 · Rendu/ergonomie web ou projection PC. Logique ou présentation web à adapter ; aucun chargement Godot attesté. |
| `matchday-center.js` | F15 · Rendu/ergonomie web ou projection PC. Logique ou présentation web à adapter ; aucun chargement Godot attesté. |
| `lnr-rosters-data.js` | F01 · BDD réelle remplacée par compilation commune. Exclusion volontaire des identités réelles ; données sportives V12 compilées séparément, ne pas conclure BDD absente. |
| `lnr-birthyears-data.js` | F01 · BDD réelle remplacée par compilation commune. Exclusion volontaire des identités réelles ; données sportives V12 compilées séparément, ne pas conclure BDD absente. |
| `lnr-ratings-v12.js` | F01 · BDD réelle remplacée par compilation commune. Exclusion volontaire des identités réelles ; données sportives V12 compilées séparément, ne pas conclure BDD absente. |
| `lnr-career.js` | F01 · BDD réelle remplacée par compilation commune. Exclusion volontaire des identités réelles ; données sportives V12 compilées séparément, ne pas conclure BDD absente. |
| `lnr05-enriched-data.js` | F01 · BDD réelle remplacée par compilation commune. Exclusion volontaire des identités réelles ; données sportives V12 compilées séparément, ne pas conclure BDD absente. |
| `lnr05-evidence-center.js` | F01 · BDD réelle remplacée par compilation commune. Exclusion volontaire des identités réelles ; données sportives V12 compilées séparément, ne pas conclure BDD absente. |
| `ui-preferences.js` | F15 · Rendu/ergonomie web ou projection PC. Écran/adaptateur web ; récupérer le concept utile dans Godot, sans charger HTML/CSS/DOM. |
| `main-menu-slots.js` | F15 · Rendu/ergonomie web ou projection PC. Écran/adaptateur web ; récupérer le concept utile dans Godot, sans charger HTML/CSS/DOM. |
| `main-menu-v3.js` | F15 · Rendu/ergonomie web ou projection PC. Écran/adaptateur web ; récupérer le concept utile dans Godot, sans charger HTML/CSS/DOM. |
| `art-direction-v4.js` | F15 · Rendu/ergonomie web ou projection PC. Écran/adaptateur web ; récupérer le concept utile dans Godot, sans charger HTML/CSS/DOM. |
| `v17-v10-engine.js` | F15 · Rendu/ergonomie web ou projection PC. Écran/adaptateur web ; récupérer le concept utile dans Godot, sans charger HTML/CSS/DOM. |
| `v17-unified-pc.js` | F15 · Rendu/ergonomie web ou projection PC. Écran/adaptateur web ; récupérer le concept utile dans Godot, sans charger HTML/CSS/DOM. |
| `finance-v2.js` | F08 · Cockpit financier. Logique ou présentation web à adapter ; aucun chargement Godot attesté. |
| `v17-native-adapter.js` | F15 · Rendu/ergonomie web ou projection PC. Écran/adaptateur web ; récupérer le concept utile dans Godot, sans charger HTML/CSS/DOM. |
| `vestiaire-v64.js` | F09 · Vestiaire et duos. Logique ou présentation web à adapter ; aucun chargement Godot attesté. |
| `staff-meeting-v65.js` | F06 · Staff et soins. Logique ou présentation web à adapter ; aucun chargement Godot attesté. |
| `staff-advisor-v66.js` | F06 · Staff et soins. Logique ou présentation web à adapter ; aucun chargement Godot attesté. |
| `training-plans-v67.js` | F06 · Staff et soins. Logique ou présentation web à adapter ; aucun chargement Godot attesté. |
| `medical-decisions-v68.js` | F06 · Staff et soins. Logique ou présentation web à adapter ; aucun chargement Godot attesté. |
| `briefing-strategique-v69.js` | F02 · Stratégie avant match avec effet moteur. Le script ajoute un effet moteur réel par wrapper ; portage distinct à qualifier. |
| `relations-duos-v70.js` | F09 · Vestiaire et duos. Le script ajoute un effet moteur réel par wrapper ; portage distinct à qualifier. |
| `bureau-agents-v71.js` | F04 · Agents et stratégies contractuelles. Logique ou présentation web à adapter ; aucun chargement Godot attesté. |
| `youth-pathways-v72.js` | F05 · Formation et parcours. Logique ou présentation web à adapter ; aucun chargement Godot attesté. |
| `espoirs-league-v73.js` | F05 · Formation et parcours. Logique ou présentation web à adapter ; aucun chargement Godot attesté. |
| `espoirs-accession-v74.js` | F05 · Formation et parcours. Logique ou présentation web à adapter ; aucun chargement Godot attesté. |
| `espoirs-movement-v75.js` | F05 · Formation et parcours. Logique ou présentation web à adapter ; aucun chargement Godot attesté. |
| `espoirs-scouting-v76.js` | F05 · Formation et parcours. Logique ou présentation web à adapter ; aucun chargement Godot attesté. |
| `espoirs-pro-v77.js` | F05 · Formation et parcours. Logique ou présentation web à adapter ; aucun chargement Godot attesté. |
| `espoirs-parcours-v78-v81.js` | F05 · Formation et parcours. Logique ou présentation web à adapter ; aucun chargement Godot attesté. |
| `espoirs-career-v82-v85.js` | F05 · Formation et parcours. Logique ou présentation web à adapter ; aucun chargement Godot attesté. |
| `espoirs-followup-v86-v89.js` | F05 · Formation et parcours. Logique ou présentation web à adapter ; aucun chargement Godot attesté. |
| `espoirs-dynamics-v90-v94.js` | F05 · Formation et parcours. Logique ou présentation web à adapter ; aucun chargement Godot attesté. |
| `espoirs-strategy-v95-v100.js` | F05 · Formation et parcours. Logique ou présentation web à adapter ; aucun chargement Godot attesté. |
| `espoirs-coaching-v101-v104.js` | F05 · Formation et parcours. Logique ou présentation web à adapter ; aucun chargement Godot attesté. |
| `sporting-director-v105-v110.js` | F07 · Direction sportive et raccord. Logique ou présentation web à adapter ; aucun chargement Godot attesté. |
| `fan-experience-v111-v116.js` | F12 · Supporters. Logique ou présentation web à adapter ; aucun chargement Godot attesté. |
| `v101-v116-ui-bridge.js` | F07 · Direction sportive et raccord. Logique ou présentation web à adapter ; aucun chargement Godot attesté. |
| `office-career-press.js` | F16 · Presse et média. Logique ou présentation web à adapter ; aucun chargement Godot attesté. |
| `press-question-bank.js` | F16 · Presse et média. Logique ou présentation web à adapter ; aucun chargement Godot attesté. |
| `press-conference-interactive.js` | F16 · Presse et média. Logique ou présentation web à adapter ; aucun chargement Godot attesté. |
| `rugby-broadcast.js` | F13 · Renderer web et présentation du match. Logique ou présentation web à adapter ; aucun chargement Godot attesté. |
| `media-evidence-v60.js` | F16 · Presse et média. Logique ou présentation web à adapter ; aucun chargement Godot attesté. |
| `media-native-adapter-v60.js` | F16 · Presse et média. Logique ou présentation web à adapter ; aucun chargement Godot attesté. |
| `media-world-v60.js` | F16 · Presse et média. Logique ou présentation web à adapter ; aucun chargement Godot attesté. |
| `living-locker-room-v117-v123.js` | F09 · Vestiaire et duos. Logique ou présentation web à adapter ; aucun chargement Godot attesté. |
| `interclub-world-v124-v130.js` | F10 · Monde interclubs. Logique ou présentation web à adapter ; aucun chargement Godot attesté. |
| `match3d/vendor/three-r149.min.js` | F13 · Renderer web et présentation du match. Logique ou présentation web à adapter ; aucun chargement Godot attesté. |
| `match3d/vendor/GLTFLoader-r149.js` | F13 · Renderer web et présentation du match. Logique ou présentation web à adapter ; aucun chargement Godot attesté. |
| `match3d/asset-player.js` | F13 · Renderer web et présentation du match. Logique ou présentation web à adapter ; aucun chargement Godot attesté. |
| `match3d/rugby-player-v22.js` | F13 · Renderer web et présentation du match. Logique ou présentation web à adapter ; aucun chargement Godot attesté. |
| `match3d/premium-motion.js` | F13 · Renderer web et présentation du match. Logique ou présentation web à adapter ; aucun chargement Godot attesté. |
| `match3d/premium-camera.js` | F13 · Renderer web et présentation du match. Logique ou présentation web à adapter ; aucun chargement Godot attesté. |
| `match3d/stadium-atmosphere.js` | F13 · Renderer web et présentation du match. Logique ou présentation web à adapter ; aucun chargement Godot attesté. |
| `match3d/stadium-crowd.js` | F13 · Renderer web et présentation du match. Logique ou présentation web à adapter ; aucun chargement Godot attesté. |
| `match3d/crowd-animation.js` | F13 · Renderer web et présentation du match. Logique ou présentation web à adapter ; aucun chargement Godot attesté. |
| `match3d/player-model.js` | F13 · Renderer web et présentation du match. Logique ou présentation web à adapter ; aucun chargement Godot attesté. |
| `match3d/contact-animation.js` | F13 · Renderer web et présentation du match. Logique ou présentation web à adapter ; aucun chargement Godot attesté. |
| `match3d/impact-effects.js` | F13 · Renderer web et présentation du match. Logique ou présentation web à adapter ; aucun chargement Godot attesté. |
| `match3d/rugby-ball-model.js` | F13 · Renderer web et présentation du match. Logique ou présentation web à adapter ; aucun chargement Godot attesté. |
| `match3d/broadcast-pitch.js` | F13 · Renderer web et présentation du match. Logique ou présentation web à adapter ; aucun chargement Godot attesté. |
| `match3d/match3d.js` | F13 · Renderer web et présentation du match. Logique ou présentation web à adapter ; aucun chargement Godot attesté. |
| `premium-editorial.js` | F15 · Rendu/ergonomie web ou projection PC. Écran/adaptateur web ; récupérer le concept utile dans Godot, sans charger HTML/CSS/DOM. |
| `premium-squad.js` | F15 · Rendu/ergonomie web ou projection PC. Écran/adaptateur web ; récupérer le concept utile dans Godot, sans charger HTML/CSS/DOM. |

**Les 39 scripts communs**, dont la présence n’implique pas que toutes les commandes soient accessibles :

- `storage.js`
- `world-data.js`
- `rugby.js`
- `frontrow.js`
- `restarts.js`
- `matchflow.js`
- `playbook.js`
- `manager.js`
- `manager-squad.js`
- `tactical-plans.js`
- `match-actions.js`
- `match2d.js`
- `match-v61-advisor.js`
- `match-cockpit.js`
- `economy.js`
- `development.js`
- `finance-planning.js`
- `board-planning.js`
- `academy-planning.js`
- `transfer-planning.js`
- `career-history.js`
- `career-integration.js`
- `club-ai.js`
- `reputation.js`
- `coach-market.js`
- `coach-opportunities.js`
- `facilities.js`
- `rugby-world.js`
- `financial-recovery.js`
- `world-career.js`
- `ai-roster-cycle.js`
- `v39.js`
- `manager-mobility.js`
- `saves.js`
- `opposition.js`
- `match-preparation.js`
- `lnr-v11-aging.js`
- `game.js`
- `match3d/scene-adapter.js`

**Les sept modules uniquement natifs** : `france-clubs.js`, `rugby-common-rosters.js`, `rugby-roster-foundation.js`, `france-competition.js`, `france-knockout.js`, `france-career.js`, `france-save-validation.js`. Ils assurent territoires, base commune, registre v1/v2, deux divisions, phases finales, cycle de carrière et validation.

| Bibliothèque racine non chargée web/natif | Statut et décision |
|---|---|
| `board-calendar.js` | Objectifs datés/revues purement calculatoires (F07/C27). |
| `coach-career.js` | Bibliothèque V58 consolidée #247, pas la mobilité S.club déjà active (F11). |
| `coach-contract-cycle.js` | Bibliothèque V58 consolidée #247, pas la mobilité S.club déjà active (F11). |
| `coach-negotiations.js` | Bibliothèque V58 consolidée #247, pas la mobilité S.club déjà active (F11). |
| `world-audit.js` | Simulateur/audit annuel indépendant V51, pas la vraie carrière jouée ; ne pas remplacer le moteur natif. |
| `world-finance.js` | Simulateur/audit annuel indépendant V51, pas la vraie carrière jouée ; ne pas remplacer le moteur natif. |
| `world-simulation.js` | Simulateur/audit annuel indépendant V51, pas la vraie carrière jouée ; ne pas remplacer le moteur natif. |

Cette différence fait ressortir, en plus de la presse, les omissions **sponsor/revues**, **délégation simple staff**, **socle satisfaction/promesses**, **bureau agents**, **briefing V69**, **centre des 15 Espoirs** et **H2H/palmarès**. Des fonctions chargées peuvent être actives en arrière-plan mais privées d’action explicite dans Godot ; des overlays web comme V69/V70 peuvent ajouter de vrais effets moteur tout en étant absents de Windows. Les anciens simulateurs V51 restent des laboratoires indépendants : ne pas les substituer aux vrais matchs pour créer une fausse carrière longue.


Les objectifs individuels V38 sont aussi dans le socle chargé : `economy.js:proposeIndividualObjective`, `confirmIndividualObjective`, `reviseIndividualObjective`, avec `tests/v38-individual-objectives.cjs`. Les projeter dans C09 évite de recréer un gestionnaire parallèle. Les dynamiques V39 sont également chargées ; leur présence ne signifie pas que le carnet Godot permette de choisir les objectifs ou engagements. Les contrôleurs de satisfaction, relations et objectifs restent les autorités avant les extensions V64/V70/V117.
## Limites et réception à appliquer

Les commandes et tests des candidats sont des **vérifications à exécuter lors de leur implémentation**, pas des succès de cet audit. Pour la lecture : état/RNG/octet de profil invariants, identités par ID et pack courant, vrais contrôles Godot aux trois tailles. Pour les actions : gardes, devis exact, effet réel, rollback disque et reprise/export/import. Pour tout état nouveau : champ optionnel strict, aucune création à l’affichage, validation des anciennes carrières, bornes et carrière réellement jouée.

Aucune nouvelle règle de rugby n’est validée. Profil de match historique et compétition française 2026–2027 restent distincts, finances fictives. Les limites des lois, des collectes et du monde fermé demeurent explicites. Les preuves CI historiques appartiennent à leurs HEAD ; elles ne qualifient pas un futur raccord natif.




## Raccordement dans le chantier natif du 8 novembre

Le tableau décrit le main3fe6d160 avant ce chantier. Les dossiers adverse/besoins/bilan, la formation initiale15Espoirs, les délégations, les missions, le registre des staffs et le coach flottant sont raccordés dans la branche staff-decisions-bulles ; leur publication, CI et réception de distribution restent à vérifier avant de les déclarer livrés. Les fonctions Presse, rivalités avancées et formationV73–104 restent des ports distincts : aucune fusion globale de brouillons n’est annoncée.

Les essais techniques supplémentaires ont reproduit les vrais blocages de chargement/validation (presse requise avant reprise, calendrier26/34 semaines, Espoirs limités14clubs). Ces constats guident les lots suivants et ne justifient aucun reset ni assouplissement des validateurs.

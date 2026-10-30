# Journal de développement — Cadrage Débordement

> Document de passation partagé entre deux comptes ChatGPT de même niveau, intervenant **en alternance, jamais simultanément**. GitHub reste l'unique source de vérité. Ce document décrit l'état connu à la date de sa dernière mise à jour ; toujours le confronter aux commits, branches, pull requests et fichiers actuels avant de travailler.

**Dernière mise à jour : 30 octobre 2026.**  
**Version annoncée dans `README.md` : 17 (fusionnée sur `main` ; validation Windows native non confirmée).**  
**Branche de référence : `main`.**

## État du projet

Jeu de management de rugby à XV en français, jouable dans le navigateur sans compilation, avec une version Windows portable (lanceur Go sous `offline/`). Le code de jeu est dans `dist/`, les tests JavaScript dans `tests/` et la documentation dans `docs/`.

Fonctionnalités documentées : effectif et feuille à 23, staff, recrutement, contrats, finances fictives, formation et progression, préparation adverse, plans tactiques, simulation des matchs, terrain 2D et commentaires synchronisés, carrière et sauvegardes. Voir `README.md` pour le détail des versions.

Le profil réglementaire documenté du moteur est **`fr-pro-2025` (saison 2025/26)**. Ne pas présumer que les règles 2026/27 sont intégrées. Lire `docs/rugby-rules-reference.md` avant de modifier les lois ou la simulation.

## Derniers travaux vérifiés

| Date | Référence | Travaux | État |
| --- | --- | --- | --- |
| 30/10/2026 | `600ae6f` / PR #2 | V17 : géométrie des transformations, scène 2D, test `goalkicking.cjs`, workflow CI, README | Fusionnée sur `main` ; CI de la PR réussie (syntaxe + toutes suites `tests/*.cjs` hors harness) ; CI post-fusion à confirmer |
| 30/10/2026 | `541d32b` | Protocole de continuité des deux comptes ajouté à `AGENTS.md` | Présent sur `main`, contenu vérifié |
| 30/10/2026 | `21dce3d` / PR #1 | Probabilité de faute de main ajustée selon la qualité des passes des joueurs actifs dans `dist/tactical-plans.js` | Fusionné sur `main`, contenu vérifié ; tests non exécutés lors de cette intervention |
| 30/10/2026 | `dbcb0f3` | Version 16 : application Windows hors ligne et sauvegardes sur disque | Historique du dépôt ; tests Windows natifs non revendiqués dans la documentation |
| 30/10/2026 | `45b6d75` | Version 15 : préparation adverse, comparaisons et analyse des consignes | Historique du dépôt |

Les références ci-dessus sont des repères historiques, **pas une garantie qu'aucun nouveau commit n'existe**. Vérifier GitHub à chaque reprise.

## Décisions de développement

- Les deux comptes ChatGPT sont des contributeurs **de même niveau**, travaillent **successivement** et ne doivent pas demander à l'utilisateur le bilan du travail de l'autre.
- Chaque session commence par la lecture de l'état actuel de GitHub : commits, différences, branches, PR et `AGENTS.md`, puis ce journal.
- Chaque changement doit être **commité sur GitHub et vérifié après publication**. Une branche non fusionnée ne constitue pas une livraison sur `main`.
- Préférer des corrections ciblées et compatibles avec les sauvegardes existantes. Pour les changements risqués, passer par une branche/PR ; pour les changements simples et vérifiés, `main` peut être utilisé conformément à `AGENTS.md`.
- Ne pas confondre règles officielles du rugby, règlements français de compétition et coefficients fictifs de simulation.
- Ne jamais présenter les données financières fictives du jeu comme des budgets réels.

## Problèmes connus et limites à examiner

1. **Transformations :** la V17 calcule désormais une distance et un angle indicatifs pour la transformation, mais la position latérale de l'essai reste approximative ; essai et transformation restent une seule action.
2. **Discipline :** `awardPenalty` utilise une probabilité de carton simplifiée dépendant surtout de la discipline collective. Les causes de faute, leur gravité et les répétitions méritent un modèle plus explicite.
3. **Équilibre tactique :** les coefficients de réussite, fatigue, fautes de main et gains de terrain sont fictifs. Le nouvel ajustement lié à la qualité des passes n'a pas encore fait l'objet d'une campagne de simulations statistiques documentée.
4. **Règles et match :** la documentation réglementaire recense des abstractions et des vérifications restantes ; ne pas revendiquer une conformité intégrale aux lois World Rugby ou aux compétitions 2026/27.
5. **Windows portable :** le `README.md` indique qu'une validation native sur Windows reste à confirmer.

Ces points sont des **limites documentées ou pistes d'audit**, pas nécessairement des anomalies reproduites par un test.

## Prochaines priorités proposées

1. Vérifier la CI post-fusion de `main` et mesurer statistiquement l'impact des ajustements tactiques et des transformations sur un échantillon de simulations.
2. Raffiner le placement latéral des essais, la prise de décision sur les pénalités et la compatibilité des matchs sauvegardés, sans inventer de données de match.
3. Examiner les cartons, l'avantage et les fautes répétées à partir des règles officielles applicables au profil simulé.
4. Calibrer les styles offensifs et défensifs sur plusieurs matchs et documenter les résultats, sans présenter les coefficients comme des statistiques réelles.

Ces priorités sont **proposées**, non des tâches déjà exécutées ou approuvées pour toutes les sessions.

## Procédure de passation obligatoire

À la **reprise** :
1. Lire `AGENTS.md` et `DEVELOPPEMENT.md`.
2. Consulter GitHub pour identifier les derniers commits, fichiers modifiés, branches et pull requests ouvertes/fusionnées.
3. Vérifier si les décisions, problèmes et priorités ci-dessus sont encore exacts ; mettre à jour le journal si nécessaire.
4. Poursuivre le chantier demandé depuis le dernier état réel du dépôt, sans demander à l'utilisateur ce que l'autre compte a fait.

À la **fin d'un chantier significatif** :
1. Mettre à jour les sections « Derniers travaux », « Décisions », « Problèmes connus » et « Prochaines priorités » selon les faits réellement vérifiés.
2. Inscrire les références de commits/PR et le résultat des tests, ou indiquer explicitement « non exécutés ».
3. Commiter la mise à jour du journal sur GitHub et **vérifier** son contenu publié.
4. Signaler les changements restant sur une branche ou en attente de fusion, sans les annoncer comme livrés sur `main`.

Les commits, le code et les tests prévalent sur ce résumé en cas de contradiction.

## Vérification V17 — 30 octobre 2026

- **Contrôle exécuté :** six assertions Node.js isolées sur la formule géométrique et ses conséquences (centre vs aile, vent, fatigue, distance) : réussies. Ces assertions utilisent une copie minimale de la formule et **ne remplacent pas** l'exécution du code complet du dépôt.
- **Validation GitHub Actions :** exécution PR `41055792667` réussie sur la branche `feature/v17-goalkicking`, avec étape « Syntaxe JavaScript » et étape « Tests du jeu » réussies (boucle sur `tests/*.cjs` hors `harness.cjs`, comprenant les 17 suites). Exécutions push précédentes réussies également. Aucun test local du dépôt complet n'a été exécuté pendant cette session ; les simulations statistiques dédiées à la V17 restent à faire.
- **Automatisation ajoutée :** `.github/workflows/tests.yml` pour vérifier syntaxe et suites Node sur GitHub Actions. PR #2 fusionnée en squash dans `main` via `600ae6fa055354a05405de86749e276d731a2a21` ; présence du test et du workflow vérifiée sur `main`. Une nouvelle exécution CI `41056246563` a été déclenchée sur le commit de fusion ; son résultat final était encore en cours au moment de ce relevé.
- **Limites :** les probabilités sont des coefficients fictifs ; les positions latérales d'essai restent schématiques, et les matchs déjà en cours ne disposent pas d'une position latérale historique enregistrée.

## Chantier V18 — discipline (branche de travail)

- Branche `feature/v18-discipline` issue de `ca60c62` ; moteur enrichi de catégories de fautes, historique de récidives, sanctions jaunes et rouges simulées, sans modifier le profil réglementaire `fr-pro-2025` ni les matchs historiques.
- Nouveau test `tests/discipline.cjs` pour les incidents, l'historique et le chargement d'une carrière.
- **Statut : livré sur `main` via PR #3, commit `b523481a9ed142f1f9e76b21875029a059e9895b`.** Les tests V18 sur la PR sont réussis, et la CI post-fusion V17 a réussi ; le modèle de gravité est un choix de simulation, pas une transposition complète du protocole officiel d'arbitrage.
- Priorité suivante : V19 — améliorer la gestion de l'avantage et les conséquences tactiques des exclusions, avec tests de sauvegarde et validation CI.

### Validation complémentaire V18

- Correctif `8d054b6` : suppression d'un tirage aléatoire supplémentaire dans la sélection des incidents, qui modifiait le scénario déterministe du test `tests/matchflow.cjs` (échec `l.flow.advantage.kind` sur valeur nulle).
- Test de compatibilité enrichi par `566f94b` : sauvegarde portable, import et reprise d'une ancienne sauvegarde sans `disciplineHistory`.
- Les workflows `41056994977` et `41057000494` se sont terminés avec succès. Les workflows `41057182500` et `41057189838` sur le dernier commit de la PR #3 (`ea2e663`) ont également réussi. PR #3 fusionnée dans `main` via `b523481a9`. La CI post-fusion de V18 est à contrôler séparément.

### Livraison V18 — 30 octobre 2026

- PR #3 fusionnée en squash sur `main` (`b523481a9ed142f1f9e76b21875029a059e9895b`). Les tests GitHub Actions de la branche et de la PR sont réussis sur son dernier commit (`41057182500`, `41057189838`).
- Vérification des sauvegardes : scénarios de restauration de l'historique, d'import portable et de reprise d'un état antérieur sans champ disciplinaire inclus dans la suite validée.
- La discipline et les décisions de cartons restent des modèles simplifiés ; le référentiel des règles demeure la référence pour les futures améliorations.
- **Prochaine priorité unique : V19 — arbitrage de l'avantage et effets tactiques du jeu en infériorité numérique.**

## Chantier V19 — avantage et infériorité numérique

- Branche `feature/v19-advantage-numerical` depuis `main` après confirmation des CI post-fusion V18 (`41057455417` et `41057476009`, toutes deux réussies).
- Le nouveau profil `advantageModel=2`, activé uniquement pour les matchs créés après V19, affine la reconnaissance d'un avantage territorial après plusieurs phases ; les matchs sauvegardés antérieurs conservent leur modèle précédent.
- En jeu au large, l'effet du différentiel de joueurs actifs est accru : l'exclusion pénalise l'équipe en infériorité et profite à son adversaire ; le modèle existant de retour des cartons demeure inchangé.
- Tests dédiés `tests/v19-advantage.cjs` pour avantage, supériorité numérique et sauvegardes anciennes. Coefficients fictifs, non assimilables à des seuils réglementaires.
- **Livré sur `main`** : workflow `41057808869` réussi sur le dernier commit de PR #4 (`45e38150`), fusion squash `bc8bdfb57c6a8af7554076f3b40b799ca225347b`. La CI post-fusion doit être vérifiée séparément.

### Livraison V19 — 30 octobre 2026

- PR #4 fusionnée sur `main` via `bc8bdfb57c6a8af7554076f3b40b799ca225347b` après succès complet de GitHub Actions `41057808869`.
- Tests ajoutés pour avantage territorial, différentiel de joueurs actifs et compatibilité des anciennes sauvegardes ; tests du jeu exécutés avec succès sur la PR.
- **Priorité V20 unique : améliorer l'intelligence tactique de l'IA en infériorité numérique**, en adaptant automatiquement les choix d'attaque et de défense aux cartons, avec tests déterministes et compatibilité des sauvegardes.

## Documentation réglementaire — PR #5 (30 octobre 2026)

- PR #5 fusionnée sur `main` par squash `0f91688a3969a401f1e972247797cb7dd6d71416` ; fichier `docs/matrice-tracabilite-rugby.md` relu sur `main` après fusion.
- Workflow de PR GitHub Actions n°28 (`41058981202`) terminé avec succès : syntaxe JavaScript et tests du jeu réussis. Aucun changement du moteur ou des sauvegardes.
- Audit CI : `.github/workflows/tests.yml` exécute séquentiellement toutes les suites `tests/*.cjs` hors `harness.cjs`, sans limite de temps par suite ni mesure de durée ; les logs montrent des simulations longues et un avertissement de dépréciation Node 20 pour `checkout@v4` et `setup-node@v4`. Ce sont des pistes d'amélioration, pas des échecs de test.
- Prochaine priorité CI : mesurer la durée de chaque suite, plafonner la durée totale et moderniser les actions GitHub sur une PR séparée, sans modifier le moteur.

## Suivi événementiel des résultats CI — PR dédiée (30 octobre 2026)

- Ajout de `.github/workflows/pr-ci-results.yml` : déclenchement `workflow_run` à la fin de `Tests JavaScript` pour les exécutions de pull request.
- Publication du statut de succès ou d'échec et du lien vers l'exécution dans un commentaire de PR, mis à jour plutôt que dupliqué ; récupération alternative de la PR lorsque l'événement n'en liste aucune, puis vérification en direct que la PR est ouverte et que son SHA correspond au commit testé avant de publier.
- Aucun polling et aucune fusion automatique. Ce suivi produit un commentaire GitHub, pas une notification ChatGPT instantanée ; le déclencheur ne sera opérationnel qu'après intégration du workflow sur la branche par défaut.
- Vérification événementielle réelle à effectuer après fusion sur `main` et prochaine fin de workflow de PR.

### Livraison et contrôle du suivi événementiel — 30 octobre 2026

- PR #7 fusionnée dans `main` après succès du workflow de PR n°36 (`41060386114`), commit squash `6975c32495be7c3efa7ce977a06040dfd2c95de3` ; workflow et journal relus sur `main`.
- CI post-fusion sur `main` n°37 (`41060753951`) réussie.
- Essais réels du déclencheur : workflows événementiels n°2 (`41061094373`) et n°3 (`41061693762`) bien déclenchés, mais publication du commentaire refusée avec HTTP 403 « Resource not accessible by integration » sur `POST /issues/{numero}/comments` (PR #6, PR de contrôle #8).
- Correctif proposé sur PR dédiée : donner explicitement `pull-requests: write` au jeton du workflow en plus de `issues: write`. Contrôler une exécution réelle après fusion ; tant que la publication n'est pas vérifiée, ne pas annoncer le suivi comme opérationnel.

### Validation opérationnelle du suivi événementiel — 30 octobre 2026

- PR corrective #9 fusionnée sur `main` par squash `69135eab67e8eaede7c4def772a4b2a61ad4aee6`, après succès du workflow CI n°39 (`41062056608`). La correction accorde `pull-requests: write` au `GITHUB_TOKEN`.
- CI post-fusion de la PR #9 sur `main` : exécution n°40 (`41062314305`) terminée avec succès.
- Test de bout en bout : relance de la CI de la PR temporaire #8, run n°38 (`41061402910`), terminée avec succès ; l'événement a déclenché le workflow « Résultats CI des pull requests » n°5 (`41062630446`), également réussi.
- Publication réelle constatée : commentaire créé par `github-actions[bot]` sur la PR #8, https://github.com/Xynph/cadrage-debordement/pull/8#issuecomment-6523854663, comprenant le statut ✅ Réussie, le lien du run n°38 et le SHA testé. La PR #8 de contrôle a été fermée sans fusion.
- Le suivi événementiel est opérationnel pour publier les résultats CI directement dans les PR GitHub ; il ne génère pas de notification instantanée dans ChatGPT. Les workflows n°2 à n°4 antérieurs au correctif ont échoué en HTTP 403 ; la validation n°5 confirme la résolution du problème.
- Prochaine priorité : finaliser la PR #6 (mesure des durées et délais de tests) avant de reprendre V20.

## Livraison CI — PR #6 : durées et limites de temps (30 octobre 2026)

- PR #6 fusionnée dans `main` par squash `7d73b1cc39e0900f11c01481c6f458e045e2ea1d`, après validation du workflow GitHub Actions n°33 (`41059347179`) sur la tête `0fb74121f9d90ffa9b39d6009fe09ec4c3fc742a` ; deux tentatives réussies (initiale et relance).
- Logs de la dernière tentative du n°33 : 19 suites `tests/*.cjs` exécutées et réussies, `tests/harness.cjs` exclu comme auparavant ; durées affichées à la seconde, cumul des durées arrondies par suite de 112 s et durée totale du job de 119 s.
- Suites les plus longues : `tests/rugby.cjs` 38 s, `tests/opposition.cjs` 29 s, `tests/saves.cjs` 15 s, `tests/tactical-plans.cjs` 14 s. Aucune ne dépasse le délai de 180 s.
- Workflow `.github/workflows/tests.yml` désormais sur `main` : `actions/checkout@v5`, `actions/setup-node@v5`, limite de 20 min par job, 180 s par suite, diagnostic d'échec et durée par suite, déclenchement `ci/**`. Pas de changement du moteur ni des formats de sauvegarde.
- CI post-fusion confirmée **réussie** sur le commit de merge : workflow de push n°42 (`41063500039`), syntaxe et tests du jeu tous réussis. Le commit documentaire `b48d1c2739940f670cce00296b032596295f14dc` a également passé la CI `main` n°43 (`41063635649`).
- **Priorité V20 unique : IA tactique réactive à l'infériorité numérique** ; adapter les choix offensifs et défensifs au différentiel de joueurs actifs (cartons jaunes/rouges), prévoir des tests déterministes pour 15 contre 15, 15 contre 14 et 15 contre 13, tout en préservant le comportement des sauvegardes anciennes.

## Chantier V20 — IA tactique et infériorité numérique (30 octobre 2026)

- Branche `feature/v20-numerical-ai`, issue de `main` au commit `e53c7727a0ace019a6deb98c03f7fa0ed5c1983f`.
- Dans `dist/opposition.js`, les nouveaux matchs activent le profil optionnel `numericalAiVersion=1`. Pour l'IA classique et experte, une variation du différentiel de joueurs actifs liée à un carton jaune, un rouge ou un remplacement autorisé provoque une réévaluation du jeu offensif et de l'organisation défensive à la prochaine minute de simulation ; le plan antérieur est mémorisé et rétabli à l'égalité numérique. L'IA découverte conserve son plan stable.
- Les choix sont des **abstractions tactiques du jeu** et non des obligations du règlement : 14 contre 15, jeu plus resserré (ou occupation sous la pluie) et couverture prudente ; 13 contre 15, occupation au pied et couverture prudente ; en supériorité, jeu au large avec pression défensive adaptée au différentiel et à la condition.
- Les sanctions, durées des jaunes/rouges, droits de remplacement et nombre de joueurs actifs restent calculés par le moteur existant, conformément au profil `fr-pro-2025`; aucune modification du modèle disciplinaire. Les cartes jaunes expirent au temps de jeu prévu ; le rouge définitif n'autorise pas de remplacement ; le rouge temporisé ne rétablit l'effectif qu'après l'entrée réglementaire d'un autre joueur.
- Dans `dist/saves.js`, validation du profil V20 et de la mémoire des plans ; les rencontres déjà sauvegardées sans marqueur V20 conservent le comportement précédent. Aucun changement du format d'export ni des valeurs du mode de difficulté.
- Ajout de `tests/v20-numerical-ai.cjs` : effectifs 15v15, 15v14, 15v13, cartons jaunes et leurs expirations, rouge définitif et rouge remplaçable, respect des consignes de l'utilisateur, absence de spam d'événements, restauration d'un export portable, anciennes sauvegardes et données invalides.
- **Validation** : la PR #10 a passé les 20 suites JavaScript du workflow n°59 (`41078699280`) sur le commit `1e17e3ee816eaa77958ccd8e6e6d37c80ea620c6` ; les scénarios V20, les tests de règles, les sauvegardes et les simulations existantes sont tous réussis. Les premières régressions de fixtures anciennes ont été corrigées avant fusion.
- **Livraison V20 sur `main`** : PR #10 fusionnée par squash `d4d0ecef7a95a056fdc5c694dd209467e7e65983` ; fichiers moteur, sauvegardes et tests relus sur la branche principale. La CI post-fusion n°60 (`41079132236`) est terminée avec succès (syntaxe et tests du jeu).
- **Priorité V21 unique** : aider le manager humain à détecter les déséquilibres numériques en cours de match et lui proposer des ajustements d'attaque/défense contextualisés, sans jamais modifier automatiquement ses consignes ; ajouter les tests d'affichage, de décision et de compatibilité des sauvegardes.

## Chantier V21 — assistant tactique du manager humain (30 octobre 2026)

- Base de départ : `main` au commit `de0377c15ca08b7f03e9a2f4cbc64a4222b49653` (V20 fusionnée, CI n°61 verte). Branche `feature/v21-human-numerical-advice`.
- `dist/tactical-plans.js` : conseil dérivé de l'effectif **réellement actif** (15 contre 15 : aucun conseil, 14 contre 15 / 13 contre 15 : réduction de risque ; supériorité : exploitation d'espace). Analyse du score, de la météo, des qualités du pack et des arrières, de leur fraîcheur et du temps réglementaire restant. Indication des minutes de carton jaune ou de remplacement autorisé après rouge de 20 minutes lorsqu'elles sont connues ; rouge définitif distingué.
- Lecture seule : `numericalStaffAdvice()` et `numericalAdvicePanel()` ne modifient pas les états des clubs, les consignes ni les sauvegardes. Aucun champ persisté, aucune migration ni changement de format de carrière. L'ancien profil de match sans `numericalAiVersion=1` ne présente pas cet assistant.
- Application par le manager **uniquement après un clic**, dans une rencontre en pause sans présentation en retard : `applyNumericalAdvice()` recalcule la recommandation, rejette une suggestion périmée, puis passe par les commandes existantes `setLiveTactic` ou `setLiveDefence`. Les réglages par zone du carnet de jeu peuvent toujours prévaloir.
- `dist/rugby.js` et `dist/style.css` : panneau lisible au centre du match, visible aussi en direct avec boutons désactivés jusqu'à la pause, masqué pendant la lecture d'événements antérieurs et après la rencontre.
- `tests/v21-numerical-advice.cjs` : tests déterministes 15/15, 14/15, 13/15, cartons jaunes, rouges permanents et temporisés, égalisation des effectifs, météo, score, temps restant, forme des joueurs, rendu, sécurité des clics, sauvegarde portable et compatibilité ancienne.
- Référentiel rugby : loi 3 (effectifs) et loi 9 (sanctions) inchangées, profil `fr-pro-2025` conservé. Ces recommandations sont des **abstractions tactiques** du jeu et ne prétendent pas être prescrites par World Rugby.
- **Validation PR V21** : les 21 suites du workflow n°72 (`41082012790`) sont passées sur le commit `d50fbcf16db0615ac49eec3cb5702a24c2c5b946`, y compris `tests/v21-numerical-advice.cjs` et les tests des anciennes sauvegardes. Les deux premières tentatives ont révélé des erreurs de scénarios de test (curseur de relecture et carton expiré), corrigées sur la branche avant fusion.
- **Livraison** : PR #11 fusionnée dans `main` par squash `2070b9b82c13c73545f7c2194cfffb9d0d7945ed` ; code des conseils vérifié sur la branche principale. CI post-fusion n°73 (`41082409688`) déclenchée ; son verdict devra être confirmé. Le présent ajout documentaire déclenche une autre CI de `main`.
- **Amélioration prioritaire du cycle de développement avant V22** : réduire les validations redondantes `push` et `pull_request`, séparer tests rapides et simulations longues, paralléliser les suites déterministes tout en conservant la règle de fusion seulement si tous les tests pertinents sont verts.
- **Piste fonctionnelle V22** : améliorer les conseils du staff par une explication comparative des risques et bénéfices de chaque consigne, sans automatiser les choix humains.

## Optimisation des validations GitHub Actions — PR CI dédiée (30 octobre 2026)

- V21 : la PR #11 a été fusionnée dans `main` au commit `2070b9b82c13c73545f7c2194cfffb9d0d7945ed`. Le workflow de PR n°72 (`41082012790`) a validé les **21 suites**, puis les workflows de `main` n°73 (`41082409688`) et n°74 (`41082478423`) ont tous deux réussi. Le dernier état de départ est `main` `4dc0a364ea4d794727040072079de7003753cb89`.
- Branche `ci/fast-targeted-workflows` réservée aux changements CI : **aucun moteur de match ni format de sauvegarde modifié**.
- `.github/workflows/tests.yml` : `concurrency` annule les workflows obsolètes pour une même branche de développement ou une même PR. Les validations de `main` ne sont pas annulées. Les événements `push` et `pull_request` restent indépendants afin que le job complet de PR ne soit pas écrasé par une validation ciblée.
- **Avant toute fusion**, l'événement `pull_request` exécute **tous** les `tests/*.cjs` (hors `harness.cjs`) et la syntaxe, comme auparavant. Les `push` sur `main` exécutent également la suite complète. La limite par suite de 180 s et la limite de job de 20 min demeurent.
- Sur les seuls `push` `feature/**` et `ci/**`, `ci/select-tests.cjs` choisit les tests correspondants aux fichiers modifiés depuis la base commune avec `main`. Les fichiers de sauvegarde et de règles ont des dépendances de test explicites ; toute modification inconnue, toute modification du harness ou toute impossibilité de comparer les branches déclenche **par prudence la suite complète**. Une mise à jour purement documentaire n'entraîne pas les simulations lors du `push` de développement.
- `tests/ci-selection.cjs` vérifie ce choix conservateur, ses dépendances et ses replis. Le nom du job requis `tests` reste inchangé. La sécurité de fusion dépend aussi des règles de protection configurées sur GitHub : ne jamais confondre un `push` ciblé vert avec le contrôle complet `pull_request`.
- **Validation réelle** : PR #12 fusionnée dans `main` par squash `704c32112a295b3d5bbc4a73fa4be9fe75093a3a`. Workflow ciblé de branche n°79 (`41083423298`) **réussi**, 1 suite `tests/ci-selection.cjs`, job de **7 s**. Workflow de PR n°80 (`41083458621`) **réussi**, **22 suites complètes**, job de **122 s**, sans erreur. Workflow post-fusion sur `main` n°81 (`41083892646`) **réussi**, **22 suites complètes**, job de **121 s**. Les trois durées sont calculées d'après les horodatages début/fin des jobs GitHub ; aucun moteur de match ni format de sauvegarde modifié. La validité du mécanisme d'annulation lors d'une course entre commits reste à observer lors de prochains développements ; seules sa configuration et les exécutions ciblées/completes ont été directement contrôlées.
- **Priorité fonctionnelle V22, une seule** : expliquer au manager humain les compromis entre les tactiques conseillées (mètres potentiels, risque de fautes, couverture, fatigue), avec des tests déterministes et sans appliquer automatiquement ses décisions.

## Chantier V22 — compromis quantifiés du modèle tactique (30 octobre 2026)

- Branche `feature/v22-tactical-tradeoffs` créée depuis `main` au commit `bcd6ccae23c2cccd4005e4571c06632d9d9e15fd` ; CI n°82 verte. Pas de modification des règles de sanctions (lois 3 et 9) ni des barèmes officiels de compétition.
- `dist/tactical-plans.js` : ajout des fonctions de **lecture seule** `numericalAdviceModel()` et `numericalAdviceComparison()`. Elles comparent la consigne actuelle et la proposition V21 **à circonstances identiques**, au moyen des fonctions et coefficients déjà utilisés par la simulation (`ATTACK_EFFECTS`, `handFaultProbability`, `openKickProbability`, `tacticalLoad`, `tacticalPenaltyAdjustment`, `effectiveAttack`, `effectiveDefence`).
- Attaque : fourchette des mètres du modèle **en cas de progression réussie** ; risque de faute de main par séquence, propension au jeu au pied selon le terrain et indice de dépense offensive. Défense : **ajustement** au risque de pénalité, indice de fatigue défensive et compromis de couverture de profondeur (pression exposant davantage aux grands gains, glissée prudente réduisant l'exposition). Les valeurs sont **internes à ce jeu fictif**, pas des résultats observés ni une promesse de gains.
- Les directives du carnet par zone conservent leur priorité : si elles remplacent la consigne générale, les aperçus restent identiques et le joueur reçoit une explication. Le conseil est toujours facultatif et n'a **aucun effet sur le match ni la sauvegarde tant que le manager ne clique pas**. La fonction existante d'application explicite V21 reste inchangée.
- `dist/style.css` : présentation lisible des comparatifs en desktop et mobile, sans nouvelle dépendance ni changement d'outil de rendu.
- `tests/v22-tactical-comparison.cjs` : comparaisons réelles de coefficients, état de lecture seule, météo, carnet par zone, garde-fous sur application des consignes, sauvegardes portables et anciennes, infériorités 14/15 et 13/15. `ci/select-tests.cjs` et `tests/ci-selection.cjs` intègrent et vérifient le nouveau test dans le ciblage de développement tout en conservant toutes les suites sur PR et `main`.
- Linear consulté : aucun projet ni ticket « Cadrage Débordement » trouvé. GitHub et ce journal restent le suivi de référence ; aucun projet Linear artificiel n'a été créé. Context7 et Figma non utilisés car aucune API de bibliothèque externe ni refonte de design n'est requise.
- **Validation et livraison confirmées** : la PR #13 a été fusionnée dans `main` par squash `90733f7e88a83177578267ed066ddac3f165d097`. CI ciblée de branche n°89 (`41086190546`) : **7 suites réussies** (incluant tests V22 et sauvegardes). CI complète de PR n°90 (`41086383922`) sur `f6ea417bb95bc08d4ce1e3f2081e32e82f9c36b7` : **23 suites réussies**, zéro erreur. CI post-fusion sur le commit de merge n°91 (`41086766322`) : **23 suites réussies**, zéro erreur. Les tests ciblés avaient révélé une attente obsolète dans `tests/ci-selection.cjs` après ajout du test V22 ; elle a été corrigée avant la validation finale. Les anciennes exécutions de branche ont été annulées par la configuration GitHub `concurrency` ; le contrôle complet de PR est resté actif. Le présent commit de documentation déclenche une nouvelle validation sur `main`.
- **Priorité V23 proposée** : expliciter et pouvoir ajuster, sur action du manager, les consignes **locales par zone** du carnet de jeu lorsqu'elles neutralisent une recommandation tactique générale.

## Chantier V23 — recommandations et consignes locales par zone (30 octobre 2026)

- Base vérifiée : `main` au commit `928fe81d2e1ba276cc37c1c0cd60e9a24b89531d`, CI n°92 réussie. Branche `feature/v23-local-zone-recommendations`.
- Dans `dist/tactical-plans.js`, l'assistant signale **toutes les zones du carnet de jeu** où une consigne locale prioritaire diffère de la recommandation actuelle, en distinguant la zone du ballon. Le conflit est visible même si la consigne générale correspond déjà à celle du staff.
- Dans `dist/playbook.js`, le bouton **« Adapter cette zone »** modifie uniquement la consigne locale (attaque ou défense) de la zone choisie, **après un clic explicite et une nouvelle validation du contexte tactique**. Commandes refusées quand le match joue, se termine, est en relecture différée, ou si le conseil a changé. Le plan principal, les autres zones et les consignes adverses restent inchangés.
- `dist/style.css` distingue les conseils locaux pour affichage desktop et mobile. Aucun changement des lois rugby 3/9, des sanctions ou des probabilités du moteur : la priorité locale existante `effectiveAttack/effectiveDefence` est conservée.
- `tests/v23-local-zones.cjs` vérifie les quatre zones, le mode lecture seule, les clics explicites, la protection des actions périmées, le maintien du plan général, le choix par zone, l'export/import portable et les sauvegardes historiques. `ci/select-tests.cjs` et `tests/ci-selection.cjs` incluent les nouvelles régressions dans les contrôles ciblés.
- **Tests ciblés** : workflow de branche n°103 (`41088715426`) **réussi** sur `a0922b47ba7c64089f0f2ad82dfa4ebf7c491069`. Les exécutions de branche obsolètes ont été annulées selon la configuration `concurrency` du dépôt.
- **Validation complète de PR** : workflow n°104 (`41088742771`) **réussi**, les **24 suites JavaScript** validées sur le dernier commit de PR `a0922b47ba7c64089f0f2ad82dfa4ebf7c491069`, y compris `tests/v23-local-zones.cjs`, `tests/saves.cjs`, les tests de règles et les comparatifs V22, sans erreur.
- **Livraison sur `main`** : PR #14 fusionnée par squash `41a7d2746d4134de8e1ff98e1b40a8574feac913`. Workflow post-fusion n°105 (`41089133871`) **réussi** sur ce commit, les **24 suites** validées et aucune erreur dans les logs. Fichiers V23 et présent journal relus sur `main`.
- **Priorité V24 unique** : présenter les compromis tactiques dans les quatre zones du terrain, sans appliquer automatiquement de changements, avec des tests déterministes et de compatibilité des sauvegardes.

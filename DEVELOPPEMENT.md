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
- **Validation** : tests GitHub Actions de la PR et CI post-fusion à consigner après exécution ; aucune fusion avant résultats verts.
- **Piste V21 à évaluer après livraison** : signaler au manager humain les déséquilibres numériques et proposer des consignes adaptées sans changer automatiquement ses choix.

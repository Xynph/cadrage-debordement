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

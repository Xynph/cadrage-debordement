# Journal de développement — Cadrage Débordement

> Document de passation partagé entre deux comptes ChatGPT de même niveau, intervenant **en alternance, jamais simultanément**. GitHub reste l'unique source de vérité. Ce document décrit l'état connu à la date de sa dernière mise à jour ; toujours le confronter aux commits, branches, pull requests et fichiers actuels avant de travailler.

**Dernière mise à jour : 30 octobre 2026.**  
**Version annoncée dans `README.md` : 16.**  
**Branche de référence : `main`.**

## État du projet

Jeu de management de rugby à XV en français, jouable dans le navigateur sans compilation, avec une version Windows portable (lanceur Go sous `offline/`). Le code de jeu est dans `dist/`, les tests JavaScript dans `tests/` et la documentation dans `docs/`.

Fonctionnalités documentées : effectif et feuille à 23, staff, recrutement, contrats, finances fictives, formation et progression, préparation adverse, plans tactiques, simulation des matchs, terrain 2D et commentaires synchronisés, carrière et sauvegardes. Voir `README.md` pour le détail des versions.

Le profil réglementaire documenté du moteur est **`fr-pro-2025` (saison 2025/26)**. Ne pas présumer que les règles 2026/27 sont intégrées. Lire `docs/rugby-rules-reference.md` avant de modifier les lois ou la simulation.

## Derniers travaux vérifiés

| Date | Référence | Travaux | État |
| --- | --- | --- | --- |
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

1. **Transformations :** `goalChance` dans `dist/rugby.js` utilise actuellement une distance fixe de 25 mètres pour les transformations ; l'angle lié au point d'essai n'est pas modélisé. La transformation est traitée dans la même action que l'essai.
2. **Discipline :** `awardPenalty` utilise une probabilité de carton simplifiée dépendant surtout de la discipline collective. Les causes de faute, leur gravité et les répétitions méritent un modèle plus explicite.
3. **Équilibre tactique :** les coefficients de réussite, fatigue, fautes de main et gains de terrain sont fictifs. Le nouvel ajustement lié à la qualité des passes n'a pas encore fait l'objet d'une campagne de simulations statistiques documentée.
4. **Règles et match :** la documentation réglementaire recense des abstractions et des vérifications restantes ; ne pas revendiquer une conformité intégrale aux lois World Rugby ou aux compétitions 2026/27.
5. **Windows portable :** le `README.md` indique qu'une validation native sur Windows reste à confirmer.

Ces points sont des **limites documentées ou pistes d'audit**, pas nécessairement des anomalies reproduites par un test.

## Prochaines priorités proposées

1. Exécuter les suites de tests existantes, en particulier `tests/tactical-plans.cjs`, et mesurer l'impact de la PR #1 sur un ensemble de simulations.
2. Auditer puis améliorer le modèle des transformations et des tirs au but, avec tests de régression et compatibilité des matchs sauvegardés.
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

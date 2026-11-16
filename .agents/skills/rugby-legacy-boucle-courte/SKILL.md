---
name: rugby-legacy-boucle-courte
description: Concevoir, corriger et vérifier une évolution de Rugby Legacy 27 avec une décision de manager explicite, un rejeu court et une observation dans le vrai Godot.
---

# Boucle courte de Rugby Legacy

Lire AGENTS.md et les réservations de #591. Appliquer
`docs/developpement-jeu-boucle-courte.md` et le pont décrit dans
`tools/godot-agent/README.md`.

Avant la modification, formuler en dix lignes au plus la situation du manager,
sa décision, le bénéfice et le coût, le retour observable et la preuve attendue.
Pour un choix de conception, examiner deux ou trois variantes puis recommander
et mettre en œuvre celle qui sert le mieux le jeu dans le périmètre autorisé.
Les grilles CCGS du projet peuvent guider conception, UX, équilibrage et profilage.

Reproduire en `world-champ`, garder l'entrée minimale puis travailler sur son
rejeu. Revenir ensuite au parcours Monde complet. Garder toutes les assertions
et la CI ; mesurer les performances au lieu de les supposer. Un seul Godot à la fois.

Pour une modification visible, piloter le vrai jeu, lire ses erreurs, prendre et
observer des captures aux dimensions pertinentes. Vérifier la cohérence entre
ce qui est dit, le modèle affiché et les effets de la commande. Les recettes
headless ne prouvent pas le rendu. Le pont et les profils restent dans la copie
de développement, les identités réelles dans le dépôt privé.

Ne lancer aucun autre agent ni changer de modèle ou de plafond d'effort sans
l'accord de Léo. Ne pas ajouter de validation utilisateur par fichier : son
autorisation de développement et de fusion dans le périmètre demandé persiste.
Les décisions ouvertes, dépenses et opérations destructives restent à demander.

Rendre un bilan français court : résultat joueur, fichiers, PR, tests observés,
mesures, limites, vérifications non faites et prochaine évolution. Distinguer
le modèle/effort effectifs lorsqu'ils sont exposés de la recommandation GPT‑6.1 Sol.

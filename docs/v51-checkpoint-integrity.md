# Tests renforcés de reprise V51 — branche de qualité indépendante

Ce test vérifie six points de reprise (1, 2, 4, 7, 10 et 14 saisons) et compare l'historique, les événements et les états finaux avec une simulation continue de 15 saisons. Les fixtures mêlent clubs aisés, modestes et déficitaires. Les données des clubs et les checkpoints initiaux ne doivent pas être modifiés.

La branche est issue de `feature/v51-world-simulation`, pour ne pas toucher au travail d'intégration. Le test ne modifie aucune sauvegarde réelle.

**Attention :** la vérification de schéma d'un checkpoint reste partielle dans le moteur V51. Le test n'est pas une garantie anti-corruption complète ; les contrôles d'intégrité supplémentaires devront être ajoutés avant tout branchement aux sauvegardes officielles.

Exécuter : `node tests/v51-checkpoint-integrity.cjs`.

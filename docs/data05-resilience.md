# DATA-05 — Gestion résiliente des erreurs et du budget

Module sans dépendance `tools/data05-resilience.cjs` destiné à être raccordé au collecteur unifié existant : `classify`, `withRetries`, `reserveBudget`, `validateCache`.

- Stop immédiatement l'exécution du traitement de la source en cas de HTTP 401, 402, 403, 429, sans nouvelle tentative automatique (préserve quotas, accès, droits) ;
- Reprend uniquement les erreurs temporaires de réseau et HTTP 5xx, jusqu'à deux tentatives supplémentaires, délais croissants bornés ;
- Vérifie l'identité ID/club/URL et refuse de certifier une appartenance au 01/07/2026 ;
- Réserve les appels payants via compteur avant requête ; une tentative ne dépasse pas la limite configurée.

Validation locale **réellement exécutée** dans le conteneur avec Node et `node --test` sur code identique, 3 tests / 3 réussis : classification, retries, budget/cache. Les tests intégrés à la PR sont `node --test tests/data05-resilience.cjs` ; la CI GitHub du HEAD doit être contrôlée.

Audit réel du corpus effectué dans la conversation via relecture GitHub : 1 592 références, 240 profils des 15 fichiers, 240 uniques, clubs/URLs vérifiés. La PR #133 ajoute l'audit exécutable et ses propres tests (encore en attente de CI au début du cycle) ; **aucune exécution locale de ce test à 240 fichiers n'a été effectuée**, les données n'étant pas téléchargées dans le conteneur.

**Limitation :** ce module est un composant prêt à intégrer, pas un patch déjà raccordé au collecteur principal. La collecte HTTP live reste impossible depuis cet environnement ; aucune consommation de crédits ni prétention de collecte massive. Aucun fichier dist/** modifié, aucune fusion.

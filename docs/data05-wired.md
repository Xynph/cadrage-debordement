# DATA-05 — Raccordement protégé en attente de PR #134

Point d'entrée `tools/data05-wired.cjs` vers le collecteur déjà fusionné `tools/data05-unified.cjs`. Charge explicitement le module de résilience `tools/data05-resilience.cjs` de PR #134 et **refuse tout démarrage en son absence**. Il n'est pas autonome sur `main` tant que #134 n'est pas intégrée ; ne pas contourner cette condition.

Le démarrage CLI actuel utilise `--limit 0`, `--budget 0` : aucune requête et aucun crédit, audit de cache possible après intégration de #134. Les appels directs transitent par un retry borné. Les tentatives Firecrawl comptées dans l'adaptateur sont plafonnées. Les réponses d'accès interdit imposent l'arrêt. Pour une vraie campagne, le wrapper nécessite un adaptateur Firecrawl (non fourni par ce point d'entrée), une clé accessible à Node et une vérification de robots.txt/conditions LNR. **Aucune campagne réseau déclenchée.**

Test `node --test tests/data05-wired.cjs` : paramètres invalides refusés, absence de dépendance #134 bloquante. La CI de PR doit être vérifiée. Prévoir une PR d'intégration ultérieure après #134 pour un pipeline complet et tests d'exécution sur vraies données, sans modification simultanée des fichiers de l'intégrateur.

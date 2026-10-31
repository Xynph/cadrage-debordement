# DATA-05 — Pipeline unifié (CLI)

`node tools/data05-pipeline.cjs` relie le collecteur unifié, le transport HTTP/Firecrawl et les contrôles résilients. **Par défaut, limite 0, budget 0 : import des 240 profils déjà présents sans aucun appel réseau**. `--limit 1 --budget 0 --ack-lnr-access` autorise un essai HTTP réel seulement après vérification de robots.txt et des conditions de consultation LNR. Ne jamais contourner CAPTCHA, HTTP 403, 429 ou restrictions réseau. En cas d'échec, le collecteur peut recourir à Firecrawl uniquement si une clé est disponible et `--budget N` positif. Le budget compte les tentatives API, pas un montant garanti de crédits.

**Dépendances explicites :** module `tools/data05-resilience.cjs` (PR #134) et `tools/data05-transport.cjs` (PR #137). Main ne les contient pas au début de ce cycle. Le module échoue clairement si ces fichiers ne sont pas présents. L'intégrateur devra respecter l'ordre de fusion, la CI et la validation post-fusion.

`node --test tests/data05-pipeline.cjs` : trois tests sur configuration, raccordement effectif par doubles réseau et arrêt sécurisé. Exécution réelle des tests à contrôler dans CI GitHub. Le test d'intégration complet sur les 240 fichiers existe dans la PR #133 déjà fusionnée, via `node tools/data05-audit.cjs`, qui doit rester le contrôle de référence.

**Pas de campagne live lancée ici** : le conteneur producteur n'a pas d'accès direct vérifié aux serveurs LNR et n'a pas de clé Firecrawl accessible au processus Node. Les 1 352 fiches non approfondies restent à collecter ; aucune naissance exacte ou appartenance historique au 1er juillet 2026 n'est inférée.

Aucun fichier `dist/**` ou sauvegarde modifié.

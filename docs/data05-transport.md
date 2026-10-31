# DATA-05 Transport HTTP et Firecrawl (31/10/2026)

Fichiers : `tools/data05-transport.cjs`, `tests/data05-transport.cjs`. Le module expose `createTransport({fetcher,firecrawlKey,firecrawlBudget,timeoutMs,retries})`, avec `direct(url)` pour une page LNR publique et `scrape(url)` pour l'API Firecrawl v2. **L'adaptateur HTTP Firecrawl est effectif** (POST et vérification du JSON) mais **n'est pas encore branché au CLI unifié** `tools/data05-unified.cjs`, et aucune clé n'a été fournie au processus Node ; ne pas prétendre à une campagne live.

Sécurité des coûts : zéro crédit par défaut, compteur réservé avant chaque appel API, aucun retry automatique sur requête Firecrawl payante ; réseau direct : retry borné sur HTTP 5xx / erreurs transitoires, arrêt sur 401/402/403/429. Valide URL `top14.lnr.fr` ou `prod2.lnr.fr` uniquement, avec identifiant numérique. Ne pas contourner robots, limitations serveur ni CAPTCHA.

**Tests réellement exécutés** dans le conteneur : `node --check tools/data05-transport.cjs` + `node --test tests/data05-transport.cjs`, Node v22.16.0, **4/4 PASS**. Les tests utilisent une simulation HTTP et un secret fictif, pas de réseau réel. GitHub CI doit être revérifiée sur HEAD de cette PR.

**Données** : 240 dossiers réels identifiés comme non-dupliqués dans les fichiers DATA-05 (90+60+90) et 1 352 profils non enrichis. La PR #133 prévoit un audit Node complet, mais cette PR ne contient pas cet audit. La PR #136 a connu un échec de syntaxe, corrigé par le producteur sur sa branche (commit 48d77a1), sa CI post-correctif doit être vérifiée. Le dernier main et les réservations #73 restent sources d'autorité.

**Suite impérative** : une intégration future du transport dans le CLI devra tester la récupération HTML et la validation du contenu, la gestion des erreurs, les crédits et le fonctionnement après fusion de la résilience #134. L'accès direct LNR reste non démontré depuis le conteneur actuel. Ne pas lancer un gros scraping avant vérification explicite des modalités du site et du budget réel.

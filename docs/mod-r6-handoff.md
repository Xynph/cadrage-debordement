# R6 — Revue de convergence, PR empilée sur R5

## État
Les PR #97 (catalogue), #99 (registre), #100 (atelier navigateur), #101 (stockage ZIP) et #102 (contrat R5) sont toujours non fusionnées. R6 **ne crée pas un gestionnaire supplémentaire** : il corrige et teste le contrat existant de R5, sur une branche enfant de #102. La PR R6 doit rester basée sur la branche R5 jusqu'à sa réception, puis être rebasée sur `main` par l'intégrateur.

## Correctifs
Validation stricte des dépendances (ID/version, exclusion de soi), conflits, listes sélectionnées et signature de sauvegarde modée avant toute activation. Rejets explicités sans changer le monde fictif. Tests supplémentaires sur anciennes carrières et copies défensives.

## Contrat d'intégration unique
1. R1 définit les types de données et la base fictive. Les faits et images réels restent exclusivement dans des packs externes autorisés.
2. R4 lit et stocke les ZIP, mais ne prend **aucune décision de simulation**.
3. R2 valide les manifestes et les droits déclarés ; R3 vérifie les octets des images et fournit l'interface d'import, sans second état global.
4. **R5/R6 est le seul détenteur de la sélection active**, du monde assemblé et des règles de compatibilité des nouvelles carrières.
5. Le jeu n'active rien automatiquement. L'intégrateur branche explicitement la sélection à la création de carrière uniquement. Une sauvegarde historique sans `modBinding` n'est reprise qu'en univers fictif.
6. Les bases R1/R2 et les manifestes R3/R4 ont des différences de format qui doivent être normalisées dans un adaptateur unique lors de l'intégration (ex. `files` / `records` ; R4 `manifest.json` dans ZIP). **Ne pas annoncer le système comme opérationnel dans le jeu tant que ces points et les tests navigateur ne sont pas résolus.**

## Vérifications
`node tests/mod-unified-r5.cjs` ; `node tests/mod-r6-hardening.cjs`. Contrôle CI complet obligatoire sur le SHA R6 et contrôle post-fusion par intégrateur. Les vérifications statiques ne remplacent pas la réception dans le navigateur et l'application Windows.

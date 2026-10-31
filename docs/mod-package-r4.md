# R4 — Installateur de packs ZIP et stockage séparé

Cette PR fournit un moteur **Node autonome** d'installation locale : lecture d'annuaire ZIP sans extraction système, chemins contrôlés, rejet des doublons/traversals, limites de décompression, validation manifeste/données/assets, empreintes SHA-256 réelles et écriture temporaire suivie d'un renommage atomique. Les packs sont installés hors dossier du jeu de base et les bindings de nouvelles sauvegardes sont vérifiés par ID/version.

R1 #97, R2 #99 et R3 #100 sont ouverts ; l'intégration dans `dist/`, UI et sauvegardes historiques a donc été volontairement différée. Pas d'import navigateur de ZIP pour l'instant, pas de stockage persistant navigateur, pas de sélection d'univers jouable au démarrage. Les ZIPs avec des entrées répertoires, certains flags et les ZIP64 ne sont pas pris en charge. **N'installer que des packs de confiance** ; le gestionnaire doit être durci et testé avant distribution.

Test : `node tests/mod-package-r4.cjs`. L'intégrateur doit faire converger R1/R2/R3/R4 et confirmer les tests sur la tête exacte avant fusion.

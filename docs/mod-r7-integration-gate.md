# R7 — Corrections nécessaires avant intégration des mods

## Résultat
Branche R7 dérivée de la PR #101, sans modification de `main`. Corrige le ZIP du module R4 existant : contrôle CRC32 **des octets décompressés**, rejet des modifications, listing des dossiers réellement installés portant un suffixe versionné, vérification de la syntaxe ID/version avant d'accéder aux chemins des sauvegardes. Corrige le générateur de ZIP dans les tests R4 pour qu'il produise un CRC conforme et ajoute des tests de corruption et de traversal.

## Ordre de réception
- PR #97 : base fictive et schéma R1.
- PR #99 : manifeste et préparation R2, sans conserver un second registre actif.
- PR #100 : navigateur R3, validation de binaires et UI de consultation.
- PR #101 **puis R7** : installation ZIP et stockage local corrigés.
- PR #102 puis #103 : contrat de monde actif R5/R6.
- L'intégrateur crée **une seule** interface du jeu, et raccorde le monde actif au démarrage de *nouvelles* carrières. Les sauvegardes anciennes restent sans `modBinding`.

## Limites à régler avant mise en service
Les API `records` / `files` / dossiers ZIP ne sont pas encore normalisées entre R2/R3/R4/R5. Les tests unitaires de PR ne prouvent pas la compatibilité bout en bout. Le parseur ZIP R4 ne prend pas en charge certains ZIP ordinaires (entrées répertoire et ZIP64), ni l'import depuis le navigateur ; il ne doit pas encore être exposé au public. Aucun mod réel distribué.

Tests : `node tests/mod-package-r4.cjs`, `node tests/mod-r7-zip-integrity.cjs` et CI complète. Ne fusionner qu'avec verdict positif et contrôle push post-fusion.

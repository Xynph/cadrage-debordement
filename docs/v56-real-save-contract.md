# V56 — Inventaire du contrat de sauvegarde réel

Les tests lisent le **vrai** fichier `dist/game.js` (sans l'exécuter dans un navigateur, sans écrire de sauvegarde) et vérifient ses invariants sources : clé `bdt-v1`, lecture des versions **1 et 2**, création de la version **2**, écriture `JSON.stringify(S)`, erreurs de lecture/écriture visibles, données multi-clubs et progression de saison.

Ils complètent les **7 contrats synthétiques V55** (transactions, effectifs, entraîneurs, investissements, reprise JSON). Deux copies fictives v1/v2 sont utilisées pour tester l'absence de mutation ; **aucun fichier de sauvegarde réel d'un utilisateur n'est ouvert**, aucun test du DOM ou de l'interface n'est annoncé. Les assertions sont de type inspection statique et peuvent nécessiter adaptation si la structure du code évolue ; elles ne remplacent pas un véritable test fonctionnel de migration.

### Point important

Les fixtures V55 sont **une spécification cible**, pas une preuve que le vrai moteur réalise déjà ces transferts. Avant intégration : construire des données de test issues de véritables exports anonymisés, tester la lecture sur navigateur et hors ligne, puis valider le round-trip sans perte de joueurs, clubs, contrats et finances. Ne pas écrire ni migrer silencieusement les sauvegardes existantes.

La PR reste isolée ; l'intégrateur conserve la propriété des fichiers `dist/` et de l'interface.

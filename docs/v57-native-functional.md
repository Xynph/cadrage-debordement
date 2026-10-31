# V57 — Regressions natives en lecture seule

Suite indépendante fondée sur le `main` intégrant V46–V51. La CI exécute 12 assertions de structure sur le **vrai code** `dist/saves.js`, `dist/world-career.js` et `dist/game.js`, puis trois suites natives déjà présentes.

Contrôles : import/export et validation de carrière, protection des erreurs, événements match, finances, devis et paiements d'infrastructures, décisions de recrutement distinctes des signatures, réputation, événements d'entraîneur et avancement des saisons. Le rapport JSON est archivé.

**Portée limitée** : contrôle statique des fonctions, et tests fonctionnels uniquement dans les suites natives existantes ; aucune ancienne sauvegarde utilisateur, aucun DOM/browser ou version Windows n'est exécuté ici. Une décision IA ne prouve pas une signature de joueur.

Pas de modifications `dist/`, sauvegardes ou fichiers de l'intégrateur. Pas de fusion.

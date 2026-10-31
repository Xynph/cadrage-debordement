# UI-02C — Raccordement jouable des fiches joueurs et de l'effectif

**Base** : `e706d6ade5406b7f7c8e9e9c4cdaeaa9033c4807`, fusion UI-01 #82 avec CI post-fusion verte. Livrable producteur : **aucune fusion dans main**.

## Fonctionnalités branchées

`dist/index.html` charge les projections de données UI-02A (PR #81), les composants UI-02B (PR #83), ainsi que le contrôleur de navigation `dist/ui02-player-controller.js`, avant `ui-preferences.js` et `game.js`. La CSS UI-01 `ui01-integration.css` reste inchangée ; les nouveaux styles sont bornés à l'interface UI-02.

Dans `dist/manager-squad.js`, seuls les onglets `squadTab=table` et `squadTab=profile` sont dirigés vers les vues UI-02. Les trois autres onglets effectif (feuille à 23, couverture, planification), la gestion de l'entraînement, toutes les routes historiques et le cockpit de match V40 restent inchangés. Les anciens tests/harness, sans chargement UI-02, gardent l'ancien tableau.

La fiche joueur prend la totalité de l'espace central avec les quatre onglets Profil, Attributs, Contrat, Progression. Les valeurs utilisent uniquement `roleNote`, `potentialAtRole`, `skill`, `physicalLoadValue`, `ATTR` et les données existantes de la carrière. Le tableau configurable propose les quatre préréglages, colonnes sélectionnables, recherche, filtre des quinze postes, tri et comparaison de deux joueurs. Les données de scouting inconnues ne sont pas ajoutées. Le volet « Gestion des charges » permet toujours de sélectionner le plan individuel par `setPhysicalTraining`. Le bouton de gestion détaillée ouvre la fiche existante `inspectCareerPlayer`.

## Sauvegardes, sécurité et accessibilité

Les modèles projettent les joueurs à partir de copies JSON pour éviter les écritures implicites d'attributs ou de potentiel dans l'état original. La navigation, les filtres, les onglets et les comparaisons ne sauvegardent ni ne modifient `S` ; les colonnes choisies restent exclusivement dans `localStorage`, clé indépendante `cd-ui02-columns-v1` (jamais dans `bdt-v1`). Si le stockage est interdit, un avertissement visible l'indique et les choix restent actifs durant la session. Le format de sauvegarde V2 ne change pas.

Les identifiants et noms de joueurs sont échappés en HTML. Les contrôles sont reliés par délégation sur `#app`, avec focus rétabli dans la recherche, navigation clavier flèches/Début/Fin dans les onglets, et bouton retour à l'effectif. Les modes Système/Tribune/Analyste, la bande de session UI-01 et `ui01-integration.css` sont préservés.

## Couverture de tests

Le test `tests/ui02-live-integration.cjs` utilise le véritable harness pour charger UI02, vérifier les données du jeu, le rendu de fiche, les filtres, les colonnes, les 23 sélectionnés, le cockpit V40, l'absence de mutation de carrière et la compatibilité avec la sauvegarde. Les tests dédiés #81 et #83 sont repris sans modification.

Un nouveau workflow isolé `.github/workflows/ui02-browser.yml` lance `tests/ui02-live-browser.py` sous Playwright Chromium Linux pour la vraie version de `dist/index.html` : 1440, 1024, 768, 390 et 320 px, deux thèmes, clics réels, capture d'écran, clavier, colonnes persistées, comparaison, entraînement, sauvegarde et V40. Les tests préexistants UI-01 et carrière ne sont pas retirés.

**Limites** : pas de certification Windows native, ni de test sur appareil tactile physique ; les anciens contrôles de contrat et développement restent accessibles via la fiche historique au lieu d'être dupliqués.

## Passation

La PR d'UI-02C importe les modules des PR #81/#83 et ajoute le vrai raccordement. L'intégrateur unique doit éviter les doubles fusions de #81 et #83 si UI-02C est retenue, puis comparer le dernier main, exécuter les validations sur le SHA exact et contrôler la CI `push` après fusion. Aucun changement de coefficients du rugby ni de sauvegardes.

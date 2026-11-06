# Collecteur RugbyData

Prototype isolé dans `tools/rugby-mass`, sans modification de la BDD ni du moteur.

Sources : TOP 14 `https://www.rugbydata.fr/statistics/competition/1`, PRO D2 `https://rugbydata.fr/statistics/competition/4`.

Installation dans un environnement séparé : `npm install --no-save playwright` puis `npx playwright install chromium`.

Exécution : `node tools/rugby-mass/collector.mjs --url https://www.rugbydata.fr/statistics/competition/1 --season 2025-2026 --out ./rugby-raw` ; répéter pour la compétition 4.

Le collecteur sélectionne une saison explicite, ouvre les statistiques individuelles, étend les classements et conserve les réponses JSON ainsi que les tableaux HTML. Il échoue sans créer d'export si la sélection de saison est introuvable. **Limite : un sélecteur personnalisé non HTML nécessite un adaptateur après essai réel.** Aucun endpoint interne du site n'est supposé.

Après inspection des données brutes, produire un tableau JSON normalisé de `{name, club, league, season, matches, minutes, tries, points, sourceUrl, sourceId}`. Les inconnues restent null. Lancer `node tools/rugby-mass/reconcile.mjs MASTER.json NORMALIZED.json REPORT.json`. Le rapport fournit les nouveaux profils, les données à vérifier et les rejets. Le rapprochement exige nom unique, saison, club et compétition compatibles et ne modifie pas le master. Les transferts exigent revue manuelle.

**Non encore réalisé :** essai Playwright sur le site réel, adaptateur des réponses JSON vers le format normalisé, pagination complète et extraction de 100+ joueurs. Ces étapes nécessitent une session réseau et une inspection de la structure réellement renvoyée. Aucun chiffre de joueurs collectés ne doit être revendiqué avant validation des rapports.

Garder les réponses brutes hors dépôt, sans cookies/tokens. Aucun service de collecte payant utilisé ; aucune modification des PR DATA, des notes, des sauvegardes ni du moteur.
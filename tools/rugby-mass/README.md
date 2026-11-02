# Collecteur RugbyData

Prototype isolé dans `tools/rugby-mass`, sans modification de la BDD ni du moteur.

Sources : TOP 14 `https://www.rugbydata.fr/statistics/competition/1`, PRO D2 `https://rugbydata.fr/statistics/competition/4`.

Installation dans un environnement séparé : `npm install --no-save playwright` puis `npx playwright install chromium`.

Exécution : `node tools/rugby-mass/collector.mjs --url https://www.rugbydata.fr/statistics/competition/1 --season 2025-2026 --out ./rugby-raw` ; répéter pour la compétition 4.

Le collecteur sélectionne une saison explicite, ouvre les statistiques individuelles, étend les classements et conserve les réponses JSON ainsi que les tableaux HTML. Il échoue sans créer d'export si la sélection de saison est introuvable. **Limite : un sélecteur personnalisé non HTML nécessite un adaptateur après essai réel.** Aucun endpoint interne du site n'est supposé.

Après inspection des données brutes, produire un tableau JSON normalisé de `{name, club, league, season, matches, minutes, tries, points, sourceUrl, sourceId}`. Les inconnues restent null. Lancer `node tools/rugby-mass/reconcile.mjs MASTER.json NORMALIZED.json REPORT.json`. Le rapport fournit les nouveaux profils, les données à vérifier et les rejets. Le rapprochement exige nom unique, saison, club et compétition compatibles et ne modifie pas le master. Les transferts exigent revue manuelle.

**Non encore réalisé :** essai Playwright sur le site réel, adaptateur des réponses JSON vers le format normalisé, pagination complète et extraction de 100+ joueurs. Ces étapes nécessitent une session réseau et une inspection de la structure réellement renvoyée. Aucun chiffre de joueurs collectés ne doit être revendiqué avant validation des rapports.

Garder les réponses brutes hors dépôt, sans cookies/tokens. Aucun service de collecte payant utilisé ; aucune modification des PR DATA, des notes, des sauvegardes ni du moteur.
## V3 — chaîne locale sans données inventées

La PR V3 ajoute `pagination.mjs` (jusqu'à 100 vagues d'extension « Voir plus », empreintes SHA256 de la page, `*-checkpoint.json`), `adapter.mjs` (normalisation **conservatrice** des tableaux JSON identifiés), `normalize.mjs` (relecture hors ligne de plusieurs captures), et 13 tests Node. En l'absence de bouton « Voir plus », la pagination signale une fin possible ; un blocage ou la limite de tours indique explicitement `complete:false`. Le checkpoint conserve la **trace** d'une tentative, mais ne rétablit pas encore la session Playwright interrompue : une nouvelle exécution recommence la navigation. Les données capturées restent locales. Le collecteur ne contourne ni authentification ni limite d'accès.

Commandes, une fois Playwright installé dans un environnement réseau autorisé :

```sh
node --test tools/rugby-mass/*.test.mjs
node tools/rugby-mass/collector.mjs --url https://www.rugbydata.fr/statistics/competition/1 --season 2025-2026 --out ./rugby-raw
node tools/rugby-mass/collector.mjs --url https://rugbydata.fr/statistics/competition/4 --season 2025-2026 --out ./rugby-raw
node tools/rugby-mass/normalize.mjs ./normalized.json ./rugby-raw/rugbydata-1-2025-2026.json ./rugby-raw/rugbydata-4-2025-2026.json
node tools/rugby-mass/reconcile.mjs ./master.json ./normalized.json ./reconciliation-report.json
```

**Important :** les noms de champs dans `adapter.mjs` sont des hypothèses à valider sur un échantillon réel, non des affirmations sur les réponses de RugbyData. Seuls sont acceptés des objets JSON contenant un nom, un club, une saison cohérente et au moins une statistique numérique entière non négative. Toute information manquante reste `null`. La page publique est fortement dynamique et n'a pas été inspectée dans un Chromium connecté au cours de la V3 ; le sélecteur réel de saison, le format des réponses et la possibilité d'export complet sont non certifiés. Si les données sont dans le DOM mais non dans des tableaux JSON reconnus, la normalisation sera vide et il faudra ajouter un adaptateur spécifique **après** examen des vrais éléments. Aucun joueur supplémentaire n'est revendiqué. Confirmer également les droits de réutilisation de la source avant redistribution.

Le rapprochement `reconcile.mjs` propose des changements et rejette les noms/club/ligue ambigus ; il ne modifie jamais le fichier central. Toutes les valeurs sorties dans les tests sont **synthétiques**, et ne représentent aucun joueur réel.

# UI-05 — Préparation collective jouable

**Objet :** moderniser un écran **déjà relié au jeu**, plutôt que créer un module supplémentaire en attente de raccordement. Le chantier producteur est issu de `main` `e706d6ade5406b7f7c8e9e9c4cdaeaa9033c4807` : UI-02C PR #84 n'est pas encore fusionnée, et l'intégrateur a réservé `dist/game.js` et `dist/career-integration.js` pour les correctifs de sauvegarde/finances. Le présent lot ne touche à aucun de ces chemins.

## Interface jouable
`dist/game.js` appelle déjà `collectivePreparationCard()` dans `tactics()`. La nouvelle présentation **UI-05** remplace uniquement le corps de cette fonction dans `dist/match-preparation.js`, via une section HTML et des styles CSS bornés au panneau. Aucune modification du chargeur `dist/index.html`, du moteur `dist/rugby.js`, des lois ou du format de sauvegarde.

La vue présente les quatre choix natifs `COLLECTIVE_FOCI`, le choix actuel, la recommandation `collectiveAdvice()`, la charge moyenne du XV actuellement retenu, le nombre de spécialistes éligibles selon `collectiveSpecialist` et leur charge actuelle. Les montants affichés proviennent **exclusivement** des constantes V28 `COLLECTIVE_EFFECTS` et du surcoût natif **+4 points de charge par joueur concerné**, calculé par `applyCollectiveTrainingCost`. Aucune nouvelle efficacité ou prévision de match n'est calculée ; le rendu précise explicitement que la sélection, la fatigue et le groupe peuvent encore changer avant le coup d'envoi.

Le bouton de chaque option conserve **exactement** le handler `setCollectiveFocus(focus)`, qui vérifie les contraintes : match en cours, séance déjà effectuée, saison terminée et validation du type de préparation. Choisir une option ne réalise aucun entraînement et n'ajoute pas automatiquement de bonus. Les verrouillages des boutons restent visibles, tandis que l'état de préparation réellement appliqué au coup d'envoi reste figé dans `S.live.collectivePreparation`.

## Accessibilité et thèmes
Le rendu propose un groupe de quatre boutons à `aria-pressed`, un résumé lisible, un focus clavier apparent, les textes alternatifs pour chiffres et indicateurs, et un agencement réactif 830/580 px. Les styles ne sont ni globaux ni ajoutés à `dist/style.css` ; ils restent bornés sous `.ui05-collective` et respectent les variables des thèmes UI-01 Système/Tribune/Analyste. Les paramètres visuels restent complètement séparés des sauvegardes.

## Validation
- `tests/ui05-live-collective.cjs` : vrai harness, `tactics()` jouable, quatre boutons uniques et natifs, conseil/charges exactes, non-mutation à la lecture, aucun tirage aléatoire supplémentaire, sauvegarde/export valides, clic de préparation réel, verrouillage après entraînement/en match, bonus et charge V28 inchangés.
- `tests/ui05-live-browser.py` : serveur HTTP local et vrai `dist/index.html` dans Chromium/Linux, interface Tactiques, clic réel et persistance, 1440/1024/768/390/320 px, thèmes Analyste/Tribune, contrôles session UI-01, verrouillages, match et export, erreurs JS, captures.
- `.github/workflows/ui05-live-browser.yml` : workflow PR dédié, distinct des workflows CI existants.
- En plus : tests JavaScript officiels, V28, UI-01 et carrières longues sur le **SHA de la PR**. Seule la CI finale sur la tête exacte fait foi.

**Limites :** valeurs et bonus du moteur fictifs et non étalonnés scientifiquement ; la charge affichée est celle du XV sélectionné au moment de la consultation, pas une prédiction d'effectif. Tests navigateur uniquement sous Chromium/Linux, pas de validation Windows ou appareils physiques. Les résultats antérieurs du stress économique #85 ne sont pas résolus par ce lot.

**Gouvernance :** l'intégrateur demeure le seul compte habilité à fusionner puis à confirmer la CI post-fusion sur `main`. Ne pas fusionner la PR #75. #84/#86/#87 et les correctifs de l'intégrateur restent entièrement hors périmètre.

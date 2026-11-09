# Bilans individuels des jeunes — 9 novembre 2026

## Conception
Le suivi existant conserve déjà une référence, six observations et trois plans. Ce lot ajoute un bilan consultatif dérivé de ces faits, un objectif chiffré et une recommandation priorisée (récupération, centre, premier contrat, minutes, prêt à examiner). Aucun nouveau champ sauvegardé, aucune croissance ni dépense ajoutée. Les écarts restent ceux de la référence initiale, même après réorientation : ils ne prouvent pas l'effet causal du plan actuel.

Les premières semaines ne permettent pas d'affirmer un manque de temps de jeu. Une référence d'un ancien club ne sert pas à conseiller le nouveau. Un prêt n'est jamais promis : son éligibilité et son acceptation restent à vérifier dans le parcours existant. Les profils annuels n'ont pas d'objectif spécialiste artificiel.

## Plan
1. Ajouter des tests rouges des bilans, des limites temporelles et des conseils.
2. Ajouter `review` à chaque projection de jeune, sans modifier les données de carrière.
3. Afficher le bilan, les faits et les liens vers Centre/Effectif dans le dialogue déjà raccordé ; filtre des dossiers à revoir et préparation locale d'une réorientation.
4. Exécuter les tests nouveaux et les tests existants de progression/sauvegarde et parser Godot.

## Validation
- Node22 : `node --test tests/youth-development-review.cjs tests/youth-development-observation.cjs tests/youth-development-plan.cjs` — **27 tests réussis**. Les nouveaux scénarios ont été observés rouges avant implémentation, puis verts.
- Godot4.7.2 Linux : import/parsing sans erreur après staging des ressources. `tests/godot-youth-development-review.cjs` — **55 contrôles réussis**, parcours réel depuis création de carrière, activation, préparation locale sans mutation, confirmation et navigation Centre.
- Projection immuable et reprise JSON identique vérifiées. Aucun nouveau champ sauvegardé ni commande native.
- La recette historique `godot-youth-scout-ui.cjs` est lancée séparément ; sa conclusion sera communiquée à l’intégrateur. Aucune recette Windows revendiquée.
- `git diff --check` réussi. La CI globale et la publication restent à l’intégrateur.

## Limites assumées
Les repères de +1 point, 240 nouvelles minutes et l’alerte consultative sous80minutes après quatre semaines sont des aides de simulation, sans récompense. Les minutes comparées sont celles de la référence initiale ; ce lot ne fabrique pas un historique hebdomadaire manquant. Un bilan ne garantit ni progression, ni contrat, ni prêt. Les bilans d’un autre club et les compteurs de minutes incohérents ne déclenchent pas de faux manque de temps de jeu.

## Raccordement
Aucun : le domaine `youthDevelopment` et l’entrée `youth_development_view.gd` sont déjà raccordés. Ajouter les deux nouveaux fichiers de tests aux sélections CI appropriées si celles-ci sont explicites.

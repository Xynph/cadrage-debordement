# Suites liées à Godot rejouées sous Windows — 11 novembre 2026

Machine : PC de Léo, Windows, Godot 4.7.2 (éditeur console du SDK local), pilote `opengl3`, NVIDIA GeForce RTX 4080 SUPER, Node du SDK local. Trois suites en parallèle, délais de la CI (180 s sauf exceptions). Projet stagé par `scripts/build-godot-prototype.py --stage-only`, puis importé. Ce n'est pas l'exécutable exporté.

Résultats bruts : `windows/fe79c365.tsv`, `windows/main-96f53704.tsv`, `windows/match-554.tsv` (résultat, suite, secondes, code de sortie).

## Bilan

| Commit | Réussies | Échecs | Délai dépassé |
| --- | --- | --- | --- |
| `fe79c365` | 56 | 38 | 12 |
| `96f53704` (`main` livré) | 57 | 37 | 12 |

Seule différence entre les deux commits : `godot-pack-ui` passe sur `96f53704`.

## Ce que ce rejeu corrige dans mon classement Linux

J'avais classé 19 suites « hors délai sur ma machine », en supposant que le rendu logiciel était trop lent. Sur une carte graphique réelle :

- 1 seule passe : `godot-salary-preference-live`.
- 11 dépassent encore 180 s : elles se bloquent réellement.
- 7 échouent sur une assertion ou une erreur de script.

Le classement « machine trop lente » était donc faux pour 18 suites sur 19.

Trois suites échouent sous Windows sans figurer dans mes 49 suites non réussies sous Linux (`3b42dbf2`) : `godot-contextual` (délai dépassé), `godot-media-packs`, `godot-preferences`. Deux lectures possibles, non départagées : propre à Windows, ou régression entre `3b42dbf2` et `fe79c365`.

`godot-engine` échoue aussi sous Windows : ce n'était pas propre à Linux.

## Suites non réussies sur `96f53704` sous Windows

| Suite | Windows | Classe Linux (`3b42dbf2`) |
| --- | --- | --- |
| `deepen-analytics-real-ui` | échec | DELAI_MACHINE |
| `deepen-market-ui` | échec | DELAI_MACHINE |
| `deepen-match` | délai dépassé | DELAI_MACHINE |
| `deepen-staff-hire-ui` | délai dépassé | DELAI_MACHINE |
| `deepen-staff-real-ui` | délai dépassé | DELAI_MACHINE |
| `deepen-youth-draft` | échec | ASSERTION |
| `deepen-youth-ui` | échec | ASSERTION |
| `godot-academy-portraits` | échec | ASSERTION |
| `godot-art-direction` | délai dépassé | DELAI_MACHINE |
| `godot-art-direction07` | échec | AIDE_NON_INSTALLEE |
| `godot-career-final-fixes` | échec | ERREUR_SCRIPT |
| `godot-carnet-ui` | échec | ERREUR_SCRIPT |
| `godot-club-memory` | échec | ASSERTION |
| `godot-competition-editor` | échec | AIDE_NON_INSTALLEE |
| `godot-contextual` | délai dépassé | réussie |
| `godot-contract-negotiation` | délai dépassé | DELAI_MACHINE |
| `godot-decision-feedback` | échec | DELAI_MACHINE |
| `godot-engine` | échec | PLATEFORME_LINUX |
| `godot-epcr-preparation` | échec | AIDE_NON_INSTALLEE |
| `godot-fatigue-overview` | échec | ASSERTION |
| `godot-gestion-carnet` | délai dépassé | DELAI_MACHINE |
| `godot-guide` | échec | DELAI_MACHINE |
| `godot-guide-integration` | échec | ASSERTION |
| `godot-guide-layout` | échec | AIDE_NON_INSTALLEE |
| `godot-immersion-copy` | échec | ERREUR_SCRIPT |
| `godot-immersive-reception` | échec | AIDE_NON_INSTALLEE |
| `godot-immersive08` | délai dépassé | DELAI_MACHINE |
| `godot-interface-layout` | échec | AIDE_NON_INSTALLEE |
| `godot-lineup-layout` | échec | AIDE_NON_INSTALLEE |
| `godot-match-action-review` | délai dépassé | DELAI_MACHINE |
| `godot-media-packs` | échec | réussie |
| `godot-native06-integration` | échec | AIDE_NON_INSTALLEE |
| `godot-office-ui` | échec | ASSERTION |
| `godot-playbook-watch-ui` | échec | ERREUR_SCRIPT |
| `godot-portrait-continuity` | échec | ERREUR_SCRIPT |
| `godot-preferences` | échec | réussie |
| `godot-readability06` | échec | AIDE_NON_INSTALLEE |
| `godot-reception-decisions` | échec | ASSERTION |
| `godot-recruitment-comparison` | échec | DELAI_MACHINE |
| `godot-regen-portraits` | échec | ASSERTION |
| `godot-review-regressions` | échec | ASSERTION |
| `godot-squad-column-sort` | échec | ASSERTION |
| `godot-staff-decisions` | délai dépassé | DELAI_MACHINE |
| `godot-three-rooms` | échec | DELAI_MACHINE |
| `godot-youth-scout-ui` | échec | ASSERTION |
| `native-academy-ui` | délai dépassé | DELAI_MACHINE |
| `native-club-support-ui` | échec | DELAI_MACHINE |
| `native-press-ui` | échec | ASSERTION |
| `native-relationships-ui` | délai dépassé | DELAI_MACHINE |

## Branche du match (#554, avant fusion de `main`)

Onze suites `godot-match-*`, chacune sans puis avec `CD_MATCH_GESTES=1` : 20 réussites sur 22. `godot-match-action-review` dépasse 180 s dans les deux cas, comme sur `fe79c365` et `96f53704` : antérieur à la branche.

Séquence de gestes rejouée dans la vraie vue de match : 1,5 à 2,3 ms de rendu par image (1280×720 à 2560×1440), soit plus de 400 images par seconde. Le rendu n'est pas un frein sur cette machine.

## Limites

- Un seul passage par commit ; pas de rejeu des échecs isolément.
- Trois suites en parallèle : un blocage dû à la concurrence n'est pas exclu pour les délais dépassés.
- Les journaux détaillés restent sur le PC (`E:\Cadrage-Debordement\worktrees\claude-recette-20261111\resultats`).

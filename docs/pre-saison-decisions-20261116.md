# Décisions de la pré-saison (16/11/2026)

Décision de Léo (16/11) : la pré-saison (reprise mi-juillet → 1re journée, ~55 jours) ne se
traverse plus sans rien décider. Elle réutilise la reprise choisie
([reprise-choisie-20261113.md](reprise-choisie-20261113.md)) : mêmes amicaux, mêmes jeunes
convoqués, même barème ; deux décisions s'y ajoutent, « Continuer » s'arrête quand elles sont dues
(référence Football Manager).

| Décision | Jour dû | Options | Défaut (délégation) |
| --- | --- | --- | --- |
| Programme des matchs amicaux | jour de la reprise du club | rodage à domicile · équilibré · opposition relevée | équilibré |
| Orientation du stage de préparation | reprise + 7 jours (au plus tard la veille de la 1re rencontre) | foncier · cohésion · technico-tactique · équilibré | équilibré |

Le troisième point envisagé (dernier point recrutement avant la 1re journée) n'est pas ajouté :
les besoins par poste sont déjà dans Recrutement et un arrêt sans décision contredirait la règle
« Continuer s'arrête quand une décision est attendue ».

## Règles

- Décisions du club du manager seulement, saison du plan de reprise. Départ « Veille de la
  1re journée » : préparation gérée par le staff, aucune décision.
- Modifiables jusqu'au jour dû ; en intersaison (saison terminée), pour la saison suivante.
- « Continuer » : arrêt obligatoire `decision` le jour dû ; tant qu'elle attend, il refuse de
  repartir (comme un rendez-vous) et l'interface ouvre « La reprise ».
- Toute autre avance qui dépasse le jour dû (« Jour suivant », « Aller à l'ouverture du
  calendrier », fin de semaine) la confie à Gabi : choix prudent, annoncé en Réception.
  « Confier à Gabi » fait de même tout de suite.
- Commande `reprise_decide` `{decision: 'amicaux'|'stage', option: <id>|'staff'}`.
- Sauvegarde : `S.reprise.program` et `S.reprise.camp` (`null` ou `{id, staff}`), validation
  stricte ; les sauvegardes antérieures (9 clés) restent lisibles.

## Barème (écarts ajoutés à celui de la date de reprise)

| Option | Condition 4 premiers matchs | Risque blessure | Charge | Automatismes | Moral | Cohésion | Jeunes (min.) | Argent |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Rodage à domicile | −1 | −0,2 % | — | −1 % | +2 | — | ×1,35 | +0,5 recette d'amical par match |
| Équilibré | — | — | — | — | — | — | ×1 | 0 |
| Opposition relevée | +2 | +0,3 % | — | +3 % | −1 | — | ×0,6 | −0,25 recette par match (déplacements) |
| Stage foncier | +4 | −0,3 % | +6 | −2 % | −1 | — | — | — |
| Stage de cohésion | −1 | — | — | +2 % | +4 | +6 | — | — |
| Stage technico-tactique | −2 | +0,2 % | — | +5 % | — | +2 | — | — |

Recette d'un amical à domicile (ordre de grandeur, par championnat) : Élite et Premiership
60 000 €, URC 45 000 €, Super Rugby 40 000 €, League One D1 35 000 €, Accession 25 000 €,
Championship 20 000 €, D2 japonaise 15 000 €, Nationale 8 000 €. Écriture au grand livre à la
fin de la préparation (« Recettes des matchs amicaux » ou « Frais de déplacement… »).

Bornes : retard de condition 0 à 12, risque 0 à 2 %, charge 0 à 25. Minutes d'un jeune par
amical : 10 à 80. Aucun tirage `Math.random`.

Conseil de Gabi : retard de condition ≥ 6 → opposition relevée et stage foncier ; quatre jeunes
convoqués ou plus (ou six internationaux absents, ou trésorerie négative) → rodage ;
automatismes ≤ −5 % → cohésion ; reprise tôt → technico-tactique.

## Mesure (club 0, graine 27, reprise 27/07, `tests/world-reprise-decisions.cjs`)

| Préparation | Charge | Retard de condition | Risque | Automatismes | Moral | Recettes |
| --- | --- | --- | --- | --- | --- | --- |
| Rodage + stage foncier (manager) | 6 | 0 | 0 % | −16 % | +3 | 60 000 € |
| Équilibré + équilibré (Gabi) | 0 | 3 | 0,4 % | −13 % | +2 | 0 € |

Les jeunes convoqués jouent ~35 % de minutes en plus en rodage (8 jeunes, 2 amicaux).

## Correctif lié : effets en calendrier journalier

En calendrier journalier (le jeu), la semaine se clôt par `CDWorldCareer.advanceDay` → `finishWeek`,
sans passer par `finishRound` : les effets de début de saison de la reprise (condition, charge,
moral, jeunes, risque) n'étaient jamais appliqués au club du manager. `CDReprise.sync`, appelé
après chaque commande, les applique désormais au changement de semaine constaté.

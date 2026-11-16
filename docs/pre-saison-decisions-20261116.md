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

Le dernier point recrutement n'est pas une décision : c'est un élément « À noter » (ci-dessous),
qui renvoie à Recrutement.

## Éléments « À noter » et flux de Continuer (façon FM, 16/11/2026)

Consigne de Léo : « Continuer » avance jusqu'au prochain jour qui contient des éléments pour le
manager, s'arrête et les montre **tous** en Réception (plusieurs le même jour, c'est normal).

- **Doit répondre** (arrêt `decision`, obligatoire) : le bouton principal devient « DÉCISION
  ATTENDUE → » et ouvre « La reprise » ; la partie n'avance pas sans réponse, quel que soit le flux.
- **Informatif** (arrêt `a_noter`, facultatif) : un nouvel appui sur Continuer repart sans réponse.
  Courrier existant de la Réception (`news`), un seul envoi par élément (`S.reprise.notes`,
  identifiants `type:date`, 32 au plus, remis à zéro à chaque saison).

| Élément | Jour | Contenu |
| --- | --- | --- |
| Retour des internationaux | retour de tournée (entre reprise et 1re journée) | joueurs qui rejoignent le groupe |
| Compte rendu de chaque amical | jour de l'amical | score (adversaire choisi selon le programme), minutes des jeunes, infirmerie |
| Bilan du stage | fin du stage (jour dû + 4) | orientation et effets |
| Dernier point recrutement | veille de la 1re journée | 3 postes faibles au plus, renvoi à Recrutement |
| Veille de la 1re journée | veille de la 1re journée | adversaire, condition moyenne, blessés |

Réglage « Flux de Continuer » (Préférences, à côté des messages et blessures ; clé `continue_flow`) :

| Flux | Types qui arrêtent |
| --- | --- |
| Allégé | veille |
| Équilibré (défaut) | amical, stage, recrutement, veille |
| Complet | + retour des internationaux |

Les éléments hors flux arrivent quand même en Réception ; un arrêt cite tous les éléments du jour.
Scores et minutes : hachage de la saison et de l'élément, aucun `Math.random`.

## Arrêts informatifs de toute la saison (décision de Léo, 16/11/2026)

Continuer s'arrête aussi, pendant la saison, sur des moments sans décision, et peut s'arrêter plusieurs fois le
même jour (comme FM). Réglage en données : `native/engine/continuer-arrets.json` (types, libellé, priorité, flux,
seuils, `maxParJour` = 3 arrêts au plus, le dernier regroupe le reste). Arrêt `info` (facultatif) :

| Type | Quand | Flux |
| --- | --- | --- |
| Veille de match | la veille d'une rencontre du club : feuille (23), blessés à remplacer, rang et forme de l'adversaire | allégé, équilibré, complet |
| Rapport médical | un joueur de l'effectif absent au moins 4 semaines | équilibré, complet |
| Bilan du match | le lendemain : score, infirmerie | complet |
| Fin de phase | changement de phase du championnat du club ou de sa coupe d'Europe (rang, suite) | tous |
| Mi-saison | lendemain du match de la moitié du championnat : rang, objectif de la direction | équilibré, complet |
| Marché des transferts | une semaine avant la fenêtre des clubs (semaine 13) | équilibré, complet |
| Rapport de recruteur | mission de recrutement terminée (remplace l'arrêt « message » de ce courrier) | équilibré, complet |

Retour de convocation internationale : déjà couvert par l'arrêt `international` (courrier groupé, #758).
Lecture seule (`SIGNAL_SOURCE`), aucun courrier ni état écrit : la carrière est identique avec ou sans ces arrêts.
Les arrêts suivants du même jour restent en mémoire du moteur (`infoQueue`, worker.cjs) ; chaque appui sur Continuer
montre le suivant sans avancer (`days: 0`, `queued` = restants) ; oubliés dès que la date change. Le joueur coupe un
type en choisissant un flux plus léger (préférence existante « Flux de Continuer ») ; `stops.ignorer: ['info']` les
coupe tous. Prochain arrêt annoncé : veille et mi-saison. Test : `tests/continuer-arrets-saison.cjs` (fenêtre courte en
CI de PR ; saison complète avec `ARRETS_SAISON_COMPLETE=1` dans le créneau régulier `career-resilience.yml`).

## Éléments visuels ajoutés (existants seulement)

Aucune couleur, police ni composant nouveau. Ajouts : libellé « DÉCISION ATTENDUE → » du bouton
principal (même bouton) ; lignes « Décision attendue : … » et « À noter : … » de l'info-bulle de
Continuer ; titre « Jusqu'au prochain élément à noter : … » du panneau de progression existant ;
liste déroulante « Flux : allégé / équilibré / complet » dans la rangée « Continuer » des
Préférences (même `OptionButton` que messages et blessures) ; courrier de Réception existant pour
les cinq éléments ; arrêt « À noter » qui ouvre la Réception (comme la presse).

## CI (16/11/2026)

Sur 532d8a7, « Godot 1/3 » (`godot-continuer`) et « Godot 2/3 » (`godot-presse-rapide`) échouaient :
la décision des amicaux (reprise du 20/07) bloquait « Continuer » et la fenêtre « La reprise »
captait Ctrl+J. `tests/helpers/contextual_flow.gd` confie désormais les décisions dues à Gabi
(`reprise_decide`, option `staff`) et referme la fenêtre ; `godot-continuer` accepte les arrêts
`decision` et `a_noter`.

## Règles

- Décisions du club du manager seulement, saison du plan de reprise. Départ « Veille de la
  1re journée » : préparation gérée par le staff, aucune décision.
- Modifiables jusqu'au jour dû ; en intersaison (saison terminée), pour la saison suivante.
- « Continuer » : arrêt obligatoire `decision` le jour dû ; tant qu'elle attend, il refuse de
  repartir (comme un rendez-vous) et l'interface ouvre « La reprise ».
- Dans l'interface, une décision due remplace « Continuer » par « DÉCISION ATTENDUE → » (ouvre
  « La reprise ») et retire « Jour suivant » : la partie n'avance pas sans réponse.
- Côté moteur, une avance qui dépasse le jour dû sans passer par Continuer (`advance_day`,
  « Aller à l'ouverture du calendrier », fin de semaine) la confie à Gabi : choix prudent, annoncé
  en Réception. « Confier à Gabi » fait de même tout de suite.
- Commande `reprise_decide` `{decision: 'amicaux'|'stage', option: <id>|'staff'}`.
- Sauvegarde : `S.reprise.program`, `S.reprise.camp` (`null` ou `{id, staff}`) et
  `S.reprise.notes`, validation stricte (12 clés) ; les sauvegardes antérieures (9 clés) restent
  lisibles et sont complétées au premier passage.

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

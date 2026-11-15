# Tests robustes au recalibrage du moteur de match (14 novembre 2026)

Problème : à chaque recalibrage du moteur de match (#709 stats réalistes, #710 essais réalistes, #721 pénalités,
#728 avantage du terrain V2), plusieurs tests cassaient parce qu'ils dépendaient du résultat exact d'un match à
graine fixe, et on les réparait en élargissant une borne ou en changeant la graine. Ces réparations ne protégeaient
rien : la borne suivante était simplement choisie pour contenir le tirage du jour.

Cette PR ne change ni le moteur ni ses taux. Elle réécrit les tests pour qu'un recalibrage ordinaire ne les casse plus
et qu'un vrai défaut de règle les casse toujours.

## 1. Recensement (journal git des trois derniers jours sur `tests/` et `tools/animation-replay`)

Réparations « borne élargie » ou « graine changée » trouvées dans le journal : `67b4842d` (bornes des temps forts et des courses),
`8884235c` (bornes des temps forts et de la courbe), `38eea44d` et `7e254138` (tirage du ralenti), `32877a2c` (fixture des gestes, tirages
de `match-penalite-main`, `playbook`, `match-actions`), `52cdac94` et `832b89b2` (fixture des gestes : quinze joueurs par camp),
`2f6bef00` (courbe commune : bornes de `opposition`, `match-rating-curve`), `8fc926ce` (#725 : bornes de `match-rating-curve`,
`opposition`, `tactical-plans`), `939e37c7` (bornes par maillot de `homme-du-match-postes`), `f891af98` (finale de `champion-budget-regression`).

| Suite | Ce qui la rendait fragile | Catégorie | Traitement |
|---|---|---|---|
| `match-highlights` | un seul match (club 3, graine du harnais) pour toutes les règles ; statistique sur 16 matchs aux bornes déplacées quatre fois (50 → 60 %, 35 → 25 %, 8 → 10 %) | (a) règles, (b) statistique | règles sur 3 matchs ; statistique sur 24 matchs, estimateur par rapport et erreur type, bornes d'intention |
| `match-importance` | six matchs à graines 0 à 5, bornes de part des temps forts qui marquent (55 → 65 %) | (a), (b) | 12 matchs, mêmes outils |
| `match-courses` | six matchs fixes, seuils de volume (`ajoutes > 20`, `essaisLongs > 5`) | (a) différentiel | on joue des matchs jusqu'à avoir assez d'essais longs (plafond 30) ; la comparaison avec / sans découpage reste exacte |
| `tactical-plans` | tirage `.6` à choisir entre deux probabilités (fenêtre de ±0,04), marges absolues (`+100` erreurs, `+60` pénalités, `+4` m, `×1,8`), un classement de deux taux voisins (rush) qui ne tenait que par chance | (a), (b), (c) | `teamEdge` lu directement ; échantillons appariés (mêmes tirages d'un plan à l'autre) ; tests de différence à 4 écarts types |
| `opposition` | 800 matchs, bornes `.62 – .985`, surprise à l'extérieur exigée (2 sur 800 mesurées) | (b) | borne basse en erreur type, « pas à coup sûr », une surprise sur la série |
| `match-rating-curve` | bornes de points et d'essais par match refaites à chaque réglage (38-62 puis 4,4-8,8…) | (b) | enveloppe de la réalité (docs/essais-realistes) ; pente et terrain élargis de trois erreurs types de l'ajustement logistique |
| `playbook` | tirages `.79`, `.1`, `.15`, `.2`, `.9, .2, .4, .5, .99` calés sur les seuils du jour | (a), (b), (c) | effets du moteur lus (`setPieceEffects`, `openKickProbability`), échantillons appariés, tirages BAS / HAUT |
| `match-actions` | tirage constant `.43` (à 0,03 du plafond des fautes), séquence `[.5, .99, 0, 0, 0, .5, 0, 0, .5, .5]` | (c) | séquence de décisions (`courseReussie`) |
| `match-penalite-main` | tirages `[0.55, 0.5]`, `[0.55, 0.9, 0.99]`, `0.3`, `0.2` entre des seuils de 0,16 à 0,55 ; facteur `×1,8` | (c), (b) | balayage du tirage de 0 à 1 (l'ordre des issues est la règle) ; tests de différence de proportions |
| `match-structured-facts` | trois clubs | (a) | cinq clubs |
| `godot-match-gestes-scenes` et sa fixture, `godot-match-gestes`, `godot-match-essai`, `godot-match-complet-regression` | recherche d'une graine dont le match contient « pénaltouche, touche conservée en ballon porté, essai » parmi trente clubs, plus des filtres (pas de carton, quinze joueurs) | (c) | scénario construit avec les vraies fonctions du moteur et des décisions forcées |
| `tools/animation-replay/export-fixture` et `fixture.js` | tirage `.64` choisi entre deux seuils (« fenêtre étroite vers .62-.70 ») | (c) | séquence de décisions, essai transformé par tirage BAS |
| `champion-budget-regression` | (déjà corrigé par `f891af98` : la finale ne dépend plus d'un tirage) | (c) | inchangé, vérifié sous recalibrage |
| nouveau : `match-regles` | aucun test ne disait « un essai vaut 5 points » sur beaucoup de matchs | (a) | 36 matchs complets, invariants à chaque pas du moteur |

Hors périmètre, relevés : `homme-du-match-postes` et `hierarchie-penalites-monde` (graine fixe mais bornes larges, plus longs) et
`essais-realistes` (calibration volontaire sur la réalité 2024-25, bornes issues du document correspondant) ne sont pas réécrits ici.

## 2. Les trois façons de tester un moteur à tirages

Outils partagés : `tests/helpers/tirages.cjs` (décisions forcées, balayage, statistiques), `tests/helpers/matchs.cjs` (matchs complets
de graines quelconques), `tests/helpers/recalibrage.cjs` (preuve, voir § 4).

**(a) Une règle du jeu** : toujours vraie, quel que soit le tirage. On la vérifie sur beaucoup de tirages, sans score attendu. Exemple :
`match-regles` vérifie à chaque minute de 36 matchs que les points marqués valent 5 par essai, 2 par transformation, 3 par pénalité,
qu'une transformation suit un essai, que l'effectif reste entre 13 et 15 et que le score ne baisse jamais.

**(b) Une statistique** : une moyenne sur un échantillon, comparée avec la variance mesurée de cet échantillon.
- Entre deux conditions (rush contre glissée, au large contre au près) : test de différence de proportions ou de moyennes, seuil à
  4 écarts types (`T.Z`), jamais une marge absolue qui dépend du volume de jeu.
- Contre une borne : estimateur par rapport (`T.rapport`, erreur type par la méthode delta) ; la borne est une intention de conception
  (« pas que des essais ») élargie de trois erreurs types, pas l'intervalle observé un jour.
- Échantillons appariés : les deux plans comparés reçoivent les mêmes tirages et chaque essai repart de la même photographie de la
  rencontre, ce qui retire presque tout le bruit (la fatigue d'une phase ne contamine plus la suivante : les premiers essais
  de cette PR comptaient sans le savoir une fatigue qui ramenait tous les plans au même avantage).

**(c) Un scénario précis** : on le construit en forçant les décisions, jamais en cherchant une graine.
- `T.BAS` (0) fait réussir toute décision `Math.random() < p`, `T.HAUT` (0,9999999) la fait échouer, pour tout taux compris entre 0 et 1 :
  le moteur borne ses probabilités par `clamp`, donc aucun recalibrage raisonnable ne les franchit.
- `T.courseReussie` donne la séquence « aucune faute, course réussie, finition ou non » ; elle demande au moteur si le tirage du coup de
  pied dégagé est consommé (structure, pas taux).
- Quand un tirage doit tomber « entre deux seuils » (ballon perdu après une pénalité jouée vite), on **balaie** le tirage de 0 à 1 sur la
  même situation et on teste l'**ordre** des issues (essai, puis ballon perdu, puis gain) et leurs faits : les bornes ne sont pas testées.
- Une séquence désynchronisée (le moteur demande un tirage de plus ou de moins) fait échouer le scénario avec la liste des scènes
  obtenues ; c'est un changement de structure du moteur, qu'il faut voir.

Fixtures : la séquence des gestes Godot et le ralenti sont maintenant **produits par un scénario forcé** avec les vraies fonctions du moteur
(`grantSetPiece`, `awardPenalty`, `scoreTry`, `advanceCausalPlay`, `matchScene` + adaptateur). Un recalibrage des taux ne les change
plus. Une modification de la mise en scène elle-même (faits, positions, commentaires, noms) les change, et alors on régénère :
`node tests/godot-match-gestes-scenes.cjs > tests/fixtures/match-gestes-sequence.json` et `node tools/animation-replay/export-fixture.cjs`.

## 3. Durée de la CI

Mesures sur la machine de développement partagée à deux cœurs, sans autre charge (varient d'un tiers selon la charge).

| Suite | Avant | Après |
|---|---|---|
| `match-regles` (nouveau, 36 matchs complets) | | ~12 s |
| `match-highlights` (3 matchs de règles + 24 de statistique) | ~12 s | ~12 s |
| `match-importance` (12 matchs au lieu de 6) | ~6 s | ~8 s |
| `match-courses` | ~6 s | ~7 s |
| `tactical-plans` (échantillons appariés, 6 000 phases de rush) | ~12 s | ~19 s |
| `opposition` | ~25 s | ~26 s |
| `playbook` | ~1 s | ~3 s |
| `match-structured-facts` (5 clubs au lieu de 3) | ~4 s | ~6 s |
| `match-penalite-main` | ~68 s | ~64 s |
| `match-rating-curve` | ~80 s | ~73 s |
| `godot-match-gestes-scenes` (scénario construit au lieu de 30 matchs possibles) | ~1 s | ~1 s |

Poids de planification des shards mis à jour (`ci/suite-weights.json`) ; `match-regles` ajouté aux dépendances de `dist/rugby.js`,
`matchflow.js`, `restarts.js` et `tactical-plans.js` (`ci/select-tests.cjs`, et son attendu dans `tests/ci-selection.cjs`).

## 4. Preuve : recalibrage simulé et défaut injecté

`tests/helpers/recalibrage.cjs` (inactif sans variable d'environnement ; appelé par `tests/harness.cjs` et `tests/monde-harness.cjs`) :

- `CD_RECALIBRAGE='{"ESSAIS.porte":1.1}'` multiplie un taux du moteur (course `ESSAIS.porte`, finition `ESSAIS.finition`, réussite au but
  `ESSAIS.but`, pénalités `PENALITES.jeu / attaque / melee / touche`) dans la machine virtuelle, sans toucher au dépôt ;
- `CD_BUG=essai-sans-points` (ou `transformation-sans-points`) injecte un vrai défaut de règle : l'essai (ou la transformation) ne rapporte plus ses points.

Les mêmes variantes ont été jouées sur `origin/main` (12 suites de la liste du problème, avec le même crochet) et sur cette branche
(les mêmes + `match-regles` + la comparaison de fixture de `godot-match-gestes`, soit 14). Résultat : suites en échec.

| Variante | Avant (`origin/main`) | Après (cette PR) |
|---|---|---|
| course réussie +10 % (`ESSAIS.porte` ×1,1) | `match-highlights` (62 % de temps forts qui marquent, borne 60 %) | aucune |
| course réussie −10 % (×0,9) | `tactical-plans` (tirage `.6` hors de la fenêtre), `animation-replay` (tirage `.64` au-dessus du taux) | aucune |
| finition −10 % (`ESSAIS.finition` ×0,9) | aucune | aucune |
| pénalités +10 % (`PENALITES.jeu` et `attaque` ×1,1) | `opposition` (aucune surprise à l'extérieur : 30 à domicile, 0 dehors) | aucune |
| dur A : course ×1,2, finition ×0,85, but ×0,9, pénalités jeu / attaque / mêlée / touche ×1,3 / 1,3 / 1,2 / 1,3 | `tactical-plans` | aucune |
| dur B : course ×0,85, finition ×1,15, but ×1,1, pénalités ×0,7 / 0,7 / 0,8 / 0,7 | `tactical-plans`, `animation-replay` | aucune |
| **défaut : un essai ne vaut plus 5 points** | 8 sur 12 : `match-highlights` (par ricochet : part de temps forts identiques), `match-courses`, `opposition`, `match-structured-facts`, `match-penalite-main`, `champion-budget-regression`, `match-rating-curve`, `animation-replay` | 9 sur 14 : `match-regles`, `match-courses`, `opposition`, `match-structured-facts`, `match-penalite-main`, `champion-budget-regression`, `match-rating-curve`, `animation-replay`, `godot-match-gestes` (fixture) |
| **défaut : une transformation ne vaut plus 2 points** | 4 sur 12 : `match-courses`, `match-structured-facts`, `match-rating-curve`, `animation-replay` | 6 sur 14 : `match-regles`, `match-courses`, `match-structured-facts`, `match-rating-curve`, `animation-replay`, `godot-match-gestes` |

Lecture :
- Sur les six recalibrages, **7 échecs de suites avant, 0 après** ; sur les deux défauts, la détection ne baisse pas (elle passe de 8 à 9 et de 4 à 6 suites)
  et c'est maintenant `match-regles` qui la porte au premier chef, avec un message qui dit la règle violée (« camp 0 à la 23e minute : +0 points pour 1 essai »).
- Les suites qui ne sont pas listées dans la ligne d'un défaut (temps forts, importance, plans tactiques, carnet de jeu, actions) ne
  vérifient pas l'arithmétique du score : elles ne doivent pas l'attraper, et ne la masquent pas.
- Mesure de variance qui fonde les bornes de `match-highlights` : quatre séries de 24 matchs de graines distinctes ; temps forts qui marquent 51 à 56 %
  (erreur type 2,3 points), grosses actions sans point 29 à 37 % (2,2 points), quarts de match de 20 à 30 %, sur la base comme sous les variantes dures A et B.
  Les bornes (30 à 75 %, 20 à 50 %, 12 à 40 %), élargies de trois erreurs types, sont des intentions de conception, au lieu de l'intervalle d'un tirage.
- Limite de cette preuve : après la grande série, trois retouches ont été faites (6 000 phases au lieu de 3 000 pour le rush de `tactical-plans`, dont le premier
  essai sous dur B donnait 3,99 écarts types pour 4 exigés ; bornes de `match-highlights` et de `match-importance` resserrées sur la mesure ci-dessus ;
  attendu de `ci-selection`). Elles ont été rejouées seules sous les variantes concernées (base, dur A, dur B) et la batterie complète est verte sur la base,
  mais la grande série n'a pas été rejouée en entier.

Rejouer : `CD_RECALIBRAGE='{"ESSAIS.porte":1.1}' node tests/match-highlights.cjs` ; `CD_BUG=essai-sans-points node tests/match-regles.cjs`.

## 5. Ce qui reste fragile (non traité ici)

- `homme-du-match-postes` et `hierarchie-penalites-monde` : graine fixe et bornes larges, des carrières Monde complètes ; à traiter de la même façon avec une marge en erreur type.
- `essais-realistes` est une calibration volontaire sur la réalité 2024-25 : elle doit casser si les essais sortent de l'enveloppe réelle, et ses bornes sont documentées.
- Les suites de ce document utilisent `tests/harness.cjs` (moteur du `dist/` sans carrière Monde, comme avant) ; seules `match-regles` et `match-rating-curve` passent par la carrière Monde.
- Un scénario forcé dépend de l'**ordre** des tirages du moteur (la séquence `courseReussie`, `[HAUT, HAUT]` avant la pénaltouche). Si le moteur ajoute ou retire un tirage de décision,
  le scénario échoue bruyamment (scènes obtenues listées) au lieu de passer par hasard : c'est voulu, mais il faudra ajuster la séquence.

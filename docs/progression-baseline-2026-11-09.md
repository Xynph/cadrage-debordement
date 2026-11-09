# Lecture descriptive des politiques de progression

3 paires complètes, trois graines préannoncées, deux saisons jouées et deux transitions par bras. Différences : attentive moins minimal. Aucun vainqueur ni preuve statistique.

| Capture | Δ trésorerie, médiane [min ; max] | n connu | Δ notes naturelles du XV, médiane | n connu |
| --- | --- | ---: | --- | ---: |
| initial | 0 [0 ; 0] | 3 | 0 | 3 |
| end-S1 | -592740 [-592740 ; -592740] | 3 | 0 | 3 |
| opening-S2 | -592740 [-592740 ; -592740] | 3 | 2.333333333333343 | 3 |
| end-S2 | -3812880 [-4474980 ; -2829080] | 3 | 1.6000000000000085 | 3 |
| opening-S3 | -3812880 [-4474980 ; -2829080] | 3 | 3.4000000000000057 | 3 |

| Graine | Clôture | minimal : division, rang, points | attentive : division, rang, points | Portée |
| --- | --- | --- | --- | --- |
| 827381 | end-S1 | elite 11/14 · 47 pts | elite 11/14 · 47 pts | même division |
| 827381 | end-S2 | elite 9/14 · 55 pts | elite 13/14 · 40 pts | même division |
| 318 | end-S1 | elite 12/14 · 41 pts | elite 12/14 · 41 pts | même division |
| 318 | end-S2 | elite 14/14 · 35 pts | elite 5/14 · 72 pts | même division |
| 52602 | end-S1 | elite 8/14 · 60 pts | elite 8/14 · 60 pts | même division |
| 52602 | end-S2 | elite 9/14 · 53 pts | elite 2/14 · 66 pts | même division |

| Graine | Politique | Cash ouverture S3 | Dette connue | Salaires hebdomadaires | Minimum cash observé | Semaines négatives | Requêtes politique acceptées/refusées | Signatures/contre-offres | Primes réellement signées |
| --- | --- | ---: | ---: | ---: | ---: | ---: | --- | --- | ---: |
| 827381 | minimal | 11045100 | 0 | 128140 | 3648180 | 0 | 63/0 | 0 / 0 | 0 |
| 827381 | attentive | 6570120 | 0 | 175740 | 3055440 | 0 | 75/0 | 12 / 0 | 163000 |
| 318 | minimal | 12526600 | 0 | 130640 | 4236180 | 0 | 69/0 | 0 / 0 | 0 |
| 318 | attentive | 8713720 | 0 | 176140 | 3643440 | 0 | 80/0 | 12 / 0 | 163000 |
| 52602 | minimal | 10755600 | 0 | 133140 | 3953180 | 0 | 65/0 | 0 / 0 | 0 |
| 52602 | attentive | 7926520 | 0 | 175340 | 3360440 | 0 | 76/0 | 12 / 0 | 163000 |

| Graine | Politique | Retenus/cohorte initiale | Entrants | Ratings suivis connus/cohorte | Δ rating médian des retenus | Δ rating médian suivi |
| --- | --- | --- | ---: | --- | ---: | ---: |
| 827381 | minimal | 16/61 | 8 | 16/61 | 0 | 0 |
| 827381 | attentive | 22/61 | 5 | 22/61 | 0 | 0 |
| 318 | minimal | 16/61 | 9 | 16/61 | 0 | 0 |
| 318 | attentive | 22/61 | 5 | 22/61 | 0 | 0 |
| 52602 | minimal | 16/61 | 10 | 16/61 | 0 | 0 |
| 52602 | attentive | 22/61 | 5 | 22/61 | 0 | 0 |

Le cash est un stock, pas un bénéfice. Le JSON sépare financements, flux inconnus, dette et salaires. Les rangs et points sont stratifiés par division et taille de ligue. La note du XV est la moyenne des notes naturelles des quinze titulaires, pas une force optimale ou au poste joué. Les variations individuelles distinguent cohortes initiales, survivants, entrants et inconnus ; les ratings des mêmes IDs connus dans les deux bras sont aussi appariés. Les acceptations API restent distinctes des refus et ne prouvent pas un effet causal. En l’absence de période négative, le redressement financier n’a pas été exercé.

## Lecture des six trajectoires réellement reçues

Les trois graines préannoncées ont chacune terminé leurs deux bras : douze saisons jouées au total sur six trajectoires appariées par trois graines, sur le même club initial et le même moteur. Ces douze saisons ne constituent pas douze répétitions indépendantes de la comparaison. Les douze périodes financières ont un résidu inexpliqué nul ; les reprises publiques et privées attendues ont toutes réussi. Aucun échec ou seed défavorable n’a été écarté de la synthèse.

La politique `attentive` a effectivement signé douze prolongations par graine, pour 163 000 € de primes, sans contre-offre ni refus API sur ces runs. Il s’agit d’une politique de renouvellement sélectif sous réserve budgétaire, comparée à une gestion minimale de la composition et de sa couverture. Ce n’est pas une comparaison exhaustive de tous les leviers d’entraînement, de recrutement ou de redressement.

Au début de S3, les trois bras `attentive` gardent 27 professionnels et 22 des 61 IDs initiaux ; `minimal` garde 24, 25 et 26 professionnels selon la graine, dont 16 des 61 IDs initiaux. La médiane standard du rating de l’effectif courant vaut75 dans les trois bras `attentive`, contre70 dans les trois bras `minimal`. Les moyennes de notes naturelles du XV sont supérieures respectivement de3,20, 3,87 et3,40 points dans les bras `attentive`.

Cela n’établit pas une progression individuelle générale : parmi les joueurs initiaux encore suivis, le changement médian de rating reste0 dans les deux politiques. Les seuls jeunes retenus ont des changements médians de1,5 sous `minimal` (8 IDs suivis sur32 jeunes initiaux), et1, 2 ou1 sous `attentive` (11 sur32). Les39 ou45 joueurs initiaux non retrouvés ne sont pas imputés à zéro ni déclarés retraités. La composition et la survie de l’effectif expliquent une partie essentielle de ce qu’on appelle ici sa qualité.

Le prix financier est visible : la trésorerie de début de S3 est inférieure sous `attentive` dans les trois graines, de4 474 980 €, 3 812 880 € et2 829 080 €. Les dettes observées restent nulles, mais les salaires hebdomadaires sont plus élevés sous `attentive`. Chaque bras reçoit5 M€ de financement annuel au total pendant les deux transitions : ces apports ne sont pas des recettes d’exploitation. Aucune semaine négative n’est rencontrée ; le redressement d’une situation déficitaire n’a donc pas été exercé.

Les résultats sportifs sont divergents, pas unanimement favorables : en S2, la graine827381 donne13e/40 points sous `attentive` contre9e/55 sous `minimal`, avec relégation du bras `attentive` constaté au passage en S3 ; la graine318 donne5e/72 contre14e/35, avec relégation du bras `minimal` ; la graine52602 donne2e/66 contre9e/53. Les rangs de début de S3 ne sont pas comparés entre divisions différentes. La S1 présente les mêmes rangs et points par paire.

La meilleure conservation de joueurs et la qualité plus élevée du XV ne suffisent donc pas à déclarer une stratégie gagnante : elles coexistent avec davantage de dépenses et des issues sportives opposées selon la graine. Les états initiaux et profils sont appariés, mais le protocole ne maintient pas l’égalité des tirages après les décisions ; ce n’est pas un contre-factuel sportif à aléa identique. Les hashes privés différents attestent des profils divergents, sans permettre de déduire à eux seuls un nombre exact de tirages RNG consommés.

Ces douze saisons ne valident pas l’équilibrage à dix saisons, la solvabilité générale, les autres clubs ou les autres modes. Les profils testés ont encore des feuilles de jeu valides aux points de capture. La baisse des volumes professionnels et le grand nombre d’IDs initiaux non suivis restent des observations à approfondir, et non des motifs pour inventer un coefficient de remplacement.


## Portée du point de départ

Ces mesures portent sur main `2623584` et le banc gelé `70e998b5a7b1ad276e28de597b5bad1d67add01d`, avant le renouvellement v2 des joueurs et les carrières du staff. Elles ne valident pas ces fonctionnalités ultérieures. Les six bras se terminent avec cinq observations, trois réouvertures exactes et conservation financière vérifiée. Aucun coefficient économique du jeu n’a été modifié.

La médiane standard est recalculée depuis les joueurs bruts dans la synthèse ; la p50 nearest-rank du runner reste conservée et contrôlée sous un nom distinct. La correction de lecture a été décidée avant agrégation des six résultats, sans changer les trajectoires.

Les empreintes des six reçus et les signatures source figurent dans `progression-baseline-receipts.json`. Pour reproduire, se placer sur le banc gelé indiqué et exécuter les six commandes documentées, puis la synthèse. Les fichiers JSON agrégés privés de cette exécution font 532 618 octets ; leurs données proviennent uniquement de carrières de test synthétiques.

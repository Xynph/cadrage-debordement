# Les remplaçants comptent (lot K3, 26 novembre 2026)

Constat (main au 26/11) : faire entrer un remplaçant à la 50e ne modifiait la suite du match que dans 19 à 31 % des
cas (60e : 15 à 24 %), avec une marge finale à peine déplacée (−0,3 à +0,7 point). Et l'ordinateur pouvait finir un
match avec son demi de mêlée à l'aile alors qu'un trois-quarts attendait sur le banc.

## Ce qui change dans le match

Rencontres créées avec `remplacantsVersion` (un match commencé avant garde ses règles).

- **Fraîcheur** (`FRAICHEUR`, `dist/matchflow.js`) : chaque joueur porte la fatigue **du match seulement** = minutes
  jouées / 25, plafonnée à 1,6 (atteinte vers la 40e). Ni la forme d'avant-match ni l'endurance n'y entrent : elles
  pèsent déjà par la condition dans les compétences. Un premier essai fondé sur la baisse de condition favorisait les
  équipes endurantes (favori +4 points, matchs serrés −3) : abandonné.
- **Entrée** : un entrant apporte un élan (0,6) qui s'éteint en 15 minutes. S'il est nettement moins bon au poste que le
  sortant (note au poste hors condition, au-delà de 3 points), l'élan baisse et il garde un décalage (0,8 par 15
  points) : un remplaçant bien plus faible coûte.
- **Effets**, camp contre camp, sans tirage ajouté (moyenne pondérée par maillot selon la phase) :
  porteur qui passe le plaquage (+0,09 × écart sur l'avantage d'attaque), fautes de main (−0,03 × écart, arrières
  ×1,5), pénalités concédées (×(1 − 0,08 × écart), avants ×1,5, borné 0,7-1,3), pénalité de mêlée (+0,1 × écart, cinq
  de devant ×2, troisième ligne ×1).
- **Remplacement au poste** (`rangPoste`, `dist/opposition.js`) : l'ordinateur ne choisit que parmi le meilleur rang
  présent sur le banc (même poste, puis même ligne : première ligne, deuxième et troisième lignes, charnière,
  trois-quarts) ; un joueur hors de sa ligne n'entre que pour un joueur à bout, faute de mieux. Même ordre pour un
  remplacement sur blessure (`native/engine/incidents-match.cjs`).
- **Incertitude** : aucun texte ni chiffre nouveau à l'écran ; le joueur ne voit jamais le poids d'un changement.

## Mesures (réglage final, commit 84eb662cd, main refusionné jusqu'à #1361)

Remplacement au poste à la 50e ou 60e, club 102, même affiche et même tirage avec ou sans le changement (200 essais,
`temp/moteur-match-realisme/k3/mesure.cjs`) — suite changée, main → branche :

| Changement | 50e | 60e |
| --- | --- | --- |
| Pilier | 15 → 25 % | 12 → 20 % |
| Troisième ligne | 26 → 40 % | 17 → 30 % |
| Demi de mêlée | 21 → 32 % | 15 → 27 % |
| Ailier | 19 → 32 % | 12 → 24 % |

Ordinateur (200 matchs IA contre IA, test) : demi de mêlée mis à l'aile avec un trois-quarts libre 2 → 0 ; sur 150
matchs toutes compétitions, remplacements hors de la ligne alors que la ligne avait un joueur libre 12 → 0.

### Calage IA contre IA (600 matchs × graines 4242 et 7, `k3/calage-k3.cjs`)

| Championnat | Matchs serrés (≤ 7) | Favori gagne | Remontées (mené 11-14 à la 75e) | Points |
| --- | --- | --- | --- | --- |
| Top 14 | 38,5 → 39,3 % | 63,7 → 63,4 % | 16,9 → 20,9 % | 50,3 → 51,0 |
| Premiership | 38,0 → 39,5 % | | 19,7 → 20,9 % | |

Écart d'échantillonnage : ± 2 points (serrés, favori), ± 5 points (remontées, ~110 à 130 matchs concernés). Depuis #1356
(défense regroupée à deux scores), les remontées tardives de main sont sous 20 % en Top 14.

Réglage d'origine de ce lot (jeu 0,18, faute 0,25, élan 0,35 ; suite changée à la 50e 39 à 56 %) : abandonné après la
refusion de main, voir plus bas. Les saisons Monde ci-dessous ont été mesurées avec ce réglage d'origine, avant #1356.

### Saisons Monde (6 graines, réglage d'origine, main du 26/11)

Carrière Monde, club 102, saison régulière, graines 4242, 7, 2026, 11, 99, 31 (`scripts/mesure-essais-monde.cjs`) —
réel (docs/realite-matchs-20261125.md) / main / branche :

| Championnat | Points | Essais | Écart ≤ 7 | Domicile | Favori (niveau ≥ 1) |
| --- | --- | --- | --- | --- | --- |
| Top 14 | 51,0 / 50,8 / 50,6 | 5,2 / 6,14 / 6,12 | 40 / 38,8 / 39,0 % | 76 / 73,1 / 72,4 % | — / 60,8 / 62,3 % |
| Premiership | 54,9 / 56,8 / 57,5 | 7,1 / 7,28 / 7,45 | 36 / 38,0 / 37,0 % | 64 / 63,0 / 64,4 % | — / 67,4 / 71,7 % |
| URC | 49,4 / 50,5 / 51,5 | 6,3 / 6,36 / 6,51 | 41 / 37,6 / 36,7 % | 63 / 64,2 / 63,4 % | — / 73,5 / 73,2 % |
| Super Rugby | 56,9 / 57,3 / 57,1 | 7,8 / 7,51 / 7,43 | 35 / 36,3 / 35,2 % | 63 / 64,8 / 62,5 % | — / 74,8 / 70,3 % |
| Japon D1 | 60,8 / 61,0 / 60,7 | 8,5 / 8,35 / 8,30 | 30 / 34,4 / 29,6 % | 50 / 52,2 / 48,1 % | — / 79,3 / 81,8 % |

Échantillon : 480 à 1 092 matchs par championnat (± 1,5 à 2,2 points).

## Test

`tests/match-remplacants.cjs` (rouge sur main, vert ici) : suite changée et marge sur les remplacements imposés à la
50e (camp sans autre changement : suite changée 18,1 % sur main, **36,7 %** ici, seuil ≥ 35 % — marge étroite ; marge
finale +0,98, main −0,39, bornée à ± 3) ; sens et bornes de chaque effet, remplaçant bien plus faible qui pèse moins ;
ordinateur jamais de demi de mêlée à l'aile ni de non-talonneur au talon quand le banc a le bon joueur (200 matchs).

## Suites existantes adaptées (accords de Léo du 27/11/2026)

- `tests/bonus-fin-de-match.cjs` : la mesure (`scripts/mesure-bonus-fin-de-match.cjs`) fait remplacer le club du joueur
  avec les règles de l'ordinateur (armes égales), minutes jouées recopiées par le miroir. « Viser » : 1,35 essai contre
  0,74 (sans cela 1,06 contre 0,90, rouge).
- `tests/match-consignes-direct.cjs` : 24 → 192 matchs, mêmes graines de départ, seuils et assertions inchangés. 96 matchs
  ne suffisent pas (rouge : relance=dégager 29 % pour 30 %, main compris) ; à 192 : main relance 31 % / touche sûre 34 %,
  branche 34 % / 27 %.
- Essais écartés pour garder ces suites sans les toucher : plafonner l'écart de fraîcheur d'un camp (tanh, 0,1 à 0,2)
  ou ne garder que l'élan d'entrée : un remplacement du joueur ne pesait presque plus rien (13-36 %, niveau de main).

## Réglage du 27/11 après refusion de main (remontées tardives #1356, fautes de main #1353)
Avec l'ancien réglage (jeu 0,18, main 0,06, faute 0,25, mêlée 0,2, élan 0,35), trois mesures existantes tombaient :
consignes en direct (« touche sûre » 17 % pour 25 %, « relance=dégager » 29 % pour 30 %, 24 matchs), poids du niveau en URC
(0,182 pour 0,30) et tirs au but de la Premiership (3,11 pour 3,12). Diagnostic (une part coupée à la fois) : l'effet sur
les pénalités faisait tomber tirs et URC ; la fraîcheur en jeu faisait tomber les consignes. Retenu : jeu 0,09, main 0,03,
faute 0,08, mêlée 0,1, et un élan d'entrée plus fort (0,6) pour que l'entrant frais pèse encore (sans lui : suite changée
31,8 % pour 35 %). Une vingtaine de variantes voisines (élan 0,5 à 0,8, jeu 0,08 à 0,13, faute 0,08 à 0,12) : chacune faisait tomber au hasard une
consigne sur 24 matchs, la compétence au but de fatigue-phases-arretees (2,1 pour 2) ou le remplaçant (29 à 34 %). Avec
l'accord de Léo, match-consignes-direct passe à 192 matchs (mêmes graines, mêmes seuils) : vert sur main et ici.

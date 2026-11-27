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

## Mesures

Remplacement au poste à la 50e ou 60e, club 102, même affiche et même tirage avec ou sans le changement (200 essais,
`temp/moteur-match-realisme/k3/mesure.cjs`) — suite changée / marge après le changement, main → branche :

| Changement | 50e suite | 50e marge | 60e suite | 60e marge |
| --- | --- | --- | --- | --- |
| Pilier | 23 → 44 % | +0,24 → +0,69 | 15 → 34 % | +0,09 → +0,63 |
| Troisième ligne | 31 → 56 % | +0,64 → +1,28 | 24 → 44 % | +0,68 → +1,07 |
| Demi de mêlée | 19 → 47 % | −0,27 → +1,72 | 17 → 32 % | +0,12 → +0,52 |
| Ailier | 30 → 39 % | +0,13 → +1,12 | 22 → 30 % | +0,40 → +0,52 |

(marge : ± 0,3 à 0,6 d'échantillonnage). Après un changement : moins de pénalités concédées (−0,1 à −0,3), plus de
porteurs qui avancent (+1,4 à +4,5 points), fautes de main par action en baisse mais un peu plus de ballons joués.

Ordinateur (200 matchs IA contre IA, test) : demi de mêlée mis à l'aile avec un trois-quarts libre 2 → 0 ; sur 150
matchs toutes compétitions, remplacements hors de la ligne alors que la ligne avait un joueur libre 12 → 0.

### Calage IA contre IA (600 matchs × graines 4242 et 7, `k1/calage.cjs` + remontées)

| Championnat | Matchs serrés (≤ 7) | Favori gagne | Remontées (mené 11-14 à la 75e) | Points |
| --- | --- | --- | --- | --- |
| Top 14 | 38,5 → 37,4 % | 64,8 → 64,3 % | 25,5 → 23,4 % | 50,6 → 51,3 |
| Premiership | 40,3 → 38,6 % | 62,4 → 63,9 % | 33,6 → 39,4 % | 57,6 → 57,8 |
| URC | 37,8 → 37,5 % | 71,7 → 68,5 % | 27,3 → 28,8 % | 51,6 → 51,1 |

Écart d'échantillonnage : ± 2 points (serrés, favori), ± 5 points (remontées, ~130 matchs concernés). Sur les trois
championnats : serrés 38,9 → 37,8 % (± 0,9), remontées 28,8 → 30,2 % (± 3). Réglage plus fort essayé (+0,25 jeu,
0,3 faute) : serrés −1,2, suite changée 31-55 % ; retenu le plus doux, qui garde la suite changée nettement au-dessus de main.

### Saisons Monde (6 graines)

Carrière Monde, club 102, saison régulière, graines 4242, 7, 2026, 11, 99, 31 (`scripts/mesure-essais-monde.cjs`) —
réel (docs/realite-matchs-20261125.md) / main / branche :

| Championnat | Points | Essais | Écart ≤ 7 | Domicile | Favori (niveau ≥ 1) |
| --- | --- | --- | --- | --- | --- |
| Top 14 | 51,0 / 50,8 / 50,6 | 5,2 / 6,14 / 6,12 | 40 / 38,8 / 39,0 % | 76 / 73,1 / 72,4 % | — / 60,8 / 62,3 % |
| Premiership | 54,9 / 56,8 / 57,5 | 7,1 / 7,28 / 7,45 | 36 / 38,0 / 37,0 % | 64 / 63,0 / 64,4 % | — / 67,4 / 71,7 % |
| URC | 49,4 / 50,5 / 51,5 | 6,3 / 6,36 / 6,51 | 41 / 37,6 / 36,7 % | 63 / 64,2 / 63,4 % | — / 73,5 / 73,2 % |
| Super Rugby | 56,9 / 57,3 / 57,1 | 7,8 / 7,51 / 7,43 | 35 / 36,3 / 35,2 % | 63 / 64,8 / 62,5 % | — / 74,8 / 70,3 % |
| Japon D1 | 60,8 / 61,0 / 60,7 | 8,5 / 8,35 / 8,30 | 30 / 34,4 / 29,6 % | 50 / 52,2 / 48,1 % | — / 79,3 / 81,8 % |

Échantillon : 480 à 1 092 matchs par championnat (± 1,5 à 2,2 points). Aucun écart hors de l'échantillonnage ; le
Japon se rapproche du réel sur les matchs serrés.

## Test

`tests/match-remplacants.cjs` (rouge sur main, vert ici) : suite changée et marge sur 248 remplacements imposés à la
50e (camp sans autre changement : suite changée 17 % avant, 50 % après, seuil ≥ 35 % ; marge +0,41, bornée à ± 3) ; sens et
bornes de chaque effet, remplaçant bien plus faible qui pèse moins ; ordinateur jamais de demi de mêlée à l'aile ni de
non-talonneur au talon quand le banc a le bon joueur (200 matchs).

## Deux suites existantes rouges (non modifiées, décision de Léo attendue)

- `tests/bonus-fin-de-match.cjs` (« viser : plus d'essais marqués ») : la mesure rend les deux XV identiques à la 60e
  (compétences et condition) mais le club du joueur n'a fait aucun changement alors que l'ordinateur a déjà sorti ses
  remplaçants ; la fraîcheur départage désormais (victoire de base en menant de 3 : 74 → 57 %). Le miroir devrait aussi
  égaliser les remplacements (ou le club du joueur remplacer comme l'ordinateur).
- `tests/match-consignes-direct.cjs` : 24 matchs à graines fixes, seuils de « suite changée » au bord (touche sûre
  17 % pour 25 %). Même cause (club du joueur sans changement face à un ordinateur qui change).
- Essais pour les garder vertes sans toucher aux tests : plafonner l'écart de fraîcheur d'un camp (tanh, 0,1 à 0,2)
  ou ne garder que l'élan d'entrée. Le bonus repasse vert, mais un remplacement du joueur après ceux de l'ordinateur ne
  pèse presque plus rien (suite changée retombée à 13-36 %, niveau de main) et la suite des consignes reste au bord du
  seuil selon la graine (relance, touche, tout tenter). Non retenu.

## Réglage du 27/11 après refusion de main (remontées tardives #1356, fautes de main #1353)
Avec l'ancien réglage (jeu 0,18, main 0,06, faute 0,25, mêlée 0,2, élan 0,35), trois mesures existantes tombaient :
consignes en direct (« touche sûre » 17 % pour 25 %, « relance=dégager » 29 % pour 30 %, 24 matchs), poids du niveau en URC
(0,182 pour 0,30) et tirs au but de la Premiership (3,11 pour 3,12). Diagnostic (une part coupée à la fois) : l'effet sur
les pénalités faisait tomber tirs et URC ; la fraîcheur en jeu faisait tomber les consignes. Retenu : jeu 0,09, main 0,03,
faute 0,08, mêlée 0,1, et un élan d'entrée plus fort (0,6) pour que l'entrant frais pèse encore (sans lui : suite changée
31,8 % pour 35 %). Une vingtaine de variantes voisines (élan 0,5 à 0,8, jeu 0,08 à 0,13, faute 0,08 à 0,12) : chacune faisait tomber au hasard une
consigne sur 24 matchs, la compétence au but de fatigue-phases-arretees (2,1 pour 2) ou le remplaçant (29 à 34 %). Avec
l'accord de Léo, match-consignes-direct passe à 192 matchs (mêmes graines, mêmes seuils) : vert sur main et ici.

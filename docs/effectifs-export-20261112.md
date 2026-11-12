# Effectifs des clubs gérés, transferts entre clubs et export mondial (12 novembre)

Suite de la mesure de la PR #552 (`docs/salaires-par-niveau-20261111.md`,
« Mesure sur deux saisons, carrière mondiale ») : deux défauts antérieurs,
présents drapeau éteint comme allumé, et quatre décisions de Léo sur
l'économie.

## 1. Les effectifs baissaient d'environ cinq joueurs par saison

### Cause

Trois seuils fixes, pensés pour une carrière de 30 clubs, s'appliquaient à
tous les clubs de la carrière mondiale :

- **Capacité** (`dist/economy.js`, `professionalCapacity`) : une carrière
  mondiale porte le marqueur de base commune ; la capacité lisait donc
  `CDCommonRosters.clubs[c.id]`, la base **française**, par numéro de club.
  Pour presque tous les clubs du monde, la capacité tombait à 42 places, alors
  que leurs effectifs réels comptent 50 à 75 joueurs. `professionalPlaces`
  valait 0 : ni recrutement ni promotion d'espoir tant que l'effectif
  dépassait 42.
- **Cible de population** (`dist/ai-roster-cycle.js`) : 37 professionnels pour
  tous (`aiRosterDepthNeeds`, boucle de promotions de l'intersaison), 40 pour
  recruter (`aiRosterMayRecruit`), 28 pour juger une prolongation
  « indispensable ».
- **Deux recrues par saison** au plus par club.

Les départs (retraites, fins de contrat non prolongées, jusqu'à cinq par club)
n'étaient donc remplacés qu'une fois l'effectif tombé vers 37-40 : la banc de
dix saisons de novembre (`docs/player-population-world-ten-season-20261109.json`)
montre la convergence de toutes les ligues vers 37,0 en saison 10.

### Correction

- **Cible par club** (`aiRosterTarget`) : la taille réelle de l'effectif à la
  création (registre mondial de l'édition, ou base commune française), bornée
  entre 40 (plancher des professionnels du moteur natif) et 58. Les besoins par
  poste sont mis à l'échelle de cette cible. La politique historique
  (population v1) et les carrières sans référence gardent 37 : les captures
  figées de la carrière France ne bougent pas.
- **Capacité mondiale** lue dans le registre de l'édition jouée : effectif
  initial + 6, au moins 42 (même règle que la base commune).
- **Recrues de la saison** : 2 comme avant, plus le manque à la cible, au plus 6.
- Un effectif sous sa cible garde au moins un besoin (au poste le moins couvert)
  quand les polyvalents masquent les manques par poste.

## 2. Transferts entre clubs gérés

`native/engine/club-transfers.cjs`, branché avant le recrutement des joueurs
libres à chaque fenêtre des clubs gérés (début de saison à partir de la
deuxième, semaine 13). Stratégie de chaque club, recalculée à chaque fenêtre
à partir de sa situation publique dans son championnat :

| Stratégie | Quand | Achète | Vend |
| --- | --- | --- | --- |
| vedettes | réputation ≥ médiane + 3, trésorerie ≥ 1,15 × médiane, masse ≤ 95 % de sa limite | des joueurs meilleurs que ses titulaires, y compris non proposés (1,5 × la valeur, jamais l'un des trois meilleurs du vendeur, vendeur moins réputé d'au moins 5 points) | son surplus seulement |
| formateur | installations ≥ 3 ou ≥ 30 % de moins de 23 ans | jeunes (≤ 23 ans), indemnité ≤ 10 % de sa trésorerie | ses jeunes réussis (≤ 24 ans) |
| rajeunissement | âge moyen des 30 meilleurs ≥ 27,3 ans | moins de 26 ans | ses trentenaires |
| vente | dette, trésorerie < 0,9 M€ ou masse au-dessus de sa limite | rien, sauf effectif sous la cible − 2 | ses gros salaires (24 ans et plus), à 80 % de la valeur |
| equilibre | sinon | ses besoins par poste | son surplus |

Bornes : trois achats et trois ventes par club et par saison, une transaction
par club et par tour (trois tours par fenêtre) ; le vendeur garde sa cible
moins trois et ses postes couverts ; l'acheteur respecte sa masse autorisée
(`aiRosterWageLimit`, liée au plafond de la ligue quand la règle des salaires
est active), une réserve de 400 000 € plus huit semaines du nouveau salaire, ses
places et une dette inférieure à 2 M€. Un club japonais n'achète qu'au Japon
(catégories d'inscription). Valeur d'un joueur : salaire annuel × années de
contrat restantes (au plus deux) × 1,6 à 0,3 selon l'âge. Le niveau est estimé
par la cellule de recrutement du club (note de rôle à ±3 points, stable pour un
couple club-joueur). Le salaire signé : le plus haut de son salaire et de sa
demande chez l'acheteur (attrait du championnat quand la règle des salaires est
active), +3 % (+8 % pour un club « vedettes »). Le club du manager n'est ni
acheteur ni vendeur par ce chemin.

## 3. Export refusé en fin de saison 2

À compléter avec les mesures.

## Mesures

À compléter.

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
- **Moyens propres** : avec une cible, un recrutement n'est plus jugé sur la
  projection fixe de 160 000 € de recettes hebdomadaires (`recruitmentFinance`),
  que dépasse la masse de la plupart des clubs de première division (tout
  recrutement y était « non soutenable »), mais sur la trésorerie du club et sa
  masse autorisée. Sans la règle des salaires, cette masse autorisée permet de
  compléter le groupe au salaire moyen actuel du club (l'ancienne fourchette
  fixe de 215 à 335 k€ par semaine était sous la masse de départ de nombreux
  clubs) ; avec la règle des salaires, c'est sa limite (plafond de la ligue,
  52 % des recettes, moyens du propriétaire).

### Carrière France (base commune, 30 clubs)

Même défaut, même correction (chargeur des tests, club 29, graine 827381,
politique de population v2, sans le drapeau). Effectif moyen des clubs gérés :

| Point | 1re division, avant | 1re division, après | 2e division, avant | 2e division, après |
| --- | --- | --- | --- | --- |
| Création | 57,5 | 57,5 | 49,8 | 49,8 |
| Après intersaison 1 | 51,8 | 56,0 | 44,4 | 48,0 |
| Après intersaison 2 | 45,7 | 55,6 | 40,1 | 49,0 |
| Après intersaison 3 | 41,0 | 55,8 | 37,3 | 49,1 |

Cibles : 1re division 50 à 58 (moyenne 56), 2e division 40 à 58. Les
carrières historiques (population v1) et leurs captures figées
(`france-parity`, `france-long-career`) ne changent pas.

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

### Cause

L'état persisté d'une carrière mondiale de 116 clubs pèse déjà 19,3 Mo à la
création, pour une limite d'export de 24 Mio. Près d'un tiers est fait de
copies exactes des registres du jeu, recopiées dans chaque joueur :

| Champ, par joueur | Taille à la création | Ce que c'est |
| --- | --- | --- |
| `worldProfile` | 4,95 Mo | profil mondial du joueur, identique au registre (la validation l'exige) |
| `rosterProfile` | 0,83 Mo | fiche d'effectif de la fondation, identique à la référence (exigé) |
| `hiddenTraitsV2` | 0,71 Mo | traits initiaux, identiques à la source pour les joueurs du registre (exigé) |

S'y ajoute le marché visible, copie des joueurs libres (jusqu'à 1 900), que
seule l'édition Champ renvoyait au vivier par identifiant.

### Correction : export v3 (`dist/saves.js`)

- Quand le fichier ordinaire (v1) ou le marché Champ réduit (v2) ne tiennent
  pas dans la limite, l'export passe en **v3** : chaque champ de référence
  identique à son registre est remplacé, à sa place, par la marque `true` ; le
  marché renvoie au vivier par identifiant, pour toutes les éditions
  mondiales. Un champ modifié reste écrit en entier : la réduction est sans
  perte.
- À l'écriture, un contrôle aller-retour reconstruit l'état et compare son
  empreinte à celle de l'état exporté ; en cas d'écart, pas de v3.
- À la lecture, les champs sont reconstruits depuis les registres de
  l'édition avant le contrôle d'empreinte et la validation ; une marque sans
  référence est refusée. Les fichiers v1 et v2 restent lus tels quels ; le
  profil sur disque (reprise) ne change pas de format.

À compléter avec les mesures.

## 4. Décisions de Léo sur l'économie (12 novembre)

### Attrait : quitter le Top 14 à salaire égal devient rare

`native/engine/league-economy.cjs`, `QUITTER_REFERENCE = 0.12` : un joueur qui
quitte le championnat de référence (première division française, réputation
100) pour un championnat étranger moins réputé demande 12 % de plus (premiers
salaires du monde, sélection nationale qui retient les joueurs du
championnat, vie installée). Le Japon garde sa règle d'âge (prime jusqu'à 29
ans, attrait fort dès 31 ans). Taux d'acceptation sur la formule du jeu (5 000
joueurs, 27 ans, seuil du jeu, contrat de deux ans, offre en part du salaire
juste du club acheteur) :

| Origine → destination | 100 % | 110 % | 120 % | 130 % | Avant, à 100 % |
| --- | --- | --- | --- | --- | --- |
| 1re française → 1re anglaise | 25 % | 85 % | 100 % | 100 % | 88 % |
| 1re française → celte | 19 % | 77 % | 99 % | 100 % | 82 % |
| 1re française → Pacifique | 9 % | 59 % | 96 % | 100 % | 64 % |
| 1re française → 2e française | 13 % | 26 % | 71 % | 97 % | 13 % (inchangé ; 45 % à 115 %) |
| 1re anglaise → 1re française | 97 % | 100 % | 100 % | 100 % | 97 % |
| celte → 1re française | 98 % | 100 % | 100 % | 100 % | 98 % |

Justification de 15-30 % : la cible de Léo (« nettement plus rare »), et la
réalité du Top 14 (salaires les plus élevés, sélection française réservée de
fait aux joueurs du championnat). L'attrait sert au salaire demandé au club
joué et, désormais, au salaire des transferts entre clubs gérés.

### Plafond : aucun club géré au-dessus

Cause du club du Pacifique au-dessus de son plafond après chaque intersaison :
`limites()` (`native/engine/club-budget.cjs`) laisse un club de mécène
« audacieux » (12 % des saisons) s'autoriser 1 à 5 % au-dessus de sa borne la
plus basse, y compris quand cette borne est le plafond de la ligue ; les
contrats recalés à l'intersaison suivent cette limite. S'y ajoutaient les
joueurs de complément (plancher de 40 professionnels) signés au salaire de la
règle sans regarder la masse, et les renforts d'urgence. Corrections :

- la masse autorisée ne dépasse jamais le plafond (l'audace ne joue que sous
  les autres bornes, 52 % des recettes ou moyens du propriétaire) ;
- un joueur de complément d'un club géré signe sous sa masse autorisée,
  jamais sous le plancher de la règle ;
- filet de conformité après chaque commande (`budgetConformite`) : un club
  géré d'une ligue plafonnée qui dépasse ramène ses contrats sous le plafond
  par la même retenue proportionnelle que l'intersaison. Le club joué n'est
  pas touché : il reçoit l'alerte de la ligue et paie l'amende s'il dépasse.

### Caisse du club joué

Cause : les clubs gérés réinvestissent 70 % de l'excédent de l'exercice dans
le staff et le fonctionnement (`ajustement`, `club-budget.cjs`) et
économisent quand le déficit dépasse l'enveloppe du propriétaire ; le club
joué gardait 100 % de son excédent. Dans une mesure en semaines déléguées, le
manager ne prolonge personne : les contrats échus partent, la masse du club
joué baisse et l'excédent grossit d'autant. Correction : même train de vie
pour le club joué (`gere: true` pour tous dans `budgetSemaine`, prévision
alignée). Les prolongations non faites restent un effet du protocole de
mesure (un manager réel prolonge ou recrute).

## Mesures

À compléter.

# IA de match réaliste : banc, pénalités, buteur (26/11/2026)

Lot « PR D » du chantier moteur de match (anomalies 5, 6, 13 et 14 de l'audit du 25/11). Rencontres créées avec
`l.iaDecisionsVersion = 1` (`initializeManagers`, `dist/opposition.js`) ; une rencontre commencée avant garde l'ancienne IA.
Test : `tests/match-ia-decisions.cjs` (matchs IA contre IA de Premiership, URC et Top 14, carrière Monde, graine 4242).

## Remplacements (`remplacementsIA`, constantes `BANC_IA`)

- Avant : un changement toutes les cinq minutes pile de la 50e à la 80e (96 à 100 % des changements à une minute multiple
  de 5, 8 à 13 % après la 75e, un changement à la 80e dans presque chaque match) et un retour tactique par camp et par match
  (9e « remplace » dans les feuilles).
- Réel (élite) : première ligne vers 45-55', avants puis charnière et trois-quarts par vagues entre 55' et 70', presque rien
  après 75' sauf blessure.
- Maintenant : quatre groupes (première ligne, autres avants, charnière, trois-quarts) avec une minute de vague par camp
  (47-55, 54-62, 57-66, 59-69), tirée d'un repère fixe de la rencontre (aucun tirage), puis 2 à 4 minutes entre deux
  changements d'un même groupe ; jusqu'à trois changements la même minute. Large avance (15 points) : vagues avancées de
  5 min (rotation) ; gros retard : de 3 min. Joueur cramé (condition < 55) : sortie dès la 40e. Après la 75e : seulement un
  joueur à bout (condition < 40). Découverte : vagues retardées de 6 min.
- Jamais de retour tactique d'un joueur remplacé par l'IA : les retours restent ceux de la loi 3 (saignement, protocole
  commotion, première ligne, rouge de 20 minutes), gérés par leurs modules.
- Buteur protégé à score serré (écart ≤ 7 après la 50e) si son remplaçant tire 8 points moins bien.

## Rouge de 20 minutes (`restoreRedReplacements`, `dist/rugby.js`)

Le remplaçant est choisi sur sa note au poste à pourvoir, et non à son propre poste : un talonneur remplaçant n'entre plus
à l'aile (il était ensuite remplacé par un ailier, d'où « talonneur remplacé par un ailier » dans le journal).

## Choix sur pénalité (`choixPoteauxStaff`, `partToucheChampionnat`, constantes `PENALITE_IA`)

Toutes les équipes en consigne « Selon le contexte », IA de tous niveaux comme club du manager, sans tirage :

- hors de portée (réussite attendue du buteur à la marque sous le seuil, vent et pluie compris) : touche ;
- à partir de la 65e : mené de 3 points ou moins, à égalité ou devant, les poteaux (sauf bonus offensif à un essai avec
  8 points d'avance : touche) ; mené de 4 ou plus : la touche, sauf entre la 72e et la fin pour revenir dans le bonus défensif
  (logique de #1302 gardée) et, avant la 75e, mené de 8 à 10 : trois points pour revenir à un essai transformé ;
- milieu de match : les poteaux ; un pack de conquête va en touche au-delà de 28 m, sauf tir facile (réussite attendue ≥ 85 %).

La culture du championnat (`TOUCHE_CHAMPIONNATS` : Premiership, URC, Super Rugby…) ne joue plus au hasard sur toutes les
pénalités : milieu de match seulement, jamais sur un tir facile, réduite près des poteaux (×0,3 sous 22 m, ×0,75 à 22-40 m),
plus forte mené de 8 ou plus (×1,4) ou en menant largement (×1,2), plus faible à score serré (×0,6).

Consignes posées par l'IA elle-même au dilemme du bonus (`native/engine/match-bonus.cjs`) : « touche » (tout pour la
victoire) est levée à partir de la 70e quand trois points égalisent ou font gagner ; « points » est levée dans les cinq
dernières minutes quand trois points ne ramènent ni l'égalité ni le bonus défensif. Les consignes du manager sont suivies.

## Buteur titulaire (`titulariserButeur`, constantes `BUTEUR_IA`)

Le meilleur buteur disponible (ouvreur, trois-quarts, arrière) entre dans le XV de l'IA quand il tire au moins 6 points mieux
que le buteur retenu et que la perte au poste reste sous 0,4 × cet écart (10 au plus) ; il prend le poste des lignes arrières
où il coûte le moins. Quotas JIFF/EQP appliqués ensuite comme avant.

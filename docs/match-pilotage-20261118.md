# Pilotage du match façon FM (18/11/2026)

Demande de Léo : rendre le match plus décisionnel — causeries à effet réel, consignes en direct dans l'écran 2D,
profil de l'arbitre connu la veille, matchs délégués gérés par le staff. Code : `dist/match-pilotage.js`.

## Périmètre

- Seul le match du joueur en carrière Monde, créé avec `pilotageVersion` (`rugbyBegin` → `initPilotage`).
  Les matchs IA et les rencontres créées avant gardent leurs règles : championnats et données figées inchangés.
- Aucun tirage aléatoire ajouté : seules des probabilités changent (pénalités, cartons, en-avant, jeu au pied,
  touche, avantage du porteur) et des points d'attribut (état des joueurs).
- Coefficients de jeu, ordres de grandeur, non mesurés sur le réel.

## Arbitre

24 arbitres fictifs aux profils stables (rucks, mêlée, hors-jeu, cartons de 1 à 5, 3 = neutre), désignés par
rencontre (`arbitreDuMatch(fixtureId, competitionId)`) : arbitres français en championnats français, étrangers
ailleurs. Même arbitre dans le mail de la veille (commission des arbitres), la tuile de l'écran Match
d'avant-match (`clubLife.avantMatch.arbitre`) et le direct (`live.pilotage.arbitre`).

Effets : pénalités de jeu × (1 + 0,04·(hors-jeu − 3)) × (1 + 0,04·(rucks − 3)) ; ballon non libéré × (1 + 0,08·(rucks − 3)) ;
pénalités de mêlée × (1 + 0,12·(mêlée − 3)) ; risque de carton × (1 + 0,2·(cartons − 3)). Il amplifie
« Rucks : Contester ».

## Consignes en direct (`set_consignes {axe, valeur}`, sans pause)

| Axe | Crans | Effet principal |
|---|---|---|
| Jeu au pied | Garder / Équilibré / Occuper | probabilité de jeu au pied × 0,55 / × 1,55 |
| Rucks | Prudence / Normale / Contester | fautes × 0,85 / × 1,22+ (arbitre) ; ballons arrachés ; avance adverse |
| Discipline | Zéro faute / Normale / À la limite | fautes × 0,78 / × 1,2 ; défense un peu moins / plus mordante |
| Rythme | Ralentir / Normal / Accélérer | avance du porteur ∓ 0,02, en-avant ± , jeu au pied |
| Touche | Sûre (lancer court) / Normale / Risquée (fond d'alignement) | touche ± 6 points ; touche risquée gagnée = meilleure plateforme |

Bilan affiché depuis le changement (pénalités concédées, ballons arrachés, coups de pied, touches gagnées…).

## Causeries

Six tons (Calme, Exigeant, Encourageant, Furieux, Rassurant, Affirmé), une phrase de la banque par ton ; cible :
groupe, avants, arrières, un ou plusieurs joueurs. Réaction de chaque joueur : traits cachés (professionnalisme,
ambition, sang-froid, sensibilité), situation (favori/outsider, score à la mi-temps, résultat), confiance envers
le manager (`S.pilotage.confiance`, 0-100, gardée dans la carrière), usure d'un ton répété (la colère surtout) et
une part d'imprévu. États : Galvanisé, Motivé, Serein, Indifférent, Tendu, Vexé, Relâché, avec des points
d'attribut pendant le match (ex. Vexé : −2 partout, −8 en discipline). Moral collectif ±2 au plus.

## Matchs délégués

Le staff choisit le ton de chaque causerie (juste dans 25 à 90 % des cas selon le niveau de l'entraîneur) et
revoit les consignes toutes les 5 minutes (fautes, touches perdues, score), avec une vigilance liée à sa
compétence ; ses changements sont notés dans le journal.

## Adversaire

L'entraîneur adverse n'est plus passif (demande de Léo, 18/11/2026). Seulement dans le match du joueur
(`pilotageActif`), sans tirage aléatoire ajouté (tout passe par `pilotageHash`).

- **Causeries** (avant-match, mi-temps) : quand la causerie du manager s'ouvre (`native/engine/match-talks.cjs` →
  `causerieAdverse`), le staff adverse choisit son ton avec la même logique que le staff du manager (`tonDuStaff`),
  dans le contexte vu de son côté (favori ↔ outsider, mené ↔ devant). Compétence : niveau réel de ses entraîneurs
  (`staffJudges`), sinon le réglage « niveau adverse » (Découverte 50, Classique 60, Expert 72). Chaque joueur de
  sa feuille réagit avec le même modèle (`reactionJoueur`), confiance neutre (50) envers son entraîneur et usure des
  tons de ce match seulement ; l'état va dans `live.pilotage.etats` (marqué `adverse`). Confiance de la carrière
  (`S.pilotage.confiance`) et moral inchangés. Journal : « Vestiaire de Pau : discours furieux à la mi-temps. »
- **Consignes** : `live.pilotage.consignesAdverses` (celles du manager restent dans `consignes`). Le banc adverse les
  revoit toutes les 5 minutes dès le coup d'envoi, en direct comme en délégation (`pilotageAdversaire`, branché
  après chaque minute par `native/engine/match-delegation.cjs`), avec les règles du staff délégué (`reglesDuStaff`,
  partagées) : arbitre pointilleux sur les rucks → Prudence ; deux pénalités en 5 minutes → Zéro faute ; deux
  touches perdues → Sûre ; mené après 55′ → Accélérer et Garder ; devant de 10 points au plus après 65′ → Occuper
  et Ralentir. Vigilance selon sa compétence. Journal, seulement ce qui se voit sur le terrain : « Pau accélère le
  rythme. » (la minute est affichée par l'écran).
- **Projection** : `live.pilotage.adversaire = {consignes, derniers, causeries}` (ajout ; `joueurs` ne contient
  que le club joué, les états adverses restent cachés).
- Rencontres créées avant ce chantier (sans `consignesAdverses`) : adversaire neutre, comme avant.

## Mesure (tests/match-pilotage.cjs, 160 matchs par réglage, mêmes graines)

Voir la sortie du test : pénalités concédées, ballons arrachés, cartons, coups de pied, touches gagnées et écart
de score selon chaque réglage. Ces séries figent le banc adverse (une seule variable change) ; le test vérifie que
des consignes adverses neutres donnent exactement les mêmes matchs qu'avant (20 matchs, mêmes graines), puis
mesure le banc adverse actif sur 60 matchs (~2,9 changements de consigne par match).

## Limites connues

- Le moteur donne déjà ~2,5 cartons jaunes par équipe et par match (bien au-dessus du Top 14) : antérieur à ce
  chantier, à corriger à part.
- Les matchs IA contre IA n'ont ni causerie ni consigne (pilotage réservé au match du joueur).
- Version web : sans le domaine natif `match-delegation`, le banc adverse ne revoit pas ses consignes en cours de match.

## Cris de la touche, fatigue, conseil de changement (fenêtre Équipe)

- Commande `cri {id}` sans pause : Encourager (+1, apaise Tendu/Vexé, 8 min), Exiger (+2, −3 discipline, 8 min),
  Calmer (+6 discipline, apaise, 10 min), Serrer la défense (+4 plaquage, −2 passe, 10 min), Tout donner (+3, dès 65′,
  use 15 % plus vite, 10 min). Un cri à la fois ; le même cri dans les 20 minutes porte moitié moins, puis plus du tout.
- Fatigue : « Accélérer » use 12 % plus vite, « Ralentir » 8 % moins. Prévision à 10 minutes avec la formule du moteur
  (`live.pilotage.fatigue`, les 4 joueurs les plus entamés).
- Conseil de Gabi (`live.pilotage.conseilChangement`) : le joueur qui passera sous 55 % dans 10 minutes, remplacé par le
  remplaçant éligible le mieux noté et frais (≥ 85 %).
- Corps arbitral : trois arbitres femmes (accords dans le résumé, le mail et le mot de Gabi).

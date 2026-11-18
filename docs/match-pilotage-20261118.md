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

## Mesure (tests/match-pilotage.cjs, 160 matchs par réglage, mêmes graines)

Voir la sortie du test : pénalités concédées, ballons arrachés, cartons, coups de pied, touches gagnées et écart
de score selon chaque réglage.

## Limites connues

- Le moteur donne déjà ~2,5 cartons jaunes par équipe et par match (bien au-dessus du Top 14) : antérieur à ce
  chantier, à corriger à part.
- L'adversaire IA ne fait ni causerie ni consigne.

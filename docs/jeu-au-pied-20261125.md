# Jeu au pied réaliste (25-26 novembre 2026)

Audit du réalisme des phases (A1, défaut n° 1) : le moteur ne racontait que 3 à 4 coups de pied par match, presque aucun 50:22,
et un « poussé en touche » fixe de 12 % par action fabriquait la moitié des touches (10 par match, réel 2-3). Le joueur voyait
des équipes qui ne dégagent jamais de leurs 22.

## Ce qui change dans le jeu

- Depuis ses 22, l'équipe dégage le plus souvent en touche (touche directe avec gain de terrain, loi 18) ; depuis son camp,
  elle cherche la touche, tape long dans le camp adverse ou fait monter une chandelle du n° 9 ; dans le camp adverse, plus
  rarement, un coup de pied rasant ou croisé que la chasse peut reprendre.
- Un coup de pied peut être raté ou perdu : touche trouvée mais courte, dégagement contré, rendu au milieu du terrain, chandelle
  trop longue, dégagement capté puis relancé par l'adversaire (le receveur remonte le terrain), rasant ou par-dessus ramassé,
  chandelle d'attaque ou croisé captés par la défense. La touche directe sans gain de terrain, rare au haut niveau, reste
  rare (~0,2 par match ; 4,1 dans la première version, où elle servait de forme principale de perte de balle dans son camp).
- Le botteur est nommé dans le journal et sur les touches au pied (match 2D/3D, fiche de stats). Le joueur qui prend le
  ballon (receveur adverse ou partenaire qui reprend) est nommé dans le fait (`receiver`) et placé au point de chute dans le
  match 2D/3D : avant, le ballon retombait seul au sol, l'équipe restant en formation 5 à 13 m en retrait. En 3D, le ballon
  suit l'arc du coup de pied jusque dans ses mains (8e passage : il finissait au sol, à ses pieds).
- À l'écran : avec le chorégraphe éteint (défaut), un coup de pied de jeu est montré au niveau « Match complet » ; aux autres
  niveaux, il ne devient un temps fort que s'il dépasse 35 m ou tombe dans les 22 adverses après 20 m (règles inchangées de
  `native/engine/match-highlights.cjs`), ce qui arrive rarement avec des coups de pied de 15 à 35 m.
- 50:22 rares ; ballons qui roulent dans l'en-but : renvoi sur la ligne d'essai (aplati par la défense) ou aux 22 m (mort).
- Plan de jeu (occupation, jeu au large), qualité des botteurs, pluie et score après la 60e pèsent sur la décision de taper.
  En fin de match, l'équipe menée de 15 points ou moins ne dégage plus de son camp, sauf depuis ses 22.
- Le porteur n'est plus « poussé en touche » qu'environ 1,5 fois par match (10 avant).
- Un en-avant commis pendant l'avantage de l'adversaire (chandelle relâchée par le receveur, par exemple) est suivi de la ligne
  « Avantage sur en-avant pour X » (avant : rien, et le journal enchaînait sur l'action suivante ; `tests/match-recit-coherent.cjs`).
- Ballon botté mort dans l'en-but : la défense ne prend la mêlée à l'endroit du coup de pied que s'il a été frappé depuis le
  camp du botteur (sinon renvoi aux 22 m).

Une action du moteur couvre plusieurs temps de jeu : le journal raconte ~13 coups de pied par match (réel 40-50, dont beaucoup
de petites relances entre arrières), dont ~7 touches au pied. La fiche de stats garde ~23 coups de pied par équipe.

## Méthode : même équilibre que l'ancien moteur

Les premiers réglages (17-18 coups de pied racontés) creusaient les écarts : sur une saison Monde, 8 à 10 points de matchs
serrés en moins. Cause mesurée : l'équipe dans son camp rendait le ballon une action sur deux au pied, celle qui attaquait
dans le camp adverse ne le perdait presque plus ; les points venaient par séries et le favori convertissait mieux.

Réglage retenu : par zone du terrain, la probabilité qu'une action change la possession reste celle de l'ancien moteur. Les
coups de pied prennent la place de l'ancien « poussé en touche » et des pertes de balle, ils ne s'y ajoutent pas. Seuls les
dégagements depuis ses 22 changent un peu plus souvent la possession (voulu). Le poids de la qualité du botteur est réduit de
moitié (`qualite` 0,5) : à plein poids, le meilleur botteur s'ajoutait au niveau de l'équipe déjà compté, et le favori gagnait
plus souvent (pente de la courbe de niveau 0,324 contre 0,313 avant ; 0,309 à mi-poids, banc URC 3 × 2 700 matchs) ; 0,3 depuis
le 26/11. Les dégagements de son camp trouvent plus souvent la touche (touche courte plutôt que ballon rendu dans le champ) et
le poussé en touche passe de 2,2 à 1,2 % par action : le reste devient un coup de pied perdu, même lancer adverse au même endroit.

## Réglages (dist/tactical-plans.js, `JEU_PIED`)

`zone` (probabilité d'ouvrir le jeu au pied par action, par zone : ses 22 0,25), `types` (touche / long / chandelle / rasant /
croisé par zone), `perdu` (coup de pied raté ou perdu, par zone, à la place de l'ancien poussé en touche), `perdus` (formes de
cette perte par zone : touche courte, touche directe 2 %, contré, rendu, chandelle, capté-relancé ; dans le camp adverse
touche, rasant, chandelle, croisé, en-but), `perduMetres` (terrain rendu : 1 à 8 m, comme l'ancien poussé), `longueur` 0,7,
`touche` 0,85 (touche trouvée), `cinquante` (tentative, réussite), `recup` (chandelle, rasant, croisé), `pousse` (1,2 % + 2 %
près des lignes), `qualite` 0,3. `JEU_PIED_RULES=0` rend l'ancien jeu au pied (comparaisons). Coefficients de jeu calés sur des
matchs Monde, pas des probabilités mesurées du rugby.

## Avant / après

Matchs de championnat Monde, moteur complet, 600 matchs par championnat et par jeu de graines (911111 et 827381, moyenne des
deux), ancien jeu au pied → nouveau, par match :

| | Top 14 | Premiership | URC |
| --- | --- | --- | --- |
| Coups de pied racontés | 3,3 → 13,0 | 3,5 → 13,2 | 4,1 → 13,7 |
| Touches au pied | 1,9 → 6,8 | 1,9 → 6,9 | 2,2 → 7,1 |
| dont directes sans gain de terrain | → 0,24 | → 0,26 | → 0,27 |
| Porteur poussé en touche | 10,1 → 1,5 | 10,0 → 1,5 | 10,3 → 1,5 |
| Renvois aux 22 m et sur la ligne d'essai | 1,44 → 1,94 | 1,28 → 1,69 | 1,25 → 1,79 |
| 50:22 | 0,01 → 0,05 | 0,01 → 0,03 | 0,01 → 0,04 |
| Points | 47,2 → 46,7 | 53,3 → 51,3 | 48,2 → 47,9 |
| Essais | 5,39 → 5,32 | 7,12 → 6,85 | 6,23 → 6,23 |
| Matchs à 7 points ou moins | 43,0 → 40,3 % | 34,5 → 32,2 % | 31,9 → 32,7 % |
| Écart moyen | 12,8 → 13,6 | 17,4 → 16,9 | 18,4 → 18,1 |

Regroupé (3 600 matchs, réglage du 26/11 avec la courbe URC recalée) : matchs serrés −1,4 point (bruit ±1,1), écart moyen 0,0,
points −0,9 (pluie : plus de jeu au pied). Changement de possession par action
(URC, ses 22 / son camp / camp adverse / 22 adverses) : 0,39 / 0,43 / 0,49 / 0,56 avant, 0,42 / 0,45 / 0,48 / 0,55 après (Top 14 : 0,37 / 0,44 / 0,50 / 0,55 → 0,44 / 0,45 / 0,49 / 0,55).
Réel (élite) : 40-50 coups de pied par match dont 12-18 en touche, 2-3 porteurs poussés en touche, 50:22 rares, touche directe
sans gain 0,3 à 0,5.

Formes des pertes (26/11, après le vérificateur) : dans la première version, la touche directe sans gain servait de perte
de balle dans son camp et faisait 65 % des touches au pied (4,1 par match). Elle est remplacée par la touche courte (1 à 5 m
gagnés), le dégagement rendu ou contré, la chandelle trop longue et le dégagement capté puis relancé ; dans le camp adverse,
par une touche trouvée de peu, le rasant ramassé, la chandelle ou le croisé captés. Le terrain rendu reste celui de l'ancien
poussé en touche : avec 6 à 14 m gagnés sur la touche courte, les points baissaient d'un point par match et les matchs serrés
de 2.
Saisons Monde complètes (`scripts/mesure-essais-monde.cjs`, club 102), réglage final du 26/11, moyenne des graines 4242, 7 et
2026, avant (`--regler "JEU_PIED_RULES=0"`, courbe URC d'avant) / après / réel (docs/realite-matchs-20261125.md) :

| Championnat | Points | Essais | Écart moyen | Écart ≤ 7 | Bonus offensif |
| --- | --- | --- | --- | --- | --- |
| Top 14 | 49,4 / 48,3 / 51,0 | 5,95 / 5,80 / 5,2-5,9 | 12,5 / 13,8 / 14,3 | 44,4 / 37,4 / 40 % | 36,6 / 35,7 % |
| Premiership | 54,1 / 52,7 / 54,9 | 7,24 / 7,09 / 7,1-8,0 | 13,2 / 14,3 / 16,1 | 40,5 / 36,6 / 36 % | 52,9 / 50,2 % |
| URC | 49,7 / 49,2 / 49,4 | 6,63 / 6,51 / 6,3-6,6 | 13,7 / 14,4 / 14,2 | 39,5 / 37,7 / 41 % | 45,7 / 42,8 % |

Par graine, écart ≤ 7 avant → après : Top 14 40,6 → 36,9 / 46,0 → 35,8 / 46,5 → 39,6 ; Premiership 43,0 → 39,8 /
39,8 → 35,5 / 38,7 → 34,4 ; URC 43,0 → 37,7 / 36,4 → 41,1 / 39,1 → 34,4 (une saison : bruit de ±3 à ±5 points).

## Courbe de niveau et cartons

- `tests/match-rating-curve.cjs` : la pente du moteur complet valait ~0,31 en moyenne sur 6 graines (ancien jeu au pied
  compris), le résultat rapide ~0,26 : l'écart touchait la limite de 0,05 du test (0,317 à sa graine avec un réglage voisin).
  Courbe URC recalée (`ECART_CHAMPIONNAT`, dist/rugby.js : complet 2,3 → 2, rapide 1,4 → 1,5, cible 0,30) : complet 0,248-0,292,
  rapide 0,278-0,287, marge 0,020 à 0,047 sur les graines 4242, 7, 2026, 11, 99, 31337 (0,045 à celle du test).
- `tests/match-jeu-au-pied.cjs` (touches au pied ≥ 6, Top 14, 48 matchs) : 5,9 à sa graine avant le 26/11 ; 7,2 / 7,0 / 6,5 / 7,5 /
  7,9 sur 5 jeux de graines (décalages 0 à 4 000) après.
- `tests/arbitrage-fin.cjs` (80 rejeux du même match) : 0,0875 exclusion par équipe (seuil 0,12). Un tirage à 0,1375 avant la
  fusion de main était du hasard : 1 680 rejeux par règle (21 jeux de graines), 0,074 avec le nouveau jeu au pied contre 0,080
  avec l'ancien.

### Test de fatigue des phases arrêtées

`tests/fatigue-phases-arretees.cjs` comparait la probabilité moyenne d'un tir de référence en début et en fin de match. Cette
moyenne dépend du buteur présent : près d'une fois sur deux, le meilleur buteur d'une feuille IA est remplaçant, et les équipes
aux meilleurs botteurs tapent plus et tirent un peu moins tôt dans le match (part des tentatives de l'équipe au meilleur buteur
51,3 → 49,2 %). Compétence au but nue du buteur, 0-19 contre 60-89 : 70,8 → 72,0 avant, 69,4 → 72,2 après ; la perte due à la
fatigue sur ce tir est identique (0,56 → 1,72 avant, 0,54 → 1,76 après). Le test mesure désormais cette perte pour le même
buteur (probabilité à condition 100 moins probabilité réelle), mêmes seuils ; un meilleur buteur entré en fin de match ne masque
plus une perte de fatigue.

# Jeu au pied réaliste (25-26 novembre 2026)

Audit du réalisme des phases (A1, défaut n° 1) : le moteur ne racontait que 3 à 4 coups de pied par match, presque aucun 50:22,
et un « poussé en touche » fixe de 12 % par action fabriquait la moitié des touches (10 par match, réel 2-3). Le joueur voyait
des équipes qui ne dégagent jamais de leurs 22.

## Ce qui change dans le jeu

- Depuis ses 22, l'équipe dégage le plus souvent en touche (touche directe avec gain de terrain, loi 18) ; depuis son camp,
  elle cherche la touche, tape long dans le camp adverse ou fait monter une chandelle du n° 9 ; dans le camp adverse, plus
  rarement, un coup de pied rasant ou croisé que la chasse peut reprendre.
- Un coup de pied peut être raté : touche directe, contré, trop court, croisé qui sort, rasant ramassé, chandelle captée.
- Le botteur est nommé dans le journal et sur les touches au pied (match 2D/3D, fiche de stats).
- 50:22 rares ; ballons qui roulent dans l'en-but : renvoi sur la ligne d'essai (aplati par la défense) ou aux 22 m (mort).
- Plan de jeu (occupation, jeu au large), qualité des botteurs, pluie et score après la 60e pèsent sur la décision de taper.
  En fin de match, l'équipe menée de 15 points ou moins ne dégage plus de son camp, sauf depuis ses 22.
- Le porteur n'est plus « poussé en touche » qu'environ 2 fois par match (10 avant).
- Un en-avant commis pendant l'avantage de l'adversaire (chandelle relâchée par le receveur, par exemple) est suivi de la ligne
  « Avantage sur en-avant pour X » (avant : rien, et le journal enchaînait sur l'action suivante ; `tests/match-recit-coherent.cjs`).
- Ballon botté mort dans l'en-but : la défense ne prend la mêlée à l'endroit du coup de pied que s'il a été frappé depuis le
  camp du botteur (sinon renvoi aux 22 m).

Une action du moteur couvre plusieurs temps de jeu : le journal raconte ~12 coups de pied par match (réel 40-50, dont beaucoup
de petites relances entre arrières), dont ~6,5 touches au pied. La fiche de stats garde ~23 coups de pied par équipe.

## Méthode : même équilibre que l'ancien moteur

Les premiers réglages (17-18 coups de pied racontés) creusaient les écarts : sur une saison Monde, 8 à 10 points de matchs
serrés en moins. Cause mesurée : l'équipe dans son camp rendait le ballon une action sur deux au pied, celle qui attaquait
dans le camp adverse ne le perdait presque plus ; les points venaient par séries et le favori convertissait mieux.

Réglage retenu : par zone du terrain, la probabilité qu'une action change la possession reste celle de l'ancien moteur. Les
coups de pied prennent la place de l'ancien « poussé en touche » et des pertes de balle, ils ne s'y ajoutent pas. Seuls les
dégagements depuis ses 22 changent un peu plus souvent la possession (voulu). Le poids de la qualité du botteur est réduit de
moitié (`qualite` 0,5) : à plein poids, le meilleur botteur s'ajoutait au niveau de l'équipe déjà compté, et le favori gagnait
plus souvent (pente de la courbe de niveau 0,324 contre 0,313 avant ; 0,309 à mi-poids, banc URC 3 × 2 700 matchs).

## Réglages (dist/tactical-plans.js, `JEU_PIED`)

`zone` (probabilité d'ouvrir le jeu au pied par action, par zone : ses 22 0,25), `types` (touche / long / chandelle / rasant /
croisé par zone), `perdu` (coup de pied raté ou perdu, par zone, à la place de l'ancien poussé en touche), `longueur` 0,7,
`touche` 0,8 (touche trouvée), `cinquante` (tentative, réussite), `recup` (chandelle, rasant, croisé), `pousse` (2,2 % + 2 %
près des lignes), `qualite` 0,5. `JEU_PIED_RULES=0` rend l'ancien jeu au pied (comparaisons). Coefficients de jeu calés sur des
matchs Monde, pas des probabilités mesurées du rugby.

## Avant / après

Matchs de championnat Monde, moteur complet, 600 matchs par championnat et par jeu de graines (911111 et 827381, moyenne des
deux), ancien jeu au pied → nouveau, par match :

| | Top 14 | Premiership | URC |
| --- | --- | --- | --- |
| Coups de pied racontés | 3,3 → 11,7 | 3,5 → 12,1 | 4,1 → 12,4 |
| Touches au pied | 2,0 → 6,4 | 2,0 → 6,7 | 2,0 → 6,7 |
| Porteur poussé en touche | 10,1 → 2,3 | 10,1 → 2,4 | 10,1 → 2,3 |
| Renvois aux 22 m et sur la ligne d'essai | 1,45 → 1,95 | 1,28 → 1,80 | 1,25 → 1,82 |
| 50:22 | 0,01 → 0,03 | 0,01 → 0,03 | 0,02 → 0,05 |
| Points | 47,2 → 47,8 | 53,3 → 52,2 | 48,2 → 48,6 |
| Essais | 5,40 → 5,49 | 7,12 → 6,96 | 6,24 → 6,33 |
| Matchs à 7 points ou moins | 43,0 → 42,3 % | 34,5 → 33,4 % | 31,9 → 29,9 % |
| Écart moyen | 12,8 → 13,3 | 17,4 → 17,3 | 18,4 → 19,4 |

Regroupé (3 600 matchs) : matchs serrés −1,3 point (bruit ±1,1), écart moyen +0,5. Réel (élite) : 40-50 coups de pied par
match dont 12-18 en touche, 2-3 porteurs poussés en touche, 50:22 rares.

Saisons Monde complètes (`scripts/mesure-essais-monde.cjs`, club 102), moyenne des graines 4242, 7 et 2026, avant
(`--regler "JEU_PIED_RULES=0"`) / après / réel (docs/realite-matchs-20261125.md) :

| Championnat | Points | Essais | Écart moyen | Écart ≤ 7 | Bonus offensif |
| --- | --- | --- | --- | --- | --- |
| Top 14 | 49,4 / 50,0 / 51,0 | 5,95 / 6,08 / 5,2-5,9 | 12,5 / 13,2 / 14,3 | 44,4 / 40,0 / 40 % | 36,6 / 37,7 % |
| Premiership | 54,1 / 53,1 / 54,9 | 7,24 / 7,13 / 7,1-8,0 | 13,2 / 14,4 / 16,1 | 40,5 / 40,5 / 36 % | 52,9 / 48,7 % |
| URC | 49,7 / 49,9 / 49,4 | 6,63 / 6,65 / 6,3-6,6 | 13,7 / 14,6 / 14,2 | 39,5 / 38,4 / 41 % | 45,7 / 45,7 % |

Par graine, écart ≤ 7 avant → après : Top 14 40,6 → 38,0 / 46,0 → 38,0 / 46,5 → 43,9 ; Premiership 43,0 → 44,1 /
39,8 → 36,6 / 38,7 → 40,9 ; URC 43,0 → 35,8 / 36,4 → 39,1 / 39,1 → 40,4.

## Courbe de niveau et cartons

- `tests/match-rating-curve.cjs` : pente du moteur complet 0,286 (ancien jeu au pied 0,281), résultat rapide 0,263 ; vert.
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

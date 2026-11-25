# Jeu au pied réaliste (25 novembre 2026)

Audit du réalisme des phases (A1, défaut n° 1) : le moteur ne jouait que 3 à 4,5 coups de pied par match (réel 40-50, dont
12-18 en touche), aucun 50:22, 0,7 renvoi aux 22 m, et un « poussé en touche » fixe de 12 % par action fabriquait la moitié
des touches (10 par match, réel 2-3). Le joueur voyait des équipes qui ne dégagent jamais de leurs 22.

## Ce qui change dans le jeu

- Depuis ses 22, l'équipe dégage presque toujours en touche (touche directe avec gain de terrain, loi 18) ; depuis son camp,
  elle cherche la touche, tape long dans le camp adverse ou fait monter une chandelle du demi de mêlée ; dans le camp
  adverse, plus rarement, un coup de pied rasant ou par-dessus la défense, que la chasse peut récupérer.
- Le botteur est nommé dans le journal et sur les touches au pied (match 2D/3D, fiche de stats).
- 50:22 rares (tentés depuis son camp, ballon qui rebondit avant la touche dans les 22 adverses) ; ballons qui roulent dans
  l'en-but : renvoi sur la ligne d'essai (aplati par la défense) ou aux 22 m (mort), d'où plus de renvois.
- Choix du plan (occupation × 2,2, jeu au large × 0,7), qualité du jeu au pied des arrières, pluie (+15 % par niveau) et score
  après la 60e (qui mène tape plus, qui est mené de 8 ou plus garde le ballon) pèsent sur la décision de taper.
- Le porteur n'est plus « poussé en touche » qu'environ 2 fois par match.
- Ballon botté mort dans l'en-but : la défense ne prend la mêlée à l'endroit du coup de pied que s'il a été frappé depuis le
  camp du botteur (sinon renvoi aux 22 m).

Une action du moteur couvre plusieurs temps de jeu : le journal raconte 17-21 coups de pied par match (pas les 45 réels,
dont beaucoup de petites relances au pied entre deux arrières), dont 8-10 en touche. La fiche de stats compte désormais les
touches au pied du journal et reconstitue moins de coups de pied courants (0,62 → 0,42 par minute) : ~23 par équipe, comme avant.

## Réglages (dist/tactical-plans.js, `JEU_PIED`)

`zone` (probabilité de taper par action : ses 22 0,85, son camp 0,55, camp adverse 0,12, 22 adverses 0,04), `types` (répartition
touche / long / chandelle / rasant par zone), `touche` 0,8 (touche trouvée), `directe22` 0,8, `cinquante` (tentative 3 %,
réussite 35 %), `recup` (chandelle 0,28, rasant 0,32), `enAvant` 0,07, `pousse` (2,2 % + 2 % à moins de 10 m des lignes).
`JEU_PIED_RULES=0` rend l'ancien jeu au pied (comparaisons). Coefficients de jeu calés sur des matchs Monde, pas des probabilités
mesurées du rugby.

## Avant / après

Matchs de championnat Monde, moteur complet, 90 matchs par championnat (graine 827381), avant (`main`) → après, par match :

| | Top 14 | Premiership | URC | Nationale |
| --- | --- | --- | --- | --- |
| Coups de pied de jeu | 3,3 → 18,3 | 3,7 → 17,2 | 4,6 → 18,3 | – → 13,1 |
| Touches au pied (dont 50:22) | 1,8 → 9,1 | 2,1 → 8,5 | 2,6 → 9,0 | – → 6,0 |
| Porteur poussé en touche | 10,0 → 2,1 | 9,9 → 2,2 | 10,1 → 2,2 | – → 1,8 |
| Renvois aux 22 m / sur la ligne d'essai | 0,66 + 0,62 → 1,09 + 0,86 | 0,58 + 0,70 → 0,80 + 1,11 | 0,77 + 0,63 → 1,00 + 1,29 | – → 1,33 + 0,84 |
| 50:22 | 0 → 0,19 | 0 → 0,14 | 0 → 0,21 | – → 0,06 |
| Lancers en touche | 18,9 → 19,4 | 20,6 → 20,5 | 21,5 → 20,8 | – → 19,4 |
| Points | 48,9 → 49,4 | 53,4 → 54,9 | 48,0 → 49,2 | – → 45,7 |
| Essais | 5,52 → 5,82 | 7,07 → 7,40 | 6,28 → 6,47 | – → 6,08 |

Réel (élite) : 40-50 coups de pied par match dont 12-18 en touche, 2-3 porteurs poussés en touche, 50:22 rares (0,2-0,5).

Saison Monde complète (`scripts/mesure-essais-monde.cjs`, graine 4242, club 102), avant (`JEU_PIED_RULES=0`) / après / réel
(docs/realite-matchs-20261125.md) :

| Championnat | Points | Essais | Écart moyen | Écart ≤ 7 | Bonus offensif (4 essais) |
| --- | --- | --- | --- | --- | --- |
| Top 14 | 49,5 / 50,9 / 51,0 | 5,93 / 6,26 / 5,2-5,9 | 12,6 / 15,2 / 14,3 | 41,7 / 33,2 / 40 % | 41,2 / 36,9 % |
| Premiership | 56,1 / 52,8 / 54,9 | 7,72 / 7,06 / 7,1-8,0 | 15,4 / 16,5 / 16,1 | 35,5 / 28,0 / 36 % | 56,5 / 50,5 % |
| URC | 48,5 / 50,9 / 49,4 | 6,45 / 6,82 / 6,3-6,6 | 13,7 / 18,6 / 14,2 | 37,7 / 27,8 / 41 % | 44,4 / 46,7 % |
| Nationale | 46,9 / 46,7 / – | 6,27 / 6,25 / – | 11,1 / 10,8 / – | 45,5 / 47,1 / – | 37,7 / 37,2 % |

**À reprendre avant fusion** : sur cette graine, les matchs deviennent plus déséquilibrés (écart ≤ 7 −8 à −10 points en
Top 14, Premiership et URC, écart moyen URC +5) ; graines 7 et 2026 non mesurées. `tests/bonus-fin-de-match.cjs` est rouge :
« sécuriser » (jeu au près, défense prudente, points) tape désormais pour sortir de son camp et encaisse 0,62 essai en 20 min
au lieu de 0,92, d'où autant de bonus offensifs que « viser » (0,45 contre 0,38 ; main 0,15 contre 0,39). Variantes essayées
sans succès net (100 fins de match) : pas de majoration « mène » pour le jeu au large, jeu au large qui sort de ses 22 comme
les autres mais tape moitié moins ailleurs (0,43 / 0,43), conquête × 0,7 (change aussi l'adversaire IA).

### Test de fatigue des phases arrêtées

`tests/fatigue-phases-arretees.cjs` comparait la probabilité moyenne d'un tir de référence en début et en fin de match. Cette
moyenne dépend du buteur présent : près d'une fois sur deux, le meilleur buteur d'une feuille IA est remplaçant, et les équipes
aux meilleurs botteurs tapent plus et tirent un peu moins tôt dans le match (part des tentatives de l'équipe au meilleur buteur
51,3 → 49,2 %). Compétence au but nue du buteur, 0-19 contre 60-89 : 70,8 → 72,0 avant, 69,4 → 72,2 après ; la perte due à la
fatigue sur ce tir est identique (0,56 → 1,72 avant, 0,54 → 1,76 après). Le test mesure désormais cette perte pour le même
buteur (probabilité à condition 100 moins probabilité réelle), mêmes seuils ; un meilleur buteur entré en fin de match ne masque
plus une perte de fatigue.

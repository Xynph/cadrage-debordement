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

MESURES

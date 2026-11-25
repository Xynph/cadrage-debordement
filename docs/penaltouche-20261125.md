# Pénaltouche contre tir au but (25/11/2026)

Constat (docs/penalites-au-but-20261123.md) : une équipe qui joue toujours la pénaltouche gagnait 55-59 % de ses matchs
contre « Selon le contexte », une équipe qui prend toujours les points 49 %. Le recalage du buteur (#1203) n'y changeait
rien. Leviers validés par Léo : touche plus risquée selon les sauteurs adverses, ballon porté mieux défendu par de bons
avants, moins d'essais directs sur ballon porté, relance après un tir réussi plus avantageuse (dans les règles).

## Réglages

Rencontres avec pénalités réalistes (`penalitesRules`), `dist/tactical-plans.js` (`PENALTOUCHE`), appelés depuis
`contestSetPiece` (`dist/rugby.js`). Aucun tirage ajouté ; les rencontres plus anciennes gardent les formules d'avant.

- **Touche sur pénalité dans le camp adverse** (`penaltoucheRisque`) : la défense conteste chaque lancer
  (`risque`, −8 points de réussite) et l'écart de touche (talonneur et deuxième ligne des deux camps) pèse 1,2 point par
  point de note, en plus de l'écart commun (0,4) : de bons sauteurs adverses rendent la pénaltouche risquée, de bons
  sauteurs chez soi la sécurisent.
- **Touche près de la ligne** (2e tour, `ligne`, `risqueLigne`, `sauteursLigne`) : à moins de 22 m de la ligne (plein effet
  à 5 m), la défense regroupée et en place met tous ses sauteurs au contre : risque +6 points et écart de touche
  +1,2 point par point de note en plus, à proportion de la proximité : à 5 m, une équipe neutre perd encore ~6 points de réussite ; de bons sauteurs la
  sécurisent davantage, de mauvais la ratent davantage.
- **Essai direct sur ballon porté après une touche gagnée près de la ligne** (`ballonPorteBase`) : base 0,14 au lieu de
  0,18 ; l'écart se mesure entre la puissance des avants qui poussent et la défense des avants adverses (moyenne
  puissance et plaquage des n° 1 à 8, 1,2 point par point de note) au lieu du plaquage de toute l'équipe (0,3 point) ;
  plancher 4 % au lieu de 8 %. Mêlées inchangées.
- **Relance après un tir réussi : pas de changement.** Mesuré : l'équipe qui vient de marquer et reçoit le renvoi
  perd environ 0,6 point net sur les 10 minutes suivantes (elle part de ses 30 m), ce qui reste plausible ; dans les
  règles, les leviers possibles (renvoi moins souvent repris : 6 % seulement le sont ; renvoi fautif) pèsent moins de
  0,1 point par renvoi. Question posée à Léo.
- Essai abandonné : réduire l'essai direct selon la distance de la touche à la ligne. La part des essais sur porté
  tombait à 5,6 % sans réduire l'avantage de la pénaltouche (le jeu après la touche marque quand même).

## Mesure

`scripts/mesure-buteurs.cjs` (outil de #1203, complété) : XV identiques (club 4 copié des deux côtés), l'un avec une
consigne figée, l'autre en « Selon le contexte » ; `--pres=30` limite la consigne aux pénalités à moins de 30 m (au-delà :
« Selon le contexte ») ; `--profil` / `--profil-adverse` modifient la copie (sauteurs : touche +15 du talonneur et des 2e
et 3e lignes ; avants : puissance, mêlée et plaquage +10 des avants ; buteur : but +15) ; `--graine` change la graine
du harnais ; mêmes graines (1 à 6) avant et après. Diagnostic par consigne : points et essais marqués et encaissés,
cartons jaunes des deux camps, renvois reçus. Résultats : voir le tableau ci-dessous.

## Résultats (graines 1 à 6, 3000 matchs par cas, intervalle à 95 %)

Avant = origin/main 817987337 ; 1er tour = risque et sauteurs sur toute touche de pénalité dans le camp adverse,
ballon porté ; 2e tour (réglage retenu) = 1er tour + touche près de la ligne.

| Cas | Pénaltouche avant / 1er / 2e tour | Tir au but avant / 1er / 2e tour |
| --- | --- | --- |
| Près des poteaux, contre « Selon le contexte » | 53,7 / 53,1 / 51,7 % (± 1,8) | 50,5 / 49,5 / 49,2 % (± 1,8) |
| Toutes pénalités | 57,7 / 53,6 / 54,3 % (± 1,8) | 48,9 / 48,7 / 50,6 % (± 1,8) |
| Duel direct, près des poteaux | 52,1 / 53,5 / 52,8 % (± 1,8) | - |
| Duel direct, toutes pénalités | 56,7 / 55,8 / 54,3 % (± 1,8) | - |
| Bons sauteurs et avants, près (2400) | 60,3 / 63,9 / 66,3 % (± 1,9) | 56,9 / 58,9 / 59,4 % (± 2,0) |
| Bon buteur, près (2400) | 51,7 / 53,1 / 52,1 % (± 2,0) | 51,2 / 50,4 / 51,2 % (± 2,0) |
| Adversaire bons sauteurs et avants, près (2400) | 44,1 / 40,8 / 39,3 % (± 2,0) | 42,9 / 40,3 / 38,6 % (± 2,0) |

Ligue (Top 14, 1200 matchs, IA contre IA), avant / 1er / 2e tour : points 54,3 / 53,2 / 53,7 ; essais 6,75 / 6,58 / 6,61
par match ; essais sur ballon porté 10,8 / 9,4 / 9,1 % ; pénaltouches 7,85 / 7,86 / 7,73 par match ; touche sur pénalité
gagnée dans le camp adverse 75,5 / 67,9 / 67,2 % (autres touches ~76 %) ; réussite au but à moins de 30 m
88,9 / 87,7 / 87,9 % ; essai dans la suite d'une pénaltouche 17,4 / 16,2 / 15,8 %.

## Limite : l'égalité stricte près des poteaux

Près des poteaux, l'écart passe de 3,2 (avant) et 3,6 (1er tour) à 2,5 points (51,7 contre 49,2), dans le bruit de
mesure (± 1,8 de chaque côté) mais au-dessus de la cible de 1,5. Le réglage retenu est le plus prudent ; aller plus loin
casserait le réalisme :

- **Ce n'est plus l'attaque qui fait l'avantage.** Près des poteaux, l'équipe « touche » marque désormais un peu moins
  que l'équipe « points » (26,5 contre 26,7 points par match) mais encaisse nettement moins (25,9 contre 27,2 ; 2,90
  essais encaissés contre 3,07). Cartons égaux des deux côtés (0,6 par match).
- **D'où vient l'écart :** l'équipe qui prend les points reçoit plus de renvois (4,9 contre 4,3 par match), chacun lui
  coûte ~0,6 point net sur 10 minutes (levier 4, question à Léo) ; et la touche garde l'adversaire coincé dans ses 22 m
  et fait tourner l'horloge, ce qui est le vrai bénéfice de la touche au rugby.
- **Ce qui ne bouge plus :** pousser le risque de touche près de la ligne jusqu'à +14 points (environ 14 points de réussite en moins à 5 m)
  ne change ni la valeur d'une touche (≈ 2,1 points nets sur 10 minutes) ni les victoires : une touche perdue à 5 m
  laisse l'adversaire dégager depuis son en-but. Baisser encore l'essai direct sur ballon porté (0,12) fait tomber la
  part du porté sous 9 % en ligue (8,8-8,9 %) sans gain net, et la touche sur pénalité gagnée vers 66 %.
- **Bon buteur :** près des poteaux, tout le monde réussit 87 à 99 % ; un meilleur buteur n'y change presque rien,
  c'est réaliste (son effet est aux longues distances).
- **Adversaire bons sauteurs et avants :** touche et tir à égalité (39,3 contre 38,6) ; le surcroît d'écart de touche
  près de la ligne ne suffit pas à faire pencher vers le tir, pour la même raison (une touche perdue coûte peu).
- **Décision « Selon le contexte » :** au but dès que la pénalité est à portée (sauf consigne « conquête » au-delà de
  28 m) ; culture du championnat (touche plus souvent hors Top 14 et PRO D2) ; score et temps pris en compte seulement
  pour l'équipe du manager et l'IA « expert » à partir de la 65e minute (touche si on est mené de plus de 3 points ou
  pour aller chercher le bonus offensif, au but à 3 points près). Raisonnable ; une IA standard qui ne regarde pas le score en fin de match reste une piste
  séparée.

Prochaine étape possible (décision de Léo) : levier 4, le renvoi après des points (repris plus souvent par l'équipe qui
botte, aujourd'hui 6 % seulement) ; c'est lui qui porte l'essentiel de l'écart restant.
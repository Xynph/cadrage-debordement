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
du harnais ; mêmes graines (1 à 6) avant et après. Résultats : voir le tableau ci-dessous.

## Résultats (graines 1 à 6, 3000 matchs par cas, intervalle à 95 %)

| Cas | Pénaltouche avant -> après | Tir au but avant -> après |
| --- | --- | --- |
| Près des poteaux, contre « Selon le contexte » | 53,7 -> 53,1 % (± 1,8) | 50,5 -> 49,5 % (± 1,8) |
| Toutes pénalités | 57,7 -> 53,6 % (± 1,8) | 48,9 -> 48,7 % (± 1,8) |
| Duel direct, près des poteaux | 52,1 -> 53,5 % (± 1,8) | - |
| Duel direct, toutes pénalités | 56,7 -> 55,8 % (± 1,8) | - |
| Bons sauteurs et avants, près (2400) | 60,3 -> 63,9 % (± 1,9) | 56,9 -> 58,9 % (± 2,0) |
| Bon buteur, près (2400) | 51,7 -> 53,1 % (± 2,0) | 51,2 -> 50,4 % (± 2,0) |
| Adversaire bons sauteurs et avants, près (2400) | 44,1 -> 40,8 % (± 2,0) | 42,9 -> 40,3 % (± 2,0) |

Ligue (Top 14, 1200 matchs, IA contre IA), avant -> après : points 54,3 -> 53,2 ; essais 6,75 -> 6,58 par match ;
essais sur ballon porté 10,8 -> 9,4 % ; pénaltouches 7,85 -> 7,86 par match ; essai dans la suite d'une pénaltouche
17,4 -> 16,2 %.

Limite : toutes pénalités, l'avantage de la touche passe de 8,8 à 4,9 points ; près des poteaux il reste ~3,6 points
(53,1 contre 49,5), à peine au-delà du bruit de mesure, à regarder si Léo veut l'égalité stricte.

# Lois manquantes du moteur de match (26/11/2026)

Lot « PR E » de l'audit du 25/11 (anomalies 8 et 11). Code : `dist/restarts.js` (bloc `LOIS`), `dist/rugby.js`
(`awardPenalty`, `CARTONS`), `dist/matchflow.js` (avantage sur passe en avant). Test : `tests/match-lois-completes.cjs`.

## Lois (World Rugby 2025, profil `fr-pro-2025`)

| Phase | Loi | Ce que fait le moteur |
| --- | --- | --- |
| Coup franc | 20 | Faute technique de conquête : mêlée (engagement anticipé, introduction pas droite, talonnage avant l'introduction, mêlée pas formée en 30 s) ou touche (couloir fermé, sauteur soutenu avant le lancer, alignement pas formé en 30 s). Le bénéficiaire joue vite à la main ou tape : dégagement en touche depuis ses 22 (gain de terrain, lancer adverse), jeu au pied depuis son camp ; le choix suit son plan de jeu au pied (`pilotageKick` : consignes « Jouer au pied », relance, rythme, fin de match ; facteur 1 sans pilotage). Aucun coup franc une fois le temps écoulé : la mêlée ou la touche due après la sirène reste la dernière action, disputée. Motif lu dans le nombre de mêlées et touches jouées, jamais dans le journal (courses découpées). Ni tir au but (pas de drop avant ballon mort ou joué par l'adversaire), ni mêlée (loi 20.3 : option réservée à la pénalité ; vérifié sur le texte en ligne le 26/11), ni 50:22. |
| Passe en avant | 11 | 16 % des fautes de main : mêlée adverse, ou « Avantage sur passe en avant » ; la mêlée rendue garde sa cause. |
| Essai de pénalité | 8 | Faute à 7 m au plus de la ligne qui empêche un essai probable : 30 % des fautes de mêlée ou de ballon porté, 8 % des autres. 7 points sans transformation, carton jaune du fautif (rouge s'il était déjà tiré), renvoi par l'équipe qui encaisse. Compte comme un essai (bonus). |
| Drop | 8 | Ouvreur (n° 10, sinon le botteur d'occupation) entre 14 et 35 m, hors avantage : 1,2 % par action, 35 % dès la 72e quand l'équipe est menée de 3 points au plus ou à égalité. Réussite : 60 % à 22 m pour un botteur de 70, −1,2 point par mètre au-delà, pluie et vent. Manqué : même suite qu'un tir manqué (renvoi aux 22 m s'il est mort). |
| Ballon injouable | 16 | 25 % des ballons perdus au contact deviennent un maul arrêté : mêlée pour l'équipe qui n'avait pas le ballon (hors avantage). |
| Cartons | 9 | `CARTONS` (base → branche) : dangereux 0,5 → 0,46, `base` 0,035 → 0,0385, `discipline` 0,0005 → 0, `repetees` 0,17 → 0,02 (rouge inchangé 0,14). Les coups francs, essais de pénalité et ballons injouables ajoutent des phases où l'on siffle ; la discipline des joueurs ne pèse plus sur le carton (0), l'écart se joue sur le plaquage dangereux et la base. |

Les probabilités sont des réglages de simulation calés sur la mesure, pas des valeurs de loi.

## Mesure finale (26/11, 3 championnats × 600 matchs, carrière Monde, même tirage de rencontres, main 1f4ad461e → branche d2755ffe8)

| Par match | Top 14 base → branche | Premiership | URC | Réel élite |
| --- | --- | --- | --- | --- |
| Coups francs | 0 → 3,18 | 0 → 3,25 | 0 → 3,46 | 3-5 |
| Passes en avant | 0 → 2,75 | 0 → 2,77 | 0 → 2,85 | 2-4 |
| Essais de pénalité | 0 → 0,09 | 0 → 0,13 | 0 → 0,12 | 0,07-0,15 |
| Drops tentés (réussis) | 0 → 0,23 (0,07) | 0 → 0,17 (0,05) | 0 → 0,18 (0,06) | ~0,2 |
| Ballons injouables | 0 → 2,30 | 0 → 1,83 | 0 → 2,11 | n.c. |
| Mêlées accordées | 10,15 → 12,12 | 9,44 → 11,31 | 10,08 → 12,27 | 12-15 (Top 14), 10-12 |
| Renvois aux 22 m | 1,16 → 1,30 | 0,86 → 0,99 | 0,97 → 0,98 | 2,5-3,5 (avec la ligne d'essai : + 0,7-0,9) |
| Jaunes | 1,96 → 1,56 | 2,14 → 1,46 | 1,90 → 1,35 | 1,1-1,5 |
| Points | 45,6 → 45,7 | 50,2 → 50,0 | 46,6 → 47,5 | inchangé |
| Essais | 5,15 → 5,17 | 6,66 → 6,62 | 6,08 → 6,17 | inchangé |
| Écart ≤ 7 | 40,8 → 43,2 % | 31,8 → 34,0 % | 36,7 → 32,7 % | bruit ±3 pts |

### Saisons Monde complètes (mesure-essais-monde.cjs, club 102, 1 425 matchs au moteur complet par graine)

Base → branche. Essais et points par match, écart ≤ 7 (%), pénalités sifflées et mêlées par match, hiérarchie (corrélation de Spearman du classement final avec l'ordre réel) :

| Graine | Élite : essais / points / écart ≤ 7 | Prem : essais / points / écart ≤ 7 | URC : essais / points / écart ≤ 7 | Tous : essais / points / écart ≤ 7 | Sifflées (tous) | Mêlées (élite) | Favori gagne (effectif) / surprises |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 4242 | 5,56 → 5,83 / 46,9 → 48,7 / 43,9 → 37,4 | 7,80 → 7,70 / 57,5 → 56,4 / 39,8 → 35,5 | 6,70 → 6,63 / 49,3 → 49,8 / 45,0 → 39,7 | 6,98 → 7,01 / 52,3 → 52,6 / 42,1 → 40,5 | 16,7 → 16,7 | 9,9 → 12,7 | 64,9 → 63,4 % / 141 → 146 |
| 7 | 6,03 → 6,21 / 49,3 → 50,9 / 38,0 → 38,0 | 7,30 → 7,32 / 54,3 → 54,2 / 38,7 → 38,7 | 6,68 → 6,60 / 51,1 → 49,9 / 33,1 → 37,1 | 6,96 → 7,09 / 52,2 → 53,2 / 39,2 → 39,5 | 16,6 → 16,4 | 9,9 → 12,3 | 63,0 → 64,3 % / 156 → 149 |
| 2026 | 5,98 → 5,86 / 50,3 → 48,2 / 35,3 → 40,6 | 7,71 → 7,62 / 57,0 → 56,1 / 41,9 → 41,9 | 6,91 → 6,70 / 51,6 → 49,9 / 33,1 → 37,1 | 7,04 → 7,03 / 53,0 → 52,7 / 39,2 → 39,2 | 16,8 → 16,3 | 10,0 → 12,6 | 65,1 → 65,1 % / 151 → 157 |

Spearman avec l'ordre réel (élite / prem / urc) : 4242 : 0,50 → 0,50 / 0,65 → 0,77 / 0,56 → 0,67 ; 7 : 0,79 → 0,60 / 0,68 → 0,62 / 0,69 → 0,74 ; 2026 : 0,66 → 0,69 / 0,87 → 0,53 / 0,70 → 0,81.
La corrélation ne bouge pas dans un sens commun (saison unique, écarts allant jusqu'à 0,3 entre base et branche sur une même graine) ; essais et points restent à ± 0,2 / ± 1,5 de la base, sans dérive.

### Courbe de niveau (tests/match-rating-curve.cjs, club de base 4, moteur complet)

| | Base (240 matchs/écart, ancien plan) | Branche (600 matchs/écart) |
| --- | --- | --- |
| +6 : victoires du plus fort | 83,3 % | 81,1 % (seuil du test : 75 %) |
| Pente logistique | 0,292 par point | 0,274 par point |
| +10 | 90,6 % | 92,8 % |

À +6 la branche perd environ 2 points et 0,02 de pente par rapport à l'ancien échantillon de 240 matchs (±2,6 points d'échantillon à +6) ; le test passe, avec le plan à 600 matchs par écart.

Scripts : `temp/moteur-match-realisme/lois/mesure.cjs` (`WT=<worktree> node mesure.cjs 600 elite out.json`) et `an.cjs`. Les « mêlées accordées » comptent
les mêlées formées (`setup`), coups francs compris ; `stats.scrums` ne compte que celles disputées.

## Limites

- Rendu : le coup franc, l'essai de pénalité, le drop et le ballon injouable sont des faits `message` du journal
  (bandeau et commentaire) ; le match 2D/3D montre la suite (course, touche, renvoi, carton, mêlée) mais pas de geste
  propre : ni bras plié de l'arbitre, ni arbitre sous les poteaux, ni drop qui passe entre les poteaux.
- Renvois aux 22 m : toujours sous le réel ; leur source principale (coups de pied morts dans l'en-but) appartient au
  jeu au pied (#1307), non retouché ici.
- Pas de marque (loi 17), ni de coup franc dans le jeu courant.

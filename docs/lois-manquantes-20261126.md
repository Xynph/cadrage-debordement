# Lois manquantes du moteur de match (26/11/2026)

Lot « PR E » de l'audit du 25/11 (anomalies 8 et 11). Code : `dist/restarts.js` (bloc `LOIS`), `dist/rugby.js`
(`awardPenalty`, `CARTONS`), `dist/matchflow.js` (avantage sur passe en avant). Test : `tests/match-lois-completes.cjs`.

## Lois (World Rugby 2025, profil `fr-pro-2025`)

| Phase | Loi | Ce que fait le moteur |
| --- | --- | --- |
| Coup franc | 20 | Faute technique de conquête : mêlée (engagement anticipé, introduction pas droite, talonnage avant l'introduction, mêlée pas formée en 30 s) ou touche (couloir fermé, sauteur soutenu avant le lancer, alignement pas formé en 30 s). Le bénéficiaire joue vite à la main ou tape : dégagement en touche depuis ses 22 (gain de terrain, lancer adverse), jeu au pied depuis son camp. Ni tir au but (pas de drop avant ballon mort ou joué par l'adversaire), ni mêlée (loi 20.3 : option réservée à la pénalité ; vérifié sur le texte en ligne le 26/11), ni 50:22. |
| Passe en avant | 11 | 16 % des fautes de main : mêlée adverse, ou « Avantage sur passe en avant » ; la mêlée rendue garde sa cause. |
| Essai de pénalité | 8 | Faute à 7 m au plus de la ligne qui empêche un essai probable : 30 % des fautes de mêlée ou de ballon porté, 8 % des autres. 7 points sans transformation, carton jaune du fautif (rouge s'il était déjà tiré), renvoi par l'équipe qui encaisse. Compte comme un essai (bonus). |
| Drop | 8 | Ouvreur (n° 10, sinon le botteur d'occupation) entre 14 et 35 m, hors avantage : 1,2 % par action, 35 % dès la 72e quand l'équipe est menée de 3 points au plus ou à égalité. Réussite : 60 % à 22 m pour un botteur de 70, −1,2 point par mètre au-delà, pluie et vent. Manqué : même suite qu'un tir manqué (renvoi aux 22 m s'il est mort). |
| Ballon injouable | 16 | 25 % des ballons perdus au contact deviennent un maul arrêté : mêlée pour l'équipe qui n'avait pas le ballon (hors avantage). |
| Cartons | 9 | `CARTONS.base` 0,035 → 0,012, `repetees` 0,17 → 0,06 (plaquage dangereux inchangé). |

Les probabilités sont des réglages de simulation calés sur la mesure, pas des valeurs de loi.

## Mesure (3 championnats × 600 matchs, carrière Monde, même tirage de rencontres)

| Par match | Top 14 avant → après | Premiership | URC | Réel élite |
| --- | --- | --- | --- | --- |
| Coups francs | 0 → 3,21 | 0 → 3,27 | 0 → 3,36 | 3-5 |
| Passes en avant | 0 → 2,85 | 0 → 2,65 | 0 → 2,90 | 2-4 |
| Essais de pénalité | 0 → 0,10 | 0 → 0,12 | 0 → 0,11 | 0,07-0,15 |
| Drops tentés (réussis) | 0 → 0,22 (0,09) | 0 → 0,17 (0,06) | 0 → 0,19 (0,06) | ~0,2 |
| Mêlées accordées | 10,15 → 12,33 | 9,44 → 11,11 | 10,08 → 12,26 | 12-15 (Top 14), 10-12 |
| Renvois aux 22 m | 1,16 → 1,27 | 0,86 → 0,97 | 0,97 → 1,03 | 2,5-3,5 (avec la ligne d'essai : + 0,7-0,9) |
| Jaunes | 1,96 → 1,24 | 2,14 → 1,31 | 1,90 → 1,22 | 1,1-1,5 |
| Points | 45,6 → 45,6 | 50,2 → 50,0 | 46,6 → 46,9 | inchangé |
| Essais | 5,15 → 5,14 | 6,66 → 6,63 | 6,08 → 6,08 | inchangé |
| Écart ≤ 7 | 40,8 → 42,0 % | 31,8 → 35,2 % | 36,7 → 32,2 % | bruit ±3 pts |

Scripts : `temp/moteur-match-realisme/lois/mesure.cjs` (`WT=<worktree> node mesure.cjs 600 elite out.json`) et `an.cjs`. Les « mêlées accordées » comptent
les mêlées formées (`setup`), coups francs compris ; `stats.scrums` ne compte que celles disputées.

## Limites

- Rendu : le coup franc, l'essai de pénalité, le drop et le ballon injouable sont des faits `message` du journal
  (bandeau et commentaire) ; le match 2D/3D montre la suite (course, touche, renvoi, carton, mêlée) mais pas de geste
  propre : ni bras plié de l'arbitre, ni arbitre sous les poteaux, ni drop qui passe entre les poteaux.
- Renvois aux 22 m : toujours sous le réel ; leur source principale (coups de pied morts dans l'en-but) appartient au
  jeu au pied (#1307), non retouché ici.
- Pas de marque (loi 17), ni de coup franc dans le jeu courant.

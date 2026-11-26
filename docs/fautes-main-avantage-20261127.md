# Fautes de main et avantage (27/11/2026)

Reste de la liste d'anomalies du moteur de match (audit du 25/11 : lignes 2, 8, 9, 10). Test :
`tests/match-fautes-main-avantage.cjs` (300 matchs de championnat, Top 14 / Premiership / URC, graines fixes).

## Audit de main (0fea57e87), 450 matchs (150 par championnat, carrière Monde, vrai moteur)

| Par match | Top 14 | Premiership | URC | Réel élite | Verdict |
| --- | --- | --- | --- | --- | --- |
| En-avants racontés | 14,6 | 14,2 | 15,0 | 10-20 (fautes de main) | bon |
| Passes en avant | 2,7 | 2,8 | 2,8 | 2-4 | bon |
| Avantages sur faute de main / sur pénalité | 7,5 / 7,8 | 7,3 / 7,5 | 7,7 / 7,3 | | bon |
| Avantage obtenu (dont points) | 3,2 (0,9) | 3,5 (1,3) | 3,3 (0,9) | | bon |
| Avantage sans faute racontée juste avant | 0 | 0 | 0 | 0 | réglé par #1308 |
| Retour à la mêlée / pénalité joué par l'équipe annoncée | 100 % | 100 % | 100 % | loi 7 | bon |
| Mêlées formées | 12,3 | 11,5 | 12,3 | 12-15 (Top 14), 10-12 | bon |
| Coups francs | 3,0 | 3,0 | 3,0 | 3-5 | bon (bas de fourchette) |
| Renvois aux 22 m / sur la ligne d'essai | 1,19 / 0,66 | 1,01 / 0,97 | 1,08 / 0,85 | voir plus bas | laissé |
| Jaunes | 1,43 | 1,45 | 1,33 | 1,1-1,5 | bon |
| Renvoi repris par l'équipe qui botte, dit « renvoi court » | 135/135 | 151/151 | 151/151 | | réglé par #1308 |
| Deux récupérations de suite à la même minute | 37 | 19 | 32 | | **récit à reprendre** |

## Corrigé

Deux récupérations de suite à la même minute (≈ 0,2 par match, 2 % des récupérations) : le journal enchaînait
« A est arrêté net : B récupère » puis aussitôt « B est arrêté net : A récupère », comme deux récupérations sorties
de nulle part. La seconde raconte maintenant la relance perdue : « Ballon aussitôt rendu : X relance tout de suite mais
est arrêté net : Y récupère le ballon après le plaquage pour … ». Lecture du journal seule (`recupereALinstant`,
`dist/restarts.js`), aucun tirage : scores, essais, matchs serrés et toutes les mesures de calage sont identiques à main.

Test sur main : 70/70 secondes récupérations sans relance racontée (rouge) ; branche : vert.

## Laissé tel quel (décision)

- Renvois aux 22 m (≈ 1,1 par match, l'anomalie du 25/11 visait ≈ 3) : depuis la loi de 2022, le ballon tenu dans
  l'en-but, l'en-avant de l'attaque dans l'en-but et le coup de pied aplati par la défense donnent un renvoi sur la ligne
  d'essai (0,7-1,0 par match ici), plus aux 22 m. Le total (≈ 1,9-2,0) est plausible, et monter les 22 m demanderait
  plus de coups de pied dans l'en-but, donc toucher le jeu au pied (#1307) et le calage. Aucun chiffre réel récent
  trouvé pour trancher ; le test garde un plancher (22 m ≥ 0,7, 22 m + ligne ≥ 1,4).
- En-avants, passes en avant, mêlées, coups francs, avantages, jaunes : dans les fourchettes, verrouillés par le test.

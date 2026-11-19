# Chrono des arrêts de jeu (18/11/2026)

Carrière Monde uniquement. Rencontres créées avec `chronoVersion: 1` ; les matchs commencés avant gardent leurs règles.

## Constat

Dans le moteur complet, une action de jeu valait une minute de chrono quoi qu'il arrive. Une pénalité tentée au but
et un essai transformé ne consommaient qu'une minute avant l'action suivante (mesure de référence : 1 min 00 dans les
deux cas sur 600 matchs de Top 14). Mené de 8 en fin de match, prendre les trois points ne mangeait donc pas de temps à
l'adversaire, qui remarquait le plus souvent : taper au but ne valait pas mieux que la pénaltouche (bonus défensif
0,30 contre 0,32 à la 72e, 0,34 contre 0,31 à la 60e).

## Durées retenues (vérifiées le 18/11/2026, voir `docs/rugby-rules-reference.md`)

| Arrêt | Loi / règlement | Temps compté par le moteur |
| --- | --- | --- |
| Pénalité tentée au but | Loi 8.21 : 60 s ; Top 14 2026-2027 : 45 s | 10 s (annonce, ballon posé) + délai + 25 s (renvoi ou remise en jeu) : 80 s en Top 14, 95 s ailleurs |
| Essai et transformation | Loi 8.8c : 60 s (90 s jusqu'en 2024) ; Top 14 : 45 s | 15 s (essai accordé, buteur en place) + délai + 25 s (renvoi) : 85 s en Top 14, 100 s ailleurs |
| Pénaltouche | Loi 18.12 : alignement en 30 s | 30 s (coup de pied en touche, alignement formé) |
| Action de jeu | — | 45 s de match en Top 14, 43 s ailleurs (calées : même nombre d'actions par match qu'avant) |

Les chiffres de la demande (60 s et 90 s, soit ≈ 2 min et 2 min 30) datent de 2023 : la transformation est passée à
60 s en 2025 et la LNR impose 45 s en Top 14 dès 2026-2027, la saison de la carrière. Pro D2 n'est pas vérifié et reste
à 60 s. Les mêlées et touches ordinaires restent comprises dans la durée moyenne d'une action.

## Fonctionnement

- Le chrono compte en secondes : chaque action dure `CHRONO.action` (45 s en Top 14, 43 s ailleurs) et les arrêts y ajoutent leur temps
  (`CHRONO` dans `dist/matchflow.js`). Une minute de match compte zéro, une ou deux actions ; l'horloge affichée
  avance toujours d'une minute par minute (écran 2D et résultat inchangés dans leur forme).
- Le renvoi après des points (et le renvoi aux 22 après un tir manqué mort) se joue au début de l'action suivante, au
  moment dû. S'il tombe après la fin du temps réglementaire, la période se termine (loi 5) : une pénalité réussie à
  la 79e ne laisse plus de renvoi.
- Le staff (consigne « auto » du club du manager, IA experte) prend les trois points à partir de la 72e quand
  l'équipe est menée d'un peu plus que l'écart du bonus défensif (Top 14 : −6 à −8).
- Aucun tirage ajouté ; la séquence des tirages d'une action est celle d'avant.
- Statistiques : possession et territoire comptés par action (les pourcentages ne changent pas de sens) ; l'usage
  des plans (`planUsage.minutes`) compte les actions observées.

## Mesures

`node scripts/mesure-chrono-arrets.cjs` (en ligne : `bash ci/en-ligne.sh --ref <ref> --suites mesure-chrono-arrets`),
600 matchs de Top 14 (vrais effectifs), 4 × 200 matchs de styles (XV identiques), 2 × 150 matchs de courbe de niveau,
400 fins de match par consigne ; `bash ci/mesure-monde.sh` (10 saisons Monde, 14 250 matchs).

### Top 14, 600 matchs (vrais effectifs, IA contre IA ; mêmes affiches avant et après)

| | Avant | Après |
| --- | --- | --- |
| Points / essais par match | 53,6 / 6,45 | 54,3 / 6,55 |
| Pénalités tentées / réussies | 4,77 / 3,73 | 4,67 / 3,65 |
| Fautes sifflées, jaunes, rouges | 17,0 · 2,36 · 0,44 | 16,6 · 2,33 · 0,46 |
| Actions de jeu par match | 82,8 | 83,4 |
| Durée (minutes jouées, 1re période) | 81,2 (41,7) | 80,7 (41,0) |
| De l'action qui marque à l'action suivante : pénalité réussie / essai | 1 min 00 / 1 min 00 | 2 min 04 / 2 min 10 |
| Arrêts comptés par match (essais, pénalités tentées, pénaltouches) | — | 9,3 + 6,2 + 4,0 min |
| Victoires à domicile | 72,0 % | 76,2 % (écart dans le bruit : ≈ 1,7 écart type) |

### Styles contre « Équilibré » (XV identiques, consignes figées, 200 matchs chacun)

| Style | Avant | Après |
| --- | --- | --- |
| Équilibré | 49,8 % | 50,2 % |
| Large | 47,5 % | 46,5 % |
| Près (conquête) | 57,5 % | 53,3 % |
| Occupation | 47,3 % | 44,8 % |

Écarts dans le bruit (≈ 3,5 points d'écart type) ; le jeu au près, déjà au-dessus avant, s'en rapproche. Rien à recaler.

### Courbe de niveau (moteur complet, 150 matchs par écart)

| Écart | Plus fort gagnant avant | après | Domicile à niveau égal avant | après |
| --- | --- | --- | --- | --- |
| 0 | 51,0 % | 52,3 % | 65,3 % | 66,7 % |
| +15 | 92,0 % | 92,3 % | — | — |

Surprises à 15 points : 8,0 % → 7,7 % (à l'extérieur du plus fort : 14,7 % → 12,7 %).

### Dix saisons Monde (14 250 matchs)

Points et essais par match : 55,7 / 7,10 → 55,9 / 7,17. Favori gagnant (toutes tranches) : 64,9 % → 65,1 % en moyenne,
par tranche d'écart 50,1 → 50,8 (0-1), 62,2 → 63,0 (2-3), 77,5 → 77,7 (5 et plus). Avec une action unique à 45 s
partout, les championnats à 60 s perdaient 1 à 4 points par match (essais plus nombreux, arrêts plus longs) : d'où 43 s
hors Top 14.

### Mené de 8 (XV identiques, 400 fins de match par consigne)

| Situation | Consigne | Bonus défensif avant | après | Victoires après | Points de classement après |
| --- | --- | --- | --- | --- | --- |
| 72e, 21-29 | Pénalités tentées (« Aller chercher le bonus défensif ») | 0,30* | **0,49** | 0,11 | 0,95 |
| 72e, 21-29 | Pénaltouche (« Tout pour la victoire ») | 0,32* | 0,42 | 0,17 | 1,11 |
| 60e, 21-29 | Pénalités tentées | 0,34 | 0,33 | 0,27 | 1,44 |
| 60e, 21-29 | Pénaltouche | 0,31 | 0,30 | 0,32 | 1,58 |

\* avant, à la 72e : 200 fins de match (mesure locale). À la 72e, prendre les points donne désormais nettement plus
souvent le bonus défensif (essais encaissés 0,31 → 0,16 : l'adversaire n'a plus le temps), la pénaltouche garde plus de
victoires : un vrai choix. À la 60e, il reste trop de temps pour que les trois points pèsent : normal.

### Remesure après fusion (19/11, 1 200 matchs, `tests/mesure-chrono-1200.cjs`, run 44488746565)

Sur `main` après #925 et #937 (contre recalé à .03/5 m), XV identiques.

| Mesure | Avant le chrono (#925) | Après |
| --- | --- | --- |
| Jeu au large contre « Équilibré », victoires (1 200 matchs) | 49,4 % | 47,8 % (écart type ≈ 1,4 point : dans le bruit) |

Mené de 8 à la 72e, 1 200 fins de match par consigne :

| Consigne | Victoires | Bonus défensif | Points de classement | Essais encaissés |
| --- | --- | --- | --- | --- |
| Staff (« auto ») | 0,06 | 0,39 | 0,62 | 0,26 |
| Pénalités tentées (« Aller chercher le bonus défensif ») | 0,05 | **0,44** | **0,66** | 0,23 |
| Pénaltouche (« Tout pour la victoire ») | 0,04 | 0,36 | 0,51 | 0,23 |

Garde-fous : `match-rating-curve` et `fatigue-phases-arretees` verts, seuils inchangés.

Constat : taper au but rapporte désormais nettement plus de bonus défensif (0,44 contre 0,30 avant le chrono), et la
pénaltouche ne gagne pas davantage de matchs à −8 (0,04 contre 0,05). C'est conforme au rugby réel : à −8, il faut deux
scores pour gagner quelle que soit l'option, prendre les points est le choix courant.

### Le dilemme là où il existe (19/11, `tests/mesure-bonus-1200.cjs`, run 44494782700, 1 200 rejeux par consigne, 72e)

| Situation | Pénaltouche (« Tout pour la victoire ») V / BD / pts | Points (« défensif » ou « garder ») V / BD / pts |
| --- | --- | --- |
| −8 | 0,04 / 0,36 / 0,51 | 0,05 / **0,44** / **0,66** |
| −6 (un essai transformé gagne) | **0,33** / 0,10 / **1,43** | 0,23 / 0,25 / 1,20 |
| −4 (bonus en poche) | **0,37** / 0,40 / **1,98** | 0,26 / **0,53** / 1,66 |

À −6 et −4, la pénaltouche gagne nettement plus (+10 et +11 points de victoires) au prix du bonus défensif : vrai choix.
À −8, les points dominent : réaliste, aucun recalage du moteur.

## Limites

- Le moteur ne distingue pas ballon vivant et ballon mort à l'intérieur d'une action : le temps de jeu effectif réel
  (≈ 33,6 min en Top 14) n'est pas reproduit, seuls les arrêts qui comptent pour les décisions sont explicites.
- Mêlées et touches ordinaires, soins, arbitrage vidéo : compris dans la durée moyenne d'une action.
- Pro D2 : délai de 45 s non vérifié, gardé à 60 s.

# Résultats des matchs calés sur la réalité (25 novembre 2026)

Demande de Léo (25/11) : « je veux que le pourcentage de gain de match soit similaire avec la réalité ».
Branche `claude/match-niveau-role` : le Niveau au rôle joue dans le match (voir `docs/notation-fm-20261124.md`),
puis l'avantage du terrain et le poids de l'écart de niveau sont réglés championnat par championnat.

## Chiffres réels

Saisons régulières comptées (aucune donnée envoyée, seulement des pages de résultats lues) : Top 14, Premiership,
URC et Super Rugby Pacific (résultats ESPN, 2022-23 à 2025-26 ; Super Rugby 2023 à 2026 ; quelques matchs absents
de la source), Pro D2 et Japan Rugby League One D1 (Wikipédia, 4 saisons complètes, recoupées avec les classements ;
6 scores du Japon 2023-24 déduits des totaux du classement). Agrégats sans noms d'équipes :
`tests/fixtures/realite-matchs-20261125.json`. Bonus calculés selon la règle du championnat (Top 14, Pro D2 et
Japon : 3 essais de plus ; ailleurs 4 essais ; défensif à 5 points en France, 7 ailleurs) ; Japon : essais et bonus
offensifs tirés des totaux des classements.

« Hiérarchie » : écart-type des % de victoires des clubs sur la saison, part du hasard retirée (bruit binomial du
nombre de matchs) : petit = championnat serré. « Domicile à niveau égal » : ajustement logistique du résultat sur la
différence de bilan de saison des deux clubs (le match lui-même retiré), constante = victoire à domicile à bilan égal.

## Réel / moteur

Moteur : carrière Monde (club 102), une saison complète par graine, tous championnats au moteur complet.
« Avant » = branche avant calage (3 graines : 4242, 7, 2026) ; « après » = réglages de cette note (6 graines :
4242, 7, 2026, 11, 99, 31). Hiérarchie et favori : ± 2 points d'échantillonnage environ.

| Championnat | Victoires à domicile (réel / avant / après) | Nuls | Hiérarchie | Favori gagne (bilan ≥ 15 pts d'écart) | Favori gagne (≥ 35 pts) |
| --- | --- | --- | --- | --- | --- |
| Top 14 | 76 / 74 / 77 % | 2,2 / 1,8 / 1,9 % | 8 / 9 / 6 | 57 / 61 / 56 % | 87 / 57 / 63 % |
| Pro D2 | 74 / 70 / 74 % | 2,4 / 1,9 / 1,4 % | 9 / 12 / 10 | 61 / 69 / 66 % | 72 / 76 / 65 % |
| Premiership | 64 / 63 / 64 % | 0,8 / 2,2 / 2,4 % | 15 / 14 / 13 | 68 / 67 / 65 % | 80 / 80 / 72 % |
| URC | 63 / 57 / 63 % | 2,8 / 3,0 / 2,1 % | 17 / 12 / 18 | 73 / 63 / 78 % | 82 / 70 / 81 % |
| Super Rugby | 63 / 57 / 65 % | 0,3 / 0,4 / 0,4 % | 18 / 12 / 13 (17 au réglage C) | 73 / 63 / 67 % | 81 / 71 / 70 % |
| Japon D1 | 50 / 60 / 51 % | 2,5 / 1,2 / 1,7 % | 23 / 20 / 20 | 85 / 78 / 80 % | 93 / 85 / 86 % |

Le Top 14 « ≥ 35 pts » ne compte que 21 matchs réels. Résultat rapide (championnats suivis de loin, 3 graines) :
victoires à domicile 74 / 72 / 66 / 63 / 65 / 46 % (même ordre), hiérarchie 7 / 6 / 13 / 14 / 15 / 21.

Scores (réel / après) — **pas recalés ici**, à reprendre dans un chantier « essais réalistes » :

| Championnat | Points / match | Essais / match | Écart moyen | Écart ≤ 7 | Bonus offensif (par équipe) | Bonus défensif (par match) |
| --- | --- | --- | --- | --- | --- | --- |
| Top 14 | 51,0 / 54,3 | 5,2 / 6,8 | 14,3 / 15,6 | 40 / 32 % | 15 / 21 % | 32 / 21 % |
| Pro D2 | 48,0 / 48,8 | 5,5 / 6,2 | 13,8 / 14,1 | 42 / 34 % | 17 / 19 % | 32 / 24 % |
| Premiership | 54,9 / 64,4 | 7,1 / 8,9 | 16,1 / 16,4 | 36 / 30 % | 44 / 67 % | 35 / 28 % |
| URC | 49,4 / 54,4 | 6,3 / 7,3 | 14,2 / 16,9 | 41 / 29 % | 35 / 50 % | 38 / 27 % |
| Super Rugby | 56,9 / 65,3 | 7,8 / 9,1 | 16,1 / 16,5 | 35 / 31 % | 52 / 70 % | 35 / 31 % |
| Japon D1 | 60,8 / 64,0 | 8,5 / 9,0 | 18,1 / 18,4 | 30 / 28 % | 24 / 25 % | 28 / 26 % |

Le moteur marque environ un essai de trop par match (Premiership, URC, Super Rugby : bonus offensifs trop
fréquents) et laisse trop peu de matchs serrés (bonus défensifs rares).

## Réglages (dist/rugby.js, native/engine/league-detail.cjs)

- `TERRAIN_CHAMPIONNAT` : Top 14 ×2,2 (2,1), Pro D2 ×2,1 (1,7), Premiership ×1,45, URC ×1,3, Super Rugby ×1,5,
  Japon D1 ×0,1 (stades partagés : presque pas d'avantage du terrain), autres ×1.
- `ECART_CHAMPIONNAT` : `facteur` multiplie l'écart de niveau au moteur complet, `rapide` au résultat rapide (avant
  la compression du Top 14, inchangée). Le moteur complet ne laisse régler qu'une partie de la pente (les duels de
  qualités départagent déjà ; banc : pente ≈ 0,14 + 0,07 × facteur), d'où des facteurs plus forts qu'au rapide :
  Pro D2 0,55 / 0,84, Premiership 1,3 / 1,19, URC 2,3 / 1,4, Super Rugby 3,5 / 1,89, Japon 2,3 / 1,46.
  Les clubs de Super Rugby sont très proches en note dans la base du monde alors que le vrai championnat est très
  étagé : le facteur compense.
- Résultat rapide du Top 14 : poids du terrain 0,63 → 0,8 (78 % à niveau égal contre 82 % au complet, réel 79 %), poids de l’écart 1 → 1,2 (même victoire à +6 que le complet).
- Après la 1re vérification (25/11) : URC 2,6 → 2,3 au complet (1,52 → 1,4 au rapide), tests resserrés (240 matchs complets, réel ± 7 points, pente ± 0,06). Leader de l’URC sur 6 saisons : 91 % de victoires (réel 83 %), même valeur aux deux réglages : il vient de l’effectif du club de tête de la base, pas de la courbe ; hiérarchie URC 16 (réel 16,5).

Banc (tests/helpers/courbe-niveau.cjs, deux copies du club 4, 400 matchs complets et 2 000 rapides par écart 0/+6),
pente par point complet / rapide et domicile à niveau égal complet / rapide :

| Championnat | Pente | Domicile (réel) |
| --- | --- | --- |
| Top 14 | 0,19 / 0,16 | 82 / 78 % (79 %) |
| Pro D2 | 0,17 / 0,16 | 78 / 75 % (78 %) |
| Premiership | 0,24 / 0,23 | 75 / 73 % (69 %) |
| URC | 0,32 / 0,33 | 73 / 71 % (70 %) |
| Super Rugby | 0,42 / 0,44 | 75 / 71 % (69 %) |
| Japon D1 | 0,33 / 0,28 | 50 / 51 % (52 %) |

## Tests

- `tests/match-rating-curve.cjs` : le banc joue en URC ; bornes = URC réelle (domicile à niveau égal 70 % ± 7,
  pente 0,24-0,40, +6 entre 75 et 92 %, +10 entre 86 et 99 %, −10 entre 2 et 15 %, surprises à +15 entre 0,3 et 8 %, le plus fort de 6 points perd au moins 15 % de ses déplacements).
  Mesuré (CI) : complet pente 0,334, domicile 71,7 %, +6 84 % ; rapide 0,332, 70,1 %, +6 85 %.
- `tests/match-realite-championnats.cjs` (nouveau, ~5 min 30, 240 matchs complets et 1 000 rapides par écart) : pour chacun des 6 championnats, domicile à niveau
  égal du banc = réel ± 7 points, pente = visée ± 0,06 (plus une erreur type), moteurs complet et rapide d’accord à +6 (± 6 points). Vu rouge avec les réglages de main (Super Rugby rapide : pente 0,21 pour 0,40).

Outils de mesure (hors dépôt, dossier temp/realite-match) : relevé des matchs réels, saison Monde complète par graine
(`scripts/mesure-essais-monde.cjs`, fonction `mesurer`), analyses identiques pour le réel et le moteur.

## Scores calés sur la réalité (25/11, 2e étape, branche `claude/scores-realistes`)

Le moteur marquait environ un essai de trop. Réglages : ouverture du jeu au moteur complet (`OUVERTURE_CHAMPIONNATS`,
dist/tactical-plans.js) Top 14 0 → −0,045, Pro D2 −0,03 → −0,045, URC 0,025 → −0,025, Premiership 0,11 → 0,03,
Super Rugby 0,115 → 0,035, Japon D1 0,125 → 0,095 ; volume d'essais du résultat rapide (`VOLUME`, league-detail.cjs)
Top 14 1,09 → 1,02, Premiership 1,53 → 1,32, URC 1,22 → 1,08, Super Rugby 1,57 → 1,34 ; poids de l'écart du résultat
rapide en Premiership 1,19 → 1,35 (moins d'essais = moins de hiérarchie, ramenée à celle du complet).

Saisons Monde (6 graines au moteur complet), réel / avant / après :

| Championnat | Points / match | Essais / match | Écart ≤ 7 | Bonus offensif | Bonus défensif | Hiérarchie |
| --- | --- | --- | --- | --- | --- | --- |
| Top 14 | 51,0 / 54,3 / 49,9 | 5,2-5,9 / 6,8 / 6,1 | 40 / 32 / 35 % | 15 / 21 / 17 % | 32 / 21 / 24 % | 8 / 6 / 9 |
| Pro D2 | 48,0 / 48,8 / 46,9 | 5,5 / 6,2 / 5,9 | 42 / 34 / 36 % | 17 / 19 / 16 % | 32 / 24 / 25 % | 9 / 10 / 8 |
| Premiership | 54,9 / 64,4 / 56,1 | 7,1-8,0 / 8,9 / 7,6 | 36 / 30 / 28 % | 44-59 / 67 / 53 % | 35 / 28 / 26 % | 15 / 13 / 13 |
| URC | 49,4 / 54,4 / 49,9 | 6,3-6,6 / 7,3 / 6,6 | 41 / 29 / 30 % | 35-42 / 50 / 43 % | 38 / 27 / 28 % | 17 / 18 / 17 |
| Super Rugby | 56,9 / 65,3 / 56,1 | 7,8-8,3 / 9,1 / 7,7 | 35 / 31 / 33 % | 52 / 70 / 56 % | 35 / 31 / 32 % | 18 / 13 / 14 |
| Japon D1 | 60,8 / 64,0 / 60,3 | 8,5 / 9,0 / 8,5 | 30 / 28 / 26 % | 24 / 25 / 27 % | 28 / 26 / 26 % | 23 / 20 / 21 |

Essais réels : moyenne des saisons comptées et saison 2024-25 (docs/essais-realistes-20261114.md). Résultat rapide
(2 graines) : points 50,5 / 49,0 / 55,9 / 47,9 / 54,9 / 61,9, essais 6,0 / 5,9 / 7,7 / 6,3 / 7,7 / 8,5.
Vérificateur (graine neuve 3003, complet et rapide) : points à moins de 3 du réel partout.

Restes :
- Essais du Top 14 encore hauts (6,0-6,1 contre 5,2 sur 2022-24 et 5,9 en 2024-25), Pro D2 et URC +0,4 : à points
  égaux, un peu trop d'essais et pas assez de pénalités.
- Matchs serrés : écart ≤ 7 et bonus défensif 5 à 11 points sous le réel au moteur complet, jusqu'à 13-14 points au
  résultat rapide (Top 14 : 27,5 % d'écarts ≤ 7 contre 40 %, 17,6 % de bonus défensifs contre 31,7 %). L'écart moyen
  est juste : le moteur laisse moins de fins de match à un score (gestion du score, pénalités de fin de match), et le
  résultat rapide tire les essais des deux camps indépendamment.
- Hiérarchie du Super Rugby un peu basse (14 contre 18).

## Fins de match serrées (25/11, 3e étape, branche `claude/fins-serrees`)

Le moteur laissait trop peu de matchs à un score d'écart (écart ≤ 7 et bonus défensif 5 à 14 points sous le réel).
Nouveau terme de « gestion du score » (`GESTION_SCORE`, `gestionScore` de dist/rugby.js, matchs de compétition Monde) :
à partir de la 60e minute, effet croissant jusqu'à la 80e, l'équipe qui mène de 8 points ou plus gère (attaque −0,15 ×
part de l'écart au-delà de 7, plein à 21) et l'équipe menée de 4 à 15 points pousse (attaque +0,3). Résultat rapide
(`FIN_MATCH_RAPIDE`, league-detail.cjs) : l'équipe menée de 8 à 21 points marque un essai de fin de match une fois sur
deux, sinon, menée de 6 à 12, une pénalité une fois sur deux (jamais de quoi passer devant : favoris inchangés).
Volume d'essais légèrement baissé pour compenser (ouverture −0,01 partout, `VOLUME` −5 %). Super Rugby plus étagé
(facteur 3,5 → 4,2 au complet, 1,89 → 2,4 au rapide ; hiérarchie mesurée 13 à 15 contre 18 au réel).

Saisons Monde (6 graines au complet, réglage final sauf Super Rugby ; 3 graines au rapide pour la fin de match rapide),
réel / avant / après :

| Championnat | Écart ≤ 7 | Bonus défensif | Écart ≥ 21 | Nuls | Points | Hiérarchie |
| --- | --- | --- | --- | --- | --- | --- |
| Top 14 | 40 / 35 / 39 % | 32 / 24 / 28 % | 26 / 26 / 23 % | 2,2 / 2,2 / 2,7 % | 51 / 50 / 49 | 8 / 9 / 8 |
| Pro D2 | 42 / 36 / 45 % | 32 / 25 / 31 % | 25 / 23 / 19 % | 2,4 / 1,9 / 2,3 % | 48 / 47 / 47 | 9 / 8 / 8 |
| Premiership | 36 / 28 / 34 % | 35 / 26 / 32 % | 29 / 30 / 30 % | 0,8 / 1,9 / 2,4 % | 55 / 56 / 55 | 15 / 13 / 15 |
| URC | 41 / 30 / 37 % | 38 / 28 / 35 % | 28 / 34 / 29 % | 2,8 / 2,1 / 2,5 % | 49 / 50 / 50 | 17 / 17 / 16 |
| Super Rugby | 35 / 33 / 39 % | 35 / 32 / 39 % | 31 / 29 / 25 % | 0,3 / 1,3 / 0,2 % | 57 / 56 / 56 | 18 / 14 / 13 |
| Japon D1 | 30 / 26 / 32 % | 28 / 26 / 29 % | 36 / 40 / 37 % | 2,5 / 0,5 / 2,8 % | 61 / 60 / 60 | 23 / 20 / 22 |

Résultat rapide, après dosage par championnat ( : Pro D2 0,62, Premiership 0,7, Super
Rugby 0,4, Japon 0,3 ; 2 graines) : écart ≤ 7 43 / 41 / 38 / 45 / 35 / 29 % (réel 40 / 42 / 36 / 41 / 35 / 30), bonus
défensif 32 / 29 / 36 / 42 / 35 / 27 % (réel 32 / 32 / 35 / 38 / 35 / 28), points 50 / 48 / 54 / 48 / 53 / 60 (Top 14 avant :
27,5 % d'écarts ≤ 7 et 17,6 % de bonus défensifs). Vérificateur (graines neuves 8128 et 9317) : complet conforme ; un club
qui mène de 8 à 15 points à la 60e gagne 88 % du temps (100 % sans la gestion du score), à 16 points ou plus il ne perd
jamais. Sondes au banc (300 à 400 matchs, URC et
Top 14) : la réussite des favoris ne bouge pas (+6 : 85-86 % URC, 66-67 % Top 14).

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
  Pro D2 0,55 / 0,84, Premiership 1,3 / 1,19, URC 2,6 / 1,52, Super Rugby 3,5 / 1,89, Japon 2,3 / 1,46.
  Les clubs de Super Rugby sont très proches en note dans la base du monde alors que le vrai championnat est très
  étagé : le facteur compense.
- Résultat rapide du Top 14 : poids du terrain 0,63 → 0,8 (78 % à niveau égal contre 82 % au complet, réel 79 %).

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
  pente 0,24-0,40, +6 entre 75 et 92 %, +10 entre 86 et 99 %, −10 entre 2 et 15 %, surprises à +15 entre 0,3 et 8 %).
  Mesuré (CI) : complet pente 0,334, domicile 71,7 %, +6 84 % ; rapide 0,332, 70,1 %, +6 85 %.
- `tests/match-realite-championnats.cjs` (nouveau, ~2 min 40) : pour chacun des 6 championnats, domicile à niveau
  égal du banc = réel ± 7 points, pente = visée ± 0,07, moteurs complet et rapide d'accord.

Outils de mesure (hors dépôt, dossier temp/realite-match) : relevé des matchs réels, saison Monde complète par graine
(`scripts/mesure-essais-monde.cjs`, fonction `mesurer`), analyses identiques pour le réel et le moteur.

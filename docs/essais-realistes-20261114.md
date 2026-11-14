# Essais réalistes du moteur de match (14 novembre 2026)

Problème validé par Léo : le moteur de match (carrière Monde, matchs au moteur complet) marque trop
peu d'essais ; un ailier titulaire marque ~0,15 essai par match (cible réelle ~0,3 à 0,5).
Carrière Monde uniquement (world-champ, 116 clubs, tous les championnats détaillés).

## 1. Mesure

`scripts/mesure-essais-monde.cjs` joue une saison complète (46 semaines, ~1 425 matchs au moteur
complet) et lit chaque match par des crochets en lecture seule (aucun tirage, aucun état modifié) :
essais et points par match (deux équipes), part des points, écart, bonus offensifs, marqueurs par
maillot, entrées dans les 22, choix sur pénalité, réussite au but, ballons perdus, hiérarchie.
`--ancien` rejoue les coefficients d'avant (`ESSAIS_RULES=0`) sur la même graine ;
`--analyser fichier.json` relit une mesure enregistrée.

### Réalité récente (saison régulière 2024-25 ; sources en fin de document)

| Championnat (id du jeu) | Essais / match | Points / match | Part des points sur essais | Bonus offensif |
|---|---|---|---|---|
| Top 14 (`elite`) | 5,90 (1 073 / 182) | 51,1 | 58 % | 14,8 % des feuilles (règle +3 essais) |
| Pro D2 (`accession`) | ~5,2 (phase aller) | 50,9 | — | 81 bonus / 480 feuilles |
| Nationale (`nationale`) | pas de source chiffrée ; cible plausible 5 à 6 (troisième division, jeu fermé) | ~45 | — | — |
| Premiership (`prem`) | 7,96 (716 / 90) | 56,3 | 71 % | 59 % (4 essais) |
| URC (`urc`) | 6,63 (954 / 144) | 48,3 | 69 % | 42 % (4 essais) |
| RFU Championship (`champ`) | 8,6 (1 137 / 132) | 59,0 | — | 153 bonus / 264 feuilles |
| Super Rugby Pacific 2025 (`srp`) | 8,27 (637 / 77) | 57,8 | — | — |
| Japan League One D1 (`jlo-d1`) | 8,6 (930 / 108) | 61,7 | — | — |
| Japan League One D2 (`jlo-d2`) | pas de source ; cible plausible proche de la D1 (7 à 9) | — | — | — |

Réussite au but en élite : ~75 % des pénalités et ~70-75 % des transformations (ordre de grandeur
des compilations de buteurs). Marqueurs : au plus haut niveau les arrières marquent environ deux
essais sur trois, l'ailier est le poste le plus prolifique, puis arrière et centres ; le numéro 8
est l'avant le plus prolifique, le talonneur dépasse piliers, deuxième ligne et troisième ligne aile
(ballon porté) ; piliers et deuxième ligne sont les plus rares (Frame Sports, 13 000 essais) — en
Top 14 2024-25, trois talonneurs figurent parmi les 13 meilleurs marqueurs.

### Avant (deux saisons, graines 4242 et 7, club 102)

Le moteur donnait **le même match partout** : ~4,0 essais et ~31 points par match dans tous les
championnats (Top 14 comme Japon), 54 % de réussite au but, 12 % des équipes sans essai, un ailier
titulaire à 0,15 essai par match, et des marqueurs uniformes entre troisième ligne et arrières.

| Championnat | Matchs | Essais / match | Points / match | Part essais / transfo / pénalités (%) | Écart moyen | Sans essai (%) | Bonus 4 essais (%) | Bonus +3 essais (%) | Entrées 22 / essais par entrée | Réussite pénalités / transfo (%) | Ballons perdus |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Pro D2 | 490 | 4,02 | 30,7 | 65,5 / 14,8 / 19,7 | 8,6 | 8,9 | 12,1 | 7,7 | 4,4 / 0,9 | 52,4 / 56,6 | 19,6 |
| Nationale | 374 | 4,07 | 30,7 | 66,2 / 13,8 / 20 | 8,5 | 10,4 | 12,8 | 7,4 | 4,3 / 0,95 | 50,8 / 52,2 | 19,6 |
| Top 14 | 374 | 3,93 | 30,8 | 63,9 / 15,8 / 20,3 | 9 | 12,3 | 12,7 | 7,6 | 4,2 / 0,93 | 59 / 62 | 19,6 |
| Championship | 374 | 3,99 | 30 | 66,4 / 14,2 / 19,4 | 9 | 13,2 | 13,8 | 7,9 | 4,3 / 0,93 | 48,7 / 53,4 | 19,2 |
| URC | 302 | 4,06 | 31,3 | 64,8 / 15,5 / 19,7 | 9,1 | 14,2 | 13,7 | 8,1 | 4,3 / 0,94 | 54,2 / 59,9 | 19,7 |
| League One D1 | 228 | 4,14 | 32 | 64,6 / 15 / 20,4 | 8,4 | 11,8 | 15,8 | 6,8 | 4,4 / 0,94 | 59,4 / 57,9 | 19,8 |
| Premiership | 186 | 3,7 | 29,7 | 62,3 / 15,2 / 22,5 | 7,8 | 12,4 | 9,1 | 5,4 | 4,2 / 0,88 | 58,1 / 61 | 19,9 |
| Super Rugby | 170 | 4,01 | 30,8 | 65,2 / 14,5 / 20,3 | 8 | 10 | 14,1 | 4,7 | 4,1 / 0,98 | 51,8 / 55,7 | 19,5 |
| Champions Cup | 126 | 4,22 | 32,5 | 65 / 15,7 / 19,3 | 9,1 | 9,5 | 13,9 | 8,3 | 4,3 / 0,97 | 57,5 / 60,3 | 19,2 |
| League One D2 | 112 | 3,95 | 29,7 | 66,5 / 14,3 / 19,1 | 9,9 | 14,7 | 14,3 | 12,5 | 4,2 / 0,94 | 52,5 / 53,8 | 20,1 |
| Challenge Cup | 102 | 3,9 | 30,5 | 64 / 15,7 / 20,3 | 9,9 | 15,7 | 13,2 | 7,8 | 4,2 / 0,92 | 58,9 / 61,3 | 19,6 |
| Tous | 2850 | 4,01 | 30,8 | 65,1 / 14,9 / 20 | 8,7 | 11,7 | 13,2 | 7,5 | 4,3 / 0,93 | 54 / 57,2 | 19,6 |

Choix sur pénalité (tous) : 42,4 % au but, 51,7 % en touche, 6 % à la main ; 9 pénalités jouées par match.

Marqueurs par maillot (% des essais) : 1 : 2,8 · 2 : 2,8 · 3 : 2,9 · 4 : 3,1 · 5 : 3,2 · 6 : 10,6 · 7 : 10,4 · 8 : 10,5 · 9 : 7,4 · 10 : 7,8 · 11 : 7,7 · 12 : 7,9 · 13 : 7,6 · 14 : 7,7 · 15 : 7,5
Groupes : avants 46,4 % (première ligne 8,6, troisième ligne 31,6), charnière 15,2, centres 15,5, ailiers 15,4, arrière 7,5. **Ailier titulaire : 0,15 essai par match.**

Hiérarchie (championnats, par graine) :
- graine 4242 : favori selon l'effectif (écart ≥ 1) 47,3 (491) ; écart ≥ 3 47 (66) ; corrélation rang / effectif 0,07 (effectif) ; victoires à domicile 56,1 % ; Top 14 : CTR 82 (67.1), TCX 74 (70.5), PDX 73 (69.1)
- graine 7 : favori selon l'effectif (écart ≥ 1) 48,2 (471) ; écart ≥ 3 53,1 (64) ; corrélation rang / effectif 0,09 (effectif) ; victoires à domicile 52,4 % ; Top 14 : TCX 78 (70.2), PBX 71 (66.9), PCX 70 (67.3)

## 2. Où le moteur étranglait les essais

Le moteur joue ~85 actions par match (une par minute de jeu). Mesure des goulots :

1. **Ballon perdu trop vite.** À chaque action, l'équipe en possession la perdait une fois sur deux
   environ : pénalité ~12 %, en-avant ~12 %, touche ~12 %, et surtout une course réussie seulement
   49 % du temps, l'échec rendant le ballon (turnover ou en-avant). Une possession durait donc
   ~1,8 action pour ~18 m gagnés : **4,3 entrées dans les 22 par match** (les deux équipes), là où
   une équipe professionnelle en compte une dizaine.
2. **Conversion des 22 faible** : 0,93 essai par entrée (essai en jeu courant à 36 % une fois
   dans les 26 derniers mètres).
3. **Buteurs à 54 %** : base trop basse (0,23 + note × 0,006 − distance − angle) ; la moitié des
   transformations et pénalités manquées, d'où ~31 points.
4. **Choix pénalité / touche** : 42 % au but, 52 % en touche, 6 % à la main, proche de la réalité
   (les clubs pros vont souvent en touche dans le camp adverse) : **non modifié**.
5. **Marqueur tiré au hasard uniforme** parmi les 10 joueurs n° 6 à 15 (jeu courant) ou les 8
   avants (ballon porté, mêlée) : troisième ligne 32 % des essais, ailiers 15 %, talonneur 3 %.
6. **Aucune différence de style entre championnats** : un seul jeu pour tous.
7. **Hiérarchie très faible (défaut existant)** : à effectif plus fort (23 meilleures notes au poste,
   écart ≥ 1), le favori ne gagnait que 47-48 % de ses matchs de championnat ; corrélation rang final
   / effectif ~0,1. L'avantage de niveau (`tacticalEdge`, 0,004 par point d'écart d'attributs) pèse
   trop peu devant le hasard de 85 actions.

## 3. Correction (à la source, sans essai ajouté)

Rencontres créées avec `essaisVersion: 1` (drapeau posé à la création ; un match en cours d'une
ancienne sauvegarde garde ses coefficients, `saves.js` valide le drapeau). `ESSAIS_RULES=0` rend
l'ancien moteur (mesure `--ancien`). Fichiers : `dist/tactical-plans.js` (coefficients),
`dist/restarts.js` (course en jeu courant), `dist/rugby.js` (buts, marqueur), `dist/saves.js`.

- **Course réussie** : 0,49 → **0,63** + ouverture du championnat + avantage (le terrain gagné, les
  en-avant, les pénalités, le jeu au pied et les touches sont inchangés) : les équipes gardent le
  ballon plus longtemps et entrent plus souvent dans les 22.
- **Finition dans les 26 derniers mètres** : 0,36 → **0,47** + ouverture + avantage (ballon tenu ou
  échappé dans l'en-but inchangés).
- **Avantage de niveau doublé** dans ces deux tirages (`ESSAIS.ecart = 2` sur `tacticalEdge` seul :
  attributs et plans de jeu ; domicile, moral, supériorité numérique et préparation collective
  inchangés, ce qui garde des équipes identiques à 50/50).
- **Buteurs** : les échecs reculent de 40 % (`1 − (1 − p) × 0,6`, plafond 0,96) : réussite ~70 %,
  meilleurs buteurs ~75-80 %, la hiérarchie entre buteurs (note, fatigue, distance, angle, vent) est
  gardée.
- **Ouverture par championnat** (`OUVERTURE_CHAMPIONNATS`, ajoutée aux deux probabilités, pour les
  deux équipes) : défense et arbitrage plus ou moins ouverts selon la ligue réelle — Top 14 0,
  Pro D2 −0,03, Nationale −0,015, URC +0,025, Champions Cup +0,02, Challenge Cup +0,03,
  Premiership +0,11, Super Rugby +0,115, Championship et League One D1 +0,125, D2 +0,11.
- **Marqueur selon le poste occupé et l'origine** (`finisseurEssai`, un seul tirage comme avant) :
  jeu courant pondéré ailiers 4,1, arrière 3, centres 2 et 2,4, n° 8 et demi de mêlée 1,8,
  troisième ligne aile 1,2-1,3, ouvreur 1,2, talonneur 0,8, deuxième ligne 0,5, piliers 0,3 ;
  ballon porté talonneur 6, troisième ligne 1,5, deuxième ligne 0,8, piliers 0,6 ; mêlée n° 8 4,
  demi de mêlée 2, troisième ligne aile 1,5, talonneur 1.

Ce qui n'est pas touché : choix sur pénalité, pénalité jouée à la main, essais sur ballon porté et
mêlée à partir d'une conquête dans les 22, temps de jeu, jeu au pied, discipline, cartons.

## 4. Après (mêmes graines)

Saisons complètes, graines 4242 et 7 (2 850 matchs). Mesurées avec la version précédant deux
retouches finales sans effet sur le volume : l'amplification de niveau limitée à `tacticalEdge` (elle
portait aussi sur domicile et moral, ce qui déséquilibrait deux équipes identiques : 67 % pour la
première, test `opposition`) et la réussite au but en « échecs × 0,6 » (au lieu de +0,15, qui
plafonnait les meilleurs buteurs : test `goalkicking`). Contrôle du code final : `tests/essais-realistes.cjs`
(262 matchs, graine 4242) donne 6,16 essais et 47,7 points par match, ailier titulaire 0,45, ailiers 29 %,
avants 35 %. La relance d'une saison entière avec le code final a été tuée deux fois par manque de
mémoire de la machine partagée (autres agents) : à refaire avec `scripts/mesure-essais-monde.cjs`.

| Championnat | Matchs | Essais / match | Points / match | Part essais / transfo / pénalités (%) | Écart moyen | Sans essai (%) | Bonus 4 essais (%) | Bonus +3 essais (%) | Entrées 22 / essais par entrée | Réussite pénalités / transfo (%) | Ballons perdus |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Pro D2 | 490 | 5,6 | 43,5 | 64,4 / 18 / 17,6 | 12,1 | 6,4 | 31,8 | 14 | 4,7 / 1,2 | 67,6 / 70 | 15,9 |
| Nationale | 374 | 5,74 | 43,4 | 66,2 / 17,2 / 16,6 | 12,3 | 5,1 | 31,4 | 14,4 | 4,6 / 1,26 | 65,5 / 65,1 | 15,2 |
| Top 14 | 374 | 5,92 | 46,8 | 63,2 / 19,5 / 17,3 | 11,6 | 4,8 | 34,4 | 11,9 | 4,6 / 1,29 | 75,5 / 76,9 | 15,2 |
| Championship | 374 | 8,51 | 62,3 | 68,4 / 19,2 / 12,4 | 15,1 | 2,4 | 63,1 | 17 | 4,3 / 1,97 | 66,8 / 70,2 | 11,7 |
| URC | 302 | 6,55 | 49,5 | 66,2 / 19,6 / 14,2 | 12,7 | 3,6 | 42,5 | 13,7 | 4,5 / 1,47 | 68,5 / 74,1 | 15 |
| League One D1 | 228 | 8,32 | 61,2 | 67,9 / 20,1 / 12 | 14,5 | 1,5 | 61,6 | 17,3 | 4,7 / 1,79 | 73,3 / 73,9 | 11,9 |
| Premiership | 186 | 7,88 | 58,7 | 67 / 19,8 / 13,2 | 15,4 | 2,4 | 54,8 | 20,4 | 5 / 1,57 | 71,4 / 73,7 | 12,2 |
| Super Rugby | 170 | 8,17 | 60,1 | 68 / 20 / 12 | 14,8 | 0,9 | 57,9 | 20,6 | 4,3 / 1,89 | 65,2 / 73,9 | 12 |
| Champions Cup | 126 | 6,05 | 47 | 64,3 / 19,1 / 16,6 | 13,6 | 5,6 | 34,5 | 15,1 | 4,8 / 1,25 | 72,8 / 74,3 | 14,8 |
| League One D2 | 112 | 7,93 | 57,8 | 68,6 / 19 / 12,4 | 11,9 | 0,9 | 56,7 | 12,5 | 4,6 / 1,72 | 66,6 / 69,1 | 12,4 |
| Challenge Cup | 102 | 7,33 | 54,8 | 66,9 / 19,2 / 13,8 | 14,9 | 2,9 | 53,4 | 16,7 | 4,7 / 1,57 | 69,7 / 71,9 | 14,5 |
| Tous | 2850 | 6,84 | 51,6 | 66,3 / 19 / 14,6 | 13,2 | 3,9 | 44,7 | 15,3 | 4,6 / 1,49 | 69,1 / 71,8 | 14 |

Choix sur pénalité (tous) : 42,2 % au but, 52,1 % en touche, 5,7 % à la main ; 8,6 pénalités jouées par match.

Marqueurs par maillot (% des essais) : 1 : 1,5 · 2 : 6,5 · 3 : 1,4 · 4 : 2,5 · 5 : 2,3 · 6 : 5,4 · 7 : 5,9 · 8 : 8,9 · 9 : 7,2 · 10 : 4,1 · 11 : 14 · 12 : 7 · 13 : 8,7 · 14 : 14,1 · 15 : 10,4
Groupes : avants 34,5 % (première ligne 9,5, troisième ligne 20,3), charnière 11,3, centres 15,7, ailiers 28, arrière 10,4. **Ailier titulaire : 0,48 essai par match.**

Hiérarchie (championnats, par graine) :
- graine 4242 : favori selon l'effectif (écart ≥ 1) 56 (491) ; écart ≥ 3 68,2 (66) ; corrélation rang / effectif 0,21 (effectif) ; victoires à domicile 60,6 % ; Top 14 : BNR 77 (67.1), PCX 77 (66.9), PBX 72 (66.8)
- graine 7 : favori selon l'effectif (écart ≥ 1) 48,2 (471) ; écart ≥ 3 59,4 (64) ; corrélation rang / effectif 0,13 (effectif) ; victoires à domicile 60,1 % ; Top 14 : MGX 81 (67.4), PCX 77 (67.2), PDX 76 (68.5)

Comparaison à la réalité : Top 14 5,9-6,2 (réel 5,9) ; Pro D2 5,6 (5,2) ; URC 6,3-6,8 (6,6) ;
Premiership 7,9 (8,0) ; Championship 8,4-8,7 (8,6) ; League One D1 8,2-8,5 (8,6) ; Super Rugby 8,0-8,4
(8,3). Points : Top 14 ~47 (réel 51 : pénalités encore rares, voir limites), Premiership ~59 (56),
League One ~61 (62). Bonus offensif Top 14 (+3 essais) ~12 % des feuilles (réel 14,8 %) ; Premiership
(4 essais) ~55 % (59 %) ; URC ~42 % (42 %).

## 5. Notes et feuille de statistiques

- `match-stats.cjs` lit le même journal : les essais, transformations et pénalités de la feuille
  restent égaux au score (contrôle de `scripts/stats-match-validation.cjs` et des suites
  `match-stats-realistes`, `stats-fiche-joueur`).
- Notes (`match-notes.cjs`, étalonnage par maillot de #707) : plus d'essais aux ailiers, moins aux troisième ligne : la
  part des faits « essai » par maillot change, donc l'attendu par maillot peut dériver.
  `scripts/etalonner-notes-postes.cjs` rend la méthode de docs/homme-du-match-postes-20261114.md
  rejouable (non encore exécuté faute de mémoire : capture des journaux reçus par `noter`, puis ajustement des attendus vers la
  moyenne commune et des amplitudes vers la cible d'homme du match). Le test
  `tests/homme-du-match-postes.cjs` n'a pas pu être rejoué en local (processus tué par manque de
  mémoire de la machine partagée, deux fois) : c'est la CI de la PR qui tranche ; s'il sort des
  bornes, ré-étalonner avec ce script.

## 6. Test

`tests/essais-realistes.cjs` (carrière Monde, dix semaines, ~300 matchs, graine fixe) : 5 à 8,5
essais et 38 à 62 points par match ; championnats ouverts plus prolifiques que Top 14 et Pro D2 ;
réussite au but 58-85 % ; ailiers 18-40 % des essais, ailiers + centres 32-60 %, avants 20-45 %,
piliers et deuxième ligne ≤ 5 % chacun, talonneur ≥ 3 %, chaque ailier au moins autant que chaque
avant ; ailier titulaire 0,25 à 0,65 essai par match ; favori (XV aligné meilleur de 2 points) > 52 %.

Données figées : `tests/fixtures/match-gestes-sequence.json` régénérée avec son script
(`node tests/godot-match-gestes-scenes.cjs > tests/fixtures/match-gestes-sequence.json`) : la
séquence « touche, ballon porté, essai » est cherchée club par club avec la graine du harnais ; les
tirages ayant changé, elle est désormais trouvée au club 2 (au lieu du club 1), même forme (7 scènes).
Les données figées France (`france-legacy-parity.json`, `france-long-career-s6.json.gz`) changeront
aussi, mais leurs suites sont exclues de la CI (anciens modes, `CD_MODES_HERITES`) et ne peuvent pas
être rejouées ici (Monde uniquement) : à régénérer seulement si ces suites reviennent.

## 7. Limites et suites proposées

- Le volume de pénalités (~8,7 par match accordées, réel ~20) reste bas : les points sur pénalités
  sont sous-représentés en Top 14 (réel ~25 % des points). Non traité : il faudrait revoir le pas de
  temps du moteur.
- Hiérarchie : mieux qu'avant mais encore faible (voir tableau). La cause est l'écart d'attributs
  entre effectifs, très resserré dans un même championnat, et la rotation de l'IA (le XV aligné du
  favori est souvent plus faible). Proposition : une passe dédiée « hiérarchie » (poids de l'écart de
  niveau, rotation de l'IA, avantage du terrain), mesurée sur plusieurs saisons.
- Nationale et League One D2 : cibles sans source chiffrée.
- Une saison par graine : chaque championnat compte 50 à 245 matchs, l'incertitude par ligue est
  d'environ ±0,3 essai par match.

## Sources

- Top 14 2024-25 : https://en.wikipedia.org/wiki/2024%E2%80%9325_Top_14_season ;
  https://www.rugbypass.com/news/top-14-record-dessais-pour-toulouse-les-bayonnais-imprenables-a-domicile-la-saison-en-bref/
- Premiership 2024-25 : https://en.wikipedia.org/wiki/2024%E2%80%9325_Premiership_Rugby
- URC 2024-25 : https://en.wikipedia.org/wiki/2024%E2%80%9325_United_Rugby_Championship
- Japan Rugby League One D1 2024-25 : https://wiki.sizzltek.com/content/wikipedia_en_all_maxi_2025-08/2024%E2%80%9325_Japan_Rugby_League_One_%E2%80%93_Division_1
- Pro D2 2024-25 : https://en.wikipedia.org/wiki/2024%E2%80%9325_Rugby_Pro_D2_season ; https://rugbypass.com/news/pro-d2-le-bilan-de-la-phase-aller
- RFU Championship 2024-25 : https://en.wikipedia.org/wiki/2024%E2%80%9325_RFU_Championship
- Super Rugby Pacific 2025 : https://en.wikipedia.org/wiki/2025_Super_Rugby_Pacific_season
- Essais par poste : https://framesports.ai/blog/which-rugby-position-scores-the-most-tries/

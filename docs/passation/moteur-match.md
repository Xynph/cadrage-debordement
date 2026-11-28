# Passation — chantier « moteur de match réaliste » (27/11/2026)

Reprise prévue depuis GitHub (Claude Cloud). Ce fichier remplace la passation locale ; la liste détaillée des anomalies du moteur reste dans `ANOMALIES.md` du chantier (copie de travail locale, à reconstruire à partir de la section « Restes » ci-dessous si absente).

## 1. État (tout est fusionné sauf mention)

| PR | Côté jeu |
|---|---|
| #1305, #1307, #1308, #1312, #1313, #1314, #1316, #1319, #1320, #1323, #1334, #1338 | Transformation, jeu au pied, récit des fautes, chorégraphe 3D, conquête, IA de match, temps forts au pied, écran intermédiaire d'en-avant, contacts 3D, 50:22, consignes en direct, XV complet (détail dans l'historique git) |
| #1353 | Fautes de main et avantage |
| #1356 | Remontées tardives réalistes (défense regroupée en fin de match, équipe menée qui pousse plus fort) |
| #1351 | Niveau au poste : un titulaire bien plus faible que la norme de son poste pèse dans la phase de son poste (mêlée, touche, finition, percée) |
| #1350 | Remplaçants : un remplaçant frais pèse, l'ordinateur remplace au poste. Prête, fusion automatique squash armée (à vérifier qu'elle est bien passée) |

## 2. Chiffres de calage à tenir (ordinateur contre ordinateur, 2 graines × 600 matchs)

- Top 14 matchs serrés (≤ 7 points) : cible ≈ 40 % (réel). Mesuré : 38-40 %.
- Favori qui gagne : Top 14 ≈ 64 %, Premiership ≈ 62 %. Stable.
- Remontées tardives (mené de 11 à 14 points à la 75e, fin à ≤ 7 points) : cible 20-25 %. Main avant #1356 : 34 % en saison Monde mais 17 % en IA contre IA ; avec #1350 : 20,9 %.
- Points par match Top 14 ≈ 50-51 ; essais ≈ 6,1.
- Niveau au poste (400 matchs appariés, un titulaire affaibli de 15 points) : pilier, mêlées gardées −1,4 → −4,4 points ; talonneur, touches gardées −5,0 → −7,3. Ailier : effet visible dans les phases mais dans le bruit sur matchs joués.
- Remplaçants : part de matchs dont la suite change après un remplacement à la 50e (main → réglage final) : pilier 15 → 25 %, 3e ligne 26 → 40 %, demi de mêlée 21 → 32 %, ailier 19 → 32 %. Demi de mêlée mis à l'aile par l'ordinateur : 4 → 0 sur 150 matchs.
- Contrôle de garde de `tests/match-remplacants.cjs` : 36,7 % pour un seuil de 35 % (marge étroite : toute retouche de la fraîcheur peut le faire tomber).

## 3. Règles à garder

- Incertitude : jamais l'effet exact d'une décision n'est montré au joueur.
- Jamais abaisser un seuil de test. Élargir l'échantillon (même seuil, mêmes graines) est le remède aux tests à graine fixe fragiles : fait pour `match-pilotage` (1000 matchs par série), `match-consignes-direct` (192 matchs ; à 96 il est rouge), `cartons-realistes` (800 affiches).
- Un vérificateur indépendant (GO / NO-GO sur le vrai jeu) avant toute PR prête ; fusion automatique squash ensuite.
- Après toute modification de `dist/` : `node scripts/build-rugby-common.cjs --check` (régénérer sans `--check` sinon). Une nouvelle suite se déclare dans `ci/select-tests.cjs` et `ci/suite-weights.json` ; `tests/ci-selection.cjs` ne se modifie pas.
- La limite CI d'une suite vient de `budget()` dans `ci/run-shard-suites.sh`, pas de son poids (le poids ne sert qu'à répartir les suites sur les lots).

## 4. Pièges rencontrés

- Une fonction homonyme dans un autre module (forme 0-4 de `development.js`) a faussé la 1re version du niveau au poste : renommer les nouvelles fonctions.
- Tests à graine fixe sur petit échantillon : un test peut passer sur main uniquement par chance (`cartons-realistes` : bruit ±0,04 sur 160 matchs, rouge une fois sur huit).
- Les effets s'additionnent : une fraîcheur de remplaçant trop forte cassait en même temps les consignes en direct, le poids du niveau en URC et les tirs au but de la Premiership (l'effet « fautes » surtout). Régler une part à la fois.
- Un brouillon de PR ne lance pas la batterie CI complète : le verdict reste rouge jusqu'au passage en « prête ».
- `packages.microsoft.com` peut renvoyer 403 pendant l'apt update d'un job Godot : relancer les jobs en échec (`gh run rerun <id> --failed`), ce n'est pas la PR.
- Fusions de main successives : vérifier `MERGE_HEAD` avant de commiter, jamais de marqueurs de conflit commités ; jamais `git stash` dans un dépôt à plusieurs worktrees.

## 5. Restes

1. **Cartons jaunes en baisse (à faire, lot suivant).** Top 14 : ≈ 0,546 jaune par équipe et par match sur 3200 matchs, alors que le commentaire de `tests/cartons-realistes.cjs` annonce ≈ 0,65. Pas causé par #1351 (identique avec ou sans). Bissection partielle (2400 affiches, jaunes par équipe et par match) : 0,624 après le jeu au pied (#1307), 0,609 après la gestion du score en fin de match, 0,592 après l'IA de match (#1314), puis 0,532 au commit « lois manquantes » (coups francs, passes en avant, essais de pénalité, #1315) ; les commits plus récents restent à 0,54. Suspect principal : « lois manquantes » (une partie des fautes devient coup franc au lieu de pénalité → moins de jaunes ?). À trancher : conséquence voulue d'une loi plus fidèle, ou défaut à corriger (jaunes pour fautes répétées, plaquages hauts, en-avant volontaires). Une PR seulement si c'est un vrai défaut ; sinon mettre à jour le commentaire et la cible du test.
2. Matchs serrés en URC ≈ 34-37 % (réel 41) et Premiership un peu bas ; surveiller à chaque lot.
3. Poids du niveau en URC ≈ 0,23-0,27 pour 0,30 visé (le test tolère l'écart) après les remplaçants : à reprendre si on retouche la fraîcheur.
4. Remontées tardives Top 14 en saison Monde plus finement : demande de réélargir `match-consignes-direct` si on y retouche (marge actuelle de 2 à 4 points).
5. Lois de mêlée secondaires (non traitées).
6. Relances aux 22 mètres : ≈ 1,0-1,2 par match plus 0,7-1,0 sur la ligne d'en-but pour ≈ 3 réels. Lot de jeu au pied à part.
7. 3D : bras dans les corps encore nombreux (mêlée, maul, plaquage), animation du botteur au drop (pack d'animations privé, hors jeu de base).
8. Durées CI à surveiller : `match-pilotage` ≈ 9 min, `match-consignes-direct` ≈ 6 min, `cartons-realistes` ≈ 75 s.

## 6. Outils de mesure (dans le dépôt)

- `scripts/mesure-essais-monde.cjs` : saisons Monde (essais, serrés, points).
- `scripts/mesure-bonus-fin-de-match.cjs` : bonus de fin de match (le club du joueur remplace comme l'ordinateur ; option `--sans-remplacements` pour l'ancienne mesure).
- `tests/match-niveau-poste.cjs`, `tests/match-remplacants.cjs`, `tests/match-remontees-tardives.cjs`, `tests/match-fautes-main-avantage.cjs` : tests de chaque lot (rouges sur l'ancien main).
- Documentation par lot : `docs/niveau-au-poste-20261126.md`, `docs/remplacants-20261126.md`, `docs/remontees-tardives-20261127.md`, `docs/fautes-main-avantage-20261127.md`, `docs/realite-matchs-20261125.md`.

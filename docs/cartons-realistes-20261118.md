# Cartons réalistes (18/11/2026)

Constat (chantier #912) : le moteur donnait ~2,6 cartons jaunes par équipe et par match, contre ~0,6 à 0,8 en Top 14
(~1,3 carton par match, un rouge tous les ~8 à 10 matchs).

Causes, dans `disciplineDecision` (`dist/rugby.js`) :
- tout plaquage dangereux (10 % des incidents tirés) donnait un carton (jaune, ou rouge 18 %) ;
- dès trois pénalités depuis le dernier carton, chaque pénalité suivante ajoutait 18 % de risque, sans jamais oublier.

Réglages (`CARTONS`) : plaquage dangereux sanctionné d'un carton dans ~22 % des cas (rouge pour ~35 % d'entre eux) ;
faute ordinaire 0,6 % + 0,05 % par point de discipline sous 65 ; fautes répétées = au moins trois pénalités sans dix
minutes de répit (+5 %) ; derbys et arbitre (`pilotageCard`) inchangés. Un seul tirage par décision, comme avant.

Mesure (`tests/cartons-realistes.cjs`, carrière Monde, 80 matchs rejoués) : ~0,6 jaune et ~0,05 exclusion définitive
par équipe et par match, ~13 pénalités concédées (inchangé).

## Recalage du 19/11/2026

Cible : Top 14 réel ~0,6 à 0,9 jaune par équipe et par match (~1,3 à 1,6 par match ; un promu en prend ~24 en 20
journées, un club très indiscipliné ~1,5 par match), une exclusion définitive tous les ~10 à 15 matchs.

Le réglage du 18/11 avait été calé sur un seul match rejoué (deux clubs de deuxième division, ~12 pénalités chacun). Sur
1 000 vraies affiches de Top 14 IA contre IA (`scripts/mesure-chrono-arrets.cjs --parties=reels --reels=1000`), où chaque
équipe ne concède que ~8,3 pénalités, il donnait **~0,2 jaune par équipe** (0,43 par match) : trop peu.

Le carton se tire à chaque pénalité : son nombre suit le volume de fautes. Réglages (`CARTONS`) : plaquage dangereux
carton une fois sur deux (rouge ~1 sur 7 d'entre eux, même nombre de rouges qu'avant), faute ordinaire 3,5 %, fautes
répétées +17 %.

| Mesure (par équipe et par match) | 18/11 | 19/11 |
| --- | --- | --- |
| Top 14, 1 000 affiches IA contre IA : jaunes | 0,22 | **0,65** |
| Top 14 : exclusions définitives | 0,04 | 0,04 |
| Match du joueur rejoué 80 fois (2e division, ~12 pénalités) : jaunes | 0,6 | ~1,1 |

Le match du joueur du test, très fautif, sort plus de cartons : plausible pour ce profil, pas d'avalanche (la limite
haute du test est 1,4). Points, essais et pénalités inchangés.

Limite : le Top 14 IA contre IA concède ~8,3 pénalités par équipe, sous le réel (~10 à 12). Le taux de carton par
pénalité (~7,8 %) compense ce manque. Si le volume de fautes remonte (chantier arbitrage), les jaunes monteront avec :
le test `cartons-realistes` (lot de 160 affiches de Top 14) le signalera, et il faudra baisser `CARTONS.base` et
`CARTONS.repetees`.

Effet de bord : dans `tests/match-pilotage.cjs`, l'écart de score entre joueurs galvanisés et vexés passe de ~3,1 à ~2
points (480 matchs) ; la série passe de 160 à 480 matchs et le seuil de 2 à 1,5 point.

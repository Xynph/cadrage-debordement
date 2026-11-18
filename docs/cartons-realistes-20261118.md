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

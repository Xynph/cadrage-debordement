'use strict';
// Carrière mondiale complète (116 clubs, édition world-champ) dans la VM du moteur natif :
// sert aux tests des matchs des jeunes et à la mesure sur 20 saisons. La VM et la carrière sont
// celles du worker (tests/monde-harness.cjs : dist, modules natifs, new_career world-champ).
const {context}=require('../monde-harness.cjs');
// Une carrière Monde occupe ~1 Go : la précédente est libérée à la création de la suivante.
let previous=null;
function worldYouth({seed=827381,club=0}={}){previous?.close();previous=context(seed,{club});return previous;}
module.exports={worldYouth};

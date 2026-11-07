'use strict';
// Invoked inside the engine VM. No source identity catalogue is needed at runtime.
module.exports=function commonCareer(){
 function start(id){
  if(!Number.isInteger(id)||id<0||id>=CDCommonRosters.clubCount)throw Error('Club de base commune invalide.');
  CDFranceCareer.start(id,{database:CDCommonRosters.marker,rosterFoundation:CDRosterFoundation.marker,playersForClub:clubId=>CDCommonRosters.clubs[clubId].players.map(source=>{
   const p=JSON.parse(JSON.stringify(source));
   if(!CDRosterFoundation.players[p.id])throw Error('Référence effectif absente : '+p.id);
   const profile=JSON.parse(JSON.stringify(CDRosterFoundation.players[p.id]));
   p.rosterProfile=profile;p.pos=profile.position.primary;p.fam=FAMILIES[POS.indexOf(p.pos)];
   if(profile.position.basis==='official')p.gameplayPosition=p.pos;
   p.contractEnd=profile.contract.endSeason;return p;
  })});
 }
 return Object.freeze({start});
};

'use strict';
// Invoked inside the engine VM. No source identity catalogue is needed at runtime.
module.exports=function commonCareer(seniorCalibration=null){
 function start(id){
  if(!Number.isInteger(id)||id<0||id>=CDCommonRosters.clubCount)throw Error('Club de base commune invalide.');
  const registry=CDRosterFoundation.resolve(CDRosterFoundation.marker);
  if(!registry)throw Error('Registre effectif courant indisponible.');
  CDFranceCareer.start(id,{database:CDCommonRosters.marker,rosterFoundation:registry.marker,playersForClub:clubId=>{
   const players=CDCommonRosters.clubs[clubId].players.map(source=>{
    const p=JSON.parse(JSON.stringify(source));
    if(!registry.players[p.id])throw Error('Référence effectif absente : '+p.id);
    const profile=JSON.parse(JSON.stringify(registry.players[p.id]));
    p.rosterProfile=profile;p.pos=profile.position.primary;p.fam=FAMILIES[POS.indexOf(p.pos)];
    if(profile.position.basis==='official')p.gameplayPosition=p.pos;
    p.contractEnd=profile.contract.endSeason;return p;
   });
   if(seniorCalibration)seniorCalibration.apply(players);
   return players;
  }});
  if(seniorCalibration)S.seniorCalibrationVersion=seniorCalibration.version;
 }
 return Object.freeze({start});
};

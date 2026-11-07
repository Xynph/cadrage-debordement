'use strict';
// Invoked inside the engine VM. No source identity catalogue is needed at runtime.
module.exports=function commonCareer(){
 function start(id){
  if(!Number.isInteger(id)||id<0||id>=CDCommonRosters.clubCount)throw Error('Club de base commune invalide.');
  CDFranceCareer.start(id,{database:CDCommonRosters.marker,playersForClub:clubId=>JSON.parse(JSON.stringify(CDCommonRosters.clubs[clubId].players))});
 }
 return Object.freeze({start});
};

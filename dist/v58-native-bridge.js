'use strict';
// V58 integration bridge: read-only observation of the native manager career.
// No synthetic V58 contracts are inserted into S, finances or saved games.
(function(root,factory){
  const api=factory();
  if(typeof module==='object'&&module.exports)module.exports=api;
  if(root)root.CDV58NativeBridge=api;
})(typeof globalThis==='object'?globalThis:null,function(){
  function snapshot(native){
    if(!native||!Array.isArray(native.clubs)||!Number.isInteger(native.club))return null;
    const mobility=native.managerMobility;
    if(native.managerMobilityVersion!==1||!mobility||mobility.version!==1)return Object.freeze({
      enabled:false,clubId:native.club,season:native.season,offers:0,pending:false
    });
    const applications=Array.isArray(mobility.applications)?mobility.applications:[];
    const offers=applications.filter(x=>x&&x.season===native.season&&x.status==='offered').length;
    return Object.freeze({
      enabled:true,clubId:native.club,season:native.season,
      offers,pending:!!mobility.pending
    });
  }
  // Validate without mutating native state. Offer acceptance stays in manager-mobility.js.
  return Object.freeze({snapshot});
});

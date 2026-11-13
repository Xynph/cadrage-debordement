'use strict';
// Régression (réception Cloud de #552) : après fermeture puis reprise du profil, le tout
// premier snapshot (lecture seule) doit déjà exposer le budget réaliste — plancher salarial
// et préavis 52 semaines — sans attendre une commande mutante. Profil et export inchangés.
const assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path');
process.env.CD_SALAIRES_PAR_NIVEAU='1';
const {createBridge}=require('../native/engine/worker.cjs');
const dir=fs.mkdtempSync(path.join(os.tmpdir(),'salary-floor-resume-'));let id=0;
function call(bridge,command,payload={}){const r=bridge.handle({id:++id,command,payload});assert.equal(r.ok,true,command+' : '+r.error);return r.model;}
let bridge=createBridge({dataDir:dir,seed:27,now:1700000000000});
const created=call(bridge,'new_career',{mode:'common',club:29});
const floor=created.finance.salaryFloor,notice=created.finance.notice;
assert.ok(Number.isFinite(floor)&&floor>0,'Plancher salarial à la création');
const exported=call(bridge,'export').meta.exportText;call(bridge,'shutdown');
bridge=createBridge({dataDir:dir,now:1700000000000});
try{
 const resumed=call(bridge,'snapshot');
 assert.equal(resumed.finance.salaryFloor,floor,'Plancher salarial dès le premier snapshot de reprise');
 assert.equal(resumed.finance.notice,notice,'Préavis budget réaliste conservé à la reprise');
 assert.equal(call(bridge,'export').meta.exportText,exported,'Profil repris identique');
}finally{bridge.close?.();fs.rmSync(dir,{recursive:true,force:true});}
console.log('salary-floor-resume : plancher '+floor+' conservé au premier snapshot de reprise');

'use strict';
// Sequential, bounded worker benchmark. Optional baseline must be a local checkout.
const fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'..'),baseline=process.argv[2];
for(const [label,engine] of [...(baseline?[['baseline',path.resolve(baseline)]]:[]),['candidate',root]]){
 const {createBridge}=require(path.join(engine,'native/engine/worker.cjs'));
 const profile=fs.mkdtempSync('/tmp/cd-position-benchmark-'),start=performance.now();
 const bridge=createBridge({dataDir:profile,seed:213,now:1700000000000});let id=0;
 try{
  const measure=(command,payload={})=>{const t=performance.now(),r=bridge.handle({id:++id,command,payload});if(!r.ok)throw Error(command+': '+r.error);return {ms:performance.now()-t,model:r.model};};
  const creation=measure('new_career',{mode:'common',club:0}),snapshots=Array.from({length:3},()=>measure('snapshot').ms),auto=measure('auto_lineup');
  console.log(JSON.stringify({label,seed:213,node:process.version,root:engine,creationMs:Math.round(creation.ms),snapshotMs:snapshots.map(Math.round),autoLineupMs:Math.round(auto.ms),totalMs:Math.round(performance.now()-start),valid:auto.model.selection.valid}));
 }finally{bridge.close();fs.rmSync(profile,{recursive:true,force:true});}
}

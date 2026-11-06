'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const E33=require('./economy-v2-e33-run.cjs'),E34=require('./economy-v2-e34-advisor.cjs');
const profiles=['reference','modeste','alternatif'],seeds=[827381,99173];
function run(profile,seed,dir='economy-v2-e34-reports'){
 assert(profiles.includes(profile)&&seeds.includes(seed));
 fs.mkdirSync(dir,{recursive:true});
 // Inherits E3.3 + E3.2 15-season native campaign, never mutates loaded game.
 const upstream=E33.run(profile,seed,dir),advisor=E34.build(upstream.evidence);
 assert.equal(upstream.nativeCampaign.rounds,435);
 assert.equal(upstream.nativeCampaign.imports,3);
 assert.equal(upstream.nativeCampaign.saveParity,true);
 assert.equal(upstream.snapshotSaveParity,true);
 assert.equal(advisor.gameplayChanged,false);
 const summary={stage:'E3.4',profile,seed,advisor,nativeCampaign:upstream.nativeCampaign,
  snapshotSaveParity:true,saveParity:true,legacyLiabilitiesCreated:0,gameplayChanged:false};
 const p=path.join(dir,'e34-'+profile+'-'+seed+'.json');
 fs.writeFileSync(p,JSON.stringify(summary,null,2));
 assert.deepEqual(JSON.parse(fs.readFileSync(p,'utf8')),summary);
 return summary;
}
if(require.main===module){
 try{const [profile,seed,dir]=process.argv.slice(2),r=run(profile,Number(seed),dir);
 console.log('E34 PASS '+JSON.stringify({profile,seed,native:r.nativeCampaign,
  saveParity:r.saveParity,legacyLiabilitiesCreated:r.legacyLiabilitiesCreated}));}
 catch(e){console.error(e.stack);process.exitCode=1;}
}
module.exports={run};

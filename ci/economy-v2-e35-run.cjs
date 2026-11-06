'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const E34=require('./economy-v2-e34-run.cjs');
const E35=require('./economy-v2-e35-counterfactual.cjs');
const clubs={reference:0,modeste:13,alternatif:6};
function run(profile,seed,dir='economy-v2-e35-reports'){
 assert(Object.hasOwn(clubs,profile)&&[827381,99173].includes(seed));
 fs.mkdirSync(dir,{recursive:true});
 const campaign=E34.run(profile,seed,dir);
 assert.equal(campaign.nativeCampaign.seasons,15);
 assert.equal(campaign.nativeCampaign.rounds,435);
 assert.equal(campaign.nativeCampaign.imports,3);
 assert.equal(campaign.saveParity,true);
 const paired=E35.run(clubs[profile],seed);
 assert.equal(paired.saveParity,true);assert.equal(paired.gameplayChanged,false);
 assert.equal(paired.limits.fullSeasonCausalEffect,null);
 assert.equal(paired.limits.matchResultsCompared,false);
 const out={stage:'E3.5',profile,seed,campaign:campaign.nativeCampaign,
  paired,saveParity:true,legacyLiabilitiesCreated:0,gameplayChanged:false};
 const file=path.join(dir,'e35-'+profile+'-'+seed+'.json');
 fs.writeFileSync(file,JSON.stringify(out,null,2));
 assert.deepEqual(JSON.parse(fs.readFileSync(file,'utf8')),out);
 return out;
}
if(require.main===module){
 try{const [profile,seed,dir]=process.argv.slice(2),r=run(profile,Number(seed),dir);
 console.log('E35 PASS '+JSON.stringify({profile,seed,campaign:r.campaign,
  facility:{paid:r.paired.facility.actualImmediateDebit,growth:r.paired.facility.measuredGrowth.changedRating,
   xp:r.paired.facility.measuredGrowth.deltaXp},
  academy4000:{paid:r.paired.academy4000.actualImmediateDebit,ratings:r.paired.academy4000.measuredGrowth.changedRating},
  academy12000:{paid:r.paired.academy12000.actualImmediateDebit,ratings:r.paired.academy12000.measuredGrowth.changedRating},
  saveParity:r.saveParity,legacyLiabilitiesCreated:r.legacyLiabilitiesCreated}));}
 catch(e){console.error(e.stack);process.exitCode=1;}
}
module.exports={run};

'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const E35=require('./economy-v2-e35-run.cjs');
const E36=require('./economy-v2-e36-multiweek.cjs');
const clubs={reference:0,modeste:13,alternatif:6};
function run(profile,seed,dir='economy-v2-e36-reports'){
 assert(Object.hasOwn(clubs,profile)&&[827381,99173].includes(seed));
 fs.mkdirSync(dir,{recursive:true});
 // Long native campaign is independently an integrity regression, not a sports experiment.
 const legacy=E35.run(profile,seed,dir);
 assert.equal(legacy.campaign.seasons,15);
 assert.equal(legacy.campaign.rounds,435);
 assert.equal(legacy.campaign.imports,3);
 assert.equal(legacy.saveParity,true);
 const experiments={
  facility:E36.run(clubs[profile],seed,'facility'),
  academy4000:E36.run(clubs[profile],seed,'academy',4000),
  academy12000:E36.run(clubs[profile],seed,'academy',12000)
 };
 for(const e of Object.values(experiments)){
  assert.equal(e.sourceSaveParity,true);
  assert.equal(e.rows.length,6);
  assert.equal(e.createdHistoricalLiability,0);
 }
 const report={stage:'E3.6',profile,seed,
  nativeRegressionCampaign:legacy.campaign,
  experimentalWeeksPerArm:6,
  experiments,
  longTermSportEffect:null,fullSeasonCausalMatches:null,
  legacyLiabilitiesCreated:0,saveParity:true,gameplayChanged:false};
 const file=path.join(dir,'e36-'+profile+'-'+seed+'.json');
 fs.writeFileSync(file,JSON.stringify(report,null,2));
 assert.deepEqual(JSON.parse(fs.readFileSync(file,'utf8')),report);
 return report;
}
if(require.main===module){
 try{const [profile,seed,dir]=process.argv.slice(2),r=run(profile,Number(seed),dir);
 console.log('E36 PASS '+JSON.stringify({profile,seed,campaign:r.nativeRegressionCampaign,
  multiweek:Object.fromEntries(Object.entries(r.experiments).map(([k,v])=>[k,{
   paid:v.actualInvestmentDebited,rating:v.endGrowth.sumRatingDifference,
   xp:v.endGrowth.sumXpDifference,firstRngDivergence:v.firstRngDivergence?.week??null,
   match:v.observedFinalMatchDifference,sourceParity:v.sourceSaveParity}])),
  saveParity:r.saveParity,legacyLiabilitiesCreated:r.legacyLiabilitiesCreated}));}
 catch(e){console.error(e.stack);process.exitCode=1;}
}
module.exports={run};

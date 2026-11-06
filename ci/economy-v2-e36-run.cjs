'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const E35=require('./economy-v2-e35-run.cjs');
const E36=require('./economy-v2-e36-multiweek.cjs');
const clubs={reference:0,modeste:13,alternatif:6};
function run(profile,seed,dir='economy-v2-e36-reports'){
 assert(Object.hasOwn(clubs,profile)&&[827381,99173].includes(seed));
 fs.mkdirSync(dir,{recursive:true});
 // Fifteen full native seasons are non-regression controls, not 15 paired counterfactual seasons.
 const baseline=E35.run(profile,seed,dir);
 assert.equal(baseline.campaign.seasons,15);
 assert.equal(baseline.campaign.rounds,435);
 assert.equal(baseline.campaign.imports,3);
 assert.equal(baseline.saveParity,true);
 const paired=E36.run(clubs[profile],seed);
 assert.equal(paired.saveParity,true);
 const cases=[paired.facility,paired.academy4000,paired.academy12000];
 assert(cases.every(c=>c.records.length===4&&c.sourceSaveParity&&c.crossSeasonEffect===null));
 const report={stage:'E3.6',profile,seed,baseline:baseline.campaign,paired,
  totalPairedRounds:cases.reduce((sum,c)=>sum+c.records.length*2,0),
  baseSaveParity:true,legacyDebtsCreated:0,gameplayChanged:false};
 const file=path.join(dir,'e36-'+profile+'-'+seed+'.json');
 fs.writeFileSync(file,JSON.stringify(report,null,2));
 assert.deepEqual(JSON.parse(fs.readFileSync(file,'utf8')),report);
 return report;
}
if(require.main===module){
 try{const [profile,seed,dir]=process.argv.slice(2);
 const out=run(profile,Number(seed),dir);
 const x=out.paired;
 console.log('E36 PASS '+JSON.stringify({profile,seed,baseline:out.baseline,
  pairedRounds:out.totalPairedRounds,saveParity:out.baseSaveParity,
  facility:{debit:x.facility.facilityDebit,growth:x.facility.measuredFinalGrowth,
   match:x.facility.measuredMatchResult,rngDivergence:x.facility.firstRngDivergenceWeek},
  academy4000:{debit:x.academy4000.academyDebit,growth:x.academy4000.measuredFinalGrowth,
   match:x.academy4000.measuredMatchResult,rngDivergence:x.academy4000.firstRngDivergenceWeek},
  academy12000:{debit:x.academy12000.academyDebit,growth:x.academy12000.measuredFinalGrowth,
   match:x.academy12000.measuredMatchResult,rngDivergence:x.academy12000.firstRngDivergenceWeek},
  legacyDebtsCreated:0}));}
 catch(e){console.error(e.stack);process.exitCode=1;}
}
module.exports={run};

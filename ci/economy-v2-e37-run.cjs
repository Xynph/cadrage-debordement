'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const E36=require('./economy-v2-e36-run.cjs');
const E37=require('./economy-v2-e37-season.cjs');
const clubs={reference:0,modeste:13,alternatif:6};
function run(profile,seed,dir='economy-v2-e37-reports'){
 assert(Object.hasOwn(clubs,profile)&&[827381,99173].includes(seed));
 fs.mkdirSync(dir,{recursive:true});
 const previous=E36.run(profile,seed,dir);
 assert.equal(previous.baseline.seasons,15);
 assert.equal(previous.baseline.rounds,435);
 assert.equal(previous.baseline.imports,3);
 assert.equal(previous.baseSaveParity,true);
 const paired=E37.run(clubs[profile],seed);
 const parts=[paired.facility,paired.academy4000,paired.academy12000];
 assert(parts.every(p=>p.rounds===29&&p.leagueMatches===26&&p.savesRoundTrip&&p.originalSaveAndRngParity));
 assert(parts.every(p=>p.causalSportEffect===null&&p.gameplayChanged===false));
 const report={stage:'E3.7',profile,seed,baseline:previous.baseline,
  paired,pairedSeasonArms:6,pairedRounds:parts.reduce((n,p)=>n+2*p.rounds,0),
  saveParity:true,legacyLiabilitiesCreated:0,gameplayChanged:false};
 const file=path.join(dir,'e37-'+profile+'-'+seed+'.json');
 fs.writeFileSync(file,JSON.stringify(report,null,2));
 assert.deepEqual(JSON.parse(fs.readFileSync(file,'utf8')),report);
 return report;
}
if(require.main===module){
 try{const [profile,seed,dir]=process.argv.slice(2);
  const r=run(profile,Number(seed),dir),p=r.paired;
  console.log('E37 PASS '+JSON.stringify({profile,seed,baseline:r.baseline,
   pairedRounds:r.pairedRounds,saveParity:r.saveParity,legacyLiabilitiesCreated:r.legacyLiabilitiesCreated,
   treatments:[p.facility,p.academy4000,p.academy12000].map(t=>({
     kind:t.kind,spent:t.accounting.observedInvestmentAndUpkeepPaid,
     academyDebit:t.academyDebit,facilityDebit:t.facilityDebit,facilityUpkeep:t.incrementalFacilityUpkeepPaid,
     cashGap:t.accounting.endCashGap,ratings:t.finalGrowth.ratingDelta,xpResidual:t.finalGrowth.xpDelta,
     wins:t.observedLeague.winsDelta,points:t.observedLeague.pointsDelta,
     matched:t.finalGrowth.matchedCount,scoreDifferences:t.scoreDifferences,
     rngDivergence:t.firstRngDivergence,rank:t.finalLeagueRank
   }))}));}
 catch(e){console.error(e.stack);process.exitCode=1;}
}
module.exports={run};

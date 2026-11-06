'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const N=require('../tests/career-resilience/native.cjs');
const D=require('../tests/economy-v2-debt-audit.cjs');
const O=require('../tests/economy-v2-obligations.cjs');
const profiles={reference:0,modeste:13,alternatif:6};
function run(profile,seed){
 assert.ok(Object.hasOwn(profiles,profile)&&[827381,99173].includes(seed),'Invalid campaign');
 let g=N.fresh(profiles[profile],seed),stats=N.newStats(),series=[];
 const total={rounds:0,rollovers:0,imports:0,cashMovements:0,interclubMoves:0,externalArrivals:0,departures:0,
   recordedTerms:0,unmeasuredLiabilities:0,debtChecks:0,unknownEnd:0};
 for(let season=1;season<=15;season++){
  const opening=O.snapshot(g),beforeTerms=O.contractEvidence(opening);
  let r=0;
  while(g.run('S.phase')!=='ended'){
   assert.ok(++r<=29,'Round limit');total.rounds++;
   const before=O.snapshot(g);
   const o=D.round(g,stats);
   const after=O.snapshot(g);
   const change=O.rosterChanges(before,after);
   total.interclubMoves+=change.interclubMoves;total.externalArrivals+=change.arrivals;total.departures+=change.departures;
   total.cashMovements+=o.flow.rows.length;total.debtChecks+=14;
   const evidence=O.contractEvidence(after);
   assert.equal(evidence.clubs.length,14);
  }
  assert.equal(r,29);
  N.verified(g,stats,'e24-end-season');
  const closing=O.snapshot(g),evidence=O.contractEvidence(closing);
  for(const c of evidence.clubs){
   total.recordedTerms+=c.contractTermsObserved;
   total.unmeasuredLiabilities+=c.bookedPayable===null?1:0;
   total.unknownEnd+=c.missingEnd;
  }
  series.push({season,clubs:evidence.clubs.map(c=>({
   id:c.clubId,name:c.name,cash:c.cash,debt:c.debt,wageWeekly:c.weeklyWage,expiring:c.expiring,
   contractTermsObserved:c.contractTermsObserved,missingEnd:c.missingEnd,
   planning29Weeks:c.planning29Weeks,bookedPayable:c.bookedPayable
  })),opening:beforeTerms.clubs.map(c=>({id:c.clubId,cash:c.cash,debt:c.debt})),
    offersPending:evidence.offersPending,negotiationsPending:evidence.negotiationsPending,
    forecastNotLiability:true});
  if(season%5===0){g=N.reload(g,stats,'e24-native-import');total.imports++}
  if(season<15){
   const before=O.snapshot(g),roll=D.rollover(g),after=O.snapshot(g);
   const delta=O.rosterChanges(before,after);
   total.interclubMoves+=delta.interclubMoves;total.externalArrivals+=delta.arrivals;total.departures+=delta.departures;
   total.rollovers++;total.cashMovements+=roll.flow.rows.length;total.debtChecks+=14;
   O.contractEvidence(after);
  }
 }
 assert.equal(total.rounds,435);assert.equal(total.rollovers,14);assert.equal(total.imports,3);
 assert.equal(total.unmeasuredLiabilities,14*15);
 const report={schema:1,source:'native-game-actual',version:'e24',profile,seed,sha:process.env.GITHUB_SHA||null,
  series,counts:total,provenance:{
   observed:'S.clubs roster and worldManagement debt, salaries and contract end seasons',
   estimate:'29 weekly wages at current rates, illustrative budget only',
   missing:'no dated accrued accounts payable or guaranteed future wage liability ledger',
   transfers:'changes of player ownership tracked; fees not reconstructed from roster movement'},
  limitations:['Fictional game data; not real club budgets','Projections never treated as signed payables',
   'No month invented; missing booked liabilities represented by null']};
 return report;
}
if(require.main===module){try{
 const [profile,seed,dir='economy-v2-e24-reports']=process.argv.slice(2);
 const report=run(profile,Number(seed));fs.mkdirSync(dir,{recursive:true});
 fs.writeFileSync(path.join(dir,'obligations-'+profile+'-'+seed+'.json'),JSON.stringify(report,null,2));
 console.log('E24 PASS '+JSON.stringify({profile,seed,seasons:report.series.length,...report.counts}));
}catch(e){console.error(e.stack);process.exitCode=1}}
module.exports={run};

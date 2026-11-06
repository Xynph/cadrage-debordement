'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const N=require('../tests/career-resilience/native.cjs');
const D=require('../tests/economy-v2-debt-audit.cjs');
const profiles={reference:0,modeste:13,alternatif:6};
function run(profile,seed){
 assert.ok(Object.hasOwn(profiles,profile)&&[827381,99173].includes(seed),'Invalid campaign');
 let g=N.fresh(profiles[profile],seed),stats=N.newStats();
 const series=[],debtEvents=[],counts={rounds:0,rollovers:0,imports:0,cashMovements:0,debtConverted:0,interest:0,repayment:0,unknownLiabilities:0};
 for(let season=1;season<=15;season++){
  const opening=D.snapshot(g);
  let rounds=0;
  while(g.run('S.phase')!=='ended'){
   const o=D.round(g,stats);assert.ok(++rounds<=29);counts.rounds++;
   counts.cashMovements+=o.flow.rows.length;
  }
  N.verified(g,stats,'e23-end-season');
  const closing=D.snapshot(g);
  const exposure=D.exposures(closing);
  counts.unknownLiabilities+=exposure.clubs.filter(c=>c.bookedPayable===null).length;
  series.push({season,clubs:closing.clubs.map(c=>({id:c.id,name:c.name,cash:c.cash,debt:c.debt,
   wageWeekly:c.wageWeekly,expiring:c.expiring,unknownEnd:c.unknownEnd})),
   opening:opening.clubs.map(c=>({id:c.id,cash:c.cash,debt:c.debt})),
   exposureKnown:false});
  if(season%5===0){g=N.reload(g,stats,'e23-native-save-import');counts.imports++}
  if(season<15){
   const o=D.rollover(g);counts.rollovers++;counts.cashMovements+=o.flow.rows.length;
   for(const x of o.debtRows){counts.debtConverted+=x.debtConverted;counts.interest+=x.interest;counts.repayment+=x.repayment;}
   debtEvents.push({afterSeason:season,clubs:o.debtRows});
  }
 }
 assert.equal(counts.rounds,435);assert.equal(counts.rollovers,14);assert.equal(counts.imports,3);
 const report={schema:1,source:'native-game-actual',sha:process.env.GITHUB_SHA||null,profile,seed,
  counts,series,debtEvents,limits:['Amounts are fictional game currency, not actual club financial statements',
  'Historical liabilities/commitments lack a complete AI obligations ledger; null means unmeasured',
  'Cash and debt are native read-only observations; no synthetic monthly series']};
 return report;
}
if(require.main===module){try{
 const [profile,seed,dir='economy-v2-e23-reports']=process.argv.slice(2),r=run(profile,Number(seed));
 fs.mkdirSync(dir,{recursive:true});const p=path.join(dir,'audit-'+profile+'-'+seed+'.json');
 fs.writeFileSync(p,JSON.stringify(r,null,2));
 console.log('E23 PASS '+JSON.stringify({profile,seed,seasons:r.series.length,...r.counts}));
}catch(e){console.error(e.stack);process.exitCode=1}}
module.exports={run};

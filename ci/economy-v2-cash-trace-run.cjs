'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const N=require('../tests/career-resilience/native.cjs');
const T=require('../tests/economy-v2-cash-trace.cjs');
const profiles={reference:0,modeste:13,alternatif:6};
function run(profile,seed){
 assert.ok(Object.hasOwn(profiles,profile)&&[827381,99173].includes(seed),'Invalid campaign');
 let g=N.fresh(profiles[profile],seed),stats=N.newStats(),sites={},seasons=[],mutations=0,managerMismatch=0,rollovers=0;
 for(let season=1;season<=15;season++){
  let rounds=0,seasonMutations=0;
  while(g.run('S.phase')!=='ended'){
   assert.ok(++rounds<=29,'Invalid round count');
   const tr=T.traceAction(g,()=>N.round(g,stats),'season-'+season+'-round-'+rounds);
   T.groupSites(tr,sites);mutations+=tr.identified;seasonMutations+=tr.identified;
   const manager=tr.before.manager;
   const journal=tr.outcome.reduce((s,e)=>s+e.amount,0);
   const nativeDelta=tr.after.clubs.find(c=>c.id===manager).cash-tr.before.clubs.find(c=>c.id===manager).cash;
   if(nativeDelta!==journal)managerMismatch++;
  }
  assert.equal(rounds,29);N.verified(g,stats,'e21-season-save');
  if(season%5===0)g=N.reload(g,stats,'e21-save-import');
  if(season<15){
   const tr=T.traceAction(g,()=>g.run('advanceSeason()'),'season-'+season+'-rollover');
   T.groupSites(tr,sites);mutations+=tr.identified;seasonMutations+=tr.identified;rollovers++;
  }
  seasons.push({season,rounds,observedMutations:seasonMutations,closing:T.snap(g).clubs});
 }
 assert.equal(stats.reloads,3);assert.equal(managerMismatch,0);
 const siteRows=Object.entries(sites).map(([source,v])=>({source,...v})).sort((a,b)=>b.count-a.count);
 const result={schema:1,profile,seed,sha:process.env.GITHUB_SHA||null,
   seasons:15,rounds:435,rollovers,imports:stats.reloads,observedMutations:mutations,
   sources:siteRows.length,managerRoundMismatch:managerMismatch,unattributedMutations:0,
   unmatchedCashDeltas:0,sourceTotals:siteRows,seasonSeries:seasons,
   disclaimer:'Cash changes traced at native JS assignment sites; source labels are technical provenance, not audited economic categories. No game/save mutation persists.'};
 return result;
}
if(require.main===module){try{
 const [profile,seed,dir='economy-v2-e21-reports']=process.argv.slice(2),r=run(profile,Number(seed));
 fs.mkdirSync(dir,{recursive:true});fs.writeFileSync(path.join(dir,'cash-trace-'+profile+'-'+seed+'.json'),JSON.stringify(r,null,2));
 console.log('E21 PASS '+JSON.stringify({profile,seed,seasons:r.seasons,rounds:r.rounds,rollovers:r.rollovers,imports:r.imports,mutations:r.observedMutations,sources:r.sources,unmatched:r.unmatchedCashDeltas,unattributed:r.unattributedMutations,topSources:r.sourceTotals.slice(0,5)}));
}catch(e){console.error(e.stack);process.exitCode=1}}
module.exports={run};

'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const N=require('../tests/career-resilience/native.cjs');
const E=require('../tests/economy-v2-components.cjs');
const profiles={reference:0,modeste:13,alternatif:6};
function run(profile,seed){
 assert.ok(Object.hasOwn(profiles,profile)&&[827381,99173].includes(seed),'Invalid campaign');
 let g=N.fresh(profiles[profile],seed),stats=N.newStats();
 const years=[],byType={},bySite={},unclassified={},observations={cash:0,classified:0,unknown:0,rollovers:0},sourceSet=new Set();
 for(let season=1;season<=15;season++){
  let rounds=0;const opening=E.nativeContext(g),yearTypes={},yearUnknown=0;
  const add=x=>{
   for(const row of x.rows){
    sourceSet.add(row.site);bySite[row.site]=(bySite[row.site]||0)+1;
    for(const c of row.components){byType[c.type]=(byType[c.type]||0)+c.amount;yearTypes[c.type]=(yearTypes[c.type]||0)+c.amount}
   }
   observations.cash+=x.rows.length;observations.unknown+=x.unknownCount;
   observations.classified+=x.rows.flatMap(r=>r.components).filter(x=>x.type!=='unknown'&&!x.type.startsWith('unclassified')).length;
  };
  while(g.run('S.phase')!=='ended'){
   assert.ok(++rounds<=29,'Native round overflow');
   const x=E.auditedAction(g,()=>N.round(g,stats),'round');add(x);
  }
  assert.equal(rounds,29);
  N.verified(g,stats,'e22-season-save');
  if(season%5===0)g=N.reload(g,stats,'e22-save-import');
  const closingBeforeRollover=E.nativeContext(g);
  if(season<15){
   const x=E.auditedAction(g,()=>g.run('advanceSeason()'),'rollover');add(x);observations.rollovers++;
  }
  years.push({season,opening:opening.clubs.map(c=>({id:c.id,cash:c.cash,debt:c.debt})),
   closing:closingBeforeRollover.clubs.map(c=>({id:c.id,cash:c.cash,debt:c.debt})),
   cashComponents:yearTypes,unclassifiedComponents:yearUnknown});
 }
 assert.equal(stats.reloads,3);
 const result={schema:1,sha:process.env.GITHUB_SHA||null,profile,seed,seasons:15,rounds:435,
  imports:stats.reloads,rollovers:observations.rollovers,observedCashMutations:observations.cash,
  sourceCount:sourceSet.size,componentCount:observations.classified,unclassifiedCount:observations.unknown,
  byType,bySite,years,limitations:[
   'Accounting classifications describe cash flows, not accrual financial results',
   'Income and cost categories derive from documented native rules and legacy titles',
   'Debt and commitments not exhaustively reconstructed as double entry',
   'No cash or debt is modified by audit']};
 return result;
}
if(require.main===module){try{
 const [profile,seed,dir='economy-v2-e22-reports']=process.argv.slice(2),r=run(profile,Number(seed));
 fs.mkdirSync(dir,{recursive:true});fs.writeFileSync(path.join(dir,'components-'+profile+'-'+seed+'.json'),JSON.stringify(r,null,2));
 console.log('E22 PASS '+JSON.stringify({profile,seed,seasons:r.seasons,rounds:r.rounds,imports:r.imports,rollovers:r.rollovers,mutations:r.observedCashMutations,sources:r.sourceCount,unclassified:r.unclassifiedCount,byType:r.byType}));
}catch(e){console.error(e.stack);process.exitCode=1}}
module.exports={run};

'use strict';
// Long-run native shadow audit. No changes to gameplay state beyond real native simulation.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const N=require('../tests/career-resilience/native.cjs');
const Shadow=require('../dist/economy-v2-shadow.js');
const profiles={reference:0,modeste:13,alternatif:6};
function snap(g){return N.data(g,'({season:S.season,round:S.round,phase:S.phase,manager:S.club,clubs:S.clubs.map(c=>({id:c.id,cash:c.cash}))})')}
function run(profile,seed){
 assert.ok(Object.hasOwn(profiles,profile)&&[827381,99173].includes(seed),'Invalid campaign');
 let g=N.fresh(profiles[profile],seed),checks=N.newStats(),observations=[],seasons=[];
 for(let y=1;y<=15;y++){
  let rounds=0,failures=0,unknown=0,opened=snap(g);
  while(g.run('S.phase')!=='ended'){
   assert.ok(++rounds<=29,'Invalid round count');
   const before=snap(g),ledger=N.round(g,checks),after=snap(g);
   const o=Shadow.observe(before,after,ledger,'season-'+y+'-round-'+rounds);
   assert.equal(o.managerReconciled,true,'Manager cash unexplained on native round');
   failures+=!o.managerReconciled;unknown+=o.unexplainedClubs.length;
   observations.push(o);
  }
  assert.equal(rounds,29);N.verified(g,checks,'shadow-season-save');
  const ended=snap(g);seasons.push({season:y,rounds,opening:opened.clubs,closing:ended.clubs,managerUnexplained:failures,unknownAiObservations:unknown});
  if(y%5===0)g=N.reload(g,checks,'shadow-save-import');
  if(y<15){const before=snap(g);g.run('advanceSeason()');const after=snap(g);
   // Interseason ledger may reset and AI economic transactions are not fully itemized.
   observations.push(Shadow.observe(before,after,[],'season-'+y+'-rollover'));
  }
 }
 const summary=Shadow.summarize(observations);
 assert.equal(seasons.length,15);assert.equal(seasons.reduce((s,x)=>s+x.rounds,0),435);
 assert.equal(checks.reloads,3);
 const out={schema:1,profile,seed,source:'native-game',sha:process.env.GITHUB_SHA||null,seasons,
  rounds:435,imports:checks.reloads,managerRoundReconciliationFailures:seasons.reduce((s,x)=>s+x.managerUnexplained,0),
  observations:summary.periods,unknownAiObservations:seasons.reduce((s,x)=>s+x.unknownAiObservations,0),
  residualObservations:summary.unexplainedSteps,allClubsReconciled:summary.allClubsReconciled,
  warnings:['AI cash variations lack a complete transaction ledger','Rollover cash may lack ledger provenance','Not an activated E1 accounting simulation']};
 assert.equal(out.managerRoundReconciliationFailures,0);
 return out;
}
if(require.main===module){try{const [profile,seed,outDir='economy-v2-shadow-reports']=process.argv.slice(2),result=run(profile,Number(seed));
 fs.mkdirSync(outDir,{recursive:true});const filename=path.join(outDir,'shadow-'+profile+'-'+seed+'.json');
 fs.writeFileSync(filename,JSON.stringify(result,null,2));console.log('SHADOW PASS '+JSON.stringify({profile,seed,seasons:15,rounds:435,imports:result.imports,managerReconciliationFailures:0,unknownAiObservations:result.unknownAiObservations,allClubsReconciled:result.allClubsReconciled}));
 }catch(e){console.error(e.stack);process.exitCode=1}}
module.exports={run};

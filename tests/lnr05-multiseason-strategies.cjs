'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const {context}=require('./harness.cjs');
const MODES=['temoin','rotation','repos','combine'],SEEDS=[0,29],SEASONS=4;
function boot(offset){
 const t=context();
 for(const file of ['lnr-rosters-data.js','lnr-career.js','lnr05-enriched-data.js','lnr05-evidence-center.js'])vm.runInContext(fs.readFileSync(__dirname+'/../dist/'+file,'utf8'),t.ctx);
 t.run('for(let i=0;i<'+offset+';i++)Math.random()');t.run("start(0,'lnr')");
 return t;
}
function snapshot(run){return run('({condition:club().players.reduce((n,p)=>n+p.condition,0)/club().players.length,load:club().players.reduce((n,p)=>n+physicalLoadValue(p),0)/club().players.length,injured:club().players.filter(p=>p.injury).length,wins:club().won})')}
test('LNR quatre strategies, quatre saisons, deux graines, entrainement et rencontres natives',()=>{
 const results=[];
 for(const seed of SEEDS)for(const mode of MODES){
  const t=boot(seed),run=t.run,years=[];let matches=0,rotations=0,recovery=0,minutes=0;
  run('var auditMinutes=0;var originalMatchFactory=createRugbyMatch;createRugbyMatch=function(pair,legacy,automated,preparation){const l=originalMatchFactory(pair,legacy,automated,preparation);if(pair.includes(S.club)){const originalAdvance=advanceRugby;/* feuille inspectee sans modifier ses choix */auditMinutes+=l.sheets[pair.indexOf(S.club)].on.filter(Boolean).length*80;}return l;}');
  for(let season=1;season<=SEASONS;season++){
   let rounds=0;const start=snapshot(run);let proposed=0,trained=0;
   while(run("S.phase!=='ended'")&&rounds<42){
    if(mode==='rotation'||mode==='combine'){
     const choices=run('lnr05AdviceCandidates(3).map(x=>({id:x.id,token:x.proposal.token}))');
     proposed+=choices.length;
     if(choices.length){const c=choices[0];rotations+=Number(run('lnr05Apply('+JSON.stringify(c.id)+','+JSON.stringify(c.token)+')'));}
    }
    if(mode==='repos'||mode==='combine'){
     // Saisie directe des plans individuels identique au setter, sans render/save par joueur.
     recovery+=run("club().players.filter(p=>p.condition<65||physicalLoadValue(p)>45).map(p=>setPhysicalTraining(p.id,'repos')).filter(Boolean).length");
    }
    run('trainWeek()');trained++;
    // Match en mode simulation native; depuis #186 la feuille du manager est conservee.
    run('finishRound()');rounds++;matches++;
   }
   assert.equal(run('S.phase'),'ended');
   assert.equal(run('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'),true,'sauvegarde saine');
   years.push({season,rounds,trained,proposed,starting:start,ending:snapshot(run)});
   if(season<SEASONS)run('advanceSeason()');
  }
  minutes=run('auditMinutes');
  assert.equal(years.length,SEASONS);
  assert(years.every(y=>y.rounds>0&&y.trained===y.rounds));
  results.push({seed,mode,matches,rotations,recovery,minutesProxy:minutes,years});
 }
 assert.equal(results.length,SEEDS.length*MODES.length);
 for(const seed of SEEDS)assert.equal(new Set(results.filter(x=>x.seed===seed).map(x=>x.matches)).size,1,'calendriers comparables');
 console.log(JSON.stringify({passed:true,kind:'observational; minutesProxy counts nominal starters, not measured minutes',results}));
});

'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const {context}=require('./harness.cjs');
function boot(){const t=context();for(const f of ['lnr-rosters-data.js','lnr-career.js','lnr05-enriched-data.js','lnr05-evidence-center.js'])vm.runInContext(fs.readFileSync(__dirname+'/../dist/'+f,'utf8'),t.ctx);t.run("start(0,'lnr')");return t}
function metrics(run){return run('({injured:club().players.filter(p=>p.injury).length,condition:club().players.reduce((a,p)=>a+p.condition,0)/club().players.length,load:club().players.reduce((a,p)=>a+physicalLoadValue(p),0)/club().players.length})')}
test('LNR: trois strategies comparables, saisons completes et sauvegardes',()=>{
 const outcomes=[];
 for(const mode of ['temoin','rotation','repos']){
  const t=boot(),run=t.run,baseline=metrics(run);
  let steps=0,applied=0,proposed=0,planned=0;
  while(run("S.phase!=='ended'")&&steps<42){
   if(mode==='repos'){
    // Politique explicite sur le moteur existant ; ne pas injecter de condition.
    planned+=run("club().players.filter(p=>p.condition<65||physicalLoadValue(p)>45).map(p=>setPhysicalTraining(p.id,'repos')).filter(Boolean).length");
   }
   if(mode==='rotation'){
    const options=run('lnr05AdviceCandidates(3).map(x=>({id:x.id,token:x.proposal.token}))');
    proposed+=options.length;
    if(options.length){
     const p=options[0];
     applied+=Number(run('lnr05Apply('+JSON.stringify(p.id)+','+JSON.stringify(p.token)+')'));
    }
   }
   run('finishRound()');
   steps++;
  }
  assert.equal(run('S.phase'),'ended');
  assert.ok(run('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'),'format sauvegarde valide');
  const after=metrics(run);
  assert(Number.isFinite(after.condition)&&after.condition>=0&&after.condition<=100);
  outcomes.push({mode,steps,baseline,after,proposed,applied,planned});
 }
 assert.equal(new Set(outcomes.map(o=>o.steps)).size,1,'calendrier comparable');
 console.log(JSON.stringify({passed:true,kind:'observational comparison using native functions, not causal evidence',outcomes}));
});

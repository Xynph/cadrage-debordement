'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const {context}=require('./harness.cjs');
const seed=Number(process.env.LNR_REST_SEED||0),mode=process.env.LNR_REST_MODE||'persistent';
assert(Number.isInteger(seed)&&seed>=0&&seed<10);
assert(['persistent','weekly'].includes(mode));
function boot(){
 const t=context();
 for(const file of ['lnr-rosters-data.js','lnr-career.js','lnr05-enriched-data.js','lnr05-evidence-center.js'])vm.runInContext(fs.readFileSync(__dirname+'/../dist/'+file,'utf8'),t.ctx);
 t.run('for(let i=0;i<'+(seed*17)+';i++)Math.random()');t.run("start(0,'lnr')");
 return t;
}
test('repos persistant versus repos ponctuel: suivi et veritable reprise native',()=>{
 let t=boot(),r=t.run;
 r('var auditMinutes=0,auditLastMatch=null,origMatch=createRugbyMatch;createRugbyMatch=function(pair,legacy,automated,preparation){const l=origMatch(pair,legacy,automated,preparation);if(automated&&pair.includes(S.club))auditLastMatch=l;return l;}');
 const stats={seed,mode,rounds:0,assigned:0,restPlayerWeeks:0,newInjuries:0,minutes:0,checkpoints:0,beforeCondition:0,afterTrainingCondition:0,afterMatchCondition:0,beforeLoad:0,afterTrainingLoad:0,afterMatchLoad:0};
 const sample=()=>r('({condition:club().players.reduce((a,p)=>a+p.condition,0)/club().players.length,load:club().players.reduce((a,p)=>a+physicalLoadValue(p),0)/club().players.length,injured:club().players.filter(p=>p.injury).length})');
 while(r("S.phase!=='ended'")&&stats.rounds<42){
  if(mode==='weekly')r("club().players.forEach(p=>{if(p.physicalLoad&&p.physicalLoad.plan==='repos')p.physicalLoad.plan='normal'})");
  const assigned=r("club().players.filter(p=>p.condition<65||physicalLoadValue(p)>45).map(p=>setPhysicalTraining(p.id,'repos')).filter(Boolean).length");
  stats.assigned+=assigned;
  stats.restPlayerWeeks+=r("club().players.filter(p=>physicalModeFor(p,S.club)==='repos').length");
  const before=sample();
  r('trainWeek()');const trained=sample();
  r('finishRound()');const after=sample();
  stats.beforeCondition+=before.condition;stats.afterTrainingCondition+=trained.condition;stats.afterMatchCondition+=after.condition;
  stats.beforeLoad+=before.load;stats.afterTrainingLoad+=trained.load;stats.afterMatchLoad+=after.load;
  stats.newInjuries+=Math.max(0,after.injured-before.injured);
  stats.minutes+=r('auditLastMatch?Object.values(auditLastMatch.sheets[auditLastMatch.pair.indexOf(S.club)].minutes).reduce((a,b)=>a+b,0):0');
  r('auditLastMatch=null');
  stats.rounds++;
  if(stats.rounds===15){
   const document=r('JSON.stringify(createSaveDocument())'),parsed=JSON.parse(document);
   assert.equal(r('!!parseSaveDocument('+JSON.stringify(document)+')'),true);
   const resumed=context(parsed.state);
   for(const file of ['lnr-rosters-data.js','lnr-career.js','lnr05-enriched-data.js','lnr05-evidence-center.js'])vm.runInContext(fs.readFileSync(__dirname+'/../dist/'+file,'utf8'),resumed.ctx);
   assert.equal(resumed.run('S.round'),r('S.round'),'vraie reprise sauvegarde meme journee');
   assert.equal(resumed.run('club().players[0].condition'),r('club().players[0].condition'),'condition reprise identique');
   stats.checkpoints++;
  }
 }
 assert.equal(r('S.phase'),'ended');assert(stats.rounds>=25);assert.equal(stats.checkpoints,1);
 for(const key of ['beforeCondition','afterTrainingCondition','afterMatchCondition','beforeLoad','afterTrainingLoad','afterMatchLoad'])stats[key]=Number((stats[key]/stats.rounds).toFixed(3));
 stats.final=sample();stats.wins=r('club().won');
 console.log(JSON.stringify({passed:true,observational:true,...stats}));
});

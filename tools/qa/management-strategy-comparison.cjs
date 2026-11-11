'use strict';
// Real worker only. Copy complete temporary profiles so the alternatives share
// the career AND its saved RNG. Importing a JSON career alone would not do so.
const assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path'),crypto=require('node:crypto'),{execFileSync}=require('node:child_process');
const ROOT=path.resolve(__dirname,'../..');
const {createBridge}=require('../../native/engine/worker.cjs');
const {settleClubMeetings}=require('../../tests/helpers/club-meetings.cjs');
const hash=v=>crypto.createHash('sha256').update(typeof v==='string'||Buffer.isBuffer(v)?v:JSON.stringify(v)).digest('hex');
const mean=a=>a.length?a.reduce((s,n)=>s+n,0)/a.length:null;
const round=n=>n===null?null:Math.round(n*1000)/1000;
function worker(directory,seed){
 const bridge=createBridge({dataDir:directory,seed,now:1794434400000});let serial=0,model;
 const actions=[];
 const go=(command,payload={})=>{
  const response=bridge.handle({id:++serial,command,payload});
  assert.equal(response.ok,true,command+': '+response.error);model=response.model;
  if(!['snapshot','export'].includes(command))actions.push({command,payload,season:model.meta.season,week:model.meta.week});
  return model;
 };
 const state=()=>JSON.parse(go('export').meta.exportText).state;
 const profile=()=>fs.readFileSync(path.join(directory,'PrototypeGodot','donnees.json'));
 const pure=()=>{const before=profile(),s=hash(state());go('snapshot');assert.equal(hash(state()),s);assert.deepEqual(profile(),before);};
 return {go,state,profile,pure,actions,close:()=>bridge.close(),get model(){return model;}};
}
function settle(w){return settleClubMeetings(w.model,w.go);}
function metrics(model){
 const academy=model.decisions.development.academy;
 return {season:model.meta.season,week:model.meta.week,cash:model.finance.cash,wage:model.finance.wage,
  points:model.club.points,rank:model.club.rank,morale:model.meta.morale,trust:model.meta.trust,
  players:model.squad.length,averageRating:round(mean(model.squad.map(p=>p.rating).filter(Number.isFinite))),
  averageCondition:round(mean(model.squad.map(p=>p.condition))),averageFatigue:round(mean(model.squad.map(p=>p.physicalLoad).filter(Number.isFinite))),
  injured:model.squad.filter(p=>p.injury>0).length,
  academyAverageRating:round(mean(academy.map(p=>p.rating).filter(Number.isFinite))),
  academyInvestment:model.clubLife.clubStrategy.finance.academyInvestment,
  academySpent:model.clubLife.clubStrategy.finance.academySpent};
}
function play(w){
 settle(w);if(!w.model.meta.trained)w.go('train',{mode:'normal'});settle(w);
 w.go('auto_lineup');w.go('begin_match');w.go('delegate');
 assert.equal(w.model.live.finished,true);
 const report=w.model.decisions.report,score=[...report.score],side=report.side;
 const result={round:w.model.meta.round,opponent:report.teams[1-side].id,score:score[side]+'–'+score[1-side],
  won:score[side]>score[1-side],draw:score[side]===score[1-side]};
 w.go('finish_round');settle(w);return {...result,metrics:metrics(w.model)};
}
function publicQuote(p){return {id:p.id,clubId:p.clubId,pos:p.pos,family:p.family,age:p.age,fee:p.fee,salary:p.salary,
 rating:p.rating,ratingRange:p.ratingRange,knowledge:p.knowledge?.stage};}
function bid(model,p){return {playerId:p.id,sellerId:p.clubId,fee:p.fee,salary:p.salary,sourceSalary:p.sourceSalary,contractEnd:p.contractEnd,context:model.clubLife.interclubMarket.context};}
function recruit(w,id){
 const p=w.model.clubLife.interclubMarket.candidates.find(p=>p.id===id);assert.ok(p?.available,'The real quote must still be available: '+id);
 const offer=bid(w.model,p);const before=metrics(w.model);
 w.go('interclub_transfer',{...offer,confirmed:true});
 assert.ok(w.model.squad.some(p=>p.id===id));assert.equal(w.model.finance.cash,before.cash-p.fee);
 return {quote:publicQuote(p),before,after:metrics(w.model)};
}
function initialTargets(model){
 const candidates=model.clubLife.interclubMarket.candidates.filter(p=>p.available);
 const stable=(a,b)=>a.id.localeCompare(b.id);
 // Highest public salary is a scouting lead, never evidence of ability.
 const expensive=candidates.slice().sort((a,b)=>b.salary-a.salary||a.fee-b.fee||stable(a,b))[0];assert.ok(expensive);
 const choices=[expensive],families=new Set([expensive.family]);
 for(const p of candidates.slice().sort((a,b)=>a.salary-b.salary||a.fee-b.fee||stable(a,b))){
  if(p.id===expensive.id||families.has(p.family))continue;choices.push(p);families.add(p.family);if(choices.length===3)break;
 }
 assert.equal(choices.length,3);return choices;
}
function campaign(seed,horizon,temp){
 const baseDir=path.join(temp,'seed-'+seed,'checkpoint');const baseline=worker(baseDir,seed);
 try{
  baseline.go('new_career',{mode:'fiction',club:13});settle(baseline);
  const leads=initialTargets(baseline.model);
  for(const p of leads)baseline.go('observe_player',{playerId:p.id,confirmed:true,context:p.scouting.context});
  const preparation=[];
  for(let i=0;baseline.model.clubLife.interclubMarket.candidates.filter(p=>leads.some(q=>q.id===p.id)).some(p=>p.knowledge.stage==='unobserved');i++){
   assert.ok(i<8,'Three queued observations finish within eight real weeks');preparation.push(play(baseline));
  }
  baseline.pure();const model=baseline.model;
  const targets=leads.map(p=>model.clubLife.interclubMarket.candidates.find(q=>q.id===p.id));
  assert.ok(targets.every(p=>p.available&&p.knowledge.stage!=='unobserved'));
  const checkpoint=baseline.profile(),checkpointHash=hash(checkpoint),stateHash=hash(baseline.state());
  const checkpointRng=JSON.parse(checkpoint).seed;
  const plans=[{id:'reference',label:'Conserver les moyens'},
   {id:'vedette',label:'Un renfort au salaire élevé'},
   {id:'talent_observe',label:'Le meilleur niveau observé parmi les trois pistes'},
   {id:'profondeur',label:'Deux familles de postes'},
   {id:'formation',label:'Financer la formation'}];
  const initial=metrics(model),baselineActions=baseline.actions.slice();baseline.close();
  const results=[];
  for(const plan of plans){
   const directory=path.join(temp,'seed-'+seed,plan.id);fs.cpSync(baseDir,directory,{recursive:true});
   const w=worker(directory,0);
   try{
    assert.equal(hash(w.profile()),checkpointHash,'Exact full saved profile copied');
    assert.equal(JSON.parse(w.profile()).seed,checkpointRng);assert.equal(hash(w.state()),stateHash);w.pure();
    const decisions=[];
    if(plan.id==='vedette')decisions.push(recruit(w,targets[0].id));
    if(plan.id==='talent_observe'){
     const known=targets.slice().filter(p=>Number.isFinite(p.rating)||Number.isFinite(p.ratingRange?.min));
     known.sort((a,b)=>(b.rating??b.ratingRange.min)-(a.rating??a.ratingRange.min)||a.salary-b.salary||a.id.localeCompare(b.id));
     assert.ok(known.length);decisions.push(recruit(w,known[0].id));
    }
    if(plan.id==='profondeur')for(const p of targets.slice(1))decisions.push(recruit(w,p.id));
    if(plan.id==='formation'){
     const before=metrics(w.model);w.go('club_academy_investment',{context:w.model.clubLife.clubStrategy.context,amount:12000,confirmed:true});
     assert.equal(w.model.finance.cash,before.cash,'Configuring investment charges no money');
     decisions.push({investmentPerSession:12000,before,after:metrics(w.model)});
    }
    const rounds=[];for(let i=0;i<horizon;i++)rounds.push(play(w));
    const end=metrics(w.model);w.pure();
    const matches=rounds.map(r=>({round:r.round,opponent:r.opponent,score:r.score,won:r.won,draw:r.draw}));
    results.push({...plan,openingProfileSha256:checkpointHash,openingStateSha256:stateHash,openingRng:checkpointRng,
     decisions,rounds,summary:{wins:matches.filter(m=>m.won).length,draws:matches.filter(m=>m.draw).length,matches:matches.length,
      cashChange:end.cash-initial.cash,wageChange:end.wage-initial.wage,pointsChange:end.points-initial.points,
      academyRatingChange:round(end.academyAverageRating-initial.academyAverageRating),fatigueChange:round(end.averageFatigue-initial.averageFatigue),
      moraleChange:end.morale-initial.morale,trustChange:end.trust-initial.trust},end,commands:w.actions,
     closingProfileSha256:hash(w.profile()),closingStateSha256:hash(w.state()),closingRng:JSON.parse(w.profile()).seed});
    console.error('seed='+seed+' '+plan.id+' '+JSON.stringify(results.at(-1).summary));
   }finally{w.close();}
  }
  return {seed,checkpointProfileSha256:checkpointHash,checkpointStateSha256:stateHash,checkpointRng,initial,
   scouting:{selection:'Public salary, fees and distinct families only; no hidden ability or potential read for decisions',targets:targets.map(publicQuote),preparation,commands:baselineActions},results};
 }catch(e){baseline.close();throw e;}
}
function main(){
 const get=(name,fallback)=>{const arg=process.argv.find(a=>a.startsWith('--'+name+'='));return arg?arg.slice(name.length+3):fallback;};
 const seeds=get('seeds','427,731,1299').split(',').map(Number),horizon=Number(get('rounds','8'));
 assert.ok(seeds.length&&seeds.every(n=>Number.isSafeInteger(n)&&n>=0&&n<=0xffffffff));assert.ok(Number.isSafeInteger(horizon)&&horizon>=1&&horizon<=12);
 const output=path.resolve(get('output','work/management-strategy-results.json'));fs.mkdirSync(path.dirname(output),{recursive:true});
 const temp=fs.mkdtempSync(path.join(os.tmpdir(),'rg27-strategies-'));
 const report={schema:1,sourceSha:execFileSync('git',['rev-parse','HEAD'],{cwd:ROOT,encoding:'utf8'}).trim(),
  scriptSha256:hash(fs.readFileSync(__filename)),nodeVersion:process.version,
  workerSha256:hash(fs.readFileSync(path.join(ROOT,'native/engine/worker.cjs'))),
  engineFilesUnmodified:true,method:'Complete isolated saved profiles copied byte for byte including saved RNG and clock; public worker commands only',
  edition:'Fiction, XV adulte professionnel français 2025–2026, historical engine abstractions; no rule modification or 2026/27 compliance claim',
  limits:['Directed scenario, not a balance verdict or proof of causal performance.','Expensive scouted target does not guarantee a star.','Budgets and total spends differ; no claim of equal spend.','No tactical/manual substitution differences: normal training, auto lineup and full delegation for all branches.','Scouting warm-up and mandatory meetings precede the common checkpoint.','No Windows execution, no Godot/3D/audio needed.'],horizon,campaigns:[]};
 try{for(const seed of seeds){report.campaigns.push(campaign(seed,horizon,temp));fs.writeFileSync(output,JSON.stringify(report,null,2)+'\n');}report.complete=true;fs.writeFileSync(output,JSON.stringify(report,null,2)+'\n');}
 catch(error){report.complete=false;report.failure=error.stack;fs.writeFileSync(output,JSON.stringify(report,null,2)+'\n');throw error;}
 finally{fs.rmSync(temp,{recursive:true,force:true});}
 console.log(output);
}
if(require.main===module)main();
module.exports={metrics,initialTargets};

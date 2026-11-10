'use strict';
const assert=require('node:assert/strict'),vm=require('node:vm'),fs=require('node:fs'),path=require('node:path');
const domain=require('../native/engine/match-talks.cjs');
const clone=x=>JSON.parse(JSON.stringify(x));
function harness(){
 const players=Array.from({length:25},(_,i)=>({id:'p'+i,fam:i<8?3:6,age:24,skills:{mental:70},rating:70}));
 const state={season:1,round:0,phase:'league',club:0,morale:75,economy:{week:0},clubs:[{id:0,players},{id:1,players:[]}],live:null};
 const ctx=vm.createContext({S:state,JSON,Math,Set,Map,console});
 vm.runInContext(`
 var tickCalls=0,continueCalls=0,finishCalls=0;
 function atHalftime(l){return !!l.flow.atBreak;}
 function tick(){tickCalls++;if(!S.live.paused){S.live.minute++;if(S.live.minute===43){S.live.flow.atBreak=true;S.live.paused=true;}if(S.live.minute===85)S.live.finished=true;}}
 function continueMatch(){continueCalls++;S.live.paused=false;S.live.flow.atBreak=false;}
 function finishRound(){finishCalls++;S.live=null;S.round++;}
 `,ctx);
 const bank=path.join(__dirname,'../dist/native-scene-dialogues.js');
 assert.ok(fs.existsSync(bank),'production dialogue selector required');
 vm.runInContext(fs.readFileSync(bank,'utf8'),ctx);
 vm.runInContext(`var talks=(${domain.factory.toString()})();talks.installHooks();`,ctx);
 const run=src=>vm.runInContext(src,ctx),call=(name,...args)=>{ctx.args=args;return clone(run('talks.'+name+'(...args)')??null);};
 const begin=(liveFields={})=>{state.live={pair:[0,1],userSide:0,minute:0,score:[0,0],finished:false,paused:false,flow:{atBreak:false},sheets:[{initial:players.slice(0,15).map(p=>p.id),bench:players.slice(15,23).map(p=>p.id)},{initial:[],bench:[]}],...liveFields};call('observe','begin_match');return call('project').scene;};
 const decide=(s,extra={})=>call('execute','match_talk_decide',{key:s.key,phase:s.phase,choiceId:s.options[0].id,audience:'group',playerIds:[],...extra});
 const proceed=s=>call('execute','match_talk_continue',{key:s.key,phase:s.phase,skip:true});
 return {ctx,state,call,run,begin,decide,proceed};
}
const h=harness(),{state,call,run}=h;
assert.equal(call('project').scene,null);assert.equal(state.contextualMatch,undefined);
call('observe','snapshot');assert.equal(state.contextualMatch,undefined,'reads and unrelated mutations leave old absence untouched');
let scene=h.begin();assert.equal(scene.phase,'pre');assert.equal(scene.options.length,6);assert.equal(scene.participants.length,23);assert.equal(state.live.paused,true);
assert.equal(scene.participants.find(p=>p.number===9).group,'backs','true positional family, not shirt-number heuristic');
const pre=JSON.stringify(state);call('project');call('validate',state);assert.equal(JSON.stringify(state),pre);
for(const alter of [s=>s.contextualMatch.current.participants[1].id='p0',s=>s.contextualMatch.current.participants[0].group='backs',s=>s.contextualMatch.current.phases[0].context.score=[5,0],s=>s.contextualMatch.current.context.fixture='invented',s=>s.contextualMatch.current.phases.push(clone(s.contextualMatch.current.phases[0]))]){const s=clone(state);alter(s);assert.throws(()=>call('validate',s));}
assert.throws(()=>call('guard','tick',{}));assert.throws(()=>call('guard','pause',{paused:false}));assert.throws(()=>run('continueMatch()'));
assert.throws(()=>h.decide(scene,{choiceId:'forged'}));assert.throws(()=>h.decide(scene,{tone:'warm'}));assert.throws(()=>h.decide(scene,{audience:'players',playerIds:['p24']}));
assert.throws(()=>h.decide(scene,{audience:'forwards',playerIds:['p0']}));assert.throws(()=>h.decide(scene,{audience:'players',playerIds:['p0','p0']}));
h.decide(scene);scene=call('project').scene;assert.ok(scene.decision);assert.equal(scene.phase,'pre');assert.equal(scene.decision.reactions.length,23);assert.ok(Math.abs(state.morale-75)<=1);
const decided=JSON.stringify(state);assert.throws(()=>h.decide(scene));assert.equal(JSON.stringify(state),decided);
const saved=clone(state);call('clearTransient');h.ctx.S=clone(saved);call('validate',h.ctx.S);assert.deepEqual(call('project').scene,scene,'decision resumes without effects');h.ctx.S=state;
h.proceed(scene);assert.equal(call('project').scene,null);assert.equal(state.live.paused,false);assert.equal(run('continueCalls'),1);
state.live.minute=40;call('observe','tick');assert.equal(call('project').scene,null,'minute forty alone is not halftime');
state.live.minute=42;run('for(let i=0;i<120;i++)tick()');scene=call('project').scene;assert.equal(scene.phase,'half');assert.equal(state.live.minute,43,'batched tick stops at the actual halftime without rolling back');
assert.throws(()=>call('execute','match_talk_continue',{key:scene.key,phase:'half'}),'explicit skip required');h.proceed(scene);assert.equal(state.live.flow.atBreak,false);
state.live.minute=84;run('tick()');scene=call('project').scene;assert.equal(scene.phase,'post');assert.throws(()=>call('guard','finish_round',{}));
h.decide(scene);h.proceed(scene);assert.equal(run('finishCalls'),1);assert.equal(state.live,null);assert.equal(call('project').receipts.length,3);assert.equal(state.contextualMatch.current,null);
for(const alter of [s=>s.contextualMatch.version=2,s=>s.contextualMatch.receipts.push(s.contextualMatch.receipts[0]),s=>s.contextualMatch.receipts[0].choiceId='fake',s=>s.contextualMatch.receipts[0].moraleDelta=99]){const s=clone(state);alter(s);assert.throws(()=>call('validate',s));}
const delegated=harness();delegated.begin();delegated.call('setDelegating',true);delegated.call('observe','delegate');
for(let i=0;!delegated.state.live.finished&&i<200;i++)delegated.run('S.live.paused?continueMatch():tick()');
assert.equal(delegated.state.live.finished,true);assert.equal(delegated.call('project').scene,null);delegated.call('guard','finish_round',{});assert.equal(delegated.call('project').receipts.length,3);assert.ok(delegated.call('project').receipts.every(r=>r.status==='delegated'));
delegated.call('setDelegating',false);delegated.call('clearTransient');
const old=harness();old.begin();delete old.state.contextualMatch;old.state.live.minute=43;old.state.live.flow.atBreak=true;old.call('observe','tick');assert.equal(old.call('project').scene,null,'existing old live never gets fabricated pre or half');
const effects=[];
for(let i=0;i<6;i++){const trial=harness(),s=trial.begin();trial.decide(s,{choiceId:s.options[i].id});effects.push(trial.state.morale-75);}
assert.ok(effects.some(n=>n!==0),'some offered declarations must have a meaningful bounded effect');assert.ok(effects.some(n=>n<=0),'declaring a talk cannot guarantee positive morale');
for(const phase of ['semi','final']){const f=harness();f.state.phase=phase;const s=f.begin();assert.equal(s.context.venue,'neutral');assert.ok(s.options.every(o=>!require('../dist/native-scene-dialogues.js').find(o.id).conditions.all.some(tag=>tag==='home'||tag==='away')));}
for(const neutral of [true,false]){const f=harness();f.state.phase='final';const s=f.begin({worldContext:{id:'world-cup-semi-42',phase:'semi',neutral}});assert.equal(s.context.venue,neutral?'neutral':'home','world fixture venue overrides generic career phase');assert.equal(s.context.fixture,'world-cup-semi-42');assert.equal(s.context.competitionPhase,'semi');f.call('validate',f.state);}
console.log('Native match talks VM: contextual phases, six choices, audience authority, once-only effects, saved decisions, halftime, post validation, delegation and hostile state PASS.');

function workerTests(){
 const {createBridge}=require('../native/engine/worker.cjs');
 const {refuseSavePublication}=require('./helpers/save-publication-refusal.cjs');
 const root=fs.mkdtempSync(path.join(require('node:os').tmpdir(),'native-match-talks-'));
 let b=createBridge({dataDir:root,seed:371,now:1700000000000}),seq=0,m;
 const good=(command,payload={})=>{const out=b.handle({id:++seq,command,payload});assert.equal(out.ok,true,command+': '+out.error);m=out.model;return m;};
 const bad=(command,payload={})=>{const out=b.handle({id:++seq,command,payload});assert.equal(out.ok,false,command+' should fail');return out;};
 const scene=()=>m.clubLife.matchTalks.scene;
 const exported=()=>good('export').meta.exportText;
 const continuation=s=>good('match_talk_continue',{key:s.key,phase:s.phase,skip:true});
 const decision=s=>({key:s.key,phase:s.phase,choiceId:s.options[0].id,audience:'group',playerIds:[]});
 const restart=()=>{b.close();b=createBridge({dataDir:root});good('snapshot');};
 const checksum=doc=>{let hash=2166136261;for(const ch of JSON.stringify(doc.state))hash=Math.imul(hash^ch.charCodeAt(0),16777619);doc.checksum=(hash>>>0).toString(16).padStart(8,'0');return JSON.stringify(doc);};
 try{
  good('new_career',{mode:'common',club:29});assert.ok(m.clubLife.matchTalks);assert.equal(scene(),null);
  let before=exported();good('snapshot');assert.equal(exported(),before,'fresh reads do not initialize the domain');
  good('train');good('auto_lineup');good('begin_match');assert.equal(scene().phase,'pre');assert.equal(scene().participants.length,23);
  assert.equal(scene().options.length,6);before=exported();const profile=path.join(m.meta.dataDir,'donnees.json'),disk=fs.readFileSync(profile);
  good('snapshot');good('snapshot');assert.equal(exported(),before);assert.deepEqual(fs.readFileSync(profile),disk);
  bad('tick',{steps:120});bad('pause',{paused:false});bad('finish_round');bad('match_talk_decide',{...decision(scene()),tone:'warm'});
  assert.equal(exported(),before,'refusals preserve the career');
  refuseSavePublication(profile,()=>bad('match_talk_decide',decision(scene())));
  assert.equal(exported(),before,'failed disk publication rolls back the entire decision and morale');assert.deepEqual(fs.readFileSync(profile),disk);
  for(const morale of [0,100,75.5,0.5,99.5]){
   const imported=JSON.parse(before);imported.state.morale=morale;good('import',{text:checksum(imported)});
   good('match_talk_decide',decision(scene()));const d=scene().decision;
   assert.equal(d.moraleBefore,morale,'decision preserves the actual base-valid imported value');assert.ok(d.moraleAfter>=0&&d.moraleAfter<=100&&Math.abs(d.moraleAfter-morale)<=1);assert.equal(d.moraleDelta,d.moraleAfter-morale);
   const savedDecision=exported();good('import',{text:savedDecision});assert.equal(exported(),savedDecision,'fractional/boundary morale decisions validate on import');
  }
  good('import',{text:before});
  good('match_talk_decide',decision(scene()));const decidedScene=clone(scene()),decided=exported();
  bad('match_talk_decide',decision(scene()));restart();assert.deepEqual(scene(),decidedScene);assert.equal(exported(),decided);
  for(const alter of [s=>s.contextualMatch.current.phases[0].decision.tone='invented',s=>s.contextualMatch.current.phases[0].decision.playerIds=['forged'],s=>s.contextualMatch.current.participants[0].id='forged',s=>s.contextualMatch.current.phases[0].phase='post']){
   const doc=JSON.parse(decided);alter(doc.state);bad('import',{text:checksum(doc)});assert.equal(exported(),decided,'hostile domain import is atomic');
  }
  continuation(scene());
  for(let tries=0;tries<80&&!scene();tries++){
   if(m.live.paused)good('pause',{paused:false});good('tick',{steps:120});
  }
  assert.equal(scene()?.phase,'half','real worker tick batches reach the actual halftime scene');
  const half=clone(scene()),halfSave=exported();restart();assert.deepEqual(scene(),half);assert.equal(exported(),halfSave);
  bad('pause',{paused:false});continuation(scene());
  for(let tries=0;tries<80&&!scene();tries++){
   if(m.live.paused)good('pause',{paused:false});good('tick',{steps:120});
  }
  assert.equal(scene()?.phase,'post');bad('finish_round');const post=clone(scene()),postSave=exported();restart();assert.deepEqual(scene(),post);assert.equal(exported(),postSave);
  good('match_talk_decide',decision(scene()));continuation(scene());assert.equal(m.live,null);assert.equal(scene(),null);assert.equal(m.clubLife.matchTalks.receipts.length,3);
  bad('match_talk_continue',{key:post.key,phase:'post',skip:true});
  good('train');good('auto_lineup');good('begin_match');good('delegate');assert.equal(m.live.finished,true);assert.equal(scene(),null);assert.equal(m.clubLife.matchTalks.receipts.length,6);good('finish_round');
  // Old saves with an already-live match remain on the existing live flow.
  good('train');good('auto_lineup');good('begin_match');const old=JSON.parse(exported());delete old.state.contextualMatch;
  good('import',{text:checksum(old)});assert.equal(scene(),null);const oldSave=exported();good('snapshot');assert.equal(exported(),oldSave);good('delegate');assert.equal(scene(),null);good('finish_round');
  console.log('Native match talks worker: live lifecycle, batch boundaries, save/restart, strict import, disk rollback, delegation and legacy live compatibility PASS.');
 }finally{b.close();fs.rmSync(root,{recursive:true,force:true});}
}
const {CORE_FILES}=require('../native/engine/worker.cjs');
assert.ok(CORE_FILES.includes('native-scene-dialogues.js'),'worker must register the closed production match-talks domain');
workerTests();

'use strict';
// Scenario observer only. Every choice, minute of play and deadline is reached
// through existing public commands; never alter a saved player or sports state.
const assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path'),crypto=require('node:crypto'),{execFileSync}=require('node:child_process');
const {createBridge}=require('../../native/engine/worker.cjs');
const {settleClubMeetings}=require('../../tests/helpers/club-meetings.cjs');
const ROOT=path.resolve(__dirname,'../..');
const hash=x=>crypto.createHash('sha256').update(typeof x==='string'||Buffer.isBuffer(x)?x:JSON.stringify(x)).digest('hex');
const copy=x=>structuredClone(x);
function worker(directory){
 let bridge=createBridge({dataDir:directory,seed:427,now:1794434400000}),serial=0,model=null;const commands=[],restarts=[];
 const bytes=()=>fs.readFileSync(path.join(directory,'PrototypeGodot','donnees.json'));
 const send=(command,payload={},ok=true)=>{
  const before=model?{cash:model.finance?.cash,wage:model.finance?.wage,morale:model.meta?.morale,trust:model.meta?.trust}:null;
  const response=bridge.handle({id:++serial,command,payload});
  assert.equal(response.id,serial);if(response.model)model=response.model;
  const after=model?{cash:model.finance?.cash,wage:model.finance?.wage,morale:model.meta?.morale,trust:model.meta?.trust}:null;
  commands.push({requestId:serial,command,payload:copy(payload),accepted:response.ok,error:response.error??null,before,after,
   cashChange:Number.isFinite(before?.cash)&&Number.isFinite(after?.cash)?after.cash-before.cash:null,wageChange:Number.isFinite(before?.wage)&&Number.isFinite(after?.wage)?after.wage-before.wage:null});
  assert.equal(response.ok,ok,command+': '+response.error);return model;
 };
 const go=(command,payload={})=>send(command,payload,true);
 const stateHash=()=>{const text=go('export').meta.exportText;return hash(JSON.parse(text).state);};
 const read=()=>{
  const prior=bytes(),state=stateHash();go('snapshot');assert.equal(stateHash(),state);assert.deepEqual(bytes(),prior,'Consulting memory must not rewrite sports state, RNG or clock');
  const saved=JSON.parse(prior);return {profileSha256:hash(prior),stateSha256:state,seed:saved.seed,clock:saved.clock,readOnly:true};
 };
 const reject=(command,payload)=>{const prior=bytes(),state=stateHash();send(command,payload,false);assert.deepEqual(bytes(),prior,'Refused repetition leaves profile unchanged');assert.equal(stateHash(),state);return {command,rejected:true,profileUnchanged:true,stateUnchanged:true,profileSha256:hash(prior),seed:JSON.parse(prior).seed,clock:JSON.parse(prior).clock};};
 const restart=()=>{
  const prior=bytes(),state=stateHash();bridge.close();bridge=createBridge({dataDir:directory,seed:0,now:1794434400000});
  assert.deepEqual(bytes(),prior,'Restart must retain exact profile bytes');assert.equal(stateHash(),state,'Restart retains the complete career state');
  const receipt={afterRequestId:serial,profileSha256:hash(prior),stateSha256:state,seed:JSON.parse(prior).seed,clock:JSON.parse(prior).clock,unchanged:true};restarts.push(receipt);return receipt;
 };
 return {go,reject,read,restart,bytes,stateHash,commands,restarts,get model(){return model;},close:()=>bridge.close()};
}
function archive(event){
 return Object.fromEntries(['key','playerId','kind','title','context','trait','leadership','choice','season','week','status'].filter(k=>Object.hasOwn(event,k)).map(k=>[k,event[k]]));
}
function story(model,target,partner){
 const rel=model.clubLife.relationships,p=rel.players.find(p=>p.id===target),identity=model.squad.find(p=>p.id===target);assert.ok(p&&identity?.knowledge?.owned===true);
 return {career:{club:model.club.id,season:model.meta.season,round:model.meta.round,week:model.meta.week,phase:model.meta.phase},relationshipContext:copy(rel.context),
  character:{id:target,name:identity.name,pos:identity.pos,personality:copy(p.personality),satisfaction:p.score,condition:p.condition,physicalLoad:identity.physicalLoad,injury:p.injury,minutes:p.minutes,
   promise:copy(p.promise),promiseHistory:copy(p.promiseHistory),conversationAvailable:p.conversationAvailable,promiseAvailable:p.promiseAvailable},
  commitments:copy(rel.commitments.filter(c=>c.playerId===target)),
  personalEvents:rel.history.filter(e=>e.playerId===target).map(archive),recentEvents:rel.history.slice(0,6).map(archive),
  conversations:copy(rel.conversationHistory.filter(h=>h.playerId===target)),
  pair:copy(rel.pairs.find(p=>[p.a,p.b].includes(target)&&[p.a,p.b].includes(partner))??null),
  currentEvent:rel.event?archive(rel.event):null,morale:model.meta.morale,trust:model.meta.trust,finance:{cash:model.finance.cash,wage:model.finance.wage}};
}
function verifyMemory(observation,baseline,firstEvent,choice){
 assert.equal(observation.character.personality.trait,baseline.character.personality.trait,'The ID-bound trait persists instead of rerolling');
 assert.ok(observation.conversations.some(h=>h.choice==='clarifier'&&h.season===baseline.conversations[0].season&&h.round===baseline.conversations[0].round),'The original conversation stays archived');
 assert.equal(observation.pair?.score,baseline.pair.score,'No repeated duo was necessary to retain its link');
 const stored=observation.personalEvents.find(e=>e.key===firstEvent.key);assert.ok(stored);assert.equal(stored.title,firstEvent.title);assert.equal(stored.context,firstEvent.context);assert.equal(stored.trait,firstEvent.trait);assert.equal(stored.leadership,firstEvent.leadership);assert.equal(stored.choice,choice);
}
function prioritize(w,id,reserved){
 const p=w.model.squad.find(p=>p.id===id);assert.ok(p?.knowledge?.owned===true);
 if(p.injury>0)return {id,selected:false,reason:'Public injury: do not force an unavailable player'};
 const primary=new Set(p.primaryPositions??[p.primaryPosition]);
 let slots=w.model.selection.slots.filter(s=>s.slot<15&&primary.has(s.positionNumber??s.slot+1)&&s.eligibleIds.includes(id)&&!reserved.has(s.slot));
 if(!slots.length)slots=w.model.selection.slots.filter(s=>s.slot<15&&s.label===p.pos&&s.eligibleIds.includes(id)&&!reserved.has(s.slot));
 const selected=slots.find(s=>s.playerId===id)??slots[0];
 if(!selected)return {id,selected:false,reason:'No currently public eligible primary-position slot'};
 if(selected.playerId!==id)w.go('set_lineup',{slot:selected.slot,playerId:id});reserved.add(selected.slot);
 assert.equal(w.model.lineup[selected.slot],id);
 return {id,selected:true,slot:selected.slot,positionNumber:selected.positionNumber??selected.slot+1,primaryPositions:[...primary]};
}
function play(w,target,partner){
 settleClubMeetings(w.model,w.go);w.go('train',{mode:'normal'});settleClubMeetings(w.model,w.go);w.go('auto_lineup');
 const reserved=new Set(),selection=[prioritize(w,target,reserved),prioritize(w,partner,reserved)];
 if(!w.model.selection.valid){const q=w.model.selection.coverage;assert.ok(q?.slots?.length&&q.slots.length<=q.places,'Keep the real qualified-sheet and capacity guard');w.go('promote_cover',{confirmed:true,expectedSlots:q.slots});}
 w.go('begin_match');const on=w.model.live.lineup.filter(Boolean).map(p=>p.id),pairAtKickoff=on.includes(target)&&on.includes(partner);
 w.go('delegate');assert.equal(w.model.live.finished,true);const report=w.model.decisions.report,score=copy(report.score),side=report.side;
 const result={round:w.model.meta.round,opponentId:report.teams[1-side].id,score:score[side]+'–'+score[1-side],won:score[side]>score[1-side],draw:score[side]===score[1-side],selection,pairTogetherAtKickoff:pairAtKickoff};
 w.go('finish_round');settleClubMeetings(w.model,w.go);return result;
}
function collect(output){
 const temp=fs.mkdtempSync(path.join(os.tmpdir(),'rg27-character-memory-')),checkpoint=path.join(temp,'checkpoint');let initial=worker(checkpoint);
 const report={schema:1,sourceSha:execFileSync('git',['rev-parse','HEAD'],{cwd:ROOT,encoding:'utf8'}).trim(),runnerSha256:hash(fs.readFileSync(__filename)),nodeVersion:process.version,
  method:'Public APIs only, full saved profile fork including state/RNG/clock, same qualified selection/time policy, three played rounds',
  limits:['One character and one checkpoint do not establish global narrative variety or personality-specific strategy.','After decisions, match results and RNG paths can diverge; no single-cause attribution of results.','Two different clocks are retained: the role commitment uses weeks, the playing-time promise uses three recorded matches.','No game engine, coefficients, sports fixture, economic rule, calendar, Godot, import, Windows or speech is changed or qualified.'],branches:[]};
 try{
  initial.go('new_career',{mode:'fiction',club:13});settleClubMeetings(initial.model,initial.go);
  const event=copy(initial.model.clubLife.relationships.event);assert.ok(event?.available);const target=event.playerId;
  const partner=initial.model.lineup.find(id=>id!==target&&initial.model.squad.some(p=>p.id===id&&!p.injury&&p.condition>=45&&[1,2,3].includes(p.primaryPosition)));
  assert.ok(partner,'An actual available starting front-row partner is needed');
  const commonActions=[];const act=(command,payload)=>{const before=story(initial.model,target,partner);initial.go(command,payload);const after=story(initial.model,target,partner);commonActions.push({command,payload:copy(payload),before,after,cashChange:after.finance.cash-before.finance.cash,wageChange:after.finance.wage-before.finance.wage});};
  act('relationship_conversation',{context:initial.model.clubLife.relationships.context,playerId:target,choice:'clarifier'});
  const rejectedConversation=initial.reject('relationship_conversation',{context:initial.model.clubLife.relationships.context,playerId:target,choice:'rassurer'});
  act('relationship_duo',{context:initial.model.clubLife.relationships.context,mode:'duo',a:target,b:partner});
  const rejectedDuo=initial.reject('relationship_duo',{context:initial.model.clubLife.relationships.context,mode:'duo',a:target,b:partner});
  const minimum=initial.model.clubLife.relationships.promiseOptions.slice().sort((a,b)=>a.minutes-b.minutes)[0];assert.equal(minimum.minutes,80);
  act('relationship_promise',{context:initial.model.clubLife.relationships.context,playerId:target,target:minimum.id});
  const rejectedPromise=initial.reject('relationship_promise',{context:initial.model.clubLife.relationships.context,playerId:target,target:minimum.id});
  const baseline=story(initial.model,target,partner);assert.equal(initial.model.clubLife.relationships.event.key,event.key);
  const opening=initial.read(),profile=initial.bytes();report.checkpoint={...opening,characterId:target,partnerId:partner,event:archive(event),story:baseline,commonActions,rejections:[rejectedConversation,rejectedDuo,rejectedPromise],commands:initial.commands};
  initial.close();initial=null;
  for(const choice of ['ecouter','responsabiliser']){
   const directory=path.join(temp,choice);fs.cpSync(checkpoint,directory,{recursive:true});const w=worker(directory);
   try{
    assert.deepEqual(w.bytes(),profile,'The two policies start from the exact same saved profile');assert.equal(w.stateHash(),opening.stateSha256);
    const branch={choice,label:choice==='ecouter'?'Écouter sans nouvelle obligation de rôle':'Confier un rôle et avancer un engagement de 60 minutes',openingProfileSha256:hash(w.bytes()),openingSeed:JSON.parse(w.bytes()).seed,openingClock:JSON.parse(w.bytes()).clock,observations:[],rounds:[],rejections:[]};
    branch.commands=w.commands;branch.restarts=w.restarts;report.branches.push(branch);
    const observe=phase=>{const observation=story(w.model,target,partner);verifyMemory(observation,baseline,event,choice);const integrity=w.read();branch.observations.push({phase,story:observation,integrity});return observation;};
    w.go('locker_room_decision',{context:w.model.clubLife.relationships.context,eventKey:event.key,choice});observe('after_initial_choice');
    branch.rejections.push(w.reject('locker_room_decision',{context:w.model.clubLife.relationships.context,eventKey:event.key,choice}));
    const first=branch.observations[0].story;assert.equal(first.finance.cash,baseline.finance.cash);assert.equal(first.finance.wage,baseline.finance.wage);
    branch.initialDirectChanges={satisfaction:first.character.satisfaction-baseline.character.satisfaction,morale:first.morale-baseline.morale,trust:first.trust-baseline.trust,cash:first.finance.cash-baseline.finance.cash,wage:first.finance.wage-baseline.finance.wage};
    for(let i=0;i<3;i++){
     if(i>0){
      const rel=w.model.clubLife.relationships,person=rel.players.find(p=>p.id===target);assert.ok(person.conversationAvailable);
      w.go('relationship_conversation',{context:rel.context,playerId:target,choice:'rassurer'});observe('followup_conversation_before_round_'+(i+1));
      branch.rejections.push(w.reject('relationship_conversation',{context:w.model.clubLife.relationships.context,playerId:target,choice:'rassurer'}));
      const next=w.model.clubLife.relationships.event;
      if(next?.available){
       const previous=w.model.clubLife.relationships.history.slice(0,3).map(e=>e.playerId);assert.ok(!previous.includes(next.playerId),'A public follow-up event avoids the three recently treated characters');
       w.go('locker_room_decision',{context:w.model.clubLife.relationships.context,eventKey:next.key,choice:'ecouter'});
       branch.rejections.push(w.reject('locker_room_decision',{context:w.model.clubLife.relationships.context,eventKey:next.key,choice:'ecouter'}));
       observe('followup_weekly_event_before_round_'+(i+1));
      }
     }
     branch.rounds.push(play(w,target,partner));observe('after_round_'+(i+1));
     if(i===0){w.restart();observe('after_restart_round_1');}
    }
    const final=observe('final');branch.commands=w.commands;branch.restarts=w.restarts;
    branch.summary={playedRounds:branch.rounds.length,wins:branch.rounds.filter(r=>r.won).length,draws:branch.rounds.filter(r=>r.draw).length,
     targetMinutes:final.character.minutes-baseline.character.minutes,satisfaction:final.character.satisfaction,morale:final.morale,trust:final.trust,
     cashChange:final.finance.cash-baseline.finance.cash,wageChange:final.finance.wage-baseline.finance.wage,
     trait:final.character.personality.trait,leadership:final.character.personality.leadership,pairScore:final.pair.score,
     roleCommitments:final.commitments,promise:final.character.promise,promiseHistory:final.character.promiseHistory,
     originalEventStillArchived:final.personalEvents.some(e=>e.key===event.key),conversationCount:final.conversations.length,
     closingProfileSha256:branch.observations.at(-1).integrity.profileSha256,closingStateSha256:branch.observations.at(-1).integrity.stateSha256,
     closingSeed:branch.observations.at(-1).integrity.seed,closingClock:branch.observations.at(-1).integrity.clock};
    console.error(choice+' '+JSON.stringify(branch.summary));
   }finally{w.close();}
  }
  assert.equal(report.branches[0].openingProfileSha256,report.branches[1].openingProfileSha256);assert.equal(report.branches[0].openingSeed,report.branches[1].openingSeed);assert.equal(report.branches[0].openingClock,report.branches[1].openingClock);
  report.complete=true;fs.mkdirSync(path.dirname(output),{recursive:true});fs.writeFileSync(output,JSON.stringify(report,null,2)+'\n');return report;
 }catch(error){report.complete=false;report.failure=error.stack;report.localDiagnosticDirectory=temp;fs.mkdirSync(path.dirname(output),{recursive:true});fs.writeFileSync(output,JSON.stringify(report,null,2)+'\n');throw error;}
 finally{initial?.close();if(report.complete)fs.rmSync(temp,{recursive:true,force:true});}
}
if(require.main===module){const output=path.resolve(process.argv.find(a=>a.startsWith('--output='))?.slice(9)||'work/character-story-persistence.json');const r=collect(output);console.log(JSON.stringify({output,complete:r.complete,branches:r.branches.length}));}
module.exports={collect};

'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');
const source=fs.readFileSync(path.join(__dirname,'../dist/tactical-plans.js'),'utf8');
const players=Array.from({length:15},(_,i)=>({condition:90,fam:i<8?2:6}));
const events=[];
const ctx={S:{clubs:[{abbr:'A'},{abbr:'B'}]},TACTICS:{equilibre:['Équilibré'],conquete:['Conquête'],large:['Large'],occupation:['Occupation']},
 activePlayers:()=>players,mean:a=>a.reduce((s,x)=>s+x,0)/(a.length||1),
 matchMinute:l=>l.minute,unit:(l,side,key,filter)=>key==='power'?65:key==='pass'?70:78,
 addEvent:(l,text,kind,meta)=>events.push({text,kind,meta})};
vm.runInNewContext(source+'\nthis.ai={opponentAttackDecision,adaptOpponentAttack,adaptDefence};',ctx);
const ai=ctx.ai;
function match(extra={}){return {tacticalVersion:1,restartVersion:1,balanceVersion:2,userSide:0,minute:74,
 score:[20,8],tactics:['equilibre','equilibre'],defences:['equilibre','equilibre'],
 pair:[0,1],weather:'Beau',tacticalStats:[{kicks:0},{handErrors:0,carries:3,advances:2}],...extra}}
test('late deficit prompts fast wide attack when fit',()=>{
 const l=match();assert.equal(ai.opponentAttackDecision(l,1).plan,'large');
 assert.equal(ai.adaptOpponentAttack(l,1),true);assert.equal(l.tactics[1],'large');
 assert.equal(events.at(-1).meta.team,1);
});
test('late lead prioritizes territory',()=>{
 const l=match({score:[3,20]});assert.equal(ai.opponentAttackDecision(l,1).plan,'occupation');
});
test('rain and handling errors prioritize conquest',()=>{
 const l=match({weather:'Pluie',tacticalStats:[{}, {handErrors:3,carries:6,advances:2}]});
 assert.equal(ai.opponentAttackDecision(l,1).plan,'conquete');
});
test('old saves and user side are untouched',()=>{
 const l=match({tacticalVersion:0}),old=JSON.stringify(l);
 assert.equal(ai.opponentAttackDecision(l,1),null);assert.equal(ai.adaptOpponentAttack(l,1),false);
 assert.equal(JSON.stringify(l),old);assert.equal(ai.opponentAttackDecision(match(),0),null);
});
test('idempotence, no random and no state writes outside native tactic',()=>{
 const l=match(),before=JSON.stringify(l);
 const decision=ai.opponentAttackDecision(l,1);
 assert.equal(JSON.stringify(l),before);assert.equal(ai.adaptOpponentAttack(l,1),true);
 const n=events.length;assert.equal(ai.adaptOpponentAttack(l,1),false);assert.equal(events.length,n);
 assert.equal(decision.plan,'large');
});
test('multi-scenario 300 deterministic decisions without career mutation',()=>{
 for(let i=0;i<300;i++){
  const l=match({minute:i%81,score:[i%39,(i*7)%37],weather:i%3===0?'Pluie':'Beau'});
  const before=JSON.stringify(l),a=ai.opponentAttackDecision(l,1),b=ai.opponentAttackDecision(l,1);
  assert.deepEqual(JSON.parse(JSON.stringify(a)),JSON.parse(JSON.stringify(b)));
  assert.equal(JSON.stringify(l),before);
  assert.ok(['equilibre','large','occupation','conquete'].includes(a.plan));
 }
});

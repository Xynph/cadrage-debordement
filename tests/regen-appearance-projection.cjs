'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const {context}=require('./native-reference-harness.cjs');

function office(){
 const h=context();h.run('CDCommonCareer.start(0)');
 return {...h,project:name=>JSON.parse(h.run('JSON.stringify(nativeSystems.domain('+JSON.stringify(name)+').project())'))};
}
function pure(h,read){
 const state=h.run('JSON.stringify(S)'),rng=h.randomState(),result=read();
 assert.equal(h.run('JSON.stringify(S)'),state,'portrait projection must not change the career');
 assert.deepEqual(h.randomState(),rng,'portrait projection must not draw randomness');
 return result;
}

test('legacy scouting and youth portraits keep the bank marker absent',()=>{
 const h=office();
 const rows=pure(h,()=>[...h.project('regenScouting').candidates,...h.project('youthDevelopment').players]);
 assert.ok(rows.length>0);
 for(const p of rows)assert.equal(Object.hasOwn(p,'appearanceBankVersion'),false);
});

for(const version of [1,2]){
 test('scouting candidates and shared shortlist preserve explicit portrait bank '+version,()=>{
  const h=office(),before=h.project('regenScouting').candidates[0];assert.ok(before);
  h.ctx.auditId=before.id;h.ctx.auditBank=version;
  h.run('for(const p of [...S.market,...S.economy.freeAgents])if(p.id===auditId)p.appearanceBankVersion=auditBank;S.manager.watch.push(auditId)');
  const result=pure(h,()=>h.project('regenScouting')),p=result.candidates.find(p=>p.id===before.id);
  assert.equal(p.appearanceBankVersion,version);assert.equal(p.id,before.id);assert.equal(p.age,before.age);
  assert.equal(result.shortlist.find(p=>p.id===before.id).appearanceBankVersion,version);
  const {appearanceBankVersion,...legacy}=p;
  assert.deepEqual(legacy,{...before,watched:true},'the public candidate gains only its explicit bank marker');
 });

 test('academy and promoted youth portraits preserve explicit portrait bank '+version,()=>{
  const h=office();h.run('var auditYouth=S.development.academy[0];auditYouth.age=21');
  const id=h.run('auditYouth.id'),before=h.project('youthDevelopment').players.find(p=>p.id===id);
  h.ctx.auditBank=version;h.run('auditYouth.appearanceBankVersion=auditBank');
  const p=pure(h,()=>h.project('youthDevelopment')).players.find(p=>p.id===id);
  assert.equal(p.appearanceBankVersion,version);assert.equal(p.id,id);assert.equal(p.age,21);
  const {appearanceBankVersion,...legacy}=p;assert.deepEqual(legacy,before);
  assert.equal(h.run('promoteYouth(auditYouth.id)'),true);
  const promoted=pure(h,()=>h.project('youthDevelopment')).players.find(p=>p.id===id);
  assert.equal(promoted.appearanceBankVersion,version);assert.equal(promoted.id,id);assert.equal(promoted.age,21);assert.equal(promoted.stage,'professional');
 });
}

test('a real recruited regen keeps the same bank and identity from scouting to youth development',()=>{
 const h=office(),candidate=h.project('regenScouting').candidates.find(p=>p.available&&p.age<=24);assert.ok(candidate);
 h.ctx.auditId=candidate.id;h.run('for(const p of [...S.market,...S.economy.freeAgents])if(p.id===auditId)p.appearanceBankVersion=2');
 const scouted=pure(h,()=>h.project('regenScouting')).candidates.find(p=>p.id===candidate.id);
 assert.equal(scouted.appearanceBankVersion,2);
 assert.equal(h.run('negotiateContract(auditId,"recruit",100000,1)&&confirmContract(talkKey(auditId,"recruit"))'),true);
 const recruited=pure(h,()=>h.project('youthDevelopment')).players.find(p=>p.id===candidate.id);
 assert.ok(recruited);assert.equal(recruited.appearanceBankVersion,2);assert.equal(recruited.id,scouted.id);assert.equal(recruited.age,scouted.age);
 assert.equal(h.project('regenScouting').candidates.some(p=>p.id===candidate.id),false);
});

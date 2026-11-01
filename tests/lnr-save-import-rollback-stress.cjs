'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const {context}=require('./harness.cjs');

function open(clubId){
 const t=context();
 t.run('start('+clubId+')');
 return t;
}
function exportOf(t){return t.run('JSON.stringify(createSaveDocument())');}
function stateOf(t){return t.run('JSON.stringify(S)');}
function beginPreview(t,payload){return t.run('pendingSave=parseSaveDocument('+JSON.stringify(payload)+');showImportReview();!!pendingSave');}

for(const [home,away] of [[0,13],[13,0],[4,8]]){
 test('save import transactional preview, cancellation and backup '+home+' to '+away,()=>{
  const current=open(home),incoming=exportOf(open(away));
  const original=stateOf(current),disk=current.store['bdt-v1'];
  assert.equal(beginPreview(current,incoming),true);
  assert.equal(stateOf(current),original);
  assert.equal(current.store['bdt-v1'],disk);
  current.run('cancelSaveImport()');
  assert.equal(stateOf(current),original);
  assert.equal(current.store['bdt-v1'],disk);
  assert.equal(beginPreview(current,incoming),true);
  assert.equal(current.run('confirmSaveImport()'),true);
  assert.equal(current.run('S.club'),away);
  assert.equal(current.run('backupDocument().state.club'),home);
  assert.equal(JSON.parse(current.store['bdt-v1']).club,away);
  current.run('reviewBackup()');
  assert.equal(current.run('confirmSaveImport()'),true);
  assert.equal(stateOf(current),original);
  assert.equal(current.run('backupDocument().state.club'),away);
  assert.equal(current.run('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'),true);
 });
 for(const key of ['bdt-before-import','bdt-v1']){
  test('import rollback on quota failure '+key+' '+home+' to '+away,()=>{
   const current=open(home),incoming=exportOf(open(away));
   const original=stateOf(current),disk=current.store['bdt-v1'];
   const backup=current.store['bdt-before-import'];
   assert.equal(beginPreview(current,incoming),true);
   current.run('var savedSetItem=localStorage.setItem;localStorage.setItem=(k,v)=>{if(k==='+JSON.stringify(key)+')throw Error("quota");savedSetItem(k,v)}');
   assert.equal(current.run('confirmSaveImport()'),false);
   assert.equal(stateOf(current),original);
   assert.equal(current.store['bdt-v1'],disk);
   assert.equal(current.store['bdt-before-import'],backup);
  });
 }
}
console.log(JSON.stringify({passed:true,scenarios:9,scope:'preview, cancellation, rollback, backup restore',engineChanges:false}));

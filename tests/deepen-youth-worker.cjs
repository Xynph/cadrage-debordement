'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {prepare}=require('./deepen-youth-fixture.cjs');
test('real four-week review leads to an atomic loan and exact disk resume',()=>{
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'cd-deepen-youth-worker-'));let result;
 try{
  result=prepare(dir);const {bridge,call,request,player}=result;
  const before=call('export').meta.exportText,state=JSON.parse(before).state,profile=path.join(result.model.meta.dataDir,'donnees.json'),bytes=fs.readFileSync(profile);
  const academy=call('snapshot').clubLife.academyPathways,host=academy.loanClubs[0];assert.ok(host);
  const refusal=request('academy_loan',{...academy.context,playerId:player.id,to:state.club,confirmed:true});assert.equal(refusal.ok,false);assert.equal(call('export').meta.exportText,before);assert.deepEqual(fs.readFileSync(profile),bytes);
  let model=call('academy_loan',{...academy.context,playerId:player.id,to:host.id,confirmed:true});
  const after=call('export').meta.exportText,loaned=JSON.parse(after).state;
  assert.equal(loaned.clubs[state.club].players.some(p=>p.id===player.id),false);assert.equal(loaned.clubs[host.id].players.filter(p=>p.id===player.id).length,1);
  assert.equal(model.clubLife.youthDevelopment.players.some(p=>p.id===player.id),false,'loaned player leaves the current-club review');
  assert.equal(loaned.v78to81.loans.filter(p=>p.id===player.id).length,1);
  assert.deepEqual(loaned.youthDevelopment,state.youthDevelopment,'loan does not rewrite earlier youth observations');
  call('import',{text:after});assert.equal(call('export').meta.exportText,after);
  bridge.close();result=null;
  const resumed=require('../native/engine/worker.cjs').createBridge({dataDir:dir,now:1700000000000});try{const r=resumed.handle({id:1,command:'export',payload:{}});assert.equal(r.ok,true,r.error);assert.equal(r.model.meta.exportText,after);}finally{resumed.close();}
 }finally{result?.bridge.close();fs.rmSync(dir,{recursive:true,force:true});}
});

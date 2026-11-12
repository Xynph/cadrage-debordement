'use strict';
// Diagnostic replay against a real local profile, never edit or import its state.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const {createBridge}=require('../../native/engine/worker.cjs');
const hash=x=>crypto.createHash('sha256').update(x).digest('hex');
function replay(dataDir,playerId){
 const file=path.join(dataDir,'PrototypeGodot','donnees.json'),bridge=createBridge({dataDir,seed:0});let id=0;
 const go=command=>bridge.handle({id:++id,command,payload:{}});
 const read=()=>{const bytes=fs.readFileSync(file),profile=JSON.parse(bytes),result=go('export');assert.equal(result.ok,true);const s=JSON.parse(result.model.meta.exportText).state;
  const p=s.clubs[s.club].players.find(p=>p.id===playerId);assert.ok(p&&s.live?.finished);
  return {profileSha256:hash(bytes),stateSha256:hash(JSON.stringify(s)),seed:profile.seed,clock:profile.clock,
   publicOwnCharacter:{id:playerId,promise:p.satisfaction.promise,recordedMinutes:p.dev.minutes,finishedMatchMinutes:s.live.sheets[s.live.userSide].minutes[playerId]}};};
 try{const before=read(),response=go('finish_round'),after=read();assert.equal(response.ok,false);assert.deepEqual(after,before);return {before,requestId:response.id,accepted:response.ok,error:response.error,after,transactionUnchanged:true};}finally{bridge.close();}
}
if(require.main===module){const [directory,playerId,output]=process.argv.slice(2);const result=replay(path.resolve(directory),playerId);fs.writeFileSync(output,JSON.stringify(result,null,2)+'\n');console.log(JSON.stringify(result));}
module.exports={replay};

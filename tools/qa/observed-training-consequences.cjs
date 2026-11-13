'use strict';
// Public worker commands and public owned-squad projections only. Copy complete
// saved profiles to keep the same career, RNG and clock for each alternative.
const assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path'),crypto=require('node:crypto'),{execFileSync}=require('node:child_process');
const {createBridge}=require('../../native/engine/worker.cjs');
const {settleClubMeetings}=require('../../tests/helpers/club-meetings.cjs');
const ROOT=path.resolve(__dirname,'../..');
const sha=x=>crypto.createHash('sha256').update(x).digest('hex');
function worker(directory){
 const bridge=createBridge({dataDir:directory,seed:427,now:1794434400000});let serial=0,model;const commands=[];
 const send=(command,payload={})=>{const r=bridge.handle({id:++serial,command,payload});model=r.model;if(!['snapshot','export'].includes(command))commands.push({command,payload,ok:r.ok,error:r.error??null});return r;};
 const go=(command,payload={})=>{const r=send(command,payload);assert.equal(r.ok,true,command+': '+r.error);return model;};
 const bytes=()=>fs.readFileSync(path.join(directory,'PrototypeGodot','donnees.json'));
 return {go,send,bytes,commands,close:()=>bridge.close(),get model(){return model;}};
}
function publicModel(model){
 return {club:{id:model.club.id},meta:{mode:model.meta.mode,season:model.meta.season,week:model.meta.week,trained:model.meta.trained,training:model.meta.training,morale:model.meta.morale,saveError:model.meta.saveError},
  finance:{cash:model.finance.cash,wage:model.finance.wage},
  squad:model.squad.map(p=>({id:p.id,name:p.name,condition:p.condition,physicalLoad:p.physicalLoad,rating:p.rating,knowledge:{owned:p.knowledge?.owned,stage:p.knowledge?.stage}}))};
}
function expected(before,after){
 const prior=new Map(before.squad.filter(p=>p.knowledge?.owned===true).map(p=>[p.id,p]));
 const next=new Map(after.squad.filter(p=>p.knowledge?.owned===true).map(p=>[p.id,p]));
 const format=n=>(Math.round(n*10)/10).toString().replace('.',',');
 return ['condition','physicalLoad','rating'].map(field=>{
  const ids=[...prior.keys()].filter(id=>next.has(id)&&Number.isFinite(prior.get(id)[field])&&Number.isFinite(next.get(id)[field]));
  const a=ids.length?ids.reduce((sum,id)=>sum+prior.get(id)[field],0)/ids.length:null;
  const b=ids.length?ids.reduce((sum,id)=>sum+next.get(id)[field],0)/ids.length:null;
  return {field,count:ids.length,before:a,after:b,beforeText:a===null?null:format(a),afterText:b===null?null:format(b),visible:ids.length>0&&format(a)!==format(b)};
 });
}
function collect(output){
 const temp=fs.mkdtempSync(path.join(os.tmpdir(),'rg27-observed-training-'));
 const baseDir=path.join(temp,'checkpoint');let base=worker(baseDir);
 const report={schema:1,sourceSha:execFileSync('git',['rev-parse','HEAD'],{cwd:ROOT,encoding:'utf8'}).trim(),runnerSha256:sha(fs.readFileSync(__filename)),nodeVersion:process.version,
  method:'Same complete temporary saved profile copied byte for byte, public TRAIN commands, explicit owned projections only',
  limits:['Before/after observations do not attribute the whole change to a single cause.','These four training sessions do not establish a long-term progression guarantee.','No potential, hidden opponent data, edited save, coefficient or forecast is collected.'],cases:[]};
 try{
  base.go('new_career',{mode:'fiction',club:13});settleClubMeetings(base.model,base.go);
  base.go('train',{mode:'normal'});settleClubMeetings(base.model,base.go);base.go('auto_lineup');
  if(!base.model.selection.valid){const quote=base.model.selection.coverage;assert.ok(quote?.slots?.length<=quote?.places);base.go('promote_cover',{confirmed:true,expectedSlots:quote.slots});}
  base.go('begin_match');base.go('delegate');base.go('finish_round');settleClubMeetings(base.model,base.go);
  base.go('set_delegation',{key:'training',enabled:false});base.go('snapshot');
  assert.equal(base.model.meta.trained,false);
  const tired=base.model.squad.filter(p=>p.knowledge?.owned===true).sort((a,b)=>b.physicalLoad-a.physicalLoad||a.id.localeCompare(b.id))[0];assert.ok(tired.physicalLoad>0);
  const profile=base.bytes(),state=JSON.parse(base.go('export').meta.exportText).state;
  report.checkpointProfileSha256=sha(profile);report.checkpointStateSha256=sha(JSON.stringify(state));report.checkpointRng=JSON.parse(profile).seed;report.checkpointClock=JSON.parse(profile).clock;
  report.setupCommands=base.commands;report.individualExceptionId=tired.id;base.close();base=null;
  for(const policy of [{id:'repos',mode:'repos'},{id:'normal',mode:'normal'},{id:'intense',mode:'intense'},{id:'intense_exception_repos',mode:'intense',rest:tired.id}]){
   const directory=path.join(temp,policy.id);fs.cpSync(baseDir,directory,{recursive:true});const w=worker(directory);
   try{
    assert.equal(sha(w.bytes()),report.checkpointProfileSha256);assert.equal(JSON.parse(w.bytes()).seed,report.checkpointRng);w.go('snapshot');
    if(policy.rest)w.go('set_player_load',{playerId:policy.rest,mode:'repos'});
    const before=publicModel(w.model),beforeProfile=w.bytes();w.go('train',{mode:policy.mode});const after=publicModel(w.model),afterProfile=w.bytes();
    const observations=expected(before,after);
    const row={id:policy.id,mode:policy.mode,ok:true,before,after,expected:observations,commands:w.commands,
     openingCheckpointSha256:report.checkpointProfileSha256,beforeTrainProfileSha256:sha(beforeProfile),afterTrainProfileSha256:sha(afterProfile),
     rngBeforeTrain:JSON.parse(beforeProfile).seed,rngAfterTrain:JSON.parse(afterProfile).seed,
     observedException:policy.rest?{id:policy.rest,before:before.squad.find(p=>p.id===policy.rest),after:after.squad.find(p=>p.id===policy.rest)}:null};
    w.go('snapshot');w.go('export');assert.deepEqual(w.bytes(),afterProfile,'Read-only collection preserves the actual result profile, saved RNG and clock');
    row.readOnlyCollectionPreservedProfile=true;report.cases.push(row);
    if(policy.id==='normal'){
     const previous=publicModel(w.model),prior=w.bytes(),repeat=w.send('train',{mode:'normal'});const current=publicModel(w.model);
     assert.deepEqual(w.bytes(),prior,'Repeated or refused training cannot charge, train or reroll again');
     report.cases.push({id:'normal_repeat',mode:'normal',ok:repeat.ok,error:repeat.error??null,before:previous,after:current,expected:expected(previous,current),noNewReceipt:true,profileUnchanged:true});
    }
   }finally{w.close();}
  }
  const uniform=report.cases.find(c=>c.id==='intense').after.squad.find(p=>p.id===tired.id),exception=report.cases.find(c=>c.id==='intense_exception_repos').after.squad.find(p=>p.id===tired.id);
  assert.ok(exception.physicalLoad<uniform.physicalLoad,'The public individual rest exception is actually applied');
  report.individualRestActuallyObserved={playerId:tired.id,collectiveIntense:{condition:uniform.condition,physicalLoad:uniform.physicalLoad},withRestException:{condition:exception.condition,physicalLoad:exception.physicalLoad}};
  report.complete=true;fs.mkdirSync(path.dirname(output),{recursive:true});fs.writeFileSync(output,JSON.stringify(report,null,2)+'\n');return report;
 }finally{base?.close();fs.rmSync(temp,{recursive:true,force:true});}
}
if(require.main===module){const output=path.resolve(process.argv.find(a=>a.startsWith('--output='))?.slice(9)||'work/observed-training-consequences.json');const report=collect(output);console.log(JSON.stringify({output,cases:report.cases.length,exception:report.individualRestActuallyObserved}));}
module.exports={collect};

'use strict';
process.env.CD_MODES_HERITES='1'; // Anciens modes de carrière (non-Monde) : test à migrer vers le mode Monde.
const {settleClubMeetings}=require('./helpers/club-meetings.cjs');
const {refuseSavePublication}=require('./helpers/save-publication-refusal.cjs');
// Witness: delegate branch captured verbatim from worker.cjs at f88e16fd.
// Only disposable worker fixtures are rewritten; no runtime optimisation switch.
const {test}=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),os=require('node:os'),path=require('node:path'),crypto=require('node:crypto'),Module=require('node:module');
const {spawnSync}=require('node:child_process');
const ROOT=path.resolve(__dirname,'..'),WORKER=path.join(ROOT,'native/engine/worker.cjs');
const LEGACY_DELEGATE="     }else if(command==='delegate'){\n      if(!run('!!S.live'))throw Error('Aucun match à déléguer.');\n      run(\"for(let steps=0;!S.live.finished;steps++){if(steps>=3000)throw Error('Limite de délégation atteinte.');if(S.live.paused)continueMatch();else tick();}\");\n";
const LEGACY_SHA256="a2dade2a6565cdb471249d0f7d9d5ea5c65f9aab89712b80a2df479036f84e4b";
const source=fs.readFileSync(WORKER,'utf8').replace(/\r\n/g,'\n');
const start="     }else if(command==='delegate'){",end="     }else if(command==='finish_round'){";
assert.equal(source.split(start).length,2,'Unique delegate branch required');
assert.equal(source.split(end).length,2,'Unique following branch required');
assert.equal(crypto.createHash('sha256').update(LEGACY_DELEGATE).digest('hex'),LEGACY_SHA256,'Historical witness must remain verbatim');
const left=source.indexOf(start),right=source.indexOf(end,left),current=source.slice(left,right);
const historical=source.slice(0,left)+LEGACY_DELEGATE+source.slice(right);
const loop="for(let steps=0;!S.live.finished;steps++){if(steps>=3000)throw Error('Limite de délégation atteinte.');if(S.live.paused)continueMatch();else tick();}";
const hooks={
 ordinary:'',
 read_after_tick:"if(steps===2)S.contractSeen=JSON.parse(gameStorage.getItem('bdt-v1')).round;",
 save_mutate_read:"if(steps===2){S.contractProbe=1;save();S.contractProbe=2;const seen=JSON.parse(gameStorage.getItem('bdt-v1')).contractProbe;if(seen!==1)throw Error('Le lecteur doit voir le dernier save');S.contractSeen=seen;delete S.contractProbe;}",
 caught_read:"if(steps===2){S.contractProbe=1;save();S.contractProbe=2;try{const seen=JSON.parse(gameStorage.getItem('bdt-v1')).contractProbe;if(seen!==1)throw Error('Ancien save perdu');S.contractSeen=seen;}catch(error){S.contractSeen=-999;}delete S.contractProbe;}",
 read_other_key:"if(steps===2)S.contractSeen=gameStorage.getItem('bdt-match-view')===null?0:1;",
 persist_fault:"if(steps===0)S.contractSaveErrorAtTick=lastSaveError;",
 persist_fault_read:"if(steps===0)S.contractSaveErrorAtTick=lastSaveError;if(steps===2)S.contractSeen=JSON.parse(gameStorage.getItem('bdt-v1')).round;",
 invalid_import:'',
 tojson_text:'',
 dynamic_clock:"if(steps===2){S.contractClock=String(Date.now());S.contractSeen=JSON.parse(gameStorage.getItem('bdt-v1')).round;}",
 vm_timeout:"if(steps===2){for(;;){}}"
};
function sha(value){return crypto.createHash('sha256').update(value).digest('hex');}
function checksum(state){const text=JSON.stringify(state);let h=2166136261;for(let i=0;i<text.length;i++)h=Math.imul(h^text.charCodeAt(i),16777619);return (h>>>0).toString(16).padStart(8,'0');}
function sameFile(a,b){
 const aa=fs.openSync(a,'r'),bb=fs.openSync(b,'r'),ba=Buffer.alloc(1024*1024),bc=Buffer.alloc(ba.length);
 try{assert.equal(fs.fstatSync(aa).size,fs.fstatSync(bb).size);for(;;){const n=fs.readSync(aa,ba,0,ba.length,null),m=fs.readSync(bb,bc,0,bc.length,null);assert.equal(n,m);if(!n)break;assert.equal(ba.subarray(0,n).equals(bc.subarray(0,m)),true,'Complete JSON/file bytes must match');}}
 finally{fs.closeSync(aa);fs.closeSync(bb);}
}
function sameCheckpoints(a,b){
 assert.equal(fs.existsSync(a),fs.existsSync(b),'Checkpoint directory availability must match');
 if(!fs.existsSync(a))return;
 const names=fs.readdirSync(a).sort();assert.deepEqual(fs.readdirSync(b).sort(),names,'Every checkpoint path must match');
 for(const name of names){const left=path.join(a,name),right=path.join(b,name),stat=fs.lstatSync(left);assert.equal(fs.lstatSync(right).isDirectory(),stat.isDirectory());if(stat.isDirectory())sameCheckpoints(left,right);else sameFile(left,right);}
}
test('Delegate : transactions JSON, repli de lecture, erreurs et reprises exacts',()=>{
 const scratch=fs.mkdtempSync(path.join(os.tmpdir(),'cd-delegate-transaction-')),app=path.join(scratch,'app'),engine=path.join(app,'native/engine');
 fs.mkdirSync(path.dirname(engine),{recursive:true});fs.cpSync(path.dirname(WORKER),engine,{recursive:true});
 // The two variants exercise identical checkpoint code, but UUIDs and the real
 // wall-clock creation date are deliberately fresh in production. Give only
 // this disposable copied module a repeatable entropy source. Never remove
 // checkpoint fields from replies or relax complete byte comparisons.
 const safetyFile=path.join(engine,'profile-safety.cjs'),safetySource=fs.readFileSync(safetyFile,'utf8');
 const safetyFactory='function createStore(dataDir) {',safetyDate='createdAt: new Date().toISOString()';
 assert.equal(safetySource.split(safetyFactory).length,2,'Unique checkpoint factory required');
 assert.equal(safetySource.split(safetyDate).length,2,'Unique checkpoint wall-clock date required');
 const fixtureSafety=safetySource.replace(safetyFactory,safetyFactory+`
  let checkpointSequence=0;
  const randomUUID=()=>{let id;do{id='00000000-0000-4000-8000-'+(++checkpointSequence).toString(16).padStart(12,'0');}while(fs.existsSync(path.join(dataDir,'Copies-securite',id)));return id;};
 `).replace(safetyDate,'createdAt: new Date(1700000000000+checkpointSequence).toISOString()');
 fs.writeFileSync(safetyFile,fixtureSafety);
 const fixtureWorker=path.join(engine,'worker.cjs'),dist=path.join(ROOT,'dist');
 fs.symlinkSync(dist,path.join(app,'dist'),process.platform==='win32'?'junction':'dir');
 const own=file=>{const resolved=path.resolve(file);assert.ok(resolved.startsWith(path.resolve(scratch)+path.sep));return resolved;};
 function load(variant,name){
  let text=variant==='historical'?historical:source;
  if(hooks[name]){assert.ok(text.includes(loop));text=text.replaceAll(loop,loop.slice(0,-1)+hooks[name]+'}');}
  if(name==='vm_timeout'){
   const marker='vm.runInContext(source,ctx,{timeout:15000})';assert.equal(text.split(marker).length,2);
   // Genuine interruption, shorter only inside this disposable delegate fixture.
   text=text.replace(marker,"vm.runInContext(source,ctx,{timeout:source.startsWith('for(let steps=0;')?25:15000})");
  }
  const loaded=new Module(fixtureWorker,module);loaded.filename=fixtureWorker;loaded.paths=Module._nodeModulePaths(engine);loaded._compile(text,fixtureWorker);return loaded.exports;
 }
 // Prepare a valid late-match checkpoint through real commands once. The long
 // existing season suite still plays every complete match; this regression
 // targets transaction boundaries without replaying eleven whole matches.
 const checkpoint=path.join(scratch,'checkpoint');let checkpointModel,setupCommands=0;
 {
  const setup=load('historical','ordinary').createBridge({dataDir:checkpoint,seed:411,now:1700000000000});
  const send=(command,payload={})=>{const r=setup.handle({id:++setupCommands,command,payload});assert.equal(r.ok,true,command+': '+r.error);return r.model;};
  try{
   settleClubMeetings(send('new_career',{mode:'common',club:29}),send);send('train');send('auto_lineup');
   const support=send('snapshot').clubLife.clubSupport;send('strategic_briefing',{context:support.context,fixture:support.briefing.fixture,plan:'espaces'});checkpointModel=send('begin_match');
   // This byte-for-byte witness exercises the historical delegate branch on
   // an old live save. Import that explicit legacy fixture through the real
   // validator; never weaken the new causerie guards or rewrite the witness.
   const legacy=JSON.parse(send('export').meta.exportText);delete legacy.state.contextualMatch;delete legacy.state.clubMeetings;legacy.checksum=checksum(legacy.state);
   checkpointModel=send('import',{text:JSON.stringify(legacy)});
   assert.equal(JSON.parse(send('export').meta.exportText).state.contextualMatch,undefined);assert.equal(JSON.parse(send('export').meta.exportText).state.clubMeetings,undefined);
   for(let steps=0;checkpointModel.live.minute<72&&steps<40;steps++){
    if(checkpointModel.live.paused)checkpointModel=send('pause',{paused:false});
    checkpointModel=send('tick',{steps:Math.min(16,72-checkpointModel.live.minute)});
   }
   assert.equal(checkpointModel.live.finished,false);assert.ok(checkpointModel.live.minute>=72,JSON.stringify({minute:checkpointModel.live.minute,paused:checkpointModel.live.paused,period:checkpointModel.live.period,atBreak:checkpointModel.live.atBreak,commands:setupCommands}));assert.equal(checkpointModel.live.period,2);
  }finally{setup.close();}
 }
 function scenario(variant,name,profile,out){
  fs.mkdirSync(out,{recursive:true});const worker=load(variant,name),responses=path.join(out,'responses.jsonl');
  const actualNow=Date.now;let wall=1700000000000,clockFrozen=false,b=null,n=0,lastExport='';Date.now=()=>wall;
  const options={dataDir:profile,seed:411};if(name!=='dynamic_clock')options.now=1700000000000;
  const request=(command,payload={})=>{if(!clockFrozen)wall+=1000;const r=b.handle({id:++n,command,payload});fs.appendFileSync(responses,JSON.stringify(r)+'\n');if(command==='export'&&r.ok)lastExport=r.model.meta.exportText;return r;};
  const good=(command,payload)=>{const r=request(command,payload);assert.equal(r.ok,true,name+'/'+variant+'/'+command+': '+r.error);return r.model;};
  const exportNow=()=>good('export').meta.exportText;
  try{
   fs.cpSync(checkpoint,profile,{recursive:true});b=worker.createBridge(options);assert.equal(request('tick',{steps:0}).ok,false);
   if(name==='invalid_import'||name==='tojson_text'){
    const original=exportNow(),doc=JSON.parse(original);
    if(name==='invalid_import'){
     assert.equal(request('import',{text:'{invalid'}).ok,false);assert.equal(exportNow(),original);
     Object.defineProperty(doc.state,'__proto__',{value:{polluted:true},enumerable:true});doc.checksum=checksum(doc.state);
     assert.equal(request('import',{text:JSON.stringify(doc)}).ok,false);assert.equal(exportNow(),original);assert.equal({}.polluted,undefined);
    }else{doc.state.contractText={toJSON:'Une donnée, pas une fonction',note:'Texte importé'};doc.checksum=checksum(doc.state);good('import',{text:JSON.stringify(doc)});}
   }
   assert.equal(good('snapshot').live.finished,false);
   const before=exportNow(),file=path.join(profile,'PrototypeGodot/donnees.json'),disk=fs.readFileSync(file);
   if(name.startsWith('persist_fault')){
    assert.equal(refuseSavePublication(file,()=>request('delegate')).ok,false);
    assert.equal(exportNow(),before);assert.deepEqual(fs.readFileSync(file),disk);
   }
   const delegated=request('delegate');
   if(name==='vm_timeout'){
    assert.equal(delegated.ok,false);assert.match(delegated.error,/timed out after 25ms/);assert.equal(exportNow(),before);assert.deepEqual(fs.readFileSync(file),disk);
    good('tick',{steps:1});good('pause',{paused:true});exportNow();
   }else{
    assert.equal(delegated.ok,true,name+'/'+variant+': '+delegated.error);good('finish_round');
    // First exercise real command-clock changes and fallback. Freeze only the
    // following roundtrip so its exportedAt legitimately stays unchanged.
    if(name==='dynamic_clock'){wall=JSON.parse(fs.readFileSync(file,'utf8')).clock;clockFrozen=true;}
    const text=exportNow();good('import',{text});assert.equal(exportNow(),text);
   }
   const expected=lastExport;good('shutdown');
   b=worker.createBridge({dataDir:profile,...(name==='dynamic_clock'?{}:{now:1700000000000})});assert.equal(exportNow(),expected);
   fs.writeFileSync(path.join(out,'export.json'),lastExport);fs.copyFileSync(file,path.join(out,'donnees.json'));
   const persisted=JSON.parse(fs.readFileSync(file,'utf8'));
   return {responses:n,seed:persisted.seed,clock:persisted.clock};
  }finally{try{if(b)b.close();}finally{Date.now=actualNow;}}
 }
 const rows=[];
 for(const name of Object.keys(hooks)){
  const caseRoot=path.join(scratch,name),profile=path.join(caseRoot,'profile');fs.mkdirSync(caseRoot);
  const before=scenario('historical',name,profile,path.join(caseRoot,'historical'));
  const moved=own(path.join(caseRoot,'historical-profile'));assert.equal(fs.existsSync(moved),false);fs.renameSync(own(profile),moved);
  const after=scenario('current',name,profile,path.join(caseRoot,'current'));
  for(const file of ['responses.jsonl','export.json','donnees.json'])sameFile(path.join(caseRoot,'historical',file),path.join(caseRoot,'current',file));
  sameCheckpoints(path.join(moved,'PrototypeGodot','Copies-securite'),path.join(profile,'PrototypeGodot','Copies-securite'));
  assert.deepEqual(after,before);rows.push({name,...after});console.log('Delegate contract received: '+name);
 }
 // Real stdio parser: no request can contain functions or getters. Unknown code
 // strings are commands rejected by the allowlist, never evaluated as source.
 const cliRoot=path.join(scratch,'stdio'),profile=path.join(cliRoot,'profile');fs.mkdirSync(cliRoot);
 const clockFixture=path.join(cliRoot,'clock.cjs');fs.writeFileSync(clockFixture,"'use strict';Date.now=()=>1700000000000;\n");
 const lines=[JSON.stringify({id:1,command:'new_career',payload:{mode:'common',club:29}}),JSON.stringify({id:2,command:'snapshot',payload:JSON.parse('{"toJSON":"texte","__proto__":{"polluted":true}}')}),JSON.stringify({id:3,command:'delegate; process.exit(7)',payload:{}}),'{invalid}',JSON.stringify({id:4,command:'shutdown'})].join('\n')+'\n';
 // Keep complete catalogue replies on disk, outside spawnSync's bounded pipes.
 const stdioBytes=[];
 let firstOutput,firstProfile;
 for(const variant of ['historical','current']){
  fs.writeFileSync(fixtureWorker,variant==='historical'?historical:source);
  const stdoutFile=path.join(cliRoot,variant+'-stdout.jsonl'),stderrFile=path.join(cliRoot,variant+'-stderr.log');
  const stdoutFd=fs.openSync(stdoutFile,'wx'),stderrFd=fs.openSync(stderrFile,'wx');
  let result;
  try{
   result=spawnSync(process.execPath,['--require',clockFixture,fixtureWorker,'--data-dir',profile],{input:lines,env:{...process.env,CD_GODOT_SEED:'411'},windowsHide:true,timeout:30000,stdio:['pipe',stdoutFd,stderrFd]});
  }finally{fs.closeSync(stdoutFd);fs.closeSync(stderrFd);}
  const stderr=fs.readFileSync(stderrFile,'utf8');
  stdioBytes.push({variant,stdout:fs.statSync(stdoutFile).size,stderr:fs.statSync(stderrFile).size});
  assert.equal(result.error,undefined);assert.equal(result.status,0,stderr);assert.equal(stderr,'');
  const parsed=fs.readFileSync(stdoutFile,'utf8').trim().split('\n').map(line=>JSON.parse(line));assert.deepEqual(parsed.map(item=>item.ok),[true,true,false,false,true]);
  assert.equal(parsed[2].error,'Commande inconnue ou interdite.');assert.equal(parsed[3].model,null);
  const profileBytes=fs.readFileSync(path.join(profile,'PrototypeGodot/donnees.json'));
  if(firstOutput){sameFile(stdoutFile,firstOutput);assert.deepEqual(profileBytes,firstProfile,'Complete stdio profile');}else{firstOutput=stdoutFile;firstProfile=profileBytes;}
  const moved=own(path.join(cliRoot,variant+'-profile'));assert.equal(fs.existsSync(moved),false);fs.renameSync(own(profile),moved);
 }
 fs.writeFileSync(path.join(scratch,'report.json'),JSON.stringify({cases:rows,stdio:true,stdioCapture:'file',stdioBytes,checkpointCopiesBytewise:true,fixtureCheckpointEntropy:true,checkpointModuleSha256:sha(safetySource),fixtureCheckpointModuleSha256:sha(fixtureSafety),checkpoint:{minute:checkpointModel.live.minute,period:checkpointModel.live.period,setupCommands},historicalOrigin:'f88e16fdbbffec38c1259f21a156ac6217374b12',historicalBranchSha256:LEGACY_SHA256,currentWorkerSha256:sha(source),currentDelegateSha256:sha(current)},null,2));
 console.log('Delegate transaction : '+rows.length+' cas appariés complets + stdio, checkpoint réel '+checkpointModel.live.minute+'min, aucune normalisation des réponses/exports/profils ; '+scratch);
});

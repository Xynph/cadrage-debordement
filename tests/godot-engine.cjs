'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {spawn}=require('node:child_process');
const workerPath=path.resolve(__dirname,'../native/engine/worker.cjs');
assert.ok(fs.existsSync(workerPath),'Le worker Godot de production doit exister');
const {createBridge,CORE_FILES}=require(workerPath),{context}=require('./native-reference-harness.cjs');
assert.ok(fs.existsSync(path.resolve(__dirname,'../native/godot/engine_bridge.gd')),'Le pont Godot asynchrone doit exister');
const root=fs.mkdtempSync(path.join(os.tmpdir(),'cd-godot-test-'));
let count=0;const bridges=[];
function bridge(name,extra={}){const b=createBridge({dataDir:path.join(root,name),seed:827381,now:1700000000000,...extra});bridges.push(b);return b;}
function call(b,command,payload={}){return b.handle({id:++count,command,payload});}
function good(b,command,payload={}){const r=call(b,command,payload);assert.equal(r.ok,true,r.error);assert.equal(r.id,count);return r.model;}
if(process.argv.includes('--storage-review')){
 reviewStorage().then(()=>console.log('STORAGE_REVIEW_PASS')).catch(e=>{console.error(e);process.exitCode=1;});
}else{
try{
 const b=bridge('main');
 for(const request of [null,{command:'snapshot'},{id:[],command:'snapshot'},{id:1,command:'eval',payload:{code:'process.exit()'}},{id:1,command:'snapshot',payload:[]}])assert.equal(b.handle(request).ok,false);
 assert.equal(good(b,'snapshot').club,null);
 const initial=good(b,'new_career',{club:0});assert.equal(initial.protocol,1);assert.equal(initial.league.length,14);assert.equal(initial.squad.length,30);assert.equal(initial.meta.catalogue.length,30);assert.equal(initial.meta.catalogue.filter(c=>c.playable).length,30);
 assert.equal(Object.keys(initial.squad[0].attributes).length,11);assert.ok(initial.squad[0].portraitIndex<32);
 assert.equal(initial.squad[0].portraitIndex,0,'Même index de portrait que CDEditorial pour les identifiants natifs');
 // new_career initializes the native staff cycle after the shared start().
 // Exercise the same initialization in the direct reference before comparing
 // the complete state, without the bridge, protocol or disk transactions.
 const direct=context({dataDir:path.join(root,'reference')});direct.run('start(0);CDStaffCareer.initialize(S)');
 const assertRng=()=>assert.equal(JSON.parse(fs.readFileSync(path.join(initial.meta.dataDir,'donnees.json'),'utf8')).seed,direct.randomState().seed,'curseur RNG identique à la référence native directe');
 let document=JSON.parse(good(b,'export').meta.exportText);assert.deepEqual(document.state,JSON.parse(direct.run('JSON.stringify(createSaveDocument().state)')),'état initial identique au moteur direct');
 assertRng();
 const before=good(b,'export').meta.exportText;for(let i=0;i<6;i++)good(b,'snapshot');assert.equal(good(b,'export').meta.exportText,before,'snapshot/export ne consomment pas le RNG');
 good(b,'train',{mode:'normal'});direct.run('trainWeek();save()');assert.equal(good(b,'train').meta.trained,true);
 assertRng();
 good(b,'auto_lineup');direct.run('autoLineup()');
 assertRng();
 const live=good(b,'begin_match').live;direct.run('beginMatch()');assert.equal(live.scene.players.length,30);assert.equal(live.teams.length,2);assert.equal(typeof live.teams[0].presentation.stadium,'string');assert.equal(live.statsRows[0].label,'Possession');
 assertRng();
 for(let i=0;i<15;i++){good(b,'snapshot');good(b,'tick');direct.run('tick()');}
 document=JSON.parse(good(b,'export').meta.exportText);assert.deepEqual(document.state,JSON.parse(direct.run('JSON.stringify(createSaveDocument().state)')),'ticks identiques au moteur direct malgré snapshots');
 assertRng();
 const scene=good(b,'snapshot').live.scene;direct.run(require('node:fs').readFileSync(path.resolve(__dirname,'../dist/match3d/scene-adapter.js'),'utf8'));assert.deepEqual(scene,JSON.parse(direct.run('JSON.stringify(CDMatch3DAdapter.normalize(matchScene(S.live)))')));
 good(b,'pause');assert.equal(good(b,'snapshot').live.paused,true);const minute=good(b,'snapshot').live.minute;good(b,'tick');assert.equal(good(b,'snapshot').live.minute,minute);good(b,'pause',{paused:false});
 good(b,'delegate');direct.run('while(!S.live.finished){if(S.live.paused)continueMatch();else tick()}');assert.equal(good(b,'snapshot').live.finished,true);assert.deepEqual(JSON.parse(good(b,'export').meta.exportText).state,JSON.parse(direct.run('JSON.stringify(createSaveDocument().state)')));
 assertRng();
 good(b,'finish_round');direct.run('finishRound()');assert.equal(good(b,'snapshot').meta.round,1);assert.deepEqual(JSON.parse(good(b,'export').meta.exportText).state,JSON.parse(direct.run('JSON.stringify(createSaveDocument().state)')));
 assertRng();
 const saved=good(b,'save');assert.ok(fs.existsSync(path.join(saved.meta.dataDir,'donnees.json')));assert.ok(fs.existsSync(path.join(saved.meta.dataDir,'donnees-precedentes.json')));
 const exported=good(b,'export').meta.exportText;assert.equal(call(b,'import',{text:'{}'}).ok,false);assert.equal(good(b,'export').meta.exportText,exported);
 assert.throws(()=>bridge('main'),/utilisé|verrou/i,'double ouverture refusée');
 good(b,'shutdown');assert.equal(call(b,'train').ok,false);const restored=bridge('main');assert.equal(good(restored,'snapshot').meta.round,1);assert.deepEqual(JSON.parse(good(restored,'export').meta.exportText).state,JSON.parse(exported).state);
 const incoming=bridge('incoming');good(incoming,'new_career',{club:13});const incomingText=good(incoming,'export').meta.exportText;good(restored,'import',{text:incomingText});assert.equal(good(restored,'snapshot').club.id,13);
 // A real filesystem failure at the destination must leave memory and disk intact.
 const fail=bridge('write-failure');const fm=good(fail,'new_career',{club:0}),file=path.join(fm.meta.dataDir,'donnees.json');const original=fs.readFileSync(file,'utf8');
 fs.renameSync(file,file+'.held');fs.mkdirSync(file);const failed=call(fail,'train',{mode:'intense'});assert.equal(failed.ok,false);assert.match(failed.error,/sauvegarde|EISDIR|EPERM|EACCES/i);assert.equal(good(fail,'snapshot').meta.trained,false);
 assert.equal(call(fail,'import',{text:incomingText}).ok,false);assert.equal(good(fail,'snapshot').club.id,0);fs.rmdirSync(file);fs.renameSync(file+'.held',file);assert.equal(fs.readFileSync(file,'utf8'),original);
 good(fail,'train',{mode:'normal'});assert.equal(good(fail,'snapshot').meta.trained,true);
 // Import an actual live native export: use the production kickoff path, which
 // prepares valid AI cover before creating a live (the bare shared beginMatch
 // is not the native command). Restart paused, score/fitness preserved.
 const liveSource=bridge('live-import-source');good(liveSource,'import',{text:exported});good(liveSource,'begin_match');good(liveSource,'tick',{steps:2});
 const liveText=good(liveSource,'export').meta.exportText;good(restored,'import',{text:liveText});assert.equal(good(restored,'snapshot').live.paused,true);
 assert.deepEqual(JSON.parse(good(restored,'export').meta.exportText).state,JSON.parse(liveText).state);
 const staleRoot=path.join(root,'stale','PrototypeGodot');fs.mkdirSync(staleRoot,{recursive:true});fs.writeFileSync(path.join(staleRoot,'profil.lock'),'2147483647');const recovered=bridge('stale');assert.equal(good(recovered,'snapshot').club,null,'verrou PID disparu récupérable après fermeture forcée');
 // The private profile preserves the RNG cursor as well as the native career.
 const seeded=bridge('seeded');good(seeded,'new_career',{club:0});good(seeded,'begin_match');good(seeded,'tick',{steps:12});good(seeded,'pause');good(seeded,'save');
 const copyRoot=path.join(root,'seeded-copy','PrototypeGodot');fs.mkdirSync(copyRoot,{recursive:true});fs.copyFileSync(path.join(root,'seeded','PrototypeGodot','donnees.json'),path.join(copyRoot,'donnees.json'));
 good(seeded,'shutdown');const seededResume=bridge('seeded'),seededCopy=bridge('seeded-copy');for(const item of [seededResume,seededCopy]){good(item,'pause',{paused:false});good(item,'delegate');}assert.deepEqual(JSON.parse(good(seededResume,'export').meta.exportText).state,JSON.parse(good(seededCopy,'export').meta.exportText).state,'RNG persistant après redémarrage');
 console.log(JSON.stringify({passed:true,checks:['bounded protocol','real native state/export/action parity','snapshot RNG invariance','normalized scene parity','delegated match parity','atomic persistence/restart','import rollback','real disk write refusal','profile lock','live paused import','closed commands']}));
}finally{for(const b of bridges)b.close();fs.rmSync(root,{recursive:true,force:true});}

// Exercise the actual private JSON-lines pipes, including malformed input and clean exit.
(async()=>{const dir=fs.mkdtempSync(path.join(os.tmpdir(),'cd-godot-pipe-'));const child=spawn(process.execPath,[workerPath,'--data-dir',dir],{stdio:['pipe','pipe','pipe']});let stdout='',stderr='';child.stdout.on('data',d=>stdout+=d);child.stderr.on('data',d=>stderr+=d);child.stdin.end('invalid\n'+JSON.stringify({id:'a',command:'snapshot'})+'\n'+JSON.stringify({id:'z',command:'shutdown'})+'\n');const code=await new Promise((resolve,reject)=>{child.on('error',reject);child.on('exit',resolve);});assert.equal(code,0,stderr);const lines=stdout.trim().split('\n').map(JSON.parse);assert.equal(lines.length,3);assert.equal(lines[0].ok,false);assert.equal(lines[1].id,'a');assert.equal(lines[2].ok,true);assert.equal(stderr,'');fs.rmSync(dir,{recursive:true,force:true});console.log('JSON-lines process: PASS');
 if(process.env.CD_GODOT_EXECUTABLE)await godotTest();else console.log('Godot runtime: NON EXÉCUTÉ (CD_GODOT_EXECUTABLE absent)');
})().catch(e=>{console.error(e);process.exitCode=1;});
}

async function reviewStorage(){
 const temp=fs.mkdtempSync(path.join(os.tmpdir(),'cd-storage-review-')),exportRoot=path.join(temp,'app'),engine=path.join(exportRoot,'engine');
 const children=[];
 try{
  fs.mkdirSync(path.join(engine,'core'),{recursive:true});
  for(const name of ['worker.cjs','model.cjs'])fs.copyFileSync(path.join(path.dirname(workerPath),name),path.join(engine,name));
  for(const name of CORE_FILES){const target=path.join(engine,'core',name);fs.mkdirSync(path.dirname(target),{recursive:true});fs.copyFileSync(path.resolve(__dirname,'../dist',name),target);}
  const exported=require(path.join(engine,'worker.cjs'));
  const valid=exported.createBridge({dataDir:path.join(temp,'outside')});assert.equal(valid.handle({id:1,command:'snapshot'}).ok,true);valid.close();
  const driveRoot=process.platform==='win32'?'C:\\app':'/app';
  assert.equal(exported.applicationRoot(path.join(driveRoot,'engine')),driveRoot,'racine exportée au premier niveau du lecteur');
  assert.equal(exported.applicationRoot(path.join(driveRoot,'native','engine')),driveRoot,'racine développement explicite');
  assert.throws(()=>exported.createBridge({dataDir:path.join(exportRoot,'..profil')}),/hors du dossier/,'deux points dans un nom ne sont pas un chemin parent');
  const junction=path.join(temp,'junction');fs.symlinkSync(exportRoot,junction,process.platform==='win32'?'junction':'dir');
  assert.throws(()=>exported.createBridge({dataDir:path.join(junction,'hidden')}),/hors du dossier/,'jonction entrante dans le bundle refusée');
  console.log('I1 PASS: exported layout + drive root + ..profil + physical junction containment');
  // Force A to pause after observing the dead PID. B must be excluded from
  // the entire stale-lock acquisition, not only its final open("wx").
  const profile=path.join(temp,'race','PrototypeGodot'),release=path.join(temp,'release');fs.mkdirSync(profile,{recursive:true});fs.writeFileSync(path.join(profile,'profil.lock'),'2147483647');
  const childSource=`const fs=require('fs');const realKill=process.kill.bind(process);let bridge;
   if(process.env.PAUSE_STALE==='1')process.kill=(pid,signal)=>{try{return realKill(pid,signal)}catch(e){if(pid===2147483647&&e.code==='ESRCH'){process.send({type:'observed'});const end=Date.now()+10000;while(!fs.existsSync(process.env.RELEASE)){if(Date.now()>end)throw Error('barrier timeout');Atomics.wait(new Int32Array(new SharedArrayBuffer(4)),0,0,5);}}throw e;}};
   process.on('message',m=>{if(m==='exit'){try{if(bridge)bridge.close();process.send({type:'closed'});}catch(e){process.send({type:'closed',error:e.message});}process.exit();}else if(m==='write'){const r=bridge.handle({id:1,command:'new_career',payload:{club:0}});process.send({type:'write',ok:r.ok,error:r.error});}});
   try{bridge=require(process.env.WORKER).createBridge({dataDir:process.env.PROFILE});process.send({type:'opened',ok:true});}catch(e){process.send({type:'opened',ok:false,error:e.message});}`;
  const launch=pause=>{const child=spawn(process.execPath,['-e',childSource],{env:{...process.env,WORKER:workerPath,PROFILE:profile,RELEASE:release,PAUSE_STALE:pause?'1':'0'},stdio:['ignore','pipe','pipe','ipc']});children.push(child);child.received=[];child.on('message',m=>child.received.push(m));return child;};
  const wait=async(child,type)=>{const end=Date.now()+10000;while(Date.now()<end){const result=child.received.find(m=>m.type===type);if(result)return result;await new Promise(resolve=>setTimeout(resolve,5));}throw Error('Timeout '+type);};
  const a=launch(true);await wait(a,'observed');const b=launch(false);assert.equal((await wait(b,'opened')).ok,false,'B ne doit pas récupérer pendant l’acquisition A');
  fs.writeFileSync(release,'go');assert.equal((await wait(a,'opened')).ok,true);const owned=fs.readFileSync(path.join(profile,'profil.lock'),'utf8');
  b.send('exit');await wait(b,'closed');assert.equal(fs.readFileSync(path.join(profile,'profil.lock'),'utf8'),owned,'le perdant ne retire pas le verrou du gagnant');
  const c=launch(false);assert.equal((await wait(c,'opened')).ok,false,'un troisième processus doit rester exclu');a.send('write');assert.equal((await wait(a,'write')).ok,true);assert.equal(fs.readFileSync(path.join(profile,'profil.lock'),'utf8'),owned);
  console.log('I2 PASS: deterministic stale recovery race + loser cleanup + third writer refused + winner disk write');
  const ownership=createBridge({dataDir:path.join(temp,'ownership')}),ownedPath=path.join(temp,'ownership','PrototypeGodot','profil.lock');fs.unlinkSync(ownedPath);fs.writeFileSync(ownedPath,'new-owner');assert.throws(()=>ownership.close(),/propriét|appart|verrou/i);assert.equal(fs.readFileSync(ownedPath,'utf8'),'new-owner','close ne supprime jamais un verrou remplacé');
  console.log('I2 PASS: close preserves a lock whose ownership changed');
  const abandoned=path.join(temp,'abandoned','PrototypeGodot','profil.acquisition');fs.mkdirSync(abandoned,{recursive:true});fs.writeFileSync(path.join(abandoned,'owner'),'abandoned');assert.throws(()=>createBridge({dataDir:path.join(temp,'abandoned')}),/verrou/);assert.equal(fs.readFileSync(path.join(abandoned,'owner'),'utf8'),'abandoned');
  if(process.env.CD_GODOT_EXECUTABLE)await godotEofTest();
 }finally{
  for(const child of children){if(child.connected)child.send('exit');}
  await Promise.all(children.map(child=>child.exitCode!==null?Promise.resolve():new Promise(resolve=>{const timeout=setTimeout(()=>{child.kill();resolve();},2000);child.once('exit',()=>{clearTimeout(timeout);resolve();});})));
  fs.rmSync(temp,{recursive:true,force:true});fs.rmSync(root,{recursive:true,force:true});
 }
}

async function godotEofTest(){
 const temp=fs.mkdtempSync(path.join(os.tmpdir(),'cd-godot-eof-')),fake=path.join(temp,'exit.cjs');
 fs.writeFileSync(fake,"process.stdin.once('data',()=>process.exit(0));");
 fs.writeFileSync(path.join(temp,'project.godot'),'config_version=5\n[application]\nconfig/name="EOF test"\n[native_engine]\nworker_path='+JSON.stringify(fake.replaceAll('\\','/'))+'\n');
 fs.copyFileSync(path.resolve(__dirname,'../native/godot/engine_bridge.gd'),path.join(temp,'engine_bridge.gd'));
 fs.writeFileSync(path.join(temp,'test.gd'),`extends SceneTree
var bridge: Node
var failed := false
var frames := 0
func _initialize():
 bridge = load("res://engine_bridge.gd").new()
 root.add_child.call_deferred(bridge)
 bridge.command_failed.connect(func(_message): failed = true)
 _begin.call_deferred()
func _begin():
 bridge.start(${JSON.stringify(temp.replaceAll('\\','/')+'/profile')})
func _process(_delta):
 frames += 1
 if failed and bridge.child_pid == -1:
  print("GODOT_EOF_PASS")
  quit(0)
 if frames > 1000:
  quit(1)
 return false
`);
 const child=spawn(process.env.CD_GODOT_EXECUTABLE,['--headless','--path',temp,'--script','test.gd'],{env:{...process.env,CD_NODE_EXECUTABLE:process.execPath},stdio:['ignore','pipe','pipe']});let output='',errors='';child.stdout.on('data',d=>output+=d);child.stderr.on('data',d=>errors+=d);
 const timer=setTimeout(()=>child.kill(),10000);const code=await new Promise((resolve,reject)=>{child.on('error',reject);child.on('exit',resolve);});clearTimeout(timer);
 try{assert.equal(code,0,output+'\n'+errors);assert.match(output,/GODOT_EOF_PASS/);assert.doesNotMatch(errors,/SCRIPT ERROR|Parse Error|ERROR:/);console.log('EOF PASS: explicit command_failed, no Godot parser error, child terminated');}finally{fs.rmSync(temp,{recursive:true,force:true});}
}

async function godotTest(){
 const temp=fs.mkdtempSync(path.join(os.tmpdir(),'cd-godot-runtime-'));
 const settings='config_version=5\n[application]\nconfig/name="Bridge test"\n[native_engine]\nworker_path='+JSON.stringify(workerPath.replaceAll('\\','/'))+'\n';
 fs.writeFileSync(path.join(temp,'project.godot'),settings);fs.copyFileSync(path.resolve(__dirname,'../native/godot/engine_bridge.gd'),path.join(temp,'engine_bridge.gd'));
 fs.writeFileSync(path.join(temp,'test.gd'),`extends SceneTree
var bridge: Node
var frames := 0
var stage := 0
var pid := -1
var small_export := ""
var large_export := ""
func _initialize():
 bridge = load("res://engine_bridge.gd").new()
 root.add_child.call_deferred(bridge)
 bridge.model_changed.connect(_model)
 bridge.command_failed.connect(_failed)
 _begin.call_deferred()
func _begin():
 bridge.start(${JSON.stringify(temp.replaceAll('\\','/')+'/profile')})
 pid = bridge.child_pid
func _process(_delta):
 frames += 1
 if frames > 6000:
  _failed("Timeout runtime")
 if stage == 5 and bridge.child_pid == -1:
  if frames < 3 or OS.is_process_running(pid):
   _failed("Pont bloquant ou enfant encore actif")
  else:
   print("GODOT_BRIDGE_PASS frames=", frames)
   quit(0)
 return false
func _model(model):
 match stage:
  0:
   stage = 1
   bridge.send("new_career", {"club": 0})
  1:
   if model.squad.size() != 30:
    _failed("Effectif")
    return
   stage = 2
   bridge.send("export")
  2:
   stage = 3
   small_export = model.meta.exportText
   var padding = JSON.stringify("\\\\".repeat(3*1024*1024))
   var text = small_export.trim_suffix("}") + ',"padding":' + padding + "}"
   text += " ".repeat(8*1024*1024-text.to_utf8_buffer().size())
   bridge.send("import", {"text": text})
  3:
   stage = 30
   bridge.send("import", {"text": "x".repeat(8*1024*1024+1)})
  31:
   var fixture = OS.get_environment("CD_SAVE_LIMIT_REPRO_EXPORT")
   if not fixture.is_empty():
    large_export = FileAccess.get_file_as_string(fixture)
    if large_export.to_utf8_buffer().size() <= 5*1024*1024:
     _failed("Fixture longue réelle insuffisante")
     return
    stage = 32
    bridge.send("import", {"text": large_export})
   else:
    stage = 4
    bridge.send("begin_match")
  32:
   stage = 33
   bridge.send("export")
  33:
   if JSON.parse_string(model.meta.exportText).state != JSON.parse_string(large_export).state:
    _failed("Etat réelS28 altéré via pont Godot")
    return
   print("GODOT_S28_IMPORT_PASS bytes=",large_export.to_utf8_buffer().size())
   stage = 34
   bridge.send("import", {"text": small_export})
  34:
   stage = 4
   bridge.send("begin_match")
  4:
   if model.live.scene.players.size() != 30:
    _failed("Scène")
    return
   stage = 5
   bridge.stop()
func _failed(message):
 if stage == 30 and message.contains("8 Mio"):
  stage = 31
  bridge.send("snapshot")
  return
 push_error(message)
 quit(1)
`);
 const child=spawn(process.env.CD_GODOT_EXECUTABLE,['--headless','--audio-driver','Dummy','--path',temp,'--script','test.gd'],{env:{...process.env,CD_NODE_EXECUTABLE:process.execPath},stdio:['ignore','pipe','pipe']});let output='',errors='';child.stdout.on('data',d=>output+=d);child.stderr.on('data',d=>errors+=d);
 const timer=setTimeout(()=>child.kill(),30000);const code=await new Promise((resolve,reject)=>{child.on('error',reject);child.on('exit',resolve);});clearTimeout(timer);
 try{assert.equal(code,0,output+'\n'+errors);assert.match(output,/GODOT_BRIDGE_PASS/);assert.doesNotMatch(errors,/SCRIPT ERROR|Parse Error|ERROR:/);console.log(output.trim());}finally{fs.rmSync(temp,{recursive:true,force:true});}
}

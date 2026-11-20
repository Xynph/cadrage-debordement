'use strict';
// Pont natif Godot ↔ worker en carrière Monde (world-champ, seul mode autorisé) : protocole borné,
// déterminisme (deux workers de même graine, l'un interrogé par des snapshots, restent identiques),
// match délégué (adjoint compris), persistance atomique, verrou, import, refus d'écriture, puis le vrai
// pont Godot. Avant le 16/11/2026, la comparaison se faisait contre la référence directe
// (tests/native-reference-harness.cjs), qui ne sait créer que les anciens modes.
const assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {spawn}=require('node:child_process');
// Un worker Monde fermé ne rend pas toute sa mémoire au processus (plusieurs centaines de Mo chacun) ; le test en ouvre\n// sept l'un après l'autre : il se relance avec un tas de 6 Go plutôt que le plafond par défaut (~4 Go).
if(process.env.CD_GODOT_ENGINE_HEAP!=='1'){const r=require('node:child_process').spawnSync(process.execPath,['--max-old-space-size=6144',__filename,...process.argv.slice(2)],{stdio:'inherit',env:{...process.env,CD_GODOT_ENGINE_HEAP:'1'}});process.exit(r.status??1);}
const workerPath=path.resolve(__dirname,'../native/engine/worker.cjs');
assert.ok(fs.existsSync(workerPath),'Le worker Godot de production doit exister');
const {createBridge,CORE_FILES}=require(workerPath);
const {skipMatchTalk}=require('./helpers/scene-match-talks.cjs');
const {settleClubMeetings}=require('./helpers/club-meetings.cjs');
assert.ok(fs.existsSync(path.resolve(__dirname,'../native/godot/engine_bridge.gd')),'Le pont Godot asynchrone doit exister');
const MONDE={mode:'world-champ',club:102};
// Cadence hebdomadaire (comme tests/helpers/carriere-monde.cjs, `hebdomadaire`) : un match par semaine, sans presse obligatoire.
const HEBDO={dailyCalendar:false,mandatoryPress:false,internationalCareer:false};
const root=fs.mkdtempSync(path.join(os.tmpdir(),'cd-godot-test-'));
let count=0,liveExportFile=null;const bridges=[];
function bridge(name,extra={}){const b=createBridge({dataDir:path.join(root,name),seed:827381,now:1794315600000,...HEBDO,...extra});bridges.push(b);return b;}
function release(b){b.close();bridges.splice(bridges.indexOf(b),1);}
function call(b,command,payload={}){return b.handle({id:++count,command,payload});}
function good(b,command,payload={}){const r=call(b,command,payload);assert.equal(r.ok,true,command+' : '+r.error);assert.equal(r.id,count);return r.model;}
const state=b=>JSON.parse(good(b,'export').meta.exportText).state;
const settle=(b,model=good(b,'snapshot'))=>settleClubMeetings(model,(command,payload)=>good(b,command,payload));
const talk=(b,model)=>skipMatchTalk(model,(command,payload)=>good(b,command,payload));
// Semaines de préparation sans match : rendez-vous réglés, semaine close, jusqu'à la semaine du premier match.
function toMatch(b,model=settle(b)){for(let w=0;w<20&&!model.next;w++)model=settle(b,good(b,'finish_round'));assert.ok(model.next,'aucun match en 20 semaines');return model;}
if(process.argv.includes('--storage-review')){
 reviewStorage().then(()=>console.log('STORAGE_REVIEW_PASS')).catch(e=>{console.error(e);process.exitCode=1;});
}else{
try{
 // Un worker Monde pèse plusieurs centaines de Mo : chaque étape vit dans son propre bloc et rend ses
 // workers (release) ; seuls des textes d'export passent d'une étape à l'autre.
 let exported,liveText,round;
 {
  const b=bridge('main'),twin=bridge('twin');
  const same=message=>assert.deepEqual(state(b),state(twin),message);
  const both=(fn)=>{const r=fn(b);fn(twin);return r;};
  for(const request of [null,{command:'snapshot'},{id:[],command:'snapshot'},{id:1,command:'eval',payload:{code:'process.exit()'}},{id:1,command:'snapshot',payload:[]}])assert.equal(b.handle(request).ok,false);
  assert.equal(good(b,'snapshot').club,null);
  assert.equal(call(b,'new_career',{club:0}).ok,false,'Ancien mode de carrière refusé');assert.equal(good(b,'snapshot').club,null);
  const initial=both(x=>good(x,'new_career',MONDE));assert.equal(initial.protocol,1);assert.equal(initial.club.id,102);assert.equal(initial.league.length,14);assert.ok(initial.squad.length>=23&&initial.squad.every(p=>!p.id.startsWith('depth-')),'club joué : effectif réel, sans joueurs de complément (plus de plancher de 40, décision de Léo du 19/11/2026)');assert.ok(initial.meta.catalogue.filter(c=>c.playable).length>=30);
  assert.equal(Object.keys(initial.squad[0].attributesV2).length,36);assert.ok(Number.isInteger(initial.squad[0].portraitIndex));
  same('création Monde déterministe (même graine, même horloge)');
  const before=good(b,'export').meta.exportText;for(let i=0;i<6;i++)good(b,'snapshot');assert.equal(good(b,'export').meta.exportText,before,'snapshot/export ne consomment pas le RNG');
  assert.equal(call(b,'train').ok,false,'Le worker garde le rendez-vous obligatoire avant progression');
  assert.equal(good(b,'export').meta.exportText,before,'Le garde conserve la carrière');
  const afterMeetings=both(x=>settle(x));
  same('Mêmes vraies réponses de presse et décisions des rendez-vous initiaux');
  assert.ok(afterMeetings.clubLife.clubMeetings.receipts.length>=1,'Les décisions initiales sont réellement enregistrées');
  both(x=>toMatch(x));same('Semaines de préparation identiques');
  both(x=>good(x,'train',{mode:'normal'}));assert.equal(good(b,'train').meta.trained,true);good(twin,'train');
  both(x=>good(x,'auto_lineup'));same('Entraînement et composition identiques');
  const live=both(x=>good(x,'begin_match')).live;assert.equal(live.scene.players.length,30);assert.equal(live.teams.length,2);assert.equal(typeof live.teams[0].presentation.stadium,'string');assert.equal(live.statsRows[0].label,'Possession');
  both(x=>talk(x,good(x,'snapshot')));same('Coup d’envoi identique');
  for(let i=0;i<15;i++){good(b,'snapshot');good(b,'tick');good(twin,'tick');}
  same('ticks identiques malgré snapshots');
  assert.deepEqual(good(b,'snapshot').live.scene,good(twin,'snapshot').live.scene,'scène normalisée identique');
  liveText=good(b,'export').meta.exportText;
  both(x=>good(x,'pause'));assert.equal(good(b,'snapshot').live.paused,true);const minute=good(b,'snapshot').live.minute;both(x=>good(x,'tick'));assert.equal(good(b,'snapshot').live.minute,minute);both(x=>good(x,'pause',{paused:false}));
  both(x=>good(x,'delegate'));assert.equal(good(b,'snapshot').live.finished,true);same('Match délégué identique (adjoint compris)');
  round=good(b,'snapshot').meta.round;
  both(x=>good(x,'finish_round'));assert.equal(good(b,'snapshot').meta.round,round+1);same('Clôture de semaine identique');
  both(x=>settle(x));same('Rendez-vous de la semaine suivante : mêmes décisions et effets réels');release(twin);
  const saved=good(b,'save');assert.ok(fs.existsSync(path.join(saved.meta.dataDir,'donnees.json')));assert.ok(fs.existsSync(path.join(saved.meta.dataDir,'donnees-precedentes.json')));
  exported=good(b,'export').meta.exportText;assert.equal(call(b,'import',{text:'{}'}).ok,false);assert.equal(good(b,'export').meta.exportText,exported);
  assert.throws(()=>bridge('main'),/utilisé|verrou/i,'double ouverture refusée');
  good(b,'shutdown');assert.equal(call(b,'train').ok,false);release(b);
 }
 {
  const restored=bridge('main');assert.equal(good(restored,'snapshot').meta.round,round+1);assert.deepEqual(JSON.parse(good(restored,'export').meta.exportText).state,JSON.parse(exported).state);
  // Export pris pendant le match ci-dessus : reprise avant le coup d'envoi (#836), aucun match en cours après import.
  good(restored,'import',{text:liveText});assert.equal(good(restored,'snapshot').live,null,'export en plein match = carrière d’avant le coup d’envoi');
  assert.deepEqual(JSON.parse(good(restored,'export').meta.exportText).state,JSON.parse(liveText).state);release(restored);
 }
 {
  // A real filesystem failure at the destination must leave memory and disk intact.
  const fail=bridge('write-failure');const fm=settle(fail,good(fail,'new_career',MONDE)),file=path.join(fm.meta.dataDir,'donnees.json');const original=fs.readFileSync(file,'utf8');
  fs.renameSync(file,file+'.held');fs.mkdirSync(file);const failed=call(fail,'train',{mode:'intense'});assert.equal(failed.ok,false);assert.match(failed.error,/sauvegarde|EISDIR|EPERM|EACCES/i);assert.equal(good(fail,'snapshot').meta.trained,false);
  assert.equal(call(fail,'import',{text:liveText}).ok,false);assert.equal(good(fail,'snapshot').club.id,102);fs.rmdirSync(file);fs.renameSync(file+'.held',file);assert.equal(fs.readFileSync(file,'utf8'),original);
  good(fail,'train',{mode:'normal'});assert.equal(good(fail,'snapshot').meta.trained,true);release(fail);
 }
 {
  const staleRoot=path.join(root,'stale','PrototypeGodot');fs.mkdirSync(staleRoot,{recursive:true});fs.writeFileSync(path.join(staleRoot,'profil.lock'),'2147483647');const recovered=bridge('stale');assert.equal(good(recovered,'snapshot').club,null,'verrou PID disparu récupérable après fermeture forcée');release(recovered);
 }
 {
  // The private profile preserves the RNG cursor as well as the native career.
  // Match commencé puis interrompu : le profil garde la carrière et la graine d'avant le coup d'envoi (#836).
  const seeded=bridge('seeded');good(seeded,'import',{text:liveText});talk(seeded,good(seeded,'begin_match'));good(seeded,'pause',{paused:false});good(seeded,'tick',{steps:12});good(seeded,'pause');good(seeded,'save');
  const copyRoot=path.join(root,'seeded-copy','PrototypeGodot');fs.mkdirSync(copyRoot,{recursive:true});fs.copyFileSync(path.join(root,'seeded','PrototypeGodot','donnees.json'),path.join(copyRoot,'donnees.json'));
  good(seeded,'shutdown');release(seeded);
 }
 {
  const resumed=[];for(const name of ['seeded','seeded-copy']){const item=bridge(name);assert.equal(good(item,'snapshot').live,null,'reprise avant le coup d’envoi : '+name);talk(item,good(item,'begin_match'));good(item,'pause',{paused:false});good(item,'delegate');resumed.push(state(item));release(item);}
  assert.deepEqual(resumed[0],resumed[1],'RNG persistant après redémarrage');
 }
 // Export en direct réel transmis au passage Godot (import par le vrai pont, scène de match).
 liveExportFile=path.join(os.tmpdir(),'cd-godot-live-'+process.pid+'.json');fs.writeFileSync(liveExportFile,liveText);
 console.log(JSON.stringify({passed:true,checks:['bounded protocol','legacy career refused','world career determinism (twin worker)','snapshot RNG invariance','normalized scene parity','delegated match parity','atomic persistence/restart','import rollback','real disk write refusal','profile lock','pre-match resume on live import','closed commands']}));
}finally{for(const b of bridges.splice(0)){try{b.close();}catch{/* déjà fermé */}}fs.rmSync(root,{recursive:true,force:true});}

// Exercise the actual private JSON-lines pipes, including malformed input and clean exit.
(async()=>{const dir=fs.mkdtempSync(path.join(os.tmpdir(),'cd-godot-pipe-'));const child=spawn(process.execPath,[workerPath,'--data-dir',dir],{stdio:['pipe','pipe','pipe']});let stdout='',stderr='';child.stdout.on('data',d=>stdout+=d);child.stderr.on('data',d=>stderr+=d);child.stdin.end('invalid\n'+JSON.stringify({id:'a',command:'snapshot'})+'\n'+JSON.stringify({id:'z',command:'shutdown'})+'\n');const code=await new Promise((resolve,reject)=>{child.on('error',reject);child.on('exit',resolve);});assert.equal(code,0,stderr);const lines=stdout.trim().split('\n').map(JSON.parse);assert.equal(lines.length,3);assert.equal(lines[0].ok,false);assert.equal(lines[1].id,'a');assert.equal(lines[2].ok,true);assert.equal(stderr,'');fs.rmSync(dir,{recursive:true,force:true});console.log('JSON-lines process: PASS');
 try{
  if(process.env.CD_GODOT_EXECUTABLE){
   await godotTransportTest('unterminated');
   await godotTransportTest('fragments');
   await godotTest(liveExportFile);
  }else console.log('Godot runtime: NON EXÉCUTÉ (CD_GODOT_EXECUTABLE absent)');
 }finally{if(liveExportFile)fs.rmSync(liveExportFile,{force:true});}
})().catch(e=>{console.error(e);process.exitCode=1;});
}

async function reviewStorage(){
 const temp=fs.mkdtempSync(path.join(os.tmpdir(),'cd-storage-review-')),exportRoot=path.join(temp,'app'),engine=path.join(exportRoot,'engine');
 const children=[];
 try{
  fs.mkdirSync(path.join(engine,'core'),{recursive:true});
  // Tout le moteur natif tel qu'il est livré (le worker charge aujourd'hui une centaine de modules et de bases voisins).
  for(const entry of fs.readdirSync(path.dirname(workerPath),{withFileTypes:true}))if(entry.isFile())fs.copyFileSync(path.join(path.dirname(workerPath),entry.name),path.join(engine,entry.name));
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
   process.on('message',m=>{if(m==='exit'){try{if(bridge)bridge.close();process.send({type:'closed'});}catch(e){process.send({type:'closed',error:e.message});}process.exit();}else if(m==='write'){const r=bridge.handle({id:1,command:'new_career',payload:{mode:'world-champ',club:102}});process.send({type:'write',ok:r.ok,error:r.error});}});
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
  if(process.env.CD_GODOT_EXECUTABLE)await godotTransportTest();
 }finally{
  for(const child of children){if(child.connected)child.send('exit');}
  await Promise.all(children.map(child=>child.exitCode!==null?Promise.resolve():new Promise(resolve=>{const timeout=setTimeout(()=>{child.kill();resolve();},2000);child.once('exit',()=>{clearTimeout(timeout);resolve();});})));
  fs.rmSync(temp,{recursive:true,force:true});fs.rmSync(root,{recursive:true,force:true});
 }
}

async function godotTransportTest(mode = 'eof'){
 const temp=fs.mkdtempSync(path.join(os.tmpdir(),'cd-godot-eof-')),fake=path.join(temp,'exit.cjs');
 const writer=mode==='eof'?"process.stdin.once('data',()=>process.exit(0));":`const readline=require('node:readline');
 const reply=(id,data)=>Buffer.from(JSON.stringify({id,ok:true,model:{data}})+'\\n');
 const input=readline.createInterface({input:process.stdin});
 input.on('line',line=>{
  const request=JSON.parse(line);
  if(${JSON.stringify(mode)}==='unterminated'){
   const bytes=reply(request.id,'dernier fragment sans LF');
   process.stdout.write(bytes.subarray(0,-1),()=>process.exit(0));
  }else if(request.id===1){
   const first=reply(1,'déjà 🏉');
   const cut=first.indexOf(Buffer.from('🏉'))+2;
   process.stdout.write(first.subarray(0,cut));
   setTimeout(()=>{
    const second=reply(2,'x'.repeat(8*1024*1024+17)+' fin 🏉');
    process.stdout.write(Buffer.concat([first.subarray(cut),second]));
   },30);
  }else if(request.id===3){
   process.stdout.write(reply(4,'mauvais identifiant'));
  }
 });`;
 fs.writeFileSync(fake,writer);
 fs.writeFileSync(path.join(temp,'project.godot'),'config_version=5\n[application]\nconfig/name="Transport test"\n[native_engine]\nworker_path='+JSON.stringify(fake.replaceAll('\\','/'))+'\n');
 fs.copyFileSync(path.resolve(__dirname,'../native/godot/engine_bridge.gd'),path.join(temp,'engine_bridge.gd'));
 fs.writeFileSync(path.join(temp,'test.gd'),`extends SceneTree
var bridge: Node
var failure := ""
var pid := -1
var stage := 0
var exited_frames := 0
var deadline := Time.get_ticks_msec() + 9000
const MODE := ${JSON.stringify(mode)}
func _initialize():
 bridge = load("res://engine_bridge.gd").new()
 root.add_child.call_deferred(bridge)
 bridge.model_changed.connect(_model)
 bridge.command_failed.connect(func(message: String):
  if failure.is_empty(): failure = message)
 _begin.call_deferred()
func _begin():
 bridge.start(${JSON.stringify(temp.replaceAll('\\','/')+'/profile')})
 pid = bridge.child_pid
func _model(model: Dictionary):
 if MODE != "fragments":
  push_error("Une réponse sans LF a été acceptée")
  quit(1)
  return
 if stage == 0 and model.data == "déjà 🏉":
  stage = 1
  bridge.send("snapshot")
 elif stage == 1 and model.data.length() == 8*1024*1024+23 and model.data.ends_with(" fin 🏉"):
  stage = 2
  bridge.send("snapshot")
 else:
  push_error("Contenu, ordre ou identifiant de réponse incorrect")
  quit(1)
# Sous Unix, le moteur Godot journalise une ERREUR quand on interroge un enfant déjà récolté par le pont ;
# la disparition se lit alors dans /proc (une entrée zombie resterait visible, donc un enfant non récolté échoue).
func _gone(process_id: int) -> bool:
 if OS.has_feature("linux"): return not DirAccess.dir_exists_absolute("/proc/%d" % process_id)
 return not OS.is_process_running(process_id)
func _process(_delta):
 if Time.get_ticks_msec() > deadline:
  quit(1)
 if bridge.child_pid == -1 and not failure.is_empty():
  exited_frames += 1
  if exited_frames >= 3:
   if pid <= 0 or not _gone(pid) or (MODE == "fragments" and (stage != 2 or not failure.contains("identifiant inattendu"))):
    quit(1)
   else:
    print("GODOT_TRANSPORT_PASS ",MODE)
    quit(0)
 return false
`);
 const child=spawn(process.env.CD_GODOT_EXECUTABLE,['--headless','--path',temp,'--script','test.gd'],{env:{...process.env,CD_NODE_EXECUTABLE:process.execPath},stdio:['ignore','pipe','pipe']});
 let output='',errors='';
 child.stdout.on('data',d=>output+=d);child.stderr.on('data',d=>errors+=d);
 const timer=setTimeout(()=>child.kill(),12000);
 const code=await new Promise((resolve,reject)=>{child.on('error',reject);child.on('exit',resolve);});
 clearTimeout(timer);
 try{assert.equal(code,0,output+'\n'+errors);assert.ok(output.includes('GODOT_TRANSPORT_PASS '+mode));assert.doesNotMatch(errors,/SCRIPT ERROR|Parse Error|ERROR:/);console.log(output.trim());}finally{fs.rmSync(temp,{recursive:true,force:true});}
}

// Vrai pont Godot (worker lancé comme par le jeu : calendrier journalier, presse obligatoire) : carrière Monde,
// export de ~20 Mo réimporté par le pont, refus d'un import trop volumineux, rendez-vous réels, puis import
// d'un export en direct réel (LIVE_EXPORT, produit plus haut) et scène de match.
async function godotTest(liveExport){
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
func _settle_club_meetings(model: Dictionary) -> bool:
 var meeting: Variant = model.get("clubLife",{}).get("clubMeetings",{}).get("scene")
 if not meeting is Dictionary: return false
 if meeting.completed:
  bridge.send("club_meeting_continue",{"meetingId":meeting.id})
 elif meeting.kind == "press":
  var press: Dictionary = model.clubLife.press
  var answers: Array = []
  for question: Dictionary in press.conference.questions:
   if question.answers.is_empty():
    _failed("Question réelle sans réponse autorisée")
    return true
   answers.append({"questionId":question.id,"answerId":question.answers[0].id})
  var payload := {"context":press.context,"answers":answers}
  if press.conference.get("invitationId") is String: payload.invitationId = press.conference.invitationId
  bridge.send("press_conference",payload)
 elif meeting.ackAllowed:
  bridge.send("club_meeting_ack",{"meetingId":meeting.id})
 else:
  var medical: Dictionary = model.clubLife.clubSupport.medical
  for player: Dictionary in medical.players:
   if player.id == meeting.get("playerId"):
    bridge.send("medical_protocol",{"context":meeting.context,"id":player.id,"protocol":player.protocol})
    return true
  _failed("Rendez-vous médical sans participant réel")
 return true
func _initialize():
 bridge = load("res://engine_bridge.gd").new()
 root.add_child.call_deferred(bridge)
 bridge.model_changed.connect(_model)
 bridge.command_failed.connect(_failed)
 _begin.call_deferred()
func _begin():
 bridge.start(${JSON.stringify(temp.replaceAll('\\','/')+'/profile')})
 pid = bridge.child_pid
# Sous Unix, le moteur Godot journalise une ERREUR quand on interroge un enfant déjà récolté par le pont ;
# la disparition se lit alors dans /proc (une entrée zombie resterait visible, donc un enfant non récolté échoue).
func _gone(process_id: int) -> bool:
 if OS.has_feature("linux"): return not DirAccess.dir_exists_absolute("/proc/%d" % process_id)
 return not OS.is_process_running(process_id)
func _process(_delta):
 frames += 1
 # Carrière Monde (création, exports de ~20 Mo dans les deux sens) : délai en temps, pas en images.
 if Time.get_ticks_msec() > 240000:
  _failed("Timeout runtime")
 if stage == 5 and bridge.child_pid == -1:
  if frames < 3 or not _gone(pid):
   _failed("Pont bloquant ou enfant encore actif")
  else:
   print("GODOT_BRIDGE_PASS frames=", frames)
   quit(0)
 return false
func _model(model):
 match stage:
  0:
   stage = 1
   bridge.send("new_career", {"mode": "world-champ", "club": 102})
  1:
   # Club joué sans plancher de 40 (décision de Léo du 19/11/2026) : effectif réel, au moins une feuille de 23.
   if model.squad.size() < 23:
    _failed("Effectif")
    return
   stage = 2
   bridge.send("export")
  2:
   stage = 3
   small_export = model.meta.exportText
   if small_export.to_utf8_buffer().size() <= 8*1024*1024:
    _failed("Export Monde réel attendu au-delà de 8 Mio")
    return
   bridge.send("import", {"text": small_export})
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
    stage = 35
    bridge.send("snapshot")
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
   stage = 35
   bridge.send("snapshot")
  35:
   if _settle_club_meetings(model): return
   stage = 4
   bridge.send("import", {"text": FileAccess.get_file_as_string(${JSON.stringify(liveExport.replaceAll('\\','/'))})})
  4:
   # Export pris en plein match : la carrière reprend avant le coup d'envoi (#836), puis le match se relance.
   # (Le pont Godot ouvre le moteur en cadence quotidienne ; le relancement du match est vérifié côté Node.)
   if model.get("live") != null or not model.get("club") is Dictionary:
    _failed("Export en plein match : la carrière devait reprendre avant le coup d'envoi")
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
 const timer=setTimeout(()=>child.kill(),270000);const code=await new Promise((resolve,reject)=>{child.on('error',reject);child.on('exit',resolve);});clearTimeout(timer);
 try{assert.equal(code,0,output+'\n'+errors);assert.match(output,/GODOT_BRIDGE_PASS/);assert.doesNotMatch(errors,/SCRIPT ERROR|Parse Error|ERROR:/);console.log(output.trim());}finally{fs.rmSync(temp,{recursive:true,force:true});}
}

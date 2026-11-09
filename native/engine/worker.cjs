'use strict';
// Prototype bridge: local private stdio only. Never load browser UI, the source
// identity catalogue, the test harness, a network server, or protocol-supplied code.
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),readline=require('node:readline'),{randomUUID}=require('node:crypto');
const projection=require('./model.cjs'),gestion=require('./gestion.cjs'),common=require('./common-rosters.cjs'),mediaPacks=require('./media-packs.cjs'),staff=require('./staff.cjs'),decisions=require('./decisions.cjs'),systems=require('./native-systems.cjs');
const worldVm=require('./world-vm.cjs'),worldModel=require('./world-model.cjs'),worldRegistry=require('./world-registry.json');
const {createWorldEditions}=require('./world-editions.cjs');
const worldEditions=createWorldEditions(worldRegistry);
const MODULES=['storage.js','world-data.js','rugby.js','frontrow.js','restarts.js','matchflow.js','playbook.js','manager.js','manager-squad.js','tactical-plans.js','match-actions.js','match2d.js','match-v61-advisor.js','match-cockpit.js','economy.js','development.js','finance-planning.js','board-planning.js','academy-planning.js','transfer-planning.js','career-history.js','career-integration.js','club-ai.js','reputation.js','coach-market.js','coach-opportunities.js','facilities.js','rugby-world.js','financial-recovery.js','world-career.js','ai-roster-cycle.js','v39.js','manager-mobility.js','saves.js','opposition.js','match-preparation.js','france-clubs.js','rugby-common-rosters.js','rugby-roster-foundation.js','lnr-v11-aging.js','france-competition.js','france-knockout.js','france-career.js','france-save-validation.js','match3d/scene-adapter.js','game.js'];
MODULES.splice(MODULES.indexOf('game.js'),0,...systems.files.filter(name=>!MODULES.includes(name)));
const SYSTEM_COMMANDS=new Set(systems.commands);
const IMPORT_LIMIT_BYTES=8*1024*1024,WORLD_IMPORT_LIMIT_BYTES=16*1024*1024,REQUEST_LIMIT_BYTES=17*1024*1024,WORLD_REQUEST_LIMIT_BYTES=34*1024*1024;
const COMMANDS=new Set([...SYSTEM_COMMANDS,'set_collective_focus','set_opponent_level','set_delegation','set_development_focus','promote_academy','scout_mission','snapshot','new_career','train','auto_lineup','begin_match','tick','pause','delegate','finish_round','save','import','export','shutdown','set_lineup','set_tactics','set_player_load','recruit','extend_contract','next_season','substitute','promote_cover','recover_profile','pack_inspect','pack_install','pack_select']);
function applicationRoot(engineDirectory=__dirname){
 // The only supported layouts are repo/native/engine and bundle/engine/core.
 const isDevelopment=path.basename(path.dirname(engineDirectory))==='native'&&!fs.existsSync(path.join(engineDirectory,'core'));
 return path.resolve(engineDirectory,isDevelopment?'../..':'..');
}
function physicalLocation(location){
 const suffix=[];let existing=path.resolve(location);
 while(!fs.existsSync(existing)){
  const parent=path.dirname(existing);if(parent===existing)throw Error('Racine de stockage introuvable.');
  suffix.unshift(path.basename(existing));existing=parent;
 }
 return path.resolve(fs.realpathSync.native(existing),...suffix);
}
function inside(root,target){const relative=path.relative(root,target);return relative===''||relative!=='..'&&!relative.startsWith('..'+path.sep)&&!path.isAbsolute(relative);}
function createBridge(options={}){
 if(typeof options.dataDir!=='string'||!path.isAbsolute(options.dataDir))throw Error('Dossier de données absolu requis.');
 const dataDir=path.resolve(options.dataDir,path.basename(options.dataDir)==='PrototypeGodot'?'':'PrototypeGodot');
 const appRoot=physicalLocation(applicationRoot());
 if(inside(appRoot,physicalLocation(dataDir)))throw Error('Le profil PrototypeGodot doit être hors du dossier de l’application.');
 fs.mkdirSync(dataDir,{recursive:true});
 if(inside(appRoot,fs.realpathSync.native(dataDir)))throw Error('Le profil PrototypeGodot doit être hors du dossier de l’application.');
 const file=path.join(dataDir,'donnees.json'),lock=path.join(dataDir,'profil.lock');
 const gate=path.join(dataDir,'profil.acquisition'),gateOwner=path.join(gate,'owner');
 // Every acquisition, stale recovery, and release uses the same independent
 // exclusive gate. A crashed gate is deliberately refused, never reclaimed.
 function exclusive(operation){
  const token=randomUUID();fs.mkdirSync(gate);
  fs.writeFileSync(gateOwner,token,{flag:'wx'});
  try{return operation();}finally{
   if(fs.readFileSync(gateOwner,'utf8')!==token)throw Error('Le garde d’acquisition n’appartient plus à ce processus.');
   fs.unlinkSync(gateOwner);fs.rmdirSync(gate);
  }
 }
 const ownership=JSON.stringify({pid:process.pid,owner:randomUUID()});let lockFd,identity;
 try{exclusive(()=>{
   try{lockFd=fs.openSync(lock,'wx');}catch(e){
    if(e.code!=='EEXIST')throw e;
    const prior=fs.readFileSync(lock,'utf8');let priorPid=Number(prior),dead=false;
    if(!Number.isSafeInteger(priorPid)){try{priorPid=JSON.parse(prior).pid;}catch{}}
    if(Number.isSafeInteger(priorPid)&&priorPid>0){try{process.kill(priorPid,0);}catch(probe){dead=probe.code==='ESRCH';}}
    if(!dead)throw e;
    fs.unlinkSync(lock);lockFd=fs.openSync(lock,'wx');
   }
   fs.writeFileSync(lockFd,ownership);identity=fs.fstatSync(lockFd);
  });
 }catch(e){if(lockFd!==undefined)fs.closeSync(lockFd);throw Error('Profil déjà utilisé ou verrou indisponible : '+e.message);}
 let closed=false,store={},seed=(options.seed??Math.floor(Math.random()*0xffffffff))>>>0,clock=options.now??Date.now();
 const close=()=>{
  if(closed)return;closed=true;
  try{exclusive(()=>{
   const current=fs.lstatSync(lock);
   if(current.isSymbolicLink()||current.dev!==identity.dev||current.ino!==identity.ino||fs.readFileSync(lock,'utf8')!==ownership)throw Error('Le verrou de profil n’appartient plus à ce processus.');
   fs.unlinkSync(lock);
  });}finally{fs.closeSync(lockFd);}
 };
 let ctx,profileError='',recoveryBackup=null;
 let deferredDelegateActive=false,deferredDelegateRead=false;
 const deferredReadError=new Error('Lecture storage pendant une délégation différée.');
 try{
  if(fs.existsSync(file)){
   try{const saved=JSON.parse(fs.readFileSync(file,'utf8'));
   if(saved.protocol!==1||!Number.isInteger(saved.seed)||!Number.isFinite(saved.clock)||!saved.store||typeof saved.store!=='object'||Array.isArray(saved.store))throw Error('Profil PrototypeGodot illisible ou incompatible.');
   store=saved.store;seed=saved.seed>>>0;clock=saved.clock;}catch(e){profileError='Profil illisible : '+e.message;store={};}
  }
  const math=Object.create(Math);math.random=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296;};
  class EngineDate extends Date{constructor(...args){super(...(args.length?args:[clock]));}static now(){return clock;}}
  const storage={offline:true,directory:dataDir,getItem:key=>{if(deferredDelegateActive){deferredDelegateRead=true;throw deferredReadError;}return store[key]??null;},setItem:(key,value)=>{store[key]=String(value);},removeItem:key=>{delete store[key];}};
  const element={innerHTML:'',textContent:'',style:{}};
  ctx=vm.createContext({console:{log(){},warn(){},error(){}},Intl,Math:math,Date:EngineDate,Set,JSON,CDNativeHeadless:true,document:{querySelector:()=>element},window:{CDNativeHeadless:true,CDOfflineStorage:storage,CDOfflineError:true},localStorage:storage,setTimeout:()=>0,clearTimeout(){},setInterval:()=>0,clearInterval(){},nativeDataDirectory:dataDir});
  const run=source=>vm.runInContext(source,ctx,{timeout:15000});
  const dist=options.distDir?path.resolve(options.distDir):fs.existsSync(path.join(__dirname,'core'))?path.join(__dirname,'core'):path.resolve(__dirname,'../../dist');
  for(const name of MODULES)run(fs.readFileSync(path.join(dist,name),'utf8'));
  ctx.nativeWorldRegistryText=JSON.stringify(worldRegistry);
  run(`render=()=>{};toast=()=>{};startTimer=()=>{};save=()=>{if(S&&!validatingStartup){gameStorage.setItem('bdt-v1',JSON.stringify(S));lastSaveError=false;}};validatingStartup=false;const CDCommonCareer=(${common.toString()})();${worldVm.bootstrap()}const nativeBaseModel=${projection.toString()};const nativeModel=(${worldModel.toString()})(nativeBaseModel);const nativeDecisions=${decisions.toString()};const nativeGestion=${gestion.toString()};`);
  run(systems.bootstrap());
  try{run("if(loadSaveFailure)throw Error(loadSaveFailure);if(S){validateCareer(S);if(S.lnrMode)throw Error('Les effectifs réels ne sont pas chargés dans le moteur natif.');if(S.live&&!S.live.finished)S.live.paused=true;}");}catch(e){profileError='Profil illisible : '+e.message;run('S=null;');}
  const legacyDatabase=JSON.parse(run('JSON.stringify(CDCommonRosters)')),packs=mediaPacks.createStore(dataDir,legacyDatabase,worldRegistry);
  const creationKey=mode=>mode==='world'?'identity-pack-world-creation':'identity-pack-creation';
  const creation=(mode='common')=>store[creationKey(mode)]||'base';
  const edition=mode=>{if(!['common','world'].includes(mode))throw Error('Édition de pack invalide.');return mode==='world'?worldRegistry.id:legacyDatabase.id;};
  const currentEdition=()=>run('CDWorldCareer.active(S)')?'world':'common';
  const snapshot=()=>{const m=JSON.parse(run('JSON.stringify(nativeModel())'));m.decisions=JSON.parse(run('JSON.stringify(nativeDecisions())'));m.clubLife=JSON.parse(run('JSON.stringify(nativeSystems.project())'));m.meta.profileError=profileError;m.meta.recoveryRequired=!!profileError;m.meta.recoveryBackup=recoveryBackup;return packs.project(staff.project(m),JSON.parse(run('JSON.stringify(S?.identityPack||null)')),creation(),creation('world'));};
  const persist=()=>{
   const token=randomUUID(),text=JSON.stringify({protocol:1,seed,clock,store}),temp=path.join(dataDir,'donnees.tmp-'+token),backup=path.join(dataDir,'donnees-precedentes.json'),backupTemp=path.join(dataDir,'donnees-precedentes.tmp-'+token),rollback=path.join(dataDir,'donnees-precedentes.rollback-'+token);
   const write=(target,content)=>{const fd=fs.openSync(target,'wx');try{fs.writeFileSync(fd,content);fs.fsyncSync(fd);}finally{fs.closeSync(fd);}};
   const ordinary=target=>{const s=fs.lstatSync(target);if(!s.isFile()||s.isSymbolicLink())throw Error('Fichier de sauvegarde ou de secours non ordinaire.');};
   let stashed=false,published=false;
   try{
    write(temp,text);
    if(fs.existsSync(file)){
     ordinary(file);write(backupTemp,fs.readFileSync(file));
     if(fs.existsSync(backup)){ordinary(backup);fs.renameSync(backup,rollback);stashed=true;}
     fs.renameSync(backupTemp,backup);published=true;
    }
    fs.renameSync(temp,file);
   }catch(e){
    let retained='';
    try{if(stashed)fs.renameSync(rollback,backup);else if(published)fs.unlinkSync(backup);}catch{if(stashed)retained=' Copie de secours conservée : '+path.basename(rollback)+'.';}
    for(const p of [temp,backupTemp]){try{fs.unlinkSync(p);}catch{}}
    const failure=Error('Écriture de sauvegarde impossible : '+e.message+retained);failure.storageFailure=true;throw failure;
   }
   // A cleanup failure cannot turn an already published career into a failure.
   if(stashed){try{fs.unlinkSync(rollback);}catch{}}
  };
  function handle(request){
   let id=null;
   try{
    if(!request||typeof request!=='object'||Array.isArray(request))throw Error('Message JSON invalide.');
    if(!(Number.isSafeInteger(request.id)&&request.id>=0||typeof request.id==='string'&&request.id.length>0&&request.id.length<=100&&!/[\r\n]/.test(request.id)))throw Error('Identifiant de commande invalide.');
    id=request.id;if(closed)throw Error('Le moteur est fermé.');
    if(!COMMANDS.has(request.command))throw Error('Commande inconnue ou interdite.');
    const payload=request.payload??{};if(typeof payload!=='object'||payload===null||Array.isArray(payload))throw Error('Paramètres de commande invalides.');
    const command=request.command;
    if(command==='snapshot')return {id,ok:true,model:snapshot()};
    if(command==='recover_profile'){if(!profileError)throw Error('Aucun profil à récupérer.');if(payload.confirmed!==true)throw Error('Confirmation requise pour préserver puis remplacer le profil illisible.');const backup=path.join(dataDir,'donnees-endommagees-'+randomUUID()+'.json');fs.copyFileSync(file,backup,fs.constants.COPYFILE_EXCL);recoveryBackup=backup;profileError='';store={};run('S=null;loadSaveFailure="";lastSaveError=false;');return {id,ok:true,model:snapshot()};}
    if(profileError&&!['snapshot','shutdown'].includes(command))throw Error(profileError+' Confirmez la récupération du profil.');
    if(command==='pack_inspect'){packs.inspect(payload.path,edition(payload.mode??currentEdition()));return {id,ok:true,model:snapshot()};}
    if(command==='pack_install'){packs.install(payload.path,payload.digest,payload.mode===undefined?undefined:edition(payload.mode));return {id,ok:true,model:snapshot()};}
    if(command==='pack_select'&&payload.scope==='creation'){const mode=payload.mode??'common',databaseId=edition(mode),key=creationKey(mode),selected=payload.id==='base'?null:packs.get(payload.id);if(payload.id!=='base'&&!selected)throw Error('Pack non installé.');if(selected&&selected.meta.databaseId!==databaseId)throw Error('Pack incompatible avec cette édition.');const prior=store[key];try{store[key]=payload.id;persist();}catch(e){if(prior===undefined)delete store[key];else store[key]=prior;throw e;}return {id,ok:true,model:snapshot()};}
    if(command==='export'){const model=snapshot();model.meta.exportText=run('JSON.stringify(createSaveDocument())');return {id,ok:true,model};}
    if(command==='shutdown'){const model=snapshot();close();return {id,ok:true,model};}
    const prior=run('JSON.stringify({state:S,playback:S?.live?playback(S.live):null,saveError:lastSaveError})'),priorStore=JSON.stringify(store),priorSeed=seed,priorClock=clock;
    try{
     if(options.now===undefined)clock=Date.now();
     ctx.nativePayload=JSON.parse(JSON.stringify(payload));
     if(command!=='new_career'&&command!=='import'&&!run('!!S'))throw Error('Créez ou importez une carrière.');
     if(command==='pack_select'){
      if(payload.scope!=='career'||!run('!!S?.commonDatabase'))throw Error('Sélection réservée à une carrière de base commune.');const pack=payload.id==='base'?null:packs.get(payload.id);if(payload.id!=='base'&&!pack)throw Error('Pack non installé.');if(pack&&pack.meta.databaseId!==run('S.commonDatabase.id'))throw Error('Pack incompatible avec cette édition.');ctx.nativeBinding=pack?{id:pack.meta.id,digest:pack.meta.digest}:null;run('if(nativeBinding)S.identityPack=nativeBinding;else delete S.identityPack');
     }else if(command==='new_career'){
      const mode=payload.mode??'fiction';if(!['fiction','france','common','world'].includes(mode))throw Error('Mode de carrière invalide.');if(!Number.isInteger(payload.club)||payload.club<0||payload.club>=(mode==='world'?56:mode==='fiction'?14:30))throw Error('Club invalide pour ce mode.');run("if(nativePayload.mode==='world')CDWorldCareer.start(nativePayload.club);else if(nativePayload.mode==='common')CDCommonCareer.start(nativePayload.club);else start(nativePayload.club,nativePayload.mode??'fiction')");if(['common','world'].includes(mode)&&creation(mode)!=='base'){const selected=packs.get(creation(mode));if(!selected)throw Error('Pack de création absent ; réimportez-le ou choisissez Base.');if(selected.meta.databaseId!==edition(mode))throw Error('Pack incompatible avec cette édition.');ctx.nativeBinding={id:selected.meta.id,digest:selected.meta.digest};run('S.identityPack=nativeBinding');}
     }else if(command==='train'){
      const mode=payload.mode??run('S.training');if(!['normal','repos','intense'].includes(mode))throw Error('Entraînement invalide.');
      if(run("!!S.live||S.phase==='ended'"))throw Error('Entraînement indisponible pendant le match ou après la saison.');
      if(!run('S.trained')){ctx.nativeMode=mode;run('S.training=nativeMode;trainWeek()');}
     }else if(command==='auto_lineup'){
      if(run('!!S.live'))throw Error('Composition indisponible pendant un match.');run('autoLineup()');
     }else if(command==='begin_match'){
      if(run("!!S.live||S.phase==='ended'"))throw Error('Aucun nouveau match disponible.');
      const hadFixture=run('!!nextMatch()');
      // The native live must pass strict save validation. Keep this cover out of
      // historical web/background simulations, and run it after normal training.
      const nativeCreate=ctx.createRugbyMatch;
      try{run(`{
       const nativeCreate=createRugbyMatch;
       try{
        createRugbyMatch=(pair,legacy=null,automated=false,preparation=null)=>{
         if(!legacy&&!automated&&pair.includes(S.club)&&typeof CDFranceCareer!=='undefined'&&typeof CDFranceCareer.ensureAISheet==='function'&&typeof aiRosterActive==='function'&&aiRosterActive()&&!(typeof CDFranceCompetition!=='undefined'&&CDFranceCompetition.active(S)))for(const ci of pair)CDFranceCareer.ensureAISheet(S.clubs[ci]);
         return nativeCreate(pair,legacy,automated,preparation);
        };
        beginMatch();
       }finally{createRugbyMatch=nativeCreate;}
      }`);}finally{
       // VM timeouts skip its inner finally; restore without executing more VM code.
       ctx.createRugbyMatch=nativeCreate;
      }
      if(hadFixture&&!run('!!S.live'))throw Error('Coup d’envoi refusé : vérifiez la feuille à 23 et le calendrier.');
     }else if(command==='tick'){
      if(!run('!!S.live'))throw Error('Aucun match en cours.');const steps=payload.steps??1;
      if(!Number.isInteger(steps)||steps<1||steps>120)throw Error('Nombre de pas invalide (1 à 120).');
      for(let i=0;i<steps;i++)run('tick()');
     }else if(command==='pause'){
      if(!run('!!S.live'))throw Error('Aucun match en cours.');if(payload.paused!==undefined&&typeof payload.paused!=='boolean')throw Error('Pause invalide.');
      run(payload.paused===false?'continueMatch()':'pauseMatch()');
     }else if(command==='delegate'){
      if(!run('!!S.live'))throw Error('Aucun match à déléguer.');
      const delegateLoop="for(let steps=0;!S.live.finished;steps++){if(steps>=3000)throw Error('Limite de délégation atteinte.');if(S.live.paused)continueMatch();else tick();}";
      const historicalSave=ctx.save,delegateClock=clock;
      // Les saves intermédiaires restent privés à cette commande synchrone.
      // Une lecture inattendue impose un rejeu historique, jamais un faux flush.
      const deferredSave=run('(function(){if(S&&!validatingStartup)lastSaveError=false;})');
      deferredDelegateRead=false;ctx.save=deferredSave;deferredDelegateActive=true;
      try{run(delegateLoop);}catch(error){if(!deferredDelegateRead)throw error;}
      finally{ctx.save=historicalSave;deferredDelegateActive=false;}
      if(deferredDelegateRead){
       deferredDelegateRead=false;seed=priorSeed;clock=delegateClock;store=JSON.parse(priorStore);ctx.nativePrior=JSON.parse(prior);
       run('S=nativePrior.state;if(S?.live&&nativePrior.playback)MATCH_PLAYBACK.set(S.live,nativePrior.playback);pendingSave=null;lastSaveError=nativePrior.saveError;');
       run(delegateLoop);
      }
     }else if(command==='finish_round'){
      if(!run("S.phase!=='ended'&&(S.live?.finished||!S.live&&!nextMatch())"))throw Error('Terminez le match avant de valider la journée.');run('finishRound()');
     }else if(command==='import'){
      if(typeof payload.text!=='string')throw Error('Texte JSON d’import requis.');
      if(Buffer.byteLength(payload.text,'utf8')>WORLD_IMPORT_LIMIT_BYTES)throw Error('Fichier trop volumineux (16 Mio UTF-8 maximum).');
      run("pendingSave=parseSaveDocument(nativePayload.text);if(pendingSave.state.lnrMode)throw Error('Les effectifs réels ne sont pas chargés dans le moteur natif.');");
      const imported=JSON.parse(run('JSON.stringify({binding:pendingSave.state.identityPack,database:pendingSave.state.commonDatabase?.id})')),bound=imported.binding&&packs.get(imported.binding.id);if(bound&&bound.meta.databaseId!==imported.database)throw Error('Pack incompatible avec cette édition.');
      run("if(!confirmSaveImport())throw Error('Import annulé : sauvegarde impossible.');");
     }
     let extra=null;if(SYSTEM_COMMANDS.has(command)){ctx.nativeCommand=command;extra=run('nativeSystems.execute(nativeCommand,nativePayload)');}
     else if(['set_collective_focus','set_opponent_level','set_delegation','set_development_focus','promote_academy','scout_mission','set_lineup','set_tactics','set_player_load','recruit','extend_contract','next_season','substitute','promote_cover'].includes(command)){ctx.nativeCommand=command;extra=run('nativeGestion(nativeCommand,nativePayload)');}
     run('save();validateCareer(S)');
     const model=snapshot();if(extra)Object.assign(model.meta,JSON.parse(JSON.stringify(extra)));persist();return {id,ok:true,model};
    }catch(error){
     seed=priorSeed;clock=priorClock;store=JSON.parse(priorStore);ctx.nativePrior=JSON.parse(prior);ctx.nativePrior.saveError=ctx.nativePrior.saveError||error.storageFailure===true;
     run('S=nativePrior.state;if(S?.live&&nativePrior.playback)MATCH_PLAYBACK.set(S.live,nativePrior.playback);pendingSave=null;lastSaveError=nativePrior.saveError;');
     throw error;
    }finally{deferredDelegateActive=false;deferredDelegateRead=false;delete ctx.nativePayload;delete ctx.nativePrior;delete ctx.nativeMode;delete ctx.nativeCommand;delete ctx.nativeBinding;}
   }catch(error){return {id,ok:false,model:closed?null:snapshot(),error:error.message};}
  }
  return {handle,close};
 }catch(e){close();throw e;}
}
module.exports={createBridge,applicationRoot,IMPORT_LIMIT_BYTES,REQUEST_LIMIT_BYTES,WORLD_IMPORT_LIMIT_BYTES,WORLD_REQUEST_LIMIT_BYTES,CORE_FILES:Object.freeze([...MODULES])};
if(require.main===module){
 let bridge;
 try{const rawSeed=process.env.CD_GODOT_SEED;let seed;if(rawSeed!==undefined){seed=Number(rawSeed);if(!/^(0|[1-9]\d*)$/.test(rawSeed)||!Number.isInteger(seed)||seed<0||seed>0xffffffff)throw Error('CD_GODOT_SEED doit être un entier entre 0 et 4294967295.');}const index=process.argv.indexOf('--data-dir');bridge=createBridge({...(seed===undefined?{}:{seed}),dataDir:index>=0?process.argv[index+1]:path.join(process.env.LOCALAPPDATA||require('node:os').homedir(),'CadrageDebordement','PrototypeGodot')});}
 catch(e){process.stdout.write(JSON.stringify({id:null,ok:false,model:null,error:e.message})+'\n');process.exitCode=1;return;}
 const input=readline.createInterface({input:process.stdin,crlfDelay:Infinity});
 input.on('line',line=>{
  let result;try{const bytes=Buffer.byteLength(line);if(bytes>WORLD_REQUEST_LIMIT_BYTES)throw Error('Message trop volumineux.');const request=JSON.parse(line);if(bytes>REQUEST_LIMIT_BYTES){if(request.command!=='import'||typeof request.payload?.text!=='string'||Buffer.byteLength(request.payload.text)>WORLD_IMPORT_LIMIT_BYTES)throw Error('Message trop volumineux.');const state=JSON.parse(request.payload.text)?.state;if(!worldEditions.forState(state))throw Error('Message trop volumineux.');}result=bridge.handle(request);}catch(e){result={id:null,ok:false,model:null,error:e.message};}
  process.stdout.write(JSON.stringify(result)+'\n');if(result.ok&&line&&JSON.parse(line).command==='shutdown'){input.close();process.stdin.destroy();}
 });
 input.on('close',()=>bridge.close());process.on('exit',()=>bridge.close());
}

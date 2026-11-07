'use strict';
// Prototype bridge: local private stdio only. Never load browser UI, real roster
// data, the test harness, a network server, or code supplied by protocol clients.
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),readline=require('node:readline'),{randomUUID}=require('node:crypto');
const projection=require('./model.cjs');
const MODULES=['storage.js','world-data.js','rugby.js','frontrow.js','restarts.js','matchflow.js','playbook.js','manager.js','manager-squad.js','tactical-plans.js','match-actions.js','match2d.js','match-v61-advisor.js','match-cockpit.js','economy.js','development.js','finance-planning.js','board-planning.js','academy-planning.js','transfer-planning.js','career-history.js','career-integration.js','club-ai.js','reputation.js','coach-market.js','coach-opportunities.js','facilities.js','rugby-world.js','financial-recovery.js','world-career.js','ai-roster-cycle.js','v39.js','manager-mobility.js','saves.js','opposition.js','match-preparation.js','france-clubs.js','match3d/scene-adapter.js','game.js'];
const COMMANDS=new Set(['snapshot','new_career','train','auto_lineup','begin_match','tick','pause','delegate','finish_round','save','import','export','shutdown']);
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
 let ctx;
 try{
  if(fs.existsSync(file)){
   const saved=JSON.parse(fs.readFileSync(file,'utf8'));
   if(saved.protocol!==1||!Number.isInteger(saved.seed)||!Number.isFinite(saved.clock)||!saved.store||typeof saved.store!=='object'||Array.isArray(saved.store))throw Error('Profil PrototypeGodot illisible ou incompatible.');
   store=saved.store;seed=saved.seed>>>0;clock=saved.clock;
  }
  const math=Object.create(Math);math.random=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296;};
  class EngineDate extends Date{constructor(...args){super(...(args.length?args:[clock]));}static now(){return clock;}}
  const storage={offline:true,directory:dataDir,getItem:key=>store[key]??null,setItem:(key,value)=>{store[key]=String(value);},removeItem:key=>{delete store[key];}};
  const element={innerHTML:'',textContent:'',style:{}};
  ctx=vm.createContext({console:{log(){},warn(){},error(){}},Intl,Math:math,Date:EngineDate,Set,JSON,document:{querySelector:()=>element},window:{CDOfflineStorage:storage,CDOfflineError:true},localStorage:storage,setTimeout:()=>0,clearTimeout(){},setInterval:()=>0,clearInterval(){},nativeDataDirectory:dataDir});
  const run=source=>vm.runInContext(source,ctx,{timeout:15000});
  const dist=options.distDir?path.resolve(options.distDir):fs.existsSync(path.join(__dirname,'core'))?path.join(__dirname,'core'):path.resolve(__dirname,'../../dist');
  for(const name of MODULES)run(fs.readFileSync(path.join(dist,name),'utf8'));
  run(`render=()=>{};toast=()=>{};startTimer=()=>{};save=()=>{if(S&&!validatingStartup){gameStorage.setItem('bdt-v1',JSON.stringify(S));lastSaveError=false;}};validatingStartup=false;if(loadSaveFailure)throw Error(loadSaveFailure);if(S){validateCareer(S);if(S.lnrMode||S.franceMode)throw Error('Ce prototype accepte uniquement les carrières historiques fictives à 14 clubs.');if(S.live&&!S.live.finished)S.live.paused=true;}const nativeModel=${projection.toString()};`);
  const snapshot=()=>JSON.parse(run('JSON.stringify(nativeModel())'));
  const persist=()=>{
   const text=JSON.stringify({protocol:1,seed,clock,store}),temp=path.join(dataDir,'donnees.tmp'),backup=path.join(dataDir,'donnees-precedentes.json'),backupTemp=path.join(dataDir,'donnees-precedentes.tmp');
   const write=(target,content)=>{const fd=fs.openSync(target,'w');try{fs.writeFileSync(fd,content);fs.fsyncSync(fd);}finally{fs.closeSync(fd);}};
   try{
    write(temp,text);
    if(fs.existsSync(file)){write(backupTemp,fs.readFileSync(file));fs.renameSync(backupTemp,backup);}
    fs.renameSync(temp,file);
   }catch(e){for(const p of [temp,backupTemp]){try{fs.unlinkSync(p);}catch{}}throw Error('Écriture de sauvegarde impossible : '+e.message);}
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
    if(command==='export'){const model=snapshot();model.meta.exportText=run('JSON.stringify(createSaveDocument())');return {id,ok:true,model};}
    if(command==='shutdown'){const model=snapshot();close();return {id,ok:true,model};}
    const prior=run('JSON.stringify({state:S,playback:S?.live?playback(S.live):null})'),priorStore=JSON.stringify(store),priorSeed=seed,priorClock=clock;
    try{
     if(options.now===undefined)clock=Date.now();
     ctx.nativePayload=JSON.parse(JSON.stringify(payload));
     if(command!=='new_career'&&command!=='import'&&!run('!!S'))throw Error('Créez ou importez une carrière.');
     if(command==='new_career'){
      if(!Number.isInteger(payload.club)||payload.club<0||payload.club>13)throw Error('Club historique invalide (0 à 13).');
      run("start(nativePayload.club,'fiction')");
     }else if(command==='train'){
      const mode=payload.mode??run('S.training');if(!['normal','repos','intense'].includes(mode))throw Error('Entraînement invalide.');
      if(run("!!S.live||S.phase==='ended'"))throw Error('Entraînement indisponible pendant le match ou après la saison.');
      if(!run('S.trained')){ctx.nativeMode=mode;run('S.training=nativeMode;trainWeek()');}
     }else if(command==='auto_lineup'){
      if(run('!!S.live'))throw Error('Composition indisponible pendant un match.');run('autoLineup()');
     }else if(command==='begin_match'){
      if(run("!!S.live||S.phase==='ended'"))throw Error('Aucun nouveau match disponible.');
      const hadFixture=run('!!nextMatch()');run('beginMatch()');if(hadFixture&&!run('!!S.live'))throw Error('Coup d’envoi refusé : vérifiez la feuille à 23 et le calendrier.');
     }else if(command==='tick'){
      if(!run('!!S.live'))throw Error('Aucun match en cours.');const steps=payload.steps??1;
      if(!Number.isInteger(steps)||steps<1||steps>120)throw Error('Nombre de pas invalide (1 à 120).');
      for(let i=0;i<steps;i++)run('tick()');
     }else if(command==='pause'){
      if(!run('!!S.live'))throw Error('Aucun match en cours.');if(payload.paused!==undefined&&typeof payload.paused!=='boolean')throw Error('Pause invalide.');
      run(payload.paused===false?'continueMatch()':'pauseMatch()');
     }else if(command==='delegate'){
      if(!run('!!S.live'))throw Error('Aucun match à déléguer.');
      run("for(let steps=0;!S.live.finished;steps++){if(steps>=3000)throw Error('Limite de délégation atteinte.');if(S.live.paused)continueMatch();else tick();}");
     }else if(command==='finish_round'){
      if(!run("S.phase!=='ended'&&(S.live?.finished||!S.live&&!nextMatch())"))throw Error('Terminez le match avant de valider la journée.');run('finishRound()');
     }else if(command==='import'){
      if(typeof payload.text!=='string')throw Error('Texte JSON d’import requis.');
      if(Buffer.byteLength(payload.text,'utf8')>5*1024*1024)throw Error('Fichier trop volumineux (5 Mio UTF-8 maximum).');
      run("pendingSave=parseSaveDocument(nativePayload.text);if(pendingSave.state.lnrMode||pendingSave.state.franceMode)throw Error('Seules les carrières historiques fictives à 14 clubs sont acceptées.');if(!confirmSaveImport())throw Error('Import annulé : sauvegarde impossible.');");
     }
     run('save();validateCareer(S)');
     const model=snapshot();persist();return {id,ok:true,model};
    }catch(error){
     seed=priorSeed;clock=priorClock;store=JSON.parse(priorStore);ctx.nativePrior=JSON.parse(prior);
     run('S=nativePrior.state;if(S?.live&&nativePrior.playback)MATCH_PLAYBACK.set(S.live,nativePrior.playback);pendingSave=null;lastSaveError=true;');
     throw error;
    }finally{delete ctx.nativePayload;delete ctx.nativePrior;delete ctx.nativeMode;}
   }catch(error){return {id,ok:false,model:closed?null:snapshot(),error:error.message};}
  }
  return {handle,close};
 }catch(e){close();throw e;}
}
module.exports={createBridge,applicationRoot,CORE_FILES:Object.freeze([...MODULES])};
if(require.main===module){
 let bridge;
 try{const index=process.argv.indexOf('--data-dir');bridge=createBridge({dataDir:index>=0?process.argv[index+1]:path.join(process.env.LOCALAPPDATA||require('node:os').homedir(),'CadrageDebordement','PrototypeGodot')});}
 catch(e){process.stdout.write(JSON.stringify({id:null,ok:false,model:null,error:e.message})+'\n');process.exitCode=1;return;}
 const input=readline.createInterface({input:process.stdin,crlfDelay:Infinity});
 input.on('line',line=>{
  let result;try{if(Buffer.byteLength(line)>6*1024*1024)throw Error('Message trop volumineux.');result=bridge.handle(JSON.parse(line));}catch(e){result={id:null,ok:false,model:null,error:e.message};}
  process.stdout.write(JSON.stringify(result)+'\n');if(result.ok&&line&&JSON.parse(line).command==='shutdown'){input.close();process.stdin.destroy();}
 });
 input.on('close',()=>bridge.close());process.on('exit',()=>bridge.close());
}

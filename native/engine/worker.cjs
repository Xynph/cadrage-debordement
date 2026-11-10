'use strict';
// Prototype bridge: local private stdio only. Never load browser UI, the source
// identity catalogue, the test harness, a network server, or protocol-supplied code.
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),readline=require('node:readline'),{randomUUID}=require('node:crypto');
const projection=require('./model.cjs'),gestion=require('./gestion.cjs'),common=require('./common-rosters.cjs'),mediaPacks=require('./media-packs.cjs'),staff=require('./staff.cjs'),decisions=require('./decisions.cjs'),systems=require('./native-systems.cjs');
const playerAttributes=require('./player-attributes.cjs');
const epcrPreparation=require('./epcr-preparation.cjs');
const competitionEditor=require('./competition-editor.cjs');
const {calendarContext}=require('./calendar-clock.cjs');
const calendarPlanning=require('./calendar-planning.cjs'),calendarMail=require('./calendar-mail.cjs');
const worldVm=require('./world-vm.cjs'),worldModel=require('./world-model.cjs'),publishedVenue=require('./world-venues.cjs'),worldRegistry=require('./world-registry.json');
const clubHistory=require('./club-history.json');
const {createWorldEditions}=require('./world-editions.cjs');
const {extendWorldRegistry,extendJapanRegistry,extendNationaleRegistry,extendChampRegistry}=require('./world-pacific-registry.cjs');
const pacificSource=path.join(__dirname,'world-pacific-extension.json');
const pacificRegistry=extendWorldRegistry(worldRegistry,fs.existsSync(pacificSource)?JSON.parse(fs.readFileSync(pacificSource,'utf8')):null);
const japanSource=path.join(__dirname,'world-japan-extension.json');
const japanRegistry=extendJapanRegistry(pacificRegistry,fs.existsSync(japanSource)?JSON.parse(fs.readFileSync(japanSource,'utf8')):null);
const nationaleSource=path.join(__dirname,'world-nationale-extension.json');
const nationaleRegistry=extendNationaleRegistry(japanRegistry,fs.existsSync(nationaleSource)?JSON.parse(fs.readFileSync(nationaleSource,'utf8')):null);
const champSource=path.join(__dirname,'world-champ-extension.json');
const champRegistry=extendChampRegistry(nationaleRegistry,fs.existsSync(champSource)?JSON.parse(fs.readFileSync(champSource,'utf8')):null);
const worldEditions=createWorldEditions(worldRegistry,pacificRegistry,japanRegistry,nationaleRegistry,champRegistry);
const MODULES=['storage.js','world-data.js','rugby.js','frontrow.js','restarts.js','matchflow.js','playbook.js','manager.js','manager-squad.js','tactical-plans.js','match-actions.js','match2d.js','match-v61-advisor.js','match-cockpit.js','economy.js','development.js','finance-planning.js','board-planning.js','academy-planning.js','transfer-planning.js','career-history.js','career-integration.js','club-ai.js','reputation.js','coach-market.js','coach-opportunities.js','facilities.js','rugby-world.js','financial-recovery.js','world-career.js','ai-roster-cycle.js','v39.js','manager-mobility.js','saves.js','opposition.js','match-preparation.js','france-clubs.js','rugby-common-rosters.js','rugby-roster-foundation.js','lnr-v11-aging.js','france-competition.js','france-knockout.js','france-career.js','france-save-validation.js','match3d/scene-adapter.js','game.js'];
MODULES.splice(MODULES.indexOf('game.js'),0,...systems.files.filter(name=>!MODULES.includes(name)));
const SYSTEM_COMMANDS=new Set(systems.commands);
const IMPORT_LIMIT_BYTES=8*1024*1024,WORLD_IMPORT_LIMIT_BYTES=16*1024*1024,REQUEST_LIMIT_BYTES=17*1024*1024,WORLD_REQUEST_LIMIT_BYTES=34*1024*1024,EXTENDED_IMPORT_LIMIT_BYTES=20*1024*1024,EXTENDED_REQUEST_LIMIT_BYTES=42*1024*1024,CHAMP_IMPORT_LIMIT_BYTES=24*1024*1024,CHAMP_REQUEST_LIMIT_BYTES=50*1024*1024;
const COMMANDS=new Set([...SYSTEM_COMMANDS,'population_enable','competition_editor_preview','epcr_preview','set_collective_focus','set_opponent_level','set_delegation','set_development_focus','promote_academy','scout_mission','snapshot','new_career','train','auto_lineup','begin_match','tick','pause','delegate','finish_round','advance_pacific_preparation','advance_japan_preparation','advance_champ_preparation','save','import','export','shutdown','set_lineup','set_tactics','set_player_load','recruit','extend_contract','next_season','substitute','promote_cover','recover_profile','pack_inspect','pack_install','pack_select']);
COMMANDS.add('calendar_template');
COMMANDS.add('calendar_mail_decide');
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
  const calendarState=(source='S')=>JSON.parse(run(`JSON.stringify({planning:${source}?.calendarPlanning,mail:${source}?.calendarMail})`));
  function validateCalendarState(state){
   if(calendarPlanning.validateState(state.planning)===false||calendarMail.validate(state.mail)===false)throw Error('Planification du calendrier invalide.');
  }
  const dist=options.distDir?path.resolve(options.distDir):fs.existsSync(path.join(__dirname,'core'))?path.join(__dirname,'core'):path.resolve(__dirname,'../../dist');
  for(const name of MODULES)run(fs.readFileSync(path.join(dist,name),'utf8'));
  ctx.nativeWorldRegistryText=JSON.stringify(worldRegistry);
  if(pacificRegistry)ctx.nativeWorldPacificRegistryText=JSON.stringify(pacificRegistry);
  if(japanRegistry)ctx.nativeWorldJapanRegistryText=JSON.stringify(japanRegistry);
  if(nationaleRegistry)ctx.nativeWorldNationaleRegistryText=JSON.stringify(nationaleRegistry);
  if(champRegistry)ctx.nativeWorldChampRegistryText=JSON.stringify(champRegistry);
  run(`render=()=>{};toast=()=>{};startTimer=()=>{};save=()=>{if(S&&!validatingStartup){gameStorage.setItem('bdt-v1',JSON.stringify(S));lastSaveError=false;}};validatingStartup=false;const CDCommonCareer=(${common.toString()})();${worldVm.bootstrap()}const nativeAttributeStore=(${playerAttributes.toString()})();const nativePlayerAttributes=nativeAttributeStore.project;const nativeBaseModel=${projection.toString()};const nativeModel=(${worldModel.toString()})(nativeBaseModel,(${publishedVenue.factory.toString()})(${JSON.stringify(publishedVenue.data)}),${JSON.stringify(clubHistory)});const nativeDecisions=${decisions.toString()};const nativeGestion=${gestion.toString()};`);
  ctx.nativeStaffCareerSourcesText=JSON.stringify(Object.fromEntries([run('CDCommonRosters.id'),...worldEditions.entries.map(e=>e.id)].map(id=>[id,staff.forDatabase(id).registry.clubs])));
  run(systems.bootstrap());delete ctx.nativeStaffCareerSourcesText;
  try{run("if(loadSaveFailure)throw Error(loadSaveFailure);if(S){validateCareer(S);if(S.lnrMode)throw Error('Les effectifs réels ne sont pas chargés dans le moteur natif.');nativeAttributeStore.complete(S);if(S.live&&!S.live.finished)S.live.paused=true;}");validateCalendarState(calendarState());}catch(e){profileError='Profil illisible : '+e.message;run('S=null;');}
  const legacyDatabase=JSON.parse(run('JSON.stringify(CDCommonRosters)')),packs=mediaPacks.createStore(dataDir,legacyDatabase,worldRegistry,pacificRegistry,japanRegistry,nationaleRegistry,champRegistry);
  const creationKey=mode=>mode==='world-champ'?'identity-pack-champ-creation':mode==='world-nationale'?'identity-pack-nationale-creation':mode==='world-japan'?'identity-pack-japan-creation':mode==='world-pacific'?'identity-pack-pacific-creation':mode==='world'?'identity-pack-world-creation':'identity-pack-creation';
  const creation=(mode='common')=>store[creationKey(mode)]||'base';
  const edition=mode=>{if(mode==='common')return legacyDatabase.id;const e=worldEditions.forMode(mode);if(!e)throw Error('Édition de pack invalide.');return e.id;};
  const currentEdition=()=>run("CDWorldCareer.edition(S)?.mode||'common'");
  function projectCalendar(model, operation){
   if(!model.club)return;
   const {fixtures,today,simulatedDates}=calendarContext(model);
   const stored=calendarState();
   const planningModel={...model,calendar:fixtures};
   let planning=stored.planning,mail=stored.mail;
   if(today&&!simulatedDates){
    mail=calendarMail.observe(fixtures,mail,{today,clubId:model.club.id,season:model.meta.season});
   }
   if(operation?.command==='calendar_template'){
    if(!today||model.live)throw Error('La planification est indisponible.');
    planning=calendarPlanning.applyTemplate(planningModel,planning,operation.payload,today,{anchors:calendarMail.anchors(mail)});
   }else if(operation?.command==='calendar_mail_decide'){
    if(!today||simulatedDates||model.live)throw Error('La planification est indisponible.');
    const anchors=calendarMail.anchors(mail);
    const decision=calendarMail.decide(mail,operation.payload);
    mail=decision.state;
    if(decision.change&&operation.payload.choice==='recalibrate'){
     planning=calendarPlanning.reschedule(planningModel,planning,decision.change,today,{anchors});
    }
   }
   model.calendarPlanning={
    ...calendarPlanning.project(planningModel,planning,today,{anchors:calendarMail.anchors(mail)}),
    ...(fixtures===model.calendar ? {} : {fixtures}),simulatedDates
   };
   model.calendarMail=calendarMail.project(mail);
   if(operation&&(JSON.stringify(mail)!==JSON.stringify(stored.mail)||JSON.stringify(planning)!==JSON.stringify(stored.planning))){
    validateCalendarState({planning,mail});
    ctx.nativeCalendarState=JSON.parse(JSON.stringify({planning,mail}));
    try{
     run('if(nativeCalendarState.planning)S.calendarPlanning=nativeCalendarState.planning;if(nativeCalendarState.mail)S.calendarMail=nativeCalendarState.mail;save();');
    }finally{delete ctx.nativeCalendarState;}
   }
  }
  const snapshot=operation=>{const m=JSON.parse(run('JSON.stringify(nativeModel())'));m.decisions=JSON.parse(run('JSON.stringify(nativeDecisions())'));m.clubLife=JSON.parse(run('JSON.stringify(nativeSystems.project())'));m.meta.profileError=profileError;m.meta.recoveryRequired=!!profileError;m.meta.recoveryBackup=recoveryBackup;const result=packs.project(staff.project(m),JSON.parse(run('JSON.stringify(S?.identityPack||null)')),creation(),creation('world'),creation('world-pacific'),creation('world-japan'),creation('world-nationale'),creation('world-champ'));staff.applyCareerPresentation(result);const custom=result.clubLife?.customCompetition;if(custom&&result.leagues?.length===1){result.leagues[0].name=custom.name;result.leagues[0].notice=custom.notice;}result.epcrPreparation=epcrPreparation.project(result);projectCalendar(result,operation);return result;};
  const backup=path.join(dataDir,'donnees-precedentes.json');
  let committedFiles='';
  const profileFilesVersion=()=>{
   try{
    const entries=[file,backup].map(target=>fs.lstatSync(target,{bigint:true}));
    if(entries.some(entry=>!entry.isFile()))return '';
    return entries.map(entry=>[entry.dev,entry.ino,entry.size,entry.mtimeNs,entry.ctimeNs].join(':')).join('|');
   }catch{return '';}
  };
  const persist=()=>{
   committedFiles='';
   const token=randomUUID(),text=JSON.stringify({protocol:1,seed,clock,store}),temp=path.join(dataDir,'donnees.tmp-'+token),backupTemp=path.join(dataDir,'donnees-precedentes.tmp-'+token),rollback=path.join(dataDir,'donnees-precedentes.rollback-'+token);
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
   committedFiles=profileFilesVersion();
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
    if(command==='competition_editor_preview'){const model=snapshot();model.competitionEditor=competitionEditor.project(payload);return {id,ok:true,model};}
    if(command==='epcr_preview'){const model=snapshot();model.epcrPreparation=epcrPreparation.project(model,payload);return {id,ok:true,model};}
    if(command==='pack_inspect'){packs.inspect(payload.path,edition(payload.mode??currentEdition()));return {id,ok:true,model:snapshot()};}
    if(command==='pack_install'){packs.install(payload.path,payload.digest,payload.mode===undefined?undefined:edition(payload.mode));return {id,ok:true,model:snapshot()};}
    if(command==='pack_select'&&payload.scope==='creation'){const mode=payload.mode??'common',databaseId=edition(mode),key=creationKey(mode),selected=payload.id==='base'?null:packs.get(payload.id);if(payload.id!=='base'&&!selected)throw Error('Pack non installé.');if(selected&&selected.meta.databaseId!==databaseId)throw Error('Pack incompatible avec cette édition.');const prior=store[key];try{store[key]=payload.id;persist();}catch(e){if(prior===undefined)delete store[key];else store[key]=prior;throw e;}return {id,ok:true,model:snapshot()};}
    if(command==='export'){const model=snapshot();model.meta.exportText=run('JSON.stringify(createSaveDocument())');return {id,ok:true,model};}
    if(command==='shutdown'){const model=snapshot();close();return {id,ok:true,model};}
    const prior=run('JSON.stringify({state:S,playback:S?.live?playback(S.live):null,saveError:lastSaveError})'),priorStore=JSON.stringify(store),priorSeed=seed,priorClock=clock;
    try{
     ctx.nativePayload=JSON.parse(JSON.stringify(payload));
     if(command!=='new_career'&&command!=='import'&&!run('!!S'))throw Error('Créez ou importez une carrière.');
     if(command==='interclub_negotiate'){
      ctx.nativeCommand=command;const extra=run('nativeSystems.execute(nativeCommand,nativePayload)');
      if(run('JSON.stringify(S)')!==JSON.stringify(JSON.parse(prior).state)||seed!==priorSeed||JSON.stringify(store)!==priorStore)throw Error('Une consultation ne peut pas modifier la carrière.');
      const model=snapshot();Object.assign(model.meta,JSON.parse(JSON.stringify(extra)));return {id,ok:true,model};
     }
     if(options.now===undefined)clock=Date.now();
     const liveOnly=command==='tick'||command==='delegate';
     const previousAcademyClub=command==='next_season'?run('S.club'):null;
     ctx.nativeAttributeBaseline=['new_career','import'].includes(command)?null:run('nativeAttributeStore.before(S,'+liveOnly+');');
     if(command==='population_enable'){
      if(payload.confirmed!==true||Object.keys(payload).some(k=>!['confirmed','context'].includes(k)))throw Error('Confirmez explicitement la nouvelle politique de population.');
      const context=JSON.parse(run('JSON.stringify({season:S.season,week:S.franceMode?.version===1?S.franceMode.week:S.round,club:S.club})'));
      if(!payload.context||Object.keys(payload.context).length!==3||['season','week','club'].some(k=>payload.context[k]!==context[k]))throw Error('Le contexte de carrière a changé.');
      if(!run("typeof enablePopulationPolicy==='function'&&enablePopulationPolicy()"))throw Error('Activation de population indisponible ou déjà effectuée.');
      run('CDStaffCareer.initialize(S)');
     }else if(command==='pack_select'){
      if(payload.scope!=='career'||!run('!!S?.commonDatabase'))throw Error('Sélection réservée à une carrière de base commune.');const pack=payload.id==='base'?null:packs.get(payload.id);if(payload.id!=='base'&&!pack)throw Error('Pack non installé.');if(pack&&pack.meta.databaseId!==run('S.commonDatabase.id'))throw Error('Pack incompatible avec cette édition.');ctx.nativeBinding=pack?{id:pack.meta.id,digest:pack.meta.digest}:null;run('if(nativeBinding)S.identityPack=nativeBinding;else delete S.identityPack');
     }else if(command==='new_career'&&payload.mode==='custom'){
      run("nativeSystems.domain('customCompetition').create(nativePayload)");
      if(run("typeof aiRosterPopulationActive==='function'&&aiRosterPopulationActive(S)"))run('CDStaffCareer.initialize(S)');
     }else if(command==='new_career'){
      const mode=payload.mode??'fiction',worldEdition=worldEditions.forMode(mode);if(!worldEdition&&!['fiction','france','common'].includes(mode))throw Error('Mode de carrière invalide.');if(!Number.isInteger(payload.club)||payload.club<0||(worldEdition?!worldEdition.playable.includes(payload.club):payload.club>=(mode==='fiction'?14:30)))throw Error('Club invalide pour ce mode.');if(worldEdition)run('CDWorldCareer.start(nativePayload.club,nativePayload.mode)');else run("if(nativePayload.mode==='common')CDCommonCareer.start(nativePayload.club);else start(nativePayload.club,nativePayload.mode??'fiction')");if((worldEdition||mode==='common')&&creation(mode)!=='base'){const selected=packs.get(creation(mode));if(!selected)throw Error('Pack de création absent ; réimportez-le ou choisissez Base.');if(selected.meta.databaseId!==edition(mode))throw Error('Pack incompatible avec cette édition.');ctx.nativeBinding={id:selected.meta.id,digest:selected.meta.digest};run('S.identityPack=nativeBinding');}
      if(run("typeof aiRosterPopulationActive==='function'&&aiRosterPopulationActive(S)"))run('CDStaffCareer.initialize(S)');
     }else if(command==='train'){
      const mode=payload.mode??run('S.training');if(!['normal','repos','intense'].includes(mode))throw Error('Entraînement invalide.');
      if(run("!!S.live||S.phase==='ended'"))throw Error('Entraînement indisponible pendant le match ou après la saison.');
      if(!run('S.trained')){ctx.nativeMode=mode;run('S.training=nativeMode;trainWeek()');}
     }else if(command==='auto_lineup'){
      if(run('!!S.live'))throw Error('Composition indisponible pendant un match.');run('autoLineup()');
     }else if(command==='begin_match'){
      if(run("!!S.live||S.phase==='ended'"))throw Error('Aucun nouveau match disponible.');
      if(payload.reducedBench!==undefined&&typeof payload.reducedBench!=='boolean')throw Error('Confirmation de la feuille à 22 invalide.');
      const reducedBench=payload.reducedBench===true;
      if(reducedBench&&!run('CDNationaleReducedBench?.vacancy(S)'))throw Error('La feuille à 22 n’est pas disponible pour cette rencontre.');
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
        beginMatch(nativePayload.reducedBench===true);
       }finally{createRugbyMatch=nativeCreate;}
      }`);}finally{
       // VM timeouts skip its inner finally; restore without executing more VM code.
       ctx.createRugbyMatch=nativeCreate;
      }
      if(hadFixture&&!run('!!S.live'))throw Error(reducedBench?'La feuille à 22 a changé après la préparation. Vérifiez la composition et l’entraînement.':'Coup d’envoi refusé : vérifiez la feuille à 23 et le calendrier.');
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
     }else if(['advance_pacific_preparation','advance_japan_preparation','advance_champ_preparation'].includes(command)){
      if(!Number.isInteger(payload.fromWeek)||payload.fromWeek<0||payload.fromWeek>=46)throw Error('Semaine de préparation invalide.');
      const allowed=command==='advance_champ_preparation'
       ?"CDWorldCareer.edition(S)?.version===5&&CDWorldCareer.leagueId(S)==='champ'"
       :command==='advance_pacific_preparation'
        ?"(CDWorldCareer.edition(S)?.version??0)>=2&&CDWorldCareer.leagueId(S)==='srp'"
        :"(CDWorldCareer.edition(S)?.version??0)>=3&&['jlo-d1','jlo-d2'].includes(CDWorldCareer.leagueId(S))";
      const eligible=run(allowed+"&&S.round===nativePayload.fromWeek&&S.phase!=='ended'&&!S.live&&!nextMatch()&&S.worldMode.fixtures.some(f=>f.week>S.round&&(f.homeId===S.club||f.awayId===S.club))");
      if(!eligible)throw Error('Avance de préparation indisponible cette semaine.');
      // Replay ordinary weekly actions, with one atomic publication. Stop as
      // soon as a match is ready, even if the originally planned one changed.
      for(let i=0;i<4&&run("S.phase!=='ended'&&!S.live&&!nextMatch()");i++)run('finishRound()');
     }else if(command==='import'){
      if(typeof payload.text!=='string')throw Error('Texte JSON d’import requis.');
      if(Buffer.byteLength(payload.text,'utf8')>CHAMP_IMPORT_LIMIT_BYTES)throw Error('Fichier trop volumineux (24 Mio UTF-8 maximum).');
      run("pendingSave=parseSaveDocument(nativePayload.text);if(pendingSave.state.lnrMode)throw Error('Les effectifs réels ne sont pas chargés dans le moteur natif.');");
      validateCalendarState(calendarState('pendingSave.state'));
      const imported=JSON.parse(run('JSON.stringify({binding:pendingSave.state.identityPack,database:pendingSave.state.commonDatabase?.id})')),bound=imported.binding&&packs.get(imported.binding.id);if(bound&&bound.meta.databaseId!==imported.database)throw Error('Pack incompatible avec cette édition.');
      run("if(!confirmSaveImport())throw Error('Import annulé : sauvegarde impossible.');");
     }
     let extra=null;if(SYSTEM_COMMANDS.has(command)){ctx.nativeCommand=command;extra=run('nativeSystems.execute(nativeCommand,nativePayload)');}
     else if(['set_collective_focus','set_opponent_level','set_delegation','set_development_focus','promote_academy','scout_mission','set_lineup','set_tactics','set_player_load','recruit','extend_contract','next_season','substitute','promote_cover'].includes(command)){ctx.nativeCommand=command;extra=run('nativeGestion(nativeCommand,nativePayload)');}
     if(command==='new_career')run('CDNativeAcademyGroups.start(S)');
     else if(command==='next_season')run('CDNativeAcademyGroups.afterSeason(S,'+previousAcademyClub+');');
     run('nativeAttributeStore.complete(S,nativeAttributeBaseline,'+liveOnly+');save();validateCareer(S)');
     const model=snapshot({command,payload});if(extra)Object.assign(model.meta,JSON.parse(JSON.stringify(extra)));
     // Advancing the presentation cursor can leave both the career and RNG
     // untouched. Keep the previous durable revision and its recovery copy.
     if(command==='tick'&&committedFiles&&seed===priorSeed&&JSON.stringify(store)===priorStore&&profileFilesVersion()===committedFiles)clock=priorClock;
     else persist();
     return {id,ok:true,model};
    }catch(error){
     seed=priorSeed;clock=priorClock;store=JSON.parse(priorStore);ctx.nativePrior=JSON.parse(prior);run('nativeSystems.clearTransient()');ctx.nativePrior.saveError=ctx.nativePrior.saveError||error.storageFailure===true;
     run('S=nativePrior.state;if(S?.live&&nativePrior.playback)MATCH_PLAYBACK.set(S.live,nativePrior.playback);pendingSave=null;lastSaveError=nativePrior.saveError;');
     throw error;
    }finally{deferredDelegateActive=false;deferredDelegateRead=false;delete ctx.nativePayload;delete ctx.nativePrior;delete ctx.nativeMode;delete ctx.nativeCommand;delete ctx.nativeBinding;delete ctx.nativeAttributeBaseline;}
   }catch(error){return {id,ok:false,model:closed?null:snapshot(),error:error.message};}
  }
  return {handle,close};
 }catch(e){close();throw e;}
}
module.exports={createBridge,applicationRoot,IMPORT_LIMIT_BYTES,REQUEST_LIMIT_BYTES,WORLD_IMPORT_LIMIT_BYTES,WORLD_REQUEST_LIMIT_BYTES,EXTENDED_IMPORT_LIMIT_BYTES,EXTENDED_REQUEST_LIMIT_BYTES,CHAMP_IMPORT_LIMIT_BYTES,CHAMP_REQUEST_LIMIT_BYTES,CORE_FILES:Object.freeze([...MODULES])};
if(require.main===module){
 let bridge;
 try{const rawSeed=process.env.CD_GODOT_SEED;let seed;if(rawSeed!==undefined){seed=Number(rawSeed);if(!/^(0|[1-9]\d*)$/.test(rawSeed)||!Number.isInteger(seed)||seed<0||seed>0xffffffff)throw Error('CD_GODOT_SEED doit être un entier entre 0 et 4294967295.');}const index=process.argv.indexOf('--data-dir');bridge=createBridge({...(seed===undefined?{}:{seed}),dataDir:index>=0?process.argv[index+1]:path.join(process.env.LOCALAPPDATA||require('node:os').homedir(),'CadrageDebordement','PrototypeGodot')});}
 catch(e){process.stdout.write(JSON.stringify({id:null,ok:false,model:null,error:e.message})+'\n');process.exitCode=1;return;}
 const input=readline.createInterface({input:process.stdin,crlfDelay:Infinity});
 input.on('line',line=>{
  let result;try{const bytes=Buffer.byteLength(line);if(bytes>CHAMP_REQUEST_LIMIT_BYTES)throw Error('Message trop volumineux.');const request=JSON.parse(line);if(bytes>REQUEST_LIMIT_BYTES){if(request.command!=='import'||typeof request.payload?.text!=='string'||Buffer.byteLength(request.payload.text,'utf8')>CHAMP_IMPORT_LIMIT_BYTES)throw Error('Message trop volumineux.');const state=JSON.parse(request.payload.text)?.state,edition=worldEditions.forState(state);if(!edition||bytes>edition.limits.requestBytes||Buffer.byteLength(request.payload.text,'utf8')>edition.limits.saveBytes)throw Error('Message trop volumineux.');}result=bridge.handle(request);}catch(e){result={id:null,ok:false,model:null,error:e.message};}
  process.stdout.write(JSON.stringify(result)+'\n');if(result.ok&&line&&JSON.parse(line).command==='shutdown'){input.close();process.stdin.destroy();}
 });
 input.on('close',()=>bridge.close());process.on('exit',()=>bridge.close());
}

'use strict';
// Prototype bridge: local private stdio only. Never load browser UI, the source
// identity catalogue, the test harness, a network server, or protocol-supplied code.
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),readline=require('node:readline'),{randomUUID}=require('node:crypto');
const projection=require('./model.cjs'),gestion=require('./gestion.cjs'),common=require('./common-rosters.cjs'),mediaPacks=require('./media-packs.cjs'),pressIdentities=require('./press-identities.cjs'),staff=require('./staff.cjs'),decisions=require('./decisions.cjs'),systems=require('./native-systems.cjs');
const playerAttributes=require('./player-attributes.cjs');
const playerKnowledge=require('./player-knowledge.cjs'),knowledgeProjection=playerKnowledge.factory();
const positionAptitudes=require('./position-aptitudes.cjs');
const careerVariation=require('./career-variation.cjs');
const potentialEvolution=require('./potential-evolution.cjs'),potentialEvolutionValidation=potentialEvolution();
const inSeasonDevelopment=require('./in-season-development.cjs');
const clubTransfers=require('./club-transfers.cjs'),clubDirections=require('./club-directions.cjs'),boardNames=require('./staff-completion.cjs');
const profileSafetyFactory=require('./profile-safety.cjs');
const makePlayerFacts=require('./player-facts.cjs');
const makeNational=require('./international-native.cjs');
const {factory:internationalCallups}=require('./international-callups.cjs');
const factsFile=path.join(__dirname,'player-real-facts.json');
const playerFactsCatalogue=fs.existsSync(factsFile)?JSON.parse(fs.readFileSync(factsFile,'utf8')):{};
const professionalDepth=require('./professional-depth.cjs');
const epcrPreparation=require('./epcr-preparation.cjs');
const competitionEditor=require('./competition-editor.cjs');
const {calendarContext}=require('./calendar-clock.cjs');
const franceCalendar=require('./france-calendar-cadence.cjs');
const confirmMatchResult=require('./match-result.cjs');
const matchDirect=require('./match-direct.cjs');
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
const referenceClubs=(champRegistry??nationaleRegistry??japanRegistry??pacificRegistry??worldRegistry).clubs;
function clubCountry(club){
 if(club.country==='GB'){
  if(club.id===42)return 'IRE';
  if(club.id===44||club.id===45)return 'SCO';
  if(club.id>=46&&club.id<=49)return 'WAL';
  return 'ENG';
 }
 return {FR:'FRA',IE:'IRE',IT:'ITA',ZA:'RSA',GE:'GEO',NZ:'NZL',AU:'AUS',FJ:'FIJ',JP:'JPN'}[club.country];
}
const factClubs=Object.fromEntries(referenceClubs.map(club=>[club.id,clubCountry(club)]));
const factOrigins=Object.fromEntries(referenceClubs.flatMap(club=>club.players.map(player=>[player.id,factClubs[club.id]])));
const nationalFacts=makePlayerFacts(playerFactsCatalogue,factOrigins,factClubs);
const MODULES=['storage.js','world-data.js','rugby.js','frontrow.js','restarts.js','matchflow.js','playbook.js','manager.js','manager-squad.js','tactical-plans.js','match-actions.js','match2d.js','match-v61-advisor.js','match-cockpit.js','economy.js','development.js','finance-planning.js','board-planning.js','academy-planning.js','transfer-planning.js','career-history.js','career-integration.js','club-ai.js','reputation.js','coach-market.js','coach-opportunities.js','facilities.js','rugby-world.js','financial-recovery.js','world-career.js','ai-roster-cycle.js','v39.js','manager-mobility.js','saves.js','opposition.js','match-preparation.js','france-clubs.js','rugby-common-rosters.js','rugby-roster-foundation.js','lnr-v11-aging.js','france-competition.js','france-knockout.js','france-career.js','france-save-validation.js','match3d/scene-adapter.js','game.js'];
MODULES.splice(MODULES.indexOf('game.js'),0,...systems.files.filter(name=>!MODULES.includes(name)));
const SYSTEM_COMMANDS=new Set(systems.commands);
const IMPORT_LIMIT_BYTES=8*1024*1024,WORLD_IMPORT_LIMIT_BYTES=16*1024*1024,REQUEST_LIMIT_BYTES=17*1024*1024,WORLD_REQUEST_LIMIT_BYTES=34*1024*1024,EXTENDED_IMPORT_LIMIT_BYTES=20*1024*1024,EXTENDED_REQUEST_LIMIT_BYTES=42*1024*1024,CHAMP_IMPORT_LIMIT_BYTES=24*1024*1024,CHAMP_REQUEST_LIMIT_BYTES=50*1024*1024;
// Mode unique « Monde » (décision de Léo, 13/11/2026) : le joueur ne crée et ne charge que des
// carrières du Monde complet. Les anciens modes (fiction 14 clubs, France 30 clubs « common »/« france »,
// compétition personnalisée, éditions partielles du Monde) restent accessibles en interne aux seuls
// tests non encore migrés, par le drapeau explicite legacyModes de createBridge ou CD_MODES_HERITES=1
// (déclaré en tête de chaque fichier de test concerné, et pour les recettes Godot).
const WORLD_ONLY_MODE='world-champ';
const LEGACY_CAREER_MESSAGE='Cette carrière a été créée dans un ancien mode de jeu, qui n’existe plus : seul le mode Monde est disponible.';
const LEGACY_PURGE_NOTICE='Les carrières des anciens modes de jeu ont été retirées : seul le mode Monde existe désormais.';
// Clés du profil qui portent une carrière (jamais les réglages, packs ou préférences du joueur).
const CAREER_STATE_KEYS=['bdt-v1','bdt-backup-v1','bdt-before-import','bdt-recovery-invalid'];
const CAREER_SIDE_KEYS=['bdt-backup-development','bdt-backup-economy','bdt-matchday-pending','bdt-exported-at'];
const PRESS_PROGRESSION=new Set(['advance_day','begin_match','finish_round','next_season','advance_pacific_preparation','advance_japan_preparation','advance_champ_preparation']);
const COMMANDS=new Set([...SYSTEM_COMMANDS,'population_enable','academy_groups_preview','academy_groups_enable','competition_editor_preview','epcr_preview','set_collective_focus','set_opponent_level','set_delegation','set_development_focus','promote_academy','scout_mission','snapshot','new_career','train','auto_lineup','begin_match','tick','pause','delegate','advance_day','finish_round','advance_pacific_preparation','advance_japan_preparation','advance_champ_preparation','save','import','export','shutdown','set_lineup','set_tactics','set_penalty_policy','set_player_load','recruit','extend_contract','next_season','substitute','promote_cover','recover_profile','pack_inspect','pack_install','pack_select']);
COMMANDS.add('observe_player');
COMMANDS.add('restore_checkpoint');
COMMANDS.add('remove_checkpoint');
COMMANDS.add('calendar_template');
COMMANDS.add('calendar_mail_decide');
const NATIONAL_COMMANDS=['national_take_job','national_leave_job','national_play_match'];
NATIONAL_COMMANDS.forEach(command=>COMMANDS.add(command));
const NATIONAL_ONLY_COMMANDS=new Set(['new_career','import','save','advance_day','next_season',...NATIONAL_COMMANDS]);
const BLOCKED_AFTER_RESULT=new Set(['begin_match','tick','pause','delegate','train','auto_lineup','substitute','next_season']);
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
 if(options.matchHighlights!==undefined&&options.matchHighlights!==null&&!matchDirect.NIVEAUX.includes(options.matchHighlights))throw Error('Niveau de temps forts inconnu.');
 if(options.legacyModes!==undefined&&typeof options.legacyModes!=='boolean')throw Error('Drapeau des anciens modes invalide.');
 const legacyModes=options.legacyModes??process.env.CD_MODES_HERITES==='1';
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
 let ctx,profileError='',recoveryBackup=null,loadedProfile=null;
 const profileSafety=profileSafetyFactory.createStore(dataDir);
 let deferredDelegateActive=false,deferredDelegateRead=false;
 let legacyPurgeNotice='';
 // Mode unique Monde (Léo, 13/11/2026) : les carrières des anciens modes n'étaient que des essais. Au
 // chargement, elles sont supprimées sans rien demander (profil, fichier précédent, copies de sécurité) ;
 // réglages, packs et préférences restent intacts. Une ligne d'information est montrée une fois.
 const obsoleteState=state=>!!state&&typeof state==='object'&&Array.isArray(state.clubs)&&worldEditions.forState(state)?.mode!==WORLD_ONLY_MODE;
 const careerOf=value=>value&&typeof value==='object'&&value.state&&typeof value.state==='object'?value.state:value;
 const obsoleteText=text=>{if(typeof text!=='string')return false;try{const state=careerOf(JSON.parse(text));return Array.isArray(state?.clubs)&&obsoleteState(state);}catch{return false;}};
 function purgeLegacyCareers(){
  let changed=false;
  if(obsoleteText(store['bdt-v1'])){for(const key of [...CAREER_STATE_KEYS,...CAREER_SIDE_KEYS])if(Object.hasOwn(store,key)){delete store[key];changed=true;}}
  for(const key of CAREER_STATE_KEYS)if(obsoleteText(store[key])){delete store[key];changed=true;}
  const previous=path.join(dataDir,'donnees-precedentes.json');
  try{if(fs.existsSync(previous)&&obsoleteText(JSON.parse(fs.readFileSync(previous,'utf8')).store?.['bdt-v1'])){fs.unlinkSync(previous);changed=true;}}catch{}
  try{if(profileSafety.purge(obsoleteState).length)changed=true;}catch{}
  if(!changed)return;
  if(fs.existsSync(file)){const temp=path.join(dataDir,'donnees.tmp-'+randomUUID());fs.writeFileSync(temp,JSON.stringify({protocol:1,seed,clock,store}));fs.renameSync(temp,file);}
  legacyPurgeNotice=LEGACY_PURGE_NOTICE;
 }
 const deferredReadError=new Error('Lecture storage pendant une délégation différée.');
 try{
  if(fs.existsSync(file)){
   try{loadedProfile=profileSafety.readProfile(file);const saved=JSON.parse(loadedProfile.toString('utf8'));
   if(saved.protocol!==1||!Number.isInteger(saved.seed)||!Number.isFinite(saved.clock)||!saved.store||typeof saved.store!=='object'||Array.isArray(saved.store))throw Error('Profil PrototypeGodot illisible ou incompatible.');
   store=saved.store;seed=saved.seed>>>0;clock=saved.clock;}catch(e){profileError='Profil illisible : '+e.message;store={};}
  }
  if(!legacyModes&&!profileError)purgeLegacyCareers();
  const math=Object.create(Math);math.random=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296;};
  class EngineDate extends Date{constructor(...args){super(...(args.length?args:[clock]));}static now(){return clock;}}
  const storage={offline:true,directory:dataDir,getItem:key=>{if(deferredDelegateActive){deferredDelegateRead=true;throw deferredReadError;}return store[key]??null;},setItem:(key,value)=>{store[key]=String(value);},removeItem:key=>{delete store[key];}};
  const element={innerHTML:'',textContent:'',style:{}};
  ctx=vm.createContext({console:{log(){},warn(){},error(){}},Intl,Math:math,Date:EngineDate,Set,JSON,CDNativeHeadless:true,document:{querySelector:()=>element},window:{CDNativeHeadless:true,CDOfflineStorage:storage,CDOfflineError:true},localStorage:storage,setTimeout:()=>0,clearTimeout(){},setInterval:()=>0,clearInterval(){},nativeDataDirectory:dataDir});
  const run=source=>vm.runInContext(source,ctx,{timeout:15000});
  ctx.nativeMandatoryPress=options.mandatoryPress===true;
  ctx.nativeLegacyModes=legacyModes;ctx.nativeLegacyCareerMessage=LEGACY_CAREER_MESSAGE;
  const calendarState=(source='S')=>JSON.parse(run(`JSON.stringify({planning:${source}?.calendarPlanning,mail:${source}?.calendarMail})`));
  function validateCalendarState(state){
   if(calendarPlanning.validateState(state.planning)===false||calendarMail.validate(state.mail)===false)throw Error('Planification du calendrier invalide.');
  }
  ctx.nativeKnowledgeValidate=knowledgeProjection.validate;
  ctx.nativePotentialEvolutionValidate=potentialEvolutionValidation.validate;
  const dist=options.distDir?path.resolve(options.distDir):fs.existsSync(path.join(__dirname,'core'))?path.join(__dirname,'core'):path.resolve(__dirname,'../../dist');
  for(const name of MODULES)run(fs.readFileSync(path.join(dist,name),'utf8'));
  // Découpage des longues courses du moteur (présentation du journal, docs/match-courses-20261112.md) :
  // CD_MATCH_COURSES=0 (ou l'option matchCourses:false) rend l'ancien journal, un seul fait jusqu'à la ligne.
  if(options.matchCourses===false||process.env.CD_MATCH_COURSES==='0')ctx.MATCH_COURSES_DECOUPEES=false;
  // Notes de match : CD_NOTES_EFFETS=0 (ou l'option notesEffets:false) garde les notes sans leurs effets (mesure d'équilibre).
  if(options.notesEffets===false||process.env.CD_NOTES_EFFETS==='0')ctx.CDNotesEffets=false;
  // Carrières aux salaires liés au niveau : plancher des discussions de contrat, avant tout habillage de la validation.
  run(require('./club-budget.cjs').VALIDATION);
  ctx.nativeWorldRegistryText=JSON.stringify(worldRegistry);
  if(pacificRegistry)ctx.nativeWorldPacificRegistryText=JSON.stringify(pacificRegistry);
  if(japanRegistry)ctx.nativeWorldJapanRegistryText=JSON.stringify(japanRegistry);
  if(nationaleRegistry)ctx.nativeWorldNationaleRegistryText=JSON.stringify(nationaleRegistry);
  if(champRegistry)ctx.nativeWorldChampRegistryText=JSON.stringify(champRegistry);
  run(`render=()=>{};toast=()=>{};startTimer=()=>{};save=()=>{if(S&&!validatingStartup){gameStorage.setItem('bdt-v1',JSON.stringify(S));lastSaveError=false;}};validatingStartup=false;const nativeCareerVariation=(${careerVariation.toString()})();const nativeProfessionalDepth=(${professionalDepth.toString()})();${worldVm.bootstrap()}const nativePositionAptitudes=(${positionAptitudes.toString()})();nativePositionAptitudes.installHooks();const CDCommonCareer=(${common.toString()})(CDWorldSeniorCalibration);const nativeAttributeStore=(${playerAttributes.toString()})();const nativeFacts=(${makePlayerFacts.toString()})(${JSON.stringify(playerFactsCatalogue)},${JSON.stringify(factOrigins)},${JSON.stringify(factClubs)});
   const nativeCallups=(${internationalCallups.toString()})();
   const nativeInternationalStatus=new WeakMap();
   const nativePlayerAttributes=p=>{
    const career=S?.national?.career;
    if(career&&!nativeInternationalStatus.has(career))nativeInternationalStatus.set(career,nativeCallups.internationalStatus(career));
    const status=career&&nativeInternationalStatus.get(career);
    return {...nativeAttributeStore.project(p),...nativePositionAptitudes.project(p),playerFacts:{...nativeFacts.project(p.id,status?.caps.get(p.id),p),onInternationalDuty:status?.released.has(p.id)??false}};
   };
   const nativeBaseModel=${projection.toString()};const nativeModel=(${worldModel.toString()})(nativeBaseModel,(${publishedVenue.factory.toString()})(${JSON.stringify(publishedVenue.data)}),${JSON.stringify(clubHistory)});const nativeDecisions=${decisions.toString()};const nativeGestion=${gestion.toString()};`);
  ctx.nativeStaffCareerSourcesText=JSON.stringify(Object.fromEntries([run('CDCommonRosters.id'),...worldEditions.entries.map(e=>e.id)].map(id=>[id,staff.forDatabase(id).registry.clubs])));
  run(systems.bootstrap());delete ctx.nativeStaffCareerSourcesText;
  run(`const nativeClubTransfers=(${clubTransfers.toString()})();nativeClubTransfers.installHooks();`);
  // Directions des clubs gérés (carrières mondiales créées avec elles) ; validation de leur état.
  run(`const nativeClubDirections=(${clubDirections.toString()})(nativeClubTransfers,(${boardNames.factory.toString()})());
   const nativeClubDirectionsValidator=validateCareer;validateCareer=state=>{const result=nativeClubDirectionsValidator(state);nativeClubDirections.validate(state);return result;};`);
  run(`const nativeInSeasonDevelopment=(${inSeasonDevelopment.toString()})();nativeInSeasonDevelopment.installHooks();const nativePotentialEvolution=(${potentialEvolution.toString()})();nativePotentialEvolution.installHooks();`);
  run(`const nativeKnowledge=(${playerKnowledge.factory.toString()})();nativeKnowledge.installHooks();
   const nativeKnowledgeValidator=validateCareer;validateCareer=state=>{const result=nativeKnowledgeValidator(state);nativeKnowledge.validate(state);return result;};`);
  run(`const nativeFranceCalendar=(${franceCalendar.toString()})(CDFranceCompetition.userFixture);
   const nativeValidateDaily=validateCareer;
   validateCareer=state=>{const result=nativeValidateDaily(state);nativeFranceCalendar.validate(state);return result;};
   const nativeDailyStatus=()=>CDWorldCareer.active(S)?CDWorldCareer.dailyStatus(S):nativeFranceCalendar.project(S)?.calendarCadence??null;
   function nativeEnableDailyCalendar(){
    if(!S)return;
    CDWorldCareer.enableDaily(S);
    if(S.franceCalendar!==undefined)return;
    const calendar=nativeFranceCalendar.project(S,true);
    if(calendar)S.franceCalendar={day:calendar.calendarCadence.day};
   }
   const nativeConfirmMatchResult=(${confirmMatchResult.toString()});`);
  // Match en temps forts (mode de base ; repli CD_MATCH_TEMPS_FORTS=0) : lecture seule du match en cours.
  run(`const nativeMatchDirect=(${matchDirect.lecteur.toString()})();`);
  let matchHighlights=options.matchHighlights??null;
  // Chorégraphe des temps forts (présentation seule, éteint par défaut) : CD_MATCH_CHOREGRAPHE=1.
  const matchChoreography=options.matchChoreography??process.env.CD_MATCH_CHOREGRAPHE==='1';
  const matchDirectReader={profils:ids=>JSON.parse(run('JSON.stringify(nativeMatchDirect.profils('+JSON.stringify(ids)+'))')),scenes:indices=>JSON.parse(run('JSON.stringify(nativeMatchDirect.scenes('+JSON.stringify(indices)+'))')),transformation:(index,made)=>JSON.parse(run('JSON.stringify(nativeMatchDirect.transformation('+Number(index)+','+(made===true)+'))')),etat:()=>JSON.parse(run('JSON.stringify(nativeMatchDirect.etat())'))};
  try{run("if(loadSaveFailure)throw Error(loadSaveFailure);if(S){validateCareer(S);if(S.lnrMode)throw Error('Les effectifs réels ne sont pas chargés dans le moteur natif.');if(!nativeLegacyModes&&CDWorldEditions.forState(S)?.mode!=='world-champ')throw Error(nativeLegacyCareerMessage);if(normalizeAcademyPotential(S))validateCareer(S);nativeProfessionalDepth.fill(S);nativeAttributeStore.complete(S);if(S.live&&!S.live.finished)S.live.paused=true;if(S.national?.role?.club!==false)nativeSystems.domain('press').observeInvitation();}");validateCalendarState(calendarState());}catch(e){profileError='Profil illisible : '+e.message;run('S=null;');}
  const national=makeNational(run,ctx,nationalFacts,options.internationalCareer===true);
  const updatePressPolicy=()=>{ctx.nativeMandatoryPress=options.mandatoryPress===true&&!national.isNationalOnly();};
  try{if(options.dailyCalendar)run('nativeEnableDailyCalendar()');national.initialize(seed);updatePressPolicy();}
  catch(e){profileError='Profil illisible : '+e.message;run('S=null;');}
  let resumeCheckpoint=null;
  if(loadedProfile&&!profileError&&run('!!S')){
   const original=JSON.parse(loadedProfile.toString('utf8')).store['bdt-v1'];
   if(original!==run('JSON.stringify(S)'))resumeCheckpoint={profile:loadedProfile,replaySeed:seed,replayClock:clock,text:run('JSON.stringify(createSaveDocument())'),...JSON.parse(run('JSON.stringify({club:S.clubs[S.club].name,season:S.season,round:S.round??0})'))};
  }
  const protectCurrent=(reason,replaySeed=seed,replayClock=clock)=>{
   if(!run('!!S')||!fs.existsSync(file))return null;
   return profileSafety.checkpoint({profile:profileSafety.readProfile(file),replaySeed,replayClock,text:run('JSON.stringify(createSaveDocument())'),reason,...JSON.parse(run('JSON.stringify({club:S.clubs[S.club].name,season:S.season,round:S.round??0})'))});
  };
  const legacyDatabase=JSON.parse(run('JSON.stringify(CDCommonRosters)')),packs=mediaPacks.createStore(dataDir,legacyDatabase,worldRegistry,pacificRegistry,japanRegistry,nationaleRegistry,champRegistry,pressIdentities.catalogue(JSON.parse(run('JSON.stringify(CDPressQuestionBank.journalists)'))));
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
  function projectFranceCalendar(model){
   const calendar=JSON.parse(run('JSON.stringify(nativeFranceCalendar.project(S))'));
   if(!calendar)return;
   Object.assign(model.meta,calendar);
   if(model.next)Object.assign(model.next,{
    date:run('nativeFranceCalendar.date(S.season,S.franceMode.week)'),dateSimulated:true,
    kickoffLocal:'15:00',kickoffSource:'simulated-not-official',timezone:'Europe/Paris'
   });
   if(calendar.calendarCadence.resultConfirmed){
    const fixture=model.calendar.find(f=>f.week===model.meta.week&&!f.played);
    if(fixture&&model.live){fixture.score=model.live.score;fixture.played=true;}
    model.next=null;model.live=null;
   }
  }
  const projectKnowledge=model=>{
   knowledgeProjection.project(model,JSON.parse(run('JSON.stringify(nativeKnowledge.visibility(S))')));
   const trends=JSON.parse(run('JSON.stringify(Object.fromEntries((S?.clubs[S.club]?.players||[]).map(p=>[p.id,nativePotentialEvolution.project(S,p.id)])))'));
   for(const p of model.squad||[])if(p.knowledge?.owned&&trends[p.id])p.potentialDevelopment=trends[p.id];
   return model;
  };
  // Une projection lit l'état sans le modifier : le dossier d'avant-match (feuille adverse
  // complète) y est calculé une seule fois puis partagé. Hors projection, chaque appel
  // recalcule comme avant. CD_ENGINE_MEMO=0 coupe ce partage (contrôle d'identité).
  const projectionMemo=process.env.CD_ENGINE_MEMO!=='0';
  if(projectionMemo)run(`{const original=matchDossier;let active=false,cached;globalThis.nativeProjectionMemo=on=>{active=on;cached=undefined;};matchDossier=function(){if(!active)return original();if(cached===undefined)cached=original();return cached;};}`);
  const snapshotRaw=operation=>{if(!projectionMemo)return snapshotProjection(operation);run('nativeProjectionMemo(true)');try{return snapshotProjection(operation);}finally{run('nativeProjectionMemo(false)');}};
  const snapshotProjection=operation=>{updatePressPolicy();const m=JSON.parse(run('JSON.stringify(nativeModel())'));projectFranceCalendar(m);m.decisions=JSON.parse(run('JSON.stringify(nativeDecisions())'));if(m.decisions?.recruitment)m.decisions.recruitment.reports.push(...JSON.parse(run('JSON.stringify(nativeKnowledge.reports(S))')));m.clubLife=JSON.parse(run('JSON.stringify(nativeSystems.project())'));national.project(m);m.meta.profileError=profileError;m.meta.legacyPurgeNotice=legacyPurgeNotice;m.meta.legacyModes=legacyModes;m.meta.recoveryRequired=!!profileError;m.meta.recoveryBackup=recoveryBackup;m.meta.profileSafety=profileSafety.project();m.meta.academyGroupPolicy=run('S?.academyGroupPolicy??0');m.meta.careerVariation=JSON.parse(run('JSON.stringify(S?.careerVariation??null)'));const result=packs.project(staff.project(m),JSON.parse(run('JSON.stringify(S?.identityPack||null)')),creation(),creation('world'),creation('world-pacific'),creation('world-japan'),creation('world-nationale'),creation('world-champ'));staff.applyCareerPresentation(result);const custom=result.clubLife?.customCompetition;if(custom&&result.leagues?.length===1){result.leagues[0].name=custom.name;result.leagues[0].notice=custom.notice;}result.epcrPreparation=epcrPreparation.project(result);projectCalendar(result,operation);if(matchHighlights&&result.live){/* Présentation seule : si la projection échoue, le match reste jouable dans le direct d'origine et la raison est jointe. */try{result.live.direct=matchDirect.project(result,matchHighlights,matchDirectReader,{choregraphe:matchChoreography});}catch(error){result.live.directError=String(error?.message||error);}}return result;};
  // Raw models stay private; every protocol path still applies the final
  // knowledge boundary after attaching receipts, previews or export metadata.
  const snapshot=operation=>projectKnowledge(snapshotRaw(operation));
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
   if(resumeCheckpoint)profileSafety.checkpoint({...resumeCheckpoint,reason:'adaptation-reprise'});
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
   committedFiles=profileFilesVersion();resumeCheckpoint=null;
  };
  // Instrumentation des allers-retours (CD_ENGINE_TIMING=1) : durées par phase, sans effet sur la simulation.
  const timing=options.timing===true||process.env.CD_ENGINE_TIMING==='1';let phases=null,phaseAt=0;
  const mark=label=>{if(!phases)return;const now=performance.now();phases[label]=Math.round(((phases[label]||0)+now-phaseAt)*10)/10;phaseAt=now;};
  function handle(request){
   if(!timing)return handleCommand(request);
   phases={};phaseAt=performance.now();const started=phaseAt;
   const response=handleCommand(request);mark('reste');phases.total=Math.round((performance.now()-started)*10)/10;
   if(response&&typeof response==='object')response.timing=phases;phases=null;return response;
  }
  function handleCommand(request){
   let id=null;
   try{
    if(!request||typeof request!=='object'||Array.isArray(request))throw Error('Message JSON invalide.');
    if(!(Number.isSafeInteger(request.id)&&request.id>=0||typeof request.id==='string'&&request.id.length>0&&request.id.length<=100&&!/[\r\n]/.test(request.id)))throw Error('Identifiant de commande invalide.');
    id=request.id;if(closed)throw Error('Le moteur est fermé.');
    if(!COMMANDS.has(request.command))throw Error('Commande inconnue ou interdite.');
    let payload=request.payload??{};if(typeof payload!=='object'||payload===null||Array.isArray(payload))throw Error('Paramètres de commande invalides.');
    let command=request.command,restoring=null;
    // Budget réaliste des carrières aux salaires liés au niveau : branché avant toute commande,
    // y compris le premier snapshot en lecture seule après une reprise (plancher et prévision).
    if(!ctx.nativeClubBudget){ctx.nativeClubBudget=require('./club-budget.cjs');ctx.nativeStartingSalaries=require('./starting-salaries.cjs');ctx.nativeLeagueEconomy=require('./league-economy.cjs');run(ctx.nativeClubBudget.BRANCHEMENT);}
    if(command==='snapshot')return {id,ok:true,model:snapshot()};
    if(command==='recover_profile'){if(!profileError)throw Error('Aucun profil à récupérer.');if(payload.confirmed!==true)throw Error('Confirmation requise pour préserver puis remplacer le profil illisible.');const backup=path.join(dataDir,'donnees-endommagees-'+randomUUID()+'.json');fs.copyFileSync(file,backup,fs.constants.COPYFILE_EXCL);recoveryBackup=backup;profileError='';store={};run('S=null;loadSaveFailure="";lastSaveError=false;');return {id,ok:true,model:snapshot()};}
    if(profileError&&!['snapshot','shutdown'].includes(command))throw Error(profileError+' Confirmez la récupération du profil.');
    if(command==='competition_editor_preview'){const model=snapshotRaw();model.competitionEditor=competitionEditor.project(payload);return {id,ok:true,model:projectKnowledge(model)};}
    if(command==='epcr_preview'){const model=snapshotRaw();model.epcrPreparation=epcrPreparation.project(model,payload);return {id,ok:true,model:projectKnowledge(model)};}
    if(command==='pack_inspect'){packs.inspect(payload.path,edition(payload.mode??currentEdition()));return {id,ok:true,model:snapshot()};}
    if(command==='pack_install'){packs.install(payload.path,payload.digest,payload.mode===undefined?undefined:edition(payload.mode));return {id,ok:true,model:snapshot()};}
    if(command==='pack_select'&&payload.scope==='creation'){const mode=payload.mode??'common',databaseId=edition(mode),key=creationKey(mode),selected=payload.id==='base'?null:packs.get(payload.id);if(payload.id!=='base'&&!selected)throw Error('Pack non installé.');if(selected&&selected.meta.databaseId!==databaseId)throw Error('Pack incompatible avec cette édition.');const prior=store[key];try{store[key]=payload.id;persist();}catch(e){if(prior===undefined)delete store[key];else store[key]=prior;throw e;}return {id,ok:true,model:snapshot()};}
    if(command==='export'){const model=snapshotRaw();model.meta.exportText=run('JSON.stringify(createSaveDocument())');return {id,ok:true,model:projectKnowledge(model)};}
    if(command==='shutdown'){const model=snapshotRaw();close();return {id,ok:true,model:projectKnowledge(model)};}
    if(command==='remove_checkpoint'){const receipt=profileSafety.remove(payload.id,payload.confirmed);const model=snapshotRaw();model.meta.profileSafetyReceipt=receipt;return {id,ok:true,model:projectKnowledge(model)};}
    if(command==='restore_checkpoint'){if(payload.confirmed!==true)throw Error('Confirmation explicite requise pour reprendre cette copie.');restoring=profileSafety.load(payload.id);command='import';payload={...payload,text:restoring.text};}
    const advancesCareer=PRESS_PROGRESSION.has(command)||command==='match_talk_continue'&&payload.phase==='post';
    updatePressPolicy();
    if(national.isNationalOnly()&&!NATIONAL_ONLY_COMMANDS.has(command))throw Error('Cette décision est réservée au manager d’un club.');
    if(ctx.nativeMandatoryPress&&advancesCareer)run('nativeSystems.domain("press").guardProgress()');
    mark('garde');const prior=run('JSON.stringify({state:S,playback:S?.live?playback(S.live):null,saveError:lastSaveError})'),priorStore=JSON.stringify(store),priorSeed=seed,priorClock=clock;mark('copie_annulation');
    try{
     ctx.nativePayload=JSON.parse(JSON.stringify(payload));
     if(command==='new_career'){
      if(!legacyModes&&payload.mode!==WORLD_ONLY_MODE)throw Error('Seul le mode Monde est disponible pour une nouvelle carrière.');
      if(payload.varyCurrent!==undefined&&typeof payload.varyCurrent!=='boolean')throw Error('Option de variation du niveau actuel invalide.');
      if(payload.varyPotential!==undefined||payload.careerVariation!==undefined||payload.seed!==undefined)throw Error('Le potentiel varie à chaque nouvelle carrière ; paramètres de variation non autorisés.');
     }
     if(command!=='new_career'&&command!=='import'&&!run('!!S'))throw Error('Créez ou importez une carrière.');
     ctx.nativeCommand=command;
     run("nativeSystems.domain('matchTalks').guard(nativeCommand,nativePayload);nativeSystems.domain('sceneInvitations').guard(nativeCommand,nativePayload);nativeSystems.domain('clubMeetings').guard(nativeCommand,nativePayload);");
     if(command==='next_season')national.checkSeason();
     if(BLOCKED_AFTER_RESULT.has(command)&&run('nativeDailyStatus()?.resultConfirmed===true'))throw Error('Résultat confirmé. Continuez jusqu’à la clôture de la semaine.');
     if(command==='interclub_negotiate'||command==='academy_groups_preview'){
      ctx.nativeCommand=command;
      const extra=command==='academy_groups_preview'?{academyGroups:run('CDNativeAcademyGroups.preview(S)')}:run('nativeSystems.execute(nativeCommand,nativePayload)');
      if(run('JSON.stringify(S)')!==JSON.stringify(JSON.parse(prior).state)||seed!==priorSeed||JSON.stringify(store)!==priorStore)throw Error('Une consultation ne peut pas modifier la carrière.');
      const model=snapshotRaw();Object.assign(model.meta,JSON.parse(JSON.stringify(extra)));return {id,ok:true,model:projectKnowledge(model)};
     }
     ctx.nativeKnowledgeBefore=run('nativeKnowledge.before(S)');ctx.nativeKnowledgeCommand=command;
     if(!restoring&&options.now===undefined)clock=Date.now();
     const liveOnly=command==='tick'||command==='delegate';
     const previousAcademyClub=command==='next_season'?run('S.club'):null;
     ctx.nativePressPrevious=advancesCareer?run('nativeSystems.domain("press").context(S)'):null;
     const advancesWithinWeek=command==='advance_day'&&run('(nativeDailyStatus()?.day??6)<6');
     ctx.nativeAttributeBaseline=advancesWithinWeek||['new_career','import'].includes(command)?null:run('nativeAttributeStore.before(S,'+liveOnly+');');
     if(NATIONAL_COMMANDS.includes(command)){
      national.command(command,payload);
     }else if(command==='observe_player'){
      ctx.nativeKnowledgeReceipt=run(`nativeKnowledge.plan(S,nativePayload,{charge:amount=>ledgerEntry('Observation ciblée',-amount),message:(title,body)=>managerMessage(title,body,'recruitment','recruitment')})`);
     }else if(command==='population_enable'){
      if(payload.confirmed!==true||Object.keys(payload).some(k=>!['confirmed','context'].includes(k)))throw Error('Confirmez explicitement la nouvelle politique de population.');
      const context=JSON.parse(run('JSON.stringify({season:S.season,week:S.franceMode?.version===1?S.franceMode.week:S.round,club:S.club})'));
      if(!payload.context||Object.keys(payload.context).length!==3||['season','week','club'].some(k=>payload.context[k]!==context[k]))throw Error('Le contexte de carrière a changé.');
      if(!run("typeof enablePopulationPolicy==='function'&&enablePopulationPolicy()"))throw Error('Activation de population indisponible ou déjà effectuée.');
      run('CDStaffCareer.initialize(S)');
     }else if(command==='academy_groups_enable'){
      run('CDNativeAcademyGroups.enable(S,nativePayload)');
     }else if(command==='pack_select'){
      if(payload.scope!=='career'||!run('!!S?.commonDatabase'))throw Error('Sélection réservée à une carrière de base commune.');const pack=payload.id==='base'?null:packs.get(payload.id);if(payload.id!=='base'&&!pack)throw Error('Pack non installé.');if(pack&&pack.meta.databaseId!==run('S.commonDatabase.id'))throw Error('Pack incompatible avec cette édition.');ctx.nativeBinding=pack?{id:pack.meta.id,digest:pack.meta.digest}:null;run('if(nativeBinding)S.identityPack=nativeBinding;else delete S.identityPack');
     }else if(command==='new_career'&&payload.mode==='custom'){
      run("nativeSystems.domain('customCompetition').prepareCreation((({varyCurrent,...custom})=>custom)(nativePayload))");
      protectCurrent('nouvelle-carriere',priorSeed,priorClock);
      run("nativeSystems.domain('customCompetition').create((({varyCurrent,...custom})=>custom)(nativePayload))");
      if(run("typeof aiRosterPopulationActive==='function'&&aiRosterPopulationActive(S)"))run('CDStaffCareer.initialize(S)');
     }else if(command==='new_career'){
       const mode=payload.mode??'fiction',worldEdition=worldEditions.forMode(mode),selectedClub=payload.nationalRole==='nation'?0:payload.club;if(!worldEdition&&!['fiction','france','common'].includes(mode))throw Error('Mode de carrière invalide.');if(!Number.isInteger(selectedClub)||selectedClub<0||(worldEdition?!worldEdition.playable.includes(selectedClub):selectedClub>=(mode==='fiction'?14:30)))throw Error('Club invalide pour ce mode.');ctx.nativePayload.club=selectedClub;protectCurrent('nouvelle-carriere',priorSeed,priorClock);if(worldEdition)run('CDWorldCareer.start(nativePayload.club,nativePayload.mode,'+(options.dailyCalendar===true)+')');else run("if(nativePayload.mode==='common')CDCommonCareer.start(nativePayload.club);else start(nativePayload.club,nativePayload.mode??'fiction')");if((worldEdition||mode==='common')&&creation(mode)!=='base'){const selected=packs.get(creation(mode));if(!selected)throw Error('Pack de création absent ; réimportez-le ou choisissez Base.');if(selected.meta.databaseId!==edition(mode))throw Error('Pack incompatible avec cette édition.');ctx.nativeBinding={id:selected.meta.id,digest:selected.meta.digest};run('S.identityPack=nativeBinding');}
      if(options.dailyCalendar)run('nativeEnableDailyCalendar()');
      if(run("typeof aiRosterPopulationActive==='function'&&aiRosterPopulationActive(S)"))run('CDStaffCareer.initialize(S)');
     }else if(command==='train'){
      const mode=payload.mode??run('S.training');if(!['normal','repos','intense'].includes(mode))throw Error('Entraînement invalide.');
      if(run("!!S.live||S.phase==='ended'"))throw Error('Entraînement indisponible pendant le match ou après la saison.');
      if(!run('S.trained')){ctx.nativeMode=mode;run('S.training=nativeMode;trainWeek()');}
     }else if(command==='auto_lineup'){
      if(run('!!S.live'))throw Error('Composition indisponible pendant un match.');run('autoLineup()');
     }else if(command==='advance_day'){
      const offSeason=national.advance(payload.fromDate);
      if(offSeason){
       // The international calendar continues between two club seasons.
      }else if(run('S.franceCalendar!==undefined')){
       run(`{const step=nativeFranceCalendar.advance(S,nativePayload.fromDate);
        if(step.closeWeek)finishRound();S.franceCalendar=step.calendar;}`);
      }else{
       if(!run('S.worldMode?.day!==undefined'))throw Error('Avance journalière indisponible.');
       run('CDWorldCareer.advanceDay(S,nativePayload.fromDate)');
      }
     }else if(command==='begin_match'){
      if(run("!!S.live||S.phase==='ended'"))throw Error('Aucun nouveau match disponible.');
      if(run('nativeDailyStatus()?.matchReady===false'))throw Error('Le coup d’envoi est disponible le jour de la rencontre.');
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
      if(payload.minute!==undefined||payload.temps_forts!==undefined){
       // Direct en temps forts : un pas = une minute simulée, présentation à jour avant et après.
       if(!matchHighlights)throw Error('Temps forts non activés (repli CD_MATCH_TEMPS_FORTS=0).');
       if(payload.minute!==true||steps!==1)throw Error('Pas de minute invalide.');
       if(payload.temps_forts!==undefined){if(!matchDirect.NIVEAUX.includes(payload.temps_forts))throw Error('Niveau de temps forts inconnu.');matchHighlights=payload.temps_forts;}
       run('syncMatchPresentation(S.live);tick();if(S.live)syncMatchPresentation(S.live)');
      }else
      for(let i=0;i<steps;i++)run('tick()');
     }else if(command==='pause'){
      if(!run('!!S.live'))throw Error('Aucun match en cours.');if(payload.paused!==undefined&&typeof payload.paused!=='boolean')throw Error('Pause invalide.');
      run(payload.paused===false?'continueMatch()':'pauseMatch()');
     }else if(command==='delegate'){
      if(!run('!!S.live'))throw Error('Aucun match à déléguer.');
      run("nativeSystems.domain('matchTalks').setDelegating(true);nativeSystems.domain('matchTalks').observe('delegate');");
      try{
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
      }finally{run("nativeSystems.domain('matchTalks').setDelegating(false);");}
     }else if(command==='finish_round'){
      run('nativeConfirmMatchResult()');
     }else if(['advance_pacific_preparation','advance_japan_preparation','advance_champ_preparation'].includes(command)){
      if(run('S.worldMode?.day!==undefined'))throw Error('Utilisez l’avance journalière pour cette préparation.');
      if(!Number.isInteger(payload.fromWeek)||payload.fromWeek<0||payload.fromWeek>=46)throw Error('Semaine de préparation invalide.');
      const allowed=command==='advance_champ_preparation'
       ?"CDWorldCareer.edition(S)?.version===5&&CDWorldCareer.leagueId(S)==='champ'"
       :command==='advance_pacific_preparation'
        ?"(CDWorldCareer.edition(S)?.version??0)>=2&&CDWorldCareer.leagueId(S)==='srp'"
        :"(CDWorldCareer.edition(S)?.version??0)>=3&&['jlo-d1','jlo-d2'].includes(CDWorldCareer.leagueId(S))";
      const eligible=run(allowed+"&&S.round===nativePayload.fromWeek&&S.phase!=='ended'&&!S.live&&!nextMatch()&&S.worldMode.fixtures.some(f=>f.week>S.round&&(f.homeId===S.club||f.awayId===S.club))");
      if(!eligible)throw Error('Avance de préparation indisponible cette semaine.');
      // Advance only while the newly reached week has no required invitation.
      for(let i=0;i<4&&run("S.phase!=='ended'&&!S.live&&!nextMatch()");i++){
       const requiresPress=run('finishRound();nativeSystems.domain("press").observeInvitation();nativeSystems.domain("press").requiresConference()');
       if(requiresPress)break;
      }
     }else if(command==='import'){
      if(typeof payload.text!=='string')throw Error('Texte JSON d’import requis.');
      if(Buffer.byteLength(payload.text,'utf8')>CHAMP_IMPORT_LIMIT_BYTES)throw Error('Fichier trop volumineux (24 Mio UTF-8 maximum).');
      run("pendingSave=parseSaveDocument(nativePayload.text);if(pendingSave.state.lnrMode)throw Error('Les effectifs réels ne sont pas chargés dans le moteur natif.');if(!nativeLegacyModes&&CDWorldEditions.forState(pendingSave.state)?.mode!=='world-champ')throw Error(nativeLegacyCareerMessage);");
      national.validate(national.read('pendingSave.state'));
      validateCalendarState(calendarState('pendingSave.state'));
      const imported=JSON.parse(run('JSON.stringify({binding:pendingSave.state.identityPack,database:pendingSave.state.commonDatabase?.id})')),bound=imported.binding&&packs.get(imported.binding.id);if(bound&&bound.meta.databaseId!==imported.database)throw Error('Pack incompatible avec cette édition.');
      protectCurrent(restoring?'restauration':'import',priorSeed,priorClock);
      if(restoring){seed=restoring.seed;clock=restoring.clock;}
      run("if(!confirmSaveImport())throw Error('Import annulé : sauvegarde impossible.');normalizeAcademyPotential(S);");
      if(options.dailyCalendar)run('nativeEnableDailyCalendar()');
     }
     let extra=ctx.nativeKnowledgeReceipt??null;if(SYSTEM_COMMANDS.has(command)){ctx.nativeCommand=command;extra=run('nativeSystems.execute(nativeCommand,nativePayload)');}
     else if(['set_collective_focus','set_opponent_level','set_delegation','set_development_focus','promote_academy','scout_mission','set_lineup','set_tactics','set_penalty_policy','set_player_load','recruit','extend_contract','next_season','substitute','promote_cover'].includes(command)){ctx.nativeCommand=command;extra=run('nativeGestion(nativeCommand,nativePayload)');}
     if(command==='new_career'){
      run('CDNativeAcademyGroups.start(S)');
      ctx.nativeCreationVariation={version:1,seed:priorSeed,varyCurrent:payload.varyCurrent??true};
      run('nativeProfessionalDepth.fill(S);nativeCareerVariation.apply(S,nativeCreationVariation);nativeAttributeStore.complete(S);');
      if(process.env.CD_SALAIRES_PAR_NIVEAU==='1')run("if(budgetFrance()||budgetMonde()){nativeStartingSalaries.apply(S,budgetForces(),nativeLeagueEconomy,budgetLimites(true));[...S.economy.freeAgents,...S.market].forEach(budgetValeur);budgetOuvrir(true);}");
      run('autoLineup();');
      // Directions des clubs gérés : carrières mondiales nouvelles seulement ; CD_DIRECTIONS_CLUBS=0 les coupe.
      if(process.env.CD_DIRECTIONS_CLUBS!=='0')run('nativeClubDirections.create(S,nativeCreationVariation.seed)');
      delete ctx.nativeCreationVariation;
     }
     else if(command==='next_season')run('CDNativeAcademyGroups.afterSeason(S,'+previousAcademyClub+');');
     if(command==='new_career'||command==='import')national.initialize(seed,command==='new_career'?payload:null);
     updatePressPolicy();
     if(advancesCareer||command==='new_career'||command==='import')run('nativeSystems.domain("press").observeInvitation(nativePressPrevious,'+(command==='new_career')+');');
     run(`nativeKnowledge.observe(S,nativeKnowledgeBefore,nativeKnowledgeCommand,nativePayload,{observedPlayerIds:nativeKnowledgeCommand==='academy_center_scout'?(nativeSystems.domain('academyPathways').project().centers||[]).find(c=>c.id===nativePayload.centerId)?.candidates.map(p=>p.id)||[]:[]});`);
     run("nativeSystems.domain('matchTalks').observe(nativeCommand);nativeSystems.domain('sceneInvitations').observe(nativeCommand);nativeSystems.domain('clubMeetings').observe(nativeCommand,nativePayload);");
     mark('commande');
     if(advancesWithinWeek)run('save()');
     else run('budgetAvantProfondeur();nativeProfessionalDepth.fill(S);budgetProfondeur();nativeAttributeStore.complete(S,nativeAttributeBaseline,'+liveOnly+');save();validateCareer(S)');
     mark('validation_sauvegarde');const model=snapshotRaw({command,payload});mark('projection');if(extra)Object.assign(model.meta,JSON.parse(JSON.stringify(extra)));
     // Advancing the presentation cursor can leave both the career and RNG
     // untouched. Keep the previous durable revision and its recovery copy.
     if(command==='tick'&&committedFiles&&seed===priorSeed&&JSON.stringify(store)===priorStore&&profileFilesVersion()===committedFiles)clock=priorClock;
     else persist();
     mark('ecriture_disque');model.meta.profileSafety=profileSafety.project();if(restoring)model.meta.profileSafetyReceipt={command:'restore_checkpoint',id:restoring.id};
     const known=projectKnowledge(model);mark('connaissance');return {id,ok:true,model:known};
    }catch(error){
     seed=priorSeed;clock=priorClock;store=JSON.parse(priorStore);ctx.nativePrior=JSON.parse(prior);run('nativeSystems.clearTransient()');ctx.nativePrior.saveError=ctx.nativePrior.saveError||error.storageFailure===true;
     run('S=nativePrior.state;if(S?.live&&nativePrior.playback)MATCH_PLAYBACK.set(S.live,nativePrior.playback);pendingSave=null;lastSaveError=nativePrior.saveError;');
     throw error;
    }finally{deferredDelegateActive=false;deferredDelegateRead=false;delete ctx.nativePayload;delete ctx.nativePrior;delete ctx.nativeMode;delete ctx.nativeCommand;delete ctx.nativeBinding;delete ctx.nativeAttributeBaseline;delete ctx.nativePressPrevious;delete ctx.nativeKnowledgeBefore;delete ctx.nativeKnowledgeCommand;delete ctx.nativeKnowledgeReceipt;}
   }catch(error){return {id,ok:false,model:closed?null:snapshot(),error:error.message};}
  }
  return {handle,close};
 }catch(e){close();throw e;}
}
module.exports={createBridge,applicationRoot,IMPORT_LIMIT_BYTES,REQUEST_LIMIT_BYTES,WORLD_IMPORT_LIMIT_BYTES,WORLD_REQUEST_LIMIT_BYTES,EXTENDED_IMPORT_LIMIT_BYTES,EXTENDED_REQUEST_LIMIT_BYTES,CHAMP_IMPORT_LIMIT_BYTES,CHAMP_REQUEST_LIMIT_BYTES,CORE_FILES:Object.freeze([...MODULES])};
if(require.main===module){
 let bridge;
 try{const rawSeed=process.env.CD_GODOT_SEED;let seed;if(rawSeed!==undefined){seed=Number(rawSeed);if(!/^(0|[1-9]\d*)$/.test(rawSeed)||!Number.isInteger(seed)||seed<0||seed>0xffffffff)throw Error('CD_GODOT_SEED doit être un entier entre 0 et 4294967295.');}const index=process.argv.indexOf('--data-dir');/* Match en temps forts : mode de base du jeu. Repli sur le direct d'origine : CD_MATCH_TEMPS_FORTS=0. */const niveauTempsForts=process.env.CD_MATCH_TEMPS_FORTS==='0'?null:(process.env.CD_MATCH_TEMPS_FORTS_NIVEAU||'dynamique');bridge=createBridge({dailyCalendar:true,mandatoryPress:true,internationalCareer:true,...(niveauTempsForts?{matchHighlights:niveauTempsForts}:{}),...(seed===undefined?{}:{seed}),dataDir:index>=0?process.argv[index+1]:path.join(process.env.LOCALAPPDATA||require('node:os').homedir(),'CadrageDebordement','PrototypeGodot')});}
 catch(e){process.stdout.write(JSON.stringify({id:null,ok:false,model:null,error:e.message})+'\n');process.exitCode=1;return;}
 const input=readline.createInterface({input:process.stdin,crlfDelay:Infinity}),delta=require('./model-delta.cjs').createEncoder();
 input.on('line',line=>{
  // L'interface Godot annonce la révision du modèle qu'elle détient : réponse différentielle.
  let result,base=null;try{const bytes=Buffer.byteLength(line);if(bytes>CHAMP_REQUEST_LIMIT_BYTES)throw Error('Message trop volumineux.');const request=JSON.parse(line);if(bytes>REQUEST_LIMIT_BYTES){if(request.command!=='import'||typeof request.payload?.text!=='string'||Buffer.byteLength(request.payload.text,'utf8')>CHAMP_IMPORT_LIMIT_BYTES)throw Error('Message trop volumineux.');const state=JSON.parse(request.payload.text)?.state,edition=worldEditions.forState(state);if(!edition||bytes>edition.limits.requestBytes||Buffer.byteLength(request.payload.text,'utf8')>edition.limits.saveBytes)throw Error('Message trop volumineux.');}if(Number.isSafeInteger(request?.base))base=request.base;result=bridge.handle(request);}catch(e){result={id:null,ok:false,model:null,error:e.message};}
  process.stdout.write((base===null?JSON.stringify(result):delta.encode(result,base))+'\n');if(result.ok&&line&&JSON.parse(line).command==='shutdown'){input.close();process.stdin.destroy();}
 });
 input.on('close',()=>bridge.close());process.on('exit',()=>bridge.close());
}

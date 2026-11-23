'use strict';
// Prototype bridge: local private stdio only. Never load browser UI, the source
// identity catalogue, the test harness, a network server, or protocol-supplied code.
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),readline=require('node:readline'),{randomUUID,createHash}=require('node:crypto');
const projection=require('./model.cjs'),gestion=require('./gestion.cjs'),common=require('./common-rosters.cjs'),mediaPacks=require('./media-packs.cjs'),pressIdentities=require('./press-identities.cjs'),staff=require('./staff.cjs'),decisions=require('./decisions.cjs'),systems=require('./native-systems.cjs');
const playerAttributes=require('./player-attributes.cjs');
const managerPlanning=require('./manager-planning.cjs');
// Réactivité (lot 19) : sections lourdes reprises d'une réponse à l'autre, versions des sections de la carrière.
const projectionSections=require('./projection-sections.cjs'),stateVersions=require('./state-versions.cjs'),modelDelta=require('./model-delta.cjs');
const playerKnowledge=require('./player-knowledge.cjs'),knowledgeProjection=playerKnowledge.factory();
const positionAptitudes=require('./position-aptitudes.cjs');
const careerVariation=require('./career-variation.cjs');
const potentialEvolution=require('./potential-evolution.cjs'),potentialEvolutionValidation=potentialEvolution();
const inSeasonDevelopment=require('./in-season-development.cjs');
const clubTransfers=require('./club-transfers.cjs'),clubDirections=require('./club-directions.cjs'),boardNames=require('./staff-completion.cjs');
const profileSafetyFactory=require('./profile-safety.cjs');
const makePlayerFacts=require('./player-facts.cjs');
const makePortraitLooks=require('./portrait-looks.cjs').createLooks;
const makeNational=require('./international-native.cjs');
const continuer=require('./continuer.cjs');
const actionJournal=require('./action-journal.cjs');
const {factory:internationalCallups}=require('./international-callups.cjs');
const factsFile=path.join(__dirname,'player-real-facts.json');
const playerFactsCatalogue=fs.existsSync(factsFile)?JSON.parse(fs.readFileSync(factsFile,'utf8')):{};
const professionalDepth=require('./professional-depth.cjs');
const epcrPreparation=require('./epcr-preparation.cjs'),clubPreview=require('./club-preview.cjs');
const competitionEditor=require('./competition-editor.cjs');
const leagueDetail=require('./league-detail.cjs');
const defisDepart=require('./defis-depart.cjs');
const {calendarContext}=require('./calendar-clock.cjs');
const franceCalendar=require('./france-calendar-cadence.cjs');
const confirmMatchResult=require('./match-result.cjs');
const matchDirect=require('./match-direct.cjs');
const matchBonus=require('./match-bonus.cjs');
const calendarPlanning=require('./calendar-planning.cjs'),calendarMail=require('./calendar-mail.cjs');
const jsonCopy=require('./json-copy.cjs'),worldVm=require('./world-vm.cjs'),worldModel=require('./world-model.cjs'),publishedVenue=require('./world-venues.cjs'),worldRegistry=require('./world-registry.json');
const clubHistory=require('./club-history.json');
const clubPalmares=require('./club-palmares.cjs'),gabiRepliques=require('./gabi-repliques.cjs');
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
// Éligibilité anglaise (EQP) des joueurs non documentés, club par club : native/engine/eqp_eligibilite.json.
const eqpEligibilite=JSON.parse(fs.readFileSync(path.join(__dirname,'eqp_eligibilite.json'),'utf8'));
const factHomes=Object.fromEntries(referenceClubs.flatMap(club=>club.players.map(player=>[player.id,club.id])));
const nationalFacts=makePlayerFacts(playerFactsCatalogue,factOrigins,factClubs,{regles:eqpEligibilite,homes:factHomes});
const portraitLooks=makePortraitLooks(nationalFacts);
const MODULES=['season-label.js','storage.js','world-data.js','rugby.js','frontrow.js','restarts.js','matchflow.js','playbook.js','manager.js','manager-squad.js','tactical-plans.js','arbitrage.js','match-actions.js','match-pilotage.js','match2d.js','match-v61-advisor.js','match-cockpit.js','economy.js','development.js','finance-planning.js','board-planning.js','academy-planning.js','transfer-planning.js','career-history.js','career-integration.js','club-ai.js','reputation.js','coach-market.js','coach-opportunities.js','facilities.js','rugby-world.js','financial-recovery.js','world-career.js','ai-roster-cycle.js','v39.js','manager-mobility.js','saves.js','opposition.js','match-preparation.js','france-clubs.js','rugby-common-rosters.js','rugby-roster-foundation.js','lnr-v11-aging.js','france-competition.js','france-knockout.js','france-career.js','france-save-validation.js','match3d/scene-adapter.js','game.js'];
MODULES.splice(MODULES.indexOf('game.js'),0,...systems.files.filter(name=>!MODULES.includes(name)));
const SYSTEM_COMMANDS=new Set(systems.commands);
const repriseStarts=require('./reprise.cjs').STARTS;
const PRESEASON_OPENERS=new Set(['finish_round','begin_match','train','next_season','advance_pacific_preparation','advance_japan_preparation','advance_champ_preparation']);
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
const COMMANDS=new Set([...SYSTEM_COMMANDS,'population_enable','academy_groups_preview','academy_groups_enable','competition_editor_preview','epcr_preview','club_sheet','set_collective_focus','set_opponent_level','set_delegation','set_development_focus','promote_academy','scout_mission','snapshot','new_career','train','auto_lineup','begin_match','tick','pause','delegate','advance_day','finish_round','advance_pacific_preparation','advance_japan_preparation','advance_champ_preparation','save','import','export','shutdown','set_lineup','set_tactics','set_penalty_policy','set_consignes','appliquer_staff','set_role_direct','cri','set_player_load','set_intensite_auto','appliquer_avis_kine','recruit','extend_contract','next_season','substitute','promote_cover','sale_list','sale_answer','precontract_offer','recover_profile','pack_inspect','pack_install','pack_select','advance_until_event']);
COMMANDS.add('observe_player');
// Rallonge demandée au conseil (budget-transferts.cjs) : contrôleur dans gestion.cjs.
COMMANDS.add('transfer_budget_extension');
COMMANDS.add('league_benchmark');
COMMANDS.add('club_preview');
COMMANDS.add('start_challenges');
COMMANDS.add('restore_checkpoint');
COMMANDS.add('remove_checkpoint');
COMMANDS.add('calendar_template');
COMMANDS.add('calendar_mail_decide');
const NATIONAL_COMMANDS=['national_take_job','national_leave_job','national_play_match'];
NATIONAL_COMMANDS.forEach(command=>COMMANDS.add(command));
const NATIONAL_ONLY_COMMANDS=new Set(['new_career','import','save','advance_day','next_season',...NATIONAL_COMMANDS]);
const FULL_VALIDATION=new Set(['new_career','import','finish_round','next_season']);
const BLOCKED_AFTER_RESULT=new Set(['begin_match','tick','pause','delegate','train','auto_lineup','substitute','next_season','match_incident_choice']);
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
 if(options.deferredCommits!==undefined&&typeof options.deferredCommits!=='boolean')throw Error('Drapeau d’écriture différée invalide.');
 if(options.journal!==undefined&&typeof options.journal!=='boolean')throw Error('Drapeau du journal d’actions invalide.');
 if(options.savePolicy!==undefined&&!actionJournal.POLICIES.includes(options.savePolicy))throw Error('Fréquence de sauvegarde inconnue.');
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
 let flushBeforeClose=()=>{};
 const close=()=>{
  if(closed)return;
  // Écriture différée (voir plus bas) : la dernière décision en attente est écrite avant de rendre le verrou.
  try{flushBeforeClose();}catch{}
  closed=true;
  try{exclusive(()=>{
   const current=fs.lstatSync(lock);
   if(current.isSymbolicLink()||current.dev!==identity.dev||current.ino!==identity.ino||fs.readFileSync(lock,'utf8')!==ownership)throw Error('Le verrou de profil n’appartient plus à ce processus.');
   fs.unlinkSync(lock);
  });}finally{fs.closeSync(lockFd);}
 };
 let ctx,profileError='',recoveryBackup=null,loadedProfile=null;
 // Journal d'actions (native/engine/action-journal.cjs) : option journal (activée par le jeu) ; CD_JOURNAL=0 le coupe.
 // Les décisions ne réécrivent plus le profil : une ligne par commande, sauvegarde complète selon la fréquence choisie.
 const journalMode=options.journal===true&&process.env.CD_JOURNAL!=='0';
 const journal=journalMode?actionJournal.createJournal(dataDir):null;
 const savePolicyOverride=options.savePolicy??(actionJournal.POLICIES.includes(process.env.CD_SAUVEGARDE_AUTO)?process.env.CD_SAUVEGARDE_AUTO:undefined);
 let loadedSha=null,journalNotice=null,unvalidated=false,lastSavedKey=null,savedNow=false;
 const profileSafety=profileSafetyFactory.createStore(dataDir);
 let deferredDelegateActive=false,deferredDelegateRead=false;
 // Décision différée : les save() internes du moteur pendant la commande ne sérialisent pas la carrière (la
 // sauvegarde finale le fait) ; une lecture de la carrière enregistrée pendant ce temps la sérialise d'abord.
 let savesDeferred=false,realSave=null,deferringSave=null;
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
   try{loadedProfile=profileSafety.readProfile(file);if(journalMode)loadedSha=actionJournal.sha256(loadedProfile);const saved=JSON.parse(loadedProfile.toString('utf8'));
   if(saved.protocol!==1||!Number.isInteger(saved.seed)||!Number.isFinite(saved.clock)||!saved.store||typeof saved.store!=='object'||Array.isArray(saved.store))throw Error('Profil PrototypeGodot illisible ou incompatible.');
   store=saved.store;seed=saved.seed>>>0;clock=saved.clock;}catch(e){profileError='Profil illisible : '+e.message;store={};}
  }
  if(!legacyModes&&!profileError)purgeLegacyCareers();
  const math=Object.create(Math);math.random=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296;};
  class EngineDate extends Date{constructor(...args){super(...(args.length?args:[clock]));}static now(){return clock;}}
  const storage={offline:true,directory:dataDir,getItem:key=>{if(deferredDelegateActive){deferredDelegateRead=true;throw deferredReadError;}if(savesDeferred&&key==='bdt-v1'&&realSave)realSave();return store[key]??null;},setItem:(key,value)=>{store[key]=String(value);},removeItem:key=>{delete store[key];}};
  const element={innerHTML:'',textContent:'',style:{}};
  // Formats numériques réutilisés (même résultat) : le jeu crée un Intl.NumberFormat à chaque montant affiché (money,
  // ~120 demandes salariales par réponse) ; sa création coûte ~50 µs. Prototype et méthodes statiques gardés.
  const numberFormats=new Map();
  const NumberFormat=function NumberFormat(locales,options){const key=JSON.stringify([locales??null,options??null]);let format=numberFormats.get(key);if(!format){format=new Intl.NumberFormat(locales,options);if(numberFormats.size<64)numberFormats.set(key,format);}return format;};
  NumberFormat.prototype=Intl.NumberFormat.prototype;NumberFormat.supportedLocalesOf=Intl.NumberFormat.supportedLocalesOf.bind(Intl.NumberFormat);
  const engineIntl=Object.create(Intl,{NumberFormat:{value:NumberFormat,writable:true,configurable:true}});
  ctx=vm.createContext({console:{log(){},warn(){},error(){}},Intl:engineIntl,Math:math,Date:EngineDate,Set,JSON,CDNativeHeadless:true,document:{querySelector:()=>element},window:{CDNativeHeadless:true,CDOfflineStorage:storage,CDOfflineError:true},localStorage:storage,setTimeout:()=>0,clearTimeout(){},setInterval:()=>0,clearInterval(){},nativeDataDirectory:dataDir});
  const run=(source,filename)=>vm.runInContext(source,ctx,filename?{timeout:15000,filename}:{timeout:15000});
  // Visage affiché d'un joueur (même calcul que la projection des portraits) : repris tel quel par la reconversion en staff.
  ctx.nativePortraitLook=process.env.CD_PORTRAIT_CARRURE==='0'?undefined:(player,world)=>{
    if(portraitLooks.hasRealPhoto(player))return null;
    const upgrade=world===true&&player.appearanceBankVersion===undefined,r=portraitLooks.resolve(player,upgrade);
    return {appearanceId:r.appearanceId,appearanceBuild:r.appearanceBuild,bank:upgrade||player.appearanceBankVersion===2?2:1};
  };
  // Lecture ou bascule immédiate de l'état (aucune boucle, aucun calcul) : sans minuterie de garde. Sa mise en place (un
  // fil par appel) coûtait ~0,1 à 1 ms à chaque appel, soit plusieurs ms par réponse.
  const peek=source=>vm.runInContext(source,ctx);
  // Lecture sans tirage du flux unique : graine des flux séparés des championnats suivis de loin.
  ctx.nativeRandomPeek=()=>seed;
  ctx.nativeMandatoryPress=options.mandatoryPress===true;
  // Essais seulement : plafond d'export abaissé pour exercer la réduction sans perte des grands exports.
  if(Number.isInteger(options.saveBytes)&&options.saveBytes>0)ctx.nativeSaveBytes=options.saveBytes;
  ctx.nativeLegacyModes=legacyModes;ctx.nativeLegacyCareerMessage=LEGACY_CAREER_MESSAGE;
  const calendarState=(source='S')=>JSON.parse(run(`JSON.stringify({planning:${source}?.calendarPlanning,mail:${source}?.calendarMail})`));
  function validateCalendarState(state){
   if(calendarPlanning.validateState(state.planning)===false||calendarMail.validate(state.mail)===false)throw Error('Planification du calendrier invalide.');
  }
  ctx.nativeKnowledgeValidate=knowledgeProjection.validate;
  ctx.nativeVerifySections=options.verifyCleanCopy===true||process.env.CD_VERIFIER_COPIE==='1';
  // Mémoire des projections par domaine (native-systems.cjs, projectText) : CD_MEMO_DOMAINES=0 (ou memoDomains:false)
  // la coupe ; CD_VERIFIER_MEMO=1 (ou verifyMemo:true, tests) recalcule chaque domaine repris et exige le même texte.
  const memoDomains=options.memoDomains!==false&&process.env.CD_MEMO_DOMAINES!=='0';
  ctx.nativeMemoDomains=memoDomains;ctx.nativeVerifyMemo=options.verifyMemo===true||process.env.CD_VERIFIER_MEMO==='1';
  ctx.nativePotentialEvolutionValidate=potentialEvolutionValidation.validate;
  const dist=options.distDir?path.resolve(options.distDir):fs.existsSync(path.join(__dirname,'core'))?path.join(__dirname,'core'):path.resolve(__dirname,'../../dist');
  // Libellé de saison : la même fonction (dist/season-label.js) sert au processus Node (projection du modèle) et à la VM.
  if(typeof globalThis.libelleSaison!=='function')globalThis.libelleSaison=require(path.join(dist,'season-label.js')).libelleSaison;
  for(const name of MODULES)run(fs.readFileSync(path.join(dist,name),'utf8'),'core/'+name);
  // Découpage des longues courses du moteur (présentation du journal, docs/match-courses-20261112.md) :
  // CD_MATCH_COURSES=0 (ou l'option matchCourses:false) rend l'ancien journal, un seul fait jusqu'à la ligne.
  if(options.matchCourses===false||process.env.CD_MATCH_COURSES==='0')ctx.MATCH_COURSES_DECOUPEES=false;
  // Notes de match : CD_NOTES_EFFETS=0 (ou l'option notesEffets:false) garde les notes sans leurs effets (mesure d'équilibre).
  if(options.notesEffets===false||process.env.CD_NOTES_EFFETS==='0')ctx.CDNotesEffets=false;
  // Pas de domaine des notes du tout (option notes:false) : référence des tests « aucun résultat changé ».
  if(options.notes===false)ctx.CDNotesAbsentes=true;
  // Carrières aux salaires liés au niveau : plancher des discussions de contrat, avant tout habillage de la validation.
  run(require('./club-budget.cjs').VALIDATION);
  // Prolongations confiées au directeur sportif (prolongations-staff.cjs) : réglages et décisions vérifiés à la sauvegarde.
  ctx.nativeProlongations=require('./prolongations-staff.cjs');
  run('{const dsValidationV1=validateCareer;validateCareer=function(s){const r=dsValidationV1(s);if(s&&typeof s==="object"&&s.manager)nativeProlongations.valider(s.manager,s.season);return r;};}');
  // Staff du club joué renouvelé par le directeur sportif (staff-renouvellement.cjs) : bureau vérifié à la sauvegarde.
  ctx.nativeStaffRenouvellement=require('./staff-renouvellement.cjs');
  run('{const dsStaffValidationV1=validateCareer;validateCareer=function(s){const r=dsStaffValidationV1(s);if(s&&typeof s==="object"&&s.manager)nativeStaffRenouvellement.valider(s.manager,s.season);return r;};}');
  ctx.nativeWorldRegistryText=JSON.stringify(worldRegistry);
  if(pacificRegistry)ctx.nativeWorldPacificRegistryText=JSON.stringify(pacificRegistry);
  if(japanRegistry)ctx.nativeWorldJapanRegistryText=JSON.stringify(japanRegistry);
  if(nationaleRegistry)ctx.nativeWorldNationaleRegistryText=JSON.stringify(nationaleRegistry);
  if(champRegistry)ctx.nativeWorldChampRegistryText=JSON.stringify(champRegistry);
  run(`const nativeJsonCopy=(${jsonCopy.toString()})();render=()=>{};toast=()=>{};startTimer=()=>{};save=()=>{if(S&&!validatingStartup){gameStorage.setItem('bdt-v1',nativeSaveText(S));lastSaveError=false;}};
   /* Sauvegarde incrémentale : le texte de la carrière est assemblé section par section (premier niveau de S),
      identique à JSON.stringify(S) ; ces textes servent ensuite à la validation (sections inchangées) et à
      l'écriture du profil (encodage des seules sections modifiées). */
   var nativeSaveSections=null,nativeSafeTreeArmed=null,nativeSafeTreeCache=new Map();
   /* Sections à jour pour la projection : vrai seulement quand le moteur sait que S n'a pas changé depuis le dernier
      nativeSaveText (projection en cours, sauvegarde suivie de la validation d'une décision). Toute commande qui peut
      modifier la carrière le remet à faux avant de s'exécuter ; une carrière remplacée (S d'une autre identité) n'est
      jamais reprise. */
   var nativeSectionsFresh=false;
   function nativeCurrentSections(){
    if(!S)return null;
    if(nativeSectionsFresh&&nativeSaveSections?.state===S){
     if(nativeVerifySections&&JSON.stringify(S)!==nativeSaveSections.whole)throw Error('Sections de projection périmées.');
     return nativeSaveSections.texts;
    }
    nativeSaveText(S);nativeSectionsFresh=true;return nativeSaveSections.texts;
   }
   /* Écriture différée d'une décision : le texte assemblé pour la projection décrit encore exactement la carrière. */
   function nativeSaveCurrent(){
    if(S&&!validatingStartup&&nativeSectionsFresh&&nativeSaveSections?.state===S){
     if(nativeVerifySections&&JSON.stringify(S)!==nativeSaveSections.whole)throw Error('Sections de sauvegarde périmées.');
     gameStorage.setItem('bdt-v1',nativeSaveSections.whole);lastSaveError=false;return;
    }
    save();
   }
   function nativeSaveText(state){
    const texts=new Map(),parts=[];
    let clubs=null;
    for(const key of Object.keys(state)){
     let text;
     /* Clubs : texte assemblé club par club (identique à JSON.stringify d'un tableau sans toJSON), gardé pour la
        projection (state-versions.cjs, clubs~others) qui n'a alors plus à resérialiser les autres clubs. */
     const v=state[key];
     if(key==='clubs'&&Array.isArray(v)&&Object.getPrototypeOf(v)===Array.prototype&&typeof v.toJSON!=='function'){clubs=new Array(v.length);for(let i=0;i<v.length;i++)clubs[i]=JSON.stringify(v[i])??'null';text='['+clubs.join(',')+']';}
     else text=JSON.stringify(v);
     if(text===undefined)continue;texts.set(key,text);parts.push(JSON.stringify(key)+':'+text);}
    const whole='{'+parts.join(',')+'}';
    if(nativeVerifySections&&whole!==JSON.stringify(state))throw Error('Sauvegarde par sections différente du texte complet.');
    nativeSaveSections={state,texts,keys:[...texts.keys()],whole,clubs};return whole;
   }
   function nativeSafeTreeSections(root){
    if(!root||root!==nativeSafeTreeArmed||nativeSaveSections?.state!==root)return null;
    if(nativeVerifySections&&JSON.stringify(root)!==nativeSaveSections.whole)throw Error('Sections de sauvegarde périmées avant la validation.');
    return {texts:nativeSaveSections.texts,cache:nativeSafeTreeCache};
   }
   function nativeValidateSaved(full){nativeSafeTreeArmed=full?null:S;try{return validateCareer(S);}finally{nativeSafeTreeArmed=null;}}validatingStartup=false;const nativeCareerVariation=(${careerVariation.toString()})();const nativeDepthOptions=${JSON.stringify({managedFloor:process.env.CD_PLANCHER_CLUBS_GERES!=='0'})};const nativeProfessionalDepth=(${professionalDepth.toString()})();${worldVm.bootstrap()}const nativePositionAptitudes=(${positionAptitudes.toString()})();nativePositionAptitudes.installHooks();const CDCommonCareer=(${common.toString()})(CDWorldSeniorCalibration);const nativeAttributeStore=(${playerAttributes.toString()})();const nativeFacts=(${makePlayerFacts.toString()})(${JSON.stringify(playerFactsCatalogue)},${JSON.stringify(factOrigins)},${JSON.stringify(factClubs)},${JSON.stringify({regles:eqpEligibilite,homes:factHomes})});
   const nativeCallups=(${internationalCallups.toString()})();
   const nativeInternationalStatus=new WeakMap();
   const nativePlayerAttributes=p=>{
    const career=S?.national?.career;
    if(career&&!nativeInternationalStatus.has(career))nativeInternationalStatus.set(career,nativeCallups.internationalStatus(career));
    const status=career&&nativeInternationalStatus.get(career);
    return {...nativeAttributeStore.project(p),...nativePositionAptitudes.project(p),playerFacts:{...nativeFacts.project(p.id,status?.caps.get(p.id),p),onInternationalDuty:status?.released.has(p.id)??false,listeElite:nativeSystems.domain('doublons').isListed(S,p.id)}};
   };
   const nativeBaseModel=${projection.toString()};const nativeModel=(${worldModel.toString()})(nativeBaseModel,(${publishedVenue.factory.toString()})(${JSON.stringify(publishedVenue.data)}),${JSON.stringify(clubHistory)});const nativeDecisions=${decisions.toString()};const nativeGestion=${gestion.toString()};`,'native-bootstrap');
  ctx.nativeStaffCareerSourcesText=JSON.stringify(Object.fromEntries([run('CDCommonRosters.id'),...worldEditions.entries.map(e=>e.id)].map(id=>[id,staff.forDatabase(id).registry.clubs])));
  run(systems.bootstrap(),'native-systems');delete ctx.nativeStaffCareerSourcesText;
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
  // Rapport de l'analyste vidéo après le match (match-direct.cjs analyseVideo) : calculé hors de la VM sur le journal du
  // match terminé (lecture seule, aucun tirage), gardé dans `S.lastReport.analyse` à la clôture de la journée
  // (captureReport) ; avant la clôture, lu sur le direct terminé (decisions.cjs). Contrôlé à chaque validation.
  ctx.nativeAnalyseVideoHote=texte=>JSON.stringify(matchDirect.analyseVideo(JSON.parse(texte)));
  run(`const nativeAnalyseVideo=(()=>{
    let cle=null,valeur=null;
    const calculer=l=>{
     if(!l||!l.finished||!Array.isArray(l.events)||!l.events.length)return null;
     const k=String(l.pair)+'|'+String(l.score)+'|'+l.events.length;
     if(k!==cle){try{valeur=JSON.parse(nativeAnalyseVideoHote(JSON.stringify(l.events)));}catch(e){valeur=null;}cle=k;}
     return valeur?JSON.parse(JSON.stringify(valeur)):null;
    };
    const entier=(n,a,b)=>Number.isInteger(n)&&n>=a&&n<=b;
    const paire=(x,max)=>Array.isArray(x)&&x.length===2&&x.every(n=>entier(n,0,max));
    const valider=a=>{
     const ok=a&&typeof a==='object'&&!Array.isArray(a)&&a.version===${matchDirect.ANALYSE_VERSION}
      &&Array.isArray(a.domination)&&a.domination.length<=120&&a.domination.every(n=>entier(n,-100,100))
      &&(a.miTemps===null||entier(a.miTemps,0,120))&&a.zone22&&paire(a.zone22.entrees,200)&&paire(a.zone22.points,400)&&paire(a.zone22.secondes,7200)
      &&Array.isArray(a.occasions)&&a.occasions.length<=200&&a.occasions.every(o=>Array.isArray(o)&&o.length===2&&entier(o[0],0,120)&&(o[1]===0||o[1]===1));
     if(!ok)throw Error('Rapport de l’analyste vidéo invalide.');
    };
    return {calculer,valider};
   })();
   const nativeCaptureReportSansAnalyse=captureReport;
   captureReport=function(){const l=S.live;nativeCaptureReportSansAnalyse();if(l&&S.lastReport&&String(S.lastReport.pair)===String(l.pair)){const a=nativeAnalyseVideo.calculer(l);if(a)S.lastReport.analyse=a;}};
   const nativeValidateAnalyse=validateCareer;
   validateCareer=state=>{const result=nativeValidateAnalyse(state);if(state?.lastReport&&state.lastReport.analyse!==undefined)nativeAnalyseVideo.valider(state.lastReport.analyse);return result;};`);
  // Dilemme du bonus en fin de match (match-bonus.cjs) : barème lu dans les classements, décision des clubs IA.
  run(`const nativeMatchBonus=(${matchBonus.factory.toString()})();nativeMatchBonus.installHooks();`);
  let matchHighlights=options.matchHighlights??null;
  // Chorégraphe des temps forts (présentation seule, éteint par défaut) : CD_MATCH_CHOREGRAPHE=1.
  const matchChoreography=options.matchChoreography??process.env.CD_MATCH_CHOREGRAPHE==='1';
  const matchDirectReader={profils:ids=>JSON.parse(run('JSON.stringify(nativeMatchDirect.profils('+JSON.stringify(ids)+'))')),scenes:indices=>JSON.parse(run('JSON.stringify(nativeMatchDirect.scenes('+JSON.stringify(indices)+'))')),transformation:(index,made)=>JSON.parse(run('JSON.stringify(nativeMatchDirect.transformation('+Number(index)+','+(made===true)+'))')),etat:()=>JSON.parse(run('JSON.stringify(nativeMatchDirect.etat())')),
   // Multiplex de la journée et classement en direct à la minute montrée (match-multiplex.cjs).
   journee:(minute,fini,score,essais)=>JSON.parse(run('JSON.stringify(nativeSystems.domain("multiplex").journee('+JSON.stringify([minute,fini,score,essais]).slice(1,-1)+'))')),
   // Attributs des joueurs de la rencontre (feuille de statistiques, match-stats.cjs).
   attributs:()=>JSON.parse(run('JSON.stringify((()=>{const l=S.live,o={};if(!l)return o;l.sheets.forEach((sh,s)=>{for(const id of new Set([...sh.on,...(sh.bench||[]),...(sh.used||[])])){if(id==null)continue;const p=matchPlayer(l,s,id);if(p&&p.skills)o[id]={skills:p.skills}}});return o})())'))};
  try{run("if(loadSaveFailure)throw Error(loadSaveFailure);if(S){validateCareer(S);if(S.lnrMode)throw Error('Les effectifs réels ne sont pas chargés dans le moteur natif.');if(!nativeLegacyModes&&CDWorldEditions.forState(S)?.mode!=='world-champ')throw Error(nativeLegacyCareerMessage);if(normalizeAcademyPotential(S))validateCareer(S);nativeProfessionalDepth.fill(S);nativeAttributeStore.complete(S);if(S.live&&!S.live.finished)S.live.paused=true;if(S.national?.role?.club!==false)nativeSystems.domain('press').observeInvitation();}");validateCalendarState(calendarState());}catch(e){profileError='Profil illisible : '+e.message;run('S=null;');}
  const national=makeNational(run,ctx,nationalFacts,options.internationalCareer===true,peek);
  const updatePressPolicy=()=>{ctx.nativeMandatoryPress=options.mandatoryPress===true&&!national.isNationalOnly();};
  try{if(options.dailyCalendar)run('nativeEnableDailyCalendar()');national.initialize(seed);updatePressPolicy();}
  catch(e){profileError='Profil illisible : '+e.message;run('S=null;');}
  let resumeCheckpoint=null;
  if(loadedProfile&&!profileError&&peek('!!S')){
   const original=JSON.parse(loadedProfile.toString('utf8')).store['bdt-v1'];
   if(original!==run('JSON.stringify(S)'))resumeCheckpoint={profile:loadedProfile,replaySeed:seed,replayClock:clock,text:run('JSON.stringify(createSaveDocument())'),...JSON.parse(run('JSON.stringify({club:S.clubs[S.club].name,season:S.season,round:S.round??0})'))};
  }
  // Copie de reprise de la carrière ouverte avant son remplacement. Le texte du document est rendu : l'import le
  // reprend tel quel pour sa copie « bdt-before-import » (même carrière, même document) au lieu de le recréer.
  const protectCurrent=(reason,replaySeed=seed,replayClock=clock)=>{
   if(!peek('!!S')||!fs.existsSync(file))return null;
   const text=saveDocumentText();
   // Pendant un match, la copie décrit la carrière d'avant le coup d'envoi (celle du profil sur le disque).
   if(preMatch){replaySeed=preMatch.seed;replayClock=preMatch.clock;}
   profileSafety.checkpoint({profile:profileSafety.readProfile(file),replaySeed,replayClock,text,reason,...JSON.parse(run('JSON.stringify({club:S.clubs[S.club].name,season:S.season,round:S.round??0})'))});
   return text;
  };
  const legacyDatabase=JSON.parse(run('JSON.stringify(CDCommonRosters)')),packs=mediaPacks.createStore(dataDir,legacyDatabase,worldRegistry,pacificRegistry,japanRegistry,nationaleRegistry,champRegistry,pressIdentities.catalogue(JSON.parse(run('JSON.stringify(CDPressQuestionBank.journalists)'))));
  const creationKey=mode=>mode==='world-champ'?'identity-pack-champ-creation':mode==='world-nationale'?'identity-pack-nationale-creation':mode==='world-japan'?'identity-pack-japan-creation':mode==='world-pacific'?'identity-pack-pacific-creation':mode==='world'?'identity-pack-world-creation':'identity-pack-creation';
  const creation=(mode='common')=>store[creationKey(mode)]||'base';
  const edition=mode=>{if(mode==='common')return legacyDatabase.id;const e=worldEditions.forMode(mode);if(!e)throw Error('Édition de pack invalide.');return e.id;};
  const currentEdition=()=>run("CDWorldCareer.edition(S)?.mode||'common'");
  function projectCalendar(model, operation){
   ctx.nativeProgrammeEffets=null;
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
   // Effets des séances de la semaine en cours (calendar-planning.cjs weekEffects) : lus par trainWeek dans la VM
   // (programme-semaine.cjs) pour le club du manager, seulement pour cette saison et cette semaine.
   const semaine=model.calendarPlanning.week;
   ctx.nativeProgrammeEffets=semaine&&!simulatedDates?JSON.parse(JSON.stringify({...semaine,season:model.meta?.season,round:model.meta?.week})):null;
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
  // VM projections contain state only; parse a fresh detached copy per reader.
  const projectionCache=new Map();let allowProjectionCache=false;
  const readProjection=(expression,text=false)=>{
   const source=text?expression:'JSON.stringify('+expression+')';
   if(!allowProjectionCache||options.cacheProjections===false)return JSON.parse(run(source));
   if(!projectionCache.has(source))projectionCache.set(source,run(source));
   return JSON.parse(projectionCache.get(source));
  };
  // Mémoire de la connaissance par domaine (voir projectKnowledge) ; en vérification (CD_VERIFIER_MEMO=1), tout est
  // reparcouru et comparé au texte mémorisé.
  const KNOWLEDGE_MEMO=['interclubMarket','staffCareer','coachNotebook','regenScouting','managerCareer','youthDevelopment'];
  const knowledgeMemo=new Map(),knowledgeMemoOn=memoDomains,knowledgeVerify=options.verifyMemo===true||process.env.CD_VERIFIER_MEMO==='1';
  const projectKnowledge=model=>{
   if(projectionState?.result===model&&projectionState.sections)return projectKnowledgeSections(model);
   // Cibles du carnet personnel (tous les joueurs du monde : identifiant, nom, poste, disponibilité) : elles ne
   // portent aucune note ni aucun potentiel et l'écran du carnet n'en lit que le nom. Les tenir hors des parcours
   // de portraits et de connaissance évite de leur greffer fiches de recrutement et fourchettes (~6 Mio de modèle
   // en carrière Monde, recalculés, comparés et recopiés par l'interface à chaque réponse). CD_CARNET_CIBLES=complet
   // rétablit l'ancien modèle.
   // Gros domaines de la vie du club (marché entre clubs, staff, carnet…) : leur version vue par le joueur (portraits,
   // fourchettes de connaissance) ne dépend que de leur texte projeté, de la frontière de connaissance et du mode.
   // Quand ces trois textes sont ceux de la réponse précédente, elle est reprise telle quelle au lieu d'être
   // reparcourue ; ces domaines sont mis de côté pendant le parcours du reste du modèle puis remis à leur place (même
   // ordre des clés). En vérification (CD_VERIFIER_MEMO=1), tout est reparcouru et comparé au texte mémorisé.
   const life=knowledgeMemoOn&&model?.clubLife&&typeof model.clubLife==='object'?model.clubLife:null;
   const visibilityText=run('JSON.stringify(nativeKnowledge.visibility(S))'),mode=String(model?.meta?.mode??'');
   const aside=new Map(),before=new Map();
   if(life)for(const key of KNOWLEDGE_MEMO){
    if(!Object.hasOwn(life,key))continue;
    const text=JSON.stringify(life[key]);if(text===undefined)continue;before.set(key,text);
    const hit=knowledgeMemo.get(key);
    if(!knowledgeVerify&&hit&&hit.before===text&&hit.visibility===visibilityText&&hit.mode===mode){aside.set(key,JSON.parse(hit.text));life[key]=null;}
   }
   if(!life)knowledgeMemo.clear();
   const notebook=process.env.CD_CARNET_CIBLES!=='complet'?model?.clubLife?.coachNotebook:null,targets=Array.isArray(notebook?.targets)?notebook.targets:null;
   if(targets)notebook.targets=[];
   try{
   // Portraits cohérents avec la carrure et l'origine (copie projetée seulement : la sauvegarde n'est pas touchée).
   if(process.env.CD_PORTRAIT_CARRURE!=='0')sub('portraits',()=>portraitLooks.apply(model));
   sub('knowledge',()=>knowledgeProjection.project(model,JSON.parse(visibilityText)));
   }finally{if(targets)notebook.targets=targets;for(const [key,value] of aside)life[key]=value;}
   for(const [key,text] of before){
    if(aside.has(key))continue;
    const after=JSON.stringify(life[key]),hit=knowledgeMemo.get(key);
    if(knowledgeVerify&&hit&&hit.before===text&&hit.visibility===visibilityText&&hit.mode===mode&&hit.text!==after)throw Error('Mémoire de connaissance périmée : '+key+'.');
    knowledgeMemo.set(key,{before:text,visibility:visibilityText,mode,text:after});
   }
   const trends=readProjection('Object.fromEntries((S?.clubs[S.club]?.players||[]).map(p=>[p.id,nativePotentialEvolution.project(S,p.id)]))');
   for(const p of model.squad||[])if(p.knowledge?.owned&&trends[p.id])p.potentialDevelopment=trends[p.id];
   model.managerPlanning=sub('planning',()=>managerPlanning.project(model));
   return model;
  };
  // Connaissance en mode « sections » (projection-sections.cjs) : mêmes étapes que projectKnowledge ; les sections
  // reprises sont des sentinelles que portraits et connaissance ne parcourent pas, puis la planification du manager lit
  // leur présentation mémorisée ; enfin le texte de chaque section est joint au modèle.
  const projectKnowledgeSections=model=>{
   const state=projectionState;projectionState=null;
   const notebook=process.env.CD_CARNET_CIBLES!=='complet'?model?.clubLife?.coachNotebook:null,targets=Array.isArray(notebook?.targets)?notebook.targets:null;
   if(targets)notebook.targets=[];
   try{
    if(process.env.CD_PORTRAIT_CARRURE!=='0')sub('portraits',()=>portraitLooks.apply(model));
    sub('knowledge',()=>knowledgeProjection.project(model,visibleOf(state.visibility)));
   }finally{if(targets)notebook.targets=targets;}
   const trends=readProjection('Object.fromEntries((S?.clubs[S.club]?.players||[]).map(p=>[p.id,nativePotentialEvolution.project(S,p.id)]))');
   for(const p of model.squad||[])if(p.knowledge?.owned&&trends[p.id])p.potentialDevelopment=trends[p.id];
   const keptPlanning=state.live?sectionMemo.keep('managerPlanning'):null;
   if(keptPlanning)model.managerPlanning=keptPlanning;
   else{sectionMemo.reveal(model);model.managerPlanning=sub('planning',()=>managerPlanning.project(model));sectionMemo.note('managerPlanning');}
   return sub('textes',()=>sectionMemo.finish(model));
  };
  // Une projection lit l'état sans le modifier : le dossier d'avant-match (feuille adverse
  // complète) y est calculé une seule fois puis partagé. Hors projection, chaque appel
  // recalcule comme avant. CD_ENGINE_MEMO=0 coupe ce partage (contrôle d'identité).
  const projectionMemo=process.env.CD_ENGINE_MEMO!=='0';
  if(projectionMemo)run(`{const original=matchDossier;let active=false,cached;let serial=0;globalThis.nativeProjectionMemo=on=>{active=on;cached=undefined;if(on)serial++;};globalThis.nativeProjectionActive=()=>active?serial:0;globalThis.nativeProjectionMemoBypass=fn=>{const was=active;active=false;try{return fn();}finally{active=was;}};matchDossier=function(){if(!active)return original();if(cached===undefined)cached=original();return cached;};}`);
  // Vie du club avec la mémoire par domaine ; si la mémoire elle-même échoue (hors vérification), calcul complet comme
  // avant : une réponse n'est jamais perdue à cause d'elle.
  const projectClubLife=()=>{
   try{return readProjection('nativeSystems.projectText(nativeCurrentSections())',true);}
   catch(error){if(ctx.nativeVerifyMemo)throw error;run('nativeSystems.clearMemo();nativeSectionsFresh=false;');return readProjection('nativeSystems.project()');}
  };
  // Palmarès connu dès le jour 1 (club-history.json) fusionné aux saisons archivées : club du manager et fiche club.
  const attachPalmares=model=>{if(model?.club&&model.meta?.mode==='world'&&Number.isSafeInteger(model.club.id))model.club.palmares=clubPalmares.build({history:clubHistory[model.club.id],archives:model.archives,clubId:model.club.id,clubName:model.club.name});if(model?.club&&model.meta?.hasCareer)model.gabi=gabiRepliques.choisir(model);return model;};
  // Réactivité (lot 19) : sections lourdes du modèle reprises d'une réponse à l'autre (projection-sections.cjs) et
  // versions des sections de la carrière à la place de leur texte pour la mémoire des domaines (state-versions.cjs).
  // CD_SECTIONS_PROJECTION=0 (ou projectionSections:false, ou sans mémoire des domaines) : projection complète d'avant.
  // CD_VERIFIER_PROJECTION=1 (ou verifyProjection:true, tests) : aucune section n'est reprise ; chaque section qui
  // l'aurait été est recalculée et comparée à la mémoire, et toutes les sections de la carrière sont relues pour
  // vérifier les déclarations de state-versions.cjs.
  const sectionsOn=memoDomains&&options.projectionSections!==false&&process.env.CD_SECTIONS_PROJECTION!=='0';
  const verifyProjection=options.verifyProjection===true||process.env.CD_VERIFIER_PROJECTION==='1';
  const sectionMemo=projectionSections.createSectionMemo();
  if(sectionsOn){run(stateVersions.SOURCE,'native-state-versions');run(projectionSections.CATALOGUE_SOURCE,'native-catalogue-sections');}
  const memoDomainKeys=sectionsOn?JSON.parse(run('JSON.stringify(nativeSystems.memoDomains())')):[];
  // Direct du match (tick, pause, consignes, remplacements, causeries pendant la rencontre) : seul l'état utile au
  // direct est recalculé ; les grands domaines de la vie du club (marché, staff, carnet, centre…) et la carrière
  // internationale gardent leur présentation de la dernière réponse complète jusqu'au coup de sifflet final ou à la
  // première commande hors du direct. Les sections lourdes de la carrière touchées pendant le direct sont relues à
  // la projection complète suivante.
  const LIVE_COMMANDS=new Set(['tick','pause','set_tactics','set_penalty_policy','set_consignes','appliquer_staff','set_role_direct','cri','substitute','match_talk_decide','match_talk_continue','match_incident_choice']);
  let projectionState=null,versionsSynced=false;
  // Versions des sections de la carrière pour cette projection (state-versions.cjs), avant toute lecture mémorisée.
  const refreshVersions=operation=>{
   const command=operation?.command??'snapshot',declared=stateVersions.untouched(command,operation?.payload),live=projectionState.live;
   if(live)run('nativeStateVersions.markDirty('+JSON.stringify(stateVersions.HEAVY.filter(key=>!declared.includes(key)))+')');
   // Décision sur un joueur du club (state-versions.cjs, OWN_CLUB) : seul le club du manager est relu dans `clubs`.
   const own=!live&&stateVersions.ownClubOnly(command)?['clubs']:[];
   run('nativeStateVersions.refresh('+JSON.stringify(live?stateVersions.HEAVY:declared)+','+(verifyProjection&&!live)+','+JSON.stringify(own)+')');
   versionsSynced=true;
  };
  // Frontière de connaissance (~6 Mo) : relue une fois par texte (même chaîne = même carte, jamais modifiée).
  let visibleText=null,visibleMap=null;
  const visibleOf=text=>{if(text!==visibleText){visibleMap=JSON.parse(text);visibleText=text;}return visibleMap;};
  // Début d'une projection par sections : réglages globaux de la présentation (mode, frontière de connaissance…).
  // La frontière (~6 Mo) entre dans les réglages globaux par un numéro, changé seulement quand son texte change (même
  // chaîne reprise de la mémoire : comparaison immédiate) : ni jointure ni comparaison de 6 Mo à chaque réponse.
  let globalVisibility=null,globalVisibilityId=0;
  const beginSections=m=>{
   const visibility=run('nativeStateVersions.memoText("visibility",state=>nativeKnowledge.visibility(state))');
   if(visibility!==globalVisibility){globalVisibility=visibility;globalVisibilityId++;}
   sectionMemo.begin({globals:[String(m.meta?.mode??''),String(m.meta?.database?.id??''),'frontiere#'+globalVisibilityId,process.env.CD_PORTRAIT_CARRURE!=='0',process.env.CD_CARNET_CIBLES??'',creation(),creation('world'),creation('world-pacific'),creation('world-japan'),creation('world-nationale'),creation('world-champ')].join('\u0001'),bypass:projectionState.bypass,verify:verifyProjection});
   projectionState.visibility=visibility;
  };
  // Décisions du manager (decisions.cjs) : fonction de la carrière seule, reprises tant que les parties lues n'ont pas
  // changé (relevé fin, state-versions.cjs). Le dossier d'avant-match, partagé pendant une projection, est recalculé
  // dans le relevé pour que ses lectures y soient notées. En vérification, recalculées et comparées.
  // Mémoire périmée : calcul direct, relevé fait après la réponse (flushStep, warmPending).
  const DECISIONS_MEMO=projectionMemo?'nativeStateVersions.memoTextLater("decisions",()=>nativeProjectionMemoBypass(()=>nativeDecisions()),nativeDecisionParts.stringify)':'nativeStateVersions.memoTextLater("decisions",()=>nativeDecisions(),nativeDecisionParts.stringify)';
  // Décisions par sections (clé de premier niveau de decisions) : chacune est reprise telle que présentée à la réponse
  // précédente quand son texte brut et les réglages globaux sont les mêmes (projection-sections.cjs) ; les rapports
  // d'observation, joints à `recruitment`, font partie de son entrée. Pendant le direct, `development` garde sa
  // présentation de la dernière réponse complète.
  // Texte des décisions assemblé clé par clé (même texte que JSON.stringify pour un objet simple sans toJSON) : ses
  // parties sont gardées avec lui, sans relire le texte.
  if(sectionsOn)run(`globalThis.nativeDecisionParts=(()=>{let last,parts=null;
   const split=d=>d&&typeof d==='object'&&!Array.isArray(d)&&Object.getPrototypeOf(d)===Object.prototype&&typeof d.toJSON!=='function'?Object.keys(d).map(k=>[k,JSON.stringify(d[k])]).filter(x=>x[1]!==undefined):null;
   const out=text=>{if(text!==last){const d=JSON.parse(text);parts=split(d)??(d===null?null:[[null,text]]);last=text;}return parts;};
   out.stringify=d=>{const list=split(d);if(!list)return JSON.stringify(d);const text='{'+list.map(([k,t])=>JSON.stringify(k)+':'+t).join(',')+'}';last=text;parts=list;return text;};
   return out;})();`);
  const projectDecisionSections=()=>{
   const parts=run('nativeDecisionParts('+DECISIONS_MEMO+')');
   if(!warmPending&&peek('nativeStateVersions.hasLater()'))warmPending=true;
   if(parts===null)return null;
   if(parts.length===1&&parts[0][0]===null)return JSON.parse(parts[0][1]);
   const out={};
   for(const [key,text] of parts){
    const path='decisions.'+key;
    if(key==='development'&&projectionState.live){out[key]=JSON.parse(text);liveSection(out,key,path);continue;}
    if(key==='recruitment'&&text.charCodeAt(0)===123){
     const reports=sub('reports',()=>run('nativeStateVersions.memoText("reports",state=>nativeKnowledge.reports(state))'));
     const kept=sectionMemo.take(path,[text,reports]);
     if(kept){out[key]=kept;continue;}
     const value=JSON.parse(text);value.reports.push(...JSON.parse(reports));out[key]=value;continue;
    }
    out[key]=sectionMemo.take(path,text)||JSON.parse(text);
   }
   return out;
  };
  // Carrière internationale (international-native.cjs, projectCareer) : reprise tant que ses entrées sont les mêmes
  // (carrière internationale, effectifs vus par les sélections, club, phase, absents de la tournée d'été). En
  // vérification, recalculée et comparée.
  // Sa présentation (section `international` du modèle) est elle-même reprise quand son texte brut et les réglages
  // globaux sont ceux de la réponse précédente (projection-sections.cjs) ; `nationalRaw` note qu'elle est suivie ainsi.
  let nationalMemo=null,nationalRaw=null;
  const memoNational=compute=>{
   const roster=run('nativeStateVersions.memoText("roster",()=>nativeInternationalRoster())');
   const inputs=run(`JSON.stringify([S?.national??null,S?.club??null,S?.phase??null,(()=>{try{return typeof CDReprise!=='undefined'?CDReprise.absentees(S):null}catch(e){return 'indisponible'}})()])`);
   const hit=nationalMemo&&nationalMemo.roster===roster&&nationalMemo.inputs===inputs?nationalMemo:null;
   if(hit&&!verifyProjection){nationalRaw=hit.text;return {...hit.out,international:sectionMemo.take('international',hit.text)||JSON.parse(hit.text)};}
   const out=compute(),text=JSON.stringify(out.international);
   if(hit&&text!==hit.text)throw Error('Mémoire de projection périmée : international.');
   nationalMemo={roster,inputs,text,out:{date:out.date,current:out.current,managedClub:out.managedClub}};
   if(text!==undefined){nationalRaw=text;const kept=sectionMemo.take('international',text);if(kept)return {...out,international:kept};}
   return out;
  };
  // Catalogues de création (projection-sections.cjs, CATALOGUES) : repris tels que présentés à la réponse précédente
  // quand leur jeton (même catalogue mémorisé dans la VM) et les réglages globaux n'ont pas changé ; sinon relus.
  const carryCatalogues=(m,tokens)=>{
   for(const [key,token] of Object.entries(tokens)){
    const kept=projectionState?sectionMemo.take('meta.'+key,token):null;
    m.meta[key]=kept||JSON.parse(run('nativeCatalogueSections.text('+JSON.stringify(key)+')'));
   }
  };
  // Direct du match : sections gardées telles que présentées à la dernière réponse complète (sinon recalculées et notées).
  const liveSection=(container,key,path)=>{
   if(!projectionState||!container||typeof container!=='object'||!Object.hasOwn(container,key))return;
   const kept=projectionState.live?sectionMemo.keep(path):null;
   if(kept)container[key]=kept;else sectionMemo.note(path);
  };
  // Parties de la vie du club lues par une autre étape avant la présentation finale (reprise impossible : la
  // sentinelle serait lue à leur place) : presse (répliques de Gabi), compétition personnalisée (nom du championnat).
  // Les autres parties, mémorisables ou non, sont reprises quand leur texte brut et les réglages globaux sont les mêmes.
  const LIFE_READ_EARLY=new Set(['press','customCompetition']);
  const projectLifeSections=(m,operation)=>{
   const live=projectionState.live;
   const staffKey=JSON.stringify(m.meta?.catalogue??null)+'\u0001'+JSON.stringify(m.meta?.database??null);
   let skip=null;
   if(live){skip=memoDomainKeys.filter(key=>!LIFE_READ_EARLY.has(key)&&sectionMemo.available('clubLife.'+key));if(!sectionMemo.available('staff'))skip=skip.filter(key=>key!=='staffCareer');}
   const parts=run('nativeSystems.projectParts(nativeStateVersions.current(),'+(skip?'new Set('+JSON.stringify(skip)+')':'null')+')');
   const life={};
   for(const [key,text] of parts){
    const path='clubLife.'+key;
    if(text===null){life[key]=sectionMemo.keep(path);if(key==='staffCareer')projectionState.staff=sectionMemo.keep('staff');continue;}
    if(key==='staffCareer'&&memoDomainKeys.includes(key)){const [career,team]=sectionMemo.takeAll([[path,text],['staff',[text,staffKey]]]);life[key]=career||JSON.parse(text);projectionState.staff=team;continue;}
    life[key]=(!LIFE_READ_EARLY.has(key)&&sectionMemo.take(path,text))||JSON.parse(text);
   }
   return life;
  };
  const snapshotRaw=(operation,bypass=true)=>{
   if(sectionsOn&&!bypass)sectionMemo.abort();
   const attempt=allow=>{if(!projectionMemo)return attachPalmares(snapshotProjection(operation,allow));peek('nativeProjectionMemo(true)');try{return attachPalmares(snapshotProjection(operation,allow));}finally{peek('nativeProjectionMemo(false)');}};
   try{return attempt(bypass);}
   catch(error){
    // Pack d'identité dont les remplacements de noms ont changé : projection refaite sans reprise de section.
    if(error?.code!==projectionSections.RETRY)throw error;
    sectionMemo.abort();return attempt(false);
   }
  };
  const snapshotProjection=(operation,bypass=true)=>{updatePressPolicy();projectionState=null;const [m,catalogueTokens]=sub('model',()=>sectionsOn?JSON.parse(run('nativeCatalogueSections.read()')):[readProjection('nativeModel()'),null]);if(sectionsOn&&peek('!!S'))projectionState={sections:true,bypass,live:!!operation&&LIVE_COMMANDS.has(operation.command)&&!!m.live&&!m.live.finished&&!(operation.command==='match_talk_continue'&&operation.payload?.phase==='post'),staff:null,result:null};if(projectionState){sub('versions',()=>refreshVersions(operation));sub('visibility',()=>beginSections(m));}if(catalogueTokens)sub('catalogues',()=>carryCatalogues(m,catalogueTokens));sub('france',()=>projectFranceCalendar(m));if(projectionState)m.decisions=sub('decisions',()=>projectDecisionSections());else{m.decisions=sub('decisions',()=>readProjection('nativeDecisions()'));if(m.decisions?.recruitment)sub('reports',()=>m.decisions.recruitment.reports.push(...readProjection('nativeKnowledge.reports(S)')));}if(projectionState){try{m.clubLife=sub('clubLife',()=>projectLifeSections(m,operation));}catch(error){if(ctx.nativeVerifyMemo||verifyProjection)throw error;/* Repli : calcul complet comme avant (la mémoire ne fait jamais perdre une réponse). */sectionMemo.abort();projectionState=null;run('nativeSystems.clearMemo();nativeStateVersions.reset();');m.decisions=readProjection('nativeDecisions()');if(m.decisions?.recruitment)m.decisions.recruitment.reports.push(...readProjection('nativeKnowledge.reports(S)'));m.clubLife=readProjection('nativeSystems.project()');}}else m.clubLife=sub('clubLife',()=>memoDomains?projectClubLife():readProjection('nativeSystems.project()'));
   const keptInternational=projectionState?.live?sectionMemo.keep('international'):null;if(keptInternational)m.international=keptInternational;else{nationalRaw=null;sub('national',()=>national.project(m,projectionState?{roster:()=>JSON.parse(run('nativeStateVersions.memoText("roster",()=>nativeInternationalRoster())')),memo:memoNational}:{}));if(projectionState&&m.international!==undefined&&nationalRaw===null)sectionMemo.note('international');}m.meta.profileError=profileError;m.meta.legacyPurgeNotice=legacyPurgeNotice;m.meta.matchResumeNotice=matchResumeNotice;m.meta.legacyModes=legacyModes;m.meta.recoveryRequired=!!profileError;m.meta.recoveryBackup=recoveryBackup;m.meta.profileSafety=profileSafety.project();if(journal)m.meta.autosave=autosaveMeta();m.meta.academyGroupPolicy=peek('S?.academyGroupPolicy??0');m.meta.repriseCreation=JSON.parse(run('JSON.stringify(CDReprise.creation())'));m.meta.careerVariation=JSON.parse(peek('JSON.stringify(S?.careerVariation??null)'));const result=sub('packs',()=>packs.project(sub('staff',()=>projectionState?.staff?{...m,staff:projectionState.staff}:staff.project(m)),JSON.parse(peek('JSON.stringify(S?.identityPack||null)')),creation(),creation('world'),creation('world-pacific'),creation('world-japan'),creation('world-nationale'),creation('world-champ'),projectionState?{nested:modelDelta.NESTED,carriedOf:sectionMemo.carriedOf,recordCarried:sectionMemo.recordCarried,signature:sectionMemo.packSignature}:null));if(projectionState)projectionState.result=result;sub('presentation',()=>staff.applyCareerPresentation(result));const custom=result.clubLife?.customCompetition;if(custom&&result.leagues?.length===1){result.leagues[0].name=custom.name;result.leagues[0].notice=custom.notice;}result.epcrPreparation=sub('epcr',()=>epcrPreparation.project(result));sub('calendar',()=>projectCalendar(result,operation));if(matchHighlights&&result.live){/* Présentation seule : si la projection échoue, le match reste jouable dans le direct d'origine et la raison est jointe. */try{result.live.direct=sub('direct',()=>matchDirect.project(result,matchHighlights,matchDirectReader,{choregraphe:matchChoreography}));}catch(error){result.live.directError=String(error?.message||error);}}return result;};
  // Raw models stay private; every protocol path still applies the final
  // knowledge boundary after attaching receipts, previews or export metadata.
  const snapshot=operation=>{const m=snapshotRaw(operation);continuePlan(m);return projectKnowledge(m);};
  const backup=path.join(dataDir,'donnees-precedentes.json');
  let committedFiles='';
  // Texte de la dernière sauvegarde publiée tant que la carrière en mémoire n'a pas changé depuis ;
  // null sinon (démarrage, annulation d'origine inconnue, récupération). CD_VERIFIER_COPIE=1 (tests)
  // recalcule l'état pour vérifier cette égalité à chaque commande.
  let cleanSave=null,lastFlushMs=0;
  const verifyCleanCopy=options.verifyCleanCopy===true||process.env.CD_VERIFIER_COPIE==='1';
  const copyStore=source=>{const out={};for(const key of Object.keys(source)){const value=source[key];if(typeof value==='string'){out[key]=value;continue;}const text=JSON.stringify(value);if(text!==undefined)out[key]=JSON.parse(text);}return out;};
  const sameStore=(a,b)=>{const keys=Object.keys(a);if(keys.length!==Object.keys(b).length)return false;for(const key of keys)if(!Object.hasOwn(b,key)||(typeof a[key]==='string'?a[key]!==b[key]:JSON.stringify(a[key])!==JSON.stringify(b[key])))return false;return true;};
  const profileFilesVersion=()=>{
   try{
    const entries=[file,backup].map(target=>fs.lstatSync(target,{bigint:true}));
    if(entries.some(entry=>!entry.isFile()))return '';
    return entries.map(entry=>[entry.dev,entry.ino,entry.size,entry.mtimeNs,entry.ctimeNs].join(':')).join('|');
   }catch{return '';}
  };
  // Texte du profil : identique octet pour octet à JSON.stringify({protocol:1,seed,clock,store}), mais
  // chaque valeur du magasin (la carrière fait ~22 Mo) n'est réencodée que si elle a changé. Le texte est rendu en
  // morceaux, écrits l'un après l'autre : ni la carrière encodée ni le profil complet (~40 Mo chacun, en double octet)
  // ne sont assemblés en mémoire à chaque écriture.
  const storeEncoding=new Map(),sectionEscapes=new Map();
  // Encodage JSON (chaîne dans la chaîne) de la carrière à partir de ses sections : l'échappement d'un texte
  // se fait caractère par caractère et les coupures tombent sur des virgules, donc la concaténation des
  // sections encodées est exactement JSON.stringify(texte complet).
  const encodeSections=sections=>{
   const chunks=['"{'];
   for(const key of sections.keys){
    const text=sections.texts.get(key);let hit=sectionEscapes.get(key);
    if(!hit||hit.text!==text){hit={text,escaped:JSON.stringify(JSON.stringify(key)+':'+text).slice(1,-1)};sectionEscapes.set(key,hit);}
    if(chunks.length>1)chunks.push(',');
    chunks.push(hit.escaped);
   }
   for(const key of [...sectionEscapes.keys()])if(!sections.texts.has(key))sectionEscapes.delete(key);
   chunks.push('}"');
   return chunks;
  };
  const profileChunks=()=>{
   const chunks=['{"protocol":1,"seed":'+JSON.stringify(seed)+',"clock":'+JSON.stringify(clock)+',"store":{'];let first=true;
   for(const key of Object.keys(store)){
    const value=store[key];let encoded;
    if(typeof value==='string'){
     const cached=storeEncoding.get(key);
     if(cached&&cached.value===value)encoded=cached.encoded;
     else{
      const sections=key==='bdt-v1'?ctx.nativeSaveSections:null;
      encoded=sections&&sections.whole===value?encodeSections(sections):[JSON.stringify(value)];
      if(ctx.nativeVerifySections&&encoded.join('')!==JSON.stringify(value))throw Error('Encodage par sections différent du texte complet.');
      storeEncoding.set(key,{value,encoded});
     }
    }else{const text=JSON.stringify(value);encoded=text===undefined?undefined:[text];}
    if(encoded===undefined)continue;
    chunks.push((first?'':',')+JSON.stringify(key)+':');first=false;
    for(const chunk of encoded)chunks.push(chunk);
   }
   for(const key of storeEncoding.keys())if(!Object.hasOwn(store,key)||typeof store[key]!=='string')storeEncoding.delete(key);
   chunks.push('}}');
   return chunks;
  };
  // Copie de secours du fichier courant : un lien physique vers le fichier déjà écrit (et forcé sur
  // disque) remplace la relecture et la réécriture de ~25 Mo ; le renommage atomique qui suit est
  // inchangé, si bien que la copie garde seule l'ancien contenu. Sans lien possible (FAT, partage
  // réseau, fichier déjà lié ailleurs), copie complète comme avant.
  const backupFrom=(source,target,write)=>{
   const s=fs.lstatSync(source);
   if(s.nlink===1){
    try{fs.linkSync(source,target);}catch{write(target,fs.readFileSync(source));return;}
    // Windows refuse fsync (EPERM) sur un descripteur ouvert en lecture seule : ouverture en 'r+'. Le lien partage l'inode déjà écrit, donc un refus de fsync n'enlève aucune donnée.
    try{const fd=fs.openSync(target,'r+');try{fs.fsyncSync(fd);}finally{fs.closeSync(fd);}}catch{}
    return;
   }
   write(target,fs.readFileSync(source));
  };
  // Reprise avant le match (décision de Léo, 16/11/2026) : une carrière n'est jamais enregistrée en plein match. Du coup
  // d'envoi (begin_match) à la validation du résultat (finish_round), le profil écrit est celui d'avant le coup d'envoi
  // (texte de la carrière, graine et horloge d'alors, autres clés du magasin à jour) et le journal ne note rien : une
  // fermeture ou une coupure pendant le match fait reprendre la carrière le jour du match, avant le coup d'envoi.
  // CD_REPRISE_AVANT_MATCH=0 (ou matchResume:false) rétablit l'ancien comportement (tests des anciennes sauvegardes).
  const matchResume=options.matchResume!==false&&process.env.CD_REPRISE_AVANT_MATCH!=='0';
  const matchOpenNow=()=>matchResume&&peek("!!S?.live&&S.worldMode?.resultConfirmed!==true&&S.franceCalendar?.resultConfirmed!==true");
  let preMatch=null,matchResumeNotice=null;
  // Ancienne sauvegarde écrite en plein match (avant cette règle) sans l'état d'avant le coup d'envoi : lue telle quelle,
  // match repris en pause, et le manager en est informé.
  const legacyMatchNotice=()=>matchOpenNow()?{kind:'en-match',text:'Cette carrière a été enregistrée pendant un match par une version précédente du jeu : l’état d’avant le coup d’envoi n’y figure pas. Le match reprend donc en pause, à la minute enregistrée.'}:null;
  const PRE_MATCH_NOTICE={kind:'avant-match',text:'Le match en cours n’avait pas été terminé : ta carrière reprend avant le coup d’envoi.'};
  // Texte d'avant le coup d'envoi validé une fois (validation complète) avant sa première écriture.
  const preMatchStore=()=>{
   if(!preMatch.validated){ctx.nativePreMatchText=preMatch.text;try{run('validateCareer(JSON.parse(nativePreMatchText))');}finally{delete ctx.nativePreMatchText;}preMatch.validated=true;}
   return {...store,'bdt-v1':preMatch.text};
  };
  // Document de sauvegarde de la carrière (export, copies de sécurité) : pendant un match, celui d'avant le coup d'envoi.
  const saveDocumentText=()=>{
   if(!preMatch)return run('JSON.stringify(createSaveDocument())');
   ctx.nativePreMatchText=preMatch.text;
   try{return run('JSON.stringify(createSaveDocument(JSON.parse(nativePreMatchText)))');}finally{delete ctx.nativePreMatchText;}
  };
  const persist=()=>{
   if(!preMatch)return persistNow();
   // Profil d'avant le coup d'envoi déjà publié et inchangé depuis : rien à réécrire.
   if(preMatch.committed&&preMatch.committed===committedFiles&&profileFilesVersion()===committedFiles)return;
   const current={seed,clock,store},written=preMatchStore();
   seed=preMatch.seed;clock=preMatch.clock;store=written;
   try{persistNow();}finally{seed=current.seed;clock=current.clock;store=current.store;}
   preMatch.committed=committedFiles;
  };
  const persistNow=()=>{
   committedFiles='';
   if(resumeCheckpoint)profileSafety.checkpoint({...resumeCheckpoint,reason:'adaptation-reprise'});
   const token=randomUUID(),text=profileChunks(),temp=path.join(dataDir,'donnees.tmp-'+token),backupTemp=path.join(dataDir,'donnees-precedentes.tmp-'+token),rollback=path.join(dataDir,'donnees-precedentes.rollback-'+token);
   const write=(target,content)=>{const fd=fs.openSync(target,'wx');try{if(Array.isArray(content))for(const chunk of content)fs.writeFileSync(fd,chunk);else fs.writeFileSync(fd,content);fs.fsyncSync(fd);}finally{fs.closeSync(fd);}};
   const ordinary=target=>{const s=fs.lstatSync(target);if(!s.isFile()||s.isSymbolicLink())throw Error('Fichier de sauvegarde ou de secours non ordinaire.');};
   let stashed=false,published=false,digest=null;
   try{
    mark('profil_texte');write(temp,text);mark('ecriture_fsync');
    // Journal : empreinte du profil à publier, marquée avant le renommage (voir action-journal.cjs, « publication »).
    if(journal){const hash=createHash('sha256');for(const chunk of text)hash.update(chunk,'utf8');digest=hash.digest('hex');journal.markPublication(digest);mark('journal');}
    if(fs.existsSync(file)){
     ordinary(file);backupFrom(file,backupTemp,write);mark('secours');
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
   // Profil publié : nouveau journal vide lié à lui. Un échec ici ne perd rien (marque de publication déjà écrite).
   if(journal){try{journal.reset(digest);}catch{}loadedSha=digest;lastSavedKey=dateKey();savedNow=true;if(journalNotice&&!journalNotice.alert)journalNotice=null;}
  };
  // Date de la carrière (calendrier journalier), saison et journée : repère de la fréquence de sauvegarde.
  function dateKey(){try{return JSON.parse(run("(()=>{if(!S)return 'null';let d=null;try{const pre=typeof CDPreseason!=='undefined'?CDPreseason.pending(S):null;if(pre)d=pre.today;else if(S.worldMode?.day!==undefined)d=CDWorldCareer.calendarToday(S)}catch(e){}return JSON.stringify({date:d,season:S.season??null,round:S.round??null})})()"));}catch{return null;}}
  const savePolicy=()=>actionJournal.readPolicy(dataDir,savePolicyOverride);
  const fullSaveDue=()=>actionJournal.due(savePolicy(),lastSavedKey,dateKey());
  // Sauvegarde complète en mode journal : texte de la carrière à jour, validation des décisions qui ne l'ont pas encore
  // été (leurs sections modifiées), puis écriture atomique ; le journal repart de zéro.
  function fullSave(){
   if(peek('!!S')){run('nativeSaveCurrent()');mark('texte_complet');if(unvalidated){run('nativeValidateSaved(false)');unvalidated=false;mark('validation_decisions');}}
   persist();
  }
  // Ligne du journal pour la commande qui vient de réussir (graine avant/après, horloge utilisée).
  const journalAppend=(command,payload,priorSeed)=>{if(preMatch)return;try{if(!journal.exists()&&journal.count()===0&&loadedSha)journal.reset(loadedSha);journal.append({c:command,p:payload,k:clock,s:priorSeed,e:seed});}catch(e){const failure=Error('Décision non notée dans le journal de sauvegarde : '+e.message);failure.storageFailure=true;throw failure;}};
  // `planned` : sauvegarde complète prévue juste après la réponse (jour différé, voir dayAfter) : annoncée comme faite ;
  // si elle échoue, la commande suivante le dit.
  const autosaveMeta=(planned=null)=>journal?{policy:savePolicy(),lastSave:(planned??lastSavedKey)?.date??null,pending:planned?0:journal.count(),saved:planned?true:savedNow,notice:journalNotice}:null;
  // Jour différé (mode journal, lot 36) : un jour du calendrier (« Jour suivant » ou jour de « Continuer ») est noté au
  // journal avant sa réponse, comme une décision ; sa validation stricte (clôture de semaine, avant-saison) et la
  // sauvegarde complète due suivent la réponse (flushStep), au plus tard avant la commande suivante ou la fermeture.
  // Les jours de « Continuer » ne sont plus sérialisés un par un : la carrière l'est une fois, à l'arrêt. En cas
  // d'échec, la journée (ou l'avance) est annulée et la commande suivante le dit. CD_JOUR_DIFFERE=0 (ou
  // dayDeferral:false) rétablit le chemin d'avant.
  const dayDeferral=journalMode&&options.dayDeferral!==false&&process.env.CD_JOUR_DIFFERE!=='0';
  // Écriture différée des décisions courantes (option deferredCommits, activée par le jeu ; CD_ECRITURE_DIFFEREE=0
  // la coupe). Une décision qui n'avance pas le calendrier (composition, consignes, réunions, causeries, temps du
  // match en direct…) répond d'abord à l'interface ; sa sérialisation, sa validation stricte et l'écriture atomique
  // du profil suivent, dès que le moteur est libre (après l'envoi de la réponse) et au plus tard avant la commande
  // suivante, la fermeture ou « Sauvegarder ». Les commandes qui avancent la carrière (jour, semaine, saison, coup
  // d'envoi, préparation), la création, l'import, les restaurations et « Sauvegarder » restent écrites avant leur
  // réponse. Une coupure brutale ne perd donc au pire que la dernière décision courante, jamais la sauvegarde
  // (remplacement atomique inchangé). Si cette écriture échoue, la décision est annulée en mémoire comme avant et la
  // commande suivante est refusée avec la raison : aucun échec silencieux.
  const deferredCommits=options.deferredCommits===true&&process.env.CD_ECRITURE_DIFFEREE!=='0';
  const SYNC_COMMANDS=new Set(['new_career','import','restore_checkpoint','save','next_season','pack_select','population_enable','academy_groups_enable','recover_profile',...NATIONAL_COMMANDS]);
  // Commandes déjà écrites avant leur réponse (sérialisation, validation, écriture atomique de toute la carrière) :
  // une décision en attente y est regroupée au lieu d'être écrite d'abord à part. Sans ce regroupement, une avance
  // du calendrier envoyée juste après une décision attendait l'écriture complète de celle-ci (2 à 6 s selon la
  // machine et la taille du profil) avant son propre travail : la nouvelle saison dépassait ainsi la borne de 20 s de
  // la recette Windows (run 43603330612). La création, l'import et les restaurations remplacent la carrière : la
  // décision est alors écrite d'abord, comme avant.
  const COALESCING=new Set([...PRESS_PROGRESSION,'save','advance_until_event']);
  // Lectures pures (aucune écriture de la carrière) : elles gardent le texte des sections de la projection précédente.
  const READ_ONLY=new Set(['snapshot','club_sheet','epcr_preview','competition_editor_preview','club_preview','start_challenges']);
  let pendingCommit=null,pendingFailure=null,coalescing=null,undoPending=false,warmPending=false;
  // Relevés différés de la mémoire de projection (state-versions.cjs, memoTextLater) : faits après la réponse, en
  // dernière étape de l'écriture différée ; abandonnés si une commande arrive avant.
  const dropWarm=()=>{if(warmPending){warmPending=false;run('nativeStateVersions.dropLater()');}};
  const restorePrior=prior=>{
   stateEpoch++;
   seed=prior.seed;clock=prior.clock;store=copyStore(prior.store);ctx.nativePrior=prior.state();cleanSave=prior.fromSave?prior.text:null;projectionCache.clear();
   try{run('nativeSystems.clearTransient()');run('S=nativePrior.state;if(S?.live&&nativePrior.playback)MATCH_PLAYBACK.set(S.live,nativePrior.playback);pendingSave=null;lastSaveError=nativePrior.saveError;nativeSaveSections=null;');}
   finally{delete ctx.nativePrior;}
   if(preMatch&&!matchOpenNow())preMatch=null;
  };
  // Termine la décision en attente par étapes : sérialisation, validation, puis écriture atomique. Entre deux étapes,
  // la boucle stdio lit les commandes arrivées : une commande qui n'attend donc au plus que l'étape en cours, et une
  // avance du calendrier reprend la décision à son compte (regroupement ci-dessus). Chaque étape renvoie vrai quand
  // il n'y a plus rien à écrire. En cas d'échec, l'état d'avant la décision est rétabli et l'erreur est gardée pour
  // la prochaine réponse.
  // Signal de sauvegarde en arrière-plan (option onEvent ; le jeu l'active avec --events) : `persist` started au début du
  // travail différé (sérialisation, validation, écriture), done à sa fin, failed s'il échoue (l'erreur reste refusée à la
  // commande suivante, comme avant). Observation seulement : aucune réponse, graine ni écriture n'en dépend.
  const emitEvent=typeof options.onEvent==='function'?options.onEvent:null;let persistBusy=false;
  function flushStep(){
   if(!emitEvent)return flushWork();
   const before=pendingFailure;
   if(pendingCommit&&!persistBusy){persistBusy=true;try{emitEvent({event:'persist',state:'started',command:pendingCommit.command});}catch{}}
   const done=flushWork();
   if(persistBusy&&done){persistBusy=false;const failed=pendingFailure&&pendingFailure!==before;try{emitEvent(failed?{event:'persist',state:'failed',message:pendingFailure.message}:{event:'persist',state:'done'});}catch{}}
   return done;
  }
  function flushWork(){
   // Journal et projection par sections : copie d'annulation de la dernière décision (texte de la carrière), faite
   // après la réponse plutôt qu'avant.
   if(!pendingCommit&&undoPending){undoPending=false;if(peek('!!S')){run('nativeSaveCurrent()');cleanSave=typeof store['bdt-v1']==='string'?store['bdt-v1']:null;}return !warmPending;}
   // Relevés différés (rien à écrire) : un échec ne coûte que la reprise de la mémoire, jamais la réponse ni l'écriture.
   if(!pendingCommit&&warmPending){warmPending=false;try{run('nativeStateVersions.warm()');}catch(error){run('nativeStateVersions.dropLater()');if(verifyProjection)throw error;}return true;}
   const pending=pendingCommit;if(!pending)return true;
   if(pending.day)return dayStep(pending);
   try{
    if(pending.stage===0){run(memoDomains?'nativeSaveCurrent();':'save();');pending.stage=1;return false;}
    if(pending.stage===1){run('nativeValidateSaved('+pending.full+')');pending.stage=2;return false;}
    pendingCommit=null;
    if(pending.tick&&committedFiles&&seed===pending.prior.seed&&sameStore(store,pending.prior.store)&&profileFilesVersion()===committedFiles)clock=pending.prior.clock;
    else persist();
    cleanSave=typeof store['bdt-v1']==='string'?store['bdt-v1']:null;
    return !warmPending;
   }catch(error){
    pendingCommit=null;
    const failure=Error('Ta dernière décision n’a pas pu être enregistrée ; elle est annulée et cette nouvelle action n’a pas été appliquée. '+error.message);failure.command=pending.command;failure.storageFailure=true;
    try{restorePrior({...pending.prior,state:()=>({...pending.prior.state(),saveError:true})});}catch(restore){failure.message+=' Restauration impossible : '+restore.message;}
    pendingFailure=failure;
    return true;
   }
  }
  // Jour différé (dayDeferral) : validation stricte (clôture, avant-saison), puis sauvegarde complète si elle est due. Un
  // échec annule la journée (ou l'avance de « Continuer ») et retire ses lignes du journal ; la commande suivante le dit.
  function dayStep(pending){
   // Validation stricte d'une journée : les relevés différés de la mémoire de projection ne sont pas faits après elle.
   dropWarm();
   try{
    if(pending.stage===1){if(pending.validate&&run('!!S')){run('nativeSaveCurrent()');run('nativeValidateSaved(false)');unvalidated=false;}pending.stage=2;return false;}
    pendingCommit=null;
    if(pending.save)fullSave();
    cleanSave=typeof store['bdt-v1']==='string'?store['bdt-v1']:null;
    return true;
   }catch(error){
    pendingCommit=null;
    const failure=Error('Ta dernière journée n’a pas pu être enregistrée ; elle est annulée et cette nouvelle action n’a pas été appliquée. '+error.message);failure.command=pending.command;failure.storageFailure=true;
    try{restorePrior({...pending.prior,state:()=>({...pending.prior.state(),saveError:true})});}catch(restore){failure.message+=' Restauration impossible : '+restore.message;}
    if(journal){try{journal.truncate(pending.journalAt.offset,pending.journalAt.count);}catch(e){failure.message+=' Journal non raccourci : '+e.message;}}
    pendingFailure=failure;
    return true;
   }
  }
  function flushCommit(){while(!flushStep());}
  // Fermeture : en mode journal, sauvegarde complète si des actions attendent (en cas d'échec, le journal les garde).
  flushBeforeClose=()=>{if(advanceSession){const session=advanceSession;advanceSession=null;try{finishAdvance(null,session,null);}catch{}}flushCommit();if(journal&&journal.count()>0&&!profileError)fullSave();};
  // Instrumentation des allers-retours (CD_ENGINE_TIMING=1) : durées par phase, sans effet sur la simulation.
  const timing=options.timing===true||process.env.CD_ENGINE_TIMING==='1';let phases=null,phaseAt=0;
  const mark=label=>{if(!phases)return;const now=performance.now();phases[label]=Math.round(((phases[label]||0)+now-phaseAt)*10)/10;phaseAt=now;};
  // Détail d'une phase (préfixe « p. ») sans déplacer le repère de mark : coût de chaque étape de la projection.
  const sub=(label,fn)=>{if(!phases)return fn();const started=performance.now();try{return fn();}finally{phases['p.'+label]=Math.round(((phases['p.'+label]||0)+performance.now()-started)*10)/10;}};
  // Réponses légères aux commandes refusées (option lightErrors, boucle stdio) : l'époque de l'état avance à chaque
  // commande qui peut modifier la carrière ; celle du dernier modèle rendu est notée par handle(). Égales, l'interface
  // détient le modèle de l'état courant.
  const lightErrors=options.lightErrors===true&&process.env.CD_ERREURS_LEGERES!=='0';
  const LIGHT_ERROR_EXCLUDED=new Set(['pack_inspect','pack_install','pack_select','recover_profile','import','restore_checkpoint','new_career','remove_checkpoint','shutdown','export']);
  let stateEpoch=0,modelEpoch=-1;
  const lightError=(id,message)=>{const out={id,ok:false,model:null,error:message};Object.defineProperty(out,modelDelta.UNCHANGED,{value:true});Object.defineProperty(out,modelDelta.FALLBACK,{value:()=>snapshot()});return out;};
  function handleMeasured(request){
   const handler=request?.command==='advance_until_event'?advanceUntilEvent:handleCommand;
   if(!timing)return handler(request);
   phases={};phaseAt=performance.now();const started=phaseAt;
   const response=handler(request);mark('reste');phases.total=Math.round((performance.now()-started)*10)/10;
   if(response&&typeof response==='object')response.timing=phases;phases=null;return response;
  }
  // `replay` : ligne du journal rejouée au chargement (horloge et graine enregistrées, ni projection ni écriture).
  function handleCommand(request,light=false,replay=null){
   dropWarm();
   let id=null;const epochBefore=stateEpoch;
   try{
    if(!request||typeof request!=='object'||Array.isArray(request))throw Error('Message JSON invalide.');
    if(!(Number.isSafeInteger(request.id)&&request.id>=0||typeof request.id==='string'&&request.id.length>0&&request.id.length<=100&&!/[\r\n]/.test(request.id)))throw Error('Identifiant de commande invalide.');
    id=request.id;if(closed)throw Error('Le moteur est fermé.');
    if(!COMMANDS.has(request.command))throw Error('Commande inconnue ou interdite.');
    let payload=request.payload??{};if(typeof payload!=='object'||payload===null||Array.isArray(payload))throw Error('Paramètres de commande invalides.');
    let command=request.command,restoring=null;
    // Budget réaliste des carrières aux salaires liés au niveau : branché avant toute commande,
    // y compris le premier snapshot en lecture seule après une reprise (plancher et prévision).
    if(!ctx.nativeClubBudget){ctx.nativeClubBudget=require('./club-budget.cjs');ctx.nativeStartingSalaries=require('./starting-salaries.cjs');ctx.nativeLeagueEconomy=require('./league-economy.cjs');run(ctx.nativeClubBudget.BRANCHEMENT);ctx.nativeClubHealth=require('./club-finance-health.cjs');run(ctx.nativeClubHealth.BRANCHEMENT);ctx.nativeClubOwner=require('./club-owner.cjs');run(ctx.nativeClubOwner.BRANCHEMENT);ctx.nativeClubInvestments=require('./club-investments.cjs');run(ctx.nativeClubInvestments.BRANCHEMENT);run(ctx.nativeProlongations.BRANCHEMENT);run(ctx.nativeStaffRenouvellement.BRANCHEMENT);ctx.nativeA2R=require('./a2r.cjs');run(ctx.nativeA2R.BRANCHEMENT);ctx.nativePresidentReprise=require('./president-reprise.cjs');run(ctx.nativePresidentReprise.BRANCHEMENT);ctx.nativeBudgetTransferts=require('./budget-transferts.cjs');run(ctx.nativeBudgetTransferts.BRANCHEMENT);ctx.nativeVenteJoueurs=require('./vente-joueurs.cjs');run(ctx.nativeVenteJoueurs.BRANCHEMENT);ctx.nativeCalendrierMutations=require('./calendrier-mutations.cjs');run(ctx.nativeCalendrierMutations.BRANCHEMENT);}
    const syncedAtStart=versionsSynced;
    if(!READ_ONLY.has(command)){peek('nativeSectionsFresh=false');stateEpoch++;versionsSynced=false;}
    if(command==='snapshot')return {id,ok:true,model:snapshot()};
    if(command==='recover_profile'){if(!profileError)throw Error('Aucun profil à récupérer.');if(payload.confirmed!==true)throw Error('Confirmation requise pour préserver puis remplacer le profil illisible.');const backup=path.join(dataDir,'donnees-endommagees-'+randomUUID()+'.json');fs.copyFileSync(file,backup,fs.constants.COPYFILE_EXCL);recoveryBackup=backup;profileError='';store={};cleanSave=null;run('S=null;loadSaveFailure="";lastSaveError=false;nativeSaveSections=null;');return {id,ok:true,model:snapshot()};}
    if(profileError&&!['snapshot','shutdown'].includes(command))throw Error(profileError+' Confirme la récupération du profil.');
    if(command==='competition_editor_preview'){const model=snapshotRaw();model.competitionEditor=competitionEditor.project(payload);return {id,ok:true,model:projectKnowledge(model)};}
    // Fiche d'un club (lecture seule, rien n'est écrit) : native/engine/club-sheet.cjs.
    if(command==='club_sheet'){
     if(!Number.isSafeInteger(payload.club)||Object.keys(payload).some(k=>k!=='club'))throw Error('Paramètres de fiche club invalides.');
     if(!peek('!!S'))throw Error('Crée ou importe une carrière.');
     ctx.nativePayload={club:payload.club};
     const model=snapshotRaw();model.clubSheet=JSON.parse(run('JSON.stringify(nativeSystems.domain("clubSheet").sheet(nativePayload.club))'));model.clubSheet.palmares=clubPalmares.build({history:clubHistory[payload.club],archives:model.archives,clubId:payload.club,clubName:model.clubSheet.name});
     // La fiche est lue à part : même présentation que le modèle (noms, logos, compétitions du pack actif).
     model.clubSheet=packs.projectExtra(model.clubSheet);
     return {id,ok:true,model:projectKnowledge(model)};
    }
    // Aperçu d'un club à la création (écran « Options de carrière ») : lecture seule, sans carrière requise,
    // rien n'est écrit ; meta.clubPreview est recalculé à chaque appel (native/engine/club-preview.cjs).
    if(command==='club_preview'){
     const champ=worldEditions.forMode('world-champ');
     if(!champ)throw Error('La carrière Monde est indisponible sur cette installation.');
     if(Object.keys(payload).some(k=>k!=='club')||!Number.isSafeInteger(payload.club))throw Error('Paramètres d’aperçu de club invalides : indique seulement l’identifiant du club (club).');
     if(!champ.playable.includes(payload.club))throw Error('Club inconnu : choisis un club du catalogue de la carrière Monde.');
     const priorPayload=ctx.nativePayload;ctx.nativePayload={club:payload.club,daily:options.dailyCalendar===true};
     let raw;try{raw=JSON.parse(run(clubPreview.VM_SOURCE));}finally{if(priorPayload===undefined)delete ctx.nativePayload;else ctx.nativePayload=priorPayload;}
     const model=projectKnowledge(snapshotRaw()),names=new Map((model.meta.champCatalogue||[]).map(c=>[c.id,c.name]));
     const packId=creation('world-champ');let pack=null;
     if(packId!=='base'){try{const selected=packs.get(packId);if(selected?.meta.databaseId===champRegistry.id)pack=selected;}catch{pack=null;}}
     model.meta.clubPreview=clubPreview.build({clubId:payload.club,raw,names:id=>names.get(id),pack,playerName:(p,id)=>mediaPacks.playerIdentity(p,id)?.name,
      patchLook:process.env.CD_PORTRAIT_CARRURE!=='0'?face=>portraitLooks.patch(face,true):null,registry:champRegistry});
     return {id,ok:true,model};
    }
    // Défis de départ (écran de création) : lecture seule, calculés sur le catalogue world-champ (defis-depart.cjs).
    if(command==='start_challenges'){
     if(Object.keys(payload).length)throw Error('Défis de départ : aucun paramètre attendu.');
     const model=projectKnowledge(snapshotRaw());model.meta.startChallenges=defisDepart.proposer(model.meta.champCatalogue);
     return {id,ok:true,model};
    }
    if(command==='epcr_preview'){const model=snapshotRaw();model.epcrPreparation=epcrPreparation.project(model,payload);return {id,ok:true,model:projectKnowledge(model)};}
    if(command==='pack_inspect'){packs.inspect(payload.path,edition(payload.mode??currentEdition()));return {id,ok:true,model:snapshot()};}
    if(command==='pack_install'){packs.install(payload.path,payload.digest,payload.mode===undefined?undefined:edition(payload.mode));return {id,ok:true,model:snapshot()};}
    if(command==='pack_select'&&payload.scope==='creation'){const mode=payload.mode??'common',databaseId=edition(mode),key=creationKey(mode),selected=payload.id==='base'?null:packs.get(payload.id);if(payload.id!=='base'&&!selected)throw Error('Pack non installé.');if(selected&&selected.meta.databaseId!==databaseId)throw Error('Pack incompatible avec cette édition.');const prior=store[key];try{store[key]=payload.id;if(journal)fullSave();else persist();}catch(e){if(prior===undefined)delete store[key];else store[key]=prior;throw e;}return {id,ok:true,model:snapshot()};}
    if(command==='league_benchmark'){
     // Banc d'essai de la machine pour la jauge de fluidité : lecture seule, sans carrière requise.
     // Résultat mis en cache dans un petit fichier du profil ; `refresh` relance la mesure.
     const machine={cores:payload.cores,memoryGb:payload.memoryGb};
     if(Object.keys(payload).some(k=>!['cores','memoryGb','refresh'].includes(k))||(payload.refresh!==undefined&&typeof payload.refresh!=='boolean')||Object.values(machine).some(x=>x!==undefined&&!(Number.isFinite(x)&&x>=0&&x<=4096)))throw Error('Paramètres de banc d’essai invalides.');
     const cacheFile=path.join(dataDir,'banc-essai.json');let bench=null;
     if(payload.refresh!==true){try{const cached=JSON.parse(fs.readFileSync(cacheFile,'utf8'));if(cached?.version===1&&cached.runtime===process.version&&cached.serialMs>0&&cached.computeMs>0)bench={...cached,cached:true};}catch{}}
     if(!bench){bench={...leagueDetail.benchmark(),runtime:process.version,measuredAt:new Date(clock).toISOString()};try{const temp=cacheFile+'.tmp-'+randomUUID();fs.writeFileSync(temp,JSON.stringify(bench));fs.renameSync(temp,cacheFile);}catch{}bench.cached=false;}
     const model=snapshotRaw();
     model.meta.leagueBenchmark={...bench,...machine,costs:leagueDetail.costTable({...machine,serialMs:bench.serialMs,computeMs:bench.computeMs})};
     return {id,ok:true,model:projectKnowledge(model)};
    }
    if(command==='export'){
      const model=snapshotRaw();let preuve=null;
      // Preuve de l'aller-retour (recettes, tests) : empreinte SHA-256 du texte de l'état exporté, avant toute réduction.
      // Un grand export est réduit sans perte (références de joueurs, marché) : son état littéral diffère alors de la
      // sauvegarde ; cette empreinte permet de comparer le texte exact du profil à l'état restitué sans affaiblir le contrôle.
      if(payload?.proof===true)ctx.nativeSaveProof=texte=>{preuve=createHash('sha256').update(texte,'utf8').digest('hex');};
      // Pendant un match : document de la carrière d'avant le coup d'envoi (reprise avant le match, voir preMatch).
      try{model.meta.exportText=saveDocumentText();}finally{delete ctx.nativeSaveProof;}
      if(preuve)model.meta.exportRoundTripSha256=preuve;
      return {id,ok:true,model:projectKnowledge(model)};
    }
    if(command==='shutdown'){const model=snapshotRaw();close();return {id,ok:true,model:projectKnowledge(model)};}
    if(command==='remove_checkpoint'){const receipt=profileSafety.remove(payload.id,payload.confirmed);const model=snapshotRaw();model.meta.profileSafetyReceipt=receipt;return {id,ok:true,model:projectKnowledge(model)};}
    if(command==='restore_checkpoint'){if(payload.confirmed!==true)throw Error('Confirmation explicite requise pour reprendre cette copie.');restoring=profileSafety.load(payload.id);command='import';payload={...payload,text:restoring.text};}
    const advancesCareer=PRESS_PROGRESSION.has(command)||command==='match_talk_continue'&&payload.phase==='post';
    updatePressPolicy();
    if(national.isNationalOnly()&&!NATIONAL_ONLY_COMMANDS.has(command))throw Error('Cette décision est réservée au manager d’un club.');
    if(ctx.nativeMandatoryPress&&advancesCareer)run('nativeSystems.domain("press").guardProgress()');
    mark('garde');
    // Copie d'annulation : le magasin ne contient que des chaînes (immuables), une copie superficielle
    // suffit ; l'état reprend le texte de la dernière sauvegarde quand la carrière n'a pas bougé depuis.
    const priorFromSave=cleanSave!==null&&store['bdt-v1']===cleanSave;
    if(priorFromSave&&verifyCleanCopy&&run('JSON.stringify(S)')!==cleanSave)throw Error('Copie d’annulation : la carrière a changé hors commande.');
    // Jour différé (voir dayDeferral) ; jour de « Continuer » (light) : ni sérialisé, ni copié avant lui. Un échec après
    // modification est repris par l'avance (retour au début de l'avance et rejeu des jours déjà passés).
    const dayAfter=dayDeferral&&command==='advance_day'&&!replay&&!restoring&&!resumeCheckpoint&&!coalescing,sessionDay=dayAfter&&light===true;
    let dayCheck=false;
    // Rejeu : pas de copie d'annulation (un échec reprend toute la reprise depuis le profil), sauf pour la délégation
    // qui la relit elle-même pendant la commande.
    const priorStateText=priorFromSave?cleanSave:sessionDay||replay&&command!=='delegate'?null:run('JSON.stringify(S)'),priorExtra=JSON.parse(run('JSON.stringify({playback:S?.live?playback(S.live):null,saveError:lastSaveError})'));
    const priorState=()=>({state:priorStateText===undefined?undefined:JSON.parse(priorStateText),...priorExtra});
    const priorStore=copyStore(store),priorSeed=seed,priorClock=clock;mark('copie_annulation');
    // Reprise avant le match : copie d'avant le coup d'envoi en cours (rétablie si la commande échoue).
    const preMatchBefore=preMatch,noticeBefore=matchResumeNotice,openBefore=matchOpenNow();let closesMatch=false;
    // Décision courante (n'avance pas le calendrier). En mode journal, elle n'est ni sérialisée ni validée ni écrite :
    // une ligne de journal suffit. Rejouée, elle suit le même chemin qu'à l'origine (l'adaptation de reprise éventuelle
    // n'existait pas encore quand elle a été prise).
    const lightDecision=!advancesCareer&&!SYNC_COMMANDS.has(command)&&!restoring&&(!resumeCheckpoint||!!replay);
    const defer=(journalMode||deferredCommits)&&lightDecision;let mutating=false;
    try{
     // Avance du calendrier (jour, clôture de semaine, coup d'envoi, saison) : la commande se termine toujours par
     // save() puis la validation (voir plus bas) ; les save() internes du moteur (fin de semaine, coup d'envoi…)
     // sérialisaient donc ~25 Mo pour rien. Ils sont différés comme pour une décision ; une lecture de la carrière
     // enregistrée pendant la commande la sérialise d'abord (storage.getItem).
     // Création : même règle, la commande se termine aussi par save() puis la validation complète.
     if(defer||(advancesCareer||command==='new_career')&&!restoring&&!resumeCheckpoint){deferringSave??=run('(function(){if(S&&!validatingStartup)lastSaveError=false;})');realSave=ctx.save;ctx.save=deferringSave;savesDeferred=true;}
     ctx.nativePayload=JSON.parse(JSON.stringify(payload));
     if(command==='new_career'){
      if(!legacyModes&&payload.mode!==WORLD_ONLY_MODE)throw Error('Seul le mode Monde est disponible pour une nouvelle carrière.');
      if(payload.varyCurrent!==undefined&&typeof payload.varyCurrent!=='boolean')throw Error('Option de variation du niveau actuel invalide.');
      if(payload.varyPotential!==undefined||payload.careerVariation!==undefined||payload.seed!==undefined)throw Error('Le potentiel varie à chaque nouvelle carrière ; paramètres de variation non autorisés.');
      if(payload.start!==undefined&&!repriseStarts.includes(payload.start))throw Error('Départ de partie invalide.');
      // Défi de départ : {id, club}, recalculé sur le catalogue (jamais repris tel quel du client).
      if(payload.challenge!==undefined){
       const ch=payload.challenge;if(!ch||typeof ch!=='object'||Array.isArray(ch)||Object.keys(ch).length!==2||typeof ch.id!=='string'||!Number.isInteger(ch.club))throw Error('Défi de départ invalide.');
       if(payload.mode!==WORLD_ONLY_MODE||payload.nationalRole==='nation'||ch.club!==payload.club)throw Error('Ce défi ne correspond pas au club choisi.');
       ctx.nativeDefi=defisDepart.trouver(projectKnowledge(snapshotRaw()).meta.champCatalogue,ch.id,ch.club);
       if(!ctx.nativeDefi)throw Error('Ce défi n’est pas proposé pour ce club.');
      }else delete ctx.nativeDefi;
     }
     if(command!=='new_career'&&command!=='import'&&!peek('!!S'))throw Error('Crée ou importe une carrière.');
     ctx.nativeCommand=command;
     if(managerPlanning.commands.includes(command))managerPlanning.validateRequest(snapshot(),command,payload);
     run("nativeSystems.domain('matchTalks').guard(nativeCommand,nativePayload);nativeSystems.domain('sceneInvitations').guard(nativeCommand,nativePayload);nativeSystems.domain('clubMeetings').guard(nativeCommand,nativePayload);");
     if(command==='next_season')national.checkSeason();
     // Avant-saison : avancer le calendrier du moteur ouvre d'abord la semaine 0 (17 août 2026).
     // À partir d'ici la commande peut modifier la carrière ; avant, un refus la laisse intacte (voir le catch).
     mutating=true;
     if(PRESEASON_OPENERS.has(command)&&run('!!CDPreseason.pending(S)'))run('CDPreseason.open(S)');
     if(BLOCKED_AFTER_RESULT.has(command)&&run('nativeDailyStatus()?.resultConfirmed===true'))throw Error('Résultat confirmé. Continue jusqu’à la clôture de la semaine.');
     if(command==='interclub_negotiate'||command==='academy_groups_preview'){
      ctx.nativeCommand=command;
      const extra=command==='academy_groups_preview'?{academyGroups:run('CDNativeAcademyGroups.preview(S)')}:run('nativeSystems.execute(nativeCommand,nativePayload)');
      if(run('JSON.stringify(S)')!==priorStateText||seed!==priorSeed||!sameStore(store,priorStore))throw Error('Une consultation ne peut pas modifier la carrière.');
      const model=snapshotRaw();Object.assign(model.meta,JSON.parse(JSON.stringify(extra)));return {id,ok:true,model:projectKnowledge(model)};
     }
     // Commande sans effet déclaré sur les joueurs (state-versions.cjs, playersUntouched) : ni progression des attributs
     // détaillés, ni connaissance nouvelle (aucun rapport, aucun départ, aucune observation). Les relevés d'avant
     // commande (qualités de tous les joueurs, registre de connaissance) sont sautés ; en mode vérification, ils sont
     // faits et toute progression ou connaissance constatée lève une erreur.
     const stablePlayers=sectionsOn&&!advancesCareer&&stateVersions.playersUntouched(command,payload)?(verifyProjection?'verify':'skip'):null;
     ctx.nativeKnowledgeBefore=stablePlayers==='skip'?null:run('nativeKnowledge.before(S)');ctx.nativeKnowledgeCommand=command;
     if(replay)clock=replay.k;else if(!restoring&&options.now===undefined)clock=Date.now();
     const liveOnly=command==='tick'||command==='delegate';
     const previousAcademyClub=command==='next_season'?run('S.club'):null;
     ctx.nativePressPrevious=advancesCareer?run('nativeSystems.domain("press").context(S)'):null;
     const advancesWithinWeek=command==='advance_day'&&run('(nativeDailyStatus()?.day??6)<6');
     // Commande sans effet déclaré sur les joueurs (state-versions.cjs) : attributs détaillés repris sans relever les
     // qualités (player-attributes.cjs, mode stable ; vérifié en mode vérification).
     ctx.nativeAttributeBaseline=advancesWithinWeek||['new_career','import'].includes(command)?null:run('nativeAttributeStore.before(S,'+liveOnly+','+(stablePlayers==='verify'?"'verify'":stablePlayers==='skip')+');');
     if(NATIONAL_COMMANDS.includes(command)){
      national.command(command,payload);
     }else if(command==='observe_player'){
      ctx.nativeKnowledgeReceipt=run(`nativeKnowledge.plan(S,nativePayload,{charge:amount=>ledgerEntry('Observation ciblée',-amount),message:(title,body)=>managerMessage(title,body,'recruitment','recruitment')})`);
     }else if(command==='population_enable'){
      if(payload.confirmed!==true||Object.keys(payload).some(k=>!['confirmed','context'].includes(k)))throw Error('Confirme explicitement la nouvelle politique de population.');
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
       const mode=payload.mode??'fiction',worldEdition=worldEditions.forMode(mode),selectedClub=payload.nationalRole==='nation'?0:payload.club;if(!worldEdition&&!['fiction','france','common'].includes(mode))throw Error('Mode de carrière invalide.');if(!Number.isInteger(selectedClub)||selectedClub<0||(worldEdition?!worldEdition.playable.includes(selectedClub):selectedClub>=(mode==='fiction'?14:30)))throw Error('Club invalide pour ce mode.');ctx.nativePayload.club=selectedClub;protectCurrent('nouvelle-carriere',priorSeed,priorClock);if(worldEdition){/* Rubrique « talents » du pack de création (potentiels relevés, joueurs ajoutés) : lue par CDWorldCareer.start, par identifiants seulement. */const talentPack=creation(mode)!=='base'?packs.get(creation(mode)):null;ctx.nativePackTalents=talentPack?.meta.databaseId===edition(mode)&&talentPack.talents?talentPack.talents:null;try{run('CDWorldCareer.start(nativePayload.club,nativePayload.mode,'+(options.dailyCalendar===true)+')');}finally{ctx.nativePackTalents=null;}}if(payload.detailedLeagues!==undefined){if(!worldEdition)throw Error('Championnats actifs : réservé à la carrière Monde.');run('CDLeagueDetail.create(S,nativePayload.detailedLeagues)');}else run("if(nativePayload.mode==='common')CDCommonCareer.start(nativePayload.club);else start(nativePayload.club,nativePayload.mode??'fiction')");if(ctx.nativeDefi)run(defisDepart.VM_APPLIQUER);if(worldEdition)run('nativeSystems.domain("clubStrategy").presidentObjective()');if((worldEdition||mode==='common')&&creation(mode)!=='base'){const selected=packs.get(creation(mode));if(!selected)throw Error('Pack de création absent ; réimporte-le ou choisis Base.');if(selected.meta.databaseId!==edition(mode))throw Error('Pack incompatible avec cette édition.');ctx.nativeBinding={id:selected.meta.id,digest:selected.meta.digest};run('S.identityPack=nativeBinding');}
      if(options.dailyCalendar)run('nativeEnableDailyCalendar()');
      if(run("typeof aiRosterPopulationActive==='function'&&aiRosterPopulationActive(S)"))run('CDStaffCareer.initialize(S)');
     }else if(command==='train'){
      const mode=payload.mode??run('S.training');if(!['normal','repos','intense'].includes(mode))throw Error('Entraînement invalide.');
      if(run("!!S.live||S.phase==='ended'"))throw Error('Entraînement indisponible pendant le match ou après la saison.');
      if(!run('S.trained')){ctx.nativeMode=mode;run('S.training=nativeMode;trainWeek()');}
     }else if(command==='auto_lineup'){
      if(run('!!S.live'))throw Error('Composition indisponible pendant un match.');run('autoLineup()');
     }else if(command==='advance_day'&&run('!!CDPreseason.pending(S)')){
      run('CDPreseason.advanceDay(S,nativePayload.fromDate)');
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
      if(payload.delegated!==undefined&&typeof payload.delegated!=='boolean')throw Error('Délégation du match invalide.');
      if(payload.espoirs!==undefined&&(!Array.isArray(payload.espoirs)||payload.espoirs.length<1||payload.espoirs.length>4||payload.reducedBench===true))throw Error('Appel d’espoirs invalide : jeunes à joindre à un match à 23.');
      if(payload.composition!==undefined&&(typeof payload.composition!=='boolean'||payload.delegated!==true))throw Error('Choix de composition invalide : à joindre à un match délégué.');
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
        // Match délégué : « Confier aussi la composition au staff » (cochée par défaut, mémorisée dans la
        // carrière). Cochée, le staff refait la feuille du jour (sélection automatique : autoLineup avant et
        // après l'entraînement, règle JIFF comprise) ; décochée, la feuille du joueur est inchangée.
        const nativeDelegation=nativePayload.delegated===true&&S.manager?.delegation?S.manager.delegation:null;
        const nativeStaffSheet=!!nativeDelegation&&(nativePayload.composition??nativeDelegation.matchLineup!==false);
        const nativeLineupFlag=nativeDelegation?.lineup;
        if(nativeDelegation){nativeDelegation.matchLineup=nativeStaffSheet;if(nativeStaffSheet)nativeDelegation.lineup=true;}
        // Match délégué : pas de causerie d'avant-match (la commande delegate qui suit confie tout le match).
        if(nativePayload.delegated===true)nativeSystems.domain('matchTalks').setDelegating(true);
        // Feuille incomplète : « Appeler un espoir » (jeunes choisis, places vides) ou « Jouer à 22 » (le staff n'appelle alors personne).
        const nativeEspoirs=nativeSystems.domain('espoirsMatch'),nativeAt22=nativePayload.reducedBench===true;
        if(Array.isArray(nativePayload.espoirs))nativeEspoirs.callUp(S,nativePayload.espoirs);
        // Plus de plancher de 40 pour le club joué (décision de Léo du 19/11/2026) : feuille encore incomplète au coup
        // d'envoi, sans choix du joueur (ni jeunes désignés, ni match à 22) : les meilleurs espoirs aptes du centre
        // montent pour ce match seulement (prêt espoirLoan, rendus au centre une fois la rencontre passée).
        // Sauf quand « Jouer à 22 » est ouvert (Nationale, pilier manquant) : ce choix reste au manager, et un coup
        // d'envoi sans réponse est refusé sans écriture (tests/native-nationale-reduced-bench.cjs).
        else if(!nativeAt22&&nativeProfessionalDepth.playedClubExempt(S)&&!(typeof CDNationaleReducedBench!=='undefined'&&CDNationaleReducedBench?.vacancy(S))){const nativeMontes=nativeEspoirs.callUpProposed(S);if(nativeMontes.length)managerMessage('Des espoirs montent pour le match',(nativeMontes.length>1?nativeMontes.length+' jeunes du centre de formation complètent':'Un jeune du centre de formation complète')+' la feuille de 23 pour ce match : '+nativeMontes.map(id=>S.clubs[S.club].players.find(p=>p.id===id)?.name).filter(Boolean).join(', ')+'. '+(nativeMontes.length>1?'Ils retourneront':'Il retournera')+' au centre après la rencontre.','staff','team');}
        if(nativeAt22)nativeEspoirs.setOff(true);
        // Blessure à la séance lancée par ce coup d'envoi (séance pas encore faite) : si un poste reste vide faute de pro
        // apte, le centre de formation complète la feuille (comme « Appeler un espoir ») et le coup d'envoi repart (séance
        // déjà faite). Sinon, les blessés du jour nomment le refus (message clair plus bas).
        const nativeSeanceAvant=!!S.trained,nativeBlessesAvant=new Set(S.clubs[S.club].players.filter(p=>p.injury>0).map(p=>p.id));
        globalThis.nativeSeanceBlesses=[];
        try{beginMatch(nativePayload.reducedBench===true);
         if(!S.live&&!nativeAt22&&!nativeSeanceAvant&&S.trained&&sheetErrors().length){
          globalThis.nativeSeanceBlesses=S.clubs[S.club].players.filter(p=>p.injury>0&&!nativeBlessesAvant.has(p.id)).map(p=>p.name+' ('+p.pos+')');
          if(nativeEspoirs.callUpProposed(S).length&&!sheetErrors().length)beginMatch(false);
         }
        }finally{if(nativeAt22)nativeEspoirs.setOff(false);if(nativePayload.delegated===true)nativeSystems.domain('matchTalks').setDelegating(false);if(nativeDelegation)nativeDelegation.lineup=nativeLineupFlag;}
       }finally{createRugbyMatch=nativeCreate;}
      }`);}finally{
       // VM timeouts skip its inner finally; restore without executing more VM code.
       ctx.createRugbyMatch=nativeCreate;
      }
      if(hadFixture&&!run('!!S.live')){const blesses=JSON.parse(run('JSON.stringify(globalThis.nativeSeanceBlesses||[])'));if(blesses.length&&!reducedBench)throw Error('Blessure à la séance d’avant-match : '+blesses.join(', ')+' forfait, aucun remplaçant au poste. Effectue d’abord la séance (Entraînement), puis complète la feuille (Composition).');}
      if(hadFixture&&!run('!!S.live'))throw Error(reducedBench?'La feuille à 22 a changé après la préparation. Vérifie la composition et l’entraînement.':'Coup d’envoi refusé : vérifie la feuille à 23 et le calendrier.');
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
      // Mémorise le choix « Confier aussi la composition au staff » pour les prochains matchs délégués
      // (la feuille du match en cours est déjà jouée : elle se règle au coup d'envoi, begin_match { delegated }).
      if(payload.composition!==undefined){if(typeof payload.composition!=='boolean')throw Error('Choix de composition invalide.');run('if(S.manager?.delegation)S.manager.delegation.matchLineup=nativePayload.composition;');}
      run("nativeSystems.domain('matchTalks').setDelegating(true);nativeSystems.domain('matchTalks').observe('delegate');nativeSystems.domain('matchDelegation').setActive(true);");
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
       deferredDelegateRead=false;seed=priorSeed;clock=delegateClock;store=copyStore(priorStore);ctx.nativePrior=priorState();
       run('S=nativePrior.state;if(S?.live&&nativePrior.playback)MATCH_PLAYBACK.set(S.live,nativePrior.playback);pendingSave=null;lastSaveError=nativePrior.saveError;');
       run(delegateLoop);
      }
      }finally{run("nativeSystems.domain('matchTalks').setDelegating(false);nativeSystems.domain('matchDelegation').setActive(false);");}
     }else if(command==='finish_round'){
      run('nativeConfirmMatchResult()');
     }else if(['advance_pacific_preparation','advance_japan_preparation','advance_champ_preparation'].includes(command)){
      if(run('S.worldMode?.day!==undefined'))throw Error('Utilise l’avance journalière pour cette préparation.');
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
      const beforeImport=protectCurrent(restoring?'restauration':'import',priorSeed,priorClock);
      if(restoring){seed=restoring.seed;clock=restoring.clock;}
      if(typeof beforeImport==='string')ctx.nativeBeforeImportText=beforeImport;
      try{run("if(!confirmSaveImport())throw Error('Import annulé : sauvegarde impossible.');normalizeAcademyPotential(S);");}
      finally{delete ctx.nativeBeforeImportText;}
      if(options.dailyCalendar)run('nativeEnableDailyCalendar()');
     }
     let extra=ctx.nativeKnowledgeReceipt??null;if(SYSTEM_COMMANDS.has(command)){ctx.nativeCommand=command;extra=run('nativeSystems.execute(nativeCommand,nativePayload)');}
     else if(['set_collective_focus','set_opponent_level','set_delegation','set_development_focus','promote_academy','scout_mission','set_lineup','set_tactics','set_penalty_policy','set_consignes','appliquer_staff','set_role_direct','cri','set_player_load','set_intensite_auto','appliquer_avis_kine','recruit','extend_contract','transfer_budget_extension','next_season','substitute','promote_cover','sale_list','sale_answer','precontract_offer'].includes(command)){ctx.nativeCommand=command;extra=run('nativeGestion(nativeCommand,nativePayload)');}
     if(command==='new_career'){
      run('CDNativeAcademyGroups.start(S)');
      ctx.nativeCreationVariation={version:1,seed:priorSeed,varyCurrent:payload.varyCurrent??true};
      run('nativeProfessionalDepth.fill(S);nativeCareerVariation.apply(S,nativeCreationVariation);nativeAttributeStore.complete(S);');
      // Budget de saison réaliste (salaires par niveau, budget du club, centre de formation) : activé par défaut
      // pour les carrières créées (décision de Léo du 13 novembre). CD_SALAIRES_PAR_NIVEAU=0 le coupe (tests,
      // comparaisons). Les carrières déjà commencées gardent leur économie : la marque S.startingSalaries ne se
      // pose qu'ici, à la création (voir docs/salaires-par-niveau-20261111.md, « Activation par défaut »).
      if(process.env.CD_SALAIRES_PAR_NIVEAU!=='0')run("if(budgetFrance()||budgetMonde()){nativeStartingSalaries.apply(S,budgetForces(),nativeLeagueEconomy,budgetLimites(true));[...S.economy.freeAgents,...S.market].forEach(budgetValeur);budgetOuvrir(true);}");
      run('autoLineup();');
      // Directions des clubs gérés : carrières mondiales nouvelles seulement ; CD_DIRECTIONS_CLUBS=0 les coupe.
      if(process.env.CD_DIRECTIONS_CLUBS!=='0')run('nativeClubDirections.create(S,nativeCreationVariation.seed)');
      delete ctx.nativeCreationVariation;
      // Début de carrière Monde : lundi 13 juillet 2026 (club seul ; les rôles de sélection gardent leur agenda).
      if(payload.nationalRole===undefined||payload.nationalRole==='club')run('CDPreseason.create(S)');
      // Départ de la partie (reprise.cjs) : juillet par défaut, date du club, ou veille de la 1re journée.
      // Sans « start » (outils, tests hérités, intégrations), la carrière s'ouvre comme avant, le 17 août,
      // sans préparation choisie : les séquences figées restent identiques. L'écran de création l'envoie toujours.
      ctx.nativeRepriseStart=payload.start??null;
      if(ctx.nativeRepriseStart&&run("CDWorldCareer.active(S)&&!!CDReprise.create(S,nativeRepriseStart)&&nativeRepriseStart==='veille'")){
       // Préparation gérée par le staff : semaines simulées jusqu'à la veille de la 1re rencontre.
       for(let i=0;i<12&&run("S.phase!=='ended'&&!S.live&&!nextMatch()");i++){run('finishRound();nativeSystems.domain("press").observeInvitation();');}
       run(`if(S.worldMode.day!==undefined){const f=CDWorldCareer.userFixture(S);for(let i=0;f&&i<7;i++){const d=CDWorldCareer.dailyStatus(S),today=CDWorldCareer.calendarToday(S);if(!d.canAdvance||new Date(Date.parse(today+'T00:00:00Z')+86400000).toISOString().slice(0,10)>=f.date)break;CDWorldCareer.advanceDay(S,today);}}`);
      }
      delete ctx.nativeRepriseStart;
     }
     else if(command==='next_season')run('CDNativeAcademyGroups.afterSeason(S,'+previousAcademyClub+');');
     if(command==='new_career'||command==='import')national.initialize(seed,command==='new_career'?payload:null);
     // Reprise choisie : le plan de la saison se fige dès que l'avant-saison s'achève (jour suivant, avance).
     run('if(S)CDReprise.sync(S)');
     updatePressPolicy();
     if(advancesCareer||command==='new_career'||command==='import')run('nativeSystems.domain("press").observeInvitation(nativePressPrevious,'+(command==='new_career')+');');
     ctx.nativeKnowledgeVerify=stablePlayers==='verify';
     run(`if(nativeKnowledge.observe(S,nativeKnowledgeBefore,nativeKnowledgeCommand,nativePayload,{observedPlayerIds:nativeKnowledgeCommand==='academy_center_scout'?(nativeSystems.domain('academyPathways').project().centers||[]).find(c=>c.id===nativePayload.centerId)?.candidates.map(p=>p.id)||[]:[]})&&nativeKnowledgeVerify)throw Error('Commande déclarée sans effet sur les joueurs : connaissance nouvelle ('+nativeKnowledgeCommand+').');`);
     run("nativeSystems.domain('matchTalks').observe(nativeCommand);nativeSystems.domain('sceneInvitations').observe(nativeCommand);nativeSystems.domain('clubMeetings').observe(nativeCommand,nativePayload);");
     // Météo du prochain match du club fixée dès la veille (world-career.cjs), quelle que soit la commande qui y
     // mène (jour suivant, fin d'avant-saison, reprise choisie, chargement) ; jamais pendant un match.
     run("if(S&&typeof CDWorldCareer!=='undefined'&&typeof CDWorldCareer.fixerMeteo==='function')CDWorldCareer.fixerMeteo(S);");
     // Courrier du club (club-mail.cjs) : une réception par jour de calendrier ; seule la boîte est écrite.
     // Prolongations confiées au directeur sportif (mars à juin) : décisions du jour, avant le courrier qui les annonce.
     run("if(typeof dsContratsObserver==='function')dsContratsObserver();if(typeof dsStaffObserver==='function')dsStaffObserver();");
     // Liste élite des Bleus et plans de doublon en attente (doublons.cjs) : avant le courrier qui s'en sert.
     run("nativeSystems.domain('doublons').observe();");
     // Fragilité des joueurs créés (fragilite.cjs) : tirée à la création, posée aussi sur les anciennes carrières.
     run("nativeSystems.domain('fragilite').observe();");
     // Familiarité au poste (familiarite-poste.cjs) : valeur de départ posée sur les joueurs créés et les anciennes carrières.
     run("nativeSystems.domain('familiarite').observe();");
     // Agents de joueurs nommés (agents-joueurs.cjs) : annuaire posé à la création et sur les anciennes carrières, relation
     // et caractère de l'agent repris des anciennes sauvegardes (S.tonAgent version 1 → 2).
     run("nativeSystems.domain('agentsJoueurs').observe();");
     // Règle « Auto » par forme (dist/development.js) : posée à la création et sur les anciennes carrières (clé toujours
     // présente : les lectures mémorisées de la projection restent valides d'une commande à l'autre).
     run("if(S&&typeof intensiteAutoValide==='function'&&!intensiteAutoValide(S.intensiteAuto))S.intensiteAuto=INTENSITE_AUTO_DEFAUT.slice();");
     // Relevé mensuel des qualités (releve-qualites.cjs) : premier relevé à la création et au chargement d'une ancienne carrière.
     run("nativeSystems.domain('releveQualites').observe();");
     // Rôle promis au contrat (role-contrat.cjs) : enregistré pour chaque nouveau contrat du club et, au premier passage,
     // pour les contrats des anciennes carrières ; jamais après une commande déclarée sans effet sur les joueurs.
     if(!stateVersions.untouched(command,payload).includes('clubs'))run("nativeSystems.domain('roleContrat').observe();");
     // Clause libératoire payée par un club géré (clauses-contrat.cjs) : période des mutations, une semaine tirée, rare.
     if(advancesCareer)run("nativeSystems.domain('clausesContrat').observe();");
     // Historique des blessures et tests de reprise d'avant-match (tests-physiques.cjs) : avant le courrier du médecin.
     run("nativeSystems.domain('testsPhysiques').observe();");
     run("nativeSystems.domain('clubMail').observe(nativeCommand);");
     // Réglage « Conférences ordinaires : envoyer l'adjoint » (press.cjs) : la conférence ordinaire qui vient de
     // s'ouvrir est tenue par Gabi dans la même commande, avant la sauvegarde ; « Jour suivant » et « Continuer »
     // ne s'arrêtent donc pas sur elle. Les grands moments restent obligatoires.
     if(advancesCareer&&ctx.nativeMandatoryPress)run('if(nativeSystems.domain("press").autoDelegate())nativeSystems.domain("clubMeetings").settleDelegatedPress();');
     if(savesDeferred){ctx.save=realSave;savesDeferred=false;realSave=null;}
     // Reprise avant le match : le coup d'envoi garde l'état d'avant lui (texte, graine, horloge) ; le match validé
     // (ou la carrière remplacée) le libère, et la carrière réelle est alors enregistrée en entier.
     if(matchResume){
      const openAfter=matchOpenNow();
      if(!openAfter){closesMatch=!!preMatch;preMatch=null;matchResumeNotice=null;}
      else if(!openBefore&&command==='begin_match'&&typeof priorStateText==='string')preMatch={seed:priorSeed,clock:priorClock,text:priorStateText,validated:false,committed:null};
      else if(command==='import'||command==='new_career'){preMatch=null;matchResumeNotice=legacyMatchNotice();}
     }
     mark('commande');
     // Décision regroupée (voir COALESCING) : sa validation stricte n'est pas sautée, même un jour de semaine.
     if(advancesWithinWeek){if(!sessionDay){run('save()');if(coalescing)run('nativeValidateSaved('+coalescing.full+')');if(memoDomains&&coalescing?.full!==true)run('nativeSectionsFresh=true');}}
     // Validation complète (sans reprise des sections) à la création, à l'import et à chaque fin de semaine ou
     // de saison ; entre deux, les sections dont le texte sauvegardé n'a pas changé ne sont pas reparcourues.
     else{run('budgetAvantProfondeur();nativeProfessionalDepth.fill(S);budgetProfondeur();nativeAttributeStore.complete(S,nativeAttributeBaseline,'+liveOnly+');');mark('completion');
      // Décision différée : seul l'effet visible de save() sur la projection (indicateur d'échec) est appliqué ici.
      if(defer)peek('if(S&&!validatingStartup)lastSaveError=false;');
      // Jour différé : validation stricte après la réponse ; le texte assemblé ici sert à la projection et à la copie
      // d'annulation de la commande suivante (jour de « Continuer » : texte assemblé une fois, à l'arrêt).
      else if(dayAfter){dayCheck=true;if(!sessionDay){run('save();');mark('serialisation');if(memoDomains)run('nativeSectionsFresh=true');}}
      else{run('save();');mark('serialisation');run('nativeValidateSaved('+(FULL_VALIDATION.has(command)||coalescing?.full===true)+')');unvalidated=false;
       // Validation partielle : elle ne modifie pas la carrière, le texte qui vient d'être assemblé sert à la projection.
       if(memoDomains&&!FULL_VALIDATION.has(command)&&coalescing?.full!==true)run('nativeSectionsFresh=true');}}
     mark('validation_sauvegarde');
     // Jour intermédiaire de « Continuer » (advance_until_event) : même jour, même sérialisation et même validation
     // que « Jour suivant » ; la projection pour l'interface et l'écriture du profil sont faites une fois, à l'arrêt.
     // Rejeu : l'état suffit, ni projection ni écriture (le journal décrit déjà cette commande).
     if(replay){if(defer)unvalidated=true;cleanSave=null;return {id,ok:true,light:true};}
     if(light){if(sectionsOn)run('nativeStateVersions.markDirty('+JSON.stringify(stateVersions.HEAVY)+')');if(journal)journalAppend(command,request.payload??{},priorSeed);cleanSave=!sessionDay&&typeof store['bdt-v1']==='string'?store['bdt-v1']:null;return {id,ok:true,light:true,check:dayCheck,deferred:sessionDay};}
     const model=snapshotRaw({command,payload});mark('projection');if(extra)Object.assign(model.meta,JSON.parse(JSON.stringify(extra)));
     if(journalMode){
      savedNow=false;
      // Décision : le texte de la carrière vient d'être assemblé pour la projection (sections à jour), il devient la
      // copie d'annulation en mémoire ; sa validation attend la prochaine sauvegarde complète.
      // Projection par sections (lot 19) : ce texte n'est plus assemblé par la projection ; la copie d'annulation est
      // faite après la réponse (flushStep), ou par la commande suivante si elle arrive avant.
      if(defer){if(sectionsOn)undoPending=true;else run('nativeSaveCurrent()');unvalidated=true;}
      let planned=null;
      if(dayAfter){
       // Jour différé : noté avant la réponse ; validation et sauvegarde complète due après (flushStep).
       const at={offset:journal.size(),count:journal.count()};journalAppend(command,request.payload??{},priorSeed);undoPending=false;
       const due=fullSaveDue();if(due)planned=dateKey();
       if(dayCheck)unvalidated=true;
       if(dayCheck||due)pendingCommit={command,day:true,stage:1,validate:dayCheck,save:due,journalAt:at,prior:{seed:priorSeed,clock:priorClock,store:priorStore,state:priorState,text:priorStateText,fromSave:priorFromSave}};
      }
      // Pendant un match (preMatch), rien n'est noté ; « Sauvegarder » écrit le profil d'avant le coup d'envoi. Le match
      // validé n'étant pas au journal, sa validation est suivie d'une sauvegarde complète.
      else if(closesMatch||(preMatch?SYNC_COMMANDS.has(command)||!!restoring:!defer&&(SYNC_COMMANDS.has(command)||restoring||resumeCheckpoint)||fullSaveDue())){fullSave();undoPending=false;}
      else journalAppend(command,request.payload??{},priorSeed);
      cleanSave=undoPending?null:typeof store['bdt-v1']==='string'?store['bdt-v1']:null;
      model.meta.autosave=autosaveMeta(planned);
     }else if(defer){
      pendingCommit={command,stage:0,full:FULL_VALIDATION.has(command),tick:command==='tick',prior:{seed:priorSeed,clock:priorClock,store:priorStore,state:priorState,text:priorStateText,fromSave:priorFromSave}};
      // La carrière en mémoire diffère désormais du texte enregistré : aucune copie d'annulation ne peut le reprendre.
      cleanSave=null;
     }else{
     // Advancing the presentation cursor can leave both the career and RNG
     // untouched. Keep the previous durable revision and its recovery copy.
     if(command==='tick'&&committedFiles&&seed===priorSeed&&sameStore(store,priorStore)&&profileFilesVersion()===committedFiles)clock=priorClock;
     else persist();
     // La sauvegarde vient d'être publiée : le texte enregistré décrit exactement la carrière en mémoire.
     cleanSave=typeof store['bdt-v1']==='string'?store['bdt-v1']:null;
     // La décision regroupée est écrite avec cette commande.
     if(coalescing&&pendingCommit===coalescing)pendingCommit=null;
     }
     mark('ecriture_disque');model.meta.profileSafety=profileSafety.project();if(restoring)model.meta.profileSafetyReceipt={command:'restore_checkpoint',id:restoring.id};
     continuePlan(model);
     const known=projectKnowledge(model);mark('connaissance');return {id,ok:true,model:known};
    }catch(error){
     preMatch=preMatchBefore;matchResumeNotice=noticeBefore;
     if(replay)throw error;
     // Refus avant toute modification (gardes, paramètres) : la carrière en mémoire est intacte ; pas de relecture
     // de son texte d'avant (~22 Mo). En vérification, l'égalité est contrôlée.
     if(!mutating&&error.storageFailure!==true&&!restoring&&command!=='new_career'&&command!=='import'){
      if(verifyCleanCopy||verifyProjection){if(run('JSON.stringify(S)')!==priorStateText)throw Error('Commande refusée après une modification de la carrière : '+command+'.');}
      seed=priorSeed;clock=priorClock;store=copyStore(priorStore);cleanSave=priorFromSave?priorStateText:null;
      run('nativeSystems.clearTransient('+(sectionsOn&&syncedAtStart)+');pendingSave=null;nativeSaveSections=null;');
      if(sectionsOn&&syncedAtStart)versionsSynced=true;
      throw error;
     }
     // Jour de « Continuer » sans copie d'annulation : l'avance reprend la carrière (advanceUntilEvent, restoreSession).
     if(sessionDay){error.sessionRestore=true;throw error;}
     seed=priorSeed;clock=priorClock;store=copyStore(priorStore);ctx.nativePrior=priorState();cleanSave=priorFromSave?priorStateText:null;run('nativeSystems.clearTransient('+(syncedAtStart&&sectionsOn&&error.storageFailure!==true)+')');ctx.nativePrior.saveError=ctx.nativePrior.saveError||error.storageFailure===true;
     run('S=nativePrior.state;if(S?.live&&nativePrior.playback)MATCH_PLAYBACK.set(S.live,nativePrior.playback);pendingSave=null;lastSaveError=nativePrior.saveError;nativeSaveSections=null;');
     if(syncedAtStart&&sectionsOn&&!error.storageFailure)run('nativeStateVersions.adopt()');
     throw error;
    }finally{if(savesDeferred){ctx.save=realSave;savesDeferred=false;realSave=null;}deferredDelegateActive=false;deferredDelegateRead=false;delete ctx.nativePayload;delete ctx.nativePrior;delete ctx.nativeMode;delete ctx.nativeCommand;delete ctx.nativeBinding;delete ctx.nativeAttributeBaseline;delete ctx.nativePressPrevious;delete ctx.nativeKnowledgeBefore;delete ctx.nativeKnowledgeCommand;delete ctx.nativeKnowledgeReceipt;delete ctx.nativeKnowledgeVerify;}
   }catch(error){
    if(replay)throw error;projectionCache.clear();
    if(error.sessionRestore)return {id,ok:false,model:null,sessionRestore:true,error:error.message};
    // Commande refusée sans effet (carrière rétablie telle qu'avant la commande, ou jamais modifiée) alors que
    // l'interface détient déjà le modèle de cet état : réponse légère (message + « rien n'a changé ») au lieu d'une
    // projection complète. Échec d'écriture, packs ou profil : modèle complet comme avant.
    if(lightErrors&&!closed&&!error.storageFailure&&!LIGHT_ERROR_EXCLUDED.has(request?.command)&&modelEpoch===epochBefore){stateEpoch=epochBefore;return lightError(id,error.message);}
    return {id,ok:false,model:closed?null:snapshot(),error:error.message};
   }
  }
  // « Continuer » jusqu'au prochain événement (native/engine/continuer.cjs) : une commande avance N jours, chacun
  // exactement comme « Jour suivant », et ne projette le modèle et n'écrit le profil qu'une fois, à l'arrêt.
  // Avec `partial` et `budgetMs`, la réponse arrive au bout du budget sans modèle ({progress}) : l'interface montre
  // la date et peut demander la suite ou l'arrêt ({stop:true}). Ces jours restent en mémoire (advanceSession) et sont
  // écrits avant toute autre commande, à la fermeture ou à l'arrêt : jamais perdus en fonctionnement normal.
  let advanceSession=null;
  // Arrêts suivants du même jour (continuer.arrets : arrêt principal puis éléments informatifs) : chaque nouvel appui
  // sur Continuer montre le suivant sans avancer ; en mémoire seulement (rien n'est écrit dans la carrière), oubliés
  // dès que la date change ou qu'une autre carrière est ouverte.
  let infoQueue=null;
  const advanceSignal=()=>JSON.parse(run('JSON.stringify('+continuer.SIGNAL_SOURCE+')'));
  // Prochain arrêt prévisible de « Continuer » (info-bulle du bouton) : rencontre du club, reprise de
  // l'entraînement ou rendez-vous en file. Lecture seule, seulement en calendrier journalier.
  const repriseDate=()=>run("(()=>{try{return CDReprise.project()?.club?.date??null}catch(e){return null}})()");
  var continueIgnore=[]; // var : lisible par continuePlan même pendant l'initialisation du pont.
  function continuePlan(model){
   if(!model?.meta?.calendarCadence)return;
   // Arrêts facultatifs ignorés par la dernière avance demandée (outils, essais) : aucun par défaut.
   try{const signal=advanceSignal();model.meta.continuePlan=continuer.plan(signal,repriseDate(),continueIgnore);model.meta.decisionsDue=signal?.decisions||[];mark('prochain_arret');}catch{delete model.meta.continuePlan;delete model.meta.decisionsDue;}
  }
  function finishAdvance(id,session,stop){
   stateEpoch++;
   try{
    const model=snapshotRaw({command:'advance_day',payload:{fromDate:session.lastFrom}});mark('projection');
    // Mode journal : chaque jour est déjà noté ; la sauvegarde complète n'a lieu qu'à la fin de l'avance, si la
    // fréquence choisie l'exige (jamais pendant les tranches).
    let planned=null;
    if(journalMode&&session.deferred){
     // Jours différés (dayDeferral) : la carrière est sérialisée une fois, ici (texte de la projection quand il est à
     // jour) ; la validation stricte (si une clôture ou un jour d'avant-saison est passé) et la sauvegarde complète due
     // suivent la réponse. Un échec ramène la carrière au jour de départ de l'avance (journal raccourci).
     run('nativeSaveCurrent()');savedNow=false;undoPending=false;const due=fullSaveDue();if(due)planned=dateKey();
     if(session.check)unvalidated=true;
     if(session.check||due){const start=session.start;pendingCommit={command:'advance_until_event',day:true,stage:1,validate:!!session.check,save:due,journalAt:session.journalAt,prior:{seed:start.seed,clock:start.clock,store:start.store,text:start.text,fromSave:start.fromSave,state:()=>({state:JSON.parse(start.text),playback:null,saveError:false})}};}
    }
    else if(journalMode){savedNow=false;if(fullSaveDue())fullSave();}else persist();mark('ecriture_disque');
    cleanSave=typeof store['bdt-v1']==='string'?store['bdt-v1']:null;
    const absorbed=session.absorbed||coalescing;if(absorbed&&pendingCommit===absorbed)pendingCommit=null;
    model.meta.advanceUntilEvent={days:session.days,from:session.from,to:model.meta.calendarToday??null,stop:stop??{kind:'arret',label:continuer.STOPS.arret.label,detail:null},pressDelegated:session.pressDelegated||0,queued:infoQueue?.stops.length||0};
    model.meta.profileSafety=profileSafety.project();if(journal)model.meta.autosave=autosaveMeta(planned);continuePlan(model);
    const known=projectKnowledge(model);mark('connaissance');return {id,ok:true,model:known};
   }catch(error){
    // Écriture impossible : la carrière revient au jour de départ, comme un « Jour suivant » refusé.
    if(pendingCommit?.day)pendingCommit=null;
    try{restorePrior({...session.start,state:()=>({state:JSON.parse(session.start.text),playback:null,saveError:true})});}catch{}
    // Les jours notés pendant cette avance sont retirés du journal : il décrit de nouveau la carrière en mémoire.
    if(journal&&session.journalAt){try{journal.truncate(session.journalAt.offset,session.journalAt.count);}catch(e){error.message+=' Journal non raccourci : '+e.message;}}
    projectionCache.clear();
    return {id,ok:false,model:closed?null:snapshot(),error:error.message};
   }
  }
  // Reprise d'une avance après un jour différé en échec : carrière du départ de l'avance, puis jours déjà passés rejoués
  // avec leur horloge et leur graine (comme au chargement du journal, dont leurs lignes restent valides).
  function restoreSession(session){
   restorePrior({...session.start,state:()=>({state:JSON.parse(session.start.text),playback:null,saveError:false})});
   const actions=session.actions||[];
   for(let i=0;i<actions.length;i++){
    const a=actions[i];seed=a.s>>>0;run('nativeSectionsFresh=false');projectionCache.clear();
    try{handleCommand({id:'continuer-'+(i+1),command:a.c,payload:a.p},false,a);}catch(error){restorePrior({...session.start,state:()=>({state:JSON.parse(session.start.text),playback:null,saveError:false})});session.days=0;return {ok:false,error:'Reprise impossible : '+error.message};}
    if(seed!==a.e){restorePrior({...session.start,state:()=>({state:JSON.parse(session.start.text),playback:null,saveError:false})});session.days=0;return {ok:false,error:'Reprise impossible : résultat différent.'};}
   }
   run('nativeSectionsFresh=false');if(sectionsOn)run('nativeStateVersions.reset()');run('save()');cleanSave=typeof store['bdt-v1']==='string'?store['bdt-v1']:null;
   return {ok:true};
  }
  function advanceUntilEvent(request){
   const id=request.id;let opts;
   try{
    if(closed)throw Error('Le moteur est fermé.');
    opts=continuer.validate(request.payload??{});
    if(!peek('!!S'))throw Error('Crée ou importe une carrière.');
   }catch(error){advanceSession=null;return {id:Number.isSafeInteger(id)||typeof id==='string'?id:null,ok:false,model:closed?null:snapshot(),error:error.message};}
   const started=performance.now(),session=advanceSession;advanceSession=null;continueIgnore=opts.ignorer;
   if(opts.stop){
    if(session&&session.days>0)return finishAdvance(id,session,{kind:'arret',label:continuer.STOPS.arret.label,detail:'Tu as arrêté l’avance.'});
    const model=snapshotRaw();model.meta.advanceUntilEvent={days:0,from:opts.fromDate,to:model.meta.calendarToday??null,stop:{kind:'arret',label:continuer.STOPS.arret.label,detail:'Tu as arrêté l’avance.'}};
    return {id,ok:true,model:projectKnowledge(model)};
   }
   let before=advanceSignal(),today=opts.fromDate,stop=null,n=0;
   // Arrêt suivant du même jour en attente : montré sans avancer ni rien écrire (plusieurs arrêts le même jour).
   const queued=!session&&infoQueue&&before?.today&&infoQueue.date===before.today?infoQueue.stops.shift():null;
   if(!session&&!queued)infoQueue=null;
   if(queued){
    if(!infoQueue.stops.length)infoQueue=null;
    const model=snapshotRaw();model.meta.advanceUntilEvent={days:0,from:opts.fromDate,to:model.meta.calendarToday??null,stop:queued,pressDelegated:0,queued:infoQueue?.stops.length||0};
    continuePlan(model);return {id,ok:true,model:projectKnowledge(model)};
   }
   const current=session||{days:0,from:opts.fromDate,lastFrom:null,repriseDate:repriseDate(),start:null};
   if(!current.start){
    const fromSave=cleanSave!==null&&store['bdt-v1']===cleanSave;
    current.start={seed,clock,store:copyStore(store),text:fromSave?cleanSave:run('JSON.stringify(S)'),fromSave};
    if(journal)current.journalAt={offset:journal.size(),count:journal.count()};
   }
   // Décision de préparation attendue aujourd'hui (reprise.cjs) : refus comme un rendez-vous obligatoire,
   // sans rien écrire ; « Jour suivant », lui, la confie au staff.
   if(current.days===0&&before?.decisions?.length)return {id,ok:false,model:snapshot(),error:continuer.decisionText(before.decisions)};
   for(;;){
    const seedBefore=seed,r=handleCommand({id,command:'advance_day',payload:{fromDate:today}},true);
    if(!r.ok){
     // Jour différé en échec après modification (sans copie d'annulation) : retour au début de l'avance et rejeu des
     // jours déjà passés, puis comme avant.
     if(r.sessionRestore){
      const replayed=restoreSession(current);
      if(!replayed.ok){if(current.days>0&&journal&&current.journalAt){try{journal.truncate(current.journalAt.offset,current.journalAt.count);}catch{}}return {id,ok:false,model:closed?null:snapshot(),error:r.error+' '+replayed.error};}
      if(current.days===0)return {id,ok:false,model:closed?null:snapshot(),error:r.error};
     }
     // Premier jour refusé : même réponse que « Jour suivant ». Plus tard : arrêt, les jours déjà passés sont écrits.
     if(current.days===0)return r;
     stop={kind:'blocage',label:continuer.STOPS.blocage.label,detail:r.error};break;
    }
    if(r.check)current.check=true;
    if(r.deferred){current.deferred=true;(current.actions??=[]).push({c:'advance_day',p:{fromDate:today},k:clock,s:seedBefore,e:seed});}
    current.days++;n++;current.lastFrom=today;
    // Décision en attente regroupée : sérialisée et validée avec le premier jour ; les jours suivants de la même
    // semaine retrouvent le chemin léger de « Jour suivant » (sans revalidation complète à chaque jour).
    if(coalescing){current.absorbed=coalescing;coalescing=null;}
    const after=advanceSignal();
    if(after&&before&&after.pressDelegated!==before.pressDelegated)current.pressDelegated=(current.pressDelegated||0)+1;
    const found=continuer.arrets(before,after,opts,current.repriseDate);stop=found.stop;
    before=after;today=after?.today;
    if(stop){infoQueue=found.queue.length&&today?{date:today,stops:found.queue}:null;break;}
    if(!today){stop={kind:'blocage',label:continuer.STOPS.blocage.label,detail:'Date de carrière indisponible.'};break;}
    if(n>=opts.maxDays||current.days>=continuer.MAX_DAYS){stop={kind:'limite',label:continuer.STOPS.limite.label,detail:'Avance interrompue après '+current.days+' jours sans événement.'};break;}
    if(opts.budgetMs>0&&performance.now()-started>=opts.budgetMs){
     if(opts.partial){
      // La décision regroupée fait partie des jours en mémoire : elle sera écrite avec eux (arrêt, fermeture ou
      // commande suivante), pas séparément entre deux tranches.
      if(current.absorbed&&pendingCommit===current.absorbed){pendingCommit=null;current.absorbed=null;}
      advanceSession=current;return {id,ok:true,model:null,progress:{from:current.from,today,days:current.days,next:after.next,plan:continuer.plan(after,current.repriseDate,opts.ignorer)}};}
     stop={kind:'limite',label:continuer.STOPS.limite.label,detail:'Avance interrompue après '+current.days+' jours sans événement.'};break;
    }
   }
   return finishAdvance(id,current,stop);
  }
  function handle(request){
   // Relevés différés non faits avant cette commande : abandonnés (la mémoire concernée sera recalculée directement).
   dropWarm();
   if(['new_career','import','restore_checkpoint','next_season','advance_day'].includes(request?.command))infoQueue=null;
   // « Continuer » interrompu par une autre commande : les jours déjà passés sont écrits d'abord.
   if(advanceSession&&request?.command!=='advance_until_event'){
    const session=advanceSession;advanceSession=null;
    const done=finishAdvance(null,session,null);
    if(!done.ok){const id=Number.isSafeInteger(request?.id)||typeof request?.id==='string'?request.id:null;return {id,ok:false,model:done.model,error:done.error};}
   }
   // Décision en attente : regroupée dans une commande écrite avant sa réponse, écrite d'abord sinon. Une commande
   // regroupée refusée laisse la décision en mémoire et en attente (sérialisation reprise du début).
   // Un jour différé n'est pas regroupé : sa validation et sa sauvegarde se terminent d'abord.
   coalescing=pendingCommit&&!pendingCommit.day&&deferredCommits&&!pendingFailure&&COALESCING.has(request?.command)&&!resumeCheckpoint?pendingCommit:null;
   if(coalescing){coalescing.stage=0;}
   else if(pendingCommit){const started=performance.now();flushCommit();lastFlushMs=performance.now()-started;}
   if(pendingFailure&&request?.command!=='shutdown'){
    const failure=pendingFailure;pendingFailure=null;projectionCache.clear();
    const id=Number.isSafeInteger(request?.id)&&request.id>=0||typeof request?.id==='string'&&request.id.length>0&&request.id.length<=100&&!/[\r\n]/.test(request.id)?request.id:null;
    return {id,ok:false,model:closed?null:snapshot(),error:failure.message};
   }
   pendingFailure=null;
   // Toute commande autre qu'une lecture peut modifier la carrière : le texte des sections n'est plus réputé à jour.
   if(!READ_ONLY.has(request?.command))peek('nativeSectionsFresh=false');
   const reading=request?.command==='snapshot';
   if(!reading)projectionCache.clear();
   allowProjectionCache=reading;
   try{
    const response=handleMeasured(request);
    if(response&&response.model&&!response[modelDelta.UNCHANGED])modelEpoch=stateEpoch;
    if(response?.timing){if(lastFlushMs)response.timing.ecriture_precedente=Math.round(lastFlushMs*10)/10;if(coalescing)response.timing.ecriture_regroupee=pendingCommit!==coalescing;}
    return response;
   }finally{if(coalescing&&pendingCommit===coalescing)coalescing.stage=0;coalescing=null;lastFlushMs=0;allowProjectionCache=false;if(!reading)projectionCache.clear();}
  }
  // Écriture de la décision en attente (boucle stdio : dès que la réponse est partie). Renvoie la durée en ms.
  const flush=()=>{if(!pendingCommit&&!undoPending&&!warmPending)return 0;const started=performance.now();flushCommit();return performance.now()-started;};
  const pending=()=>pendingCommit?pendingCommit.command:null;
  // Une étape de l'écriture en attente (boucle stdio) : vrai quand il ne reste rien à écrire.
  const flushNext=()=>flushStep();
  // Les tests réécrivent la ligne de retour ci-dessous : écriture différée exposée sur handle (handle.flush, handle.pending).
  Object.assign(handle,{flush,pending,flushStep:flushNext});
  // Reprise du journal au chargement : actions notées depuis la dernière sauvegarde complète, rejouées sur le profil
  // chargé avec leur horloge et leur graine ; la graine obtenue après chaque action doit être celle notée. Un journal
  // qui ne peut pas être repris n'est jamais effacé : il est conservé sous un autre nom et le joueur en est informé.
  function resumeJournal(){
   if(!journal)return;
   const hasProfile=fs.existsSync(file);
   if(profileError||!hasProfile){
    if(journal.exists()){const kept=journal.preserve('conserve');journalNotice={alert:true,text:'Journal de sauvegarde conservé sans reprise ('+kept+') : '+(profileError?'le profil doit d’abord être récupéré.':'aucun profil auquel l’appliquer.')};}
    return;
   }
   lastSavedKey=dateKey();
   const read=journal.read(loadedSha);
   if(read.status==='absent'||read.status==='vide'){journal.reset(loadedSha);return;}
   if(read.status!=='rejouer'){
    const kept=journal.preserve(read.status==='etranger'?'ecarte':'illisible');journal.reset(loadedSha);
    journalNotice={alert:true,text:read.status==='etranger'?'Journal de sauvegarde d’un autre état du profil, non repris ; il est conservé ('+kept+').':'Journal de sauvegarde illisible (ligne '+read.line+'), non repris ; il est conservé ('+kept+').'};
    return;
   }
   const actions=read.actions,started=performance.now();
   const base={seed,clock,store:copyStore(store),text:run('JSON.stringify(S)')};
   let reason='';
   const apply=count=>{
    for(let i=0;i<count;i++){
     const a=actions[i];seed=a.s>>>0;peek('nativeSectionsFresh=false');projectionCache.clear();
     try{handleCommand({id:'journal-'+(i+1),command:a.c,payload:a.p},false,a);}catch(error){reason=a.c+' : '+error.message;return i;}
     if(seed!==a.e){reason=a.c+' : résultat différent de celui noté';return i;}
    }
    return count;
   };
   let applied=apply(actions.length);
   if(applied<actions.length){
    // Action divergente : retour au profil chargé puis reprise des seules actions confirmées.
    restorePrior({...base,fromSave:false,state:()=>({state:JSON.parse(base.text),playback:null,saveError:false})});
    if(apply(applied)!==applied){restorePrior({...base,fromSave:false,state:()=>({state:JSON.parse(base.text),playback:null,saveError:false})});applied=0;}
   }
   // Ancien journal (avant la reprise avant le match) qui s'arrête en plein match : reprise jusqu'à la veille de son coup
   // d'envoi ; les lignes du match interrompu sont conservées à part, jamais effacées.
   let matchCut=null;
   if(matchOpenNow()){
    const kick=actions.slice(0,applied).map(a=>a.c).lastIndexOf('begin_match');
    if(kick>=0){
     restorePrior({...base,fromSave:false,state:()=>({state:JSON.parse(base.text),playback:null,saveError:false})});
     if(apply(kick)===kick&&!matchOpenNow())matchCut=kick;
     else{restorePrior({...base,fromSave:false,state:()=>({state:JSON.parse(base.text),playback:null,saveError:false})});if(apply(applied)!==applied){restorePrior({...base,fromSave:false,state:()=>({state:JSON.parse(base.text),playback:null,saveError:false})});applied=0;}}
    }
   }
   const kept=applied<actions.length?journal.preserve('non-rejoue'):matchCut!==null?journal.preserve('avant-match'):null;
   if(matchCut!==null){applied=matchCut;matchResumeNotice=PRE_MATCH_NOTICE;}
   journal.reset(loadedSha,actions.slice(0,applied));
   // Texte de la carrière reprise en mémoire (copie d'annulation de la prochaine commande, profil d'une écriture directe).
   // Actions rejouées sans projection : versions des sections de la carrière toutes relues à la projection suivante.
   projectionCache.clear();peek('nativeSectionsFresh=false');if(sectionsOn)run('nativeStateVersions.reset()');if(applied)run('save()');cleanSave=typeof store['bdt-v1']==='string'?store['bdt-v1']:null;
   const ms=Math.round(performance.now()-started);
   journalNotice=kept&&matchCut===null?{alert:true,replayed:applied,total:actions.length,ms,text:applied+' action'+(applied>1?'s':'')+' sur '+actions.length+' reprise'+(applied>1?'s':'')+' depuis le journal de sauvegarde ; la suite n’a pas pu être rejouée ('+reason+' ; journal conservé : '+kept+').'}
    :{alert:false,replayed:applied,total:actions.length,ms,text:applied+' action'+(applied>1?'s':'')+' reprise'+(applied>1?'s':'')+' depuis le journal de sauvegarde après un arrêt imprévu.'};
  }
  resumeJournal();
  if(!matchResumeNotice&&!profileError)matchResumeNotice=legacyMatchNotice();
  // Harnais de tests en processus (tests/monde-harness.cjs) : accès direct à la VM de la carrière.
  // Jamais exposé par le protocole stdio (options fixées par le code appelant).
  if(options.testVm===true)return {handle,close,flush,pending,vm:{ctx,run:(source,timeout=180000)=>vm.runInContext(source,ctx,{timeout}),seed:()=>seed,setSeed:value=>{seed=value>>>0;},store:()=>store}};
  return {handle,close};
 }catch(e){close();throw e;}
}
module.exports={createBridge,nationalFacts,applicationRoot,IMPORT_LIMIT_BYTES,REQUEST_LIMIT_BYTES,WORLD_IMPORT_LIMIT_BYTES,WORLD_REQUEST_LIMIT_BYTES,EXTENDED_IMPORT_LIMIT_BYTES,EXTENDED_REQUEST_LIMIT_BYTES,CHAMP_IMPORT_LIMIT_BYTES,CHAMP_REQUEST_LIMIT_BYTES,CORE_FILES:Object.freeze([...MODULES])};
if(require.main===module){
 let bridge,bridgeOptions;
 // Plusieurs carrières (native/engine/career-slots.cjs) : ranger, rouvrir, supprimer, moteur fermé puis relancé.
 const careerSlotCommand=request=>require('./career-slots.cjs').command(request,{get bridge(){return bridge;},set bridge(value){bridge=value;},options:bridgeOptions,create:createBridge});
 try{const rawSeed=process.env.CD_GODOT_SEED;let seed;if(rawSeed!==undefined){seed=Number(rawSeed);if(!/^(0|[1-9]\d*)$/.test(rawSeed)||!Number.isInteger(seed)||seed<0||seed>0xffffffff)throw Error('CD_GODOT_SEED doit être un entier entre 0 et 4294967295.');}const index=process.argv.indexOf('--data-dir');/* Match en temps forts : mode de base du jeu. Repli sur le direct d'origine : CD_MATCH_TEMPS_FORTS=0. */const niveauTempsForts=process.env.CD_MATCH_TEMPS_FORTS==='0'?null:(process.env.CD_MATCH_TEMPS_FORTS_NIVEAU||'dynamique');bridgeOptions={dailyCalendar:true,mandatoryPress:true,internationalCareer:true,deferredCommits:true,journal:true,lightErrors:true,...(process.argv.includes('--events')||process.env.CD_EVENTS==='1'?{onEvent:e=>{try{process.stderr.write('CD_EVENT '+JSON.stringify(e)+'\n');}catch{}}}:{}),...(niveauTempsForts?{matchHighlights:niveauTempsForts}:{}),...(seed===undefined?{}:{seed}),dataDir:index>=0?process.argv[index+1]:path.join(process.env.LOCALAPPDATA||require('node:os').homedir(),'CadrageDebordement','PrototypeGodot')};bridge=createBridge(bridgeOptions);}
 catch(e){process.stdout.write(JSON.stringify({id:null,ok:false,model:null,error:e.message})+'\n');process.exitCode=1;return;}
 const input=readline.createInterface({input:process.stdin,crlfDelay:Infinity}),delta=require('./model-delta.cjs').createEncoder();
 input.on('line',line=>{
  // L'interface Godot annonce la révision du modèle qu'elle détient : réponse différentielle.
  let result,base=null;try{const bytes=Buffer.byteLength(line);if(bytes>CHAMP_REQUEST_LIMIT_BYTES)throw Error('Message trop volumineux.');const request=JSON.parse(line);if(bytes>REQUEST_LIMIT_BYTES){if(request.command!=='import'||typeof request.payload?.text!=='string'||Buffer.byteLength(request.payload.text,'utf8')>CHAMP_IMPORT_LIMIT_BYTES)throw Error('Message trop volumineux.');const state=JSON.parse(request.payload.text)?.state,edition=worldEditions.forState(state);if(!edition||bytes>edition.limits.requestBytes||Buffer.byteLength(request.payload.text,'utf8')>edition.limits.saveBytes)throw Error('Message trop volumineux.');}if(Number.isSafeInteger(request?.base))base=request.base;if(request?.command==='career_slots'){result=careerSlotCommand(request);if(result.reopened&&base!==null)base=-1;}else result=bridge.handle(request);}catch(e){result={id:null,ok:false,model:null,error:e.message};}
  // La réponse part d'abord ; la décision courante en attente est écrite ensuite, pendant que l'interface affiche.
  // Par étapes (voir flushStep) : une commande arrivée entre deux étapes est lue sans attendre la fin de l'écriture.
  const step=()=>{let done=true;try{done=bridge.handle.flushStep();}catch{}if(!done)setImmediate(step);};
  process.stdout.write((base===null?JSON.stringify(require('./model-delta.cjs').materialize(result)):delta.encode(result,base))+'\n',()=>setImmediate(step));if(result.ok&&line&&JSON.parse(line).command==='shutdown'){input.close();process.stdin.destroy();}
 });
 input.on('close',()=>bridge.close());process.on('exit',()=>bridge.close());
}

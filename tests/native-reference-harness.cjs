'use strict';
process.env.CD_MODES_HERITES='1'; // Anciens modes de carrière (non-Monde) : test à migrer vers le mode Monde.
// Référence directe du moteur natif : même manifeste et hooks, sans protocole,
// createBridge, profil disque ni projection de sauvegarde.
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const {CORE_FILES}=require('../native/engine/worker.cjs');
const systems=require('../native/engine/native-systems.cjs');
const playerKnowledge=require('../native/engine/player-knowledge.cjs');
const common=require('../native/engine/common-rosters.cjs');
const careerVariation=require('../native/engine/career-variation.cjs');
const positionAptitudes=require('../native/engine/position-aptitudes.cjs');
const potentialEvolution=require('../native/engine/potential-evolution.cjs');
const inSeasonDevelopment=require('../native/engine/in-season-development.cjs');
const professionalDepth=require('../native/engine/professional-depth.cjs');
const playerAttributes=require('../native/engine/player-attributes.cjs');
const staff=require('../native/engine/staff.cjs');
const model=require('../native/engine/model.cjs');
const staffDatabaseIds=['world-registry','world-pacific-extension','world-japan-extension','world-nationale-extension','world-champ-extension']
 .map(name=>require('../native/engine/'+name+'.json').id);
function context({seed:initialSeed=827381,now=1700000000000,dataDir='',beforePositionHooks}={}){
 let seed=initialSeed>>>0,calls=0;
 const math=Object.create(Math);math.random=()=>{calls++;seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296;};
 class EngineDate extends Date{constructor(...args){super(...(args.length?args:[now]));}static now(){return now;}}
 const store={},storage={offline:true,directory:dataDir,getItem:key=>store[key]??null,setItem:(key,value)=>{store[key]=String(value);},removeItem:key=>{delete store[key];}};
 const element={innerHTML:'',textContent:'',style:{}};
 const ctx=vm.createContext({console:{log(){},warn(){},error(){}},Intl,Math:math,Date:EngineDate,Set,JSON,CDNativeHeadless:true,document:{querySelector:()=>element},window:{CDNativeHeadless:true,CDOfflineStorage:storage,CDOfflineError:true},localStorage:storage,setTimeout:()=>0,clearTimeout(){},setInterval:()=>0,clearInterval(){},nativeDataDirectory:dataDir});
 const run=source=>vm.runInContext(source,ctx,{timeout:15000});
 run(`const nativeCareerVariation=(${careerVariation.toString()})();`);
 ctx.nativeKnowledgeValidate=playerKnowledge.factory().validate;
 ctx.nativePotentialEvolutionValidate=potentialEvolution().validate;
 for(const name of CORE_FILES)run(fs.readFileSync(path.resolve(__dirname,'../dist',name),'utf8'));
 // Test-only source overlay: both variants still receive the production wrappers.
 if(beforePositionHooks!==undefined){if(typeof beforePositionHooks!=='string')throw new TypeError('beforePositionHooks must be JavaScript source');run(beforePositionHooks);}
 run(`const nativePositionAptitudes=(${positionAptitudes.toString()})();nativePositionAptitudes.installHooks();`);
 run(`const nativeProfessionalDepth=(${professionalDepth.toString()})();const nativeAttributeStore=(${playerAttributes.toString()})();const nativePlayerAttributes=p=>({...nativeAttributeStore.project(p),...nativePositionAptitudes.project(p)});`);
 run(`render=()=>{};toast=()=>{};startTimer=()=>{};save=()=>{if(S&&!validatingStartup){gameStorage.setItem('bdt-v1',JSON.stringify(S));lastSaveError=false;}};validatingStartup=false;const CDCommonCareer=(${common.toString()})();`);
 // Même copie des sources de référence que le vrai worker, avant les hooks.
 ctx.nativeStaffCareerSourcesText=JSON.stringify(Object.fromEntries([run('CDCommonRosters.id'),...staffDatabaseIds]
  .map(id=>[id,staff.forDatabase(id).registry.clubs])));
 run(systems.bootstrap());delete ctx.nativeStaffCareerSourcesText;
 run(`const nativeInSeasonDevelopment=(${inSeasonDevelopment.toString()})();nativeInSeasonDevelopment.installHooks();const nativePotentialEvolution=(${potentialEvolution.toString()})();nativePotentialEvolution.installHooks();`);
 run(`const nativeKnowledge=(${playerKnowledge.factory.toString()})();nativeKnowledge.installHooks();const baseKnowledgeValidator=validateCareer;validateCareer=state=>{const result=baseKnowledgeValidator(state);nativeKnowledge.validate(state);return result;};`);
 run(`const nativeReferenceModel=(${model.toString()});
  function nativeReferenceGuard(command,payload){
   nativeSystems.domain('matchTalks').guard(command,payload);
   nativeSystems.domain('sceneInvitations').guard(command,payload);
   nativeSystems.domain('clubMeetings').guard(command,payload);
  }
  function nativeReferenceObserve(command,payload){
   nativeSystems.domain('matchTalks').observe(command);
   nativeSystems.domain('sceneInvitations').observe(command);
   nativeSystems.domain('clubMeetings').observe(command,payload);
  }
  function nativeReferenceProject(){const value=nativeReferenceModel();value.clubLife=nativeSystems.project();return value;}
 `);
 const project=()=>JSON.parse(run('JSON.stringify(nativeReferenceProject())'));
 // Explicit accepted-command lifecycle for parity tests. Raw run() remains
 // available for isolated domain fixtures and does not silently settle rooms.
 function command(name,payload={},source){
  if(['snapshot','export','shutdown'].includes(name))return project();
  const previous=run('JSON.stringify({state:S,playback:S?.live?playback(S.live):null,saveError:lastSaveError})');
  const previousStore={...store},previousSeed=seed,previousCalls=calls;
  ctx.nativeCommand=name;ctx.nativePayload=JSON.parse(JSON.stringify(payload));
  ctx.nativeReferenceAttributeBaseline=name==='new_career'?null:run('S?nativeAttributeStore.before(S,'+(['tick','delegate'].includes(name))+'):null');
  ctx.nativeReferencePressPrevious=['begin_match','finish_round'].includes(name)?run('nativeSystems.domain("press").context(S)'):null;
  ctx.nativeReferenceCreationSeed=previousSeed;
  const operations={
   new_career:"if(nativePayload.mode==='common')CDCommonCareer.start(nativePayload.club);else if(nativePayload.mode==='france')CDFranceCareer.start(nativePayload.club);else start(nativePayload.club,nativePayload.mode??'fiction');if(typeof aiRosterPopulationActive==='function'&&aiRosterPopulationActive(S))CDStaffCareer.initialize(S);",
   train:"if(!['normal','repos','intense'].includes(nativePayload.mode??S.training))throw Error('Entraînement invalide.');if(S.live||S.phase==='ended')throw Error('Entraînement indisponible.');if(!S.trained){S.training=nativePayload.mode??S.training;trainWeek();}",
   auto_lineup:"if(S.live)throw Error('Composition indisponible.');autoLineup();",
   begin_match:`if(S.live||S.phase==='ended')throw Error('Aucun nouveau match disponible.');{
    const hadFixture=!!nextMatch(),nativeCreate=createRugbyMatch;
    try{createRugbyMatch=(pair,legacy=null,automated=false,preparation=null)=>{
     if(!legacy&&!automated&&pair.includes(S.club)&&typeof CDFranceCareer!=='undefined'&&typeof CDFranceCareer.ensureAISheet==='function'&&typeof aiRosterActive==='function'&&aiRosterActive()&&!(typeof CDFranceCompetition!=='undefined'&&CDFranceCompetition.active(S)))for(const ci of pair)CDFranceCareer.ensureAISheet(S.clubs[ci]);
     return nativeCreate(pair,legacy,automated,preparation);
    };beginMatch();}finally{createRugbyMatch=nativeCreate;}
    if(hadFixture&&!S.live)throw Error('Coup d’envoi refusé.');
   }`,
   tick:"if(!S.live)throw Error('Aucun match en cours.');if(!Number.isInteger(nativePayload.steps??1)||(nativePayload.steps??1)<1||(nativePayload.steps??1)>120)throw Error('Nombre de pas invalide.');for(let i=0;i<(nativePayload.steps??1);i++)tick();",
   pause:"if(!S.live)throw Error('Aucun match en cours.');if(nativePayload.paused!==undefined&&typeof nativePayload.paused!=='boolean')throw Error('Pause invalide.');if(nativePayload.paused===false)continueMatch();else pauseMatch();",
   delegate:"if(!S.live)throw Error('Aucun match à déléguer.');nativeSystems.domain('matchTalks').setDelegating(true);try{nativeSystems.domain('matchTalks').observe('delegate');for(let steps=0;!S.live.finished;steps++){if(steps>=3000)throw Error('Limite de délégation atteinte.');if(S.live.paused)continueMatch();else tick();}}finally{nativeSystems.domain('matchTalks').setDelegating(false);}",
   finish_round:"if(!(S.phase!=='ended'&&(S.live?.finished||!S.live&&!nextMatch())))throw Error('Terminez le match avant de valider la journée.');finishRound();",
   save:''
  };
  try{
   run('nativeReferenceGuard(nativeCommand,nativePayload)');
   run(source??operations[name]??'nativeSystems.execute(nativeCommand,nativePayload)');
   if(name==='new_career')run('CDNativeAcademyGroups.start(S);nativeProfessionalDepth.fill(S);nativeCareerVariation.apply(S,{version:1,seed:nativeReferenceCreationSeed,varyCurrent:nativePayload.varyCurrent??true});nativeAttributeStore.complete(S);autoLineup();nativeSystems.domain("press").observeInvitation(null,true);');
   else if(['begin_match','finish_round'].includes(name))run('nativeSystems.domain("press").observeInvitation(nativeReferencePressPrevious,false);');
   run('nativeProfessionalDepth.fill(S);nativeAttributeStore.complete(S,nativeReferenceAttributeBaseline,'+(['tick','delegate'].includes(name))+');');
   run('nativeReferenceObserve(nativeCommand,nativePayload);save();validateCareer(S)');
   return project();
  }catch(error){
   seed=previousSeed;calls=previousCalls;
   for(const key of Object.keys(store))delete store[key];Object.assign(store,previousStore);
   ctx.nativeReferencePrior=JSON.parse(previous);
   run('nativeSystems.clearTransient();S=nativeReferencePrior.state;if(S?.live&&nativeReferencePrior.playback)MATCH_PLAYBACK.set(S.live,nativeReferencePrior.playback);pendingSave=null;lastSaveError=nativeReferencePrior.saveError;');
   throw error;
  }finally{delete ctx.nativePayload;delete ctx.nativeCommand;delete ctx.nativeReferencePrior;delete ctx.nativeReferenceAttributeBaseline;delete ctx.nativeReferencePressPrevious;delete ctx.nativeReferenceCreationSeed;}
 }
 return {ctx,store,run,project,command,randomState:()=>({seed,calls})};
}
module.exports={context};

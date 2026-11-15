'use strict';
// Compatibilité de DONNÉES des composants Espoirs historiques. Aucune carrière
// à14clubs n'est créée, simulée, sauvegardée ou importée par ce helper.
const assert=require('node:assert/strict');
const {engineContext}=require('../harness.cjs');
let worldBaseline=null;
function worldFixture(){
 if(!worldBaseline){const h=engineContext();h.start(0);const cp=h.checkpoint();worldBaseline={state:JSON.parse(cp.text),text:cp.text,seed:cp.seed};return h;}
 // Tous ces cas utilisent la même graine827381 : reprise explicite et indépendante
 // d'une création World réellement effectuée, sans tester la variabilité de création.
 const h=engineContext(worldBaseline.state);h.setSeed(worldBaseline.seed);
 assert.ok(h.run('JSON.stringify(S)')===worldBaseline.text,'la reprise conserve exactement le point World partagé');
 assert.equal(h.seed(),worldBaseline.seed);return h;
}
function componentContext({planning=false,data=null,prepareWorld=null,management=false,worldData=false,annualData=false,aiV1Market=false,club=0}={}){
 assert.ok(!annualData||worldData,'les composants annuels complets exigent la copie116');
 const h=worldData?engineContext():worldFixture();if(worldData)h.start(club);if(prepareWorld)prepareWorld(h);h.run('save()');
 const healthy=h.checkpoint(),disk=h.store['bdt-v1'];
 assert.equal(h.run('S.worldMode.version'),5);assert.equal(h.run('S.clubs.length'),116);
 assert.equal(h.run('S.development.academy.length'),60);
 assert.equal(h.run('nativeSystems.domain("academyPathways").project().available'),false);
 assert.throws(()=>h.command('academy_activate',{confirmed:true,context:{season:1,week:0,club:0}}),/pas encore disponibles/);
 assert.ok(h.run('JSON.stringify(S)')===healthy.text,'le refus du composant historique conserve World');
 assert.ok(h.store['bdt-v1']===disk,'le refus conserve la vraie sauvegarde');
 // Le document sain passe toujours par le vrai codec de carrière Monde.
 h.run('parseSaveDocument(JSON.stringify(createSaveDocument()))');
 h.run(`if(${worldData})globalThis.componentData=JSON.parse(JSON.stringify(S));else {
  const clubs=S.clubs.slice(0,14).map(c=>{
   const sheet=buildSheet(c),ids=new Set([...sheet.lineup,...sheet.bench]);
   const players=c.players.filter(p=>ids.has(p.id));
   for(const p of c.players)if(players.length<30&&!ids.has(p.id)){players.push(p);ids.add(p.id);}
   return {...c,players};
  });
  globalThis.componentData={club:0,season:1,round:0,phase:'league',live:null,trained:false,
   clubs:JSON.parse(JSON.stringify(clubs)),lineup:S.lineup.slice(),reserves:S.reserves.slice(),news:[],
   economy:{version:1,week:0,talks:{},listings:{},offers:[],transfers:[],freeAgents:[],settled:0},market:[],
   development:{version:1,academyPotentialVersion:1,academy:POS.map((_,i)=>academyPlayer(0,i,1,i)),intakeSeason:1,rolledSeason:0,retired:[]},
   aiRosterVersion:1,aiRoster:{version:1,academies:clubs.slice(1).map(c=>({clubId:c.id,intakeSeason:1,players:POS.map((_,i)=>academyPlayer(c.id,i,1,300+i))})),reports:[],events:[],lastIntake:1,lastContracts:0,lastRecruitment:null}};
 }
 if(${planning}){
  componentData.worldVersion=S.worldVersion;componentData.worldManagement={...JSON.parse(JSON.stringify(S.worldManagement)),clubInfo:JSON.parse(JSON.stringify(S.worldManagement.clubInfo.slice(0,14))),matches:[],yearbook:[]};
  if(${management}){componentData.integratedManagementVersion=S.integratedManagementVersion;componentData.careerManagement=JSON.parse(JSON.stringify(S.careerManagement));}
  componentData.manager=JSON.parse(JSON.stringify(S.manager));componentData.schedule=schedule();componentData.history=[];componentData.ledger=[];
  componentData.tactic=S.tactic;componentData.defence=S.defence;componentData.training=S.training;componentData.morale=S.morale;componentData.trust=S.trust;
  const pool=JSON.parse(JSON.stringify(S.market.slice(0,9)));
  for(const p of pool){p.salary=Math.max(1000,Math.round((p.rating-45)*280));p.dev.retireAge=Math.max(p.dev.retireAge,p.age+8);}
  componentData.market=pool;componentData.economy={...JSON.parse(JSON.stringify(S.economy)),freeAgents:pool};
  for(const key of ['recruitmentIntelVersion','developmentFocusVersion','salaryDemandVersion','satisfactionVersion','relationsVersion','objectivesVersion'])if(S[key]!==undefined)componentData[key]=S[key];
  for(const c of componentData.clubs)for(const p of c.players)p.dev.retireAge=Math.max(p.dev.retireAge,p.age+8);
 }
 S=componentData;delete globalThis.componentData;
 // Les transitions ci-dessous sont celles des COMPOSANTS publics ; aucun cycle
 // de carrière principale, budget, résultat senior ou calendrier World n'est appelé.
 globalThis.componentYear=function(){
  if(S.worldMode||S.phase!=='ended'||S.live)throw Error('Transition de composant hors fixture annuelle');
  const year=S.season,tracked76=!!S.v76Scouting,tracked77=!!S.v77Promotions,tracked78=!!S.v78to81;
  if(tracked78&&!CDEspoirsPathwaysV78V81.returnLoans(S))throw Error('Retour de prêt refusé');
  CDEspoirsV73.advance(S);CDEspoirsAccessionV74.advance(S);
  const choice=CDEspoirsMovementV75.candidates(S),shot=choice?CDEspoirsMovementV75.snapshot(S,choice):null;
  CDEspoirsV73.closeSeason(S);CDEspoirsAccessionV74.closeSeason(S);
  const seen=new Set();
  for(const p of [...S.development.academy,...S.clubs.flatMap(c=>c.players)])if(!seen.has(p.id)){seen.add(p.id);ageDevelopmentPlayer(p,year);}
  S.season++;S.round=0;S.phase='league';S.trained=false;
  if(!choice||!shot||!CDEspoirsMovementV75.transfer(S,choice,shot))throw Error('Transition de compétition pure refusée');
  CDEspoirsV73.setup(S);CDEspoirsAccessionV74.setup(S);CDEspoirsMovementV75.sync(S);
  if(tracked76)CDEspoirsScoutingV76.ensure(S);
  if(tracked77)CDEspoirsProV77.ensure(S);
  if(tracked78)CDEspoirsPathwaysV78V81.year(S,year);
 };
 globalThis.componentPlanningYear=function(){
  if(S.worldMode)throw Error('Échantillon de projection hors données de compatibilité');
  const seen=new Set();for(const p of [...S.clubs.flatMap(c=>c.players),...S.development.academy,...S.market])if(!seen.has(p.id)){seen.add(p.id);ageDevelopmentPlayer(p,S.season);if(Number.isInteger(p.contractEnd))p.contractEnd++;}
  S.season++;S.round=0;S.phase='league';S.trained=false;intakeYouth();autoLineup();S.clubs[S.club].cash=CDFinancePlanning.forecast({cash:S.clubs[S.club].cash,weeklyWages:0,oneOffIncome:FORECAST_SEASON_FUNDING,weeks:1}).finalBalance;
 };
 globalThis.componentDocument=function(){nativeSystems.domain('academyPathways').validate(S);if(${planning})validateManager(S);return {state:JSON.parse(JSON.stringify(S))};};
 globalThis.componentParse=function(text){const doc=JSON.parse(text);nativeSystems.domain('academyPathways').validate(doc.state);if(${planning})validateManager(doc.state);return doc;};`);
 if(data){assert.equal(data.worldMode,undefined,'reprise de données de composant seulement');h.ctx.componentInput=JSON.stringify(data);h.run('S=JSON.parse(componentInput);delete globalThis.componentInput');}
 const raw=h.run,restores=[],restore=h.restore,close=h.close;
 h.componentOnly=true;h.storageText=()=>disk;
 let closed=false;
 h.close=()=>{if(closed)return;closed=true;for(const undo of restores.reverse())undo();restore(healthy);raw('validateCareer(S);parseSaveDocument(JSON.stringify(createSaveDocument()))');assert.ok(raw('JSON.stringify(S)')===healthy.text,'le composant ne modifie pas World');assert.equal(h.seed(),healthy.seed,'le composant ne consomme pas le RNG de World');assert.ok(h.store['bdt-v1']===disk,'le composant ne modifie pas le stockage World');close();};
 const blocked=()=>{throw Error('Fixture de composants : carrière principale et IO interdits.');};
 // Barrière effective dans la VM : un alias et les appels internes des modules
 // rencontrent les mêmes refus, pas seulement les expressions du lanceur.
 for(const name of ['start','startWorld','advanceSeason','finishRound','trainWeek','promoteYouth','beginDevelopmentSeason','rollDevelopmentYear',
  'createRugbyMatch','rugbySimulate','simulate','advanceRugby','presentationTick','tick','rugbyTick','rugbyBegin','beginMatch','continueMatch','rugbyFast',
  'financeWeek','worldWeeklyEconomy','economyWeek','managerWeek','aiRecruitmentWeek','aiRosterRecruitmentWeek',
  'save','nativeSaveText','nativeSaveCurrent','createSaveDocument','parseSaveDocument','validateCareer','exportCareer','downloadSaveDocument','confirmSaveImport']){
  if(annualData&&name==='rollDevelopmentYear')continue;
  if(aiV1Market&&name==='aiRosterRecruitmentWeek'){
   const original=h.ctx[name];restores.push(()=>{h.ctx[name]=original;});
   h.ctx[name]=function(...args){if(!raw('S.aiRosterVersion===1&&S.aiRoster.version===1&&!CDWorldCareer.active(S)'))return blocked();return original.apply(this,args);};continue;
  }
  if(typeof h.ctx[name]!=='function')continue;
  const original=h.ctx[name];restores.push(()=>{h.ctx[name]=original;});h.ctx[name]=blocked;
  assert.equal(raw(name),blocked,'barrière VM effective pour '+name);
 }
 // Certains modules natifs sont gelés : exposer leurs entrées de simulation
 // par une portée protégée évite de tenter de modifier leurs constantes.
 // Les aliases reçoivent la sentinelle AVANT l’appel ; les fonctions autorisées
 // gardent leurs fermetures réelles et les garde-fous globaux/IO ci-dessus.
 const protect=(object,names)=>new Proxy({}, {has:(_,key)=>key in object,get:(_,key)=>names.includes(key)?blocked:object[key]});
 const systems=raw('nativeSystems'),guardedDomains=new Map();
 for(const [name,names] of [['leagueDetail',['simulate','quickFixture']],['youthNational',['playUntil','execute','openSeason','closeSeason']],['youthMatches',['execute']],['espoirsMatch',['execute']]]){
  const object=systems.domain(name);if(object)guardedDomains.set(name,protect(object,names));
 }
 const guardedSystems=protect(systems,['execute']);
 const systemScope=new Proxy({}, {has:(_,key)=>key in systems,get:(_,key)=>key==='domain'?(name=>guardedDomains.get(name)||systems.domain(name)):guardedSystems[key]});
 const scope={nativeSystems:systemScope,CDLeagueDetail:guardedDomains.get('leagueDetail'),CDYouthNational:guardedDomains.get('youthNational'),CDWorldCareer:protect(raw('CDWorldCareer'),['start','finishWeek','advance','advanceDay','enableDaily','newSeason','installHooks'])};
 h.ctx.componentRuntimeScope=scope;restores.push(()=>{delete h.ctx.componentRuntimeScope;});
 if(worldData)raw('(()=>{const freeze=x=>{if(x&&typeof x==="object"){for(const v of Object.values(x))freeze(v);Object.freeze(x);}};freeze(S.worldMode);})()');
 const storageObjects=new Set(raw('[gameStorage,localStorage,window.CDOfflineStorage,window.localStorage].filter(Boolean)'));
 for(const storage of storageObjects)for(const name of ['getItem','setItem','removeItem','clear','key']){
  if(typeof storage[name]!=='function')continue;
  const original=Object.getOwnPropertyDescriptor(storage,name);
  restores.push(()=>{if(original)Object.defineProperty(storage,name,original);else delete storage[name];});
  Object.defineProperty(storage,name,{value:blocked,writable:true,configurable:true});
 }
 const storeDescriptor=Object.getOwnPropertyDescriptor(h,'store');restores.push(()=>Object.defineProperty(h,'store',storeDescriptor));Object.defineProperty(h,'store',{get:blocked,configurable:true});
 for(const name of ['command','start','week','season','toMatch','restore','deferSaves','prepareCommands','prepareNativeProjection']){
  const original=h[name];restores.push(()=>{h[name]=original;});h[name]=blocked;
 }
 h.run=(code,timeout)=>{
  const forbidden=annualData?/\b(?:start|startWorld|advanceSeason|finishRound|trainWeek|promoteYouth|beginDevelopmentSeason|save|createSaveDocument|parseSaveDocument)\s*\(/:/\b(?:start|startWorld|advanceSeason|finishRound|trainWeek|promoteYouth|beginDevelopmentSeason|rollDevelopmentYear|save|createSaveDocument|parseSaveDocument)\s*\(/;
  if(forbidden.test(code))throw Error('Fixture de données uniquement : aucun cycle ni codec de carrière principale.');
  return raw('with(componentRuntimeScope){'+code+'\n}',timeout);
 };
 const beforeGuard=raw('JSON.stringify(S)');
 assert.throws(()=>h.run('{const f=CDWorldCareer.finishWeek;f()}'),/carrière principale et IO interdits/,'aucune avance du module World par alias');
 assert.throws(()=>h.run('{const f=save;f()}'),/carrière principale et IO interdits/,'un alias ne contourne pas la barrière');
 assert.throws(()=>h.command('snapshot'),/carrière principale et IO interdits/,'le worker ne reçoit pas une copie historique');
 assert.throws(()=>h.store,/carrière principale et IO interdits/,'aucune matérialisation de sauvegarde par le getter du harnais');
 assert.throws(()=>raw('{const f=createRugbyMatch;f([0,1])}'),/carrière principale et IO interdits/,'aucune simulation senior par alias');
 assert.throws(()=>raw('gameStorage.setItem("component-escape","bad")'),/carrière principale et IO interdits/,'aucune écriture par le stockage');
 assert.throws(()=>h.run('{const f=nativeSystems.domain("youthNational").playUntil;f(S)}'),/carrière principale et IO interdits/,'aucune simulation nationale interne par alias');
 assert.ok(raw('JSON.stringify(S)')===beforeGuard,'les refus de frontière sont atomiques');
 return h;
}
function planningContext(data=null,options={}){return componentContext({...options,planning:true,data});}
function populationContext(data=null){
 const h=planningContext(data);if(!data)h.run('enablePopulationPolicy()');
 h.run(`globalThis.componentPopulationDocument=function(){validatePopulationPolicy(S);for(const p of [...S.clubs.flatMap(c=>c.players),...S.economy.freeAgents,...S.development.academy,...S.aiRoster.academies.flatMap(a=>a.players)])validatePlayerPopulation(p,S);return componentDocument();}`);
 return h;
}
function annualWorldDataContext(club=0,options={}){return componentContext({...options,worldData:true,annualData:true,club});}
module.exports={componentContext,planningContext,populationContext,annualWorldDataContext};

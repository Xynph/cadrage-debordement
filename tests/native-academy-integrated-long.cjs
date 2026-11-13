'use strict';
const {settleClubMeetings}=require('./helpers/club-meetings.cjs');
// Copy the production worker outside the repository. Weekly progression uses
// the public match/delegation/result commands, including real match-talk receipts.
// Only the optional annual mobility scenario adds a test command to this copy.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),Module=require('node:module');
const sourcePath=path.resolve(__dirname,'../native/engine/worker.cjs'),folder=fs.mkdtempSync(path.join(require('node:os').tmpdir(),'native-academy-integrated-'));let source=fs.readFileSync(sourcePath,'utf8');
assert.ok(source.includes("run('nativeConfirmMatchResult()');"),'Le worker doit confirmer les résultats par son chemin public courant.');const mobility=process.env.CD_ACADEMY_MOBILITY==='1';
if(mobility){source=source.replace("new Set([...SYSTEM_COMMANDS,","new Set(['academy_test_move',...SYSTEM_COMMANDS,");source=source.replace("}else if(command==='import'){",` }else if(command==='academy_test_move'){
 run("if(!managerMobilityActive())managerMobilityEnable();{const target=(S.club+1)%30;let decision=managerMobilityDecision(target);if(!decision?.accepted){S.clubs[target].cash=Math.max(S.clubs[target].cash,10000000);worldClub(target).debt=0;worldClub(target).reputation=0;worldClub(target).coachConfidence=0;}if(!managerMobilityApply(target)||!managerMobilityAccept('job-'+S.season+'-'+target))throw Error('Mobilité annuelle de recette refusée.');}");
 }else if(command==='import'){`);}
fs.writeFileSync(path.join(folder,'worker-test-copy.cjs'),source);
const resume=process.env.CD_ACADEMY_RESUME;if(resume)fs.cpSync(path.join(resume,'profile'),path.join(folder,'profile'),{recursive:true});
const loaded=new Module(sourcePath,module);loaded.filename=sourcePath;loaded.paths=Module._nodeModulePaths(path.dirname(sourcePath));loaded._compile(source,sourcePath);const {createBridge,IMPORT_LIMIT_BYTES}=loaded.exports;
let intakes=0;
let bridge=createBridge({dataDir:path.join(folder,'profile'),seed:13,now:1700000000000}),sequence=0,maxBytes=0,maxNodes=0,playedMatches=0,resumedLiveMatches=0;let model;
function good(command,payload={}){const r=bridge.handle({id:++sequence,command,payload});assert.equal(r.ok,true,command+': '+r.error);model=r.model;return model;}
function press(){const p=model.clubLife.press;if(p.conference.available)good('press_conference',{context:p.context,answers:p.conference.questions.map(q=>({questionId:q.id,answerId:'r1'}))});}
function finishWeek(){
 const season=model.meta.season,week=model.meta.week;
 if(model.live||model.next){
  if(!model.live){
   if(!model.selection.valid)good('auto_lineup');
   if(!model.selection.valid){const expectedSlots=model.selection.coverage?.slots;assert.ok(expectedSlots?.length,'Renfort qualifié disponible pour la rencontre réelle');good('promote_cover',{confirmed:true,expectedSlots});}
   assert.equal(model.selection.valid,true,'Feuille qualifiée avant le vrai coup d’envoi');
   good('begin_match');assert.equal(model.clubLife.matchTalks.scene?.phase,'pre','Causerie du vrai match disponible');
  }else{assert.ok(resume,'Un match existant doit provenir du vrai profil de reprise');resumedLiveMatches++;}
  const pair=model.live.pair,round=model.meta.round,club=model.club.id;
  const sameMatch=row=>row.context.season===season&&row.context.round===round&&row.context.club===club&&JSON.stringify(row.context.pair)===JSON.stringify(pair);
  const key=model.clubLife.matchTalks.scene?.key??model.clubLife.matchTalks.receipts.findLast(sameMatch)?.key;
  assert.ok(key,'Identité de la causerie du match réel, y compris après reprise');
  if(!model.live.finished)good('delegate');
  assert.equal(model.live.finished,true,'Rencontre réellement terminée');assert.equal(model.clubLife.matchTalks.scene,null);
  const receipts=model.clubLife.matchTalks.receipts.filter(row=>row.key===key);
  assert.deepEqual(receipts.map(row=>row.phase),['pre','half','post'],'Trois causeries observées dans le moteur réel');
  assert.ok(receipts.every(row=>sameMatch(row)&&row.status==='delegated'),'Délégation enregistrée pour ce match par le domaine des causeries');playedMatches++;
 }
 settleClubMeetings(good('finish_round'),(command,payload)=>good(command,payload));
 assert.equal(model.meta.season,season);assert.equal(model.meta.week,week+1,'Une semaine réelle entièrement clôturée');
}
function checkpoint(){const text=good('export').meta.exportText,doc=JSON.parse(text);let nodes=0;function count(x){nodes++;if(x&&typeof x==='object')Object.values(x).forEach(count)}count(doc.state);const bytes=Buffer.byteLength(text);maxBytes=Math.max(maxBytes,bytes);maxNodes=Math.max(maxNodes,nodes);assert.ok(bytes<=IMPORT_LIMIT_BYTES,bytes+' octets');assert.ok(nodes<650000,nodes+' nœuds');const row={season:doc.state.season,week:doc.state.franceMode.week,bytes,nodes,academy:Buffer.byteLength(JSON.stringify({nativeAcademy:doc.state.nativeAcademy,v73Espoirs:doc.state.v73Espoirs,v74Accession:doc.state.v74Accession})),press:doc.state.pressConference.history.length,world:doc.state.interclubWorld.events.length};console.log(JSON.stringify(row));fs.appendFileSync(path.join(folder,'checkpoints.jsonl'),JSON.stringify(row)+'\n');fs.writeFileSync(path.join(folder,'last-export.json'),text);good('import',{text});const again=good('export').meta.exportText;assert.equal(again,text,'import/export intégrés exacts');good('shutdown');bridge=createBridge({dataDir:path.join(folder,'profile'),now:1700000000000});assert.equal(good('export').meta.exportText,text,'reprise intégrée exacte');}
try{if(resume)settleClubMeetings(good('snapshot'),(command,payload)=>good(command,payload));else{settleClubMeetings(good('new_career',{mode:'common',club:29}),(command,payload)=>good(command,payload));good('academy_activate',{...model.clubLife.academyPathways.context,confirmed:true});}const strategy=()=>model.clubLife.clubStrategy.context;
 if(!resume){good('club_board_priority',{context:strategy(),key:'effectif'});good('club_fans_price',{context:strategy(),key:'accessible'});good('club_fans_campaign',{context:strategy(),key:'locale',confirmed:true});}
 // Deux saisons intégrées en CI ; campagne longue explicite : CD_ACADEMY_YEARS=15.
 const firstYear=model.meta.season,years=Number(process.env.CD_ACADEMY_YEARS||2);assert.ok(Number.isSafeInteger(years)&&years>=firstYear,'CD_ACADEMY_YEARS doit cibler une saison entière au moins égale à la saison de reprise.');let completedSeasons=0;for(let year=firstYear;year<=years;year++){
  if(!resume||year!==firstYear)good('club_board_objective',{context:strategy(),type:'wins',target:5,deadline:34});
  for(let w=model.clubLife.academyPathways.context.week;w<34;w++){
   press();const rel=model.clubLife.relationships;if(rel.event?.available)good('locker_room_decision',{context:rel.context,eventKey:rel.event.key,choice:'ecouter'});
   finishWeek();if([10,20,34].includes(w+1))checkpoint();
  }
  assert.equal(model.meta.phase,'ended','Saison entièrement terminée avant intersaison');
  if(mobility)good('academy_test_move');settleClubMeetings(good('next_season',{confirmed:true}),(command,payload)=>good(command,payload));assert.equal(model.meta.season,year+1);if(mobility)assert.equal(model.club.id,(29+year)%30);
  // Génération du 1er juillet (politique 3) : proposition à l'intersaison, choix du club joué.
  {const view=model.clubLife.academyIntake;if(view?.available){assert.ok(view.players.length>=12,'génération de 12 à 20 jeunes');
   assert.ok(view.players.every(p=>Number.isFinite(p.rating)&&p.potentialRange&&p.potential===null),'niveau exact, potentiel en fourchette');
   const room=Math.max(0,Math.min(view.crabosCap-view.crabos,view.capacity-view.academy)),keep=view.players.slice(0,room).map(p=>p.id);
   assert.equal(bridge.handle({id:++sequence,command:'academy_intake_confirm',payload:{context:view.context,confirmed:true,keep:view.players.map(p=>p.id),release:[]}}).ok,view.players.length<=room);
   if(view.players.length>room)good('academy_intake_confirm',{context:view.context,confirmed:true,keep,release:[]});else good('snapshot');
   assert.equal(model.clubLife.academyIntake.available,false);intakes++;}}
  completedSeasons++;
 }
 assert.equal(completedSeasons,years-firstYear+1,'Toutes les saisons demandées réellement terminées');if(!resume)assert.equal(intakes,years-firstYear+1,'Une génération choisie à chaque intersaison');assert.equal(model.meta.season,years+1);assert.ok(maxBytes>0&&maxNodes>0,'Checkpoints réels exécutés');if(!resume||years>firstYear)assert.ok(playedMatches>=30,'Rencontres et causeries réelles exécutées sur une saison complète');
 console.log(JSON.stringify({passed:true,completedSeasons,firstYear,years,playedMatches,resumedLiveMatches,mobility,resumedFrom:resume||null,maximumBytes:maxBytes,maximumNodes:maxNodes,profile:folder,proof:'Vrai worker copié : calendriers/moteur réels, rencontres déléguées et trois causeries vérifiées par match, domaines natifs actifs, conférences hebdomadaires, décisions vestiaire, objectifs/conseil/supporters, import/export/reprise aux checkpoints10/20/34.'}));
}finally{bridge.close();}



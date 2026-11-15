'use strict';
// Compatibilité de DONNÉES des composants Espoirs historiques. Aucune carrière
// à14clubs n'est créée, simulée, sauvegardée ou importée par ce helper.
const assert=require('node:assert/strict');
const {engineContext}=require('../harness.cjs');
function componentContext(){
 const h=engineContext();h.start(0);h.run('save()');
 const healthy=h.checkpoint(),disk=h.store['bdt-v1'];
 assert.equal(h.run('S.worldMode.version'),5);assert.equal(h.run('S.clubs.length'),116);
 assert.equal(h.run('S.development.academy.length'),60);
 assert.equal(h.run('nativeSystems.domain("academyPathways").project().available'),false);
 assert.throws(()=>h.command('academy_activate',{confirmed:true,context:{season:1,week:0,club:0}}),/pas encore disponibles/);
 assert.ok(h.run('JSON.stringify(S)')===healthy.text,'le refus du composant historique conserve World');
 assert.ok(h.store['bdt-v1']===disk,'le refus conserve la vraie sauvegarde');
 // Le document sain passe toujours par le vrai codec de carrière Monde.
 h.run('parseSaveDocument(JSON.stringify(createSaveDocument()))');
 h.run(`{
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
 globalThis.componentDocument=function(){nativeSystems.domain('academyPathways').validate(S);return {state:JSON.parse(JSON.stringify(S))};};
 globalThis.componentParse=function(text){const doc=JSON.parse(text);nativeSystems.domain('academyPathways').validate(doc.state);return doc;};`);
 const raw=h.run;
 h.run=(code,timeout)=>{
  if(/\b(?:start|startWorld|advanceSeason|finishRound|trainWeek|promoteYouth|beginDevelopmentSeason|rollDevelopmentYear|save|createSaveDocument|parseSaveDocument)\s*\(/.test(code))throw Error('Fixture de données uniquement : aucun cycle ni codec de carrière principale.');
  return raw(code,timeout);
 };
 h.close=(()=>{const close=h.close;let closed=false;return()=>{if(closed)return;closed=true;h.restore(healthy);raw('validateCareer(S);parseSaveDocument(JSON.stringify(createSaveDocument()))');assert.ok(raw('JSON.stringify(S)')===healthy.text,'le composant ne modifie pas World');close();};})();
 return h;
}
module.exports={componentContext};

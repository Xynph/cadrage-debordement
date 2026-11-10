'use strict';
const files=Object.freeze([]),commands=Object.freeze([]);
function factory(){
 const check=(ok,message)=>{if(!ok)throw Error('Compétition personnalisée : '+message+'.');};
 const object=x=>x!==null&&typeof x==='object'&&!Array.isArray(x);
 const shape=(x,keys)=>object(x)&&Object.keys(x).length===keys.length&&keys.every(k=>Object.hasOwn(x,k));
 const text=x=>typeof x==='string'&&x.length>=1&&x.length<=80&&x===x.trim()&&!/[<>"`&\x00-\x1f\x7f]/.test(x);
 const key=x=>x.normalize('NFC').toLocaleLowerCase('fr');
 const copy=x=>JSON.parse(JSON.stringify(x));
 const abbr=i=>'C'+String(i+1).padStart(2,'0');
 function calendar(rows){
  check(Array.isArray(rows)&&rows.length===26,'26 journées requises');const directed=new Set();
  for(const row of rows){
   check(Array.isArray(row)&&row.length===7,'sept rencontres requises par journée');const busy=new Set();
   for(const pair of row){check(Array.isArray(pair)&&pair.length===2&&pair.every(x=>Number.isInteger(x)&&x>=0&&x<14)&&pair[0]!==pair[1],'rencontre invalide');
    for(const id of pair){check(!busy.has(id),'un club joue deux fois la même journée');busy.add(id);}
    const k=pair.join('-');check(!directed.has(k),'confrontation domicile-extérieur répétée');directed.add(k);
   }
   check(busy.size===14,'journée incomplète');
  }
  check(directed.size===182,'confrontations incomplètes');return rows;
 }
 function prepare(document){
  check(shape(document,['format','version','kind','name','doubleRound','rounds','clubs','fixtures'])&&document.format==='oval-legacy-fictional-calendar'&&document.version===1&&document.kind==='fictional-preview','document de calendrier inconnu');
  check(text(document.name),'nom de compétition de 1 à 80 caractères, sans balisage réservé');
  check(document.doubleRound===true&&document.rounds===26&&Array.isArray(document.clubs)&&document.clubs.length===14,'seuls 14 clubs en aller-retour sont jouables');
  const ids=new Map(),names=new Set();
  const clubs=document.clubs.map((c,id)=>{
   check(shape(c,['id','name'])&&typeof c.id==='string'&&/^[a-zA-Z0-9_-]{1,64}$/.test(c.id)&&!ids.has(c.id),'identifiant de club invalide ou en double');
   check(text(c.name)&&!names.has(key(c.name)),'noms de clubs distincts, 1 à 80 caractères, sans balisage réservé');ids.set(c.id,id);names.add(key(c.name));return {id,sourceId:c.id,name:c.name,abbr:abbr(id)};
  });
  check(Array.isArray(document.fixtures)&&document.fixtures.length===182,'182 rencontres requises');const schedule=Array.from({length:26},()=>[]);
  for(const f of document.fixtures){check(shape(f,['round','homeId','awayId'])&&Number.isInteger(f.round)&&f.round>=1&&f.round<=26&&ids.has(f.homeId)&&ids.has(f.awayId),'rencontre du document invalide');schedule[f.round-1].push([ids.get(f.homeId),ids.get(f.awayId)]);}
  calendar(schedule);return {version:1,name:document.name,clubs,schedule};
 }
 function validate(s){
  if(s?.customCompetition===undefined)return true;
  const custom=s.customCompetition;
  check(!['worldMode','franceMode','lnrMode','commonDatabase','identityPack','rosterFoundation'].some(k=>s[k]!==undefined),'réservée aux effectifs fictifs');
  check(shape(custom,['version','name','clubs','schedule'])&&custom.version===1&&text(custom.name)&&Array.isArray(custom.clubs)&&custom.clubs.length===14&&Array.isArray(s.clubs)&&s.clubs.length===14,'métadonnées invalides');
  const sourceIds=new Set(),names=new Set();
  for(let i=0;i<14;i++){
   const c=custom.clubs[i],actual=s.clubs[i];
   check(shape(c,['id','sourceId','name','abbr'])&&c.id===i&&typeof c.sourceId==='string'&&/^[a-zA-Z0-9_-]{1,64}$/.test(c.sourceId)&&!sourceIds.has(c.sourceId)&&text(c.name)&&!names.has(key(c.name))&&c.abbr===abbr(i),'identités invalides');
   sourceIds.add(c.sourceId);names.add(key(c.name));check(actual?.id===i&&actual.name===c.name&&actual.abbr===c.abbr,'identité de club divergente');
  }
  calendar(custom.schedule);check(JSON.stringify(s.schedule)===JSON.stringify(custom.schedule),'calendrier de carrière divergent');return true;
 }
 function prepareCreation(payload){
  check(shape(payload,['mode','club','confirmed','document'])&&payload.mode==='custom'&&payload.confirmed===true&&Number.isInteger(payload.club)&&payload.club>=0&&payload.club<14,'confirmez la nouvelle carrière et choisissez un club');
  check(typeof S==='undefined'||!S?.live,'création indisponible pendant un match');return prepare(payload.document);
 }
 function create(payload){
  const custom=prepareCreation(payload);
  start(payload.club,'fiction');
  check(S&&S.clubs?.length===14,'départ fictif indisponible');S.customCompetition=copy(custom);S.schedule=copy(custom.schedule);
  for(const c of custom.clubs){S.clubs[c.id].name=c.name;S.clubs[c.id].abbr=c.abbr;}
  validate(S);return project();
 }
 function project(){
  const s=typeof S==='undefined'?null:S;if(!s?.customCompetition)return null;
  return {version:1,name:s.customCompetition.name,clubCount:14,rounds:26,notice:'Compétition fictive personnalisée : 14 clubs, 26 journées et phases finales du moteur historique. Budgets, niveaux et couleurs des emplacements fictifs conservés.'};
 }
 let installed=false;
 function installHooks(){
  if(installed)return;installed=true;const previous=worldNewSeason;
  worldNewSeason=function(){const result=previous.apply(this,arguments);if(S?.customCompetition)S.schedule=copy(S.customCompetition.schedule);return result;};
 }
 function execute(){throw Error('Créez la compétition personnalisée depuis l’atelier.');}
 return {prepare,prepareCreation,create,project,validate,installHooks,execute};
}
function support(document){try{factory().prepare(document);return {playable:true,reason:'14 clubs aller-retour : carrière fictive jouable avec les phases finales historiques.'};}catch(e){return {playable:false,reason:e.message};}}
module.exports={files,commands,factory,support};

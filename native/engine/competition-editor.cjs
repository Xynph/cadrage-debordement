'use strict';
// Atelier indépendant des carrières : aucune loi sportive ou donnée officielle.
const FORMAT='oval-legacy-fictional-calendar',LIMIT=32;
const customCompetition=require('./custom-competition.cjs');
const NOTICE='Calendrier fictif personnalisé. Les formats 14 clubs aller-retour permettent une carrière ; les autres restent des documents échangeables, sans modification des compétitions officielles.';
const object=x=>x!==null&&typeof x==='object'&&!Array.isArray(x);
const check=(ok,message)=>{if(!ok)throw Error('Atelier calendrier : '+message+'.');};
const shape=(x,keys)=>object(x)&&Object.keys(x).length===keys.length&&keys.every(k=>Object.hasOwn(x,k));
const text=x=>typeof x==='string'&&x.length>=1&&x.length<=80&&x===x.trim()&&!/[\x00-\x1f\x7f]/.test(x);
const key=x=>x.normalize('NFC').toLocaleLowerCase('fr');
function namesCheck(names){
 check(Array.isArray(names)&&names.length>=2&&names.length<=LIMIT&&names.every(text),'saisissez 2 à 32 noms de clubs de 1 à 80 caractères');
 check(new Set(names.map(key)).size===names.length,'chaque club doit avoir un nom distinct');
}
function generate(payload){
 check(shape(payload,['name','clubs','doubleRound'])&&text(payload.name)&&typeof payload.doubleRound==='boolean','paramètres de génération invalides');namesCheck(payload.clubs);
 const clubs=payload.clubs.map((name,i)=>({id:'club-'+(i+1),name})),ring=clubs.map(c=>c.id),fixtures=[];
 if(ring.length%2)ring.push(null);
 const firstRounds=ring.length-1;
 for(let r=0;r<firstRounds;r++){
  for(let i=0;i<ring.length/2;i++){
   let homeId=ring[i],awayId=ring[ring.length-1-i];if(!homeId||!awayId)continue;
   if((r+i)%2)[homeId,awayId]=[awayId,homeId];
   fixtures.push({round:r+1,homeId,awayId});
  }
  ring.splice(1,0,ring.pop());
 }
 if(payload.doubleRound)for(const f of fixtures.slice())fixtures.push({round:f.round+firstRounds,homeId:f.awayId,awayId:f.homeId});
 const doc={format:FORMAT,version:1,kind:'fictional-preview',name:payload.name,doubleRound:payload.doubleRound,rounds:firstRounds*(payload.doubleRound?2:1),clubs,fixtures};
 validate(doc);return doc;
}
function validate(doc){
 check(shape(doc,['format','version','kind','name','doubleRound','rounds','clubs','fixtures'])&&doc.format===FORMAT&&doc.version===1&&doc.kind==='fictional-preview'&&text(doc.name)&&typeof doc.doubleRound==='boolean','document inconnu ou champs invalides');
 check(Array.isArray(doc.clubs)&&doc.clubs.length>=2&&doc.clubs.length<=LIMIT,'nombre de clubs invalide');
 check(doc.clubs.every(c=>shape(c,['id','name'])&&typeof c.id==='string'&&/^[a-zA-Z0-9_-]{1,64}$/.test(c.id)),'identifiants de clubs invalides');
 namesCheck(doc.clubs.map(c=>c.name));const ids=new Set(doc.clubs.map(c=>c.id));check(ids.size===doc.clubs.length,'identifiants de clubs en double');
 const n=ids.size,factor=doc.doubleRound?2:1,rounds=(n%2?n:n-1)*factor;
 check(doc.rounds===rounds,'nombre de journées incohérent');
 check(Array.isArray(doc.fixtures)&&doc.fixtures.length===n*(n-1)/2*factor,'nombre de rencontres incohérent');
 const busy=new Set(),pairs=new Map(),directed=new Set(),counts=new Map();
 for(const f of doc.fixtures){
  check(shape(f,['round','homeId','awayId'])&&Number.isInteger(f.round)&&f.round>=1&&f.round<=rounds&&ids.has(f.homeId)&&ids.has(f.awayId)&&f.homeId!==f.awayId,'rencontre invalide');
  for(const id of [f.homeId,f.awayId]){const k=f.round+':'+id;check(!busy.has(k),'un club joue deux fois la même journée');busy.add(k);}
  const directedKey=JSON.stringify([f.homeId,f.awayId]),pair=JSON.stringify([f.homeId,f.awayId].sort());
  check(!directed.has(directedKey),'rencontre domicile/extérieur en double');directed.add(directedKey);pairs.set(pair,(pairs.get(pair)||0)+1);counts.set(f.round,(counts.get(f.round)||0)+1);
 }
 check(pairs.size===n*(n-1)/2&&[...pairs.values()].every(c=>c===factor),'certaines confrontations sont absentes ou répétées');
 for(let r=1;r<=rounds;r++)check(counts.get(r)===Math.floor(n/2),'journée incomplète');
 return {format:FORMAT,version:1,kind:'fictional-preview',name:doc.name,doubleRound:doc.doubleRound,rounds:doc.rounds,clubs:doc.clubs.map(c=>({id:c.id,name:c.name})),fixtures:doc.fixtures.map(f=>({round:f.round,homeId:f.homeId,awayId:f.awayId}))};
}
function project(payload){
 check(object(payload),'requête invalide');let document;
 if(payload.action==='generate'){
  check(shape(payload,['action','name','clubs','doubleRound']),'paramètres de génération invalides');
  document=generate({name:payload.name,clubs:payload.clubs,doubleRound:payload.doubleRound});
 }else{check(payload.action==='validate'&&shape(payload,['action','document']),'action inconnue ou paramètres invalides');document=validate(payload.document);}
 return {document,notice:NOTICE,launch:customCompetition.support(document),summary:{clubs:document.clubs.length,rounds:document.rounds,matches:document.fixtures.length,byesPerClub:document.clubs.length%2?(document.doubleRound?2:1):0},exportText:JSON.stringify(document,null,2)+'\n'};
}
module.exports={generate,validate,project};

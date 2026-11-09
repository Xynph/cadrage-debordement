'use strict';
const files=Object.freeze([]),commands=Object.freeze(['coach_note_save','coach_note_remove']);
// Serialised inside the native VM. No renderer, storage, clock or RNG access.
function factory(){
 const object=x=>x!==null&&typeof x==='object'&&!Array.isArray(x),int=(x,a,b)=>Number.isInteger(x)&&x>=a&&x<=b;
 const shape=(x,fields)=>object(x)&&Object.keys(x).length===fields.length&&Object.keys(x).every(k=>fields.includes(k));
 const check=(ok,message)=>{if(!ok)throw Error('Carnet personnel : '+message+'.');};
 const world=s=>typeof CDWorldCareer!=='undefined'&&CDWorldCareer.active(s);
 const week=s=>s.franceMode?.version===1?s.franceMode.week:s.round,context=s=>({season:s.season,week:week(s),club:s.club});
 const target=id=>typeof id==='string'&&/^[A-Za-z0-9:_-]{1,180}$/.test(id);
 const scalar=n=>int(n,0,0x10ffff)&&!(n>=0xd800&&n<=0xdfff)&&(n===9||n===10||n>=32&&!(n>=127&&n<=159));
 function decode(codes){check(Array.isArray(codes)&&codes.length>=1&&codes.length<=2000&&codes.every(scalar),'texte Unicode invalide ou limite de 2 000 caractères dépassée');const value=String.fromCodePoint(...codes);check(value.trim().length>0,'texte vide');return value;}
 function universe(s){
  const found=new Map();
  for(const p of [...s.clubs.flatMap(c=>c.players||[]),...(s.market||[]),...(s.economy?.freeAgents||[]),...(s.development?.academy||[]),...(s.aiRoster?.academies||[]).flatMap(a=>a.players||[])])if(target(p.id)&&!found.has(p.id))found.set(p.id,{id:p.id,name:p.name,pos:p.pos});
  return found;
 }
 function validate(s){
  if(!s||s.coachNotebook===undefined)return true;
  const n=s.coachNotebook;check(shape(n,['version','entries'])&&n.version===1&&Array.isArray(n.entries)&&n.entries.length<=100,'schéma ou limite de 100 notes invalide');
  const seen=new Set(),maxWeek=world(s)?CDWorldCareer.sizing(s).maxRound:s.franceMode?.version===1?34:26;
  for(const e of n.entries){
   check(shape(e,['target','textCodes','season','week','club'])&&target(e.target)&&!seen.has(e.target),'note invalide ou cible répétée');seen.add(e.target);decode(e.textCodes);
   check(int(e.season,1,s.season)&&int(e.week,0,maxWeek)&&(e.season<s.season||e.week<=week(s))&&int(e.club,0,s.clubs.length-1),'date ou club de note invalide');
  }
  return true;
 }
 function project(){
  if(!S)return null;
  const people=universe(S),identity=id=>id==='career'?{id:'career',name:'Intention de carrière',pos:null,available:true}:people.has(id)?{...people.get(id),available:true}:{id:null,name:null,pos:null,available:false};
  return {context:context(S),limit:2000,capacity:100,notice:'Notes personnelles de cette carrière. Elles n’appliquent aucune décision sportive.',entries:(S.coachNotebook?.entries||[]).map(e=>({target:e.target,text:decode(e.textCodes),season:e.season,week:e.week,club:e.club,...identity(e.target)})),targets:[identity('career'),...people.values()].map(p=>({...p,target:p.id,available:true}))};
 }
 function execute(command,payload){
  check(!!S,'créez ou importez une carrière');check(commandsList().includes(command),'commande inconnue');validate(S);
  check(shape(payload,command==='coach_note_save'?['context','target','text']:['context','target','confirmed'])&&shape(payload.context,['season','week','club']),'paramètres ou champs inconnus');
  const now=context(S);check(Object.keys(now).every(k=>payload.context[k]===now[k]),'contexte périmé');check(target(payload.target),'cible invalide');
  const prior=S.coachNotebook?.entries||[],index=prior.findIndex(e=>e.target===payload.target);let entries;
  if(command==='coach_note_save'){
   check(typeof payload.text==='string','texte invalide');const codes=Array.from(payload.text,c=>c.codePointAt(0));decode(codes);
   check(index>=0||payload.target==='career'||universe(S).has(payload.target),'dossier joueur absent');check(index>=0||prior.length<100,'limite de 100 notes atteinte');
   const entry={target:payload.target,textCodes:codes,...now};entries=prior.map(e=>({...e,textCodes:e.textCodes.slice()}));if(index<0)entries.push(entry);else entries[index]=entry;
  }else{check(payload.confirmed===true,'confirmation de suppression requise');check(index>=0,'note absente');entries=prior.filter((_,i)=>i!==index).map(e=>({...e,textCodes:e.textCodes.slice()}));}
  const notebook={version:1,entries};validate({...S,coachNotebook:notebook});S.coachNotebook=notebook;
  return {coachNote:{command,target:payload.target,context:now}};
 }
 function commandsList(){return ['coach_note_save','coach_note_remove'];}
 return {project,validate,execute,installHooks:()=>true};
}
module.exports={files,commands,factory};

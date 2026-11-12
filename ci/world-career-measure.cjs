'use strict';
// Mesure manuelle ou en CI (workflow « Mesure des clubs gérés ») : effectifs, mouvements, masses salariales et taille
// persistée d'une carrière mondiale, saison par saison, par l'API publique du worker.
// node ci/world-career-measure.cjs --seed 27 --mode world-champ --club 30 --seasons 3 --out /chemin/rapport.json [--keep /dossier]
const assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path');
// Machine partagée : le délai de 15 s par appel de la VM est relevé pour la seule
// mesure (une semaine de 116 clubs peut le dépasser sous charge).
const vm=require('node:vm'),runInContext=vm.runInContext;
vm.runInContext=(code,ctx,options)=>runInContext(code,ctx,{...options,timeout:Math.max(options?.timeout??0,180000)});
const {settleClubMeetings}=require('../tests/helpers/club-meetings.cjs');
const {createBridge}=require('../native/engine/worker.cjs');
let leagueEconomy=null;try{leagueEconomy=require('../native/engine/league-economy.cjs');}catch{}

function argumentsFor(argv){
 const o={mode:'world-champ',club:30,seasons:3,seed:27,out:null,keep:null};
 for(let i=0;i<argv.length;i+=2){
  const key={'--seed':'seed','--mode':'mode','--club':'club','--seasons':'seasons','--out':'out','--keep':'keep'}[argv[i]];
  assert(key&&argv[i+1]!==undefined,'argument inconnu : '+argv[i]);
  o[key]=['mode','out','keep'].includes(key)?argv[i+1]:Number(argv[i+1]);
 }
 assert(o.out,'--out requis');return o;
}
const median=v=>{const s=v.slice().sort((a,b)=>a-b);return s.length?s[s.length>>1]:null;};
const round=(x,d=2)=>Math.round(x*10**d)/10**d;

function leagueOf(s,club){
 const leagues=s.worldMode?.leagues??s.franceMode?.leagues??{};
 for(const [key,l] of Object.entries(leagues))if(Array.isArray(l.members)&&l.members.includes(club.id))return key;
 return 'guest';
}
function sizes(text,s){
 const out={total:Buffer.byteLength(text)};
 for(const [k,v] of Object.entries(s))out[k]=Buffer.byteLength(JSON.stringify(v)??'');
 return Object.fromEntries(Object.entries(out).sort((a,b)=>b[1]-a[1]).slice(0,16));
}
// Où se trouve chaque joueur : championnat de son club, vivier libre ou centre.
function placements(s){
 const at=new Map();
 for(const c of s.clubs){const lg=leagueOf(s,c);for(const p of c.players)at.set(p.id,lg);}
 for(const p of s.economy?.freeAgents||[])if(!at.has(p.id))at.set(p.id,'libre');
 return at;
}
// Mouvements entre deux points de mesure : origine > destination (championnat,
// « libre », « sortie » pour retraite ou bassin abstrait).
function movements(prev,now){
 if(!prev)return null;
 const out={};
 for(const [id,from] of prev){const to=now.get(id)??'sortie';if(to!==from){const k=from+'>'+to;out[k]=(out[k]||0)+1;}}
 for(const [id,to] of now)if(!prev.has(id)){const k='nouveau>'+to;out[k]=(out[k]||0)+1;}
 return Object.fromEntries(Object.entries(out).sort((a,b)=>b[1]-a[1]));
}
// Directions des clubs gérés (carrières qui en ont) : stratégies, profils, compteurs.
function directions(s){
 const d=s.clubDirections;if(!d||typeof d!=='object')return null;
 const strategies={},byLeague={},traits={};
 for(const [id,x] of Object.entries(d.clubs||{})){
  const lg=leagueOf(s,s.clubs[Number(id)]||{id:Number(id)}),st=x.strategy||'aucune';
  strategies[st]=(strategies[st]||0)+1;(byLeague[lg]??={})[st]=(byLeague[lg][st]||0)+1;
  for(const [k,v] of Object.entries(x.traits||{}))if(typeof v==='number')(traits[k]??=[]).push(v);
 }
 return {strategies,byLeague,traits:Object.fromEntries(Object.entries(traits).map(([k,v])=>[k,{median:median(v),min:Math.min(...v),max:Math.max(...v)}])),
  tally:d.tally||null,news:(d.feed||[]).slice(0,25)};
}
function observe(label,s,storeText,profileBytes,exportResult,events,elapsedMs){
 const leagues={};
 for(const c of s.clubs){
  const key=leagueOf(s,c);const l=leagues[key]??={clubs:0,sizes:[],payroll:[],cash:[]};
  l.clubs++;l.sizes.push(c.players.length);l.payroll.push(c.players.reduce((n,p)=>n+p.salary,0)*52/1e6);l.cash.push(c.cash/1e6);
 }
 const byLeague=Object.fromEntries(Object.entries(leagues).map(([k,l])=>{const cap=leagueEconomy?.CHAMPIONNATS?.[k]?.plafond??null;return [k,{clubs:l.clubs,mean:round(l.sizes.reduce((a,b)=>a+b,0)/l.clubs,1),min:Math.min(...l.sizes),max:Math.max(...l.sizes),payrollMedian:round(median(l.payroll)),payrollMax:round(Math.max(...l.payroll)),cashMedian:round(median(l.cash)),cap:cap&&cap/1e6,overCap:cap?l.payroll.filter(x=>x*1e6>cap).length:null,overCapClubs:cap?s.clubs.filter(c=>leagueOf(s,c)===k&&c.players.reduce((n,p)=>n+p.salary,0)*52>cap).map(c=>({id:c.id,payroll:round(c.players.reduce((n,p)=>n+p.salary,0)*52/1e6,3),players:c.players.length})):null}];}));
 const b=s.clubBudget,userLeague=leagueOf(s,s.clubs[s.club]);
 const budget=b?.clubs?{user:b.clubs[s.club],peers:Object.fromEntries(['recettes','charges','salaires','masse','enveloppe','depart'].map(k=>[k,round(median(b.clubs.filter((x,i)=>i!==s.club&&leagueOf(s,s.clubs[i])===userLeague).map(x=>x[k]??0))/1e6)]))}:null;
 const debt=Object.values(s.worldManagement?.clubInfo||{}).filter(x=>x.debt>0).length;
 const academies=(s.aiRoster?.academies||[]).reduce((n,a)=>n+a.players.length,0);
 return {label,season:s.season,phase:s.phase,elapsedMs,byLeague,
  professionals:s.clubs.reduce((n,c)=>n+c.players.length,0),academies,freeAgents:s.economy.freeAgents.length,market:s.market.length,
  retired:s.development?.retired?.length,userCash:round(s.clubs[s.club].cash/1e6),userPayroll:round(s.clubs[s.club].players.reduce((n,p)=>n+p.salary,0)*52/1e6),
  budget,debtClubs:debt,userLedger:s.__ledger,
  stateBytes:Buffer.byteLength(storeText),profileBytes,stateSizes:sizes(storeText,s),export:exportResult,events,
  interclub:(s.economy?.transfers||[]).filter(t=>/ achète | prête | rapatrie | engage /.test(t.text||'')).length,directions:directions(s)};
}
function run(o){
 const started=Date.now(),dir=fs.mkdtempSync(path.join(os.tmpdir(),'cd-measure-'));
 const report={options:o,flag:process.env.CD_SALAIRES_PAR_NIVEAU??null,node:process.version,observations:[]};
 let bridge,model,serial=0;const seen=new Set();let counts={};
 const go=(command,payload={})=>{const r=bridge.handle({id:++serial,command,payload});assert(r.ok,command+': '+r.error);return model=r.model;};
 const profile=path.join(dir,'PrototypeGodot/donnees.json');
 const state=()=>{const raw=fs.readFileSync(profile,'utf8');const text=JSON.parse(raw).store['bdt-v1'];return {text,bytes:Buffer.byteLength(raw)};};
 let prevLedger=[],ledgerSum={},prevPlaces=null;
 const ledger=s=>{const now=s.ledger||[];let n=now.length;if(prevLedger.length){const head=JSON.stringify(prevLedger[0]);for(let i=0;i<now.length;i++){if(JSON.stringify(now[i])===head&&JSON.stringify(now.slice(i,i+3))===JSON.stringify(prevLedger.slice(0,3))){n=i;break;}}}
  for(const e of now.slice(0,n)){const k=String(e.title).replace(/ · .*/,'').replace(/\d+/g,'#');ledgerSum[k]=round((ledgerSum[k]||0)+e.amount/1e6,3);}prevLedger=now;};
 const track=s=>{for(const e of s.aiRoster?.events||[]){const k=JSON.stringify(e);if(seen.has(k))continue;seen.add(k);const lg=leagueOf(s,s.clubs[e.clubId]||{id:e.clubId});const key=e.kind;counts[key]??={};counts[key][lg]=(counts[key][lg]||0)+1;}};
 const save=()=>{fs.mkdirSync(path.dirname(o.out),{recursive:true});fs.writeFileSync(o.out,JSON.stringify(report,null,1));};
 const capture=label=>{
  const {text,bytes}=state(),s=JSON.parse(text);track(s);ledger(s);s.__ledger=ledgerSum;ledgerSum={};
  let exp=null;const t=Date.now();if(label.startsWith('end-')||label==='after-S'+o.seasons)try{const r=bridge.handle({id:++serial,command:'export',payload:{}});exp=r.ok?{ok:true,bytes:Buffer.byteLength(r.model.meta.exportText),ms:Date.now()-t}:{ok:false,error:r.error};}catch(e){exp={ok:false,error:String(e.message)};}
  const row=observe(label,s,text,bytes,exp,counts,Date.now()-started);counts={};
  const now=placements(s);row.movements=movements(prevPlaces,now);prevPlaces=now;report.observations.push(row);
  console.log(JSON.stringify({label,elapsed:Math.round(row.elapsedMs/1000),stateMB:round(row.stateBytes/1048576),export:!exp?null:exp.ok?round(exp.bytes/1048576):exp.error,elite:row.byLeague.elite,events:row.events,strategies:row.directions?.strategies}));
  if(o.keep){fs.mkdirSync(o.keep,{recursive:true});fs.copyFileSync(profile,path.join(o.keep,label+'.json'));}
  save();
 };
 try{
  bridge=createBridge({dataDir:dir,seed:o.seed,now:1794178800000});
  settleClubMeetings(go('new_career',{mode:o.mode,club:o.club}),go);capture('initial');
  for(let season=1;season<=o.seasons;season++){
   for(let week=model.meta.week,guard=0;model.meta.phase!=='ended'&&guard<80;week++,guard++){
    if(model.next){if(!model.selection.valid)go('auto_lineup');if(!model.selection.valid)go('promote_cover',{confirmed:true});go('begin_match');go('delegate');}
    settleClubMeetings(go('finish_round'),go);
    // Pas de lecture hebdomadaire de l'état : la machine est partagée (mémoire).
    // Les mouvements se lisent aux points de mesure (clichés et rapports de saison).
   }
   capture('end-S'+season);
   settleClubMeetings(go('next_season',{confirmed:true}),go);capture('after-S'+season);
  }
  report.status='completed';
 }catch(e){report.status='failed';report.failure=String(e.stack||e);console.error(e.stack);}
 finally{bridge?.close();report.elapsedMs=Date.now()-started;save();fs.rmSync(dir,{recursive:true,force:true});}
 return report;
}
if(require.main===module)run(argumentsFor(process.argv.slice(2)));
module.exports={argumentsFor,run};

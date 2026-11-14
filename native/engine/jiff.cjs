'use strict';
const files=Object.freeze([]),commands=Object.freeze([]);
// Statut JIFF (joueur issu des filières de formation), règlements LNR 2026-27,
// décision de Léo du 12/11/2026 : « comme dans la réalité ».
// - JIFF par le centre : 3 saisons dans un centre de formation français ;
// - JIFF par la licence : 5 saisons dans un club français jusqu'à la saison des 22 ans ;
// - Top 14 et Pro D2 : moyenne de 16 JIFF par feuille de match sur la saison régulière,
//   sinon retrait de points la saison suivante ; prime du fonds JIFF au-delà de 17.
// Le statut initial des joueurs existants est inventé (aucune donnée réelle dans la base).
function factory(){
 const POLICY='lnr-2026-27-v1',TARGET=16,BONUS_FROM=17,HISTORY=120,BUCKETS=64;
 const copy=x=>JSON.parse(JSON.stringify(x)),object=x=>!!x&&typeof x==='object'&&!Array.isArray(x);
 const shape=(x,keys)=>object(x)&&Object.keys(x).length===keys.length&&Object.keys(x).every(k=>keys.includes(k));
 const int=(n,a,b)=>Number.isSafeInteger(n)&&n>=a&&n<=b,num=(n,a,b)=>typeof n==='number'&&Number.isFinite(n)&&n>=a&&n<=b;
 const id=x=>typeof x==='string'&&/^[A-Za-z0-9:_.-]{1,180}$/.test(x);
 const check=(yes,message)=>{if(!yes)throw Error('JIFF : '+message+'.');};
 const state=()=>typeof S==='undefined'?null:S;
 const hash=x=>{let h=2166136261;for(const c of String(x))h=Math.imul(h^c.charCodeAt(0),16777619);return h>>>0;};
 const franceActive=s=>typeof CDFranceCompetition!=='undefined'&&CDFranceCompetition.active(s);
 const worldActive=s=>typeof CDWorldCareer!=='undefined'&&CDWorldCareer.active(s);
 // Clubs soumis à la règle : Top 14 (« elite ») et Pro D2 (« accession »).
 function subjectLeagues(s){
  if(franceActive(s))return Object.fromEntries(Object.entries(s.franceMode.leagues||{}).map(([k,v])=>[k,(v.members||v.clubs||[]).slice()]));
  if(worldActive(s)&&s.worldMode?.leagues)return Object.fromEntries(['elite','accession'].filter(k=>s.worldMode.leagues[k]).map(k=>[k,s.worldMode.leagues[k].members.slice()]));
  return {};
 }
 function leagueOf(s,clubId){for(const [k,ids]of Object.entries(subjectLeagues(s)))if(ids.includes(clubId))return k;return null;}
 const subject=(s,clubId)=>leagueOf(s,clubId)!==null;
 // Tous les clubs français (y compris Nationale) comptent pour la licence et le centre.
 // Carrière Monde : les clubs n'ont pas de pays ; sont français les membres des ligues
 // Top 14 (« elite »), Pro D2 (« accession ») et Nationale du Monde (promus et relégués suivent).
 const WORLD_FRENCH=['elite','accession','nationale'];
 function frenchClubs(s){
  if(franceActive(s))return s.clubs.map(c=>c.id);
  if(worldActive(s)&&s.worldMode?.leagues)return WORLD_FRENCH.flatMap(k=>s.worldMode.leagues[k]?.members||[]);
  return [];
 }
 // Jeune formé dans un centre français (identifiant youth-<club>-<saison>-<n>).
 function frenchYouth(p,french){const m=/^youth-(\d+)-/.exec(p?.id||'');return !!m&&french.has(+m[1]);}
 const active=s=>s?.jiff?.version===1;
 // Statuts rangés en 64 paniers : la sauvegarde refuse les objets de plus de 2000 clés.
 const bucketOf=pid=>'b'+(hash(pid)%BUCKETS);
 const getStatus=(s,pid)=>s.jiff.players[bucketOf(pid)]?.[pid]||null;
 function setStatus(s,pid,e){const b=bucketOf(pid);(s.jiff.players[b]||(s.jiff.players[b]={}))[pid]=e;}
 function dropStatus(s,pid){const b=bucketOf(pid),bucket=s.jiff.players[b];if(!bucket)return;delete bucket[pid];if(!Object.keys(bucket).length)delete s.jiff.players[b];}
 const allStatuses=s=>Object.values(s.jiff.players).flatMap(b=>Object.entries(b));
 function academyOf(s,clubId){
  if(clubId===s.club)return s.development?.academy||[];
  return (s.aiRoster?.academies||[]).find(a=>a.clubId===clubId)?.players||[];
 }
 // Statut initial inventé : environ deux tiers de JIFF chez les pros français, comme le
 // réel moyen du Top 14 ; les jeunes des centres comptent leurs saisons d'après leur âge.
 function initialEntry(p,french){
  if(!french)return [0,0,0];
  const centre=Math.max(0,Math.min(3,(p.age|0)-16));return [centre>=3?1:0,centre,0];
 }
 function initialize(s){
  if(active(s))return false;
  const french=new Set(frenchClubs(s));
  s.jiff={version:1,policy:POLICY,since:s.season,players:{},counts:{},lastCount:null,results:[],deductions:{},deductionSeason:s.season};
  for(const c of s.clubs){
   // Pros : environ 70 % de JIFF dans chaque club français (moyenne réelle du Top 14),
   // tirés par empreinte pour que chaque effectif puisse composer une feuille conforme.
   const order=c.players.filter(p=>id(p.id)).sort((a,b)=>hash(a.id+':jiff')-hash(b.id+':jiff')||(a.id<b.id?-1:1));
   const quota=french.has(c.id)?Math.ceil(order.length*.7):0;
   // Un pro sorti d'un centre français compte ses saisons de centre d'après son âge.
   order.forEach((p,i)=>setStatus(s,p.id,i<quota?[1,0,5]:frenchYouth(p,french)?initialEntry(p,true):[0,0,0]));
   for(const p of academyOf(s,c.id))if(id(p.id))setStatus(s,p.id,initialEntry(p,french.has(c.id)));
  }
  return true;
 }
 function entry(s,p){return getStatus(s,p.id)||[0,0,0];}
 const isJiff=(s,p)=>!!p&&active(s)&&entry(s,p)[0]===1;
 function sheetIds(s,c){
  if(c.id===s.club)return [...(s.lineup||[]),...(s.reserves||[])].filter(Boolean);
  const sheet=buildSheet(c);return [...sheet.lineup,...sheet.bench].filter(Boolean);
 }
 // Carrière Monde : clubs qui jouent cette semaine une journée de saison régulière du Top 14
 // ou de la Pro D2 (le calendrier Monde compte des semaines sans match, de Coupe d'Europe
 // ou de phase finale, qui n'entrent pas dans la moyenne).
 function worldSheetsThisWeek(s){
  const out=[];
  for(const f of CDWorldCareer.fixtures(s))if(f.phase==='league'&&(f.competitionId==='elite'||f.competitionId==='accession'))out.push(f.homeId,f.awayId);
  return out;
 }
 function countSheet(s,c,ids=sheetIds(s,c)){
  const players=new Map(c.players.map(p=>[p.id,p]));
  return ids.filter(x=>isJiff(s,players.get(x))).length;
 }
 const weekKey=s=>s.season+':'+(s.franceMode?.week??s.worldMode?.week??s.round);
 // Une feuille par journée de saison régulière et par club soumis à la règle.
 function recordWeek(s){
  if(!active(s)||s.phase!=='league')return false;
  const key=weekKey(s);if(s.jiff.lastCount===key)return false;
  const playing=worldActive(s)&&!franceActive(s)?[worldSheetsThisWeek(s)]:Object.values(subjectLeagues(s));
  for(const ids of playing)for(const ci of ids){
   const c=s.clubs[ci];if(!c)continue;
   const row=s.jiff.counts[ci]||(s.jiff.counts[ci]=[0,0]);
   row[0]++;row[1]+=countSheet(s,c);
  }
  s.jiff.lastCount=key;return true;
 }
 // Barème inventé (le réel est progressif mais non publié) : 1 point par demi-JIFF manquant.
 const deductionFor=average=>average>=TARGET?0:Math.min(10,Math.ceil((TARGET-average)*2));
 function bonusFor(league,average){
  if(average<BONUS_FROM)return 0;
  const top=league==='elite'?320000:280000,base=league==='elite'?220000:190000;
  return Math.min(top,Math.round((base+(average-BONUS_FROM)*100000)/1000)*1000);
 }
 // Fin de saison : moyennes, retraits de points pour la saison suivante, primes, puis
 // une saison de plus au centre ou en club pour chaque jeune français.
 function closeSeason(s,completed){
  if(!active(s))return false;
  const deductions={},results=[];
  for(const [league,ids]of Object.entries(subjectLeagues(s)))for(const ci of ids){
   const row=s.jiff.counts[ci];if(!row||!row[0])continue;
   const average=Math.round(row[1]/row[0]*100)/100,deduction=deductionFor(average),bonus=bonusFor(league,average),c=s.clubs[ci];
   if(deduction)deductions[ci]=deduction;
   // Prime au club ; pour le club du manager, elle passe par la comptabilité.
   if(bonus&&c&&Number.isFinite(c.cash)){if(ci===s.club&&typeof ledgerEntry==='function'&&typeof club==='function'&&club()===c)ledgerEntry('Fonds JIFF',bonus);else c.cash+=bonus;}
   results.push({season:completed,clubId:ci,league,sheets:row[0],average,deduction,bonus});
   if(ci===s.club&&typeof news==='function')news(deduction?`JIFF : moyenne de ${average.toLocaleString('fr-FR')} par feuille, sous les ${TARGET} exigés. Retrait de ${deduction} point${deduction>1?'s':''} la saison prochaine.`:bonus?`JIFF : moyenne de ${average.toLocaleString('fr-FR')} par feuille. Le fonds JIFF verse ${bonus.toLocaleString('fr-FR')} € au club.`:`JIFF : moyenne de ${average.toLocaleString('fr-FR')} par feuille, quota respecté.`);
  }
  const french=new Set(frenchClubs(s));
  for(const c of s.clubs){
   if(!french.has(c.id))continue;
   for(const p of academyOf(s,c.id)){
    const e=getStatus(s,p.id)||[0,0,0];if(e[0]){setStatus(s,p.id,e);continue;}
    e[1]=Math.min(9,e[1]+1);if(e[1]>=3){e[0]=1;if(c.id===s.club&&typeof news==='function')news(`${p.name} obtient le statut JIFF après trois saisons au centre de formation.`);}
    setStatus(s,p.id,e);
   }
   for(const p of c.players){
    const e=getStatus(s,p.id)||[0,0,0];
    // Un Espoir passé pro reste rattaché au centre de son club formateur jusqu'à 21 ans.
    if(!e[0]&&(p.age|0)<=21&&frenchYouth(p,french)){e[1]=Math.min(9,e[1]+1);if(e[1]>=3){e[0]=1;if(c.id===s.club&&typeof news==='function')news(`${p.name} obtient le statut JIFF après trois saisons au centre de formation.`);}}
    if(!e[0]&&(p.age|0)<=23){e[2]=Math.min(9,e[2]+1);if(e[2]>=5){e[0]=1;if(c.id===s.club&&typeof news==='function')news(`${p.name} obtient le statut JIFF après cinq saisons de licence en France.`);}}
    setStatus(s,p.id,e);
   }
  }
  const known=new Set(s.clubs.flatMap(c=>[...c.players,...academyOf(s,c.id)].map(p=>p.id)));
  // On garde le statut acquis d'un joueur parti (libre, étranger) ; on oublie le reste.
  for(const [pid,e] of allStatuses(s))if(!known.has(pid)&&!e[0])dropStatus(s,pid);
  // Les retraits ne valent que pour la saison suivante : le classement final de la saison
  // terminée (barrage, promotions, archives) n'est jamais modifié après coup. Ils sont
  // donc mis en attente puis appliqués une fois la nouvelle saison ouverte.
  // Les retraits de la saison terminée restent en place jusqu'à l'ouverture de la suivante
  // (classement final, archives et départages calculés pendant le passage de saison).
  s.jiff.counts={};s.jiff.lastCount=null;
  s.jiff.results=s.jiff.results.concat(results).slice(-HISTORY);
  return deductions;
 }
 function openSeason(s,deductions){
  if(!active(s))return false;s.jiff.deductions=copy(deductions||{});s.jiff.deductionSeason=s.season;
  // Carrière Monde : le classement recopié dans les clubs intègre aussitôt le retrait.
  if(worldActive(s)&&!franceActive(s)&&typeof CDWorldCareer.rows==='function')for(const k of ['elite','accession'])if(s.worldMode?.leagues?.[k])for(const r of CDWorldCareer.rows(s,k))if(s.clubs[r.clubId])s.clubs[r.clubId].points=r.points;
  return true;
 }
 // Retraits applicables à une saison donnée : saison courante (état), sinon d'après les bilans
 // de la saison précédente (seules les dernières saisons restent dans l'historique).
 function deductionsFor(s,season=s?.season){
  if(!active(s))return {};
  if(season===s.jiff.deductionSeason)return copy(s.jiff.deductions);
  const out={};for(const r of s.jiff.results)if(r.season===season-1&&r.deduction)out[r.clubId]=r.deduction;return out;
 }
 // Composition automatique : on échange des remplaçants puis des titulaires non JIFF
 // contre le meilleur JIFF valide du même poste jusqu'à atteindre la moyenne exigée.
 function comply(s,c,sheet){
  if(!active(s)||!subject(s,c.id))return sheet;
  const players=new Map(c.players.map(p=>[p.id,p])),used=new Set([...sheet.lineup,...sheet.bench].filter(Boolean));
  // Carrière Monde : un joueur retenu en sélection à la date du match n'est jamais appelé.
  const fixture=worldActive(s)&&typeof CDWorldCareer.fixtures==='function'?CDWorldCareer.fixtures(s).find(f=>f.homeId===c.id||f.awayId===c.id):null;
  const released=p=>!!fixture&&typeof CDWorldCareer.clubReleaseOn==='function'&&!!CDWorldCareer.clubReleaseOn(s,p.id,fixture.date);
  let count=[...used].filter(x=>isJiff(s,players.get(x))).length;
  const swap=(list,i,eligible)=>{
   const current=players.get(list[i]);if(!current||isJiff(s,current))return false;
   const options=c.players.filter(p=>!p.injury&&!used.has(p.id)&&isJiff(s,p)&&eligible(p,i)&&!released(p));
   if(!options.length)return false;
   const best=options.sort((a,b)=>(b.rating||0)-(a.rating||0)||(a.id<b.id?-1:1))[0];
   used.delete(list[i]);used.add(best.id);list[i]=best.id;count++;return true;
  };
  const lineup=sheet.lineup.slice(),bench=sheet.bench.slice();
  const benchOrder=bench.map((x,i)=>i).sort((a,b)=>(players.get(bench[a])?.rating||0)-(players.get(bench[b])?.rating||0));
  for(const i of benchOrder){if(count>=TARGET)break;swap(bench,i,(p,j)=>typeof benchEligible!=='function'||benchEligible(p,j));}
  const lineupOrder=lineup.map((x,i)=>i).sort((a,b)=>(players.get(lineup[a])?.rating||0)-(players.get(lineup[b])?.rating||0));
  for(const i of lineupOrder){if(count>=TARGET)break;swap(lineup,i,(p,j)=>typeof slotEligible!=='function'||slotEligible(p,j));}
  return {...sheet,lineup,bench};
 }
 function deduction(s,clubId){return active(s)&&s.jiff.deductionSeason===s.season?(s.jiff.deductions[clubId]||0):0;}
 function validate(s){
  if(!s||s.jiff===undefined)return true;
  const st=s.jiff;
  check(shape(st,['version','policy','since','players','counts','lastCount','results','deductions','deductionSeason'])&&st.version===1&&st.policy===POLICY&&int(st.since,1,s.season)&&int(st.deductionSeason,1,s.season+1),'état invalide');
  check(object(st.players)&&Object.keys(st.players).length<=BUCKETS&&Object.entries(st.players).every(([b,bucket])=>/^b\d{1,2}$/.test(b)&&object(bucket)&&Object.keys(bucket).length>0&&Object.keys(bucket).length<=2000&&Object.entries(bucket).every(([k,e])=>id(k)&&bucketOf(k)===b&&Array.isArray(e)&&e.length===3&&int(e[0],0,1)&&int(e[1],0,9)&&int(e[2],0,9))),'statuts invalides');
  check(object(st.counts)&&Object.entries(st.counts).every(([k,r])=>int(+k,0,s.clubs.length-1)&&Array.isArray(r)&&r.length===2&&int(r[0],0,200)&&int(r[1],0,23*r[0])),'feuilles comptées invalides');
  check(st.lastCount===null||typeof st.lastCount==='string'&&/^\d+:\d+$/.test(st.lastCount),'dernière feuille invalide');
  check(Array.isArray(st.results)&&st.results.length<=HISTORY&&st.results.every(r=>shape(r,['season','clubId','league','sheets','average','deduction','bonus'])&&int(r.season,1,s.season)&&int(r.clubId,0,s.clubs.length-1)&&['elite','accession'].includes(r.league)&&int(r.sheets,1,200)&&num(r.average,0,23)&&int(r.deduction,0,10)&&int(r.bonus,0,320000)),'bilans invalides');
  check(object(st.deductions)&&Object.entries(st.deductions).every(([k,v])=>int(+k,0,s.clubs.length-1)&&int(v,1,10)),'retraits de points invalides');
  return true;
 }
 function execute(){throw Error('JIFF : aucune commande.');}
 function project(){
  const s=state();if(!s||!active(s))return {available:false,applies:false};
  const c=s.clubs[s.club],league=leagueOf(s,s.club),row=s.jiff.counts[s.club]||[0,0];
  const current=countSheet(s,c,[...(s.lineup||[]),...(s.reserves||[])].filter(Boolean));
  const squad=c.players.map(p=>({id:p.id,jiff:isJiff(s,p),centreSeasons:entry(s,p)[1],licenceSeasons:entry(s,p)[2]}));
  const academy=academyOf(s,s.club).map(p=>({id:p.id,jiff:isJiff(s,p),centreSeasons:entry(s,p)[1],seasonsToStatus:isJiff(s,p)?0:Math.max(0,3-entry(s,p)[1])}));
  return {available:true,applies:league!==null,league,target:TARGET,bonusFrom:BONUS_FROM,currentSheet:current,sheets:row[0],average:row[0]?Math.round(row[1]/row[0]*100)/100:null,
   deduction:deduction(s,s.club),squadJiff:squad.filter(p=>p.jiff).length,squad,academy,lastResults:s.jiff.results.filter(r=>r.clubId===s.club).slice(-5)};
 }
 function installHooks(){
  if(typeof finishRound==='function'&&!finishRound.__jiff){
   const original=finishRound,wrapped=function(){const s=state();if(s&&!active(s)&&frenchClubs(s).length)initialize(s);
    // La feuille de la journée est comptée avant que la journée ne se termine.
    if(s&&active(s)&&s.phase==='league'&&!(s.live&&!s.live.finished))recordWeek(s);
    return original.apply(this,arguments);};
   Object.assign(wrapped,original);wrapped.__jiff=true;finishRound=wrapped;
  }
  if(typeof advanceSeason==='function'&&!advanceSeason.__jiff){
   // Bilan avant le passage de saison : les feuilles et les centres sont ceux de la saison finie.
   const original=advanceSeason,wrapped=function(){const s=state(),completed=s?.season,snapshot=s&&active(s)?copy(s.jiff):null,cash=s?s.clubs.map(c=>c.cash):null;
    const pending=snapshot?closeSeason(s,completed):null;
    try{const result=original.apply(this,arguments);
     if(snapshot&&S===s&&s.season===completed+1)openSeason(s,pending);
     // Si la saison n'a pas changé (passage refusé), on restaure l'état JIFF et les trésoreries.
     if(snapshot&&S===s&&s.season!==completed+1){s.jiff=snapshot;s.clubs.forEach((c,i)=>{c.cash=cash[i];});}
     return result;
    }catch(error){if(snapshot&&S===s){s.jiff=snapshot;s.clubs.forEach((c,i)=>{c.cash=cash[i];});}throw error;}};
   Object.assign(wrapped,original);wrapped.__jiff=true;advanceSeason=wrapped;
  }
  if(typeof buildSheet==='function'&&!buildSheet.__jiff){
   const original=buildSheet,wrapped=function(c,preferred=[],preferredBench=[]){const sheet=original.apply(this,arguments);const s=state();
    // Une feuille choisie à la main par le joueur n'est jamais modifiée.
    if(!s||!c||preferred.length||preferredBench.length)return sheet;return comply(s,c,sheet);};
   Object.assign(wrapped,original);wrapped.__jiff=true;buildSheet=wrapped;
  }
  return true;
 }
 return {target:TARGET,project,validate,execute,installHooks,initialize,openSeason,getStatus,setStatus,recordWeek,closeSeason,comply,isJiff,deduction,deductionsFor,deductionFor,bonusFor,subjectLeagues,frenchClubs};
}
module.exports={files,commands,factory};

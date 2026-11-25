'use strict';
const files=Object.freeze([]),commands=Object.freeze([]);
// Statut JIFF (joueur issu des filières de formation), règlements LNR 2026-27,
// décision de Léo du 12/11/2026 : « comme dans la réalité ».
// - JIFF par le centre : 3 saisons dans un centre de formation français ;
// - JIFF par la licence : 5 saisons dans un club français jusqu'à la saison des 22 ans ;
// - Top 14 et Pro D2 : moyenne de 16 JIFF par feuille de match sur la saison régulière,
//   sinon retrait de points la saison suivante ; prime du fonds JIFF au-delà de 17.
// - doublons : les jours de doublon (convention LNR/FFR), le nombre de JIFF pris en compte est augmenté du
//   nombre de JIFF retenus en équipe de France (https://abargenteuil.fr/blog/club-du-top-14-rugby/) ;
//   un JIFF du club convoqué par la France ce jour-là compte donc dans la feuille de son club.
// Le statut initial des joueurs existants est inventé (aucune donnée réelle dans la base).
//
// Quota EQP de la Premiership (England-qualified players), même mécanique de moyenne de saison :
// - moyenne de 15 EQP par feuille de 23 sur la saison de championnat, mesurée en réalité par périodes
//   désignées (la première de la J1 à la J9) ; amende jusqu'à 250 000 £ en cas d'échec, pas de retrait
//   de points en Premiership masculine (https://uk.sports.yahoo.com/news/premiership-clubs-face-250-000-145757446.html).
//   Limites assumées : le jeu mesure la moyenne de toute la saison (pas les périodes) ; le barème exact de
//   l'amende n'est pas public, il est ici proportionnel à l'écart (prudent, plafonné à 250 000 £).
// - un EQP est un joueur sélectionnable pour l'Angleterre (naissance, ascendance ou résidence, règlement 8 de
//   World Rugby). L'éligibilité n'est modélisée que pour une partie des joueurs (sélections, nations
//   d'éligibilité documentées, jeunes formés au club) : pour les autres, on retient la nation sportive
//   du joueur (nativeFacts.origin), sans résidence ni ascendance : c'est la limite du modèle.
// - URC et Super Rugby Pacific : aucun quota de championnat comparable connu, rien n'est modélisé ;
//   Championship : le statut EQP y conditionne le financement de la RFU, sans barème public : rien.
function factory(){
 const POLICY='lnr-2026-27-v1',TARGET=16,BONUS_FROM=17,HISTORY=120,BUCKETS=64,SHEET=23;
 // Règles par championnat (clé de ligue du calendrier Monde).
 const RULES=Object.freeze({
  elite:Object.freeze({kind:'jiff',label:'JIFF',target:16,bonusFrom:17}),
  accession:Object.freeze({kind:'jiff',label:'JIFF',target:16,bonusFrom:17}),
  // 250 000 £ au plus ; 100 000 £ valent 115 000 € dans l'économie du jeu (club-budget.cjs, crédit académie).
  prem:Object.freeze({kind:'eqp',label:'EQP',target:15,fineMaxGbp:250000,fineFullGap:3,eurPerGbp:1.15})
 });
 const ruleOf=league=>RULES[league]||RULES.elite;
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
 // Championnats soumis à un quota de joueurs formés ou qualifiés localement : JIFF (Top 14, Pro D2) et EQP
 // (Premiership). subjectLeagues garde le sens historique (JIFF seul : retraits de points, fonds JIFF).
 function quotaLeagues(s){
  const out=subjectLeagues(s);
  if(worldActive(s)&&!franceActive(s)&&s.worldMode?.leagues?.prem)out.prem=s.worldMode.leagues.prem.members.slice();
  return out;
 }
 function leagueOf(s,clubId){
  if(worldActive(s)&&!franceActive(s)&&s.worldMode?.leagues){for(const k of ['elite','accession','prem'])if(s.worldMode.leagues[k]?.members.includes(clubId))return k;return null;}
  for(const [k,ids]of Object.entries(quotaLeagues(s)))if(ids.includes(clubId))return k;return null;
 }
 const subject=(s,clubId)=>leagueOf(s,clubId)!==null;
 // Quota applicable à un club : {league, kind:'jiff'|'eqp', label, target, size}, ou null.
 function quota(s,clubId){
  if(!s||!active(s))return null;
  const league=leagueOf(s,clubId);if(league===null)return null;
  const r=ruleOf(league);return {league,kind:r.kind,label:r.label,target:r.target,size:SHEET};
 }
 // EQP : sélectionnable pour l'Angleterre. Éligibilité documentée (sélections, nations d'éligibilité, jeunes
 // formés au club) ; à défaut, nation sportive du joueur. Statique par joueur : mémorisé.
 const eqpMemo=new Map();
 function isEqp(p){
  if(!p||typeof nativeFacts==='undefined'||!nativeFacts||typeof nativeFacts.eligible!=='function')return false;
  const pid=p.id;if(eqpMemo.has(pid))return eqpMemo.get(pid);
  let yes=false;
  try{
   yes=nativeFacts.eligible(pid,'ENG')===true;
   if(!yes&&typeof nativeFacts.source==='function'&&typeof nativeFacts.origin==='function'){
    const r=nativeFacts.source(pid)||{};
    if(!r.seniorNation&&!(r.eligibilityNations||[]).length)yes=nativeFacts.origin(pid)==='ENG';
   }
  }catch{yes=false;}
  eqpMemo.set(pid,yes);return yes;
 }
 // Le joueur compte-t-il pour le quota de ce club (JIFF ou EQP selon son championnat) ?
 const qualifier=(s,q)=>q.kind==='eqp'?isEqp:p=>isJiff(s,p);
 // Prédicat rapide pour les boucles de composition : {target, label, kind, yes(p)} ou null hors quota.
 function qualifierFor(s,clubId){const q=quota(s,clubId);return q?{...q,yes:qualifier(s,q)}:null;}
 function qualifies(s,clubId,p){
  const q=quota(s,clubId);if(!q||!p)return false;
  return qualifier(s,q)(p);
 }
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
  const out=[],leagues=Object.keys(quotaLeagues(s));
  for(const f of CDWorldCareer.fixtures(s))if(f.phase==='league'&&leagues.includes(f.competitionId))out.push([f.homeId,f.date],[f.awayId,f.date]);
  return out;
 }
 function countSheet(s,c,ids=sheetIds(s,c)){
  const players=new Map(c.players.map(p=>[p.id,p])),q=quota(s,c.id);
  if(!q)return 0;
  const yes=qualifier(s,q);
  return ids.filter(x=>yes(players.get(x))).length;
 }
 // Doublon (JIFF seulement) : les JIFF du club retenus en équipe de France ce jour-là, hors feuille.
 function franceCalled(s,date){
  const set=new Set();if(!date)return set;
  for(const call of s.national?.career?.callups||[])if(call.nation==='FRA'&&call.from<=date&&date<=call.through)for(const pid of call.playerIds||[])set.add(pid);
  return set;
 }
 function doublon(s,c,date,onSheet=new Set()){
  const q=quota(s,c.id);if(!q||q.kind!=='jiff'||!date)return 0;
  const called=franceCalled(s,date);if(!called.size)return 0;
  return c.players.filter(p=>called.has(p.id)&&!onSheet.has(p.id)&&isJiff(s,p)).length;
 }
 // Valeur d'une feuille pour la moyenne : qualifiés alignés + JIFF convoqués par la France ce jour-là.
 function sheetValue(s,c,date,ids=sheetIds(s,c)){return Math.min(SHEET,countSheet(s,c,ids)+doublon(s,c,date,new Set(ids)));}
 const weekKey=s=>s.season+':'+(s.franceMode?.week??s.worldMode?.week??s.round);
 // Une feuille par journée de saison régulière et par club soumis à la règle.
 function recordWeek(s){
  if(!active(s)||s.phase!=='league')return false;
  const key=weekKey(s);if(s.jiff.lastCount===key)return false;
  const playing=worldActive(s)&&!franceActive(s)?worldSheetsThisWeek(s):Object.values(subjectLeagues(s)).flatMap(ids=>ids.map(ci=>[ci,null]));
  for(const [ci,date] of playing){
   const c=s.clubs[ci];if(!c)continue;
   const row=s.jiff.counts[ci]||(s.jiff.counts[ci]=[0,0]);
   row[0]++;row[1]+=sheetValue(s,c,date);
  }
  s.jiff.lastCount=key;return true;
 }
 // Barème inventé (le réel est progressif mais non publié) : 1 point par demi-JIFF manquant.
 const deductionFor=average=>average>=TARGET?0:Math.min(10,Math.ceil((TARGET-average)*2));
 // Amende EQP en livres, proportionnelle à l'écart à l'objectif (barème réel non public) : le plafond de
 // 250 000 £ est atteint à 3 EQP de moins que les 15 exigés en moyenne ; arrondie au millier de livres supérieur.
 function fineFor(average){
  const r=RULES.prem;if(average>=r.target)return 0;
  return Math.min(r.fineMaxGbp,Math.ceil(r.fineMaxGbp*Math.min(1,(r.target-average)/r.fineFullGap)/1000)*1000);
 }
 const fineEuros=gbp=>Math.floor(gbp*RULES.prem.eurPerGbp/1000)*1000;
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
  for(const [league,ids]of Object.entries(quotaLeagues(s)))for(const ci of ids){
   const row=s.jiff.counts[ci];if(!row||!row[0])continue;
   const rule=ruleOf(league),c=s.clubs[ci],average=Math.round(row[1]/row[0]*100)/100;
   if(rule.kind==='eqp'){
    // Premiership : amende en euros (jamais de retrait de points), débitée du club.
    const fine=fineFor(average),eur=fineEuros(fine);
    if(eur&&c&&Number.isFinite(c.cash)){if(ci===s.club&&typeof ledgerEntry==='function'&&typeof club==='function'&&club()===c)ledgerEntry('Amende de la ligue (quota EQP)',-eur);else c.cash-=eur;}
    results.push({season:completed,clubId:ci,league,sheets:row[0],average,deduction:0,bonus:0,fine:eur});
    if(ci===s.club&&typeof news==='function')news(eur?`EQP : moyenne de ${average.toLocaleString('fr-FR')} par feuille, sous les ${rule.target} exigés. La ligue inflige une amende de ${eur.toLocaleString('fr-FR')} €.`:`EQP : moyenne de ${average.toLocaleString('fr-FR')} par feuille, quota respecté.`);
    continue;
   }
   const deduction=deductionFor(average),bonus=bonusFor(league,average);
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
  const q=quota(s,c.id);if(!q)return sheet;
  const target=q.target,yes=qualifier(s,q),players=new Map(c.players.map(p=>[p.id,p])),used=new Set([...sheet.lineup,...sheet.bench].filter(Boolean));
  // Carrière Monde : un joueur retenu en sélection à la date du match n'est jamais appelé.
  const fixture=worldActive(s)&&typeof CDWorldCareer.fixtures==='function'?CDWorldCareer.fixtures(s).find(f=>f.homeId===c.id||f.awayId===c.id):null;
  const released=p=>!!fixture&&typeof CDWorldCareer.clubReleaseOn==='function'&&!!CDWorldCareer.clubReleaseOn(s,p.id,fixture.date);
  let count=[...used].filter(x=>yes(players.get(x))).length;
  const swap=(list,i,eligible)=>{
   const current=players.get(list[i]);if(!current||yes(current))return false;
   const options=c.players.filter(p=>!p.injury&&!used.has(p.id)&&yes(p)&&eligible(p,i)&&!released(p));
   if(!options.length)return false;
   const best=options.sort((a,b)=>(typeof niveauMatch==='function'?niveauMatch(b):b.rating||0)-(typeof niveauMatch==='function'?niveauMatch(a):a.rating||0)||(a.id<b.id?-1:1))[0];
   used.delete(list[i]);used.add(best.id);list[i]=best.id;count++;return true;
  };
  const lineup=sheet.lineup.slice(),bench=sheet.bench.slice();
  const benchOrder=bench.map((x,i)=>i).sort((a,b)=>(typeof niveauMatch==='function'&&players.get(bench[a])?niveauMatch(players.get(bench[a])):players.get(bench[a])?.rating||0)-(typeof niveauMatch==='function'&&players.get(bench[b])?niveauMatch(players.get(bench[b])):players.get(bench[b])?.rating||0));
  for(const i of benchOrder){if(count>=target)break;swap(bench,i,(p,j)=>typeof benchEligible!=='function'||benchEligible(p,j));}
  const lineupOrder=lineup.map((x,i)=>i).sort((a,b)=>(typeof niveauMatch==='function'&&players.get(lineup[a])?niveauMatch(players.get(lineup[a])):players.get(lineup[a])?.rating||0)-(typeof niveauMatch==='function'&&players.get(lineup[b])?niveauMatch(players.get(lineup[b])):players.get(lineup[b])?.rating||0));
  for(const i of lineupOrder){if(count>=target)break;swap(lineup,i,(p,j)=>typeof slotEligible!=='function'||slotEligible(p,j));}
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
  const resultKeys=['season','clubId','league','sheets','average','deduction','bonus'];
  check(Array.isArray(st.results)&&st.results.length<=HISTORY&&st.results.every(r=>object(r)&&(shape(r,resultKeys)&&r.league!=='prem'||shape(r,[...resultKeys,'fine'])&&r.league==='prem'&&int(r.fine,0,Math.round(RULES.prem.fineMaxGbp*RULES.prem.eurPerGbp)))&&int(r.season,1,s.season)&&int(r.clubId,0,s.clubs.length-1)&&['elite','accession','prem'].includes(r.league)&&int(r.sheets,1,200)&&num(r.average,0,23)&&int(r.deduction,0,10)&&int(r.bonus,0,320000)),'bilans invalides');
  check(object(st.deductions)&&Object.entries(st.deductions).every(([k,v])=>int(+k,0,s.clubs.length-1)&&int(v,1,10)),'retraits de points invalides');
  return true;
 }
 function execute(){throw Error('JIFF : aucune commande.');}
 // Matchs de saison régulière restant à jouer (le prochain compris) et date du prochain, pour un club.
 function leagueFixtures(s,clubId,league){
  if(!worldActive(s)||!s.worldMode?.fixtures)return null;
  const week=s.worldMode.week??0;
  return s.worldMode.fixtures.filter(f=>f.phase==='league'&&f.competitionId===league&&(f.homeId===clubId||f.awayId===clubId)&&f.week>=week).sort(byDate);
 }
 const byDate=(a,b)=>a.week-b.week||(String(a.date)<String(b.date)?-1:1);
 // Le prochain match du club (toutes compétitions) est-il une journée de ce championnat ?
 function nextIsLeague(s,clubId,league){
  if(!worldActive(s)||!s.worldMode?.fixtures)return true;
  const week=s.worldMode.week??0;
  const next=s.worldMode.fixtures.filter(f=>(f.homeId===clubId||f.awayId===clubId)&&f.week>=week).sort(byDate)[0];
  return !next||next.phase==='league'&&next.competitionId===league;
 }
 // Situation d'un club au regard de son quota : moyenne de saison, objectif, marge et nombre minimal de
 // qualifiés à aligner au prochain match pour rester sur la trajectoire de la moyenne exigée.
 //   marge     : qualifiés comptés en trop (+) ou en moins (−) par rapport à « objectif × feuilles jouées » ;
 //   besoinProchain : ceil((objectif × feuilles de la saison − total compté) / matchs restants), borné à la feuille ;
 //   horsDePortee   : même après une feuille de 23 qualifiés, la moyenne ne se rattrape plus.
 // Le cas réel du Racing 92, qui devait aligner 18 JIFF à la dernière journée, est ce calcul à un match restant.
 function standing(s,clubId){
  const q=quota(s,clubId);if(!q)return null;
  const row=s.jiff.counts[clubId]||[0,0],fixtures=leagueFixtures(s,clubId,q.league);
  const sheets=row[0],total=row[1],remaining=fixtures?fixtures.length:null;
  const raw=remaining?Math.ceil((q.target*(sheets+remaining)-total)/remaining):remaining===0?null:q.target;
  return {...q,sheets,total,average:sheets?Math.round(total/sheets*100)/100:null,margin:sheets?total-q.target*sheets:0,remaining,nextDate:fixtures?.[0]?.date??null,nextIsLeague:nextIsLeague(s,clubId,q.league),
   need:raw===null?null:Math.max(0,Math.min(SHEET,raw)),outOfReach:raw!==null&&raw>SHEET};
 }
 function project(){
  const s=state();if(!s||!active(s))return {available:false,applies:false};
  const c=s.clubs[s.club],league=leagueOf(s,s.club),row=s.jiff.counts[s.club]||[0,0],st=standing(s,s.club);
  const ids=[...(s.lineup||[]),...(s.reserves||[])].filter(Boolean);
  const current=countSheet(s,c,ids),twice=st?doublon(s,c,st.nextDate,new Set(ids)):0;
  const squad=c.players.map(p=>({id:p.id,jiff:isJiff(s,p),qualified:!!st&&(st.kind==='eqp'?isEqp(p):isJiff(s,p)),centreSeasons:entry(s,p)[1],licenceSeasons:entry(s,p)[2]}));
  const academy=academyOf(s,s.club).map(p=>({id:p.id,jiff:isJiff(s,p),centreSeasons:entry(s,p)[1],seasonsToStatus:isJiff(s,p)?0:Math.max(0,3-entry(s,p)[1])}));
  const rule=league?ruleOf(league):RULES.elite,effective=current+twice;
  const alert=!!st&&st.nextIsLeague&&st.need!==null&&effective<st.need;
  return {available:true,applies:league!==null,league,kind:rule.kind,label:rule.label,target:league?rule.target:TARGET,bonusFrom:rule.kind==='jiff'?BONUS_FROM:null,
   currentSheet:current,doublon:twice,effective,sheets:row[0],average:row[0]?Math.round(row[1]/row[0]*100)/100:null,margin:st?.margin??0,remaining:st?.remaining??null,
   need:st?.need??null,outOfReach:st?.outOfReach??false,alert,deduction:deduction(s,s.club),squadJiff:squad.filter(p=>p.jiff).length,squadQualified:squad.filter(p=>p.qualified).length,
   squad,academy,lastResults:s.jiff.results.filter(r=>r.clubId===s.club).slice(-5)};
 }
 // Remplacements concrets pour tenir la trajectoire : retire des non qualifiés de la feuille au profit de
 // qualifiés disponibles du même poste (meilleure note au poste, perte minimale). Utilisé par l'alerte de Gabi.
 // `slots` = feuille à plat (15 titulaires puis 8 remplaçants) ; `rating(p,k)`, `eligible(p,k)` et `pool` viennent de
 // la sélection du staff (position-aptitudes.cjs) : blessés et libérés en sélection déjà exclus.
 function advise(s,clubId,slots,{pool,rating,eligible,missing}){
  const q=quota(s,clubId);if(!q||missing<=0)return [];
  const yes=qualifier(s,q),used=new Set(slots.filter(Boolean)),out=[];
  const incoming=pool.filter(p=>yes(p)&&!used.has(p.id));
  const all=s.clubs[clubId].players,known=new Map(all.map(p=>[p.id,p]));
  const value=(p,k)=>rating(p,k)*(.5+(p.condition??100)*.005);
  while(out.length<missing){
   let best=null;
   for(let k=0;k<slots.length;k++){
    const cur=known.get(slots[k]);if(!cur||yes(cur)||out.some(c=>c.slot===k))continue;
    for(const p of incoming){
     if(used.has(p.id)||!eligible(p,k))continue;
     const loss=(value(cur,k)-value(p,k))*(k>=15?.5:1)+(rating(p,k)<40?1000:0);
     if(!best||loss<best.loss-1e-9||Math.abs(loss-best.loss)<=1e-9&&p.id<best.p.id)best={k,p,cur,loss};
    }
   }
   if(!best)break;
   used.add(best.p.id);out.push({slot:best.k,playerId:best.p.id,sortant:best.cur.id,rating:Math.round(rating(best.p,best.k)),sortantRating:Math.round(rating(best.cur,best.k))});
  }
  return out;
 }
 // Pression du quota sur un club : écart entre l'objectif et ce que ses 23 meilleurs joueurs disponibles
 // donnent naturellement, ou entre l'objectif et sa moyenne de saison (dès trois feuilles) ; 0 si tout va bien.
 const pressureMemo=new Map();
 function pressure(s,clubId){
  const q=quota(s,clubId);if(!q)return 0;
  const c=s.clubs[clubId],sig=s.season+':'+(s.worldMode?.week??s.round)+':'+c.players.length+':'+c.players[0]?.id+':'+c.players[c.players.length-1]?.id+':'+(s.jiff.counts[clubId]||[0,0]).join(',');
  const hit=pressureMemo.get(clubId);if(hit&&hit.sig===sig)return hit.value;
  const yes=qualifier(s,q),best=c.players.filter(p=>!p.injury).sort((a,b)=>(typeof niveauMatch==='function'?niveauMatch(b):b.rating||0)-(typeof niveauMatch==='function'?niveauMatch(a):a.rating||0)||(a.id<b.id?-1:1)).slice(0,SHEET);
  let gap=q.target-best.filter(yes).length;
  const row=s.jiff.counts[clubId]||[0,0];
  if(row[0]>=3)gap=Math.max(gap,q.target-row[1]/row[0]);
  const value=gap>0?Math.min(6,Math.round(gap*10)/10):0;
  pressureMemo.set(clubId,{sig,value});return value;
 }
 // Valorisation d'un joueur par un club IA (ou le conseil de Gabi) : points ajoutés au score d'un achat quand
 // le joueur compte pour le quota du club et que celui-ci est menacé. Effet modéré : 4 à 14 points.
 function recruitBonus(s,clubId,p){
  if(!s||!active(s)||!p||!qualifies(s,clubId,p))return 0;
  const pr=pressure(s,clubId);return pr>0?Math.min(14,4+Math.round(pr*3)):0;
 }
 // Pastille de recrutement du club du manager : {label, ok, useful, note} ou null si le club n'a pas de quota.
 function marketBadge(s,p){
  const q=quota(s,s.club);if(!q||!p)return null;
  const ok=qualifier(s,q)(p),pr=ok?pressure(s,s.club):0;
  return {label:q.label,ok,useful:ok&&pr>0,note:ok?(pr>0?`${q.label} : compte pour tes ${q.target} par feuille, il t'en manque`:`${q.label} : compte pour tes ${q.target} par feuille`):`Hors ${q.label}`};
 }
 // La feuille de la journée est comptée avant que la journée ne se termine.
 function beforeWeek(s){if(!s)return;if(!active(s)&&frenchClubs(s).length)initialize(s);
  if(active(s)&&s.phase==='league'&&!(s.live&&!s.live.finished))recordWeek(s);}
 function installHooks(){
  if(typeof finishRound==='function'&&!finishRound.__jiff){
   // Carrière Monde : la semaine se clôt par finishWeek (world-career.cjs), qui appelle beforeWeek, y compris en
   // calendrier journalier (advanceDay ne passe pas par finishRound) ; ce crochet ne sert donc qu'aux autres modes.
   const original=finishRound,wrapped=function(){const s=state();if(s&&!worldActive(s))beforeWeek(s);
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
 return {target:TARGET,beforeWeek,project,validate,execute,installHooks,initialize,openSeason,getStatus,setStatus,recordWeek,closeSeason,comply,isJiff,isEqp,qualifierFor,deduction,deductionsFor,deductionFor,bonusFor,fineFor,fineEuros,subjectLeagues,quotaLeagues,quota,qualifies,standing,doublon,advise,pressure,recruitBonus,marketBadge,frenchClubs};
}
module.exports={files,commands,factory};

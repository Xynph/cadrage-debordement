'use strict';
// Matchs des centres de formation (décisions de Léo du 12-13/11/2026).
// Chaque centre (un par club) engage deux équipes : Crabos/U18 (16-17 ans, quelques 15 ans) et
// Espoirs/U21 (18-21 ans). Elles jouent les VRAIES compétitions jeunes de leur pays, à leurs dates
// réelles, reprises chaque saison ; quand un pays n'a pas de championnat sur toute l'année, des
// matchs de clubs/écoles simulés complètent jusqu'à environ 20 matchs par équipe. Tout est
// simulé par un moteur de résultat rapide (score, temps de jeu, blessures, progression), jamais
// par le moteur de match complet, sans composition ni stratégie à choisir.
// Provenance : docs/matchs-jeunes-20261113.md (réel / estimé / inventé, compétition par compétition).
const files=Object.freeze([]),commands=Object.freeze([]);
function factory(){
 const g=globalThis,DAY=86400000,CAP=30,RISK_FROM=25,TARGET=20,HISTORY_SEASONS=20,OWN_RESULTS=12;
 const object=x=>!!x&&typeof x==='object'&&!Array.isArray(x);
 const int=(x,a,b)=>Number.isSafeInteger(x)&&x>=a&&x<=b;
 const clamp=(n,a,b)=>Math.max(a,Math.min(b,n));
 const hash=text=>{let h=2166136261;for(const c of String(text))h=Math.imul(h^c.charCodeAt(0),16777619);h^=h>>>15;return h>>>0;};
 // Générateur dédié (mulberry32) : n'utilise jamais le Math.random de la simulation.
 function rng(seed){let a=seed>>>0;return ()=>{a=(a+0x6D2B79F5)>>>0;let t=a;t=Math.imul(t^t>>>15,t|1);t^=t+Math.imul(t^t>>>7,t|61);return ((t^t>>>14)>>>0)/4294967296;};}
 const dayOf=(y,md)=>{const [m,d]=md.split('-').map(Number);return Math.floor(Date.UTC(m>=7?y:y+1,m-1,d)/DAY);};
 const iso=day=>new Date(day*DAY).toISOString().slice(0,10);
 const year=s=>2025+s.season;
 const endOfYear=s=>Math.floor(Date.UTC(year(s)+1,5,30)/DAY);

 // ---------------------------------------------------------------- catalogue réel/estimé/inventé
 // dates « MM-JJ » reprises chaque année (juillet-décembre : année Y ; janvier-juin : Y+1).
 const W=(...d)=>d;
 const CATALOG=[
  // France — FFR 2025-26 (livrets officiels) : Élite Crabos 42 clubs, 7 poules de 6 aller-retour,
  // puis 24 en championnat (poules de 4) et 18 en Challenge (poules de 6), phases finales en juin.
  {id:'fr-crabos',name:'Élite Crabos',cat:'C',from:'fr',take:[0,42],level:.6,stages:[
   {k:'rr',key:'p',size:6,dates:W('10-04','10-11','10-18','11-08','11-15','11-22','12-06','12-13','01-10','01-17')},
   {k:'split',from:'p',share:24/42,upper:{key:'u',size:4,dates:W('02-14','02-21','03-07','04-11','04-18','04-25')},lower:{key:'l',size:6,dates:W('02-14','02-21','02-28','03-07','04-11','04-18','04-25','05-09','05-16','05-23')}},
   {k:'ko',key:'ku',from:'u',n:8,dates:W('06-06','06-13','06-27'),title:true},
   {k:'ko',key:'kl',from:'l',n:4,dates:W('06-06','06-13'),label:'Challenge'}]},
  {id:'fr-crabos7',name:'Crabos à 7',cat:'C',from:'fr',take:[0,42],level:.35,stages:[
   {k:'tour',key:'q',dates:W('09-06','09-13')},{k:'tour',key:'f',dates:W('03-21'),top:16,title:true}]},
  {id:'fr-u18-nat',name:'Championnat National U18',cat:'C',from:'fr',take:[42,999],level:.45,virtual:'Club fédéral U18',stages:[
   {k:'virtual',key:'v',dates:W('09-20','09-27','10-04','10-11','10-18','11-08','11-15','11-29','12-06','01-10','01-17','01-31','02-14','03-07','03-14','04-11')}]},
  // Reichel-Espoirs Élite 2025-26 : 24 clubs, 4 poules de 6, puis 16 en championnat et 8 en Challenge.
  {id:'fr-espoirs',name:'Espoirs Élite',cat:'E',from:'fr',take:[0,24],level:.65,stages:[
   {k:'rr',key:'p',size:6,dates:W('09-13','09-20','09-27','10-11','10-18','10-25','11-22','11-29','12-13','12-20')},
   {k:'split',from:'p',share:16/24,upper:{key:'u',size:4,dates:W('03-21','03-28','04-04','04-18','04-25','05-09')},lower:{key:'l',size:4,dates:W('03-21','03-28','04-04','04-18','04-25','05-09')}},
   {k:'ko',key:'ku',from:'u',n:8,dates:W('05-23','05-30','06-06'),title:true},
   {k:'ko',key:'kl',from:'l',n:4,dates:W('05-23','05-30'),label:'Challenge'}]},
  {id:'fr-espoirs7',name:'Espoirs à 7',cat:'E',from:'fr',take:[0,44],level:.35,stages:[{k:'tour',key:'q',dates:W('08-22','08-29')}]},
  // Reichel-Espoirs Accession 2025-26 : 20 clubs, 2 poules de 10 aller-retour (18 journées).
  {id:'fr-espoirs-acc',name:'Espoirs Accession',cat:'E',from:'fr',take:[24,44],level:.55,stages:[
   {k:'rr',key:'p',size:10,dates:W('09-06','09-13','09-27','10-04','10-11','10-25','11-01','11-22','11-29','12-13','12-20','01-10','01-17','03-21','03-28','04-18','04-25','05-09')},
   {k:'ko',key:'k',from:'p',n:8,dates:W('05-23','05-30','06-06'),title:true}]},
  {id:'fr-espoirs-nat',name:'Espoirs Nationaux',cat:'E',from:'fr',take:[44,999],level:.45,virtual:'Club fédéral Espoirs',stages:[
   {k:'virtual',key:'v',dates:W('09-13','09-27','10-11','10-25','11-08','11-22','12-06','01-10','01-24','02-07','02-21','03-07','03-21','04-04','04-18','05-02')}]},
  // Angleterre — PREM Next Gen U18 2026-27 (calendrier des clubs) puis journée des finales (28/02).
  {id:'eng-nextgen',name:'PREM Next Gen U18',cat:'C',from:'eng-prem',level:.6,stages:[
   {k:'rr',key:'p',size:10,dates:W('08-08','08-14','08-22','10-24','01-02','01-09','01-16','01-23','01-30')},
   {k:'ko',key:'k',from:'p',n:2,dates:W('02-28'),title:true}]},
  {id:'eng-rosslyn',name:'Tournoi scolaire à 7 de Rosslyn Park',cat:'C',from:'eng',level:.35,stages:[{k:'tour',key:'q',dates:W('03-22')}]},
  // PREM Rugby Cup 2025-26 : 10 clubs, 2 poules de 5, 8 matchs, demies et finale (15/03).
  {id:'eng-premcup',name:'PREM Rugby Cup',cat:'E',from:'eng-prem',level:.7,stages:[
   {k:'rr',key:'p',size:5,dates:W('09-12','09-26','10-31','11-07','11-28','12-05','01-30','02-06','02-20','02-27')},
   {k:'ko',key:'k',from:'p',n:4,dates:W('03-07','03-15'),title:true}]},
  // Irlande — interprovinciaux PwC 2026 (U18 écoles : 6 journées, U19 : 3 journées), en août.
  {id:'irl-u18',name:'Interprovinciaux U18',cat:'C',from:'irl',level:.6,stages:[
   {k:'rr',key:'p',size:4,dates:W('08-08','08-12','08-16','08-22','08-26','08-30'),title:true}]},
  {id:'irl-u19',name:'Interprovinciaux U19',cat:'E',from:'irl',level:.6,stages:[
   {k:'rr',key:'p',size:4,dates:W('08-15','08-22','08-29'),title:true}]},
  // Pays de Galles — championnat régional U18 des académies (phase d'été, reprise en janvier, finales 4/02).
  {id:'wal-u18',name:'Championnat des académies U18',cat:'C',from:'wal',level:.6,stages:[
   {k:'rr',key:'p',size:4,dates:W('08-16','08-23','08-30','01-03','01-10','01-17')},
   {k:'ko',key:'k',from:'p',n:2,dates:W('02-04'),title:true}]},
  {id:'wal-u19',name:'Championnat des académies U19',cat:'E',from:'wal',level:.6,stages:[
   {k:'rr',key:'p',size:4,dates:W('07-18','07-25','08-01')},{k:'ko',key:'k',from:'p',n:2,dates:W('08-08'),title:true}]},
  // Écosse — deux académies : rencontres entre elles (estimé), le reste en écoles/clubs.
  {id:'sco-derby',name:'Rencontres des académies écossaises',cat:'C',from:'sco',level:.5,stages:[{k:'rr',key:'p',size:2,dates:W('08-22','01-09')}]},
  {id:'sco-derby-e',name:'Rencontres des académies écossaises',cat:'E',from:'sco',level:.5,stages:[{k:'rr',key:'p',size:2,dates:W('08-15','01-16')}]},
  // Italie — championnat national U18 Élite (adversaires : clubs du championnat).
  {id:'ita-u18',name:'Campionato Under 18 Élite',cat:'C',from:'ita',level:.5,virtual:'Club du championnat U18',stages:[
   {k:'virtual',key:'v',dates:W('09-27','10-04','10-11','10-25','11-08','11-15','11-29','12-13','01-17','01-31','02-14','02-28','03-14','03-28')}]},
  // Afrique du Sud — Craven Week (6-11 juillet 2026) et championnat provincial U21.
  {id:'rsa-craven',name:'Craven Week',cat:'C',from:'rsa',level:.6,stages:[{k:'rr',key:'p',size:5,dates:W('07-06','07-08','07-11')}]},
  {id:'rsa-u21',name:'Championnat provincial U21',cat:'E',from:'rsa',level:.6,stages:[
   {k:'rr',key:'p',size:5,dates:W('07-25','08-01','08-08','08-15','08-22')},{k:'ko',key:'k',from:'p',n:4,dates:W('09-05','09-12'),title:true}]},
  // Nouvelle-Zélande / Pacifique — Super Rugby U20 (Taupō, mars : 3 matchs par équipe).
  {id:'nz-su20',name:'Super Rugby U20',cat:'E',from:'nzl+fij',level:.65,stages:[{k:'rr',key:'p',size:6,dates:W('03-14','03-17','03-21'),title:true}]},
  // Australie — Super Rugby Next Gen 2026 (4 équipes, 3 journées en février).
  {id:'aus-nextgen',name:'Super Rugby Next Gen',cat:'E',from:'aus',level:.65,stages:[{k:'rr',key:'p',size:4,dates:W('02-07','02-14','02-21'),title:true}]},
  // Japon — aucun championnat de centres : rencontres entre centres (inventé) + lycées/clubs.
  {id:'jpn-centres',name:'Rencontres des centres japonais',cat:'C',from:'jpn',level:.5,stages:[{k:'friendly',key:'f',dates:W('09-12','10-17','11-21','02-13','03-20','04-17')}]},
  {id:'jpn-centres-e',name:'Rencontres des centres japonais',cat:'E',from:'jpn',level:.5,stages:[{k:'friendly',key:'f',dates:W('09-19','10-24','11-28','02-20','03-27','04-24')}]},
  // Matchs amicaux d'été (décision de Léo) : entre centres du même pays, sinon contre un club local.
  {id:'amical-c',name:'Match amical d’été',cat:'C',from:'all',level:.4,stages:[{k:'friendly',key:'f',dates:W('08-01')}]},
  {id:'amical-e',name:'Match amical d’été',cat:'E',from:'all',level:.4,stages:[{k:'friendly',key:'f',dates:W('07-25','08-08')}]}];
 // Compléments simulés (matchs de clubs/écoles) jusqu'à ~20 matchs par équipe.
 const FILL={
  fr:{C:'Pôle Espoirs régional',E:'Équipe réserve fédérale'},
  'eng-prem':{C:'École (1st XV)',E:'Club partenaire (double licence)'},'eng-champ':{C:'École (1st XV)',E:'Club partenaire (double licence)'},
  irl:{C:'École (Schools Cup)',E:'Club de l’All-Ireland League'},wal:{C:'École ou collège',E:'Club de Super Rygbi Cymru'},
  sco:{C:'École ou club régional',E:'Club de Super Series'},ita:{C:'Club du championnat U18',E:'Club de Serie A Élite'},
  rsa:{C:'École (1st XV)',E:'Club universitaire ou provincial'},nzl:{C:'Lycée (1st XV)',E:'Club local'},aus:{C:'Lycée (1st XV)',E:'Club local'},
  fij:{C:'Lycée (Deans Trophy)',E:'Club local'},jpn:{C:'Lycée',E:'Club amateur'},geo:{C:'Club de jeunes',E:'Club du championnat'},other:{C:'Club local',E:'Club local'}};
 const URC={ulster:'irl',leinster:'irl',munster:'irl',connacht:'irl',glasgow:'sco',edinburgh:'sco',cardiff:'wal',dragons:'wal',ospreys:'wal',scarlets:'wal',benetton:'ita',zebre:'ita',stormers:'rsa',bulls:'rsa',sharks:'rsa',lions:'rsa',cheetahs:'rsa'};

 // ---------------------------------------------------------------- outils d'état
 const active=s=>!!s&&s.academyGroupPolicy===3&&!!s.development&&Array.isArray(s.aiRoster?.academies)&&s.nativeAcademy?.version!==2&&Array.isArray(s.clubs)&&!!s.clubs[s.club];
 const world=s=>typeof CDWorldCareer!=='undefined'&&CDWorldCareer.active(s);
 function today(s){
  if(world(s)){const d=Date.parse(CDWorldCareer.calendarToday(s)+'T00:00:00Z');return Number.isFinite(d)?Math.floor(d/DAY):null;}
  const week=s.franceMode?.week??s.round??0,y=year(s),first=Date.UTC(y,8,1),wd=new Date(first).getUTCDay();
  return Math.floor(first/DAY)+(8-wd)%7+week*7+5;
 }
 function academy(s,clubId){if(clubId===s.club)return s.development.academy;return s.aiRoster.academies.find(a=>a.clubId===clubId)?.players||null;}
 const inCat=(p,cat)=>cat==='C'?p.age<=17:p.age>=18&&p.age<=21;
 const regionMemo=new WeakMap();
 function region(s,club){
  if(!world(s))return 'fr';
  let memo=regionMemo.get(s);if(!memo)regionMemo.set(s,memo=new Map());
  if(!memo.has(club.id))memo.set(club.id,regionOf(s,club));return memo.get(club.id);
 }
 function regionOf(s,club){
  const ed=typeof CDWorldEditions!=='undefined'?CDWorldEditions.forState(s):null,row=ed?.registry?.clubs?.find(c=>c.id===club.id);
  const league=CDWorldCareer.leagueId(s,club.id),slug=String(row?.slug||''),country=row?.country;
  if(['elite','accession','nationale'].includes(league)||country==='FR')return 'fr';
  if(league==='prem')return 'eng-prem';if(league==='champ')return 'eng-champ';
  if(league==='jlo-d1'||league==='jlo-d2'||country==='JP')return 'jpn';
  for(const [key,r]of Object.entries(URC))if(slug.includes(key))return r;
  if(country==='NZ')return 'nzl';if(country==='AU')return 'aus';if(country==='FJ')return 'fij';if(country==='ZA')return 'rsa';if(country==='GE')return 'geo';if(country==='IE')return 'irl';if(country==='IT')return 'ita';
  return 'other';
 }
 const divisionRank=(s,id)=>{if(!world(s))return 0;const l=CDWorldCareer.leagueId(s,id);return l==='elite'?0:l==='accession'?1:l==='nationale'?2:3;};
 // Ligne de charge par joueur : [saison, matchs, titularisations, minutes, fatigue, jours de
 // blessure, reprise (<0 en attente, >0 matchs de retour progressif), sélections, essais, dernier jour].
 function load(s,p){
  let y=p.youthLoad;
  if(!Array.isArray(y)||y.length!==10){y=p.youthLoad=[s.season,0,0,0,0,(p.injury|0)*7,0,0,0,0];}
  if(y[0]!==s.season){y[0]=s.season;y[1]=y[2]=y[3]=y[7]=y[8]=0;}
  return y;
 }
 function refresh(s,p,day){
  const y=load(s,p);if(!y[9]){y[9]=day;if(p.injury&&!y[5])y[5]=p.injury*7;return y;}
  const gap=day-y[9];if(gap<=0)return y;
  y[9]=day;y[4]=Math.max(0,Math.round(y[4]-2.5*gap));
  if(y[5]>0){y[5]=Math.max(0,y[5]-gap);p.injury=Math.ceil(y[5]/7);if(!y[5]&&y[6]<0)y[6]=-y[6];}
  else if(p.injury>0){y[5]=Math.max(0,p.injury*7-gap);p.injury=Math.ceil(y[5]/7);}
  return y;
 }
 // Sélections : compteur du chantier des sélections jeunes (CDYouthNational, #636) quand il est
 // chargé, sinon celui alimenté par recordSelection. Le plus grand des deux évite un double compte.
 function national(s,p){
  try{if(typeof CDYouthNational==='undefined'||!CDYouthNational||typeof CDYouthNational.matches!=='function')return null;const n=CDYouthNational.matches(s,p.id,s.season);return Number.isSafeInteger(n)&&n>=0?n:null;}catch(e){return null;}
 }
 const selections=(s,p,y)=>{const n=national(s,p);return n===null?y[7]:Math.max(y[7],n);};
 const total=(y,s,p)=>y[1]+(s&&p?selections(s,p,y):y[7]);

 // ---------------------------------------------------------------- calendrier de la saison
 function strength(players){const r=players.map(p=>p.rating).sort((a,b)=>b-a).slice(0,23);return r.length?r.reduce((a,b)=>a+b,0)/r.length:0;}
 function members(s,spec,regions){
  let ids=spec.from==='all'?Object.values(regions).flat():spec.from.split('+').flatMap(r=>r==='eng'?[...(regions['eng-prem']||[]),...(regions['eng-champ']||[])]:(regions[r]||[]));
  if(spec.take)ids=ids.slice(spec.take[0],spec.take[1]);
  return ids.filter(id=>(academy(s,id)||[]).filter(p=>inCat(p,spec.cat)).length>=15);
 }
 function snake(ids,size,salt){
  const count=Math.max(1,Math.round(ids.length/size)),pools=Array.from({length:count},()=>[]);
  ids.forEach((id,i)=>{const lap=Math.floor(i/count),k=i%count;pools[lap%2?count-1-k:k].push(id);});
  return pools.map(p=>p.sort((a,b)=>hash(salt+a)-hash(salt+b)));
 }
 function setup(s){
  const regions={},str={};
  const clubs=s.clubs.filter(c=>academy(s,c.id));
  for(const c of clubs){const r=region(s,c);(regions[r]=regions[r]||[]).push(c.id);for(const cat of ['C','E'])str[c.id+cat]=strength(academy(s,c.id).filter(p=>inCat(p,cat)));}
  const base=id=>s.clubs[id].base||0;
  if(regions.fr)regions.fr.sort((a,b)=>divisionRank(s,a)-divisionRank(s,b)||base(b)-base(a)||a-b);
  const comps={};
  for(const spec of CATALOG){
   const ids=members(s,spec,regions);if(!ids.length)continue;
   const first=spec.stages[0],seeded=ids.slice().sort((a,b)=>str[b+spec.cat]-str[a+spec.cat]||a-b);
   comps[spec.id]={m:ids,pools:first.k==='rr'?{[first.key]:snake(seeded,first.size,spec.id+s.season)}:{},t:{},ko:{},champ:null};
  }
  purgePotential(s);
  s.youthMatches={version:1,season:s.season,day:Math.floor(Date.UTC(year(s),6,1)/DAY)-1,comps,own:{C:[],E:[]},history:(s.youthMatches?.history||[]).filter(r=>r[0]>s.season-HISTORY_SEASONS)};
 }
 // Purge annuelle du suivi du potentiel : les jeunes partis (libérés, retraités, disparus) ne
 // gardent pas de ligne. Même critère que la purge du module à 32 000 lignes, appliqué chaque
 // saison ; un nouvel objet est créé pour que l'index en cache du module soit reconstruit.
 function purgePotential(s){
  const st=s.potentialEvolution;if(!object(st)||!Array.isArray(st.records))return 0;
  const alive=new Set([...(s.clubs||[]).flatMap(c=>c.players||[]),...(s.development?.academy||[]),...(s.economy?.freeAgents||[]),...(s.market||[]),...(s.aiRoster?.academies||[]).flatMap(a=>a.players||[]),...(s.nativeAcademy?.centers||[]).flatMap(c=>c.players||[])].map(p=>p.id));
  const rows=st.records.flat(),kept=rows.filter(r=>alive.has(r[0]));if(kept.length===rows.length)return 0;
  const records=[];for(const r of kept){if(!records.length||records.at(-1).length===2000)records.push([]);records.at(-1).push(r);}
  s.potentialEvolution={version:st.version,records};return rows.length-kept.length;
 }
 const specOf=id=>CATALOG.find(c=>c.id===id);
 // Tour de table (méthode du cercle) : rondes de paires ; aller-retour si assez de dates.
 function rounds(pool,dates){
  const ids=pool.slice();if(ids.length%2)ids.push(null);const n=ids.length,out=[];
  for(let r=0;r<n-1;r++){const pairs=[];for(let i=0;i<n/2;i++){const a=ids[i],b=ids[n-1-i];if(a!==null&&b!==null)pairs.push(r%2?[b,a]:[a,b]);}out.push(pairs);ids.splice(1,0,ids.pop());}
  const both=dates>=2*out.length?out.concat(out.map(r=>r.map(([a,b])=>[b,a]))):out;
  return both.slice(0,dates);
 }
 const cache=new WeakMap();
 const stageDates=stage=>stage.k==='split'?[...new Set(stage.upper.dates.concat(stage.lower.dates))]:stage.dates;
 // Programme : jour → événements. Recalculé à partir de l'état (aucun match futur stocké).
 function schedule(s){
  const st=s.youthMatches;let c=cache.get(st);if(c&&c.season===st.season)return c;
  const y=year(s),events=new Map(),known=new Map(),add=(day,e)=>{if(!events.has(day))events.set(day,[]);events.get(day).push(e);};
  const mark=(id,cat,day)=>{const k=id+cat;if(!known.has(k))known.set(k,{days:[],count:0});known.get(k).days.push(day);};
  const counted=(id,cat,n=1)=>{const k=id+cat;if(!known.has(k))known.set(k,{days:[],count:0});known.get(k).count+=n;};
  for(const [id,comp]of Object.entries(st.comps)){
   const spec=specOf(id);if(!spec)continue;
   spec.stages.forEach((stage,si)=>{
    const days=stageDates(stage).map(md=>dayOf(y,md));
    days.forEach((day,di)=>add(day,{comp:id,si,di}));
    if(stage.k==='rr'){for(const pool of comp.pools[stage.key]||[]){const rs=rounds(pool,days.length);for(const pid of pool){days.forEach(d=>mark(pid,spec.cat,d));counted(pid,spec.cat,rs.filter(r=>r.some(p=>p.includes(pid))).length);}}}
    else if(stage.k==='split'){for(const pid of comp.m){stage.upper.dates.concat(stage.lower.dates).forEach(md=>mark(pid,spec.cat,dayOf(y,md)));counted(pid,spec.cat,stage.upper.dates.length);}}
    else if(stage.k==='ko'){for(const pid of comp.m)days.forEach(d=>mark(pid,spec.cat,d));}
    else for(const pid of comp.m){days.forEach(d=>mark(pid,spec.cat,d));if(!stage.top)counted(pid,spec.cat,days.length);}
   });
  }
  // Compléments : samedis de fin août à fin mai, à 6 jours au moins des autres rencontres.
  const saturdays=[];for(let d=dayOf(y,'08-20');d<=dayOf(y,'05-31');d++)if(new Date(d*DAY).getUTCDay()===6)saturdays.push(d);
  for(const club of s.clubs){if(!academy(s,club.id))continue;for(const cat of ['C','E']){
   const k=club.id+cat,info=known.get(k)||{days:[],count:0},need=TARGET-info.count;if(need<=0)continue;
   const free=saturdays.filter(d=>info.days.every(x=>Math.abs(x-d)>=6));
   for(let i=0;i<need&&i<free.length;i++){const day=free[Math.floor((i+.5)*free.length/Math.min(need,free.length))];add(day,{fill:club.id,cat});}
  }}
  c={season:st.season,events,days:[...events.keys()].sort((a,b)=>a-b)};cache.set(st,c);return c;
 }

 // ---------------------------------------------------------------- moteur de résultat rapide
 const BENCH=[1,0,2,3,5,8,9,10],ORDER=[1,0,2,8,9,3,4,7,5,6,14,11,12,10,13];
 function fit(p,slot){
  if(p.pos===POS[slot])return 0;const fam=typeof FAMILIES!=='undefined'?FAMILIES[slot]:slot;
  if(slot<=2)return p.fam===fam||(p.fam===0&&slot!==1)?-6:-60;
  return p.fam===fam?-4:(p.fam<=3)===(fam<=3)?-14:-24;
 }
 function select(s,clubId,cat,day,used,r){
  const all=academy(s,clubId)||[];let pool=all.filter(p=>inCat(p,cat)&&!used.has(p.id));
  for(const p of pool)refresh(s,p,day);
  pool=pool.filter(p=>!(load(s,p)[5]>0)&&total(load(s,p),s,p)<CAP);
  // Surclassement : des Crabos de 17 ans complètent un groupe Espoirs trop court.
  if(cat==='E'&&pool.length<23)pool=pool.concat(all.filter(p=>p.age===17&&!used.has(p.id)).filter(p=>{refresh(s,p,day);const y=load(s,p);return !(y[5]>0)&&total(y,s,p)<CAP;}).sort((a,b)=>b.rating-a.rating).slice(0,23-pool.length));
  // Valeur du jour : niveau, fatigue, charge de la saison et petit aléa de rotation (une fois par joueur).
  const base=new Map(),ramp=new Set();
  for(const p of pool){const y=load(s,p);base.set(p,p.rating-Math.max(0,y[4]-35)*.5-Math.max(0,y[1]-18)*2.5-(y[1]>=RISK_FROM?6:0)+r()*2.5);if(y[6]>0)ramp.add(p);}
  const xv=Array(15).fill(null),bench=[],taken=new Set();
  const pick=(slot,starter)=>{let best=null,bs=-1e9;for(const [p,v0]of base){if(taken.has(p))continue;const v=v0+fit(p,slot)-(starter&&ramp.has(p)?8:0);if(v>bs){bs=v;best=p;}}if(best)taken.add(best);return best;};
  for(const slot of ORDER)xv[slot]=pick(slot,true);
  for(const slot of BENCH){const p=pick(slot,false);if(p)bench.push([slot,p]);}
  for(const p of taken)used.add(p.id);
  const starters=xv.filter(Boolean),missing=15-starters.length;
  const level=starters.length?xv.reduce((n,p,slot)=>p?n+p.rating+Math.max(-12,fit(p,slot)*.5):n,0)/starters.length:40;
  return {xv,bench,strength:level-missing*3+(bench.length?bench.reduce((n,[,p])=>n+p.rating,0)/bench.length-level:0)*.15};
 }
 function poisson(r,l){let k=0,p=Math.exp(-l),f=p,u=r();while(u>f&&k<15){k++;p*=l/k;f+=p;}return k;}
 function score(r,a,b,neutral){
  const diff=a-b+(neutral?0:2.5);
  const ta=poisson(r,clamp(3+diff*.13,.4,9)),tb=poisson(r,clamp(3-diff*.13,.4,9));
  const pts=t=>{let n=t*5;for(let i=0;i<t;i++)if(r()<.68)n+=2;return n+poisson(r,1.3)*3;};
  return {score:[pts(ta),pts(tb)],tries:[ta,tb]};
 }
 function minutes(sel,r,cap){
  const m=new Map();sel.xv.forEach(p=>{if(p)m.set(p,80);});
  for(const [slot,p]of sel.bench){
   if(r()>(slot<=2?.92:.8))continue;const mins=slot<=2?18+Math.floor(r()*20):8+Math.floor(r()*24);
   const candidates=slot===10?[10,11,12,13,14]:slot===3?[3,4]:slot===5?[5,6,7]:[slot],out=sel.xv[candidates[Math.floor(r()*candidates.length)]];
   if(out&&m.get(out)===80)m.set(out,80-mins);m.set(p,mins);
  }
  for(const [p,v]of m){const y=p.youthLoad;if(y&&y[6]>0)m.set(p,Math.min(v,cap));}
  return m;
 }
 const TRY_WEIGHT=[.5,.6,.5,.6,.6,1.3,1.3,1.6,1.4,1,3,2,2,3,2.4];
 function apply(s,clubId,sel,mins,tries,level,r,day,label){
  const starters=new Set(sel.xv.filter(Boolean).map(p=>p.id)),out=[];
  const weights=[];sel.xv.forEach((p,slot)=>{if(p&&mins.get(p))weights.push([p,TRY_WEIGHT[slot]*mins.get(p)]);});for(const [slot,p]of sel.bench)if(mins.get(p))weights.push([p,TRY_WEIGHT[slot]*mins.get(p)]);
  const scorers=new Map(),tw=weights.reduce((n,[,w])=>n+w,0);
  for(let t=0;t<tries&&tw>0;t++){let u=r()*tw;for(const [p,w]of weights){u-=w;if(u<=0){scorers.set(p,(scorers.get(p)||0)+1);break;}}}
  for(const [p,m]of mins){
   if(!m)continue;const y=load(s,p);
   y[1]++;if(starters.has(p.id))y[2]++;y[3]+=m;y[8]+=scorers.get(p)||0;if(y[6]>0)y[6]--;
   const condition=100-y[4];y[4]=Math.min(100,Math.round(y[4]+m*.4));
   // Même risque que les pros (2,5 % par 80 min, 7 % fatigué), majoré au-delà de 25 matchs.
   const risk=(condition<55?.07:.025)*m/80*(y[1]>RISK_FROM?1.5:1);
   if(r()<risk){
    const u=r(),weeks=u<.88?1+Math.floor(r()*4):5+Math.floor(r()*12);y[5]=weeks*7;p.injury=weeks;if(weeks>=5)y[6]=-3;
    if(clubId===s.club&&weeks>=5&&typeof news==='function')news(`${p.name} (centre de formation) se blesse ${label?'contre '+label:'en match'} : ${weeks} semaines d’absence, puis reprise progressive.`);
   }
   if(typeof growPlayer==='function'&&p.dev){
    p.dev.minutes+=m;p.dev.careerMinutes=(p.dev.careerMinutes||0)+m;p.dev.appearances++;
    const fit=typeof growthFitnessFactor==='function'?growthFitnessFactor(p):1,age=typeof ageGrowth==='function'?ageGrowth(p):1;
    growPlayer(p,m/80*.12*level*age*Math.max(.5,condition/100)*fit,true);
   }
   out.push([p,m]);
  }
  return {played:out,scorers};
 }
 function evidence(s,sides,result){
  if(typeof nativePotentialEvolution==='undefined')return;
  const teams=sides.map((side,i)=>side.played?{players:side.played.map(([p])=>p)}:{players:[{id:'virtuel',rating:side.strength}]});
  const sheets=sides.map(side=>side.played?{used:side.played.map(([p])=>p.id),minutes:Object.fromEntries(side.played.map(([p,m])=>[p.id,m]))}:{used:['virtuel'],minutes:{virtuel:80}});
  const rows=[];sides.forEach((side,i)=>{if(side.scorers)for(const [p,n]of side.scorers)rows.push([p.id,i,Math.min(500,n*1.2)]);});
  nativePotentialEvolution.match(s,{finished:true,pair:[0,1],score:result.score,sheets,events:[],potentialEvidence:{version:1,rows}},teams);
 }
 // Joue une rencontre ; b === null : adversaire simulé (club, école, sélection régionale).
 function play(s,spec,a,b,day,used,opts={}){
  const st=s.youthMatches,r=rng(hash([st.season,spec.id,a,b,day].join(':')));
  const sa=select(s,a,spec.cat,day,used,r),sb=b===null?null:select(s,b,spec.cat,day,used,r);
  const vs=b===null?sa.strength-1+(r()-.5)*8+(opts.stronger?2:0):sb.strength;
  const result=score(r,sa.strength,vs,!!opts.neutral);
  const cap=opts.short?40:50,level=spec.level*(opts.short?.6:1);
  const label=b===null?(opts.label||'un club local'):s.clubs[b]?.name;
  const ma=minutes(sa,r,cap);if(opts.short)for(const [p,v]of ma)ma.set(p,Math.min(v,36));
  const A=apply(s,a,sa,ma,result.tries[0],level,r,day,label);
  let B=null;if(sb){const mb=minutes(sb,r,cap);if(opts.short)for(const [p,v]of mb)mb.set(p,Math.min(v,36));B=apply(s,b,sb,mb,result.tries[1],level,r,day,s.clubs[a]?.name);}
  if(!opts.short)evidence(s,[{...A,strength:sa.strength},B?{...B,strength:sb.strength}:{strength:vs}],result);
  for(const [side,club,opp]of [[0,a,b],[1,b,a]]){
   if(club!==s.club)continue;
   const list=st.own[spec.cat];list.push([day,spec.id,opp===null?-1:opp,side===0?1:0,result.score[side],result.score[1-side]]);
   if(list.length>OWN_RESULTS)list.splice(0,list.length-OWN_RESULTS);
  }
  return result;
 }
 // ---------------------------------------------------------------- phases
 function table(comp,key,pools){if(!comp.t[key])comp.t[key]=pools.map(pool=>pool.map(id=>[id,0,0,0,0,0,0,0]));return comp.t[key];}
 function record(comp,key,a,b,res){
  for(const pool of comp.t[key]||[])for(const row of pool){
   const side=row[0]===a?0:row[0]===b?1:-1;if(side<0)continue;
   const pf=res.score[side],pa=res.score[1-side],tf=res.tries[side],ta=res.tries[1-side];
   row[1]++;row[5]+=pf;row[6]+=pa;
   if(pf>pa){row[2]++;row[7]+=4+(tf>=ta+3?1:0);}else if(pf===pa){row[3]++;row[7]+=2;}else{row[4]++;row[7]+=pa-pf<=5?1:0;}
  }
 }
 const sorted=pool=>pool.slice().sort((x,y)=>y[7]-x[7]||(y[5]-y[6])-(x[5]-x[6])||y[5]-x[5]||x[0]-y[0]);
 function ranking(comp,key){
  const pools=(comp.t[key]||[]).map(sorted),out=[],depth=Math.max(0,...pools.map(p=>p.length));
  for(let i=0;i<depth;i++)out.push(...pools.map(p=>p[i]).filter(Boolean).sort((x,y)=>y[7]-x[7]||(y[5]-y[6])-(x[5]-x[6])||x[0]-y[0]));
  return out.map(r=>r[0]);
 }
 function strengthNow(s,id,cat){return strength((academy(s,id)||[]).filter(p=>inCat(p,cat)));}
 function runEvent(s,e,day,used){
  const st=s.youthMatches,comp=st.comps[e.comp],spec=specOf(e.comp),stage=spec.stages[e.si];
  if(stage.k==='rr'){
   const pools=comp.pools[stage.key]||[];table(comp,stage.key,pools);
   for(const pool of pools){const r=rounds(pool,stage.dates.length)[e.di]||[];for(const [a,b]of r)record(comp,stage.key,a,b,play(s,spec,a,b,day,used));}
   if(stage.title&&e.di===stage.dates.length-1&&pools.length===1)crown(s,e.comp,ranking(comp,stage.key)[0]);
  }else if(stage.k==='split'){
   const sub=[stage.upper,stage.lower];
   if(!comp.pools[stage.upper.key]){
    const order=ranking(comp,stage.from),cut=Math.round(order.length*stage.share);
    comp.pools[stage.upper.key]=snake(order.slice(0,cut),stage.upper.size,e.comp+'u'+st.season);
    comp.pools[stage.lower.key]=snake(order.slice(cut),stage.lower.size,e.comp+'l'+st.season);
   }
   for(const part of sub){const idx=part.dates.findIndex(md=>dayOf(year(s),md)===day);if(idx<0)continue;const pools=comp.pools[part.key];table(comp,part.key,pools);
    for(const pool of pools){const r=rounds(pool,part.dates.length)[idx]||[];for(const [a,b]of r)record(comp,part.key,a,b,play(s,spec,a,b,day,used));}}
  }else if(stage.k==='ko'){
   if(e.di===0||!comp.ko[stage.key]){let order=ranking(comp,stage.from);let n=1;while(n*2<=Math.min(stage.n,order.length))n*=2;comp.ko[stage.key]=n>=2?order.slice(0,n):[];}
   const alive=comp.ko[stage.key];if(alive.length<2)return;
   const next=[];
   for(let i=0;i<alive.length/2;i++){
    const a=alive[i],b=alive[alive.length-1-i],res=play(s,spec,a,b,day,used,{neutral:true});
    const win=res.score[0]!==res.score[1]?(res.score[0]>res.score[1]?a:b):(res.tries[0]!==res.tries[1]?(res.tries[0]>res.tries[1]?a:b):(hash(a+':'+b+':'+day)%2?a:b));
    next.push(win);
   }
   comp.ko[stage.key]=next;
   if(next.length===1&&stage.title)crown(s,e.comp,next[0]);
  }else if(stage.k==='tour'){
   let ids=comp.m.slice();if(stage.top)ids=ids.sort((x,y)=>strengthNow(s,y,spec.cat)-strengthNow(s,x,spec.cat)||x-y).slice(0,stage.top);
   // Tournoi à 7 : une seule ligne dans le plafond (un tournoi = un match), temps de jeu court.
   const r=rng(hash(st.season+':'+e.comp+':'+day)),strengthBy=new Map();
   for(const id of ids){const sel=select(s,id,spec.cat,day,used,r);strengthBy.set(id,sel.strength+r()*6);const ms=minutes({xv:sel.xv.slice(0,12),bench:[]},r,40);for(const [p]of ms)ms.set(p,28+Math.floor(r()*14));apply(s,id,{xv:sel.xv.slice(0,12),bench:[]},ms,poisson(r,2),spec.level,r,day,'');}
   if(stage.title&&ids.length)crown(s,e.comp,ids.slice().sort((x,y)=>strengthBy.get(y)-strengthBy.get(x))[0]);
  }else if(stage.k==='virtual'){
   for(const id of comp.m)play(s,spec,id,null,day,used,{label:spec.virtual});
  }else if(stage.k==='friendly'){
   const ids=comp.m.slice().sort((x,y)=>hash(st.season+':'+day+':'+x)-hash(st.season+':'+day+':'+y)),regionsBy=new Map(ids.map(id=>[id,region(s,s.clubs[id])]));
   const left=new Set(ids);
   for(const a of ids){if(!left.has(a))continue;left.delete(a);const b=[...left].find(x=>regionsBy.get(x)===regionsBy.get(a));if(b!==undefined)left.delete(b);
    play(s,spec,a,b??null,day,used,{label:FILL[regionsBy.get(a)]?.[spec.cat]||'un club local'});}
  }
 }
 function crown(s,compId,clubId){
  const st=s.youthMatches,comp=st.comps[compId];if(clubId===undefined||comp.champ!==null)return;comp.champ=clubId;
  st.history.push([st.season,compId,clubId]);
  if(clubId===s.club&&typeof news==='function')news(`Titre pour le centre de formation : ${specOf(compId).name} ${year(s)}-${year(s)+1} remporté par nos ${specOf(compId).cat==='C'?'Crabos':'Espoirs'}.`);
 }
 // Avance le calendrier des jeunes jusqu'au jour donné (inclus).
 function process(s,until){
  if(!active(s)||s.live)return 0;
  if(s.youthMatches?.season!==s.season)setup(s);
  const st=s.youthMatches,plan=schedule(s);if(until===null||until===undefined)return 0;
  until=Math.min(until,endOfYear(s));let played=0;
  for(const day of plan.days){
   if(day<=st.day||day>until)continue;
   const used=new Set(),list=plan.events.get(day);
   // Les Crabos jouent avant les Espoirs : un même jeune ne joue qu'une fois par jour.
   for(const cat of ['C','E'])for(const e of list){
    if(e.fill!==undefined){if(e.cat!==cat)continue;play(s,{id:'complement',cat,level:.45},e.fill,null,day,used,{label:FILL[region(s,s.clubs[e.fill])]?.[cat]||'un club local',stronger:cat==='E'});played++;continue;}
    if(specOf(e.comp).cat!==cat)continue;runEvent(s,e,day,used);played++;
   }
   st.day=day;
  }
  if(until>st.day)st.day=until;
  for(const a of [s.development.academy,...s.aiRoster.academies.map(x=>x.players)])for(const p of a)refresh(s,p,st.day);
  return played;
 }
 // ---------------------------------------------------------------- interface sélections
 // Le chantier des sélections nationales jeunes appelle recordSelection pour chaque match
 // international : il compte dans le plafond de 30 et dans la fatigue.
 function findYouth(s,id){for(const a of [s.development.academy,...s.aiRoster.academies.map(x=>x.players)]){const p=a.find(x=>x.id===id);if(p)return p;}return null;}
 function recordSelection(s,playerId,mins=80){
  const p=findYouth(s,playerId);if(!p||!int(mins,0,80))return false;
  const y=load(s,p);if(total(y,s,p)>=CAP)return false;y[7]++;y[4]=Math.min(100,Math.round(y[4]+mins*.4));return true;
 }
 function matches(s,p){const y=Array.isArray(p?.youthLoad)&&p.youthLoad[0]===s.season?p.youthLoad:[s.season,0,0,0,0,0,0,0,0,0],sel=selections(s,p,y),all=y[1]+sel;return {club:y[1],selection:sel,total:all,cap:CAP,available:all<CAP&&!(y[5]>0)};}
 // Branchement de la page de suivi du centre (#626, academy-follow-up.cjs) : nombre de matchs
 // comptés pour le plafond (club + sélection) et résumé des compétitions du club joué.
 function appearances(s,playerId){const p=s?.development?.academy?.find(x=>x.id===playerId)||(s?findYouth(s,playerId):null);return p?matches(s,p).total:null;}
 function summary(s){
  if(!active(s)||!s.youthMatches)return null;const view=projectFor(s);
  return {season:view.season,date:view.date,competitions:view.competitions.map(c=>({id:c.id,name:c.name,category:c.category,champion:c.champion,standings:c.tables.flatMap(t=>t.rows.map(r=>({...r,phase:t.phase}))),
   results:(c.category==='Crabos'?view.results.crabos:view.results.espoirs).filter(r=>r.competition===c.name)})),results:view.results,upcoming:view.upcoming};
 }

 // ---------------------------------------------------------------- projection, validation, crochets
 function project(){return projectFor(typeof S==='undefined'?null:S);}
 function projectFor(s){
  if(!active(s)||!s.youthMatches)return {available:false};
  const st=s.youthMatches,name=id=>id<0?null:s.clubs[id]?.name||null,mine=[];
  for(const [id,comp]of Object.entries(st.comps)){
   if(!comp.m.includes(s.club))continue;const spec=specOf(id);
   const tables=Object.entries(comp.t).map(([key,pools])=>({phase:key,rows:(pools.find(p=>p.some(r=>r[0]===s.club))||[]).length?sorted(pools.find(p=>p.some(r=>r[0]===s.club))).map(r=>({club:name(r[0]),own:r[0]===s.club,played:r[1],won:r[2],drawn:r[3],lost:r[4],for:r[5],against:r[6],points:r[7]})):[]})).filter(t=>t.rows.length);
   mine.push({id,name:spec.name,category:spec.cat==='C'?'Crabos':'Espoirs',tables,champion:name(comp.champ??-1)});
  }
  const results=cat=>st.own[cat].map(([day,comp,opp,home,pf,pa])=>({date:iso(day),competition:specOf(comp)?.name||'Match de club ou d’école',opponent:opp<0?(FILL[region(s,s.clubs[s.club])]?.[cat]||'Club local'):name(opp),home:!!home,for:pf,against:pa}));
  const plan=schedule(s),upcoming=plan.days.filter(d=>d>st.day).slice(0,40).flatMap(day=>plan.events.get(day).filter(e=>e.fill===s.club||e.comp&&st.comps[e.comp].m.includes(s.club)).map(e=>({date:iso(day),competition:e.fill!==undefined?'Match de club ou d’école':specOf(e.comp).name,category:(e.cat||specOf(e.comp).cat)==='C'?'Crabos':'Espoirs'}))).slice(0,6);
  const players=s.development.academy.map(p=>{const y=Array.isArray(p.youthLoad)&&p.youthLoad[0]===s.season?p.youthLoad:[0,0,0,0,0,0,0,0,0,0];return {id:p.id,matches:y[1],starts:y[2],minutes:y[3],tries:y[8],selection:selections(s,p,y),cap:CAP,fatigue:y[4],injuredWeeks:Math.ceil(y[5]/7),returning:y[6]>0?y[6]:0};});
  return {available:true,season:st.season,date:iso(st.day),competitions:mine,results:{crabos:results('C'),espoirs:results('E')},upcoming,players,titles:st.history.filter(r=>r[2]===s.club).map(([season,comp])=>({season,competition:specOf(comp)?.name||comp}))};
 }
 function validate(s){
  const fail=m=>{throw Error('Matchs des jeunes : '+m+'.');},check=(ok,m)=>{if(!ok)fail(m);};
  for(const a of [s?.development?.academy||[],...(s?.aiRoster?.academies||[]).map(x=>x.players||[])])for(const p of a){
   if(p.youthLoad===undefined)continue;const y=p.youthLoad;
   check(Array.isArray(y)&&y.length===10&&y.every(v=>Number.isSafeInteger(v))&&int(y[0],1,s.season)&&int(y[1],0,CAP)&&int(y[2],0,y[1])&&int(y[3],0,CAP*80)&&int(y[4],0,100)&&int(y[5],0,400)&&int(y[6],-3,3)&&int(y[7],0,CAP)&&int(y[8],0,400)&&y[9]>=0,'charge de joueur invalide');
  }
  const st=s?.youthMatches;if(st===undefined)return true;
  check(object(st)&&Object.keys(st).length===6&&st.version===1&&int(st.season,1,s.season)&&Number.isSafeInteger(st.day)&&object(st.comps)&&object(st.own)&&Array.isArray(st.history),'état invalide');
  check(st.history.length<=HISTORY_SEASONS*CATALOG.length&&st.history.every(r=>Array.isArray(r)&&r.length===3&&int(r[0],1,s.season)&&specOf(r[1])&&int(r[2],0,s.clubs.length-1)),'palmarès invalide');
  check(Object.keys(st.own).length===2&&['C','E'].every(c=>Array.isArray(st.own[c])&&st.own[c].length<=OWN_RESULTS&&st.own[c].every(r=>Array.isArray(r)&&r.length===6&&typeof r[1]==='string'&&[0,2,3,4,5].every(i=>Number.isSafeInteger(r[i])))),'résultats du club invalides');
  for(const [id,c]of Object.entries(st.comps)){
   check(specOf(id)&&object(c)&&Object.keys(c).length===5&&Array.isArray(c.m)&&c.m.length<=s.clubs.length&&c.m.every(x=>int(x,0,s.clubs.length-1))&&object(c.pools)&&object(c.t)&&object(c.ko)&&(c.champ===null||int(c.champ,0,s.clubs.length-1)),'compétition invalide');
   for(const pools of Object.values(c.pools))check(Array.isArray(pools)&&pools.every(p=>Array.isArray(p)&&p.every(x=>c.m.includes(x))),'poules invalides');
   for(const pools of Object.values(c.t))check(Array.isArray(pools)&&pools.every(p=>Array.isArray(p)&&p.every(r=>Array.isArray(r)&&r.length===8&&r.every(Number.isSafeInteger))),'classement invalide');
   for(const alive of Object.values(c.ko))check(Array.isArray(alive)&&alive.every(x=>c.m.includes(x)),'phase finale invalide');
  }
  return true;
 }
 function execute(){throw Error('Les matchs des jeunes sont entièrement simulés.');}
 let installed=false;
 function installHooks(){
  if(installed)return true;installed=true;
  const tick=()=>{try{const s=typeof S==='undefined'?null:S;if(active(s)&&!s.live&&s.phase!=='ended')process(s,today(s));}catch(error){if(typeof console!=='undefined')console.error?.(error);throw error;}};
  for(const name of ['trainWeek','finishRound']){const original=g[name];if(typeof original!=='function')continue;const wrapped=function(){const result=original.apply(this,arguments);tick();return result;};Object.assign(wrapped,original);g[name]=wrapped;}
  // Fin de saison : on joue tout ce qui reste jusqu'au 30 juin avant le vieillissement.
  const advance=g.advanceSeason;if(typeof advance==='function'){const wrapped=function(){const s=typeof S==='undefined'?null:S;if(active(s)&&!s.live)process(s,endOfYear(s));return advance.apply(this,arguments);};Object.assign(wrapped,advance);g.advanceSeason=wrapped;}
  return true;
 }
 const api=Object.freeze({process,setup,today,recordSelection,matches,project,validate,CATALOG,CAP});
 g.CDYouthMatches=api;
 g.CDYouthCompetitions=Object.freeze({appearances,summary});
 return {project,validate,execute,installHooks,process,recordSelection,matches};
}
module.exports={files,commands,factory};

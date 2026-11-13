'use strict';
const files=Object.freeze([]),commands=Object.freeze([]);
// Sélections nationales jeunes (décision de Léo du 13/11/2026) : U20 (~10 matchs par
// saison) et U18 (~6), entièrement simulées, sans composition ni stratégie, chaque
// saison, même sur une carrière de vingt ans.
// Vraies compétitions d'abord : Six Nations U20 (février–mars), U20 Rugby Championship
// (SANZAAR, avril–mai), Championnat du monde U20 à 16 (juin–juillet, Géorgie 2026),
// Trophée / Challenger Cup U20 avec montée et descente, festival Six Nations U18 (Pâques),
// série internationale U18 en Afrique du Sud (août). Matchs amicaux crédibles ensuite,
// pour que chaque nation joue à peu près autant que les autres.
// Une saison de jeu N couvre du 1er août (2025+N) au 31 juillet (2026+N).
// Convocations selon l'âge (U20 : 19 ans au plus ; U18 : 17 ans au plus) et
// l'éligibilité (règle 8 de World Rugby via nativeFacts.eligible) ; un jeune ne joue que
// pour une nation par saison ; les places manquantes sont tenues par des joueurs des
// filières fédérales (sans fiche dans le jeu).
// API pour les matchs de club des jeunes : matches(s, playerId, season) donne le nombre de
// matchs joués en sélection (U18 + U20) pendant la saison ; dates(s, playerId, season)
// donne leurs dates.
function factory(){
 const VERSION=1,BUCKETS=64,KEEP_SEASONS=3;
 const NATIONS=['RSA','NZL','ENG','IRE','FRA','ARG','AUS','FIJ','SCO','ITA','WAL','JPN',
  'GEO','URU','ESP','USA','TGA','CHI','POR','SAM','ROU','CAN','HKG','ZIM'];
 const SIX=['ENG','FRA','IRE','ITA','SCO','WAL'],SANZAAR=['RSA','NZL','AUS','ARG'];
 const JWC_2026=[['RSA','WAL','GEO','URU'],['NZL','ITA','SCO','JPN'],['ENG','IRE','ARG','USA'],['FRA','AUS','ESP','FIJ']];
 const TROPHY_DEFAULT=['CAN','CHI','SAM','TGA','POR','ROU','HKG','ZIM'];
 const TARGET={U20:10,U18:6},SQUAD={U20:28,U18:26},MAX_AGE={U20:19,U18:17},MIN_AGE={U20:17,U18:15};
 const day=86400000;
 const object=x=>!!x&&typeof x==='object'&&!Array.isArray(x);
 const shape=(x,keys)=>object(x)&&Object.keys(x).length===keys.length&&Object.keys(x).every(k=>keys.includes(k));
 const int=(n,a,b)=>Number.isSafeInteger(n)&&n>=a&&n<=b;
 const validId=x=>typeof x==='string'&&/^[A-Za-z0-9:_.-]{1,180}$/.test(x);
 const check=(yes,message)=>{if(!yes)throw Error('Sélections jeunes : '+message+'.');};
 const state=()=>typeof S==='undefined'?null:S;
 const hash=x=>{let h=2166136261;for(const c of String(x))h=Math.imul(h^c.charCodeAt(0),16777619);return h>>>0;};
 const rank=n=>NATIONS.indexOf(n);
 const iso=ms=>new Date(ms).toISOString().slice(0,10);
 const shift=(date,days)=>iso(Date.parse(date+'T00:00:00Z')+days*day);
 const saturday=(year,month,index=0)=>{const first=Date.UTC(year,month-1,1);return iso(first+((13-new Date(first).getUTCDay())%7+index*7)*day);};
 const friday=(year,month,index=0)=>shift(saturday(year,month,index),-1);
 const bucketOf=pid=>'b'+(hash(pid)%BUCKETS);
 const startYear=season=>2025+season;
 const bounds=season=>[startYear(season)+'-08-01',(startYear(season)+1)+'-08-01'];

 function random(seed){let s=hash(seed);return()=>{s=(s+0x6d2b79f5)|0;let m=Math.imul(s^(s>>>15),s|1);m^=m+Math.imul(m^(m>>>7),m|61);return((m^(m>>>14))>>>0)/4294967296;};}
 function roundRobin(teams,salt){
  const list=teams.slice();if(list.length%2)list.push(null);const rounds=[];
  for(let r=0;r<list.length-1;r++){const m=[];for(let i=0;i<list.length/2;i++){const a=list[i],b=list[list.length-1-i];if(!a||!b)continue;m.push((r+i+hash(salt+a+b))%2?[b,a]:[a,b]);}rounds.push(m);list.splice(1,0,list.pop());}
  return rounds;
 }

 // ---------------------------------------------------------------- calendrier
 function fx(list,cat,comp,key,date,home,away,extra={}){list.push({id:comp+'-'+key,cat,comp,date,home,away,...extra});}

 function u20Calendar(season,divisions){
  const y=startYear(season),next=y+1,out=[];
  // Trophée U20 (septembre) : deux poules de quatre puis matchs de classement.
  const trophy=divisions.trophy,tId='u20-trophy-'+y,tStart=saturday(y,9,1);
  const tPools=[[trophy[0],trophy[3],trophy[4],trophy[7]],[trophy[1],trophy[2],trophy[5],trophy[6]]];
  tPools.forEach((pool,p)=>roundRobin(pool,tId+p).forEach((ms,r)=>ms.forEach(([h,a],i)=>fx(out,'U20',tId,'p'+p+'-r'+(r+1)+'-'+(i+1),shift(tStart,4*r),h,a,{pool:p,phase:'pool'}))));
  for(let k=1;k<=4;k++)fx(out,'U20',tId,'place-'+k,shift(tStart,13),null,null,{phase:'place',sources:['pool:0:'+k,'pool:1:'+k],place:2*k-1});
  // Six Nations U20 (vendredis des week-ends du Tournoi).
  const sId='u20-six-nations-'+next,sStart=friday(next,2,0);
  roundRobin(SIX,sId).forEach((ms,r)=>ms.forEach(([h,a],i)=>fx(out,'U20',sId,'r'+(r+1)+'-'+(i+1),shift(sStart,7*[0,1,2,4,5][r]),h,a,{phase:'league'})));
  // U20 Rugby Championship (SANZAAR).
  const rId='u20-rugby-championship-'+next,rStart=saturday(next,4,3);
  roundRobin(SANZAAR,rId).forEach((ms,r)=>ms.forEach(([h,a],i)=>fx(out,'U20',rId,'r'+(r+1)+'-'+(i+1),shift(rStart,4*r),h,a,{phase:'league'})));
  // Championnat du monde U20 : quatre poules de quatre puis quatre tableaux de classement.
  const wId='u20-world-championship-'+next,wStart=saturday(next,6,3);
  divisions.jwc.forEach((pool,p)=>roundRobin(pool,wId+p).forEach((ms,r)=>ms.forEach(([h,a],i)=>fx(out,'U20',wId,'p'+p+'-r'+(r+1)+'-'+(i+1),shift(wStart,4*r),h,a,{pool:p,phase:'pool',neutral:true}))));
  for(let k=1;k<=4;k++){
   fx(out,'U20',wId,'b'+k+'-sf1',shift(wStart,13),null,null,{phase:'semi',sources:['pool:0:'+k,'pool:2:'+k],neutral:true});
   fx(out,'U20',wId,'b'+k+'-sf2',shift(wStart,13),null,null,{phase:'semi',sources:['pool:1:'+k,'pool:3:'+k],neutral:true});
   fx(out,'U20',wId,'b'+k+'-final',shift(wStart,18),null,null,{phase:'final',sources:['W:b'+k+'-sf1','W:b'+k+'-sf2'],place:4*k-3,neutral:true});
   fx(out,'U20',wId,'b'+k+'-third',shift(wStart,18),null,null,{phase:'final',sources:['L:b'+k+'-sf1','L:b'+k+'-sf2'],place:4*k-1,neutral:true});
  }
  const windows=[
   {key:'novembre',dates:[0,1,2,3].map(i=>saturday(y,11,i)),cap:3},
   {key:'janvier',dates:[2,3].map(i=>saturday(next,1,i)),cap:2},
   {key:'printemps',dates:[0,1,2,3].map(i=>saturday(next,5,i)),cap:2},
   {key:'juin',dates:[0,1].map(i=>saturday(next,6,i)),cap:2},
  ];
  return fill(out,'U20','u20-friendlies-'+y,windows,divisions);
 }

 function u18Calendar(season,divisions){
  const y=startYear(season),next=y+1,out=[];
  const aId='u18-south-africa-series-'+y,aStart=saturday(y,8,1),series=['RSA','ENG','FRA','IRE','WAL','ITA','SCO','GEO'];
  roundRobin(series,aId).slice(0,3).forEach((ms,r)=>ms.forEach(([h,a],i)=>fx(out,'U18',aId,'r'+(r+1)+'-'+(i+1),shift(aStart,4*r),h,a,{phase:'festival',neutral:h!=='RSA'})));
  const fId='u18-six-nations-festival-'+next,fStart=saturday(next,4,0),festival=[...SIX,'GEO','ESP'];
  roundRobin(festival,fId).slice(0,3).forEach((ms,r)=>ms.forEach(([h,a],i)=>fx(out,'U18',fId,'r'+(r+1)+'-'+(i+1),shift(fStart,4*r),h,a,{phase:'festival',neutral:true})));
  const windows=[
   {key:'automne',dates:[...[1,2,3,4].map(i=>saturday(y,10,i)),...[0,1,2].map(i=>saturday(y,11,i))].filter(d=>d<next+'-01-01'),cap:3},
   {key:'printemps',dates:[...[1,2,3].map(i=>saturday(next,5,i)),...[0,1,2].map(i=>saturday(next,6,i))],cap:3},
  ];
  return fill(out,'U18','u18-friendlies-'+y,windows,divisions);
 }

 // Amicaux : chaque nation est complétée vers l'objectif, adversaires de niveau voisin.
 function fill(out,cat,comp,windows){
  const counts=new Map(NATIONS.map(n=>[n,0])),dates=new Map(NATIONS.map(n=>[n,[]])),met=new Set();
  const placeholder=new Map();
  for(const f of out){
   if(f.home){counts.set(f.home,counts.get(f.home)+1);counts.set(f.away,counts.get(f.away)+1);dates.get(f.home).push(f.date);dates.get(f.away).push(f.date);met.add([f.home,f.away].sort().join('/'));}
   else placeholder.set(f.comp+'@'+f.date,f);
  }
  // Les phases finales comptent un match pour chaque équipe de la compétition.
  for(const f of placeholder.values())for(const n of new Set(out.filter(g=>g.comp===f.comp&&g.home).flatMap(g=>[g.home,g.away]))){counts.set(n,counts.get(n)+1);dates.get(n).push(f.date);}
  const near=(n,date)=>dates.get(n).some(d=>Math.abs(Date.parse(d)-Date.parse(date))<6*day);
  for(const w of windows){
   const used=new Map();
   for(const date of w.dates){
    const free=NATIONS.filter(n=>counts.get(n)<TARGET[cat]&&(used.get(n)||0)<w.cap&&!near(n,date))
     .sort((a,b)=>counts.get(a)-counts.get(b)||hash(comp+date+a)-hash(comp+date+b));
    const taken=new Set();
    for(const a of free){
     if(taken.has(a))continue;
     let best=null,score=-Infinity;
     for(const b of free){
      if(b===a||taken.has(b))continue;
      const gap=Math.abs(rank(a)-rank(b));if(gap>10)continue;
      const s=-gap-(met.has([a,b].sort().join('/'))?6:0)+hash(comp+date+a+b)%3;
      if(s>score){score=s;best=b;}
     }
     if(!best)continue;
     taken.add(a);taken.add(best);
     const home=hash(comp+[a,best].sort().join('/'))%2?a:best,away=home===a?best:a;
     fx(out,cat,comp,date.slice(5).replace('-','')+'-'+home+'-'+away,date,home,away,{phase:'friendly',window:w.key});
     for(const n of [a,best]){counts.set(n,counts.get(n)+1);used.set(n,(used.get(n)||0)+1);dates.get(n).push(date);}
     met.add([a,best].sort().join('/'));
    }
   }
  }
  return out;
 }

 function defaultDivisions(){return {jwc:JWC_2026.map(p=>p.slice()),trophy:TROPHY_DEFAULT.slice()};}

 const calendarCache=new Map();
 // L'éligibilité d'un joueur ne dépend que de son identité : mise en cache entre les journées.
 const eligibility=new Map();
 function seasonCalendar(season,divisions=defaultDivisions()){
  const key=season+JSON.stringify(divisions);
  if(!calendarCache.has(key)){if(calendarCache.size>8)calendarCache.clear();calendarCache.set(key,buildCalendar(season,divisions));}
  return calendarCache.get(key).map(f=>({...f}));
 }
 function buildCalendar(season,divisions){
  const [from,to]=bounds(season);
  return [...u20Calendar(season,divisions),...u18Calendar(season,divisions)].filter(f=>f.date>=from&&f.date<to)
   .sort((a,b)=>a.date<b.date?-1:a.date>b.date?1:a.id<b.id?-1:1);
 }

 // ---------------------------------------------------------------- simulation
 function poisson(rate,rand){let k=0,p=1;const l=Math.exp(-rate);do{k++;p*=rand();}while(p>l);return k-1;}
 function score(diff,rand){const tries=poisson(2.8*Math.exp(diff/30),rand);let pts=5*tries+3*poisson(2.1,rand);for(let i=0;i<tries;i++)if(rand()<0.68)pts+=2;return [pts,tries];}
 function simulate(f,homeStrength,awayStrength,seed){
  const rand=random(seed+':'+f.id),diff=homeStrength-awayStrength+(f.neutral?0:2.5);
  const [h,ht]=score(diff,rand),[a,at]=score(-diff,rand);
  let winner=h>a?f.home:a>h?f.away:null;
  if(!winner&&['semi','final','place'].includes(f.phase))winner=ht>at?f.home:at>ht?f.away:(rand()<0.5?f.home:f.away);
  return {h,a,ht,at,winner};
 }

 function table(results,fixtures,teams){
  const rows=new Map(teams.map(t=>[t,{t,pts:0,diff:0,tries:0}]));
  for(const f of fixtures){const r=results[f.id];if(!r)continue;const [h,a,ht,at]=r;const H=rows.get(f.home),A=rows.get(f.away);
   H.pts+=h>a?4:h===a?2:0;A.pts+=a>h?4:h===a?2:0;if(ht>=4)H.pts++;if(at>=4)A.pts++;if(h<a&&a-h<=7)H.pts++;if(a<h&&h-a<=7)A.pts++;
   H.diff+=h-a;A.diff+=a-h;H.tries+=ht;A.tries+=at;}
  return [...rows.values()].sort((x,y)=>y.pts-x.pts||y.diff-x.diff||y.tries-x.tries||rank(x.t)-rank(y.t)).map(r=>r.t);
 }

 function resolve(f,fixtures,results){
  if(f.home)return [f.home,f.away];
  const side=src=>{
   const [kind,a,b]=src.split(':');
   if(kind==='pool'){const pool=fixtures.filter(g=>g.comp===f.comp&&g.phase==='pool'&&g.pool===+a);if(pool.some(g=>!results[g.id]))return null;
    return table(results,pool,[...new Set(pool.flatMap(g=>[g.home,g.away]))])[+b-1]??null;}
   const g=fixtures.find(x=>x.id===f.comp+'-'+a),r=g&&results[g.id];if(!r)return null;
   const [home,away]=[r[4],r[5]],w=r[6];return kind==='W'?w:(w===home?away:home);
  };
  return f.sources.map(side);
 }

 // Joueurs des clubs et des centres de formation, dédoublonnés.
 function youthPool(s){
  const seen=new Set(),out=[];
  const add=p=>{if(!p||seen.has(p.id)||!int(p.age,MIN_AGE.U18,MAX_AGE.U20))return;seen.add(p.id);out.push(p);};
  for(const c of s.clubs||[])for(const p of c.players||[])add(p);
  for(const p of s.development?.academy||[])add(p);
  for(const a of s.aiRoster?.academies||[])for(const p of a.players||[])add(p);
  for(const c of s.nativeAcademy?.centers||[])for(const p of c.players||[])add(p);
  return out;
 }
 // Les U20 retiennent d'abord les 18-19 ans : un 17 ans n'y monte que s'il domine nettement.
 const value=(p,cat)=>p.rating-(cat==='U20'&&p.age<18?8:0);
 const eligibleFor=(p,n)=>typeof nativeFacts!=='undefined'&&typeof nativeFacts.eligible==='function'?nativeFacts.eligible(p.id,n):p.youthNation===n;

 function reserveRating(cat,n,median){return (median??(cat==='U20'?60:55))+Math.round((12-rank(n))*0.45);}

 // Quinze titulaires par poste puis huit remplaçants, parmi les convoqués.
 const FAM=[0,1,0,2,2,3,3,3,4,5,6,7,7,6,8];
 function sheet(squad){
  const used=new Set(),lineup=[];
  for(const fam of FAM){const p=squad.find(q=>!used.has(q.id)&&q.fam===fam)||squad.find(q=>!used.has(q.id));if(p){used.add(p.id);lineup.push(p);}}
  const bench=squad.filter(q=>!used.has(q.id)).slice(0,8);
  return {lineup,bench};
 }

 // ---------------------------------------------------------------- état
 function initialize(s){
  s.youthNational={version:VERSION,season:s.season,divisions:defaultDivisions(),played:{},counts:{},history:[]};
  s.youthNational.played[s.season]={};
  return s.youthNational;
 }
 const active=s=>s?.youthNational?.version===VERSION;
 const worldCareer=s=>typeof CDWorldCareer!=='undefined'&&CDWorldCareer.active(s)&&typeof nativeFacts!=='undefined';

 function today(s){
  if(typeof CDWorldCareer!=='undefined'&&CDWorldCareer.active(s)&&s.worldMode?.day!==undefined)return CDWorldCareer.calendarToday(s);
  const t=Date.UTC(startYear(s.season),7,31),d=new Date(t).getUTCDay(),start=t-((d+6)%7)*day;
  return iso(start+(s.franceMode?.week??s.round??0)*7*day);
 }

 function getCount(st,season,pid){return st.counts[season]?.[bucketOf(pid)]?.[pid]||null;}
 function addCount(st,season,pid,nation,date){
  const b=bucketOf(pid),bucket=(st.counts[season]??={})[b]??={};
  const row=bucket[pid]||(bucket[pid]=[0,rank(nation),[]]);row[0]++;row[2].push(date.slice(5));
 }

 // Joue toutes les rencontres de la saison jusqu'à la date incluse.
 function playUntil(s,until){
  if(!active(s))return 0;
  const st=s.youthNational,season=s.season,played=st.played[season]??={};
  const fixtures=seasonCalendar(season,st.divisions);
  const due=fixtures.filter(f=>f.date<=until&&!played[f.id]);
  if(!due.length)return 0;
  const pool=youthPool(s),seed=String(s.seed??s.worldMode?.seed??'rl27')+':'+season;
  const nationOf=pid=>{const r=getCount(st,season,pid);return r?NATIONS[r[1]]:null;};
  if(eligibility.size>200000)eligibility.clear();
  const eligible=(p,n)=>{const k=p.id+'/'+n;if(!eligibility.has(k))eligibility.set(k,eligibleFor(p,n));return eligibility.get(k);};
  const medians={};
  for(const cat of ['U20','U18']){const r=pool.filter(p=>p.age<=MAX_AGE[cat]&&p.age>=MIN_AGE[cat]).map(p=>p.rating).sort((a,b)=>a-b);medians[cat]=r.length>=30?r[Math.floor(r.length/2)]:null;}
  const busy=new Map();
  let count=0;
  for(const f of due){
   const [home,away]=resolve(f,fixtures,played);
   if(!home||!away)continue;
   const sides=[home,away].map(n=>{
    const squad=pool.filter(p=>p.age>=MIN_AGE[f.cat]&&p.age<=MAX_AGE[f.cat]&&!(p.injury>0)&&busy.get(p.id)!==f.date&&
     (nationOf(p.id)?nationOf(p.id)===n:eligible(p,n))).sort((a,b)=>value(b,f.cat)-value(a,f.cat)||(a.id<b.id?-1:1)).slice(0,SQUAD[f.cat]);
    const {lineup,bench}=sheet(squad);
    const filler=reserveRating(f.cat,n,medians[f.cat]);
    const ratings=lineup.map(p=>p.rating).concat(Array(15-lineup.length).fill(filler));
    const strength=ratings.reduce((a,b)=>a+b,0)/15;
    const used=hash(seed+f.id+n)%5+4;
    return {n,strength,players:[...lineup,...bench.slice(0,used)]};
   });
   const r=simulate({...f,home,away},sides[0].strength,sides[1].strength,seed);
   played[f.id]=[r.h,r.a,r.ht,r.at,home,away,r.winner];
   for(const side of sides)for(const p of side.players){addCount(st,season,p.id,side.n,f.date);busy.set(p.id,f.date);}
   count++;
  }
  return count;
 }

 // Fin de saison : montée / descente entre Championnat du monde et Trophée U20.
 function closeSeason(s){
  if(!active(s))return;
  const st=s.youthNational,season=s.season;
  playUntil(s,bounds(season)[1]);
  const fixtures=seasonCalendar(season,st.divisions),played=st.played[season]||{};
  const y=startYear(season);
  const last=fixtures.find(f=>f.id==='u20-world-championship-'+(y+1)+'-b4-final');
  const champion=fixtures.find(f=>f.id==='u20-trophy-'+y+'-place-1');
  const r1=last&&played[last.id],r2=champion&&played[champion.id];
  const entry={season,u20:null,trophy:null,relegated:null,promoted:null};
  const wc=fixtures.find(f=>f.id==='u20-world-championship-'+(y+1)+'-b1-final'),rw=wc&&played[wc.id];
  if(rw)entry.u20=rw[6];
  if(r2)entry.trophy=r2[6];
  if(r1&&r2){
   const relegated=r1[6]===r1[4]?r1[5]:r1[4],promoted=r2[6];
   entry.relegated=relegated;entry.promoted=promoted;
  }
  // Le calendrier de la saison reste figé ; la montée s'applique à l'ouverture de la suivante.
  st.history=st.history.filter(h=>h.season!==season);st.history.push(entry);st.history=st.history.slice(-30);
 }

 function openSeason(s){
  const st=s.youthNational;if(st.season>=s.season)return;
  const entry=st.history.find(h=>h.season===st.season);
  if(entry?.relegated&&entry.promoted&&st.divisions.jwc.flat().includes(entry.relegated)){
   st.divisions.jwc=st.divisions.jwc.map(pool=>pool.map(n=>n===entry.relegated?entry.promoted:n));
   st.divisions.trophy=st.divisions.trophy.map(n=>n===entry.promoted?entry.relegated:n);
  }
  st.season=s.season;st.played[s.season]??={};
  for(const k of Object.keys(st.played))if(+k<s.season-KEEP_SEASONS+1)delete st.played[k];
  for(const k of Object.keys(st.counts))if(+k<s.season-KEEP_SEASONS+1)delete st.counts[k];
 }

 // ---------------------------------------------------------------- API publique
 // Inscrit des matchs en sélection déjà joués (reprise d'historique, outils de test).
 function recordAppearances(s,playerId,nationId,dates,season=s.season){
  check(active(s)&&validId(playerId)&&NATIONS.includes(nationId)&&Array.isArray(dates)&&dates.every(d=>typeof d==='string'&&/^\d{4}-\d\d-\d\d$/.test(d)),'inscription invalide');
  const prior=nation(s,playerId,season);check(!prior||prior===nationId,'un jeune ne joue que pour une nation par saison');
  for(const d of dates)addCount(s.youthNational,season,playerId,nationId,d);
  return matches(s,playerId,season);
 }
 function matches(s,playerId,season=s?.season){return active(s)?(getCount(s.youthNational,season,playerId)?.[0]||0):0;}
 function dates(s,playerId,season=s?.season){const r=active(s)?getCount(s.youthNational,season,playerId):null;return r?r[2].map(md=>(md>='08'?startYear(season):startYear(season)+1)+'-'+md):[];}
 function nation(s,playerId,season=s?.season){const r=active(s)?getCount(s.youthNational,season,playerId):null;return r?NATIONS[r[1]]:null;}

 function validate(s){
  if(!s||s.youthNational===undefined)return true;
  const st=s.youthNational;
  check(shape(st,['version','season','divisions','played','counts','history'])&&st.version===VERSION&&int(st.season,1,s.season),'état invalide');
  check(shape(st.divisions,['jwc','trophy'])&&Array.isArray(st.divisions.jwc)&&st.divisions.jwc.length===4&&st.divisions.jwc.every(p=>Array.isArray(p)&&p.length===4)&&
   Array.isArray(st.divisions.trophy)&&st.divisions.trophy.length===8&&new Set([...st.divisions.jwc.flat(),...st.divisions.trophy]).size===24&&
   [...st.divisions.jwc.flat(),...st.divisions.trophy].every(n=>NATIONS.includes(n)),'divisions invalides');
  check(object(st.played)&&Object.keys(st.played).length<=KEEP_SEASONS+1&&Object.entries(st.played).every(([k,rows])=>int(+k,1,s.season)&&object(rows)&&Object.keys(rows).length<=600&&
   Object.entries(rows).every(([id,r])=>validId(id)&&Array.isArray(r)&&r.length===7&&r.slice(0,4).every(v=>int(v,0,300))&&NATIONS.includes(r[4])&&NATIONS.includes(r[5])&&(r[6]===null||r[6]===r[4]||r[6]===r[5]))),'résultats invalides');
  check(object(st.counts)&&Object.entries(st.counts).every(([k,buckets])=>int(+k,1,s.season)&&object(buckets)&&Object.keys(buckets).length<=BUCKETS&&
   Object.entries(buckets).every(([b,bucket])=>/^b\d{1,2}$/.test(b)&&object(bucket)&&Object.keys(bucket).length<=2000&&
    Object.entries(bucket).every(([pid,row])=>validId(pid)&&bucketOf(pid)===b&&Array.isArray(row)&&row.length===3&&int(row[0],1,40)&&int(row[1],0,23)&&
     Array.isArray(row[2])&&row[2].length===row[0]&&row[2].every(d=>/^\d\d-\d\d$/.test(d))))),'sélections invalides');
  check(Array.isArray(st.history)&&st.history.length<=30,'palmarès invalide');
  return true;
 }
 function execute(){throw Error('Sélections jeunes : aucune commande.');}
 function project(){
  const s=state();if(!s||!active(s))return {available:false};
  const st=s.youthNational,season=s.season,fixtures=seasonCalendar(season,st.divisions),played=st.played[season]||{};
  const own=[...(s.clubs?.[s.club]?.players||[]),...(s.development?.academy||[])];
  const called=own.map(p=>({id:p.id,name:p.name,matches:matches(s,p.id),nation:nation(s,p.id)})).filter(r=>r.matches>0);
  const results=fixtures.filter(f=>played[f.id]).slice(-12).map(f=>{const r=played[f.id];return {id:f.id,category:f.cat,competition:f.comp,date:f.date,homeId:r[4],awayId:r[5],home:r[0],away:r[1]};});
  const next=fixtures.filter(f=>!played[f.id]&&f.home).slice(0,8).map(f=>({id:f.id,category:f.cat,competition:f.comp,date:f.date,homeId:f.home,awayId:f.away}));
  return {available:true,season,players:called,results,next,history:st.history.slice(-5)};
 }
 function installHooks(){
  if(typeof finishRound==='function'&&!finishRound.__youthNational){
   const original=finishRound,wrapped=function(){const result=original.apply(this,arguments);const s=state();
    // Mode Monde uniquement (décision de Léo du 13/11/2026) : les autres carrières restent inchangées.
    if(s&&!s.live&&(active(s)||worldCareer(s))){if(!active(s))initialize(s);playUntil(s,today(s));}
    return result;};
   Object.assign(wrapped,original);wrapped.__youthNational=true;finishRound=wrapped;
  }
  // En carrière Monde, la fin de semaine passe par finishWeek() qui commence par trainWeek().
  if(typeof trainWeek==='function'&&!trainWeek.__youthNational){
   const original=trainWeek,wrapped=function(){const result=original.apply(this,arguments);const s=state();
    if(s&&!(s.live&&!s.live.finished)&&(active(s)||worldCareer(s))){if(!active(s))initialize(s);playUntil(s,today(s));}
    return result;};
   Object.assign(wrapped,original);wrapped.__youthNational=true;trainWeek=wrapped;
  }
  if(typeof advanceSeason==='function'&&!advanceSeason.__youthNational){
   const original=advanceSeason,wrapped=function(){const s=state(),completed=s?.season,snapshot=s&&active(s)?JSON.stringify(s.youthNational):null;
    if(snapshot)closeSeason(s);
    try{const result=original.apply(this,arguments);
     if(snapshot&&S===s){if(s.season===completed+1)openSeason(s);else s.youthNational=JSON.parse(snapshot);}
     return result;
    }catch(error){if(snapshot&&S===s)s.youthNational=JSON.parse(snapshot);throw error;}};
   Object.assign(wrapped,original);wrapped.__youthNational=true;advanceSeason=wrapped;
  }
  return true;
 }
 return {project,validate,execute,installHooks,initialize,recordAppearances,playUntil,closeSeason,openSeason,seasonCalendar,matches,dates,nation,NATIONS,TARGET};
}
module.exports={files,commands,factory};

'use strict';
// Reprise de l'entraînement (décisions de Léo, 13/11/2026, 14h42-14h45).
// 1. Départ de la partie choisi à la création : « Reprise des premiers clubs » (lundi 13 juillet
//    2026, défaut), « Reprise de ton club » (date du club) ou « Veille de la 1re journée »
//    (préparation gérée par le staff, simulée).
// 2. Date de reprise du club : décision du manager parmi les lundis proposés, avec des effets
//    modérés branchés sur les systèmes existants : fraîcheur (charge physique), condition de match,
//    automatismes collectifs (puissance de la préparation collective, cohésion du vestiaire),
//    moral, blessures, matchs amicaux et temps de jeu des jeunes du centre.
//    Les internationaux de la tournée d'été rejoignent le groupe plus tard (fin de tournée et
//    congés), quel que soit le lundi choisi ; le groupe est complété par des jeunes du centre.
//    Les clubs de l'ordinateur ont leur date (décalée par un parcours jusqu'en finale ou leur
//    habitude de club) et subissent les mêmes effets.
// Tout est déterministe (aucun Math.random). Provenance et barème : docs/reprise-choisie-20261113.md.
const files=Object.freeze([]),commands=Object.freeze(['reprise_choose','reprise_youth','reprise_advance']);
const STARTS=Object.freeze(['premiers-clubs','club','veille']);
function factory(){
 const g=globalThis,DAY=86400000,WEEK=7,HISTORY=20,YOUTH_MAX=8,WINDOW=4,LATE_FROM=30;
 const STARTS=['premiers-clubs','club','veille'];
 // Top 14 2026-27 : dates de reprise publiées par la LNR (« Les infos sur la pré-saison des clubs
 // du Top 14 »), rattachées aux identifiants de club du registre Monde (noms réels : pack privé).
 const ELITE_2026={0:'2026-07-27',1:'2026-07-22',2:'2026-07-23',3:'2026-07-15',4:'2026-07-20',5:'2026-07-13',6:'2026-07-16',
  7:'2026-07-13',8:'2026-08-03',9:'2026-07-13',10:'2026-07-28',11:'2026-07-27',12:'2026-07-15',13:'2026-07-15'};
 // Autres championnats : semaines de préparation habituelles avant la 1re journée (estimées,
 // cohérentes avec leur calendrier) ; ref = préparation de référence, effets nuls.
 const LEAGUES={elite:{ref:6,min:5,max:8},accession:{ref:7,min:6,max:8},nationale:{ref:5,min:5,max:6},
  prem:{ref:9,min:9,max:10},champ:{ref:8,min:8,max:9},urc:{ref:9,min:8,max:10},
  'jlo-d1':{ref:12,min:11,max:13},'jlo-d2':{ref:12,min:11,max:13},srp:{ref:13,min:12,max:14}};
 // Tournée d'été 2026 (Nations Championship, 4-18 juillet) : dernier test le 18/07, puis trois
 // semaines de congés ; retour le lundi suivant. Autres nations : tests jusqu'au 11/07.
 const NC=new Set(['ENG','FRA','IRE','ITA','SCO','WAL','ARG','AUS','FIJ','JPN','NZL','RSA']);
 const TOUR_END={nc:'07-18',other:'07-11'},REST_DAYS=21,SQUAD=32;
 const object=x=>!!x&&typeof x==='object'&&!Array.isArray(x);
 const int=(x,a,b)=>Number.isSafeInteger(x)&&x>=a&&x<=b;
 const clamp=(n,a,b)=>Math.max(a,Math.min(b,n));
 const round1=n=>Math.round(n*10)/10;
 const hash=text=>{let h=2166136261;for(const c of String(text))h=Math.imul(h^c.charCodeAt(0),16777619);h^=h>>>15;return h>>>0;};
 const unit=text=>hash(text)/4294967296;
 const dayOf=iso=>Math.floor(Date.parse(iso+'T00:00:00Z')/DAY);
 const iso=day=>new Date(day*DAY).toISOString().slice(0,10);
 const monday=day=>day-((new Date(day*DAY).getUTCDay()+6)%7);
 const nextMonday=day=>{const m=monday(day);return m===day?day:m+7;};
 const W=()=>typeof CDWorldCareer!=='undefined'?CDWorldCareer:null;
 const active=s=>!!s&&!!W()&&W().active(s)&&W().edition(s)?.mode==='world-champ';
 const year=s=>2025+s.season;
 const engineStart=s=>dayOf(W().calendarToday({...s,round:0,worldMode:{...s.worldMode,day:0}}));
 const leagueOf=(s,id)=>W().leagueId(s,id);
 const profile=(s,id)=>LEAGUES[leagueOf(s,id)]||{ref:7,min:6,max:8};
 const weekOfDay=(s,day)=>Math.floor((day-engineStart(s))/WEEK);

 // ------------------------------------------------------------ calendrier par club
 const fmMemo=new WeakMap();
 function firstMatches(s){
  let m=fmMemo.get(s.worldMode.fixtures);
  if(!m){m=new Map();for(const f of s.worldMode.fixtures)for(const id of [f.homeId,f.awayId]){const d=dayOf(f.date);if(!m.has(id)||d<m.get(id))m.set(id,d);}fmMemo.set(s.worldMode.fixtures,m);}
  return m;
 }
 // Lundi de la semaine de la 1re rencontre officielle (championnat ou coupe d'Europe).
 function fmDay(s,id){const d=firstMatches(s).get(id);return d===undefined?null:d;}
 function fmMonday(s,id){const d=fmDay(s,id);return d===null?null:monday(d);}
 function finalist(s,id){
  const y=s.worldMode.yearbook.at(-1);if(!y||y.season!==s.season-1)return false;
  const inLeague=Object.values(y.champions||{}).includes(id)||Object.values(y.finalists||{}).includes(id);
  const europe=Object.values(y.europe||{}).some(e=>object(e)&&(e.champion===id||e.finalist===id));
  return inLeague||europe;
 }
 // Date habituelle du club : réelle pour l'Élite 2026, sinon semaines habituelles de préparation
 // (habitude de club, déterministe), plus une semaine après un parcours jusqu'en finale.
 function clubDefault(s,id){
  const fm=fmMonday(s,id);if(fm===null)return null;
  const p=profile(s,id);
  const real=s.season===1&&leagueOf(s,id)==='elite'&&ELITE_2026[id];
  if(real)return {day:dayOf(real),real:true,finalShift:false};
  // Habitude du club, fixée sur l'Élite 2026 quand elle existe (même écart à la 1re journée).
  const habit=ELITE_2026[id]?Math.round((dayOf(ELITE_2026[id])-dayOf('2026-08-31'))/WEEK)*-1:p.min+hash('reprise:'+id)%(p.max-p.min+1);
  const shift=finalist(s,id)?1:0;
  const weeks=clamp(habit-shift,p.min-1,p.max);
  return {day:fm-weeks*WEEK,real:false,finalShift:!!shift};
 }
 // Lundis proposés au manager : de ref+3 à ref-3 semaines avant la 1re journée, jamais avant le
 // départ de la partie ni avant aujourd'hui, et la date habituelle du club.
 function options(s,id,today){
  const fm=fmMonday(s,id);if(fm===null)return [];
  const p=profile(s,id),floor=Math.max(today,s.season===1?dayOf('2026-07-13'):today),out=new Set();
  for(let w=p.ref+3;w>=Math.max(2,p.ref-3);w--){const d=fm-w*WEEK;if(d>=floor)out.add(d);}
  const def=clubDefault(s,id);if(def&&def.day>=today)out.add(def.day);
  return [...out].sort((a,b)=>a-b);
 }

 // ------------------------------------------------------------ internationaux de la tournée d'été
 const factsOf=id=>typeof nativeFacts!=='undefined'?nativeFacts.source(id):null;
 let tourMemo=null;
 function tourists(s){
  const key=s.season+':'+s.round+':'+(s.reprise?.today||'');
  if(tourMemo&&tourMemo.s===s&&tourMemo.key===key)return tourMemo.map;
  const map=touristsNow(s);tourMemo={s,key,map};return map;
 }
 function touristsNow(s){
  const byNation=new Map();
  for(const c of s.clubs)for(const p of c.players){
   const f=factsOf(p.id),nation=f?.seniorNation;
   if(!nation||!(f.seniorCaps>0)||p.age>34||p.injury>4)continue;
   if(!byNation.has(nation))byNation.set(nation,[]);
   byNation.get(nation).push(p);
  }
  const out=new Map();
  for(const [nation,players]of byNation){
   players.sort((a,b)=>b.rating-a.rating||(a.id<b.id?-1:a.id>b.id?1:0));
   const back=nextMonday(dayOf(year(s)+'-'+(NC.has(nation)?TOUR_END.nc:TOUR_END.other))+REST_DAYS);
   for(const p of players.slice(0,SQUAD))out.set(p.id,{nation,back});
  }
  return out;
 }

 // ------------------------------------------------------------ jeunes du centre
 const academyOf=(s,id)=>id===s.club?s.development?.academy||[]:(s.aiRoster?.academies||[]).find(a=>a.clubId===id)?.players||[];
 // Espoirs (18-21 ans) d'abord, puis -18 surclassés (17 ans), les plus prometteurs en tête.
 function youthCandidates(s,id){
  return academyOf(s,id).filter(p=>!p.injury&&p.age>=17&&p.age<=21)
   .map(p=>({p,score:(p.dev?.potential??p.rating)+(p.age>=18?4:0)+p.rating*.2}))
   .sort((a,b)=>b.score-a.score||(a.p.id<b.p.id?-1:1)).map(x=>x.p);
 }

 // ------------------------------------------------------------ barème (modéré, documenté)
 // e = semaines de préparation - référence du championnat (positif : reprise tôt).
 function effectsFor(e,absentShare){
  const early=Math.max(0,e),late=Math.max(0,-e);
  return {
   fatigue:Math.round(clamp(5*early,0,15)),                    // charge résiduelle : joueurs moins reposés
   conditionGap:Math.round(clamp(3*late,0,12)),                // retard de condition de match (4 semaines)
   injuryRisk:round1(clamp(.4*late,0,1.6)),                    // % de risque de blessure en plus par match (4 semaines)
   automatismes:Math.round(clamp(2*early,0,6)-clamp(4*late,0,12)-Math.round(10*absentShare)), // % puissance collective (4 semaines)
   morale:Math.round(clamp(2*late,0,6)-clamp(early,0,3)),     // moral de départ (75 = neutre)
   lateCondition:Math.round(clamp(2*early,0,6)),               // plafond de condition en fin de saison
   friendlies:0,
  };
 }
 const friendliesFor=weeks=>clamp(Math.floor(weeks/2),1,4);

 // ------------------------------------------------------------ plan de saison
 function decide(s,id,st){
  const own=id===s.club&&st&&st.season===s.season;
  const def=clubDefault(s,id);if(!def)return null;
  return own&&st.choice!==null?fmMonday(s,id)-st.choice*WEEK:def.day;
 }
 function buildClub(s,id,tour,st){
  const fm=fmMonday(s,id),first=fmDay(s,id),rep=decide(s,id,st);if(fm===null||rep===null)return null;
  const p=profile(s,id),weeks=(first-rep)/WEEK,e=clamp((fm-rep)/WEEK-p.ref,-4,3);
  const players=s.clubs[id].players,away=players.filter(x=>tour.get(x.id)&&tour.get(x.id).back>rep);
  const top=[...players].sort((a,b)=>b.rating-a.rating).slice(0,15),absentTop=top.filter(x=>{const t=tour.get(x.id);return t&&(fm-Math.max(rep,t.back))/WEEK<p.ref-2;}).length;
  const fx=effectsFor(round1(e),absentTop/15);fx.friendlies=friendliesFor(weeks);
  return {id,rep,fm,first,weeks:round1(weeks),e:round1(e),away:away.length,fx};
 }
 function build(s,st){
  const tour=tourists(s),clubs=[],players={};
  for(const c of s.clubs){
   const row=buildClub(s,c.id,tour,st);if(!row)continue;
   const ref=profile(s,c.id).ref;
   clubs.push([c.id,row.rep,weekOfDay(s,row.fm),Math.round(row.e*10),0]);
   for(const p of c.players){
    const t=tour.get(p.id);if(!t)continue;
    const join=Math.max(row.rep,t.back),e=clamp((row.fm-join)/WEEK-ref,-4,3);
    const gap=Math.round(clamp(3*Math.max(0,-e),0,12));
    players[p.id]=[join,gap];
   }
  }
  return {clubs,players};
 }
 const planClub=(st,id)=>st?.plan?.clubs.find(r=>r[0]===id)||null;

 // ------------------------------------------------------------ état
 function blank(s,start){return {version:1,start,season:s.season,today:null,choice:null,youth:null,auto:start==='veille',plan:null,report:null,history:[]};}
 function create(s,start='premiers-clubs'){
  if(!active(s))return null;
  if(!STARTS.includes(start))throw Error('Départ de partie inconnu.');
  const st=s.reprise=blank(s,start),opening=engineStart(s);
  const own=clubDefault(s,s.club);
  const startDay=start==='premiers-clubs'?dayOf('2026-07-13'):start==='club'?(own?.day??opening):opening;
  if(start==='veille')handover(s);
  else if(startDay<opening)st.today=iso(startDay);
  else handover(s);
  return st;
 }
 function suggestYouth(s,id,tour){
  const def=decide(s,id,s.reprise);
  const away=s.clubs[id].players.filter(p=>tour.get(p.id)&&tour.get(p.id).back>(def??0)).length;
  return youthCandidates(s,id).slice(0,clamp(away,2,YOUTH_MAX));
 }
 // Passage de la préparation au calendrier du moteur (17 août en 2026) : le plan de toute la
 // planète est figé ; les effets tombent à la semaine de la 1re rencontre de chaque club.
 function handover(s){
  const st=s.reprise;st.today=null;st.season=s.season;st.plan=build(s,st);st.report=null;
  applyDue(s);
 }
 function pending(s){return active(s)&&s.reprise?.today?s.reprise:null;}
 function today(s){const p=pending(s);return p?dayOf(p.today):dayOf(W().calendarToday(s));}

 // ------------------------------------------------------------ application des effets
 function friendlyDates(row){
  const out=[],n=row.fx.friendlies,span=row.first-row.rep;
  for(let i=0;i<n;i++){const d=row.rep+Math.round(span*(i+1)/(n+1));out.push(d+((6-new Date(d*DAY).getUTCDay()+7)%7));}
  return [...new Set(out.filter(d=>d<row.first))];
 }
 function playYouth(s,id,row,ids){
  const rows=[],club=s.clubs[id],youths=ids.map(x=>academyOf(s,id).find(p=>p.id===x)).filter(p=>p&&!p.injury);
  const dates=friendlyDates(row);
  for(const p of youths){
   let minutes=0;
   for(const d of dates)minutes+=25+hash('amical:'+s.season+':'+p.id+':'+d)%31;
   const before=p.rating;
   if(minutes&&typeof growPlayer==='function'&&p.dev){
    p.dev.minutes+=minutes;p.dev.careerMinutes=(p.dev.careerMinutes||0)+minutes;
    const age=typeof ageGrowth==='function'?ageGrowth(p):1;
    growPlayer(p,minutes/80*.12*.55*age,true);
   }
   rows.push({id:p.id,name:p.name,pos:p.pos,age:p.age,minutes,friendlies:dates.length,gain:p.rating-before});
  }
  return rows;
 }
 function startState(s,r){
  const [id,,fmWeek,e10]=r,c=s.clubs[id],st=s.reprise,row=buildFromPlan(s,r);
  const fx=row.fx;
  for(const p of c.players){
   const own=st.plan.players[p.id];
   if(!own){const load=typeof ensurePhysicalLoad==='function'?ensurePhysicalLoad(p):null;if(load)load.fatigue=clamp(Math.max(load.fatigue,fx.fatigue),0,100);}
   const gap=own?own[1]:fx.conditionGap;
   if(gap>0)p.condition=Math.min(p.condition,100-gap);
  }
  const morale=clamp(75+fx.morale,40,90);
  if(id===s.club){s.morale=morale;if(s.v39?.version===1)s.v39.cohesion=clamp(65+Math.round(fx.automatismes/2),40,85);}
  else c.morale=morale;
  const auto=id!==s.club||st.auto;
  const ids=id===s.club&&st.youth!==null?st.youth:suggestYouth(s,id,tourists(s)).map(p=>p.id);
  const youth=playYouth(s,id,row,ids);
  if(id===s.club){
   st.report={season:s.season,date:iso(row.rep),weeks:row.weeks,friendlies:fx.friendlies,effects:fx,youth,auto};
   st.history.push({season:s.season,date:iso(row.rep),weeks:row.weeks,friendlies:fx.friendlies,youth:youth.length,minutes:youth.reduce((n,y)=>n+y.minutes,0)});
   st.history=st.history.slice(-HISTORY);
   if(typeof news==='function')news(`Fin de la préparation : ${fx.friendlies} match${fx.friendlies>1?'s':''} amica${fx.friendlies>1?'ux':'l'}, ${youth.length} jeune${youth.length>1?'s':''} du centre lancé${youth.length>1?'s':''}.`);
  }
  return auto;
 }
 function buildFromPlan(s,r){
  const [id,rep]=r,first=fmDay(s,id),p=profile(s,id),weeks=(first-rep)/WEEK,e=r[3]/10;
  const tour=new Map(Object.entries(s.reprise.plan.players).map(([pid,[join]])=>[pid,{back:join}]));
  const top=[...s.clubs[id].players].sort((a,b)=>b.rating-a.rating).slice(0,15);
  const absentTop=top.filter(x=>{const t=s.reprise.plan.players[x.id];return t&&(monday(first)-t[0])/WEEK<p.ref-2;}).length;
  const fx=effectsFor(e,absentTop/15);fx.friendlies=friendliesFor(weeks);
  return {id,rep,first,weeks:round1(weeks),e,fx};
 }
 function applyDue(s){
  const st=s.reprise;if(!st?.plan||st.season!==s.season)return;
  for(const r of st.plan.clubs)if(!r[4]&&r[2]<=s.round){startState(s,r);r[4]=1;}
 }
 // Condition plafonnée pendant les quatre premières semaines officielles (retard de condition,
 // décroissant), et en fin de saison pour les reprises très tôt (fraîcheur entamée).
 function capConditions(s){
  const st=s.reprise;if(!st?.plan||st.season!==s.season)return;
  for(const r of st.plan.clubs){
   if(!r[4])continue;const k=s.round-r[2];
   const c=s.clubs[r[0]],fx=effectsFor(r[3]/10,0);
   if(k>=0&&k<WINDOW)for(const p of c.players){
    const gap=st.plan.players[p.id]?.[1]??fx.conditionGap;
    if(gap>0)p.condition=Math.min(p.condition,100-Math.round(gap*(1-k/WINDOW)));
   }
   if(s.round>=LATE_FROM&&fx.lateCondition>0)for(const p of c.players)p.condition=Math.min(p.condition,100-fx.lateCondition);
  }
 }
 function windowFactor(s,id){const r=planClub(s.reprise,id);if(!r||!r[4])return null;const k=s.round-r[2];return k>=0&&k<WINDOW?{r,k,f:1-k/WINDOW}:null;}
 function extraInjuries(l){
  const s=typeof S==='undefined'?null:S,st=s?.reprise;if(!active(s)||!st?.plan||st.season!==s.season||!l?.finished||!l.sheets)return;
  for(let side=0;side<2;side++){
   const id=l.pair[side],w=windowFactor(s,id);if(!w)continue;
   const base=effectsFor(w.r[3]/10,0).injuryRisk;
   for(const pid of l.sheets[side].used||[]){
    const p=s.clubs[id].players.find(x=>x.id===pid),minutes=l.sheets[side].minutes?.[pid]||0;
    if(!p||p.injury||!minutes)continue;
    const own=st.plan.players[pid],risk=(own?own[1]/3*.4:base)/100*w.f*minutes/80;
    if(risk>0&&unit('reprise-blessure:'+s.season+':'+s.round+':'+l.pair.join('-')+':'+pid)<risk){
     p.injury=1+hash('reprise-duree:'+s.season+':'+pid)%3;
     if(id===s.club&&typeof news==='function')news(`${p.name} se blesse en début de saison, encore court physiquement : ${p.injury} semaine(s) d’indisponibilité.`);
    }
   }
  }
 }
 function scaleCollective(l){
  const s=typeof S==='undefined'?null:S;if(!active(s)||!l?.collectivePreparation?.power)return;
  l.collectivePreparation.power=l.collectivePreparation.power.map((v,side)=>{
   const w=windowFactor(s,l.pair[side]);if(!w)return v;
   const row=buildFromPlan(s,w.r);return Math.round(clamp(v*(1+row.fx.automatismes/100*w.f),.55,1)*100)/100; // bornes de la sauvegarde
  });
 }

 // ------------------------------------------------------------ commandes
 function context(s){return {season:s.season,today:iso(today(s))};}
 // Décision ouverte : pendant la préparation, puis tant que la date retenue n'est pas passée ;
 // en fin de saison, pour la saison suivante (stockée en semaines avant la 1re journée).
 function target(s){
  const st=s.reprise;if(!st||st.auto&&st.season===s.season&&s.phase!=='ended')return null;
  if(pending(s))return s.season;
  if(s.phase==='ended')return s.season+1;
  if(st.season===s.season&&st.plan){const r=planClub(st,s.club);if(r&&!r[4]&&r[1]>today(s))return s.season;}
  return null;
 }
 // Lundis proposés pour la saison visée (saison suivante : même écart à la 1re journée).
 function targetOptions(s){
  const t=target(s);if(t===null)return [];
  if(t===s.season)return options(s,s.club,today(s)).map(d=>({day:d,weeks:(fmMonday(s,s.club)-d)/WEEK}));
  const p=profile(s,s.club),fm=fmMonday(s,s.club)+364,out=[];
  for(let w=p.ref+3;w>=Math.max(2,p.ref-3);w--)out.push({day:fm-w*WEEK,weeks:w});
  return out;
 }
 function choose(s,payload){
  const st=s.reprise;if(!active(s)||!st)throw Error('Reprise indisponible.');
  const t=target(s);if(t===null)throw Error('La date de reprise ne peut plus être modifiée.');
  if(payload?.habitual===true&&Object.keys(payload).length===1){
   if(t!==st.season){st.season=t;st.youth=null;st.auto=false;}
   st.choice=null;
  }else{
   const day=typeof payload?.date==='string'&&date(payload.date)?dayOf(payload.date):NaN;
   const pick=targetOptions(s).find(o=>o.day===day);if(!pick)throw Error('Date de reprise non proposée.');
   if(t!==st.season){st.season=t;st.youth=null;st.auto=false;}
   const def=t===s.season?clubDefault(s,s.club):null;
   st.choice=def&&def.day===day?null:Number.isInteger(pick.weeks)?pick.weeks:null;
  }
  if(t===s.season&&st.plan)replan(s);
  return {reprise:{choice:st.choice}};
 }
 function replan(s){
  const st=s.reprise,tour=tourists(s),row=buildClub(s,s.club,tour,st),i=st.plan.clubs.findIndex(r=>r[0]===s.club);
  st.plan.clubs[i]=[s.club,row.rep,weekOfDay(s,row.fm),Math.round(row.e*10),0];
  const ref=profile(s,s.club).ref;
  for(const p of s.clubs[s.club].players){const t=tour.get(p.id);if(!t)continue;const join=Math.max(row.rep,t.back),e=clamp((row.fm-join)/WEEK-ref,-4,3);st.plan.players[p.id]=[join,Math.round(clamp(3*Math.max(0,-e),0,12))];}
 }
 function youth(s,payload){
  const st=s.reprise;if(!active(s)||!st)throw Error('Reprise indisponible.');
  const t=target(s);if(t===null)throw Error('Le groupe de préparation est déjà constitué.');
  if(t!==st.season){st.season=t;st.choice=null;st.auto=false;}
  const ids=payload?.playerIds;
  if(!Array.isArray(ids)||ids.length>YOUTH_MAX||new Set(ids).size!==ids.length)throw Error(`Convoquez au plus ${YOUTH_MAX} jeunes.`);
  const allowed=new Set(youthCandidates(s,s.club).map(p=>p.id));
  if(!ids.every(id=>allowed.has(id)))throw Error('Jeune non convocable (Espoirs et -18 de 17 ans, valides).');
  st.youth=ids.slice();return {reprise:{youth:st.youth.length}};
 }
 function advanceDay(s,from){
  const st=pending(s);if(!st)throw Error('Aucune préparation en cours.');
  if(from!==st.today)throw Error('La date de carrière a changé.');
  const next=dayOf(st.today)+1;
  if(next>=engineStart(s))handover(s);else st.today=iso(next);
  return true;
 }
 function advanceTo(s,payload){
  const st=pending(s);if(!st)throw Error('Aucune préparation en cours.');
  if(payload?.fromDate!==st.today)throw Error('La date de carrière a changé.');
  const opening=engineStart(s),goal=payload.until==='saison'?opening:payload.until==='reprise'?decide(s,s.club,st):dayOf(st.today)+7;
  if(!(goal>dayOf(st.today)))throw Error('Date déjà atteinte.');
  if(goal>=opening)handover(s);else st.today=iso(goal);
  return {reprise:{today:st.today}};
 }
 function execute(command,payload){
  const s=S;
  if(command==='reprise_choose')return choose(s,payload);
  if(command==='reprise_youth')return youth(s,payload);
  if(command==='reprise_advance')return advanceTo(s,payload);
  throw Error('Commande de reprise inconnue.');
 }

 // ------------------------------------------------------------ projection
 function gabi(s,away,options,def,shift){
  const share=away.length/Math.max(1,s.clubs[s.club].players.length),ref=profile(s,s.club).ref,fm=fmMonday(s,s.club);
  const weeks=d=>(fm-d)/WEEK;let pick=def,text='La date habituelle du club laisse une préparation équilibrée.';
  if(finalist(s,s.club)&&!shift||shift&&s.worldMode.leagues[leagueOf(s,s.club)]?.finalist!==undefined&&[s.worldMode.leagues[leagueOf(s,s.club)].champion,s.worldMode.leagues[leagueOf(s,s.club)].finalist].includes(s.club)){
   pick=options.find(d=>weeks(d)<=ref)??def;text='Après une saison allée jusqu’en finale, les organismes ont besoin d’une semaine de plus : reprenons un peu plus tard.';}
  else if(share>=.2){pick=options.find(d=>weeks(d)<=ref+1)??def;text=`${away.length} internationaux rentrent de tournée plus tard : inutile de reprendre très tôt sans eux. Complétons le groupe avec des jeunes du centre, ils joueront les amicaux.`;}
  else if(share<.08){pick=options.find(d=>weeks(d)<=ref+2)??def;text='Peu d’internationaux en tournée : reprendre tôt construit les automatismes sans priver le groupe de ses cadres. Attention à la fraîcheur en fin de saison.';}
  return {date:iso(pick+shift),weeks:weeks(pick),text};
 }
 function project(){
  const s=typeof S==='undefined'?null:S;
  if(!active(s)||!s.reprise)return {available:false};
  const st=s.reprise,now=today(s),tour=tourists(s),t=target(s),next=t!==null&&t!==s.season;
  const shift=next?364:0,def=clubDefault(s,s.club),fm=fmDay(s,s.club),fmM=fmMonday(s,s.club),ref=profile(s,s.club).ref;
  const own={...st,season:s.season,choice:next?(st.season===t?st.choice:null):st.choice};
  const chosen=decide(s,s.club,own);
  const rowFor=choice=>buildClub(s,s.club,tour,{...own,choice});
  const describe=o=>{const row=rowFor(def&&def.day===o.day-shift?null:o.weeks);return {date:iso(o.day),weeks:round1((fmM+shift-o.day)/WEEK+(fm-fmM)/WEEK),habitual:!next&&def?.day===o.day,friendlies:row.fx.friendlies,effects:row.fx,away:row.away};};
  const club=s.clubs[s.club],away=club.players.filter(p=>tour.get(p.id)&&tour.get(p.id).back>chosen).map(p=>{const x=tour.get(p.id);return {id:p.id,name:p.name,pos:p.pos,rating:p.rating,nation:x.nation,returnDate:iso(x.back+shift),weeks:round1((fm-Math.max(x.back,chosen))/WEEK),status:now<x.back+shift?'en congés · retour le '+iso(x.back+shift):'de retour'};}).sort((a,b)=>a.returnDate.localeCompare(b.returnDate)||b.rating-a.rating);
  const candidates=youthCandidates(s,s.club),suggested=suggestYouth(s,s.club,tour).map(p=>p.id);
  const row=rowFor(own.choice),selected=(own.season===st.season&&!next||st.season===t)&&st.youth!==null?st.youth:suggested;
  const opts=targetOptions(s);
  return {available:true,start:st.start,season:t??st.season,nextSeason:next,today:st.today,calendarToday:iso(now),auto:st.auto,editable:t!==null,
   club:{date:chosen===null?null:iso(chosen+shift),habitual:def?iso(def.day+shift):null,real:!!def?.real&&!next,finalShift:!!def?.finalShift,firstMatch:fm===null?null:iso(fm+shift),reference:ref,weeks:row?.weeks??null,friendlies:row?friendlyDates(row).map(d=>iso(d+shift)):[],effects:row?.fx??null},
   options:opts.map(describe),internationals:away,
   group:{total:club.players.length,atReprise:club.players.length-away.length,youth:selected.length},
   youth:{max:YOUTH_MAX,selected:selected.slice(),staff:st.youth===null,suggested,candidates:candidates.slice(0,16).map(p=>({id:p.id,name:p.name,pos:p.pos,age:p.age,rating:p.rating,potential:p.dev?.potential??null}))},
   advice:def&&opts.length?gabi(s,away,opts.map(o=>o.day-shift),chosen??def.day,shift):null,
   report:st.report?JSON.parse(JSON.stringify(st.report)):null,history:st.history.slice()};
 }
 // Création : départ et date de reprise du club pour la saison 2026-2027 (lecture seule).
 function creation(){return {starts:STARTS.slice(),firstClubs:'2026-07-13',elite:Object.fromEntries(Object.entries(ELITE_2026))};}

 // ------------------------------------------------------------ validation
 const date=x=>typeof x==='string'&&/^\d{4}-\d{2}-\d{2}$/.test(x)&&iso(dayOf(x))===x;
 function validate(s){
  const st=s?.reprise;if(st===undefined)return true;
  const fail=m=>{throw Error('Reprise : '+m+'.');},check=(ok,m)=>{if(!ok)fail(m);};
  check(object(st)&&Object.keys(st).length===10&&st.version===1&&STARTS.includes(st.start)&&(int(st.season,1,s.season)||s.phase==='ended'&&st.season===s.season+1)&&typeof st.auto==='boolean','état invalide');
  check(st.today===null||date(st.today)&&st.season===s.season&&s.round===0&&st.plan===null,'date de préparation invalide');
  check(st.choice===null||int(st.choice,1,18),'date choisie invalide');
  check(st.youth===null||Array.isArray(st.youth)&&st.youth.length<=YOUTH_MAX&&st.youth.every(x=>typeof x==='string'&&x.length<=180)&&new Set(st.youth).size===st.youth.length,'jeunes convoqués invalides');
  check(Array.isArray(st.history)&&st.history.length<=HISTORY&&st.history.every(h=>object(h)&&int(h.season,1,s.season)&&date(h.date)&&Number.isFinite(h.weeks)&&int(h.friendlies,0,4)&&int(h.youth,0,YOUTH_MAX)&&int(h.minutes,0,10000)),'historique invalide');
  check(st.report===null||object(st.report)&&int(st.report.season,1,s.season),'bilan invalide');
  if(st.plan!==null){
   check(object(st.plan)&&Object.keys(st.plan).length===2&&Array.isArray(st.plan.clubs)&&st.plan.clubs.length<=s.clubs.length&&object(st.plan.players),'plan invalide');
   const seen=new Set();
   for(const r of st.plan.clubs){check(Array.isArray(r)&&r.length===5&&int(r[0],0,s.clubs.length-1)&&!seen.has(r[0])&&Number.isSafeInteger(r[1])&&int(r[2],-60,60)&&int(r[3],-40,30)&&(r[4]===0||r[4]===1),'ligne de club invalide');seen.add(r[0]);}
   for(const [id,v]of Object.entries(st.plan.players))check(id.length<=180&&Array.isArray(v)&&v.length===2&&Number.isSafeInteger(v[0])&&int(v[1],0,12),'retour d’international invalide');
  }
  return true;
 }

 // ------------------------------------------------------------ branchements
 let installed=false;
 function installHooks(){
  if(installed)return true;installed=true;
  const wrap=(name,after,before)=>{const original=g[name];if(typeof original!=='function')return;const wrapped=function(){if(before)before.apply(this,arguments);const result=original.apply(this,arguments);after.apply(this,[result,...arguments]);return result;};Object.assign(wrapped,original);g[name]=wrapped;};
  const live=()=>{const s=typeof S==='undefined'?null:S;return active(s)&&s.reprise?s:null;};
  wrap('trainWeek',()=>{const s=live();if(s)capConditions(s);});
  wrap('finishRound',()=>{const s=live();if(s&&s.phase!=='ended'){applyDue(s);capConditions(s);}});
  wrap('applyMatchInjuries',(result,l)=>extraInjuries(l),null);
  wrap('initializeCollectivePreparation',(result,l)=>scaleCollective(l));
  // Nouvelle saison : la décision prise en fin de saison s'applique, sinon la date habituelle.
  wrap('advanceSeason',()=>{const s=live();if(!s)return;const st=s.reprise;
   const keep=st.season===s.season;st.season=s.season;st.auto=false;if(!keep){st.choice=null;st.youth=null;}
   handover(s);});
  return true;
 }
 const api=Object.freeze({create,pending,advanceDay,today,project,validate,creation,handover,tourists,clubDefault,options,effectsFor,STARTS});
 g.CDReprise=api;
 return {project,validate,execute,installHooks,create,pending,advanceDay,creation};
}
module.exports={files,commands,factory,STARTS};

'use strict';
// Directions des clubs gérés d'une carrière mondiale (installé dans la VM native).
//
// Chaque club a une direction : un président (ambition, patience, prudence
// financière), un directeur sportif (compétence d'évaluation, goût pour la
// formation plutôt que les vedettes, préférence pour le marché national, réseau
// de championnats suivis) et un entraîneur (tendance à paniquer, confiance aux
// jeunes). Ces traits persistent et changent avec les hommes : entraîneur renvoyé
// après une mauvaise série, président remplacé après une crise ou une reprise.
//
// La stratégie du club n'est plus choisie dans une table fixe : elle résulte de la
// situation réelle (classement et objectif, dynamique, trésorerie, masse et
// plafond, âge du groupe, promotion ou relégation) pondérée par les traits, avec
// de l'inertie, et change quand la situation l'impose. Les décisions de marché
// reposent sur une évaluation bruitée des joueurs (compétence du directeur
// sportif, championnats qu'il connaît), des besoins par poste (profondeur, âge,
// blessures, fins de contrat), la valeur et l'âge des joueurs, la concurrence
// d'autres clubs sur le même joueur, l'attrait du championnat et une négociation
// qui peut échouer. Les erreurs (joueur surestimé, surpaie en panique, vieux
// joueur, doublon au même poste, contrat trop long, jeune parti qui explose
// ailleurs) en découlent, à une fréquence suivie dans S.clubDirections.tally.
//
// Mouvements : transferts, prêts de jeunes vers une division inférieure du même
// pays et leur retour, jokers médicaux, retours au club formateur ; les fins de
// contrat et les joueurs libres restent ceux du cycle des effectifs.
//
// Déterministe : tous les tirages sont des empreintes (graine de la carrière,
// club, joueur, saison), jamais le générateur des matchs. Seules les carrières
// créées avec cet état (S.clubDirections) l'utilisent ; les autres gardent les
// cinq stratégies fixes de club-transfers.cjs, sans migration.
module.exports=function clubDirections(T,N){
 const VERSION=1,FEED=30,WATCH=160,LOANS=120,TALLY_SEASONS=4,TALLY_KEYS=1900,CASH_FLOOR=400000;
 const MAX_BUYS=3,MAX_SALES=3,ROUNDS=3,MAX_LOANS_OUT=2;
 const STRATEGIES=Object.freeze(['vedettes','formateur','rajeunissement','reconstruction','maintien','vente','equilibre']);
 // Pays et réputation de repli quand l'économie des ligues n'est pas chargée.
 const LEAGUES={elite:['france',100],accession:['france',70],nationale:['france',50],prem:['angleterre',92],champ:['angleterre',48],urc:['celte',90],srp:['pacifique',86],'jlo-d1':['japon',78],'jlo-d2':['japon',52],guest:['autre',70]};
 const LOWER={elite:'accession',accession:'nationale',prem:'champ','jlo-d1':'jlo-d2'};
 const ROLE_TRAITS={president:['ambition','patience','prudence'],director:['evaluation','formation','national'],coach:['panic','youth']};
 const state=()=>S.clubDirections;
 const active=()=>!!S&&S.clubDirections?.version===VERSION&&typeof CDWorldCareer!=='undefined'&&CDWorldCareer.active(S)&&typeof aiRosterPopulationActive==='function'&&aiRosterPopulationActive();
 const h=(...k)=>seedHash(state().seed+'|'+k.join('|'));
 const roll=(...k)=>h(...k)%10000/10000;
 const leagueOf=id=>CDWorldCareer.leagueId(S,id);
 const economy=lg=>typeof nativeLeagueEconomy!=='undefined'?nativeLeagueEconomy.CHAMPIONNATS?.[lg]:null;
 const country=lg=>economy(lg)?.pays??LEAGUES[lg]?.[0]??'autre';
 const prestige=lg=>economy(lg)?.reputation??LEAGUES[lg]?.[1]??60;
 const median=v=>{const s=v.slice().sort((a,b)=>a-b);return s.length?s[s.length>>1]:0;};
 const reputation=c=>worldClub(c.id)?.reputation??c.base;
 const primarySlot=p=>Math.max(0,POS.indexOf(p.pos));
 const slotGoal=(c,slot)=>{const row=AI_POPULATION_DEPTH.find(([s])=>s===slot);return row?Math.max(2,Math.round(row[1]*aiRosterTarget(c)/37)):2;};
 const healthy=p=>!(p.injury>=3);
 const covered=(c,slot,without=null)=>c.players.filter(p=>p.id!==without&&p.age<p.dev.retireAge&&slotEligible(p,slot)).length;
 const week=()=>S.worldMode?.week??S.round;

 // ---- Personnes et traits -------------------------------------------------
 // Président et directeur sportif : identifiant stable par club (pres-<club>,
 // ds-<club>), nom inventé tiré du générateur de noms du staff ; un pack
 // d'identités (rubrique « boards ») peut le remplacer à l'affichage. Leurs
 // successeurs (pres-<club>-s<saison>) gardent un nom inventé.
 // Entraîneur : l'entraîneur principal du club dans le staff de la carrière.
 function clubCountry(clubId){
  try{return CDWorldCareer.edition(S).registry.clubs.find(r=>r.id===clubId)?.country||'FR';}catch{return 'FR';}
 }
 function boardName(id,clubId){
  if(N?.profile)return N.profile('board:'+id,{function:'teamManager',country:clubCountry(clubId)}).name;
  return (id.startsWith('pres-')?'Président':'Directeur sportif')+' de '+(S.clubs[clubId]?.name||'club');
 }
 function traitsFor(role,key,bias={}){
  const traits={};
  for(const k of ROLE_TRAITS[role])traits[k]=clamp(Math.round(15+70*roll('trait',role,key,k)+(bias[k]||0)),0,100);
  return traits;
 }
 function person(role,clubId,since,bias={}){
  const first=!S.clubDirections?.clubs?.[clubId];
  const id=(role==='president'?'pres-':'ds-')+clubId+(first?'':'-s'+since.split(':')[0]);
  return {id,name:boardName(id,clubId),since,traits:traitsFor(role,clubId+'|'+since,bias)};
 }
 const staffActive=()=>S.staffCareer?.version===1&&Array.isArray(S.staffCareer.people);
 const staffPeople=()=>staffActive()?S.staffCareer.people.flat():[];
 const HEAD=/head coach|entra[iî]neur principal|^entra[iî]neur$|^manager$|manager ?- ?entra|manager sportif|manager g[ée]n[ée]ral|director of rugby|directeur du rugby|head of rugby|senior coach|^coach$|rugby manager|first team coach|manager de l.[ée]quipe premi/i;
 const NOT_HEAD=/academy|acad[ée]mie|assistant|adjoint|junior|transition|university|skills|forwards|backs|defen|attack|scrum|kicking|lineout|line-out|s&c|avants|arri[eè]res|d[ée]fense|attaque|m[êe]l[ée]e|touche|jeu au pied|pr[ée]para|r[ée]athl|formation|espoirs/i;
 function headScore(p){const l=String(p.roleLabel||'');return (HEAD.test(l)&&!NOT_HEAD.test(l)?2:0)+(p.role==='coach'&&!NOT_HEAD.test(l)?1:0);}
 function headCoach(clubId){
  return staffPeople().filter(p=>p.clubId===clubId&&p.role==='coach').sort((a,b)=>headScore(b)-headScore(a)||b.level-a.level||(a.id<b.id?-1:1))[0]||null;
 }
 function coachFrom(clubId,p,since){
  if(!p)return {id:null,name:'Entraîneur de '+(S.clubs[clubId]?.name||'club'),since,traits:traitsFor('coach',clubId+'|'+since)};
  // Les traits suivent la personne : un entraîneur garde son tempérament d'un club à l'autre.
  return {id:p.id,name:p.name,since,traits:traitsFor('coach',p.id,{panic:-Math.round((p.level-60)/2)})};
 }
 function staffEvent(kind,p,clubId){
  const st=S.staffCareer;
  st.history.push({season:S.season,kind,id:p.id,clubId,name:p.name,role:p.role,appearanceId:p.appearanceId,appearanceAge:p.appearanceAge,age:p.age,sourcePlayerId:p.sourcePlayerId,...(p.appearanceBankVersion===undefined?{}:{appearanceBankVersion:p.appearanceBankVersion}),amount:0});
  st.history=st.history.slice(-512);
 }
 // L'entraîneur de la direction suit le staff réel (retraite, recrutement de l'intersaison).
 function syncCoach(c,x){
  if(!staffActive())return;
  const head=headCoach(c.id);
  if(head&&head.id!==x.coach.id){x.coach=coachFrom(c.id,head,S.season+':'+week());if(S.season>1||week()>0)count('entraineur-arrivee',c.id);}
 }
 // Réseau du directeur sportif : son championnat, plus d'autres selon sa compétence
 // et l'attrait des championnats (un bon recruteur d'un club réputé voit plus loin).
 function network(c,dir,since){
  const own=leagueOf(c.id),ids=Object.keys(S.worldMode.leagues).filter(id=>id!==own&&id!=='guest');
  const out=[own];
  for(const id of ids.sort((a,b)=>prestige(b)-prestige(a)||a.localeCompare(b))){
   const chance=.02+dir.traits.evaluation/400+(prestige(id)>=prestige(own)?.08:-.04)+(country(id)===country(own)?.3:0)-(dir.traits.national-50)/250;
   if(roll('network',c.id,since,id)<chance)out.push(id);
   if(out.length>=4)break;
  }
  return out;
 }
 function bias(c,peers){
  const repMedian=median(peers.map(reputation)),info=worldClub(c.id)||{facilities:2};
  const z=clamp((reputation(c)-repMedian)/6,-2,2),cash=clamp(c.cash/Math.max(1,median(peers.map(x=>x.cash)))-1,-1,2);
  return {president:{ambition:Math.round(z*9+cash*5),prudence:Math.round(-cash*4)},director:{formation:(info.facilities>=3?12:info.facilities<=1?-8:0)-Math.round(z*4),evaluation:Math.round(z*5)},coach:{}};
 }
 function newDirection(c,peers,season){
  const b=bias(c,peers);
  const d={strategy:'equilibre',since:season,objective:null,confidence:60,missed:0,league:leagueOf(c.id),
   president:person('president',c.id,season+':0',b.president),director:person('director',c.id,season+':0',b.director),coach:coachFrom(c.id,headCoach(c.id),season+':0')};
  d.director.network=network(c,d.director,season+':0');
  return d;
 }
 function create(s,seed){
  if(!s||s.clubDirections!==undefined)return false;
  const prev=S;S=s;
  try{
   if(typeof CDWorldCareer==='undefined'||!CDWorldCareer.active(S)||typeof aiRosterPopulationActive!=='function'||!aiRosterPopulationActive())return false;
   S.clubDirections={version:VERSION,seed:Number.isInteger(seed)?seed>>>0:seedHash(S.clubs.map(c=>c.name).join('|')),clubs:{},tally:{},feed:[],watch:[],loans:[],marks:{}};
   const rows=leagueRows(true);
   for(const peers of Object.values(rows))for(const c of peers)S.clubDirections.clubs[c.id]=newDirection(c,peers,S.season);
   for(const peers of Object.values(rows))for(const c of peers){const d=S.clubDirections.clubs[c.id];d.objective=objectiveFor(c,peers,d);d.strategy=choose(c,peers,d,situation(c,peers,d)).strategy;}
   return true;
  }finally{S=prev;}
 }
 function leagueRows(all=false){
  const rows={};
  for(const c of S.clubs){if(!all&&c.id===S.club)continue;(rows[leagueOf(c.id)]??=[]).push(c);}
  return rows;
 }

 // ---- Comptes, fil d'actualité --------------------------------------------
 function count(kind,clubId,n=1){
  const t=state().tally,key=S.season+'|'+(clubId==null?'monde':leagueOf(clubId))+'|'+kind;
  // L'arbre de sauvegarde refuse un objet de plus de 2000 clés (safeTree).
  if(!Object.hasOwn(t,key)&&Object.keys(t).length>=TALLY_KEYS)return;
  t[key]=(t[key]||0)+n;
 }
 function trimTally(){
  const t=state().tally;
  for(const k of Object.keys(t))if(Number(k.split('|')[0])<=S.season-TALLY_SEASONS)delete t[k];
 }
 const userLeague=()=>leagueOf(S.club);
 function say(text,clubIds,toManager=false){
  const d=state();d.feed.unshift('S'+S.season+' · '+text);d.feed=d.feed.slice(0,FEED);
  // Seuls les faits du championnat du manager deviennent des nouvelles du jeu.
  if(toManager&&clubIds.some(id=>leagueOf(id)===userLeague())){
   const key=S.season+':'+week();d.marks.news??={};
   if((d.marks.news[key]||0)<3){d.marks.news[key]=(d.marks.news[key]||0)+1;for(const k of Object.keys(d.marks.news))if(k!==key)delete d.marks.news[k];if(typeof news==='function')news(text);}
  }
 }
 const STRATEGY_LABEL={vedettes:'viser plus haut avec des joueurs confirmés',formateur:'faire confiance à sa formation',rajeunissement:'rajeunir le groupe',reconstruction:'reconstruire',maintien:'assurer le maintien',vente:'assainir ses comptes',equilibre:'compléter l’effectif poste par poste'};
 function profileText(d){
  const p=d.president.traits,ds=d.director.traits,co=d.coach.traits;
  const words=[p.ambition>=65?'président ambitieux':p.ambition<=30?'président mesuré':null,p.patience<=30?'peu patient':p.patience>=70?'patient':null,p.prudence>=70?'très regardant sur les comptes':p.prudence<=30?'dépensier':null,
   ds.evaluation>=70?'recruteur avisé':ds.evaluation<=30?'recrutement hasardeux':null,ds.formation>=70?'tourné vers la formation':ds.formation<=25?'amateur de vedettes':null,co.panic>=70?'entraîneur nerveux':null].filter(Boolean);
  return words.length?words.join(', '):'direction sans excès';
 }

 // ---- Situation et objectifs ----------------------------------------------
 function table(lg){
  const memo=T.memoOf(),key=lg+'|'+S.season+'|'+week()+'|'+(S.history?.length??0);memo.tables??=new Map();
  if(!memo.tables.has(key)){let rows=[];try{rows=CDWorldCareer.rows(S,lg)||[];}catch{rows=[];}memo.tables.set(key,rows);}
  return memo.tables.get(key);
 }
 function objectiveFor(c,peers,d){
  const order=peers.slice().sort((a,b)=>reputation(b)-reputation(a)||b.base-a.base||a.id-b.id);
  const rank=order.findIndex(x=>x.id===c.id)+1,amb=d.president.traits.ambition;
  return clamp(rank-(amb>=75?2:amb>=60?1:0)+(amb<=25?1:0),1,peers.length);
 }
 function situation(c,peers,d){
  const lg=leagueOf(c.id),rows=table(lg),i=rows.findIndex(r=>r.clubId===c.id),row=rows[i]||null;
  const played=row?.played||0,form=(row?.form||[]).slice(-5);
  const losses=form.filter(x=>x==='L').length,wins=form.filter(x=>x==='W').length;
  const rank=played>=4&&i>=0?i+1:(d.lastRank??d.objective??Math.ceil(peers.length/2));
  const limit=aiRosterWageLimit(c),payroll=aiRosterPayroll(c),info=worldClub(c.id)||{facilities:2,debt:0};
  const core=c.players.slice().sort((a,b)=>roleNote(b)-roleNote(a)).slice(0,30);
  const coreAge=core.reduce((n,p)=>n+p.age,0)/Math.max(1,core.length);
  const young=c.players.filter(p=>p.age<=22).length/Math.max(1,c.players.length);
  const cashMedian=Math.max(1,median(peers.map(x=>x.cash)));
  return {lg,n:peers.length,played,rank,gap:rank-(d.objective??rank),losses,wins,cash:c.cash,cashRatio:c.cash/cashMedian,payroll,limit,room:(limit-payroll)/Math.max(1,limit),
   debt:info.debt||0,facilities:info.facilities??2,coreAge,young,repGap:reputation(c)-median(peers.map(reputation)),
   promoted:d.moved===1&&d.movedSeason===S.season,relegated:d.moved===-1&&d.movedSeason===S.season,danger:played>=5&&rank>=peers.length-1};
 }
 // Score de chaque stratégie : situation réelle × traits de la direction.
 function scores(x,d){
  const p=d.president.traits,ds=d.director.traits,co=d.coach.traits;
  // Détresse : dette ou masse nettement au-dessus de sa limite (impératif), sinon caisse courte au regard de la masse.
  const weeks=x.cash/Math.max(1,x.payroll);
  const distress=x.debt>0||x.payroll>x.limit*1.03?100:x.payroll>x.limit?35+p.prudence*.3:weeks<6?60+p.prudence*.25:x.cashRatio<.5?20+p.prudence*.3:0;
  return {
   vente:distress,
   vedettes:x.cash<1500000||x.cashRatio<1.1&&x.repGap<2?0:p.ambition*.55+clamp(x.cashRatio-1,0,1.5)*35+clamp(x.room,0,.3)*80+clamp(x.repGap,-6,8)*2-ds.formation*.3-(x.gap>3&&p.patience<40?12:0),
   formateur:2+ds.formation*.45+(x.facilities-2)*9+x.young*55+p.patience*.12-p.ambition*.3-(x.cashRatio>1.4?12:0)-(x.danger?20:0),
   rajeunissement:(x.coreAge-26.2)*24+co.youth*.12,
   reconstruction:d.missed>0||d.coach.since.startsWith(S.season+':')&&S.season>1?40+d.missed*14+(x.coreAge-26)*8+clamp(x.payroll/Math.max(1,x.limit),0,1.2)*10-p.patience*.08:0,
   maintien:x.danger||x.promoted?48+(100-p.patience)*.15+co.panic*.12:0,
   equilibre:29,
  };
 }
 function choose(c,peers,d,x){
  const s=scores(x,d),current=d.strategy;
  // Inertie : une direction ne change pas de cap sans raison nette ; une crise de trésorerie s'impose.
  const ranked=STRATEGIES.map(k=>[k,s[k]+(k===current?12:0)+(roll('strategy',c.id,S.season,week(),k)-.5)*6]).sort((a,b)=>b[1]-a[1]||a[0].localeCompare(b[0]));
  let pick=ranked[0][0];
  if(s.vente>=60)pick='vente';
  return {strategy:pick,scores:s};
 }

 // ---- Revue de saison et changements d'hommes ------------------------------
 function seasonReview(){
  const d=state();if(d.marks.review===S.season)return;d.marks.review=S.season;
  const last=S.worldMode?.yearbook?.at(-1);
  const rows=leagueRows(true);
  for(const [lg,peers] of Object.entries(rows))for(const c of peers){
   const x=d.clubs[c.id]??=newDirection(c,peers,S.season);
   const finals=last?.standings?Object.entries(last.standings).find(([,ids])=>ids.includes(c.id)):null;
   const lastRank=finals?finals[1].indexOf(c.id)+1:null,lastLeague=finals?finals[0]:x.league;
   const moved=lastLeague&&lastLeague!==lg?(prestige(lg)>prestige(lastLeague)?1:-1):0;
   if(moved){x.moved=moved;x.movedSeason=S.season;}
   if(lastRank!=null&&x.objective!=null&&!moved){
    const miss=lastRank-x.objective;
    x.missed=miss>=3?Math.min(3,(x.missed||0)+1):miss<=-2?0:Math.max(0,(x.missed||0)-1);
    x.confidence=clamp(x.confidence-miss*6,0,100);
    if(miss>=3)count('objectif-manque',c.id);else if(miss<=-2)count('objectif-depasse',c.id);
   }else if(moved===-1){x.missed=Math.min(3,(x.missed||0)+1);x.confidence=clamp(x.confidence-25,0,100);}
   else if(moved===1)x.confidence=clamp(x.confidence+20,0,100);
   x.lastRank=moved?null:lastRank;x.league=lg;
   if(c.id===S.club)continue;
   syncCoach(c,x);
   // Président : reprise après une crise, ou passage de relais.
   const crisis=(worldClub(c.id)?.debt||0)>0||c.cash<500000;
   const takeover=crisis?roll('takeover',c.id,S.season)<.3:roll('takeover',c.id,S.season)<.04+(x.confidence<25?.08:0);
   if(takeover&&S.season>1){
    const investor=roll('investor',c.id,S.season)<(crisis?.35:.5);
    x.president=person('president',c.id,S.season+':0',investor?{ambition:20,prudence:-15}:{prudence:20,ambition:-10});
    x.confidence=60;count('president-change',c.id);
    say(c.name+' change de président : '+x.president.name+(investor?', investisseur ambitieux, reprend le club.':', dirigeant prudent, arrive pour remettre les comptes en ordre.'),[c.id],true);
    if(roll('newdir',c.id,S.season)<.6){x.director=person('director',c.id,S.season+':0',{});say(c.name+' nomme '+x.director.name+' directeur sportif.',[c.id],false);x.director.network=network(c,x.director,S.season+':0');count('directeur-change',c.id);}
   }
   // Entraîneur : un président impatient sanctionne l'objectif manqué.
   else if(x.missed>0&&S.season>1&&roll('coachend',c.id,S.season)<.15+x.missed*.15+(50-x.president.traits.patience)/200)fireCoach(c,x,'à l’intersaison après une saison décevante');
   x.objective=objectiveFor(c,peers,x);
  }
  // Jeunes partis : ceux qui ont percé ailleurs.
  d.watch=d.watch.filter(w=>{
   if(w.season>=S.season)return true;
   const owner=S.clubs.find(c=>c.players.some(p=>p.id===w.playerId));const p=owner?.players.find(q=>q.id===w.playerId);
   if(p&&owner.id!==w.from&&roleNote(p)-w.note>=6){count('erreur:jeune-parti-explose',w.from);say(p.name+', parti de '+S.clubs[w.from].name+' à '+w.age+' ans, explose à '+owner.name+'.',[w.from,owner.id],true);return false;}
   return S.season-w.season<4&&!!p;
  });
  trimTally();
 }
 // Renvoi : l'entraîneur principal quitte le staff du club, le meilleur entraîneur
 // libre du marché du staff le remplace. Sans remplaçant disponible, le président
 // garde son entraîneur (la confiance baisse).
 function fireCoach(c,x,when){
  const since=S.season+':'+week();
  if(staffActive()){
   const head=headCoach(c.id);
   const next=staffPeople().filter(p=>p.clubId===null&&p.role==='coach'&&p.age<p.retireAge-1&&p.id!==head?.id)
    .sort((a,b)=>b.level-a.level||(seedHash(state().seed+'|coach|'+c.id+'|'+a.id)%97)-(seedHash(state().seed+'|coach|'+c.id+'|'+b.id)%97)||(a.id<b.id?-1:1))[0];
   if(!next){x.confidence=clamp(x.confidence-5,0,100);return false;}
   const gone=head?.name||x.coach.name;
   if(head){head.clubId=null;head.contractEnd=null;staffEvent('release',head,c.id);}
   next.clubId=c.id;next.contractEnd=Math.min(S.season+2,S.season+next.retireAge-next.age-1);staffEvent('ai-hire',next,c.id);
   x.coach=coachFrom(c.id,next,since);
   say(c.name+' se sépare de son entraîneur '+gone+' '+when+' ; '+next.name+' prend l’équipe.',[c.id],true);
  }else{
   const gone=x.coach.name;x.coach=coachFrom(c.id,null,since);
   say(c.name+' se sépare de son entraîneur '+gone+' '+when+'.',[c.id],true);
  }
  x.confidence=clamp(x.confidence+10,0,100);x.marks??={};x.marks.fired=S.season;
  count('entraineur-renvoye',c.id);
  return true;
 }
 // Chaque semaine : série noire, président impatient, entraîneur renvoyé.
 function weekly(){
  if(!active()||S.live||S.phase!=='league')return;
  const d=state(),wk=week();if(d.marks.weekly===S.season+':'+wk)return;d.marks.weekly=S.season+':'+wk;
  if(wk<6)return;
  for(const [lg,peers] of Object.entries(leagueRows())){
   const rows=table(lg);
   for(const c of peers){
    const x=d.clubs[c.id];if(!x)continue;syncCoach(c,x);if(x.marks?.fired===S.season)continue;
    const i=rows.findIndex(r=>r.clubId===c.id),row=rows[i];if(!row||row.played<6)continue;
    const form=(row.form||[]).slice(-6),losses=form.filter(f=>f==='L').length,gap=i+1-(x.objective??i+1);
    if(losses>=5&&gap>=3){
     const chance=.25+(60-x.president.traits.patience)/150+(x.confidence<40?.15:0);
     if(roll('sack',c.id,S.season,wk)<chance)fireCoach(c,x,'après '+losses+' défaites en '+form.length+' matchs');
     else x.confidence=clamp(x.confidence-4,0,100);
    }
   }
  }
  medicalJokers();
 }

 // ---- Évaluation des joueurs ----------------------------------------------
 // Note estimée par la cellule du club : bruit selon la compétence du directeur
 // sportif, plus fort hors des championnats qu'il suit ; un recruteur peu fiable
 // se laisse aussi impressionner par les gros salaires.
 function estimate(c,p,ownerLeague){
  const x=state().clubs[c.id],ev=x?.director.traits.evaluation??50;
  const known=!ownerLeague||x?.director.network?.includes(ownerLeague);
  const amp=2+(100-ev)*.08+(known?0:4);
  const noise=(roll('eval',c.id,p.id,S.season)-.5)*2*amp;
  const glamour=clamp(p.salary/9000-1,0,2)*(100-ev)/40;
  return roleNote(p)+noise+glamour;
 }
 // Besoins par poste : profondeur, âge, blessures, fins de contrat.
 function needs(c){
  const out=[];
  for(const [slot] of AI_POPULATION_DEPTH){
   const goal=slotGoal(c,slot),mates=c.players.filter(p=>p.age<p.dev.retireAge&&slotEligible(p,slot));
   let have=0;
   for(const p of mates)have+=(!healthy(p)?.4:1)*(p.age>=33?.5:p.age>=31?.8:1)*(p.contractEnd!=null&&p.contractEnd<=S.season&&week()>=13?.6:1);
   const deficit=goal-have;
   if(deficit>.5)out.push({slot,pos:POS[slot],score:Math.round(deficit*25)});
  }
  return out.sort((a,b)=>b.score-a.score||a.slot-b.slot);
 }
 function starters(c){
  return POS.map((pos,slot)=>{
   const mates=c.players.filter(q=>slotEligible(q,slot)).map(q=>roleNote(q)).sort((a,b)=>b-a);
   return mates[Math.max(0,Math.min(mates.length-1,POS.filter(x=>x===pos).length-1))]??0;
  });
 }

 // ---- Marché ---------------------------------------------------------------
 function listed(c,plan,reports){
  if((reports.get(c.id)?.sold||0)>=MAX_SALES)return [];
  const goal=aiRosterTarget(c);
  if(c.players.length<=goal-3)return [];
  const fresh=p=>p.joinedSeason===S.season||p.contractEnd==null||p.contractEnd<S.season||onLoan(p.id);
  const keep=p=>covered(c,primarySlot(p),p.id)<Math.max(2,slotGoal(c,primarySlot(p))-1);
  const pool=c.players.filter(p=>!fresh(p)&&!keep(p)&&p.age<p.dev.retireAge-1);
  const byNote=(a,b)=>roleNote(b)-roleNote(a)||a.id.localeCompare(b.id),bySalary=(a,b)=>b.salary-a.salary||a.id.localeCompare(b.id);
  let picks=[];
  if(plan==='vente')picks=pool.filter(p=>p.age>=23).sort(bySalary).slice(0,3);
  else if(plan==='formateur')picks=pool.filter(p=>p.age<=24&&roleNote(p)>=c.base-5).sort(byNote).slice(0,1);
  else if(plan==='rajeunissement')picks=pool.filter(p=>p.age>=30).sort(bySalary).slice(0,3);
  else if(plan==='reconstruction')picks=pool.filter(p=>p.age>=28).sort(bySalary).slice(0,3);
  const top=new Set(pool.slice().sort(byNote).slice(0,5).map(p=>p.id));
  const surplus=pool.filter(p=>covered(c,primarySlot(p))>slotGoal(c,primarySlot(p))+2&&!top.has(p.id)).sort((a,b)=>roleNote(a)-roleNote(b)||a.id.localeCompare(b.id))[0];
  if(surplus&&!picks.includes(surplus))picks.push(surplus);
  const discount=plan==='vente'?.75:plan==='reconstruction'?.9:1;
  return picks.map(p=>({p,seller:c,ask:Math.round(T.value(p)*discount/10000)*10000,listed:true}));
 }
 // Joueur non proposé : un club plus riche ou plus réputé peut tenter sa chance ;
 // le vendeur en demande cher, sauf s'il doit vendre.
 function unlisted(c,plans,reports,cache){
  if(plans.get(c.id)==='vedettes'||(reports.get(c.id)?.sold||0)>=MAX_SALES||c.players.length<=aiRosterTarget(c)-3)return [];
  if(!cache.has(c.id)){
   const order=c.players.slice().sort((a,b)=>roleNote(b)-roleNote(a)||a.id.localeCompare(b.id)),best=new Set(order.slice(0,3).map(p=>p.id));
   cache.set(c.id,order.filter(p=>!best.has(p.id)&&p.joinedSeason!==S.season&&!onLoan(p.id)&&p.contractEnd!=null&&p.contractEnd>=S.season&&p.age<=30&&p.age<p.dev.retireAge-1&&
    covered(c,primarySlot(p),p.id)>=Math.max(2,slotGoal(c,primarySlot(p))-1)).slice(0,4).map(p=>({p,seller:c,ask:Math.round(T.value(p)*(plans.get(c.id)==='vente'?1.1:1.5)/10000)*10000,listed:false})));
  }
  return cache.get(c.id);
 }
 const onLoan=id=>state().loans.some(l=>l.playerId===id);
 // Club formateur : un joueur qu'il a lancé et vendu, de retour en fin de carrière.
 const formedBy=(c,p)=>state().watch.some(w=>w.playerId===p.id&&w.from===c.id)||(state().formed||[]).some(w=>w.playerId===p.id&&w.from===c.id);
 function wanted(buyer,plan,offer,ctx){
  const p=offer.p,x=state().clubs[buyer.id],sellerLeague=leagueOf(offer.seller.id),buyerLeague=leagueOf(buyer.id);
  const est=estimate(buyer,p,sellerLeague),slot=primarySlot(p),upgrade=est-ctx.starters[slot];
  const need=ctx.needs.find(n=>slotEligible(p,n.slot));
  const panic=ctx.panic,maxAge=panic?34:p.dev.retireAge-1;
  if(p.age>=maxAge)return null;
  if(!x.director.network.includes(sellerLeague)&&!formedBy(buyer,p))return null;
  if(plan==='vente'&&buyer.players.length>=aiRosterTarget(buyer)-2)return null;
  if(plan==='formateur'&&(p.age>23||offer.ask>buyer.cash*.1))return null;
  if(['rajeunissement','reconstruction'].includes(plan)&&p.age>(plan==='reconstruction'?26:25))return null;
  if(plan==='maintien'&&(p.age<25||upgrade<1))return null;
  const homecoming=p.age>=29&&formedBy(buyer,p);
  // Doublon : un directeur sportif peu fiable cède à une « occasion » sans besoin réel.
  const impulse=!need&&x.director.traits.evaluation<45&&upgrade>=4&&roll('impulse',buyer.id,p.id,S.season)<.35;
  if(!need&&!impulse&&!homecoming&&!(plan==='vedettes'&&upgrade>=3)&&!(plan==='rajeunissement'&&upgrade>=0&&p.age<=24))return null;
  if(est<buyer.base-14)return null;
  const national=country(sellerLeague)===country(buyerLeague)?(x.director.traits.national-50)/5:(50-x.director.traits.national)/10;
  const score=(need?need.score:0)+upgrade*4+(plan==='vedettes'?est*.5:0)+national+(homecoming?25:0)-(offer.listed?0:10)-Math.round(offer.ask/250000);
  return {score,est,upgrade,need:need?.pos||POS[slot],impulse,homecoming};
 }
 // Ce que l'acheteur est prêt à payer : la valeur, plus ce que vaut à ses yeux le
 // renfort, son ambition, et la panique.
 function bid(buyer,offer,w,ctx){
  const x=state().clubs[buyer.id],t=x.president.traits;
  const factor=.85+clamp(w.upgrade,0,8)*.04+t.ambition*.003-t.prudence*.002+(ctx.panic?.3:0)+(w.homecoming?.1:0);
  return Math.max(10000,Math.round(T.value(offer.p)*factor/10000)*10000);
 }
 function salaryFor(buyer,offer,w,ctx){
  const x=state().clubs[buyer.id],t=x.president.traits;
  let k=1.02+t.ambition*.0006+(ctx.plan==='vedettes'?.05:0);
  if(ctx.panic)k+=.15+x.coach.traits.panic*.002;
  if(w.homecoming)k=Math.min(k,.92);
  return clamp(Math.round(Math.max(offer.p.salary*(w.homecoming?.85:1),T.demand(offer.p,offer.seller,buyer))*k/100)*100,270,100000);
 }
 function years(buyer,p,ctx){
  const x=state().clubs[buyer.id],t=x.president.traits;
  let y=p.age<=24?3:p.age<=27?3:p.age<=30?2:1;
  // Erreur classique : le contrat long d'un trentenaire signé par une direction ambitieuse et peu regardante.
  const long=p.age>=29&&t.ambition>=60&&t.prudence<=45&&roll('long',buyer.id,p.id,S.season)<.5;
  if(long)y+=2;
  if(ctx.panic&&p.age>=30)y+=1;
  return {years:y,long};
 }
 function affordable(buyer,fee,salary){
  const info=worldClub(buyer.id);
  if(info&&info.debt>=2000000)return false;
  if(professionalPlaces(buyer)<=0)return false;
  if(aiRosterPayroll(buyer)+salary>aiRosterWageLimit(buyer))return false;
  const prudence=state().clubs[buyer.id].president.traits.prudence;
  return buyer.cash-fee-CASH_FLOOR*(.5+prudence/100)>=salary*8;
 }
 // Le joueur accepte-t-il ? Un championnat moins attirant le fait hésiter.
 function accepts(p,seller,buyer,salary){
  const drop=prestige(leagueOf(seller.id))-prestige(leagueOf(buyer.id));
  if(drop<=8)return true;
  const premium=salary/Math.max(1,p.salary)-1;
  const chance=clamp(drop/100-premium*.8+(p.age<=26?.1:-.05),0,.7);
  return roll('refuse',p.id,buyer.id,S.season)>=chance;
 }
 function execute(buyer,offer,fee,salary,plan,need,w,ctx,yrs){
  const p=offer.p,seller=offer.seller,x=state().clubs[buyer.id];
  const trueNote=roleNote(p),young=p.age<=21,ageAtSale=p.age;
  seller.players=seller.players.filter(q=>q.id!==p.id);
  seller.cash+=fee;buyer.cash-=fee;
  p.formerClub=seller.name;p.salary=salary;p.contractEnd=S.season+yrs.years-1+(week()>=13?1:0);
  p.joinedSeason=S.season;p.joinedRound=S.round;p.price=fee;
  buyer.players.push(p);
  aiRosterEvent(seller.id,'sell',p,fee);aiRosterEvent(buyer.id,'recruit',p,fee);
  const abroad=leagueOf(seller.id)!==leagueOf(buyer.id);
  count(abroad?'transfert-etranger':'transfert',buyer.id);
  if(leagueOf(seller.id)==='elite'&&abroad)count('depart-top14',seller.id);
  if(w.homecoming)count('retour-formateur',buyer.id);
  if(w.est-trueNote>=5)count('erreur:surestime',buyer.id);
  if(ctx.panic&&salary>=1.15*Math.max(p.salary,1))count('erreur:surpaie-panique',buyer.id);
  if(p.age>=32&&yrs.years>=2)count('erreur:vieux-joueur',buyer.id);
  if(yrs.long)count('erreur:contrat-trop-long',buyer.id);
  if(w.impulse||covered(buyer,primarySlot(p))>slotGoal(buyer,primarySlot(p))+2)count('erreur:doublon',buyer.id);
  if(young)state().watch=[{playerId:p.id,from:seller.id,season:S.season,note:trueNote,age:ageAtSale},...state().watch].slice(0,WATCH);
  if(p.age<=23)rememberFormed(seller,p);
  const why=w.homecoming?'retour au club formateur':ctx.panic?'renfort pressé':w.impulse?'occasion jugée trop belle':'besoin : '+need;
  S.economy.transfers.unshift({season:S.season,round:S.round,text:buyer.name+' achète '+p.name+' à '+seller.name+' pour '+money(fee)+' ('+why+').'});
  S.economy.transfers=S.economy.transfers.slice(0,80);
  if(fee>=600000||w.homecoming||ctx.panic&&fee>=200000)say(buyer.name+' recrute '+p.name+' ('+seller.name+') pour '+money(fee)+(w.homecoming?' : retour au club qui l’a formé.':ctx.panic?' : la direction veut une réaction immédiate.':'.'),[buyer.id,seller.id],true);
  else say(buyer.name+' recrute '+p.name+' ('+seller.name+', '+money(fee)+').',[buyer.id,seller.id],false);
  return {season:S.season,round:S.round,buyer:buyer.id,seller:seller.id,playerId:p.id,fee,salary,plan,sellerPlan:ctx.plans.get(seller.id),kind:abroad?'etranger':'national'};
 }
 // Joueurs lancés par un club (moins de 24 ans à leur départ) : un retour reste possible.
 function rememberFormed(seller,p){
  const d=state();d.formed??=[];
  if(!d.formed.some(w=>w.playerId===p.id))d.formed=[{playerId:p.id,from:seller.id,season:S.season},...d.formed].slice(0,WATCH);
 }
 function plansFor(){
  const d=state(),plans=new Map(),rows=leagueRows();
  for(const [lg,peers] of Object.entries(rows))for(const c of peers){
   const x=d.clubs[c.id]??=newDirection(c,peers,S.season);
   if(x.objective==null)x.objective=objectiveFor(c,peers,x);
   const sit=situation(c,peers,x),{strategy}=choose(c,peers,x,sit);
   if(strategy!==x.strategy){
    count('bascule:'+x.strategy+'-vers-'+strategy,null);
    if(['reconstruction','vente','vedettes'].includes(strategy)&&S.season>1)say(c.name+' change de cap : la direction veut '+STRATEGY_LABEL[strategy]+' ('+profileText(x)+').',[c.id],strategy!=='vedettes'||sit.promoted);
    x.strategy=strategy;x.since=S.season;
   }
   x.panic=week()>=10&&sit.gap>=2&&sit.losses>=3&&x.coach.traits.panic>=55&&roll('panic',c.id,S.season,week())<.4+x.coach.traits.panic/250;
   if(x.panic)count('panique',c.id);
   count('strategie:'+strategy,c.id);
   plans.set(c.id,strategy);
  }
  return plans;
 }
 function openWindow(){
  const d=state(),done=[];
  if(week()===0)returnLoans();
  seasonReview();
  const plans=plansFor(),reports=new Map(),clubs=S.clubs.filter(c=>c.id!==S.club);
  for(const c of clubs){const r=aiRosterReport(c.id);r.strategy=plans.get(c.id);reports.set(c.id,r);}
  const order=p=>({maintien:0,vedettes:1,reconstruction:2,rajeunissement:3,equilibre:4,formateur:5,vente:6})[p];
  for(let round=0;round<ROUNDS;round++){
   const busy=new Set(),cache=new Map();
   const offers=clubs.flatMap(c=>listed(c,plans.get(c.id),reports));
   const room=c=>aiRosterMayRecruit(c)||['vedettes','rajeunissement','reconstruction','maintien'].includes(plans.get(c.id))&&c.players.length<aiRosterTarget(c)+2&&professionalPlaces(c)>0;
   const buyers=clubs.filter(c=>(reports.get(c.id).bought||0)<MAX_BUYS&&room(c))
    .sort((a,b)=>order(plans.get(a.id))-order(plans.get(b.id))||reputation(b)-reputation(a)||a.id-b.id);
   // Chaque acheteur choisit sa cible ; plusieurs clubs peuvent viser le même joueur.
   const bids=new Map();
   for(const buyer of buyers){
    const plan=plans.get(buyer.id),x=d.clubs[buyer.id],ctx={plan,plans,panic:!!x.panic,needs:needs(buyer),starters:starters(buyer)};
    const extra=['vedettes','maintien'].includes(plan)||ctx.panic?clubs.filter(c=>c.id!==buyer.id&&(reputation(c)<=reputation(buyer)-4||c.cash<buyer.cash*.5)).flatMap(c=>unlisted(c,plans,reports,cache)):[];
    const japan=['jlo-d1','jlo-d2'].includes(leagueOf(buyer.id));
    let best=null;
    for(const offer of offers.concat(extra)){
     if(offer.seller.id===buyer.id||!offer.seller.players.some(q=>q.id===offer.p.id))continue;
     if(japan!==['jlo-d1','jlo-d2'].includes(leagueOf(offer.seller.id)))continue;
     const w=wanted(buyer,plan,offer,ctx);if(!w)continue;
     const max=bid(buyer,offer,w,ctx),salary=salaryFor(buyer,offer,w,ctx);
     if(!affordable(buyer,Math.min(max,offer.ask),salary))continue;
     if(!best||w.score>best.w.score||w.score===best.w.score&&offer.p.id<best.offer.p.id)best={buyer,offer,w,max,salary,ctx};
    }
    if(best)(bids.get(best.offer.p.id)??bids.set(best.offer.p.id,[]).get(best.offer.p.id)).push(best);
   }
   let signed=0;
   const contests=[...bids.values()].sort((a,b)=>Math.max(...b.map(x=>x.max))-Math.max(...a.map(x=>x.max))||a[0].offer.p.id.localeCompare(b[0].offer.p.id));
   for(const group of contests){
    const live=group.filter(g=>!busy.has(g.buyer.id)&&!busy.has(g.offer.seller.id)&&g.offer.seller.players.some(q=>q.id===g.offer.p.id));
    if(!live.length)continue;
    live.sort((a,b)=>b.max+b.salary*20-(a.max+a.salary*20)||a.buyer.id-b.buyer.id);
    const win=live[0],second=live[1],ask=win.offer.ask,seller=win.offer.seller;
    if(second){count('concurrence',second.buyer.id,live.length-1);}
    // Négociation : le vendeur pressé coupe la poire en deux, sinon l'écart fait échouer.
    let fee=null;
    if(win.max>=ask)fee=Math.min(win.max,Math.max(ask,second?second.max+10000:ask));
    else if(plans.get(seller.id)==='vente'&&win.max>=ask*.8)fee=Math.round((win.max+ask)/20000)*10000;
    if(fee==null){count('echec-negociation',win.buyer.id);if(ask>=500000)say('Les discussions entre '+win.buyer.name+' et '+seller.name+' pour '+win.offer.p.name+' n’aboutissent pas.',[win.buyer.id,seller.id],false);busy.add(win.buyer.id);continue;}
    if(!affordable(win.buyer,fee,win.salary))continue;
    if(!accepts(win.offer.p,seller,win.buyer,win.salary)){count('refus-joueur',win.buyer.id);say(win.offer.p.name+' refuse de rejoindre '+win.buyer.name+' : le championnat ne le tente pas.',[win.buyer.id,seller.id],false);busy.add(win.buyer.id);continue;}
    const yrs=years(win.buyer,win.offer.p,win.ctx);
    const row=execute(win.buyer,win.offer,fee,win.salary,plans.get(win.buyer.id),win.w.need,win.w,win.ctx,yrs);
    reports.get(win.buyer.id).bought=(reports.get(win.buyer.id).bought||0)+1;
    reports.get(seller.id).sold=(reports.get(seller.id).sold||0)+1;
    busy.add(win.buyer.id);busy.add(seller.id);done.push(row);signed++;
   }
   if(!signed)break;
  }
  done.push(...loans(plans));
  return done;
 }

 // ---- Prêts de jeunes -------------------------------------------------------
 function loans(plans){
  const d=state(),out=[];
  if(week()!==0)return out;
  const clubs=S.clubs.filter(c=>c.id!==S.club);
  for(const c of clubs){
   const x=d.clubs[c.id],lower=LOWER[leagueOf(c.id)];if(!lower||!x)continue;
   const keen=plans.get(c.id)==='formateur'||x.coach.traits.youth>=55||x.director.traits.formation>=60;
   if(!keen||c.players.length<aiRosterTarget(c)-1)continue;
   let lent=d.loans.filter(l=>l.from===c.id).length;
   const ranked=c.players.filter(p=>p.age>=18&&p.age<=21&&p.joinedSeason!==S.season&&!onLoan(p.id)&&p.contractEnd!=null&&p.contractEnd>S.season)
    .filter(p=>{const slot=primarySlot(p);return c.players.filter(q=>slotEligible(q,slot)&&roleNote(q)>roleNote(p)).length>=slotGoal(c,slot)-1;})
    .sort((a,b)=>roleNote(b)-roleNote(a)||a.id.localeCompare(b.id));
   for(const p of ranked){
    if(lent>=MAX_LOANS_OUT||d.loans.length>=LOANS)break;
    const slot=primarySlot(p);
    const host=S.clubs.filter(h=>h.id!==S.club&&leagueOf(h.id)===lower&&professionalPlaces(h)>0&&aiRosterPayroll(h)+p.salary<=aiRosterWageLimit(h)&&covered(h,slot)<slotGoal(h,slot)+1&&!d.loans.some(l=>l.to===h.id&&l.from===c.id))
     .sort((a,b)=>covered(a,slot)-covered(b,slot)||(seedHash(d.seed+'|loan|'+p.id+'|'+a.id)%97)-(seedHash(d.seed+'|loan|'+p.id+'|'+b.id)%97))[0];
    if(!host)continue;
    c.players=c.players.filter(q=>q.id!==p.id);host.players.push(p);
    d.loans.push({playerId:p.id,from:c.id,to:host.id,until:S.season});lent++;
    count('pret',c.id);
    S.economy.transfers.unshift({season:S.season,round:S.round,text:c.name+' prête '+p.name+' à '+host.name+' pour la saison.'});S.economy.transfers=S.economy.transfers.slice(0,80);
    say(c.name+' prête '+p.name+' ('+p.age+' ans) à '+host.name+' pour qu’il joue.',[c.id,host.id],false);
    out.push({season:S.season,round:S.round,buyer:host.id,seller:c.id,playerId:p.id,fee:0,salary:p.salary,plan:'pret',kind:'pret'});
   }
  }
  return out;
 }
 function returnLoans(){
  const d=state();
  d.loans=d.loans.filter(l=>{
   if(l.until>=S.season)return true;
   const host=S.clubs[l.to],home=S.clubs[l.from],p=host?.players.find(q=>q.id===l.playerId);
   if(!p||!home||home.id===S.club||host.id===S.club)return false;
   host.players=host.players.filter(q=>q.id!==p.id);home.players.push(p);
   p.joinedSeason=S.season;p.joinedRound=S.round;
   if(p.contractEnd==null||p.contractEnd<S.season)p.contractEnd=S.season+1;
   count('retour-pret',home.id);
   return false;
  });
 }

 // ---- Jokers médicaux --------------------------------------------------------
 function medicalJokers(){
  const d=state(),wk=week();
  if(wk<2||[0,13].includes(wk))return;
  const pool=S.economy.freeAgents.filter(p=>p.age>=22&&p.age<=33&&p.age<p.dev.retireAge-1&&!(p.injury>0));
  if(!pool.length)return;
  for(const c of S.clubs){
   if(c.id===S.club)continue;
   const x=d.clubs[c.id];if(!x||x.marks?.joker===S.season)continue;
   const hurt=c.players.filter(p=>p.injury>=6).sort((a,b)=>roleNote(b)-roleNote(a)||a.id.localeCompare(b.id))[0];
   if(!hurt)continue;
   const slot=primarySlot(hurt),fit=c.players.filter(p=>p.id!==hurt.id&&healthy(p)&&slotEligible(p,slot)).length;
   if(fit>=Math.max(2,slotGoal(c,slot)-1))continue;
   const limit=aiRosterWageLimit(c),payroll=aiRosterPayroll(c);
   const pick=pool.filter(p=>slotEligible(p,slot)&&!S.clubs.some(o=>o.players.some(q=>q.id===p.id))&&payroll+p.salary<=limit&&c.cash-p.salary*20>=CASH_FLOOR)
    .sort((a,b)=>estimate(c,b,null)-estimate(c,a,null)||a.id.localeCompare(b.id))[0];
   if(!pick)continue;
   x.marks??={};x.marks.joker=S.season;
   S.economy.freeAgents=S.economy.freeAgents.filter(p=>p.id!==pick.id);S.market=S.market.filter(p=>p.id!==pick.id);
   pick.contractEnd=S.season;pick.joinedSeason=S.season;pick.joinedRound=S.round;c.players.push(pick);
   aiRosterEvent(c.id,'recruit',pick,0);count('joker-medical',c.id);
   S.economy.transfers.unshift({season:S.season,round:S.round,text:c.name+' engage '+pick.name+' comme joker médical ('+hurt.name+' blessé).'});S.economy.transfers=S.economy.transfers.slice(0,80);
   say(c.name+' engage '+pick.name+' comme joker médical après la blessure de '+hurt.name+'.',[c.id],false);
   pool.splice(pool.indexOf(pick),1);
  }
 }

 // ---- Lecture : profil d'une direction, validation de la sauvegarde ---------
 function profile(clubId){
  const x=S?.clubDirections?.clubs?.[clubId];if(!x)return null;
  return {strategy:x.strategy,label:STRATEGY_LABEL[x.strategy],summary:profileText(x),objective:x.objective,confidence:x.confidence};
 }
 function validate(s){
  const d=s?.clubDirections;if(d===undefined)return true;
  const ok=v=>{if(!v)throw Error('Directions des clubs invalides.');};
  const int=(v,a,b)=>Number.isInteger(v)&&v>=a&&v<=b,traits=(t,role)=>ok(t&&typeof t==='object'&&Object.keys(t).length===ROLE_TRAITS[role].length&&ROLE_TRAITS[role].every(k=>int(t[k],0,100)));
  ok(d&&typeof d==='object'&&!Array.isArray(d)&&d.version===VERSION&&int(d.seed,0,4294967295)&&d.clubs&&typeof d.clubs==='object');
  ok(Object.keys(d.clubs).length<=s.clubs.length&&Object.keys(d.clubs).every(k=>/^(0|[1-9]\d*)$/.test(k)&&Number(k)<s.clubs.length));
  for(const x of Object.values(d.clubs)){
   ok(x&&STRATEGIES.includes(x.strategy)&&int(x.since,1,s.season)&&int(x.confidence,0,100)&&(x.objective===null||int(x.objective,1,64))&&int(x.missed??0,0,3));
   for(const role of Object.keys(ROLE_TRAITS)){const r=x[role];ok(r&&typeof r.since==='string'&&r.since.length<=12&&typeof r.name==='string'&&r.name.length>0&&r.name.length<=160&&!/[<>\x00-\x1f]/.test(r.name));traits(r.traits,role);}
   ok(/^pres-\d{1,3}(-s\d{1,5})?$/.test(x.president.id)&&/^ds-\d{1,3}(-s\d{1,5})?$/.test(x.director.id)&&(x.coach.id===null||typeof x.coach.id==='string'&&/^[A-Za-z0-9:._-]{1,240}$/.test(x.coach.id)));
   ok(Array.isArray(x.director.network)&&x.director.network.length>=1&&x.director.network.length<=4&&x.director.network.every(id=>typeof id==='string'&&id.length<=16));
  }
  ok(d.tally&&typeof d.tally==='object'&&Object.keys(d.tally).length<=TALLY_KEYS&&Object.entries(d.tally).every(([k,v])=>k.length<=80&&!/[<>"`&]/.test(k)&&int(v,0,1e6)));
  ok(Array.isArray(d.feed)&&d.feed.length<=FEED&&d.feed.every(t=>typeof t==='string'&&t.length<=400));
  ok(Array.isArray(d.watch)&&d.watch.length<=WATCH&&(d.formed===undefined||Array.isArray(d.formed)&&d.formed.length<=WATCH));
  ok(Array.isArray(d.loans)&&d.loans.length<=LOANS&&d.loans.every(l=>l&&typeof l.playerId==='string'&&int(l.from,0,s.clubs.length-1)&&int(l.to,0,s.clubs.length-1)&&int(l.until,1,s.season+1)));
  ok(d.marks&&typeof d.marks==='object');
  return true;
 }
 return {VERSION,STRATEGIES,active,create,openWindow,weekly,profile,validate,estimate,scores,situation,needs,profileText,
  _internal:{seasonReview,plansFor,returnLoans,medicalJokers,count}};
};

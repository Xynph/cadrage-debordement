'use strict';
// IA des effectifs : saison réelle de la carrière, sans modifier le moteur rugby ni le marché des entraîneurs.
// Choix déterministes, finances en euros et salaires hebdomadaires fictifs.
const AI_ROSTER_MAX_EVENTS=180,AI_ROSTER_MAX_REPORTS=196;
function aiRosterActive(){return S?.aiRosterVersion===1&&S?.aiRoster?.version===1}
function aiRosterSetup(){
 if(!S||!S.economy)return false;
 S.aiRosterVersion=1;
 S.aiRoster={version:1,lastContracts:0,lastIntake:0,lastRecruitment:null,
  events:[],reports:[],academies:S.clubs.filter(c=>c.id!==S.club).map(c=>({clubId:c.id,players:[],intakeSeason:0}))};
 return true;
}
function aiRosterEnable(){
 if(!S||aiRosterActive()||S.live||S.phase!=='league'||Object.keys(S.economy?.talks||{}).length)return false;
 aiRosterSetup();save();render();return true;
}
function aiRosterReport(clubId,season=S.season){
 const state=S.aiRoster;
 let r=state.reports.find(x=>x.clubId===clubId&&x.season===season);
 if(!r){r={clubId,season,renewed:0,released:0,retired:0,recruited:0,promoted:0,emergency:0,fees:0};
  state.reports.push(r);state.reports=state.reports.slice(-AI_ROSTER_MAX_REPORTS)}
 return r;
}
function aiRosterEvent(clubId,kind,p,fee=0){
 const r=aiRosterReport(clubId);
 if(kind==='renew')r.renewed++;
 if(kind==='release')r.released++;
 if(kind==='retire')r.retired++;
 if(kind==='recruit')r.recruited++;
 if(kind==='promote')r.promoted++;
 if(kind==='emergency')r.emergency++;
 r.fees+=fee;
 S.aiRoster.events.unshift({season:S.season,clubId,kind,playerId:p.id,name:p.name,
  salary:p.salary,fee});
 S.aiRoster.events=S.aiRoster.events.slice(0,AI_ROSTER_MAX_EVENTS);
}
function aiRosterPayroll(c){return c.players.reduce((sum,p)=>sum+p.salary,0)}
function aiRosterWageLimit(c){
 const info=worldActive()?worldClub(c.id):null;
 const liquidity=Math.max(0,c.cash-(info?.debt||0));
 // 1 M€ de liquidité nette au-dessus de 1,5 M€ ouvre 11 111 € de salaires hebdomadaires.
 return clamp(Math.round(235000+Math.max(0,liquidity-1500000)/90),215000,335000);
}
function aiRosterContracts(){
 if(!aiRosterActive()||S.aiRoster.lastContracts===S.season)return false;
 S.aiRoster.lastContracts=S.season;
 const e=S.economy;
 for(const c of S.clubs){
  if(c.id===S.club)continue;
  let payroll=aiRosterPayroll(c),released=0;
  const expiry=c.players.filter(p=>p.contractEnd<=S.season).sort((a,b)=>
   aiRosterPriority(c,b)-aiRosterPriority(c,a)||a.id.localeCompare(b.id));
  const maxRelease=Math.min(5,Math.max(1,Math.floor(expiry.length*.45)));
  const releasedIds=new Set();
  for(const p of expiry){
   const salary=clamp(Math.round(p.salary*(p.age>=32?.97:p.age<=27?1.04:1.01)/100)*100,1000,100000);
   const fee=Math.round(p.salary*2/1000)*1000;
   const essential=c.players.length-releasedIds.size<=28||
    [0,1,2].some(slot=>slotEligible(p,slot)&&
      c.players.filter(q=>!releasedIds.has(q.id)&&q.id!==p.id&&q.contractEnd>S.season&&slotEligible(q,slot)).length<2);
   const merit=aiRosterPriority(c,p)>=c.base-4;
   const funded=c.cash>=fee+350000;
   const maintain=essential||released>=maxRelease||
     (merit&&payroll-p.salary+salary<=aiRosterWageLimit(c));
   if(maintain&&funded&&p.age+1<p.dev.retireAge){
    c.cash-=fee;payroll+=salary-p.salary;p.salary=salary;p.contractEnd=S.season+(p.age<30?2:1);
    aiRosterEvent(c.id,'renew',p,fee);
   }else{
    releasedIds.add(p.id);released++;payroll-=p.salary;
    p.formerClub=c.name;p.price=fee;p.contractEnd=null;p.condition=100;p.injury=0;
    e.freeAgents.push(p);
    aiRosterEvent(c.id,'release',p);
   }
  }
  if(releasedIds.size)c.players=c.players.filter(p=>!releasedIds.has(p.id));
 }
 // Les joueurs libérés deviennent accessibles par les systèmes de marché existants.
 e.freeAgents=[...new Map(e.freeAgents.map(p=>[p.id,p])).values()].slice(-60);
 return true;
}
function aiRosterPriority(c,p){
 const role=roleNote(p),age=p.age;
 return role+(age<=25?8:age>=33?-13:age>=30?-5:0)-
  (p.dev.retireAge-age<=2?10:0);
}
function aiRosterRetirement(p,owner){
 if(!aiRosterActive()||!owner||owner.id===S.club)return false;
 aiRosterEvent(owner.id,'retire',p);
 return true;
}
function aiRosterAcademy(c){
 return S.aiRoster.academies.find(a=>a.clubId===c.id);
}
function aiRosterPromote(c,slot,emergency=false){
 if(c.players.length>=40)return false;
 const a=aiRosterAcademy(c);if(!a)return false;
 const eligible=a.players.filter(p=>p.age>=18&&slotEligible(p,slot))
  .sort((x,y)=>fitScore(y,FAMILIES[slot])-fitScore(x,FAMILIES[slot])||x.id.localeCompare(y.id));
 const p=eligible[0];if(!p)return false;
 if(!emergency&&aiRosterPayroll(c)+p.salary>aiRosterWageLimit(c))return false;
 a.players=a.players.filter(x=>x.id!==p.id);
 p.academy=false;p.contractEnd=S.season+2;p.joinedSeason=S.season;p.joinedRound=S.round;
 c.players.push(p);aiRosterEvent(c.id,'promote',p);
 return true;
}
function aiRosterYouthIntake(){
 if(!aiRosterActive()||S.aiRoster.lastIntake===S.season)return false;
 S.aiRoster.lastIntake=S.season;
 for(const c of S.clubs){
  if(c.id===S.club)continue;
  const a=aiRosterAcademy(c),info=worldActive()?worldClub(c.id):null;
  // Formation sur l'année écoulée, puis trois nouveaux espoirs par club.
  for(const p of a.players){
   ageDevelopmentPlayer(p);
   growPlayer(p,(.65+Math.max(0,(info?.facilities||2)-2)*.08)*ageGrowth(p),false);
  }
  a.players=a.players.filter(p=>p.age<=21&&p.age<p.dev.retireAge);
  const needs=recruitmentNeeds(c).slice(0,6);
  for(let k=0;k<3;k++){
   const slot=needs[k]?.slot??(c.id*3+S.season*7+k*5)%15;
   const p=academyPlayer(c.id,slot,S.season,300+k);
   p.dev.potential=clamp(p.dev.potential+Math.max(0,(info?.facilities||2)-2),p.rating,99);
   a.players.push(p);
  }
  a.players=a.players.sort((x,y)=>y.dev.potential-x.dev.potential||x.id.localeCompare(y.id)).slice(0,6);
  a.intakeSeason=S.season;
  let sh=buildSheet(c),serial=0;
  for(let slot=0;slot<23;slot++){
   const target=slot>=15?[1,0,2,3,5,8,9,10][slot-15]:slot;
   if(slot<15?sh.lineup[slot]:sh.bench[slot-15])continue;
   if(aiRosterPromote(c,target,true)){sh=buildSheet(c);continue}
   // Seul le manque de joueur éligible à une feuille réglementaire déclenche un renfort d'urgence.
   const p=academyPlayer(c.id,target,S.season,100+serial++,true);
   p.rating=clamp(c.base-15+seedHash(p.id)%9,54,82);
   delete p.skills;ensureSkills(p);delete p.dev;ensureDevelopment(p);
   p.contractEnd=S.season+2;p.academy=false;c.players.push(p);
   aiRosterEvent(c.id,'emergency',p);sh=buildSheet(c);
  }
  const priority=recruitmentNeeds(c).filter(x=>x.score>=45).slice(0,4);
  for(const n of priority){
   if(c.players.length>=33)break;
   aiRosterPromote(c,n.slot,false);
  }
  const candidates=c.players.slice().sort((x,y)=>y.rating-x.rating).slice(0,23);
  const average=candidates.reduce((sum,p)=>sum+p.rating,0)/Math.max(1,candidates.length);
  const target=clamp(Math.round(average*.75+(info?.reputation??c.base)*.25),57,95);
  c.base=clamp(c.base+clamp(target-c.base,-2,2),57,95);
 }
 return true;
}
function aiRosterRecruitmentChoice(c,targets){
 if(!worldActive()||!targets.length)return null;
 const info=worldClub(c.id);
 if(!info||info.debt>=2000000)return null;
 const pool=targets.filter(t=>CDReputation.recruitmentReach({
  clubReputation:info.reputation,playerReputation:clamp(Math.round(t.evidence.noteMin),0,100),tolerance:15
 }).reachable).map(t=>({id:t.p.id,pos:t.need.pos,fee:t.finance.fee,wage:t.p.salary,
  rating:clamp(Math.round(t.evidence.noteMin),0,100)}));
 const choice=CDClubAI.decideClub({cash:Math.max(0,c.cash-400000),
  wageRoom:Math.max(0,aiRosterWageLimit(c)-aiRosterPayroll(c)),
  needs:[...new Set(targets.map(t=>t.need.pos))],candidates:pool}).candidate;
 return choice?targets.find(t=>t.p.id===choice.id)||null:null;
}
// Fenêtre de marché : tous les clubs éligibles préparent une proposition avant
// que l'un d'eux ne signe. Un joueur ne peut être attribué qu'à un seul club.
// L'arbitrage porte sur les besoins réels et les liquidités ; pas sur les notes
// secrètes d'un joueur non observé ni sur un tirage aléatoire supplémentaire.
function aiRosterAuctionWinner(offers){
 if(!offers.length)return null;
 return offers.slice().sort((a,b)=>b.priority-a.priority||
  b.cashBuffer-a.cashBuffer||a.clubId-b.clubId)[0];
}
function aiRosterMarketProposals(clubs,pool){
 const proposals=[];
 for(const {c,urgent} of clubs){
  if(aiRosterReport(c.id).recruited>=2||c.cash<450000||
   worldActive()&&worldClub(c.id).debt>=2000000)continue;
  const candidates=recruitmentTargets(c,pool,false)
   .filter(t=>t.within&&t.need.score>=45&&t.p.salary<=Math.max(1000,c.base*250)&&
    aiRosterPayroll(c)+t.p.salary<=aiRosterWageLimit(c)&&c.cash-t.finance.fee>=400000);
  const best=aiRosterRecruitmentChoice(c,candidates);
  if(!best)continue;
  proposals.push({c,clubId:c.id,best,playerId:best.p.id,
   priority:best.need.score*10+Math.min(100,Math.round(best.evidence.noteMin)),
   cashBuffer:c.cash-best.finance.fee});
 }
 return proposals;
}
function aiRosterRecruitmentWeek(){
 if(!aiRosterActive()||S.live||S.phase!=='league'||![0,13].includes(S.round)||
  S.season===1&&S.round===0)return 0;
 const key=S.season+':'+S.round,e=S.economy;
 if(e.aiRecruitmentWindow===key)return 0;
 e.aiRecruitmentWindow=key;S.aiRoster.lastRecruitment=key;
 const others=S.clubs.filter(c=>c.id!==S.club&&c.players.length<40)
  .map(c=>({c,urgent:recruitmentNeeds(c)[0]}))
  .filter(x=>x.urgent&&x.urgent.score>=45)
  .sort((a,b)=>b.urgent.score-a.urgent.score||a.c.id-b.c.id);
 let count=0;
 // Plusieurs tours permettent au club perdant une concurrence de rechercher
 // un autre renfort, au lieu de réserver illégitimement le même joueur.
 for(let turn=0;turn<6&&count<6;turn++){
  const pool=[...new Map([...S.market,...e.freeAgents].map(p=>[p.id,p])).values()]
   .filter(p=>!S.clubs.some(x=>x.players.some(y=>y.id===p.id))&&p.age<p.dev.retireAge-1);
  if(!pool.length)break;
  const offers=aiRosterMarketProposals(others,pool);
  if(!offers.length)break;
  const groups=new Map();
  for(const offer of offers){
   if(!groups.has(offer.playerId))groups.set(offer.playerId,[]);
   groups.get(offer.playerId).push(offer);
  }
  const winners=[...groups.values()].map(group=>({
   winner:aiRosterAuctionWinner(group),competitors:group.length
  })).sort((a,b)=>b.winner.priority-a.winner.priority||
   a.winner.clubId-b.winner.clubId);
  let signed=0;
  for(const {winner,competitors} of winners){
   if(count>=6)break;
   const {c,best}=winner,p=best.p;
   if(aiRosterReport(c.id).recruited>=2||c.players.length>=40||
    !pool.some(x=>x.id===p.id)||S.clubs.some(x=>x.players.some(y=>y.id===p.id))||
    c.cash-best.finance.fee<400000||
    aiRosterPayroll(c)+p.salary>aiRosterWageLimit(c))continue;
   c.cash-=best.finance.fee;
   p.contractEnd=S.season+Math.min(2,Math.max(1,p.dev.retireAge-p.age-1));
   p.joinedSeason=S.season;p.joinedRound=S.round;c.players.push(p);
   S.market=S.market.filter(x=>x.id!==p.id);
   e.freeAgents=e.freeAgents.filter(x=>x.id!==p.id);
   e.transfers.unshift({season:S.season,round:S.round,text:c.name+' recrute '+p.name+
    ' pour '+money(best.finance.fee)+' (besoin : '+best.need.pos+
    (competitors>1?' ; '+competitors+' clubs intéressés':'')+').'});
   e.transfers=e.transfers.slice(0,80);
   aiRosterEvent(c.id,'recruit',p,best.finance.fee);
   count++;signed++;
  }
  if(!signed)break;
 }
 return count;
}
function aiRosterPanel(){
 if(!aiRosterActive())return '<section class="card"><h2>Évolution des effectifs IA</h2>'+
 '<p class="help">Cette ancienne carrière conserve la gestion historique. Activation volontaire de contrats, formations et décisions financières plus sélectifs pour les clubs adverses.</p>'+
 '<button class="small dark" onclick="aiRosterEnable()" '+(S.live||S.phase!=='league'?'disabled':'')+
 '>Activer le cycle des effectifs IA</button></section>';
 const st=S.aiRoster,season=S.season;
 const rows=S.clubs.filter(c=>c.id!==S.club).map(c=>{
  const r=st.reports.find(x=>x.season===season&&x.clubId===c.id),a=aiRosterAcademy(c);
  const w=aiRosterPayroll(c),limit=aiRosterWageLimit(c);
  return '<tr><td>'+visualEscape(c.abbr)+'</td><td>'+c.players.length+'</td><td>'+
   (a?.players.length||0)+'</td><td>'+money(w)+' / '+money(limit)+'</td><td>'+
   (r?.renewed||0)+' / '+(r?.released||0)+'</td><td>'+
   (r?.recruited||0)+' / '+(r?.promoted||0)+'</td></tr>';
 }).join('');
 const history=st.events.slice(0,15).map(x=>'<div class="news"><small>S'+x.season+' · '+
  visualEscape(S.clubs[x.clubId]?.abbr||'Club')+' · '+
  ({renew:'Prolongation',release:'Départ libre',retire:'Retraite',recruit:'Recrutement',
   promote:'Promotion formation',emergency:'Renfort d’urgence'})[x.kind]+'</small>'+
  '<p>'+visualEscape(x.name)+(x.fee?' · coût '+money(x.fee):'')+'</p></div>').join('');
 return '<section class="card"><h2>Observatoire des effectifs IA</h2>'+
 '<p class="help">Simulation fictive : les clubs prennent des décisions de contrats, recrutent dans le marché existant, développent des espoirs et conservent une réserve financière. Les salaires sont hebdomadaires ; une seule fenêtre de recrutement par demi-saison. La formation d’urgence intervient uniquement si la feuille de match manque de joueurs qualifiés.</p>'+
 '<div class="tablewrap"><table><thead><tr><th>Club</th><th>Pros</th><th>Espoirs</th>'+
 '<th>Salaires / plafond indicatif</th><th>Prolongations / départs S'+season+'</th>'+
 '<th>Recrues / jeunes promus</th></tr></thead><tbody>'+rows+'</tbody></table></div>'+
 '<h3>Mouvements vérifiables</h3>'+(history||'<p>Les mouvements apparaîtront après les prochaines journées et l’intersaison.</p>')+
 '</section>';
}

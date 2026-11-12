'use strict';
// Transferts entre clubs gérés d'une carrière mondiale (installé dans la VM native).
// À chaque fenêtre de recrutement des clubs gérés (début de saison à partir de la
// deuxième, et semaine 13), avant leur recrutement de joueurs libres, chaque club
// suit une stratégie lisible déduite de sa situation publique :
//   vedettes      : club riche et réputé, achète des joueurs plus forts que ses titulaires ;
//   formateur     : bon centre ou effectif jeune, vend ses jeunes réussis, achète jeune et bon marché ;
//   rajeunissement: effectif âgé, achète des moins de 26 ans et cède ses trentenaires ;
//   vente         : trésorerie tendue, dette ou masse au-dessus de ce qu'il s'autorise : vend ses gros salaires ;
//   equilibre     : comble ses besoins par poste.
// Bornes : 3 achats et 3 ventes par club et par saison, une transaction par club et par
// tour, l'effectif du vendeur ne descend pas sous sa cible moins trois et garde ses
// postes couverts ; l'acheteur respecte sa masse autorisée (plafond de la ligue
// quand la règle des salaires est active), sa réserve de trésorerie et ses places.
// Choix déterministes (empreintes), sans tirage dans le générateur des matchs.
// Le club du manager n'achète ni ne vend par ce chemin.
module.exports=function clubTransfers(){
 const MAX_BUYS=3,MAX_SALES=3,ROUNDS=3,CASH_FLOOR=400000;
 const STRATEGIES=Object.freeze(['vedettes','formateur','rajeunissement','vente','equilibre']);
 const world=()=>typeof CDWorldCareer!=='undefined'&&CDWorldCareer.active(S);
 const enabled=()=>world()&&typeof aiRosterPopulationActive==='function'&&aiRosterPopulationActive();
 const leagueOf=id=>{for(const [key,l] of Object.entries(S.worldMode.leagues))if(l.members.includes(id))return key;return null;};
 const japanese=id=>['jlo-d1','jlo-d2'].includes(leagueOf(id));
 const median=v=>{const s=v.slice().sort((a,b)=>a-b);return s.length?s[s.length>>1]:0;};
 const annual=c=>aiRosterPayroll(c)*52;
 // Estimation par la cellule de recrutement du club : note de rôle à ±3 points près,
 // stable pour un couple club-joueur.
 const estimate=(clubId,p)=>roleNote(p)+(seedHash('scout|'+clubId+'|'+p.id)%7)-3;
 const primarySlot=p=>Math.max(0,POS.indexOf(p.pos));
 const slotGoal=(c,slot)=>{const row=AI_POPULATION_DEPTH.find(([s])=>s===slot);return row?Math.max(2,Math.round(row[1]*aiRosterTarget(c)/37)):2;};
 const covered=(c,slot,without)=>c.players.filter(p=>p.id!==without&&p.age<p.dev.retireAge&&slotEligible(p,slot)).length;
 function leagueRows(){
  const rows={};
  for(const c of S.clubs){if(c.id===S.club)continue;const key=leagueOf(c.id);(rows[key]??=[]).push(c);}
  return rows;
 }
 function strategy(c,peers){
  const info=worldClub(c.id)||{reputation:c.base,facilities:2,debt:0};
  const limit=aiRosterWageLimit(c),payroll=aiRosterPayroll(c);
  const cashMedian=median(peers.map(x=>x.cash)),repMedian=median(peers.map(x=>worldClub(x.id)?.reputation??x.base));
  if(info.debt>0||c.cash<900000||payroll>limit)return 'vente';
  if(info.reputation>=repMedian+3&&c.cash>=Math.max(1500000,cashMedian*1.15)&&payroll<=limit*.95)return 'vedettes';
  const core=c.players.slice().sort((a,b)=>roleNote(b)-roleNote(a)).slice(0,30);
  const age=core.reduce((n,p)=>n+p.age,0)/Math.max(1,core.length);
  if(age>=27.3)return 'rajeunissement';
  const young=c.players.filter(p=>p.age<=22).length/Math.max(1,c.players.length);
  if(info.facilities>=3||young>=.3)return 'formateur';
  return 'equilibre';
 }
 // Indemnité demandée : salaire annuel × années de contrat restantes (au plus deux),
 // pondéré par l'âge ; arrondie aux 10 000 €.
 function value(p){
  const years=clamp((p.contractEnd??S.season)-S.season+1,1,2);
  const age=p.age<=23?1.6:p.age<=26?1.3:p.age<=29?1:p.age<=31?.6:.3;
  return Math.max(10000,Math.round(p.salary*52*years*age/10000)*10000);
 }
 function listed(c,plan,reports){
  if((reports.get(c.id)?.sold||0)>=MAX_SALES)return [];
  const goal=aiRosterTarget(c),floor=goal-3;
  if(c.players.length<=floor)return [];
  const fresh=p=>p.joinedSeason===S.season||p.contractEnd==null||p.contractEnd<S.season;
  const keep=p=>covered(c,primarySlot(p),p.id)<Math.max(2,slotGoal(c,primarySlot(p))-1);
  const pool=c.players.filter(p=>!fresh(p)&&!keep(p)&&p.age<p.dev.retireAge-1);
  const ranked=pool.slice().sort((a,b)=>estimate(c.id,b)-estimate(c.id,a)||a.id.localeCompare(b.id));
  const top=new Set(ranked.slice(0,5).map(p=>p.id));
  let picks=[];
  if(plan==='vente')picks=pool.filter(p=>p.age>=24).sort((a,b)=>b.salary-a.salary||a.id.localeCompare(b.id)).slice(0,3);
  else if(plan==='formateur')picks=pool.filter(p=>p.age<=24&&estimate(c.id,p)>=c.base-6).sort((a,b)=>estimate(c.id,b)-estimate(c.id,a)||a.id.localeCompare(b.id)).slice(0,2);
  else if(plan==='rajeunissement')picks=pool.filter(p=>p.age>=30).sort((a,b)=>b.salary-a.salary||a.id.localeCompare(b.id)).slice(0,3);
  // Surplus à un poste : le moins bien noté du poste le plus fourni.
  const surplus=pool.filter(p=>covered(c,primarySlot(p),null)>slotGoal(c,primarySlot(p))+2&&!top.has(p.id))
   .sort((a,b)=>estimate(c.id,a)-estimate(c.id,b)||a.id.localeCompare(b.id))[0];
  if(surplus&&!picks.includes(surplus))picks.push(surplus);
  return picks.map(p=>({p,seller:c,fee:plan==='vente'?Math.round(value(p)*.8/10000)*10000:value(p),listed:true}));
 }
 // Joueurs non proposés qu'un club plus réputé peut obtenir en payant une fois et
 // demie leur valeur : jamais l'un des trois meilleurs du vendeur.
 function poachable(buyer,c,plans,reports,ranked){
  if(c.id===buyer.id||plans.get(c.id)==='vedettes'||(reports.get(c.id)?.sold||0)>=MAX_SALES)return [];
  const rb=worldClub(buyer.id)?.reputation??buyer.base,rs=worldClub(c.id)?.reputation??c.base;
  if(rs>rb-5||c.players.length<=aiRosterTarget(c)-3)return [];
  if(!ranked.has(c.id))ranked.set(c.id,c.players.slice().sort((a,b)=>estimate(c.id,b)-estimate(c.id,a)||a.id.localeCompare(b.id)));
  const order=ranked.get(c.id),best=new Set(order.slice(0,3).map(p=>p.id));
  return order.filter(p=>!best.has(p.id)&&p.joinedSeason!==S.season&&p.contractEnd!=null&&p.contractEnd>=S.season&&p.age<=29&&p.age<p.dev.retireAge-1&&
   covered(c,primarySlot(p),p.id)>=Math.max(2,slotGoal(c,primarySlot(p))-1)).slice(0,4)
   .map(p=>({p,seller:c,fee:Math.round(value(p)*1.5/10000)*10000,listed:false}));
 }
 // Ce que le joueur demande pour signer chez l'acheteur : son salaire, l'attrait du
 // championnat quand la règle des salaires le fournit, sinon l'écart de réputation.
 let memo={};
 function demand(p,seller,buyer){
  const key=buyer.id+'|'+p.id;
  if(!memo.demand)memo.demand=new Map();
  if(!memo.demand.has(key))memo.demand.set(key,rawDemand(p,seller,buyer));
  return memo.demand.get(key);
 }
 function rawDemand(p,seller,buyer){
  // Règle des salaires active (carrières marquées) : salaire juste chez l'acheteur × attrait du championnat.
  if(typeof budgetActif==='function'&&budgetActif()&&typeof nativeStartingSalaries!=='undefined'&&typeof nativeLeagueEconomy!=='undefined'){
   const forces=memo.forces??=budgetForces(),juste=nativeStartingSalaries.demande(S,forces,buyer.id,p,nativeLeagueEconomy);
   const a=nativeLeagueEconomy.attrait({origine:budgetLigue(seller.id),destination:budgetLigue(buyer.id),joueurId:p.id,age:p.age,situation:nativeLeagueEconomy.situation(p,S.season,buyer.id,buyer.name)});
   // Le joueur ne signe pas sous son salaire actuel ni sous ce que l'attrait lui fait demander.
   return Math.max(p.salary*a.multiplicateur,juste*a.multiplicateur);
  }
  const gap=(worldClub(seller.id)?.reputation??seller.base)-(worldClub(buyer.id)?.reputation??buyer.base);
  return p.salary*(1+Math.max(-.08,Math.min(.25,gap*.008)));
 }
 // Ce que l'acheteur sait de lui-même, calculé une fois par tour : besoins et
 // niveau estimé du dernier titulaire à chaque poste.
 function profile(buyer){
  const needs=aiRosterMarketNeeds(buyer),starters=POS.map((pos,slot)=>{
   const mates=buyer.players.filter(q=>slotEligible(q,slot)).map(q=>estimate(buyer.id,q)).sort((a,b)=>b-a);
   return mates[Math.max(0,Math.min(mates.length-1,POS.filter(x=>x===pos).length-1))]??0;
  });
  return {needs,starters};
 }
 function wanted(buyer,plan,offer,known){
  const p=offer.p,est=estimate(buyer.id,p);
  if(p.age>=p.dev.retireAge-1)return null;
  if(plan==='vente'&&buyer.players.length>=aiRosterTarget(buyer)-2)return null;
  if(plan==='formateur'&&(p.age>23||offer.fee>buyer.cash*.1))return null;
  if(plan==='rajeunissement'&&p.age>25)return null;
  const need=known.needs.find(n=>slotEligible(p,n.slot)),slot=primarySlot(p);
  const upgrade=est-known.starters[slot];
  if(!need&&!(plan==='vedettes'&&upgrade>=3)&&!(plan==='rajeunissement'&&upgrade>=0&&p.age<=24))return null;
  if(est<buyer.base-14)return null;
  return {score:(need?need.score:0)+upgrade*4+(plan==='vedettes'?est:0)-(offer.listed?0:10)-Math.round(offer.fee/200000),need:need?.pos||POS[slot],upgrade};
 }
 function affordable(buyer,offer,salary){
  const info=worldClub(buyer.id);
  if(info&&info.debt>=2000000)return false;
  if(professionalPlaces(buyer)<=0)return false;
  if(aiRosterPayroll(buyer)+salary>aiRosterWageLimit(buyer))return false;
  return buyer.cash-offer.fee-CASH_FLOOR>=salary*8;
 }
 function execute(buyer,offer,salary,plan,sellerPlan,need){
  const p=offer.p,seller=offer.seller;
  seller.players=seller.players.filter(x=>x.id!==p.id);
  seller.cash+=offer.fee;buyer.cash-=offer.fee;
  p.formerClub=seller.name;p.salary=salary;p.contractEnd=S.season+(p.age<=27?3:2);
  p.joinedSeason=S.season;p.joinedRound=S.round;p.price=offer.fee;
  buyer.players.push(p);
  aiRosterEvent(seller.id,'sell',p,offer.fee);aiRosterEvent(buyer.id,'recruit',p,offer.fee);
  S.economy.transfers.unshift({season:S.season,round:S.round,text:buyer.name+' achète '+p.name+' à '+seller.name+' pour '+money(offer.fee)+' (besoin : '+need+').'});
  S.economy.transfers=S.economy.transfers.slice(0,80);
  return {season:S.season,round:S.round,buyer:buyer.id,seller:seller.id,playerId:p.id,fee:offer.fee,salary,plan,sellerPlan};
 }
 function transferWindow(){
  if(!enabled())return [];
  memo={};
  try{return openWindow();}finally{memo={};}
 }
 function openWindow(){
  const rows=leagueRows(),plans=new Map(),reports=new Map(),done=[];
  for(const peers of Object.values(rows))for(const c of peers)plans.set(c.id,strategy(c,peers));
  for(const c of S.clubs)if(c.id!==S.club){const r=aiRosterReport(c.id);r.strategy=plans.get(c.id);reports.set(c.id,r);}
  const clubs=S.clubs.filter(c=>c.id!==S.club);
  const order=p=>({vedettes:0,rajeunissement:1,equilibre:2,formateur:3,vente:4})[p];
  for(let round=0;round<ROUNDS;round++){
   const busy=new Set();let signed=0;
   const offers=clubs.flatMap(c=>listed(c,plans.get(c.id),reports));
   // Un club « vedettes » ou qui rajeunit peut dépasser sa cible de deux places
   // pour un renfort : il cédera ensuite son surplus.
   const room=c=>aiRosterMayRecruit(c)||['vedettes','rajeunissement'].includes(plans.get(c.id))&&c.players.length<aiRosterTarget(c)+2&&professionalPlaces(c)>0;
   const ranked=new Map();
   const buyers=clubs.filter(c=>(reports.get(c.id).bought||0)<MAX_BUYS&&room(c))
    .sort((a,b)=>order(plans.get(a.id))-order(plans.get(b.id))||(worldClub(b.id)?.reputation??0)-(worldClub(a.id)?.reputation??0)||a.id-b.id);
   for(const buyer of buyers){
    if(busy.has(buyer.id))continue;
    const plan=plans.get(buyer.id);
    const known=profile(buyer);
    const pool=offers.concat(plan==='vedettes'?clubs.flatMap(c=>poachable(buyer,c,plans,reports,ranked)):[])
     .filter(o=>o.seller.id!==buyer.id&&!busy.has(o.seller.id)&&o.seller.players.some(x=>x.id===o.p.id)&&(!japanese(buyer.id)||japanese(o.seller.id)));
    let best=null;
    for(const offer of pool){
     const w=wanted(buyer,plan,offer,known);if(!w)continue;
     if(aiRosterPayroll(buyer)+offer.p.salary>aiRosterWageLimit(buyer)||buyer.cash-offer.fee-CASH_FLOOR<0)continue;
     const salary=clamp(Math.round(Math.max(offer.p.salary,demand(offer.p,offer.seller,buyer))*(plan==='vedettes'?1.08:1.03)/100)*100,270,100000);
     if(!affordable(buyer,offer,salary))continue;
     if(!best||w.score>best.w.score||w.score===best.w.score&&offer.p.id<best.offer.p.id)best={offer,w,salary};
    }
    if(!best)continue;
    const row=execute(buyer,best.offer,best.salary,plan,plans.get(best.offer.seller.id),best.w.need);
    reports.get(buyer.id).bought=(reports.get(buyer.id).bought||0)+1;
    reports.get(best.offer.seller.id).sold=(reports.get(best.offer.seller.id).sold||0)+1;
    busy.add(buyer.id);busy.add(best.offer.seller.id);done.push(row);signed++;
   }
   if(!signed)break;
  }
  return done;
 }
 let installed=false;
 function installHooks(){
  if(installed)return;installed=true;
  const previous=aiRosterRecruitmentWeek;
  aiRosterRecruitmentWeek=function(){
   const week=S?.franceMode?.week??S?.round,windows=S?.franceMode?[0,15]:[0,13];
   const open=S&&aiRosterActive()&&!S.live&&S.phase==='league'&&windows.includes(week)&&!(S.season===1&&week===0)&&S.economy.aiRecruitmentWindow!==S.season+':'+week;
   // Carrières créées avec des directions de club : stratégie émergente (club-directions.cjs).
   const directed=typeof nativeClubDirections!=='undefined'&&nativeClubDirections.active();
   let moves=[];
   if(directed){memo={};try{nativeClubDirections.weekly();if(open)moves=nativeClubDirections.openWindow();}finally{memo={};}}
   else if(open)moves=transferWindow();
   const count=previous.apply(this,arguments);
   if(directed&&open&&count)S.clubDirections.tally[S.season+'|monde|libre']=(S.clubDirections.tally[S.season+'|monde|libre']||0)+count;
   return count+moves.length;
  };
 }
 return {installHooks,transferWindow,strategy,value,demand,memoOf:()=>memo,STRATEGIES};
};

'use strict';
// Immediate, consensual fictional releases. No registration or legal-window claim.
function factory(){
 const check=(ok,message)=>{if(!ok)throw Error('Marché entre clubs : '+message+'.');};
 const object=x=>x!==null&&typeof x==='object'&&!Array.isArray(x);
 const shape=(x,keys)=>object(x)&&Object.keys(x).length===keys.length&&Object.keys(x).every(k=>keys.includes(k));
 const integer=(n,min,max)=>Number.isSafeInteger(n)&&n>=min&&n<=max;
 const week=()=>S.worldMode?.week??S.franceMode?.week??S.round;
 const context=()=>({season:S.season,week:week(),club:S.club});
 // Local transfer safety for the canonical historical 30-player fiction.
 // aiRosterVersion is shared by fiction and reference universes; it is not a
 // roster-size provenance marker. Never alter the global AI population floor.
 function releasePolicy(s){
  const reference=['commonDatabase','worldMode','franceMode','lnrMode','rosterFoundation','identityPack'].some(k=>s[k]!==undefined);
  const fiction=!reference&&s.version===2&&s.worldVersion===1&&s.integratedManagementVersion===1&&s.clubs?.length===14&&s.clubs.every((c,i)=>c.id===i)&&
   (s.customCompetition===undefined||s.customCompetition?.version===1&&s.customCompetition?.clubs?.length===14);
  return {kind:fiction?'historical-fiction-30':'reference-or-unknown',minimum:fiction?28:37,notice:fiction?'Effectif minimum : 28 professionnels après départ (23 de feuille et cinq couvertures), deux joueurs par famille et deux piliers de chaque côté.':'Effectif minimum : 37 professionnels après départ, deux joueurs par famille et deux piliers de chaque côté.'};
 }
 const loans=()=>[S.v78to81,...Object.values(S.nativeAcademy?.offices||{}).map(o=>o.v78to81)].flatMap(o=>o?.loans||[]).filter(l=>l.season===S.season);
 function quote(c,p,loanIds=new Set(loans().map(l=>l.id))){
  const own=S.clubs[S.club],weeks=wageForecastWeeks(S),sourceSalary=p.salary,contractEnd=p.contractEnd;
  const fee=Math.max(20000,Math.ceil(sourceSalary*weeks*Math.max(1,contractEnd-S.season+1)/20000)*10000);
  const salary=Math.max(1000,Math.ceil(sourceSalary*1.05/100)*100);
  let reason='';
  if(S.live||S.phase!=='league')reason='Accords disponibles hors match en saison régulière';
  else if(!integer(p.age,18,60)||!integer(contractEnd,S.season,9999))reason='Joueur majeur sous contrat requis';
  else if(loanIds.has(p.id))reason='Joueur concerné par un prêt';
  else if(saleBlocked(p))reason=saleBlocked(p);
  else if(c.players.length<=releasePolicy(S).minimum)reason='Le vendeur conserve au moins '+releasePolicy(S).minimum+' professionnels';
  else if((p.fam===0&&c.players.filter(q=>q.id!==p.id&&q.pos===p.pos).length<2)||c.players.filter(q=>q.id!==p.id&&q.fam===p.fam).length<2)reason='Le vendeur doit conserver deux joueurs de cette famille de poste';
  const releaseReason=reason;
  if(!reason&&professionalPlaces(own,S)<=0)reason='Effectif acheteur complet';
  else if(own.cash<fee+400000)reason='Réserve de trésorerie de 400 000 € requise après indemnité';
  else if(salary>100000)reason='La demande salariale dépasse le plafond de 100 000 € par semaine';
  else if(own.cash-fee-400000<salary*Math.min(8,Math.max(0,weeks-week())))reason='Trésorerie insuffisante pour provisionner les huit prochaines semaines du nouveau salaire';
  return {id:p.id,name:p.name,clubId:c.id,club:c.name,pos:p.pos,family:p.fam,age:p.age,contractEnd,sourceSalary,fee,salary,available:!reason,reason,releaseReason};
 }
 function project(){
  const available=typeof S!=='undefined'&&!!S?.economy&&!!S.clubs?.[S.club];
  const base={available,releasePolicy:available?releasePolicy(S):null,context:available?context():null,candidates:[],notice:'Accord de libération anticipée. Indemnité intégralement versée au club vendeur ; salaire proposé +5 % (minimum 1 000 €/semaine), échéance conservée. La profondeur de libération dépend de l’univers et reste affichée ; deux joueurs de la famille et deux piliers de chaque côté sont conservés. Réserve de 400 000 € et provision des huit prochaines semaines du nouveau salaire ; aucune inscription réglementaire automatique.'};
  if(!available)return base;
  base.notice+=' '+base.releasePolicy.notice;
  const loanIds=new Set(loans().map(l=>l.id));
  base.candidates=S.clubs.filter(c=>c.id!==S.club).flatMap(c=>c.players.map(p=>quote(c,p,loanIds))).sort((a,b)=>a.clubId-b.clubId||a.contractEnd-b.contractEnd||a.name.localeCompare(b.name));
  return base;
 }
 function publicNeed(c,p){
  const eligible=c.players.filter(q=>p.fam===0?q.pos===p.pos:q.fam===p.fam);
  const durable=eligible.filter(q=>q.contractEnd>S.season&&!q.injury&&(q.condition??100)>=70).length;
  const desired=[2,3].includes(p.fam)?5:p.fam===6?4:3;
  return Math.max(0,desired-durable);
 }
 function affordable(c,fee,salary,ai=false){
  return professionalPlaces(c,S)>0&&c.cash-fee-400000>=salary*Math.min(8,Math.max(0,wageForecastWeeks(S)-week()))&&(!ai||c.players.reduce((n,p)=>n+p.salary,0)+salary<=aiRosterWageLimit(c));
 }
 function negotiate(p){
  check(typeof S!=='undefined'&&S?.economy&&!S.live&&S.phase==='league','négociation indisponible');
  check(shape(p,['playerId','sellerId','fee','salary','sourceSalary','contractEnd','context'])&&typeof p.playerId==='string'&&p.playerId.length>0&&p.playerId.length<=120&&integer(p.sellerId,0,S.clubs.length-1)&&p.sellerId!==S.club&&integer(p.fee,0,1000000000)&&integer(p.salary,1000,100000)&&integer(p.sourceSalary,0,100000)&&integer(p.contractEnd,S.season,9999),'proposition invalide');
  const now=context();check(shape(p.context,['season','week','club'])&&Object.keys(now).every(k=>p.context[k]===now[k]),'contexte périmé');
  const seller=S.clubs[p.sellerId],player=seller.players.find(q=>q.id===p.playerId);
  check(player&&player.salary===p.sourceSalary&&player.contractEnd===p.contractEnd,'joueur ou contrat source modifié');
  const q=quote(seller,player);check(!q.releaseReason,q.releaseReason);
  const sellerResponse={accepted:p.fee>=q.fee,counter:q.fee,reason:p.fee>=q.fee?'Le vendeur accepte cette indemnité.':'Le vendeur demande au moins '+money(q.fee)+'.'};
  const playerResponse={accepted:p.salary>=q.salary,counter:q.salary,reason:p.salary>=q.salary?'Le joueur accepte ce salaire.':'Le joueur demande au moins '+money(q.salary)+' par semaine.'};
  const offers=[],humanReady=sellerResponse.accepted&&playerResponse.accepted&&affordable(S.clubs[S.club],p.fee,p.salary);
  if(humanReady)offers.push({clubId:S.club,club:S.clubs[S.club].name,fee:p.fee,salary:p.salary,need:publicNeed(S.clubs[S.club],player),human:true});
  for(const c of S.clubs){
   if(c.id===S.club||c.id===seller.id)continue;
   const need=publicNeed(c,player);if(need<=0)continue;
   const fee=Math.ceil(q.fee*(1+Math.min(5,need)*.04)/1000)*1000,salary=Math.min(100000,Math.ceil(q.salary*(1+Math.min(5,need)*.025)/100)*100);
   if(salary<q.salary||!affordable(c,fee,salary,true))continue;
   offers.push({clubId:c.id,club:c.name,fee,salary,need,human:false});
  }
  offers.sort((a,b)=>b.salary-a.salary||b.fee-a.fee||b.need-a.need||a.clubId-b.clubId);
  return {playerId:player.id,sellerId:seller.id,context:now,seller:sellerResponse,player:playerResponse,humanReady,humanReason:humanReady?'Offre recevable.':q.salary>100000?'La demande du joueur dépasse le plafond salarial de 100 000 € ; aucun accord possible.':!affordable(S.clubs[S.club],p.fee,p.salary)?'Effectif ou provision financière insuffisants.':'Indemnité ou salaire refusé.',offers,winner:offers[0]||null,notice:'Les offres sont examinées à la clôture selon le salaire, l’indemnité et les besoins du club. Aucune transaction avant confirmation.'};
 }
 function auction(p){
  check(shape(p,['playerId','sellerId','fee','salary','sourceSalary','contractEnd','context','expectedWinner','expectedFee','expectedSalary','confirmed'])&&p.confirmed===true&&integer(p.expectedWinner,0,S.clubs.length-1)&&integer(p.expectedFee,20000,1000000000)&&integer(p.expectedSalary,1000,100000),'clôture invalide');
  const {expectedWinner,expectedFee,expectedSalary,confirmed,...offer}=p,result=negotiate(offer),win=result.winner;
  check(win&&win.clubId===expectedWinner&&win.fee===expectedFee&&win.salary===expectedSalary,'devis concurrent devenu périmé ; vérifiez à nouveau');
  const seller=S.clubs[p.sellerId],buyer=S.clubs[win.clubId],player=seller.players.find(q=>q.id===p.playerId);
  seller.players=seller.players.filter(q=>q.id!==player.id);buyer.players.push(player);seller.cash+=win.fee;
  if(buyer.id===S.club)ledgerEntry('Libération anticipée négociée : '+player.name,-win.fee);else buyer.cash-=win.fee;
  player.salary=win.salary;player.joinedSeason=S.season;player.joinedRound=S.round;
  delete S.economy.listings[player.id];S.economy.offers=S.economy.offers.filter(o=>o.playerId!==player.id);S.market=S.market.filter(x=>x.id!==player.id);S.economy.freeAgents=S.economy.freeAgents.filter(x=>x.id!==player.id);
  transferEvent(player.name+' rejoint '+buyer.name+' après concurrence entre '+result.offers.length+' club(s), pour '+money(win.fee)+'.');
  return {interclubTransfer:{playerId:player.id,sellerId:seller.id,buyerId:buyer.id,fee:win.fee,salary:win.salary,contractEnd:player.contractEnd,competingClubs:result.offers.length,humanWon:buyer.id===S.club}};
 }
 function execute(command,p){
  if(command==='interclub_negotiate')return {interclubNegotiation:negotiate(p)};
  if(command==='interclub_auction')return auction(p);
  check(command==='interclub_transfer','commande inconnue');check(typeof S!=='undefined'&&S?.economy&&!S.live&&S.phase==='league','accord indisponible');
  check(shape(p,['playerId','sellerId','fee','salary','sourceSalary','contractEnd','context','confirmed'])&&typeof p.playerId==='string'&&p.playerId.length<=120&&integer(p.sellerId,0,S.clubs.length-1)&&p.sellerId!==S.club&&integer(p.fee,20000,1000000000)&&integer(p.salary,1000,100000)&&integer(p.sourceSalary,0,100000)&&integer(p.contractEnd,S.season,9999)&&p.confirmed===true,'proposition invalide ou non confirmée');
  const now=context();check(shape(p.context,['season','week','club'])&&Object.keys(now).every(k=>p.context[k]===now[k]),'contexte périmé');
  const seller=S.clubs[p.sellerId],buyer=S.clubs[S.club],player=seller.players.find(q=>q.id===p.playerId);
  check(player&&!buyer.players.some(q=>q.id===p.playerId),'joueur indisponible');
  const q=quote(seller,player);check(q.available,q.reason);check(player.salary===p.sourceSalary&&player.contractEnd===p.contractEnd,'contrat source modifié');
  check(p.fee>=q.fee,'le vendeur refuse cette indemnité');check(p.salary>=q.salary,'le joueur refuse ce salaire');
  check(buyer.cash-p.fee>=400000,'réserve financière insuffisante');check(buyer.cash-p.fee-400000>=p.salary*Math.min(8,Math.max(0,wageForecastWeeks(S)-week())),'provision salariale insuffisante');
  // All checks precede writes. The worker owns disk commit and rollback.
  seller.players=seller.players.filter(x=>x.id!==player.id);buyer.players.push(player);seller.cash+=p.fee;
  ledgerEntry('Libération anticipée : '+player.name,-p.fee);
  player.salary=p.salary;player.joinedSeason=S.season;player.joinedRound=S.round;
  delete S.economy.listings[player.id];S.economy.offers=S.economy.offers.filter(o=>o.playerId!==player.id);
  S.market=S.market.filter(x=>x.id!==player.id);S.economy.freeAgents=S.economy.freeAgents.filter(x=>x.id!==player.id);
  transferEvent(player.name+' rejoint '+buyer.name+' depuis '+seller.name+' : accord de '+money(p.fee)+', fin de contrat '+(typeof libelleSaison==='function'?libelleSaison:String)(player.contractEnd)+'.');
  return {interclubTransfer:{playerId:player.id,sellerId:seller.id,buyerId:buyer.id,fee:p.fee,salary:player.salary,contractEnd:player.contractEnd}};
 }
 return {project,execute,validate:()=>true,installHooks:()=>true};
}
module.exports={files:[],commands:['interclub_transfer','interclub_negotiate','interclub_auction'],factory};

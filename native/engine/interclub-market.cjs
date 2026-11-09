'use strict';
// Immediate, consensual fictional releases. No registration or legal-window claim.
function factory(){
 const check=(ok,message)=>{if(!ok)throw Error('Marché entre clubs : '+message+'.');};
 const object=x=>x!==null&&typeof x==='object'&&!Array.isArray(x);
 const shape=(x,keys)=>object(x)&&Object.keys(x).length===keys.length&&Object.keys(x).every(k=>keys.includes(k));
 const integer=(n,min,max)=>Number.isSafeInteger(n)&&n>=min&&n<=max;
 const week=()=>S.worldMode?.week??S.franceMode?.week??S.round;
 const context=()=>({season:S.season,week:week(),club:S.club});
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
  else if(c.players.length<=37)reason='Le vendeur conserve au moins 37 professionnels';
  else if((p.fam===0&&c.players.filter(q=>q.id!==p.id&&q.pos===p.pos).length<2)||c.players.filter(q=>q.id!==p.id&&q.fam===p.fam).length<2)reason='Le vendeur doit conserver deux joueurs de cette famille de poste';
  else if(professionalPlaces(own,S)<=0)reason='Effectif acheteur complet';
  else if(own.cash<fee+400000)reason='Réserve de trésorerie de 400 000 € requise après indemnité';
  else if(salary>100000||own.cash-fee-400000<salary*Math.min(8,Math.max(0,weeks-week())))reason='Trésorerie insuffisante pour provisionner les huit prochaines semaines du nouveau salaire';
  return {id:p.id,name:p.name,clubId:c.id,club:c.name,pos:p.pos,age:p.age,contractEnd,sourceSalary,fee,salary,available:!reason,reason};
 }
 function project(){
  const available=typeof S!=='undefined'&&!!S?.economy&&!!S.clubs?.[S.club];
  const base={available,context:available?context():null,candidates:[],notice:'Accord de libération anticipée fictif. Indemnité intégralement versée au club vendeur ; salaire proposé +5 % (minimum 1 000 €/semaine), échéance conservée. Le vendeur garde 37 professionnels et deux joueurs de la famille. Réserve de 400 000 € et provision des huit prochaines semaines du nouveau salaire ; aucune inscription réglementaire automatique.'};
  if(!available)return base;
  const loanIds=new Set(loans().map(l=>l.id));
  base.candidates=S.clubs.filter(c=>c.id!==S.club).flatMap(c=>c.players.map(p=>quote(c,p,loanIds))).sort((a,b)=>a.clubId-b.clubId||a.contractEnd-b.contractEnd||a.name.localeCompare(b.name));
  return base;
 }
 function execute(command,p){
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
  transferEvent(player.name+' rejoint '+buyer.name+' depuis '+seller.name+' : accord fictif de '+money(p.fee)+', fin de contrat S'+player.contractEnd+'.');
  return {interclubTransfer:{playerId:player.id,sellerId:seller.id,buyerId:buyer.id,fee:p.fee,salary:player.salary,contractEnd:player.contractEnd}};
 }
 return {project,execute,validate:()=>true,installHooks:()=>true};
}
module.exports={files:[],commands:['interclub_transfer'],factory};

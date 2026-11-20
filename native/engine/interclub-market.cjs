'use strict';
// Consensual releases between clubs. Calendrier des mutations (calendrier-mutations.cjs, décision de Léo du 19/11/2026) :
// v2 (décision de Léo du 19/11/2026) : accord conclu toute l'année, exécuté au changement de saison (« 1er juillet »),
// enchères des autres clubs seulement pendant la période des mutations, indemnité plafonnée aux salaires repris, joueur en
// fin de contrat ou engagé par un club géré refusé ; réglage « semaines » (mesure) : immédiates pendant la période des
// mutations (1er mai – 30 juin), sinon accord conclu et exécuté à l'ouverture ;
// pré-contrats des joueurs en fin de contrat (projection `preContract` de chaque candidat concerné).
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
 // execution : revérification d'un accord au changement de saison (phase de fin de saison acceptée, engagements ignorés).
 function quote(c,p,loanIds=new Set(loans().map(l=>l.id)),budget=typeof budgetTransfertsContexte==='function'?budgetTransfertsContexte():null,execution=false){
  const own=S.clubs[S.club],weeks=wageForecastWeeks(S),sourceSalary=p.salary,contractEnd=p.contractEnd;
  // v2 : indemnité plafonnée aux salaires que l'acheteur reprend (calendrier-mutations.cjs, calIndemnite).
  const brut=Math.max(20000,Math.ceil(sourceSalary*weeks*Math.max(1,contractEnd-S.season+1)/20000)*10000),fee=typeof calIndemnite==='function'?calIndemnite(p,brut):brut;
  // v2 : joueur engagé par un club géré, ou en fin de contrat (il partirait libre à son arrivée) : pré-contrat seulement.
  const v2=!execution&&typeof calBascule==='function'&&calBascule(),engage=v2?calIAReserve(p.id).replace(/\.$/,''):'';
  const salary=Math.max(1000,Math.ceil(sourceSalary*1.05/100)*100);
  let reason='';
  if(!execution&&(S.live||S.phase!=='league'))reason='Accords disponibles hors match en saison régulière';
  else if(engage)reason=engage;
  else if(v2&&contractEnd===S.season)reason='Son contrat s’achève cette saison : propose-lui un pré-contrat à partir du 1er janvier';
  else if(!integer(p.age,18,60)||!integer(contractEnd,S.season,9999))reason='Joueur majeur sous contrat requis';
  else if(loanIds.has(p.id))reason='Joueur concerné par un prêt';
  else if(saleBlocked(p))reason=saleBlocked(p);
  else if(c.players.length<=releasePolicy(S).minimum)reason='Le vendeur conserve au moins '+releasePolicy(S).minimum+' professionnels';
  else if((p.fam===0&&c.players.filter(q=>q.id!==p.id&&q.pos===p.pos).length<2)||c.players.filter(q=>q.id!==p.id&&q.fam===p.fam).length<2)reason='Le vendeur doit conserver deux joueurs de cette famille de poste';
  const releaseReason=reason;
  if(!reason&&professionalPlaces(own,S)<=0)reason='Effectif acheteur complet';
  else if(!reason&&typeof a2rRefusRecrue==='function'&&a2rRefusRecrue(salary))reason=a2rRefusRecrue(salary);
  else if(own.cash<fee+400000)reason='Réserve de trésorerie de 400 000 € requise après indemnité';
  else if(salary>100000)reason='La demande salariale dépasse le plafond de 100 000 € par semaine';
  else if(own.cash-fee-400000<salary*Math.min(8,Math.max(0,weeks-week())))reason='Trésorerie insuffisante pour provisionner les huit prochaines semaines du nouveau salaire';
  // Budget de transferts fixé par le conseil (budget-transferts.cjs) : l'indemnité entre dans l'enveloppe.
  else if(budget&&typeof budgetTransfertsRefus==='function'&&budgetTransfertsRefus(fee,budget))reason=budgetTransfertsRefus(fee,budget);
  // v2 : l'engagement ailleurs ou la fin de contrat est la seule raison utile (pas le budget ni la trésorerie).
  if(releaseReason&&(engage||v2&&contractEnd===S.season))reason=releaseReason;
  // Calendrier des mutations (calendrier-mutations.cjs) : accord déjà conclu pour ce joueur (achat différé).
  const pending=typeof calAccordAchat==='function'?calAccordAchat(p.id):null;
  if(pending)reason='Accord conclu : il rejoindra ton club le '+nativeVenteJoueurs.dateFr(pending.date)+'.';
  // Pré-contrat déjà signé avec le club joué : c'est la seule raison utile (pas « nouvelle recrue » ni les gardes du vendeur).
  const signe=typeof calPre==='function'?calPre(p.id):null;
  if(signe&&signe.etat==='signe'&&signe.sens==='arrivee'&&signe.clubId===S.club)reason='Pré-contrat signé : il rejoindra ton club le '+nativeVenteJoueurs.dateFr(signe.arrivee)+'.';
  // Pré-contrat (joueur en fin de contrat) : seulement pour les contrats qui s'achèvent cette saison.
  const pre=contractEnd===S.season&&typeof calPreContratDevis==='function'?calPreContratDevis(c,p,budget):null;
  return {id:p.id,name:p.name,clubId:c.id,club:c.name,pos:p.pos,family:p.fam,age:p.age,contractEnd,sourceSalary,fee,salary,available:!reason,reason,releaseReason,
   ...(pending?{pending:{date:pending.date,dateLabel:nativeVenteJoueurs.dateFr(pending.date),fee:pending.fee}}:{}),...(pre?{preContract:pre}:{})};
 }
 // Période des mutations (vente-joueurs.json, fenetres) : hors période, un accord est conclu et exécuté à l'ouverture.
 const mutations=()=>typeof calInterclub==='function'?calInterclub():{ouverte:true,reouverture:null,raison:'',note:''};
 // Accord différé ? v2 : toujours (changement de saison) ; avant : hors période des mutations (exécuté à l'ouverture).
 const differe=()=>{const b=typeof calFenetreAccords==='function'?calFenetreAccords():null;if(b)return b;const f=mutations();return !f.ouverte&&f.reouverture?f:null;};
 function project(){
  const available=typeof S!=='undefined'&&!!S?.economy&&!!S.clubs?.[S.club];
  const base={available,releasePolicy:available?releasePolicy(S):null,context:available?context():null,candidates:[],notice:'Accord de libération anticipée. Indemnité intégralement versée au club vendeur ; salaire proposé +5 % (minimum 1 000 €/semaine), échéance conservée. La profondeur de libération dépend de l’univers et reste affichée ; deux joueurs de la famille et deux piliers de chaque côté sont conservés. Réserve de 400 000 € et provision des huit prochaines semaines du nouveau salaire ; aucune inscription réglementaire automatique.'};
  if(!available)return base;
  base.notice+=' '+base.releasePolicy.notice;
  const f=mutations();
  base.window={open:f.ouverte,reopens:f.reouverture,reopensLabel:f.reouverture?nativeVenteJoueurs.dateFr(f.reouverture):'',reason:f.raison,note:f.note};
  const loanIds=new Set(loans().map(l=>l.id)),budget=typeof budgetTransfertsContexte==='function'?budgetTransfertsContexte():null;
  base.candidates=S.clubs.filter(c=>c.id!==S.club).flatMap(c=>c.players.map(p=>quote(c,p,loanIds,budget))).sort((a,b)=>a.clubId-b.clubId||a.contractEnd-b.contractEnd||a.name.localeCompare(b.name));
  return base;
 }
 // Quota de championnat (JIFF, EQP) : un club dont la moyenne est menacée enchérit davantage pour un joueur qui compte
 // (jiff.cjs) ; effet modéré : un cran de besoin de plus, donc +4 % d'indemnité et +2,5 % de salaire proposés.
 const quotaNeed=(c,p)=>typeof CDJiff!=='undefined'&&CDJiff&&typeof CDJiff.recruitBonus==='function'&&CDJiff.recruitBonus(S,c.id,p)>0?1:0;
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
  const a2r=typeof a2rRefusRecrue==='function'?a2rRefusRecrue(p.salary):'',horsBudget=typeof budgetTransfertsRefus==='function'?budgetTransfertsRefus(p.fee):null,offers=[],humanReady=!a2r&&!horsBudget&&sellerResponse.accepted&&playerResponse.accepted&&affordable(S.clubs[S.club],p.fee,p.salary);
  if(humanReady)offers.push({clubId:S.club,club:S.clubs[S.club].name,fee:p.fee,salary:p.salary,need:publicNeed(S.clubs[S.club],player),human:true});
  // Hors période des mutations, les autres clubs n'enchérissent pas (ils respectent le même calendrier) : seul l'accord
  // différé du manager est possible.
  const f=mutations(),d=differe();
  for(const c of f.ouverte?S.clubs:[]){
   if(c.id===S.club||c.id===seller.id)continue;
   const base=publicNeed(c,player);if(base<=0)continue;
   const need=base+quotaNeed(c,player);
   const fee=Math.ceil(q.fee*(1+Math.min(5,need)*.04)/1000)*1000,salary=Math.min(100000,Math.ceil(q.salary*(1+Math.min(5,need)*.025)/100)*100);
   if(salary<q.salary||!affordable(c,fee,salary,true))continue;
   offers.push({clubId:c.id,club:c.name,fee,salary,need,human:false});
  }
  offers.sort((a,b)=>b.salary-a.salary||b.fee-a.fee||b.need-a.need||a.clubId-b.clubId);
  return {playerId:player.id,sellerId:seller.id,context:now,seller:sellerResponse,player:playerResponse,humanReady,humanReason:humanReady?'Offre recevable.':a2r?a2r:horsBudget?horsBudget:q.salary>100000?'La demande du joueur dépasse le plafond salarial de 100 000 € ; aucun accord possible.':!affordable(S.clubs[S.club],p.fee,p.salary)?'Effectif ou provision financière insuffisants.':'Indemnité ou salaire refusé.',offers,winner:offers[0]||null,
   deferred:d?{date:d.reouverture,dateLabel:nativeVenteJoueurs.dateFr(d.reouverture),note:d.raison}:null,
   notice:d?.bascule?d.raison+(f.ouverte?' Les autres clubs enchérissent aussi pendant la période des mutations.':' Les autres clubs n’enchérissent qu’en période des mutations.')+' Aucune transaction avant confirmation.':f.ouverte?'Les offres sont examinées à la clôture selon le salaire, l’indemnité et les besoins du club. Aucune transaction avant confirmation.':f.raison+' Les autres clubs n’enchérissent qu’en période des mutations. Aucune transaction avant confirmation.'};
 }
 // Accord d'achat conclu hors période (vente-joueurs.cjs, liste des accords) : l'indemnité est engagée sur le budget de
 // transferts tout de suite, l'argent et l'arrivée attendent l'ouverture.
 function differer(seller,player,fee,salary,f){
  const a=venteNouvelAccord({sens:'achat',playerId:player.id,joueur:player.name,seller:seller.id,vendeur:seller.name,fee,salary,date:f.reouverture,saison:S.season});
  if(typeof budgetTransfertsDepenser==='function')budgetTransfertsDepenser(fee);
  const texte='Accord conclu avec '+seller.name+' : '+player.name+' rejoindra '+S.clubs[S.club].name+' le '+nativeVenteJoueurs.dateFr(a.date)+' pour '+money(fee)+'.';
  transferEvent(texte);if(f.bascule&&typeof calMercato==='function')calMercato('accord',texte,fee);
  return {interclubTransfer:{playerId:player.id,sellerId:seller.id,buyerId:S.club,fee,salary,contractEnd:player.contractEnd,humanWon:true,deferred:true,date:a.date,dateLabel:nativeVenteJoueurs.dateFr(a.date),competingClubs:1}};
 }
 // Exécution d'un accord d'achat à l'ouverture (appelée par vente-joueurs.cjs) : revérifié comme un accord immédiat,
 // sinon il tombe avec la raison (l'indemnité engagée revient au budget de transferts de la même saison).
 function executerAchat(a){
  const seller=S.clubs[a.seller],buyer=S.clubs[S.club],player=seller?.players.find(x=>x.id===a.playerId);
  let raison='';
  if(!player)raison='Le joueur ne fait plus partie de l’effectif de '+(seller?.name||a.vendeur)+'.';
  else{const q=quote(seller,player,new Set(loans().map(l=>l.id)),null,!!a.bascule);
   // Au changement de saison, les contrats qui s'achèvent libèrent leur place.
   const places=professionalPlaces(buyer,S)+(a.bascule?buyer.players.filter(x=>x.contractEnd!=null&&x.contractEnd<=S.season).length:0);
   if(q.releaseReason)raison=q.releaseReason+'.';
   else if(places<=0)raison='Ton effectif professionnel est complet.';
   else if(buyer.cash-a.fee<400000)raison='La réserve de trésorerie de 400 000 € ne serait plus respectée après l’indemnité.';}
  const st=S.venteJoueurs;st.seq++;
  const ev={id:'vente-'+st.seq,date:typeof venteJour==='function'?venteJour()||'':'',type:raison?'achat_annule':'achat_execute',raison,joueur:a.joueur,acheteur:a.vendeur,montant:a.fee,playerId:a.playerId,buyerId:a.seller};
  st.evenements.push(ev);st.evenements=st.evenements.slice(-20);
  if(raison){
   // Indemnité engagée rendue : à la saison de l'accord, ou à la saison qui commence si l'accord tombe à la bascule.
   const e=S.budgetTransferts;if(e&&e.saison===a.saison&&e.clubId===S.club){if(typeof budgetTransfertsBascule!=='undefined'&&budgetTransfertsBascule)budgetTransfertsRendre(e,a.fee);else e.depense=Math.max(0,Math.round(e.depense-a.fee));}
   transferEvent('L’accord avec '+(seller?.name||a.vendeur)+' pour '+a.joueur+' tombe : '+raison.replace(/\.$/,'')+'.');return false;
  }
  seller.players=seller.players.filter(x=>x.id!==player.id);buyer.players.push(player);seller.cash+=a.fee;
  ledgerEntry('Libération anticipée : '+player.name,-a.fee);
  player.salary=a.salary;player.joinedSeason=a.bascule?S.season+1:S.season;player.joinedRound=a.bascule?0:S.round;
  delete S.economy.listings[player.id];S.economy.offers=S.economy.offers.filter(o=>o.playerId!==player.id);
  S.market=S.market.filter(x=>x.id!==player.id);S.economy.freeAgents=S.economy.freeAgents.filter(x=>x.id!==player.id);
  if(typeof aiRosterEvent==='function')aiRosterEvent(seller.id,'sell',player,a.fee);
  transferEvent(player.name+' rejoint '+buyer.name+' depuis '+seller.name+' : accord de '+money(a.fee)+(a.bascule?' effectif au changement de saison.':' exécuté à l’ouverture des mutations.'));
  return true;
 }
 function auction(p){
  check(shape(p,['playerId','sellerId','fee','salary','sourceSalary','contractEnd','context','expectedWinner','expectedFee','expectedSalary','confirmed'])&&p.confirmed===true&&integer(p.expectedWinner,0,S.clubs.length-1)&&integer(p.expectedFee,10000,1000000000)&&integer(p.expectedSalary,1000,100000),'clôture invalide');
  const {expectedWinner,expectedFee,expectedSalary,confirmed,...offer}=p,result=negotiate(offer),win=result.winner;
  check(win&&win.clubId===expectedWinner&&win.fee===expectedFee&&win.salary===expectedSalary,'devis concurrent devenu périmé ; vérifie à nouveau');
  const seller=S.clubs[p.sellerId],buyer=S.clubs[win.clubId],player=seller.players.find(q=>q.id===p.playerId);
  check(!(typeof calAccordAchat==='function'&&calAccordAchat(player.id)),'accord déjà conclu pour ce joueur');
  const d=differe();
  if(d&&win.clubId===S.club)return differer(seller,player,win.fee,win.salary,d);
  // v2 : un club géré qui l'emporte conclut lui aussi un accord, exécuté au changement de saison.
  if(d&&d.bascule){calIANouvelAccord(buyer,seller,player,win.fee,win.salary,Math.max(1,player.contractEnd-S.season));return {interclubTransfer:{playerId:player.id,sellerId:seller.id,buyerId:buyer.id,fee:win.fee,salary:win.salary,contractEnd:player.contractEnd,competingClubs:result.offers.length,humanWon:false,deferred:true,date:d.reouverture,dateLabel:nativeVenteJoueurs.dateFr(d.reouverture)}};}
  seller.players=seller.players.filter(q=>q.id!==player.id);buyer.players.push(player);seller.cash+=win.fee;
  const avant=buyer.cash;
  if(buyer.id===S.club){ledgerEntry('Libération anticipée négociée : '+player.name,-win.fee);if(typeof budgetTransfertsDepenser==='function')budgetTransfertsDepenser(win.fee);}else buyer.cash-=win.fee;
  player.salary=win.salary;player.joinedSeason=S.season;player.joinedRound=S.round;
  delete S.economy.listings[player.id];S.economy.offers=S.economy.offers.filter(o=>o.playerId!==player.id);S.market=S.market.filter(x=>x.id!==player.id);S.economy.freeAgents=S.economy.freeAgents.filter(x=>x.id!==player.id);
  if(buyer.id===S.club&&typeof repriseApresAchat==='function'&&!(typeof budgetTransfertsExempte==='function'&&budgetTransfertsExempte()))repriseApresAchat(buyer,avant);
  transferEvent(player.name+' rejoint '+buyer.name+' après concurrence entre '+result.offers.length+' club(s), pour '+money(win.fee)+'.');
  return {interclubTransfer:{playerId:player.id,sellerId:seller.id,buyerId:buyer.id,fee:win.fee,salary:win.salary,contractEnd:player.contractEnd,competingClubs:result.offers.length,humanWon:buyer.id===S.club}};
 }
 function execute(command,p){
  if(command==='interclub_negotiate')return {interclubNegotiation:negotiate(p)};
  if(command==='interclub_auction')return auction(p);
  check(command==='interclub_transfer','commande inconnue');check(typeof S!=='undefined'&&S?.economy&&!S.live&&S.phase==='league','accord indisponible');
  check(shape(p,['playerId','sellerId','fee','salary','sourceSalary','contractEnd','context','confirmed'])&&typeof p.playerId==='string'&&p.playerId.length<=120&&integer(p.sellerId,0,S.clubs.length-1)&&p.sellerId!==S.club&&integer(p.fee,10000,1000000000)&&integer(p.salary,1000,100000)&&integer(p.sourceSalary,0,100000)&&integer(p.contractEnd,S.season,9999)&&p.confirmed===true,'proposition invalide ou non confirmée');
  const now=context();check(shape(p.context,['season','week','club'])&&Object.keys(now).every(k=>p.context[k]===now[k]),'contexte périmé');
  const seller=S.clubs[p.sellerId],buyer=S.clubs[S.club],player=seller.players.find(q=>q.id===p.playerId);
  check(player&&!buyer.players.some(q=>q.id===p.playerId),'joueur indisponible');
  const q=quote(seller,player);check(q.available,q.reason);check(player.salary===p.sourceSalary&&player.contractEnd===p.contractEnd,'contrat source modifié');
  check(p.fee>=q.fee,'le vendeur refuse cette indemnité');check(p.salary>=q.salary,'le joueur refuse ce salaire');
  check(buyer.cash-p.fee>=400000,'réserve financière insuffisante');
  const horsBudget=typeof budgetTransfertsRefus==='function'?budgetTransfertsRefus(p.fee):null;if(horsBudget)throw Error(horsBudget);check(buyer.cash-p.fee-400000>=p.salary*Math.min(8,Math.max(0,wageForecastWeeks(S)-week())),'provision salariale insuffisante');
  // Accord différé (calendrier-mutations.cjs) : v2 toujours (changement de saison), sinon hors période des mutations.
  const d=differe();if(d)return differer(seller,player,p.fee,p.salary,d);
  // All checks precede writes. The worker owns disk commit and rollback.
  seller.players=seller.players.filter(x=>x.id!==player.id);buyer.players.push(player);seller.cash+=p.fee;
  const avant=buyer.cash;ledgerEntry('Libération anticipée : '+player.name,-p.fee);if(typeof budgetTransfertsDepenser==='function')budgetTransfertsDepenser(p.fee);
  player.salary=p.salary;player.joinedSeason=S.season;player.joinedRound=S.round;
  delete S.economy.listings[player.id];S.economy.offers=S.economy.offers.filter(o=>o.playerId!==player.id);
  S.market=S.market.filter(x=>x.id!==player.id);S.economy.freeAgents=S.economy.freeAgents.filter(x=>x.id!==player.id);
  if(typeof repriseApresAchat==='function'&&!(typeof budgetTransfertsExempte==='function'&&budgetTransfertsExempte()))repriseApresAchat(buyer,avant);
  transferEvent(player.name+' rejoint '+buyer.name+' depuis '+seller.name+' : accord de '+money(p.fee)+', fin de contrat '+(typeof libelleSaison==='function'?libelleSaison:String)(player.contractEnd)+'.');
  return {interclubTransfer:{playerId:player.id,sellerId:seller.id,buyerId:buyer.id,fee:p.fee,salary:player.salary,contractEnd:player.contractEnd}};
 }
 // releasePolicy : même effectif minimum pour la vente de joueurs du club joué (vente-joueurs.cjs).
 // executerAchat : accords d'achat différés (calendrier-mutations.cjs), exécutés à l'ouverture par vente-joueurs.cjs.
 return {project,execute,validate:()=>true,installHooks:()=>true,releasePolicy,executerAchat};
}
module.exports={files:[],commands:['interclub_transfer','interclub_negotiate','interclub_auction'],factory};

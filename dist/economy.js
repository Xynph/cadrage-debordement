'use strict';
// Fictional transfer economy. Salaries are charged by the career's weekly ledger.
let marketTab='recruit';
function ensureContract(p){if(!Number.isInteger(p.contractEnd))p.contractEnd=S.season+(seedHash(p.id)%3);return p}
function setupEconomy(backup=false){if(!S)return;const fresh=!S.economy;if(fresh&&backup){try{if(!gameStorage.getItem('bdt-backup-economy'))gameStorage.setItem('bdt-backup-economy',JSON.stringify(S))}catch(e){}}
S.economy=S.economy||{version:1,week:S.round,talks:{},listings:{},offers:[],transfers:[],freeAgents:[],settled:0};S.clubs.forEach(c=>c.players.forEach(ensureContract));if(fresh&&backup)news('Mercato enrichi : contrats, négociations, prolongations et offres de transfert. Salaires et trésorerie conservés.')}
function economyLocked(){if(S.live){toast('Validez la rencontre avant de modifier les contrats ou l’effectif.');return true}return false}
function contractBase(){return S.season+(S.phase==='ended'?1:0)}
function contractYears(p){ensureContract(p);return Math.max(0,p.contractEnd-S.season+1)}
function contractLabel(p){ensureContract(p);return `Fin saison ${p.contractEnd}${p.contractEnd===S.season?' · À prolonger':''}`}
function totalWages(){return club().players.reduce((n,p)=>n+p.salary,0)}
function futureWages(){return club().players.reduce((n,p)=>n+p.salary*(Math.max(0,29-S.round)+Math.max(0,p.contractEnd-S.season)*29),0)}
function transferValue(p){ensureDevelopment(p);const ageFactor=p.age<25?1.2:p.age>31?.65:1;const term=p.contractEnd===S.season?.65:1;return Math.max(20000,Math.round((roleNote(p)-45)**2*330*ageFactor*term*(1+Math.min(.2,(p.dev.potential-p.rating)*.012))*(p.injury?.8:1)/10000)*10000)}
function saleBlocked(p){if((p.id.startsWith('academy-')||p.id.startsWith('youth-'))&&p.age<20)return 'Espoir : disponible à la vente à partir de 20 ans.';if(p.joinedSeason===S.season&&S.round-(p.joinedRound||0)<3)return 'Nouvelle recrue : attendez trois journées avant de la revendre.';return ''}
function talkKey(id,kind){return `${S.season}:${S.economy.week}:${kind}:${id}`}
function talkPlayer(id,kind){return kind==='renew'?player(id):S.market.find(p=>p.id===id)}
function askingWage(p,kind){return kind==='renew'?Math.max(p.salary,Math.round((roleNote(p)-43)*230/100)*100):p.salary}
function reservationWage(p,kind,years){const age=p.age>=31&&years===3?1.12:years===1?1.08:years===3?.96:1;return Math.ceil(askingWage(p,kind)*(.86+(seedHash(p.id)%8)/100)*age/100)*100}
function contractFee(p,kind){return kind==='renew'?Math.round(p.salary*2/1000)*1000:p.price}
function ledgerEntry(title,amount){club().cash+=amount;S.ledger.unshift({title,amount});S.ledger=S.ledger.slice(0,100)}
function transferEvent(text){S.economy.transfers.unshift({season:S.season,round:S.round,text});S.economy.transfers=S.economy.transfers.slice(0,80);news(text)}
function openContract(id,kind='recruit'){if(economyLocked())return;let p=talkPlayer(id,kind);if(!p)return;let key=talkKey(id,kind),t=S.economy.talks[key];const min=kind==='renew'?Math.max(1,p.contractEnd-contractBase()+2):1;if(min>Math.min(3,careerContractYears(p))){toast('Pas de nouveau contrat possible avant la retraite prévue, ou contrat déjà suffisamment long.');return}
const years=t?.years||Math.max(2,min),salary=t?.salary||askingWage(p,kind),fee=contractFee(p,kind);modal=`<div class="modalback"><section class="modal contractmodal" role="dialog" aria-modal="true" aria-label="Négociation de contrat"><div class="row" style="margin-top:0"><span class="tag">${kind==='renew'?'PROLONGATION':'RECRUTEMENT'}</span><button class="small" onclick="closeModal()">Fermer ×</button></div><h2>${p.name}</h2><p>${p.pos} · ${p.age} ans · ${kind==='renew'?'Note au poste '+roleNote(p):'Niveau estimé '+recruitmentEvidence(p).noteMin+'–'+recruitmentEvidence(p).noteMax+(recruitmentEvidence(p).seen?' (rapport daté)':' (non observé)')}</p><div class="row"><span>Salaire demandé / semaine</span><strong>${money(askingWage(p,kind))}</strong></div><div class="row"><span>Prime à la signature</span><strong>${money(fee)}</strong></div>${kind==='renew'?`<p class="help">Contrat actuel : ${contractLabel(p)} · ${money(p.salary)} / semaine. La nouvelle durée inclut ${contractBase()===S.season?'la saison en cours':'la prochaine saison'}.</p>`:`<p class="help">La durée inclut ${contractBase()===S.season?'la saison en cours':'la prochaine saison'}. Le contrat prend fin à l’issue de la dernière saison indiquée.</p>`}<p class="help">Retraite prévue : fin de saison ${retirementSeason(p)}. Le choix de durée tient compte de cette échéance.</p><div class="contractfields"><label>Salaire proposé / semaine (€)<input id="offer-wage" type="number" step="100" min="1000" max="100000" value="${salary}"></label><label>Durée du contrat<select id="offer-years">${[1,2,3].filter(y=>y>=min&&y<=careerContractYears(p)).map(y=>`<option value="${y}" ${years===y?'selected':''}>${y} saison${y>1?'s':''} · fin S${contractBase()+y-1}</option>`).join('')}</select></label></div><p class="help">Trois propositions maximum par journée. Une acceptation reste à confirmer avant toute dépense.</p>${t?`<div class="notice" role="status">${t.message}</div>`:''}<div class="contractactions">${!t||t.status!=='withdrawn'?`<button class="dark" onclick="submitContract('${id}','${kind}')">Proposer ces conditions</button>`:''}${t&&['ready','counter'].includes(t.status)?`<button class="primary" onclick="confirmContract('${key}')">${t.status==='counter'?'Accepter la contre-proposition':'Confirmer la signature'} · ${money(t.acceptedSalary)} / sem.</button>`:''}</div>${t&&['ready','counter'].includes(t.status)?`<p class="help">Accord proposé : ${t.years} saison(s), fin S${t.end}. Prime ${money(t.fee)} à payer maintenant. Salaires sur ${t.years} saison(s) complète(s) : ${money(t.acceptedSalary*29*t.years)} (29 journées payées par saison ; estimation, hors primes).</p>`:''}</section></div>`;render()}
function submitContract(id,kind){const wage=Number($('#offer-wage').value),years=Number($('#offer-years').value);negotiateContract(id,kind,wage,years);openContract(id,kind)}
function negotiateContract(id,kind,wage,years){if(economyLocked())return false;let p=talkPlayer(id,kind);if(!p||!['recruit','renew'].includes(kind)||!Number.isInteger(wage)||wage<1000||wage>100000||![1,2,3].includes(years)){toast('Vérifiez le salaire et la durée proposés.');return false}let end=contractBase()+years-1;if(years>careerContractYears(p)){toast('Cette durée dépasse la retraite prévue du joueur.');return false}if(kind==='renew'&&end<=p.contractEnd){toast('La prolongation doit allonger le contrat actuel.');return false}let key=talkKey(id,kind),prev=S.economy.talks[key];if(prev?.attempts>=3||prev?.status==='withdrawn'){toast('Le joueur ne négociera plus avant la prochaine journée.');return false}const attempts=(prev?.attempts||0)+1,minimum=reservationWage(p,kind,years);const accepted=wage>=minimum;const withdrawn=!accepted&&attempts===3;const acceptedSalary=accepted?wage:minimum;const status=accepted?'ready':withdrawn?'withdrawn':'counter';const message=accepted?`Accord de principe pour ${money(wage)} par semaine. Confirmez pour signer.`:withdrawn?'Les trois propositions ont échoué. Le joueur met fin aux échanges pour cette journée.':`Le joueur refuse et demande ${money(minimum)} par semaine sur ${years} saison(s). Proposition ${attempts}/3.`;
S.economy.talks[key]={id,kind,week:S.economy.week,attempts,years,salary:wage,acceptedSalary,status,message,end,fee:contractFee(p,kind)};save();return true}
function confirmContract(key){if(economyLocked())return false;const t=S.economy.talks[key];if(!t||!['ready','counter'].includes(t.status)||t.week!==S.economy.week)return false;const p=talkPlayer(t.id,t.kind);if(!p)return false;if(t.years>careerContractYears(p)){toast('Révisez la durée : elle dépasse la retraite prévue.');return false;}if(club().cash<t.fee){toast('Trésorerie insuffisante pour payer la prime.');return false}if(t.kind==='renew'&&t.end<=p.contractEnd)return false;if(t.kind==='recruit'&&club().players.some(x=>x.id===p.id))return false;ledgerEntry(`${t.kind==='renew'?'Prolongation':'Signature'} : ${p.name}`,-t.fee);p.salary=t.acceptedSalary;p.contractEnd=t.end;if(t.kind==='recruit'){p.joinedSeason=S.season;p.joinedRound=S.round;club().players.push(p);S.market=S.market.filter(x=>x.id!==p.id);S.economy.freeAgents=S.economy.freeAgents.filter(x=>x.id!==p.id)}t.status='signed';transferEvent(`${p.name} ${t.kind==='renew'?'prolonge':'rejoint le club'} jusqu’à la fin de la saison ${t.end}, à ${money(p.salary)} par semaine.`);delete S.economy.listings[p.id];S.economy.offers=S.economy.offers.filter(o=>o.playerId!==p.id);modal=null;save();render();toast('Contrat signé.');return true}
function toggleListing(id){if(economyLocked())return;let p=player(id);if(!p)return;let why=saleBlocked(p);if(why){toast(why);return}if(S.economy.listings[id]){delete S.economy.listings[id];S.economy.offers=S.economy.offers.filter(o=>o.playerId!==id);toast('Joueur retiré du marché.')}else{S.economy.listings[id]=true;toast('Joueur proposé aux autres clubs. Consultez les offres après la prochaine journée.')}save();render()}
function economyWeek(){setupEconomy();const e=S.economy;e.week++;e.offers=e.offers.filter(o=>o.expires>=e.week&&player(o.playerId));e.talks={};for(let id of Object.keys(e.listings)){const p=player(id);if(!p){delete e.listings[id];continue}if(saleBlocked(p)||e.offers.some(o=>o.playerId===id))continue;let fee=Math.round(transferValue(p)*(.78+(seedHash(id+e.week)%25)/100)/10000)*10000;const buyers=S.clubs.filter(c=>c.id!==S.club&&c.cash>=fee&&c.players.length<42).sort((a,b)=>{const aNeed=Math.max(0,...recruitmentNeeds(a).filter(n=>slotEligible(p,n.slot)).map(n=>n.score));const bNeed=Math.max(0,...recruitmentNeeds(b).filter(n=>slotEligible(p,n.slot)).map(n=>n.score));return bNeed-aNeed||Math.abs(a.base-p.rating)-Math.abs(b.base-p.rating)||a.id-b.id});if(!buyers.length)continue;const buyer=buyers[(seedHash(id+e.week)%Math.min(3,buyers.length))];e.offers.push({id:`offer-${e.week}-${id}`,playerId:id,buyer:buyer.id,fee,expires:e.week+1})}
const expiry=club().players.filter(p=>p.contractEnd===S.season);if(expiry.length&&[0,13,22,26].includes(S.round))news(`${expiry.length} contrat(s) expire(nt) à la fin de cette saison. Consultez l’onglet Contrats pour anticiper les départs.`)}
function openSale(offerId){if(economyLocked())return;let o=S.economy.offers.find(o=>o.id===offerId),p=o&&player(o.playerId);if(!p)return;modal=`<div class="modalback"><section class="modal" role="dialog" aria-modal="true" aria-label="Offre de transfert"><span class="tag">OFFRE DE TRANSFERT</span><h2 style="margin-top:12px">${p.name}</h2><p>${S.clubs[o.buyer].name} propose <strong>${money(o.fee)}</strong>. La vente est définitive et libère ${money(p.salary)} de salaire par semaine.</p><div class="notice">${[...S.lineup,...S.reserves].includes(p.id)?'Ce joueur figure sur votre feuille de match. Le staff cherchera un remplaçant dans votre effectif après la vente.':'Ce joueur ne figure pas sur votre feuille de match.'}</div><div class="row"><button onclick="closeModal()">Garder le joueur</button><button class="primary" onclick="acceptSale('${o.id}')">Accepter la vente</button></div></section></div>`;render()}
function acceptSale(id){if(economyLocked())return false;const e=S.economy,o=e.offers.find(o=>o.id===id),p=o&&player(o.playerId),buyer=o&&S.clubs[o.buyer];if(!p||o.expires<e.week||buyer.cash<o.fee||buyer.players.length>=42){toast('Cette offre n’est plus disponible ou le club acheteur n’a plus les moyens.');return false;}buyer.cash-=o.fee;club().players=club().players.filter(x=>x.id!==p.id);buyer.players.push(p);p.contractEnd=Math.max(p.contractEnd,S.season+1);ledgerEntry('Vente : '+p.name,o.fee);delete e.listings[p.id];e.offers=e.offers.filter(x=>x.playerId!==p.id);S.lineup=S.lineup.map(x=>x===p.id?null:x);S.reserves=S.reserves.map(x=>x===p.id?null:x);repairSheet();transferEvent(`${p.name} rejoint ${buyer.name} pour ${money(o.fee)}.`);modal=null;save();render();toast('Vente conclue. Vérifiez votre feuille à 23.');return true}
function declineSale(id){if(economyLocked())return;S.economy.offers=S.economy.offers.filter(o=>o.id!==id);save();render()}
function settleContracts(){const e=S.economy;if(e.settled===S.season)return;e.settled=S.season;const leaving=club().players.filter(p=>p.contractEnd<=S.season);for(let p of leaving){p.formerClub=club().name;p.price=Math.round(p.salary*2/1000)*1000;p.contractEnd=null;p.condition=100;p.injury=0;e.freeAgents.push(p);transferEvent(`${p.name} quitte le club libre, son contrat n’ayant pas été prolongé.`)}const ids=new Set(leaving.map(p=>p.id));club().players=club().players.filter(p=>!ids.has(p.id));S.lineup=S.lineup.map(id=>ids.has(id)?null:id);S.reserves=S.reserves.map(id=>ids.has(id)?null:id);for(let c of S.clubs){if(c.id===S.club)continue;for(let p of c.players)if(p.contractEnd<=S.season)p.contractEnd=S.season+2}e.offers=[];e.listings={};e.talks={};for(let p of e.freeAgents){p.condition=100;p.injury=0}e.freeAgents=e.freeAgents.slice(-60)}
function marketSwitch(tab){if(!['recruit','contracts','sales','history'].includes(tab))return;marketTab=tab;render()}
function transferMarket(){setupEconomy();return heading('BÂTIR POUR DEMAIN','Le bureau du recrutement.','Recrutez les bons profils, anticipez les fins de contrat et gardez la maîtrise des salaires.')+`<div class="stats"><div class="card stat"><span class="eyebrow">TRÉSORERIE</span><b>${(club().cash/1e6).toFixed(2).replace('.',',')} <small>M€</small></b></div><div class="card stat"><span class="eyebrow">SALAIRES / JOURNÉE</span><b>${Math.round(totalWages()/1000)} <small>k€</small></b></div><div class="card stat"><span class="eyebrow">FIN DE CONTRAT</span><b>${club().players.filter(p=>p.contractEnd===S.season).length} <small>joueurs</small></b></div><div class="card stat"><span class="eyebrow">OFFRES REÇUES</span><b>${S.economy.offers.length}</b></div></div><div class="tabs markettabs">${[['recruit','Recruter'],['contracts','Contrats'],['sales','Ventes'],['history','Mouvements']].map(([k,t])=>`<button class="${marketTab===k?'dark':''}" onclick="marketSwitch('${k}')">${t}</button>`).join('')}</div>${({recruit:recruitmentPanel,contracts:contractsPanel,sales:salesPanel,history:movementsPanel})[marketTab]()}`}
function recruitmentPanel(){return `${recruitmentNeedsPanel()}<div class="notice" style="margin:0 0 20px">Agents libres fictifs. La prime est payée à la signature ; les salaires sont débités à chaque journée. Les négociations sont renouvelées après la prochaine journée.</div><div class="marketgrid">${S.market.map(p=>`<div class="card marketplayer"><div class="row" style="margin:0"><span class="tag">${p.pos}</span><span class="rating">${recruitmentEvidence(p).noteMin}–${recruitmentEvidence(p).noteMax} (estimé)</span></div><h3>${p.name}</h3><span class="muted">${p.age} ans · ${p.formerClub?'Ancien club : '+p.formerClub:'Agent libre'}</span><div class="row"><span class="muted">Potentiel au poste</span><strong>${recruitmentEvidence(p).seen?recruitmentEvidence(p).potentialMin+'–'+recruitmentEvidence(p).potentialMax:'À observer'}</strong></div>${recruitmentEvidence(p).seen?skillChips(p):'<p class="help">Qualités non observées ; une mission est nécessaire.</p>'}<button class="textbutton" style="margin-top:12px" onclick="inspectPlayer('${p.id}')">${recruitmentEvidence(p).seen?'Voir les attributs ↗':'Évaluation préliminaire ↗'}</button><div class="row"><span class="muted">Prime de signature</span><strong>${money(p.price)}</strong></div><div class="row"><span class="muted">Salaire demandé / semaine</span><strong>${money(p.salary)}</strong></div><button class="dark" style="width:100%" onclick="openContract('${p.id}')" ${club().cash<p.price?'disabled':''}>Négocier le contrat →</button></div>`).join('')}</div>`}
function contractsPanel(){return `<div class="card"><div class="cardtitle"><h2>Les engagements du club</h2><span class="tag">${club().players.length} CONTRATS</span></div><p class="help">Un contrat expire après les phases finales de sa dernière saison. Une prolongation remplace le salaire immédiatement. Les contrats longs pourront être prolongés quand leur échéance approchera.</p><div class="tablewrap"><table><thead><tr><th>JOUEUR</th><th>POSTE</th><th>SALAIRE / SEMAINE</th><th>ÉCHÉANCE</th><th>ACTION</th></tr></thead><tbody>${[...club().players].sort((a,b)=>a.contractEnd-b.contractEnd||b.salary-a.salary).map(p=>`<tr><td><button class="textbutton" onclick="inspectPlayer('${p.id}')">${p.name}</button></td><td>${p.pos}</td><td>${money(p.salary)}</td><td><span class="${p.contractEnd===S.season?'danger':''}">${contractLabel(p)}</span></td><td><button class="small" onclick="openContract('${p.id}','renew')" ${p.contractEnd>=contractBase()+2?'disabled':''}>Prolonger</button></td></tr>`).join('')}</tbody></table></div><div class="notice">Salaires restant à verser : environ ${money(futureWages())}. Estimation sur 29 journées payées par saison, hors primes de prolongation et futurs recrutements.</div></div>`}
function salesPanel(){const e=S.economy;return `<div class="stack"><div class="card"><h2>Les offres sur votre bureau</h2>${e.offers.map(o=>{let p=player(o.playerId);if(!p)return '';return `<div class="transferoffer"><div><strong>${p.name}</strong><p>${S.clubs[o.buyer].name} · ${money(o.fee)} · valable jusqu’à la prochaine journée incluse</p></div><div class="matchactions"><button class="small" onclick="declineSale('${o.id}')">Refuser</button><button class="primary small" onclick="openSale('${o.id}')">Examiner l’offre</button></div></div>`}).join('')||'<p>Placez un joueur sur le marché. Les premières offres pourront arriver après la prochaine journée, selon les moyens des autres clubs.</p>'}</div><div class="card"><h2>Les joueurs à céder</h2><div class="tablewrap"><table><thead><tr><th>JOUEUR</th><th>POSTE</th><th>SALAIRE / SEMAINE</th><th>VALEUR ESTIMÉE</th><th>STATUT</th></tr></thead><tbody>${club().players.map(p=>`<tr><td>${p.name}</td><td>${p.pos}</td><td>${money(p.salary)}</td><td>${money(transferValue(p))}</td><td>${saleBlocked(p)?`<small class="muted">${saleBlocked(p)}</small>`:`<button class="small ${e.listings[p.id]?'dark':''}" onclick="toggleListing('${p.id}')">${e.listings[p.id]?'Retirer du marché':'Proposer à la vente'}</button>`}</td></tr>`).join('')}</tbody></table></div></div></div>`}
function movementsPanel(){return `<div class="card"><h2>Le journal du mercato</h2>${S.economy.transfers.map(t=>`<div class="news"><small>SAISON ${t.season} · ${t.round<26?'J'+(t.round+1):'FIN DE SAISON'}</small>${t.text}</div>`).join('')||'<p>Vos signatures, prolongations, ventes et départs apparaîtront ici.</p>'}</div>`}
function careerContractYears(p){ensureDevelopment(p);return Math.max(0,p.dev.retireAge-p.age-(S.phase==='ended'?1:0))}



// V31 — Projection pure des mêmes flux fictifs que financeWeek() et advanceSeason().
// Pas de save(), rand(), ledgerEntry(), mutation de S ou de ses joueurs.
const FORECAST_PARTNERS=160000,FORECAST_HOME_LOW=300000,FORECAST_HOME_HIGH=450000;
const FORECAST_WIN_BONUS=80000,FORECAST_SEASON_FUNDING=2500000;
let forecastChoice={recruit:'',renew:'',sale:'',years:2,horizon:3};
function forecastContractBase(s){return s.season+(s.phase==='ended'?1:0)}
function forecastFirstWeek(s){return s.phase==='league'?s.round:s.phase==='barrage'?26:s.phase==='semi'?27:s.phase==='final'?28:29}
function forecastQuote(s,request){
 const kind=request?.kind||'baseline',years=request?.years??2;
 const current=s.clubs[s.club],base=forecastContractBase(s);
 if(kind==='baseline')return {kind,valid:true,fee:0,players:current.players.map(p=>({id:p.id,salary:p.salary,contractEnd:p.contractEnd})),notes:['Aucune opération']};
 if(!['recruit','renew','sale'].includes(kind))return {kind,valid:false,error:'Opération inconnue.'};
 const p=kind==='recruit'?s.market.find(q=>q.id===request.id):current.players.find(q=>q.id===request.id);
 if(!p)return {kind,valid:false,error:'Joueur indisponible pour ce scénario.'};
 if(!Number.isInteger(years)||years<1||years>3)return {kind,valid:false,error:'Durée de contrat invalide (1 à 3 saisons).'};
 const players=current.players.map(q=>({id:q.id,salary:q.salary,contractEnd:q.contractEnd}));
 let fee=0,notes=[],executable=true;
 if(kind==='recruit'){
  const maxYears=(p.dev?.retireAge??50)-p.age-(s.phase==='ended'?1:0);
  if(years>maxYears||current.players.some(q=>q.id===p.id)||current.players.length>=42)return {kind,valid:false,error:'Durée, retraite ou effectif incompatible avec la signature.'};
  fee=p.price;const wage=Math.max(askingWage(p,'recruit'),reservationWage(p,'recruit',years));
  players.push({id:p.id,salary:wage,contractEnd:base+years-1});
  notes.push('Salaire retenu : maximum du salaire demandé et de la réserve de négociation, sans accord garanti.');
 }else if(kind==='renew'){
  const item=players.find(q=>q.id===p.id),min=Math.max(1,p.contractEnd-base+2),maxYears=(p.dev?.retireAge??50)-p.age-(s.phase==='ended'?1:0);
  if(years<min||years>maxYears)return {kind,valid:false,error:'La prolongation doit allonger le contrat sans dépasser la retraite.'};
  fee=contractFee(p,'renew');
  item.salary=Math.max(askingWage(p,'renew'),reservationWage(p,'renew',years));item.contractEnd=base+years-1;
  notes.push('Nouveau salaire effectif immédiatement ; prime de prolongation existante.');
 }else{
  const offer=s.economy?.offers?.find(o=>o.playerId===p.id&&o.expires>=s.economy.week&&s.clubs[o.buyer]?.cash>=o.fee&&s.clubs[o.buyer]?.players.length<42);
  const quote=offer?offer.fee:transferValue(JSON.parse(JSON.stringify(p)));
  fee=-quote;const index=players.findIndex(q=>q.id===p.id);players.splice(index,1);
  executable=!!offer&&!saleBlocked(p);
  notes.push(offer?'Montant d’une offre existante, encore soumis à validation.':'Valeur de transfert estimée ; aucune offre ferme : vente non réalisable immédiatement.');
  if(saleBlocked(p))notes.push('Vente actuellement bloquée par les règles du mercato.');
 }
 if(kind!=='sale'&&s.clubs[s.club].cash<fee){executable=false;notes.push('Trésorerie insuffisante pour payer la prime immédiate.');}
 return {kind,valid:true,fee,players,notes,executable,player:p.name,years};
}
function forecastFinancialScenario(s,request={kind:'baseline'},horizon=3){
 if(!s||!Number.isInteger(horizon)||horizon<1||horizon>3)return {valid:false,error:'Horizon invalide.'};
 const quote=forecastQuote(s,request);
 if(!quote.valid)return {...quote,horizon};
 const startCash=s.clubs[s.club].cash,players=quote.players.map(p=>({...p}));
 const cash={low:startCash-quote.fee,central:startCash-quote.fee,high:startCash-quote.fee};
 const minima={...cash},points=[{label:'Après opération',season:s.season,week:forecastFirstWeek(s),...cash}];
 const annual=[],cal=s.schedule,seasonal=typeof schedule==='function'?schedule():cal;
 for(let offset=0;offset<horizon;offset++){
  const year=s.season+offset,from=offset===0?forecastFirstWeek(s):0;
  if(offset>0){for(const key of ['low','central','high'])cash[key]+=FORECAST_SEASON_FUNDING;}
  let grossPayroll=0,homes=0,matchDays=0;
  for(let week=from;week<29;week++){
   const active=players.filter(p=>p.contractEnd===null||p.contractEnd===undefined||p.contractEnd>=year);
   const wage=active.reduce((sum,p)=>sum+p.salary,0);grossPayroll+=wage;
   const pairs=week<26?(offset===0?cal[week]:seasonal[week]):null;
   const home=!!pairs?.some(pair=>pair[0]===s.club),match=!!pairs?.some(pair=>pair.includes(s.club));
   if(home)homes++;
   if(match)matchDays++;
   cash.low+=FORECAST_PARTNERS-wage+(home?FORECAST_HOME_LOW:0);
   cash.central+=FORECAST_PARTNERS-wage+(home?(FORECAST_HOME_LOW+FORECAST_HOME_HIGH)/2:0)+(match?FORECAST_WIN_BONUS/2:0);
   cash.high+=FORECAST_PARTNERS-wage+(home?FORECAST_HOME_HIGH:0)+(match?FORECAST_WIN_BONUS:0);
   for(const key of ['low','central','high'])minima[key]=Math.min(minima[key],cash[key]);
  }
  annual.push({season:year,payments:29-from,homes,matchDays,payroll:grossPayroll,partners:(29-from)*FORECAST_PARTNERS,low:cash.low,central:cash.central,high:cash.high});
  points.push({label:'Fin S'+year,season:year,week:29,...cash});
  for(let i=players.length-1;i>=0;i--)if(players[i].contractEnd!=null&&players[i].contractEnd<=year)players.splice(i,1);
 }
 const risk=quote.executable===false?'Non exécutable à ce jour':minima.low<0?'Trésorerie négative en scénario prudent':minima.central<0?'Trésorerie fragile en scénario médian':'Aucun déficit projeté dans ces hypothèses';
 return {valid:true,kind:quote.kind,player:quote.player,fee:quote.fee,notes:quote.notes,executable:quote.executable!==false,horizon,points,annual,minima,risk};
}
function setForecastChoice(field,value){
 if(!S||!['recruit','renew','sale','years','horizon'].includes(field))return false;
 if(field==='years'||field==='horizon'){value=Number(value);if(!Number.isInteger(value)||value<1||value>3)return false;}
 else if(typeof value!=='string'||value.length>150)return false;
 forecastChoice[field]=value;render();return true;
}
function financeForecastOptionList(kind){
 const choices=kind==='recruit'?S.market:club().players;
 const selected=forecastChoice[kind],found=choices.find(p=>p.id===selected)||choices[0];
 if(!found)return {id:'',html:'<option value="">Aucun joueur disponible</option>'};
 return {id:found.id,html:choices.map(p=>'<option value="'+p.id+'"'+(p.id===found.id?' selected':'')+'>'+visualEscape(p.name)+' · '+p.pos+(kind==='recruit'?' · '+money(p.price):'')+'</option>').join('')};
}
function financialForecastPanel(){
 const selection={};for(const kind of ['recruit','renew','sale'])selection[kind]=financeForecastOptionList(kind);
 const horizon=forecastChoice.horizon,years=forecastChoice.years;
 const scenarios=[
  {label:'Sans opération',value:forecastFinancialScenario(S,{kind:'baseline'},horizon)},
  {label:'Recrutement',value:forecastFinancialScenario(S,{kind:'recruit',id:selection.recruit.id,years},horizon)},
  {label:'Prolongation',value:forecastFinancialScenario(S,{kind:'renew',id:selection.renew.id,years},horizon)},
  {label:'Vente',value:forecastFinancialScenario(S,{kind:'sale',id:selection.sale.id,years},horizon)}
 ];
 const baseline=scenarios[0].value;
 const controls='<div class="forecast-controls">'+
  [['recruit','Recruter'],['renew','Prolonger'],['sale','Vendre']].map(([kind,label])=>'<label>'+label+'<select aria-label="Scénario '+label+'" onchange="setForecastChoice(\''+kind+'\',this.value)">'+selection[kind].html+'</select></label>').join('')+
  '<label>Contrat envisagé<select aria-label="Durée simulée" onchange="setForecastChoice(\'years\',this.value)">'+[1,2,3].map(n=>'<option value="'+n+'"'+(n===years?' selected':'')+'>'+n+' saison'+(n>1?'s':'')+'</option>').join('')+'</select></label>'+
  '<label>Horizon<select aria-label="Horizon financier" onchange="setForecastChoice(\'horizon\',this.value)">'+[1,2,3].map(n=>'<option value="'+n+'"'+(n===horizon?' selected':'')+'>'+n+' saison'+(n>1?'s':'')+'</option>').join('')+'</select></label></div>';
 const row=(name,fn)=>'<tr><th>'+name+'</th>'+scenarios.map(x=>'<td>'+(!x.value.valid?'<span class="danger">Non calculable</span>':fn(x.value,baseline))+'</td>').join('')+'</tr>';
 const points=horizon;
 const cols='<thead><tr><th>Échéance</th>'+scenarios.map(s=>'<th>'+s.label+'</th>').join('')+'</tr></thead>';
 const body=[
  row('Effet immédiat',r=>money(-r.fee)),
  ...Array.from({length:points},(_,i)=>row('Fin saison '+(S.season+i),r=>money(r.points[i+1].central))),
  row('Écart final au statu quo',(r,b)=>{const end=r.points.at(-1),ref=b.points.at(-1);return (end.central>=ref.central?'+':'')+money(end.central-ref.central);}),
  row('Fourchette finale',r=>money(r.points.at(-1).low)+' à '+money(r.points.at(-1).high)),
  row('Point bas prudent',r=>money(r.minima.low)),
  row('Risque',r=>r.risk)
 ].join('');
 const details=scenarios.slice(1).map(s=>'<p class="help"><strong>'+s.label+' :</strong> '+(s.value.valid?(s.value.executable?'Hypothèse simulable, sans engagement. ':'Hypothèse non exécutable actuellement. ')+s.value.notes.join(' '):s.value.error)+'</p>').join('');
 const first=baseline.annual[0],explain='Hypothèses du moteur : partenaires 160 000 € et salaires à chaque journée ; 300 000 à 450 000 € par match à domicile déjà programmé ; prime 0/40 000/80 000 € par match pour les bornes prudent/médian/haut. '+FORECAST_SEASON_FUNDING.toLocaleString('fr-FR')+' € versés au début des saisons suivantes. Les 26 matchs de championnat sont déterminés par le calendrier de la carrière. Les trois journées finales sont payées, mais ni match ni billetterie ni prime de titre ne sont garantis. Aucun nouveau transfert, blessure, retraite, coût de scouting, prolongation automatique ou recette non codée n’est supposé.';
 return '<section class="card finance-forecast"><div class="cardtitle"><h2>Prévoir sans engager le club</h2><span class="tag">SIMULATION V31</span></div><p class="help">Quatre plans comparés sur les mêmes journées et hypothèses. Les montants sont une trésorerie de jeu, pas un budget réel. Modifier les choix ne change ni les contrats, ni les sauvegardes, ni le match.</p>'+controls+'<div class="tablewrap"><table class="forecast-table">'+cols+'<tbody>'+body+'</tbody></table></div>'+details+'<details><summary>Hypothèses, limites et calendrier</summary><p class="help">'+explain+'</p><p class="help">Dès cette saison : '+first.payments+' journée(s) de flux, '+first.homes+' match(s) à domicile de championnat restant(s), '+first.matchDays+' match(s) de championnat programmé(s). Les contrats expirés ne sont plus payés la saison suivante ; les joueurs encore présents après leur retraite éventuelle ne sont pas prédits.</p></details></section>';
}

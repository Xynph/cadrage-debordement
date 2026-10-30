'use strict';
// Fictional transfer economy. Salaries are charged by the career's weekly ledger.
let marketTab='recruit';
// V36 : promesses observables, indépendantes du calcul des matchs.
const PROMISE_MINUTES={rotation:80,regulier:160,titulaire:200};
function satisfactionActive(){return S?.satisfactionVersion===1}
function ensureSatisfaction(p){
 if(!satisfactionActive())return null;
 if(!p.satisfaction)p.satisfaction={version:1,score:65,season:S.season,baseline:p.dev?.minutes||0,promise:null,history:[]};
 return p.satisfaction;
}
function activateSatisfaction(){
 if(!S||satisfactionActive()||S.live||Object.keys(S.economy.talks).length)return false;
 S.satisfactionVersion=1;club().players.forEach(ensureSatisfaction);save();render();return true;
}
function makePlayingPromise(id,target){
 if(!satisfactionActive()||S.live||S.phase!=='league'||S.round>23||Object.keys(S.economy.talks).length||!Object.prototype.hasOwnProperty.call(PROMISE_MINUTES,target))return false;
 const p=player(id);if(!p||p.injury)return false;
 const st=ensureSatisfaction(p);if(st.promise)return false;
 st.promise={target,season:S.season,round:S.round,completed:0,minutes:0};
 st.history.push({season:S.season,round:S.round,status:'promise',minutes:0,target});
 st.history=st.history.slice(-8);save();render();return true;
}
function recordSatisfactionRound(l){
 if(!satisfactionActive()||!l?.finished||l.pair[l.userSide]!==S.club)return false;
 for(const p of club().players){
  const st=ensureSatisfaction(p),current=p.dev?.minutes||0;
  if(st.season!==S.season){st.season=S.season;st.baseline=0;st.promise=null;}
  const played=Math.max(0,current-st.baseline);st.baseline=current;
  const promise=st.promise;
  if(!promise||promise.season!==S.season||promise.round>S.round)continue;
  // Une blessure sans minute jouée suspend la promesse.
  if(p.injury&&played===0)continue;
  promise.completed++;promise.minutes+=played;
  if(promise.completed===3){
   const met=promise.minutes>=PROMISE_MINUTES[promise.target];
   st.score=clamp(st.score+(met?8:-10),20,95);
   st.history.push({season:S.season,round:S.round,status:met?'kept':'broken',minutes:promise.minutes,target:promise.target});
   st.history=st.history.slice(-8);st.promise=null;
  }
 }
 return true;
}
function resetSatisfactionSeason(){
 if(!satisfactionActive())return;
 for(const p of club().players){
  const st=ensureSatisfaction(p);st.season=S.season;st.baseline=0;st.promise=null;
 }
}
function satisfactionWageRate(p,kind){
 if(kind!=='renew'||!satisfactionActive()||!p.satisfaction)return 0;
 return p.satisfaction.score<40?.02:p.satisfaction.score>=80?-.01:0;
}
function satisfactionPanel(){
 if(!satisfactionActive())return '<section class="card"><h2>Satisfaction V36</h2><p class="help">Carrière historique : contrat inchangé. Activation volontaire, hors match et négociations.</p><button class="small dark" onclick="activateSatisfaction()">Activer le suivi de satisfaction</button></section>';
 const rows=club().players.slice().sort((a,b)=>(a.satisfaction?.score??65)-(b.satisfaction?.score??65)||a.name.localeCompare(b.name,'fr'));
 const can=S.phase==='league'&&!S.live&&S.round<=23&&!Object.keys(S.economy.talks).length;
 return '<section class="card"><h2>Satisfaction et promesses V36</h2><p class="help">Promesse explicite de 80, 160 ou 200 minutes sur 3 rencontres réellement disputées : respect +8, non-respect −10, bornes 20–95. Blessure sans minute : rencontre non comptée. Seuil de renouvellement : +2 % si score inférieur à 40 ; −1 % dès 80. Aucun effet sur le moteur rugby.</p><div class="tablewrap"><table><thead><tr><th>JOUEUR</th><th>ÉTAT</th><th>ENGAGEMENT / HISTORIQUE</th><th>ACTION</th></tr></thead><tbody>'+rows.map(p=>{
 const st=p.satisfaction,pr=st.promise;
 const label=st.score>=80?'Satisfait':st.score>=55?'Stable':st.score>=40?'Préoccupé':'Mécontent';
 const last=st.history.slice(-2).map(h=>'<small>'+visualEscape('S'+h.season+' J'+(h.round+1)+' · '+h.status+' · '+h.minutes+' min')+'</small>').join(' · ');
 const summary=pr?pr.minutes+'/'+PROMISE_MINUTES[pr.target]+' minutes, '+pr.completed+'/3 matchs':'Aucune promesse';
 const options=Object.entries(PROMISE_MINUTES).map(([k,n])=>'<option value="'+k+'">'+n+' min / 3 matchs</option>').join('');
 const action=can&&!pr&&!p.injury?'<select id="promise-'+p.id+'">'+options+'</select><button class="small" onclick="makePlayingPromise(\''+p.id+'\',document.querySelector(\'#promise-'+p.id+'\').value)">Promettre</button>':'—';
 return '<tr><td>'+visualEscape(p.name)+'</td><td>'+st.score+'/100 · '+label+'</td><td>'+summary+'<div>'+last+'</div></td><td>'+action+'</td></tr>';
 }).join('')+'</tbody></table></div></section>';
}


// V37 — journal explicite des décisions, rendez-vous et alertes.
// Aucun bonus caché sur le moteur rugby ou la réponse contractuelle.
function relationsActive(){return S?.relationsVersion===1&&S?.satisfactionVersion===1}
function activateRelations(){
 if(!S||relationsActive()||!satisfactionActive()||S.live||Object.keys(S.economy?.talks||{}).length)return false;
 S.relationsVersion=1;
 if(!Array.isArray(S.economy.relationLog))S.economy.relationLog=[];
 if(!Array.isArray(S.economy.moodLog))S.economy.moodLog=[];
 save();render();return true;
}
function relationEntry(item){
 if(!relationsActive())return;
 if(!Array.isArray(S.economy.relationLog))S.economy.relationLog=[];
 S.economy.relationLog.unshift({season:S.season,round:S.round,...item});
 S.economy.relationLog=S.economy.relationLog.slice(0,60);
}
function logContractProposal(p,kind,wage,minimum,years,status,attempt){
 relationEntry({playerId:p.id,kind:'offer',detail:kind,status,amount:wage,minimum,years,attempt});
}
function logContractSignature(p,t){
 relationEntry({playerId:p.id,kind:'signed',detail:t.kind,status:'signed',amount:t.acceptedSalary,minimum:t.acceptedSalary,years:t.years,attempt:t.attempts});
}
function recordClubMorale(previous,scoreDiff){
 if(!relationsActive())return;
 if(!Array.isArray(S.economy.moodLog))S.economy.moodLog=[];
 S.economy.moodLog.unshift({season:S.season,round:S.round,before:previous,after:S.morale,
  cause:scoreDiff>0?'victory':scoreDiff<0?'loss':'draw'});
 S.economy.moodLog=S.economy.moodLog.slice(0,20);
}
function coachConversation(id,choice){
 if(!relationsActive()||S.live||Object.keys(S.economy?.talks||{}).length||!['ecouter','rassurer','clarifier'].includes(choice))return false;
 const p=player(id);if(!p||!p.satisfaction)return false;
 const st=p.satisfaction,week=S.economy.week;
 if(st.coachMeeting?.season===S.season&&st.coachMeeting?.week===week)return false;
 const before=st.score;
 // Interaction transparente : écouter +2, rassurer +1, clarifier +0.
 const bonus=choice==='ecouter'?2:choice==='rassurer'?1:0;
 st.score=clamp(before+bonus,20,95);
 st.coachMeeting={season:S.season,week,choice};
 relationEntry({playerId:p.id,kind:'coach',detail:choice,status:'done',amount:before,
  minimum:st.score,years:0,attempt:1});
 save();render();return true;
}
function promiseReminders(){
 if(!relationsActive())return [];
 return club().players.filter(p=>p.satisfaction?.promise).map(p=>{
  const promise=p.satisfaction.promise,target=PROMISE_MINUTES[promise.target];
  return {id:p.id,name:p.name,played:promise.completed,minutes:promise.minutes,
   target,remaining:target-promise.minutes,urgent:promise.completed>=2,
   injured:!!p.injury};
 }).sort((a,b)=>Number(b.urgent)-Number(a.urgent)||a.name.localeCompare(b.name,'fr'));
}
function tensionsDashboard(){
 if(!relationsActive())return '<section class="card"><h2>Relations V37</h2><p class="help">Ancienne carrière : les relations restent inchangées. Activation volontaire, hors match et discussions en cours.</p><button class="small dark" onclick="activateRelations()">Activer les relations V37</button></section>';
 const unhappy=club().players.filter(p=>p.satisfaction&&p.satisfaction.score<55)
  .sort((a,b)=>a.satisfaction.score-b.satisfaction.score||a.name.localeCompare(b.name,'fr'));
 const pending=promiseReminders();
 const last=S.economy.moodLog?.[0],change=last?last.after-last.before:0;
 const mood=last?'Dernière évolution : '+(change>=0?'+':'')+change+
  ' (S'+last.season+' J'+(last.round+1)+' · '+({victory:'victoire',loss:'défaite',draw:'nul'})[last.cause]+')':'Aucun résultat depuis activation V37';
 return '<section class="card"><h2>Tableau de bord des tensions · V37</h2><p class="help">Moral collectif : '+S.morale+'/100. '+mood+
  '. Le moral du club suit les résultats déjà prévus par le moteur ; V37 ne modifie pas son calcul. La satisfaction individuelle évolue uniquement lors des promesses V36 ou des entretiens explicites ci-dessous.</p>'+
  '<p><b>'+unhappy.length+'</b> joueur(s) préoccupé(s) ou mécontent(s) · <b>'+pending.length+'</b> promesse(s) en cours.</p>'+
  '<h3>Rappels des engagements</h3>'+(pending.map(a=>'<p class="notice">'+visualEscape(a.name)+' : '+a.minutes+
  '/'+a.target+' min sur '+a.played+'/3 rencontres'+(a.urgent?' · DERNIÈRE RENCONTRE':'')+
  (a.injured?' · Blessure : absence sans minutes neutralisée':'')+'</p>').join('')||'<p>Aucun engagement en cours.</p>')+
  '<h3>Joueurs à écouter</h3>'+(unhappy.slice(0,8).map(p=>'<p>'+visualEscape(p.name)+
  ' · satisfaction '+p.satisfaction.score+'/100</p>').join('')||'<p>Aucune tension identifiée sous 55/100.</p>')+
  '<p class="help">Rappels informatifs : aucune sélection automatique, aucune pénalité pour absence de consultation.</p></section>';
}
function coachPanel(){
 if(!relationsActive())return '';
 const disabled=!!S.live||Object.keys(S.economy.talks).length>0;
 const rows=club().players.slice().sort((a,b)=>(a.satisfaction?.score??65)-(b.satisfaction?.score??65)||a.name.localeCompare(b.name,'fr')).slice(0,10);
 return '<section class="card"><h2>Dialogues joueur–entraîneur · V37</h2><p class="help">Un échange maximum par joueur et journée : écouter +2 satisfaction, rassurer +1, clarifier +0. Aucun effet sur la physique du match ou les finances. Déjà à 95 : aucun bonus supplémentaire.</p>'+
 rows.map(p=>{const last=p.satisfaction?.coachMeeting,blocked=disabled||
  last?.season===S.season&&last?.week===S.economy.week;
  return '<div class="row"><span>'+visualEscape(p.name)+' · '+p.satisfaction.score+'/100</span>'+
  (blocked?'<small>Entretien indisponible cette journée</small>':
   '<button class="small" onclick="coachConversation(\''+p.id+'\',\'ecouter\')">Écouter (+2)</button>'+
   '<button class="small" onclick="coachConversation(\''+p.id+'\',\'rassurer\')">Rassurer (+1)</button>'+
   '<button class="small" onclick="coachConversation(\''+p.id+'\',\'clarifier\')">Clarifier (+0)</button>')+
   '</div>';}).join('')+'</section>';
}
function contractHistoryPanel(){
 if(!relationsActive())return '';
 const log=S.economy.relationLog||[];
 return '<section class="card"><h2>Historique des discussions · V37</h2><p class="help">Propositions, seuils, confirmations et échanges datés. Une contre-offre n’est pas une signature ; les tentatives sont plafonnées par le moteur existant. Historique limité à 60 événements.</p>'+
 (log.slice(0,20).map(e=>{const person=club().players.find(p=>p.id===e.playerId);
 const name=person?person.name:e.playerId;
 const body=e.kind==='coach'?({ecouter:'Écoute',rassurer:'Réassurance',clarifier:'Clarification'})[e.detail]+
  ' : '+e.amount+' → '+e.minimum+' satisfaction':
  e.kind==='signed'?'Signature confirmée : '+money(e.amount)+'/sem. · '+e.years+' saison(s)':
  'Proposition '+e.attempt+'/3 : '+money(e.amount)+'/sem. · minimum '+money(e.minimum)+
  '/sem. · '+e.years+' saison(s) · '+({ready:'accord de principe',counter:'contre-proposition',withdrawn:'discussions interrompues'})[e.status];
 return '<div class="news"><small>S'+e.season+' J'+(e.round+1)+' · '+visualEscape(name)+'</small> '+body+'</div>';
 }).join('')||'<p>Aucun échange enregistré depuis activation V37.</p>')+'</section>';
}

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
// V35 — nouveaux coefficients bornés autour du salaire de référence V34.
// Source des signes : minutes réellement jouées, progression observée, rôle
// dans la profondeur de poste, âge, finances et résultats réels du club.
// Pas de donnée de match individuelle inventée, ni de tirage aléatoire.
function salaryDemandBreakdown(p,kind='renew',s=S){
 const base=kind==='renew'?Math.max(p.salary,Math.round((roleNote(p)-43)*230/100)*100):p.salary;
 const owner=s?.clubs?.[s.club],active=kind==='renew'&&s?.salaryDemandVersion===1&&
  !!owner?.players?.some(q=>q.id===p.id);
 if(!active)return {active:false,base,asked:base,modifier:0,
  factors:[],reason:kind!=='renew'?'Agents libres : salaire externe déjà demandé, aucun attribut caché utilisé.':
  'Carrière historique : barème V34 conservé jusqu’à activation explicite.'};
 const factors=[],d=p.dev||{};
 const add=(key,rate,description)=>{factors.push({key,rate,description});};
 // Ne pas pénaliser un joueur quand l'échantillon est insuffisant.
 const history=d.history?.at(-1);
 const currentSample=d.minutes>=160&&d.appearances>=2&&owner.played>=3;
 const olderSample=!currentSample&&history?.season===s.season-1&&history.minutes>=160&&history.appearances>=2;
 const minutes=currentSample?d.minutes:olderSample?history.minutes:0;
 const matches=currentSample?owner.played:olderSample?26:0;
 const usage=matches?clamp(minutes/(Math.max(3,matches)*80),0,1):null;
 const usageRate=usage===null?0:usage>=.7?.045:usage<=.25?-.035:0;
 add('minutes',usageRate,usage===null?'Temps de jeu insuffisant pour moduler le salaire':
  'Temps de jeu : '+Math.round(minutes)+' min, part estimée '+Math.round(usage*100)+' %');
 const growth=currentSample?p.rating-(d.seasonStart??p.rating):
  olderSample?history.end-history.start:0;
 const perfRate=clamp(growth,-3,3)*.01;
 add('progression',perfRate,'Performance approchée par la progression générale constatée : '+
  (growth>=0?'+':'')+growth+' point(s), pas par des statistiques individuelles de match');
 const slot=POS.indexOf(p.pos),alternatives=slot<0?2:owner.players.filter(q=>
  q.id!==p.id&&!q.injury&&slotEligible(q,slot)).length;
 const roleRate=alternatives===0?.03:alternatives===1?.015:0;
 add('role',roleRate,alternatives+' alternative(s) apte(s) au poste réglementaire');
 const ageRate=p.age<=23?-.015:p.age>=33?-.02:0;
 add('age',ageRate,'Âge '+p.age+' ans ; prime de durée et retraite déjà traitées par le moteur V34');
 const clubRate=owner.cash<500000?-.025:owner.cash>=8000000?.015:0;
 add('cash',clubRate,'Trésorerie fictive du club : '+money(owner.cash));
 const wonRate=owner.played>=6?(owner.won/owner.played>=.65?.015:
  owner.won/owner.played<=.25?-.015:0):0;
 add('results',wonRate,owner.played>=6?
  'Résultats du club : '+owner.won+' victoires en '+owner.played+' rencontres de championnat':
  'Résultats insuffisants pour un ajustement (moins de 6 rencontres)');
 const raw=factors.reduce((n,v)=>n+v.rate,0);
 const modifier=clamp(raw,-.12,.12);
 const asked=Math.max(p.salary,Math.round(base*(1+modifier)/100)*100);
 return {active:true,base,asked,modifier,
  factors,reason:'Modulation ±12 % maximum sur le barème V34. Contrat actuel conservé comme plancher.'};
}
function askingWage(p,kind){return salaryDemandBreakdown(p,kind).asked}
function salaryDemandPanel(){
 if(!S)return '';
 const enabled=S.salaryDemandVersion===1;
 const candidates=club().players.filter(p=>p.contractEnd<=S.season+2)
  .slice().sort((a,b)=>a.contractEnd-b.contractEnd||a.id.localeCompare(b.id)).slice(0,6);
 const rows=candidates.map(p=>{
  const d=salaryDemandBreakdown(p,'renew'),difference=d.asked-d.base;
  const labels={minutes:'Temps de jeu',progression:'Progression',role:'Rôle',age:'Âge',cash:'Trésorerie',results:'Résultats'};
  const factors=d.factors.map(x=>'<span title="'+visualEscape(x.description)+'">'+
   visualEscape(labels[x.key])+' '+(x.rate>=0?'+':'')+Math.round(x.rate*1000)/10+' %</span>').join(' · ');
  return '<tr><th>'+visualEscape(p.name)+'<small>Fin S'+p.contractEnd+'</small></th>'+
   '<td>'+money(d.base)+'</td><td>'+money(d.asked)+'</td>'+
   '<td>'+(difference>=0?'+':'')+money(difference)+'</td><td>'+
   (enabled?factors:'Barème de la carrière historique, non modifié')+'</td></tr>';
 }).join('');
 const status=enabled?'<p class="help">Demandes évolutives actives. Les seuils de contre-offres V34 les utilisent dès la prochaine proposition, selon les informations actuellement connues.</p>':
  '<p class="help">Cette ancienne carrière conserve les demandes salariales V34, sans changement rétroactif. Activation facultative, impossible pendant un match ou avec des négociations ouvertes.</p>'+
  '<button class="small dark" onclick="enableSalaryDemandModel()">Activer les demandes évolutives pour cette carrière</button>';
 return '<section class="card salary-demand-panel"><div class="cardtitle"><h2>Expliquer les exigences salariales</h2>'+
  '<span class="tag">MODÈLE V35</span></div><p class="help">Base : barème V34. Ajustements cumulés limités à ±12 % : minutes jouées, progression constatée, profondeur au poste, âge, trésorerie fictive et résultats du club. La progression sert d’indicateur de performance : essais et plaquages individuels ne sont pas enregistrés. Les salaires de recrutement externes restent identiques.</p>'+
  status+'<div class="tablewrap"><table class="salary-demand-table"><thead><tr>'+
  '<th>Joueur</th><th>Base V34</th><th>Demande V35</th><th>Écart</th><th>Facteurs transparents</th>'+
  '</tr></thead><tbody>'+rows+'</tbody></table></div>'+
  '<p class="help">Ce tableau ne signe ni ne négocie aucun contrat. Un salaire conforme donne seulement un accord de principe dans le moteur existant ; les salaires réels dépendent ensuite d’une confirmation.</p></section>';
}
function enableSalaryDemandModel(){
 if(!S||S.salaryDemandVersion===1)return false;
 if(S.live||Object.keys(S.economy?.talks||{}).length){
  toast('Terminez le match et les discussions contractuelles en cours avant de changer de barème.');
  return false;
 }
 S.salaryDemandVersion=1;save();render();
 toast('Demandes évolutives activées pour cette carrière. Aucun contrat signé.');
 return true;
}
function reservationWage(p,kind,years){const age=p.age>=31&&years===3?1.12:years===1?1.08:years===3?.96:1;return Math.ceil(askingWage(p,kind)*(.86+(seedHash(p.id)%8)/100)*age*(1+satisfactionWageRate(p,kind))/100)*100}
function contractFee(p,kind){return kind==='renew'?Math.round(p.salary*2/1000)*1000:p.price}
function ledgerEntry(title,amount){club().cash+=amount;S.ledger.unshift({title,amount});S.ledger=S.ledger.slice(0,100)}
function transferEvent(text){S.economy.transfers.unshift({season:S.season,round:S.round,text});S.economy.transfers=S.economy.transfers.slice(0,80);news(text)}
function openContract(id,kind='recruit'){if(economyLocked())return;let p=talkPlayer(id,kind);if(!p)return;let key=talkKey(id,kind),t=S.economy.talks[key];const min=kind==='renew'?Math.max(1,p.contractEnd-contractBase()+2):1;if(min>Math.min(3,careerContractYears(p))){toast('Pas de nouveau contrat possible avant la retraite prévue, ou contrat déjà suffisamment long.');return}
const years=t?.years||Math.max(2,min),salary=t?.salary||askingWage(p,kind),fee=contractFee(p,kind);modal=`<div class="modalback"><section class="modal contractmodal" role="dialog" aria-modal="true" aria-label="Négociation de contrat"><div class="row" style="margin-top:0"><span class="tag">${kind==='renew'?'PROLONGATION':'RECRUTEMENT'}</span><button class="small" onclick="closeModal()">Fermer ×</button></div><h2>${p.name}</h2><p>${p.pos} · ${p.age} ans · ${kind==='renew'?'Note au poste '+roleNote(p):'Niveau estimé '+recruitmentEvidence(p).noteMin+'–'+recruitmentEvidence(p).noteMax+(recruitmentEvidence(p).seen?' (rapport daté)':' (non observé)')}</p><div class="row"><span>Salaire demandé / semaine</span><strong>${money(askingWage(p,kind))}</strong></div><div class="row"><span>Prime à la signature</span><strong>${money(fee)}</strong></div>${kind==='renew'?`<p class="help">Contrat actuel : ${contractLabel(p)} · ${money(p.salary)} / semaine. La nouvelle durée inclut ${contractBase()===S.season?'la saison en cours':'la prochaine saison'}.</p>`:`<p class="help">La durée inclut ${contractBase()===S.season?'la saison en cours':'la prochaine saison'}. Le contrat prend fin à l’issue de la dernière saison indiquée.</p>`}<p class="help">Retraite prévue : fin de saison ${retirementSeason(p)}. Le choix de durée tient compte de cette échéance.</p><div class="contractfields"><label>Salaire proposé / semaine (€)<input id="offer-wage" type="number" step="100" min="1000" max="100000" value="${salary}"></label><label>Durée du contrat<select id="offer-years">${[1,2,3].filter(y=>y>=min&&y<=careerContractYears(p)).map(y=>`<option value="${y}" ${years===y?'selected':''}>${y} saison${y>1?'s':''} · fin S${contractBase()+y-1}</option>`).join('')}</select></label></div><p class="help">Trois propositions maximum par journée. Une acceptation reste à confirmer avant toute dépense.</p>${t?`<div class="notice" role="status">${t.message}</div>`:''}<div class="contractactions">${!t||t.status!=='withdrawn'?`<button class="dark" onclick="submitContract('${id}','${kind}')">Proposer ces conditions</button>`:''}${t&&['ready','counter'].includes(t.status)?`<button class="primary" onclick="confirmContract('${key}')">${t.status==='counter'?'Accepter la contre-proposition':'Confirmer la signature'} · ${money(t.acceptedSalary)} / sem.</button>`:''}</div>${t&&['ready','counter'].includes(t.status)?`<p class="help">Accord proposé : ${t.years} saison(s), fin S${t.end}. Prime ${money(t.fee)} à payer maintenant. Salaires sur ${t.years} saison(s) complète(s) : ${money(t.acceptedSalary*29*t.years)} (29 journées payées par saison ; estimation, hors primes).</p>`:''}</section></div>`;render()}
function submitContract(id,kind){const wage=Number($('#offer-wage').value),years=Number($('#offer-years').value);negotiateContract(id,kind,wage,years);openContract(id,kind)}
function negotiateContract(id,kind,wage,years){if(economyLocked())return false;let p=talkPlayer(id,kind);if(!p||!['recruit','renew'].includes(kind)||!Number.isInteger(wage)||wage<1000||wage>100000||![1,2,3].includes(years)){toast('Vérifiez le salaire et la durée proposés.');return false}let end=contractBase()+years-1;if(years>careerContractYears(p)){toast('Cette durée dépasse la retraite prévue du joueur.');return false}if(kind==='renew'&&end<=p.contractEnd){toast('La prolongation doit allonger le contrat actuel.');return false}let key=talkKey(id,kind),prev=S.economy.talks[key];if(prev?.attempts>=3||prev?.status==='withdrawn'){toast('Le joueur ne négociera plus avant la prochaine journée.');return false}const attempts=(prev?.attempts||0)+1,minimum=reservationWage(p,kind,years);const accepted=wage>=minimum;const withdrawn=!accepted&&attempts===3;const acceptedSalary=accepted?wage:minimum;const status=accepted?'ready':withdrawn?'withdrawn':'counter';const message=accepted?`Accord de principe pour ${money(wage)} par semaine. Confirmez pour signer.`:withdrawn?'Les trois propositions ont échoué. Le joueur met fin aux échanges pour cette journée.':`Le joueur refuse et demande ${money(minimum)} par semaine sur ${years} saison(s). Proposition ${attempts}/3.`;
S.economy.talks[key]={id,kind,week:S.economy.week,attempts,years,salary:wage,acceptedSalary,status,message,end,fee:contractFee(p,kind)};logContractProposal(p,kind,wage,minimum,years,status,attempts);save();return true}
function confirmContract(key){if(economyLocked())return false;const t=S.economy.talks[key];if(!t||!['ready','counter'].includes(t.status)||t.week!==S.economy.week)return false;const p=talkPlayer(t.id,t.kind);if(!p)return false;if(t.years>careerContractYears(p)){toast('Révisez la durée : elle dépasse la retraite prévue.');return false;}if(club().cash<t.fee){toast('Trésorerie insuffisante pour payer la prime.');return false}if(t.kind==='renew'&&t.end<=p.contractEnd)return false;if(t.kind==='recruit'&&club().players.some(x=>x.id===p.id))return false;ledgerEntry(`${t.kind==='renew'?'Prolongation':'Signature'} : ${p.name}`,-t.fee);p.salary=t.acceptedSalary;p.contractEnd=t.end;if(t.kind==='recruit'&&satisfactionActive())ensureSatisfaction(p);if(t.kind==='recruit'){p.joinedSeason=S.season;p.joinedRound=S.round;club().players.push(p);S.market=S.market.filter(x=>x.id!==p.id);S.economy.freeAgents=S.economy.freeAgents.filter(x=>x.id!==p.id)}t.status='signed';logContractSignature(p,t);transferEvent(`${p.name} ${t.kind==='renew'?'prolonge':'rejoint le club'} jusqu’à la fin de la saison ${t.end}, à ${money(p.salary)} par semaine.`);delete S.economy.listings[p.id];S.economy.offers=S.economy.offers.filter(o=>o.playerId!==p.id);modal=null;save();render();toast('Contrat signé.');return true}
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
function contractsPanel(){return `<div class="card"><div class="cardtitle"><h2>Les engagements du club</h2><span class="tag">${club().players.length} CONTRATS</span></div><p class="help">Un contrat expire après les phases finales de sa dernière saison. Une prolongation remplace le salaire immédiatement. Les contrats longs pourront être prolongés quand leur échéance approchera.</p><div class="tablewrap"><table><thead><tr><th>JOUEUR</th><th>POSTE</th><th>SALAIRE / SEMAINE</th><th>ÉCHÉANCE</th><th>ACTION</th></tr></thead><tbody>${[...club().players].sort((a,b)=>a.contractEnd-b.contractEnd||b.salary-a.salary).map(p=>`<tr><td><button class="textbutton" onclick="inspectPlayer('${p.id}')">${p.name}</button></td><td>${p.pos}</td><td>${money(p.salary)}</td><td><span class="${p.contractEnd===S.season?'danger':''}">${contractLabel(p)}</span></td><td><button class="small" onclick="openContract('${p.id}','renew')" ${p.contractEnd>=contractBase()+2?'disabled':''}>Prolonger</button></td></tr>`).join('')}</tbody></table></div><div class="notice">Salaires restant à verser : environ ${money(futureWages())}. Estimation sur 29 journées payées par saison, hors primes de prolongation et futurs recrutements.</div></div>`+salaryDemandPanel()+satisfactionPanel()+tensionsDashboard()+coachPanel()+contractHistoryPanel()+renewalAdvisorPanel()+counterofferPanel()}
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



// V33 — Conseiller de prolongations en lecture seule : aucun appel à save(),
// ledgerEntry(), submitContract() ou confirmContract(). Le contrat et le cash
// effectifs du club sont exclusivement modifiés par les actions du mercato.
let renewalChoice={first:null,second:null,third:null,years:2,horizon:3};
function renewalEligibleYears(s,p,desired=2){
 const base=forecastContractBase(s),min=Math.max(1,p.contractEnd-base+2),
  max=Math.min(3,(p.dev?.retireAge??99)-p.age-(s.phase==='ended'?1:0));
 if(max<min)return null;
 return {min,max,years:Math.min(max,Math.max(min,desired))};
}
function renewalPriorities(s=S,horizon=3,desiredYears=2){
 if(!s||!Number.isInteger(horizon)||horizon<1||horizon>3||
  !Number.isInteger(desiredYears)||desiredYears<1||desiredYears>3)return [];
 const team=s.clubs[s.club],baseline=successionSimulate(s,[],horizon);
 if(!baseline.valid)return [];
 const needs=POS.map((_,slot)=>recruitmentNeed(team,slot));
 const totalMissing=baseline.gaps;
 return team.players.flatMap(p=>{
  const terms=renewalEligibleYears(s,p,desiredYears);
  if(!terms)return [];
  const quote=forecastQuote(s,{kind:'renew',id:p.id,years:terms.years});
  if(!quote.valid)return [];
  const projection=successionSimulate(s,[{kind:'renew',id:p.id,years:terms.years}],horizon);
  if(!projection.valid)return [];
  const slots=needs.filter(n=>slotEligible(p,n.slot));
  if(!slots.length)return [];
  const primary=slots.slice().sort((a,b)=>b.score-a.score||a.slot-b.slot)[0];
  const peers=team.players.filter(q=>q.id!==p.id&&!q.injury&&slotEligible(q,primary.slot));
  const here=roleNote(p,FAMILIES[primary.slot]);
  const backup=peers.length?Math.max(...peers.map(q=>roleNote(q,FAMILIES[primary.slot]))):team.base-12;
  const minutes=p.dev?.careerMinutes||0,age=p.age;
  const futureDelta=Math.max(0,totalMissing-projection.gaps);
  const urgency=p.contractEnd<=s.season?27:p.contractEnd===s.season+1?18:9;
  const scarcity=Math.min(18,Math.round(primary.score*.2));
  const impact=Math.min(24,futureDelta*12);
  const strength=Math.min(14,Math.max(0,Math.round((here-backup)*.7)+5));
  const upside=Math.min(9,Math.round(Math.max(0,(p.dev?.potential??p.rating)-p.rating)*.5));
  const mature=age<=28?6:age<=31?3:0;
  const retiredSoon=(p.dev?.retireAge??99)-age<=2?18:age>=34?7:0;
  const fee=quote.fee,proposedSalary=quote.players.find(q=>q.id===p.id)?.salary??p.salary;
  const financialPenalty=(fee>team.cash*.15?12:0)+(proposedSalary>p.salary*1.5?6:0);
  const score=clamp(urgency+scarcity+impact+strength+upside+mature-retiredSoon-financialPenalty,0,100);
  const youth=s.development.academy.filter(y=>slotEligible(y,primary.slot)&&y.dev?.potential>=y.rating+5).length;
  const reasons=[
   p.contractEnd<=s.season?'Contrat expirant cette saison':'Contrat fin S'+p.contractEnd,
   primary.pos+' : besoin V30 '+primary.score+'/100',
   'Note au poste '+here+' contre '+backup+' pour la meilleure alternative disponible',
   'Relève V32 : '+futureDelta+' poste-saison(s) sécurisés sur '+horizon,
   'Âge '+age+' ans, retraite prévue à '+(p.dev?.retireAge??'?')+' ans',
   'Potentiel restant '+Math.max(0,(p.dev?.potential??p.rating)-p.rating)+' point(s)',
   youth?youth+' espoir(s) du centre éligible(s)':'Aucun espoir adapté au poste',
   'Prime '+money(fee)+' ; salaire simulé '+money(proposedSalary)+'/journée'
  ];
  if(p.dev?.specialization&&Object.values(p.dev.specialization.bonuses||{}).some(v=>v>0))
   reasons.push('Qualités spécialisées V29 incluses dans la note actuelle, sans double bonus');
  if(terms.years!==desiredYears)
   reasons.push('Durée ajustée à '+terms.years+' saison(s) selon contrat existant et retraite');
  if(!projection.executable)reasons.push('Prolongation non réalisable immédiatement');
  return [{id:p.id,p,score,primarySlot:primary.slot,need:primary.score,
   futureDelta,here,backup,upside,age,fee,proposedSalary,terms,projection,
   reasons,executable:projection.executable,minutes}];
 }).sort((a,b)=>b.score-a.score||b.futureDelta-a.futureDelta||
  a.p.contractEnd-b.p.contractEnd||a.id.localeCompare(b.id));
}
function renewalCompare(s,ids=[],horizon=3,desiredYears=2,ranked=null){
 if(!s||!Array.isArray(ids)||ids.length>3||
  !Number.isInteger(horizon)||horizon<1||horizon>3||
  !Number.isInteger(desiredYears)||desiredYears<1||desiredYears>3)
  return {valid:false,error:'Horizon ou sélection invalide.'};
 const cleanIds=ids.filter(id=>id!=='');
 if(cleanIds.some(id=>typeof id!=='string')||new Set(cleanIds).size!==cleanIds.length)
  return {valid:false,error:'Sélectionnez des joueurs différents.'};
 const priorities=ranked||renewalPriorities(s,horizon,desiredYears);
 const pool=new Map(priorities.map(c=>[c.id,c]));
 if(cleanIds.some(id=>!pool.has(id)))return {valid:false,error:'Joueur indisponible à la prolongation.'};
 const variants=[{name:'Sans prolongation',ids:[]}];
 for(const id of cleanIds)variants.push({name:'Conserver '+pool.get(id).p.name,ids:[id]});
 if(cleanIds.length>=2)variants.push({name:'Conserver les 2 premiers',ids:cleanIds.slice(0,2)});
 if(cleanIds.length>=3)variants.push({name:'Conserver les 3',ids:cleanIds});
 const baseline=successionSimulate(s,[],horizon);
 if(!baseline.valid)return {valid:false,error:baseline.error};
 const cases=variants.map(v=>{
  const actions=v.ids.map(id=>({kind:'renew',id,years:pool.get(id).terms.years}));
  const result=actions.length?successionSimulate(s,actions,horizon):baseline;
  if(!result.valid)return {...v,valid:false,error:result.error};
  const last=result.finance.points.at(-1),baselineLast=baseline.finance.points.at(-1);
  return {...v,valid:true,executable:result.executable,fee:result.fee,
   savedGaps:baseline.gaps-result.gaps,
   financialChange:last.central-baselineLast.central,
   cashLow:last.low,cashCentral:last.central,cashHigh:last.high,
   minimumLow:result.finance.minima.low,risk:result.finance.risk,
   annual:result.finance.annual,coverage:result.years.map(y=>y.covered),
   gaps:result.years.map(y=>y.gaps.length),explanations:result.reasons};
 });
 return {valid:true,horizon,desiredYears,cases,priorities};
}
function setRenewalChoice(field,value){
 if(!S||!['first','second','third','years','horizon'].includes(field))return false;
 if(field==='years'||field==='horizon'){
  value=Number(value);if(!Number.isInteger(value)||value<1||value>3)return false;
 }else if(typeof value!=='string'||value.length>150||
  (value&&!renewalPriorities(S,renewalChoice.horizon,renewalChoice.years).some(p=>p.id===value)))
  return false;
 renewalChoice[field]=value;render();return true;
}
function renewalAdvisorPanel(){
 if(!S)return '';
 const o=renewalChoice,ranked=renewalPriorities(S,o.horizon,o.years),top=ranked.slice(0,12);
 const selected=[],labels=[['first','Joueur 1'],['second','Joueur 2'],['third','Joueur 3']];
 const inputs=labels.map(([key,label],i)=>{
  const remembered=o[key],fallback=top[i]?.id||'';
  const id=remembered===null?fallback:remembered;
  const current=top.find(p=>p.id===id),actual=current?id:(remembered===null?fallback:'');
  if(actual)selected.push(actual);
  return '<label>'+label+'<select aria-label="'+label+' à prolonger" onchange="setRenewalChoice(\''+
   key+'\',this.value)"><option value=""'+(!actual?' selected':'')+'>Aucune prolongation</option>'+
   top.map(t=>'<option value="'+t.id+'"'+(t.id===actual?' selected':'')+'>'+
    visualEscape(t.p.name)+' · S'+t.p.contractEnd+' · '+t.score+'/100</option>').join('')+
   '</select></label>';
 }).join('');
 const controls='<div class="renewal-controls">'+
  [['years','Durée envisagée'],['horizon','Horizon de comparaison']].map(([key,label])=>
   '<label>'+label+'<select aria-label="'+label+'" onchange="setRenewalChoice(\''+key+'\',this.value)">'+
   [1,2,3].map(n=>'<option value="'+n+'"'+(o[key]===n?' selected':'')+'>'+n+' saison'+
   (n>1?'s':'')+'</option>').join('')+'</select></label>').join('')+inputs+'</div>';
 const analysis=renewalCompare(S,selected,o.horizon,o.years,ranked);
 const recs=ranked.slice(0,8).map((r,i)=>
  '<tr><td><strong>'+(i+1)+'. '+visualEscape(r.p.name)+'</strong><small>'+r.p.pos+
  ' · '+r.p.age+' ans · fin S'+r.p.contractEnd+'</small></td><td><strong>'+r.score+'/100</strong></td>'+
  '<td>'+r.here+'<small>Alternative '+r.backup+'</small></td>'+
  '<td>'+r.futureDelta+'<small>poste-saison(s)</small></td>'+
  '<td>'+money(r.fee)+'<small>'+money(r.proposedSalary)+'/journée, '+r.terms.years+' saison(s)</small></td>'+
  '<td>'+r.reasons.slice(0,5).map(x=>visualEscape(x)).join(' · ')+
  (r.executable?'':' · Non réalisable immédiatement')+'</td></tr>').join('');
 const rows=analysis.valid?analysis.cases.map(c=>!c.valid?
  '<tr><th>'+visualEscape(c.name)+'</th><td colspan="'+(o.horizon+4)+'>'+visualEscape(c.error)+'</td></tr>':
  '<tr><th>'+visualEscape(c.name)+'</th>'+
   c.coverage.map((n,i)=>'<td>'+n+'/15<small>'+c.gaps[i]+' poste(s) à couvrir</small></td>').join('')+
   '<td>'+money(c.fee)+'</td><td>'+money(c.cashCentral)+
   '<small>Prudent '+money(c.cashLow)+'</small></td>'+
   '<td>'+(c.financialChange>=0?'+':'')+money(c.financialChange)+'</td>'+
   '<td>'+(c.executable?'Simulation possible':'Non réalisable actuellement')+
   '<small>'+visualEscape(c.risk)+'</small></td></tr>').join(''):
  '<tr><td colspan="'+(o.horizon+5)+'>'+visualEscape(analysis.error)+'</td></tr>';
 const table='<div class="tablewrap"><table class="renewal-comparison"><thead><tr><th>Option</th>'+
  Array.from({length:o.horizon},(_,i)=>'<th>Fin S'+(S.season+i)+'</th>').join('')+
  '<th>Prime totale</th><th>Trésorerie finale V31</th><th>Écart au statu quo</th>'+
  '<th>Faisabilité</th></tr></thead><tbody>'+rows+'</tbody></table></div>';
 return '<section class="card renewal-advisor"><div class="cardtitle"><h2>Prioriser les prolongations</h2>'+
  '<span class="tag">CONSEILLER V33</span></div>'+
  '<p class="help">Les priorités combinent urgence contractuelle, valeur sportive réelle, qualité V29, couverture V30, relève V32, âge, potentiel et risque de trésorerie V31. Les coefficients de priorité sont des critères fictifs d’aide à la décision, pas des probabilités ni des garanties d’accord.</p>'+
  '<div class="tablewrap"><table class="renewal-ranking"><thead><tr><th>Joueur</th><th>Priorité</th>'+
  '<th>Note au poste V29</th><th>Relève V32</th><th>Coût prévu V31</th><th>Explications</th></tr></thead><tbody>'+
  (recs||'<tr><td colspan="6">Aucun contrat renouvelable pour le moment.</td></tr>')+
  '</tbody></table></div><h3>Comparer plusieurs décisions sans négocier</h3>'+
  controls+table+
  '<p class="help">Une durée peut être ajustée si le contrat actuel exige une prolongation plus longue ou si la retraite prévue empêche la durée souhaitée. Les salaires et primes proviennent exactement de forecastQuote(), les flux futurs de forecastFinancialScenario() et les postes de successionSimulate(). Jusqu’à trois joueurs distincts peuvent être comparés seuls ou ensemble. Aucun contrat, journal ou fichier de sauvegarde n’est modifié.</p></section>';
}


// V34 — simulateur de contre-offres sans mutation ni sauvegarde.
// Reprend strictement la réservation, les trois tentatives, et les états
// ready/counter/withdrawn de negotiateContract(), jamais confirmContract().
let counterofferChoice={kind:'renew',id:'',wage:0,horizon:3,years:2};
function counterofferCandidates(s,kind){
 if(!s||!['renew','recruit'].includes(kind))return [];
 if(kind==='renew')return renewalPriorities(s,3,2).map(x=>x.p);
 return s.market.filter(p=>s.clubs[s.club].players.every(q=>q.id!==p.id))
  .sort((a,b)=>a.salary-b.salary||a.id.localeCompare(b.id)).slice(0,40);
}
function counterofferQuote(s,request={},horizon=3,priorityIndex=null){
 const {kind='renew',id,wage,years}=request;
 if(!s||!['renew','recruit'].includes(kind)||typeof id!=='string'||
  !Number.isInteger(wage)||wage<1000||wage>100000||
  !Number.isInteger(years)||years<1||years>3||
  !Number.isInteger(horizon)||horizon<1||horizon>3)
  return {valid:false,error:'Proposition hors limites du moteur : salaire 1 000 à 100 000 €, durée et horizon 1 à 3 saisons.'};
 const team=s.clubs[s.club],p=kind==='renew'?team.players.find(q=>q.id===id):s.market.find(q=>q.id===id);
 if(!p)return {valid:false,error:'Joueur indisponible dans le club ou sur le marché.'};
 const end=forecastContractBase(s)+years-1;
 const earliest=kind==='renew'?Math.max(1,p.contractEnd-forecastContractBase(s)+2):1;
 const retirement=(p.dev?.retireAge??50)-p.age-(s.phase==='ended'?1:0);
 if(years<earliest||years>retirement||end<=p.contractEnd&&kind==='renew')
  return {valid:false,error:'Durée impossible : le contrat doit être allongé sans dépasser la retraite prévue.',
   minYears:earliest,maxYears:Math.min(3,retirement)};
 if(kind==='recruit'&&(team.players.some(q=>q.id===id)||team.players.length>=42))
  return {valid:false,error:'Le joueur ne peut pas intégrer cet effectif complet ou existant.'};
 const minimum=reservationWage(p,kind,years),asking=askingWage(p,kind);
 const fee=contractFee(p,kind),key=s.season+':'+s.economy.week+':'+kind+':'+id;
 const prev=s.economy.talks[key],attempts=prev?.attempts||0;
 const exhausted=attempts>=3||prev?.status==='withdrawn';
 const available=!s.live&&!exhausted;
 const passes=wage>=minimum,nextAttempt=attempts+1;
 const engineStatus=passes?'ready':nextAttempt===3?'withdrawn':'counter';
 const status=available?engineStatus:'blocked';
 const acceptedSalary=passes?wage:minimum;
 const executable=available&&engineStatus!=='withdrawn'&&team.cash>=fee;
 const memo=[
  'Salaire demandé : '+money(asking)+' / semaine ; seuil de réservation calculé : '+money(minimum)+'.',
  passes?'Le salaire atteint le seuil déterministe : accord de principe, signature séparée obligatoire.':
   nextAttempt===3?'Sous le seuil : troisième refus, retrait des négociations pour cette journée.':
   'Sous le seuil : le joueur propose '+money(minimum)+' / semaine ; confirmation séparée obligatoire.',
  'Tentatives déjà utilisées cette journée : '+attempts+' / 3.',
  s.live?'Match en cours : toute négociation réelle est verrouillée.':null,
  exhausted?'Négociation épuisée ou retirée pour cette journée.':null,
  team.cash<fee?'Prime supérieure à la trésorerie disponible : confirmation impossible.':null
 ].filter(Boolean);
 // Contrat de simulation uniquement : projection avec les mêmes coefficients
 // financiers V31, mais le salaire réellement choisi dans cette contre-offre.
 const players=team.players.map(q=>({id:q.id,salary:q.salary,contractEnd:q.contractEnd}));
 if(kind==='renew'){
  const target=players.find(q=>q.id===id);target.salary=acceptedSalary;target.contractEnd=end;
 }else players.push({id:p.id,salary:acceptedSalary,contractEnd:end});
 const synthetic={...s,clubs:s.clubs.map((c,i)=>i===s.club?
  {...c,cash:c.cash-fee,players}:c)};
 const finance=forecastFinancialScenario(synthetic,{kind:'baseline'},horizon);
 const reference=forecastFinancialScenario(s,{kind:'baseline'},horizon);
 if(!finance.valid||!reference.valid)return {valid:false,error:'Projection de trésorerie indisponible.'};
 // Relève V32 : une seule place par joueur, aucune nouvelle compétence.
 const people=team.players.map(q=>successionPerson(q)),academy=s.development.academy;
 if(kind==='renew'){
  const target=people.find(q=>q.id===id);target.contractEnd=end;target.salary=acceptedSalary;
 }else{
  const projected=successionPerson(p,'external');projected.contractEnd=end;
  projected.salary=acceptedSalary;projected.injury=0;people.push(projected);
 }
 const yearsProjection=Array.from({length:horizon},(_,i)=>
  successionYear(s,people,academy,s.season+i));
 const now=finance.points.at(-1),base=reference.points.at(-1);
 const needs=POS.map((_,slot)=>slotEligible(p,slot)?recruitmentNeed(team,slot):null)
  .filter(Boolean).sort((a,b)=>b.score-a.score||a.slot-b.slot);
 const v33=kind==='renew'?(priorityIndex||renewalPriorities(s,horizon,years)).find(x=>x.id===id):null;
 const evidence=kind==='recruit'?recruitmentEvidence(p):null;
 return {valid:true,kind,id,player:p.name,years,end,wage,minimum,asking,fee,
  attempts,nextAttempt,status,engineStatus,acceptedSalary,passes,executable,
  needs:needs[0]?.score??0,position:needs[0]?.pos||p.pos,
  v33Priority:v33?.score??null,observed:kind==='renew'||!!evidence?.seen,
  explanation:memo,finance:{low:now.low,central:now.central,high:now.high,
   minLow:finance.minima.low,risk:finance.risk,
   delta:now.central-base.central,annual:finance.annual},
  succession:{covered:yearsProjection.map(y=>y.covered),
   gaps:yearsProjection.map(y=>y.gaps.length)}};
}
function counterofferAlternatives(s,kind,id,customWage,years=2,horizon=3){
 if(!s||!['renew','recruit'].includes(kind)||typeof id!=='string'||
  !Number.isInteger(years)||years<1||years>3||
  !Number.isInteger(horizon)||horizon<1||horizon>3)return [];
 const p=kind==='renew'?s.clubs[s.club].players.find(q=>q.id===id):s.market.find(q=>q.id===id);
 if(!p)return [];
 const min=reservationWage(p,kind,years);
 const low=Math.max(1000,Math.floor((min*.9)/100)*100);
 const high=Math.min(100000,Math.ceil(Math.max(min+100,askingWage(p,kind)*1.1)/100)*100);
 const chosen=Number.isInteger(customWage)&&customWage>=1000&&customWage<=100000?
  customWage:askingWage(p,kind);
 const priorities=kind==='renew'?renewalPriorities(s,horizon,years):null;
 const candidates=[
  {label:'Offre prudente · '+years+' saison(s)',wage:low,years},
  {label:'Au seuil · '+years+' saison(s)',wage:min,years},
  {label:'Marge haute · '+years+' saison(s)',wage:high,years},
  ...[1,2,3].map(y=>({label:'Votre salaire · '+y+' saison(s)',wage:chosen,years:y}))
 ];
 return candidates.map(x=>({...x,result:counterofferQuote(s,{kind,id,wage:x.wage,years:x.years},horizon,priorities)}));
}
function setCounterofferChoice(field,value){
 if(!S||!['kind','id','wage','years','horizon'].includes(field))return false;
 if(field==='kind'){
  if(!['renew','recruit'].includes(value))return false;
  counterofferChoice.kind=value;counterofferChoice.id='';counterofferChoice.wage=0;
 }else if(field==='id'){
  if(typeof value!=='string'||value.length>150||
   !counterofferCandidates(S,counterofferChoice.kind).some(p=>p.id===value))return false;
  counterofferChoice.id=value;counterofferChoice.wage=0;
 }else{
  value=Number(value);if(!Number.isInteger(value)||
   (field==='wage'?(value<1000||value>100000):(value<1||value>3)))return false;
  counterofferChoice[field]=value;
 }
 render();return true;
}
function counterofferPanel(){
 if(!S)return '';
 const choice=counterofferChoice,list=counterofferCandidates(S,choice.kind);
 const p=list.find(x=>x.id===choice.id)||list[0];
 if(!p)return '<section class="card"><h2>Contre-offres V34</h2><p>Aucun joueur éligible à ce scénario.</p></section>';
 const wage=choice.wage||askingWage(p,choice.kind);
 const proposals=counterofferAlternatives(S,choice.kind,p.id,wage,choice.years,choice.horizon);
 const control='<div class="counteroffer-controls">'+
  '<label>Type de discussion<select aria-label="Type de négociation V34" onchange="setCounterofferChoice(\'kind\',this.value)">'+
  [['renew','Prolongation'],['recruit','Recrutement']].map(([v,n])=>'<option value="'+v+'"'+(choice.kind===v?' selected':'')+'>'+n+'</option>').join('')+'</select></label>'+
  '<label>Joueur<select aria-label="Joueur V34" onchange="setCounterofferChoice(\'id\',this.value)">'+
  list.slice(0,24).map(q=>'<option value="'+q.id+'"'+(q.id===p.id?' selected':'')+'>'+
   visualEscape(q.name)+' · '+q.pos+'</option>').join('')+'</select></label>'+
  '<label>Salaire proposé (€ / semaine)<input aria-label="Salaire de scénario V34" type="number" min="1000" max="100000" step="100" value="'+wage+
  '" onchange="setCounterofferChoice(\'wage\',this.value)"></label>'+
  [['years','Durée principale'],['horizon','Horizon financier']].map(([k,n])=>'<label>'+n+
  '<select aria-label="'+n+' V34" onchange="setCounterofferChoice(\''+k+'\',this.value)">'+
   [1,2,3].map(y=>'<option value="'+y+'"'+(choice[k]===y?' selected':'')+'>'+y+' saison'+(y>1?'s':'')+'</option>').join('')+
   '</select></label>').join('')+'</div>';
 const rows=proposals.map(x=>{
  const r=x.result;
  if(!r.valid)return '<tr><th>'+visualEscape(x.label)+'</th><td>'+money(x.wage)+'</td>'+
   '<td>'+x.years+'</td><td colspan="6">'+visualEscape(r.error)+'</td></tr>';
  const label=r.status==='ready'?'Seuil atteint · accord de principe':r.status==='counter'?
   'Contre-proposition':r.status==='withdrawn'?'Retrait à la 3e tentative':'Négociation verrouillée';
  return '<tr><th>'+visualEscape(x.label)+'</th><td>'+money(r.wage)+'</td><td>'+r.years+'</td>'+
   '<td>'+visualEscape(label)+'<small>'+r.attempts+'/3 tentatives déjà utilisées</small></td>'+
   '<td>'+money(r.minimum)+'<small>Accord simulé à '+money(r.acceptedSalary)+'</small></td>'+
   '<td>'+money(r.fee)+'</td><td>'+money(r.finance.central)+
    '<small>Prudent '+money(r.finance.low)+'</small></td>'+
   '<td>'+(r.finance.delta>=0?'+':'')+money(r.finance.delta)+'</td>'+
   '<td>'+r.succession.covered.at(-1)+'/15<small>'+r.succession.gaps.at(-1)+' postes vacants</small>'+
   (r.executable?'':'<small>Non confirmable maintenant</small>')+'</td></tr>';
 }).join('');
 const first=proposals.find(x=>x.result.valid)?.result;
 const context=first?'<p class="help">Besoin au poste V30 : '+first.needs+'/100 · '+
  (first.v33Priority===null?'':'priorité V33 '+first.v33Priority+'/100 · ')+
  (first.observed?'joueur évalué':'joueur non observé : aucune note cachée utilisée')+
  '. Les postes futurs sont calculés par V32.</p>':'';
 return '<section class="card counteroffer-panel"><div class="cardtitle"><h2>Comparer les contre-offres</h2>'+
  '<span class="tag">SIMULATION V34</span></div><p class="help">Trois niveaux de salaire et votre proposition sur 1, 2 et 3 saisons. Le seuil utilise reservationWage() et le statut suit les trois tentatives du moteur. Une contre-proposition ou un accord de principe ne constitue JAMAIS une signature.</p>'+
  control+context+'<div class="tablewrap"><table class="counteroffer-table"><thead><tr><th>Scénario</th>'+
  '<th>Salaire proposé</th><th>Durée</th><th>Réponse simulée</th><th>Seuil / salaire accepté</th>'+
  '<th>Prime immédiate</th><th>Trésorerie finale V31</th><th>Écart</th><th>Relève V32</th>'+
  '</tr></thead><tbody>'+rows+'</tbody></table></div>'+
  '<p class="help">En cas de salaire inférieur au seuil, les chiffres financiers illustrent une acceptation ultérieure de la contre-proposition par le club, pas une signature automatique. Les coûts suivent les coefficients V31 ; l’âge, les contrats, la trésorerie, les tentatives et les matchs en cours sont contrôlés. Aucun bouton ne transmet une offre réelle, aucun journal ou sauvegarde n’est modifié.</p></section>';
}

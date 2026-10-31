'use strict';
// Coordination V41-V45 : décisions uniquement explicites, données de carrière fictives.
// Les cinq moteurs d'analyse purs restent intacts et indépendants des règles de match.
const CAREER_SPONSORS=Object.freeze({
 prudent:{label:'Partenaire stable',weekly:9500,signing:0,win:0},
 performance:{label:'Partenaire à la performance',weekly:4500,signing:30000,win:11000},
 avance:{label:'Partenaire avec avance',weekly:6500,signing:120000,win:1500}
});
const CAREER_ACADEMY_LEVELS=[0,4000,12000];
function careerIntegrated(){return S?.integratedManagementVersion===1&&S?.careerManagement?.version===1}
function careerSetup(){
 if(!S||S.integratedManagementVersion!==1)return false;
 if(!S.careerManagement)S.careerManagement={version:1,sponsor:null,academyInvestment:0,
  academySpent:0,academyWeeks:0,lastAcademyWeek:null,boardHistory:[],history:[],
  promotions:0,lastBoardRound:-1};
 return true;
}
function careerEnable(){
 if(!S||careerIntegrated()||S.live||S.phase==='ended'||Object.keys(S.economy?.talks||{}).length)return false;
 S.integratedManagementVersion=1;careerSetup();save();render();return true;
}
function careerRecord(type,label,clubId=S.club,detail=''){
 if(!careerIntegrated())return false;
 const id='S'+S.season+':J'+S.round+':club'+clubId+':'+type+':'+detail;
 S.careerManagement.history=CDCareerHistory.append(S.careerManagement.history,
  {id,type,label,season:S.season,clubId:'club-'+clubId},{limit:180});
 return true;
}
function careerSponsorPick(key){
 if(!careerIntegrated()||S.live||S.phase!=='league'||S.round>4||S.careerManagement.sponsor||
  !Object.prototype.hasOwnProperty.call(CAREER_SPONSORS,key))return false;
 const terms=CAREER_SPONSORS[key],c=S.careerManagement;
 c.sponsor={key,season:S.season};
 if(terms.signing)ledgerEntry('Signature du sponsor · '+terms.label,terms.signing);
 careerRecord('manager','Partenaire : '+terms.label,S.club,'sponsor');
 news('Accord commercial : '+terms.label+' · '+money(terms.weekly)+
  '/semaine supplémentaire'+(terms.signing?', avance '+money(terms.signing):'')+
  (terms.win?', prime de '+money(terms.win)+' par victoire':'')+'.');
 save();render();return true;
}
function careerSponsorWeek(won){
 if(!careerIntegrated())return 0;
 const contract=S.careerManagement.sponsor;
 if(!contract||contract.season!==S.season)return 0;
 const terms=CAREER_SPONSORS[contract.key];
 ledgerEntry(label()+' · Sponsor '+terms.label,terms.weekly);
 if(won&&terms.win)ledgerEntry(label()+' · Prime partenaire victoire',terms.win);
 return terms.weekly+(won?terms.win:0);
}
function careerSetAcademyInvestment(amount){
 if(!careerIntegrated()||S.live||S.trained||S.phase!=='league'||!CAREER_ACADEMY_LEVELS.includes(amount))return false;
 S.careerManagement.academyInvestment=amount;save();render();return true;
}
function careerAcademyTraining(){
 if(!careerIntegrated()||S.live||S.phase!=='league')return false;
 const c=S.careerManagement,period=S.season+':'+S.economy.week;
 if(c.lastAcademyWeek===period)return false;
 c.lastAcademyWeek=period;
 const cost=c.academyInvestment;
 if(!cost)return true;
 if(club().cash<cost){
  news('Le centre de formation ne reçoit pas ses '+money(cost)+' cette semaine : trésorerie insuffisante.');
  return false;
 }
 ledgerEntry(label()+' · Investissement formation',-cost);
 c.academySpent+=cost;c.academyWeeks++;
 const xp=cost===4000?.055:.15;
 for(const p of S.development.academy)growPlayer(p,xp*ageGrowth(p),false);
 return true;
}
function careerPromoteYouth(p){
 if(!careerIntegrated())return false;
 S.careerManagement.promotions++;
 careerRecord('manager','Premier contrat professionnel : '+p.name,S.club,'youth-'+p.id);
 return true;
}
function careerRecruitSigning(p,t){
 if(!careerIntegrated()||t.kind!=='recruit')return false;
 careerRecord('manager','Recrutement : '+p.name+' · '+money(p.salary)+'/semaine',S.club,'sign-'+p.id);
 return true;
}
function careerBoardWeekReview(){
 if(!careerIntegrated()||S.phase!=='league'||!club().played||club().played%5!==0||
  S.careerManagement.lastBoardRound===S.round)return false;
 const c=S.careerManagement,past=S.trust,team=club();
 const result=clamp(50+(team.won-team.lost)*4,0,100);
 const finance=team.cash<0?5:team.cash<750000?50:team.cash<2500000?70:90;
 const youth=clamp(50+c.promotions*20,0,100);
 const target=CDBoardPlanning.boardConfidence({current:past,results:result,finances:finance,youth});
 const delta=clamp(target.change,-2,2);
 S.trust=clamp(past+delta,0,100);
 c.boardHistory.unshift({season:S.season,round:S.round,previous:past,after:S.trust,
  results:result,finances:finance,youth,score:Math.round(target.score)});
 c.boardHistory=c.boardHistory.slice(0,24);
 c.lastBoardRound=S.round;
 news('Bilan de direction : '+(delta>=0?'+':'')+delta+' confiance (résultats 55 %, finances 30 %, formation 15 %).');
 return true;
}
function careerRecordChampion(id){
 if(!careerIntegrated()||!Number.isInteger(id)||id<0||id>=14)return false;
 return careerRecord('trophy','Bouclier de Brennus · champion de France',id,'champion');
}
function careerSeasonEnd(){
 if(!careerIntegrated())return false;
 const pos=ranked().findIndex(c=>c.id===S.club)+1;
 careerRecord('manager','Saison '+S.season+' · '+pos+'e place · '+club().won+' victoire(s)',S.club,'season-end');
 return true;
}
function careerSeasonStart(){
 if(!careerIntegrated())return;
 const c=S.careerManagement;
 c.sponsor=null;c.academySpent=0;c.academyWeeks=0;c.lastAcademyWeek=null;
 c.promotions=0;c.lastBoardRound=-1;
}
function careerBudgetModel(){
 const s=careerIntegrated()?S.careerManagement:null;
 const sponsor=s?.sponsor?.season===S.season?CAREER_SPONSORS[s.sponsor.key]:null;
 return {cash:club().cash,weeklyIncome:160000+(sponsor?.weekly||0),
  weeklyWages:totalWages(),weeklyOtherCosts:s?.academyInvestment||0,
  weeks:Math.max(1,Math.min(12,29-S.round))};
}
function careerFinancialAnalysis(){
 const base=careerBudgetModel(),projection=CDFinancePlanning.forecast(base);
 const comparison=CDFinancePlanning.compare(base,[
  {name:'Recruter (+10 000 €/sem.)',adjustments:{weeklyWages:base.weeklyWages+10000}},
  {name:'Formation (+4 000 €/sem.)',adjustments:{weeklyOtherCosts:base.weeklyOtherCosts+4000}},
  {name:'Baisse des recettes partenaires de 20 %',adjustments:{weeklyIncome:base.weeklyIncome*.8}}
 ]);
 return {base,projection,comparison};
}
function careerFinancePanel(){
 if(!careerIntegrated())return '<section class="card"><h2>Gestion de club V41–V45</h2><p class="help">Carrière créée avant l’intégration : les systèmes de direction, sponsoring et formation restent inactifs jusqu’à activation volontaire.</p><button onclick="careerEnable()" '+(S.live?'disabled':'')+'>Activer la gestion intégrée</button></section>';
 const {base,projection,comparison}=careerFinancialAnalysis(),c=S.careerManagement,terms=c.sponsor?CAREER_SPONSORS[c.sponsor.key]:null;
 const remaining=Math.max(1,26-S.round);
 return '<section class="card career-integration-card"><div class="cardtitle"><h2>Prévisions financières et décisions</h2><span class="tag">MODÈLE FICTIF</span></div>'+
 '<p class="help">Projection prudente en euros sur '+base.weeks+' semaines : partenaires existants 160 000 €/semaine, nouveau sponsor éventuel, salaires actuels et formation. Billetterie, primes sportives, transferts et aléas exclus ; les contrats peuvent évoluer.</p>'+
 '<div class="row"><span>Variation hebdomadaire projetée</span><strong>'+money(projection.weeklyNet)+'</strong></div>'+
 '<div class="row"><span>Trésorerie projetée</span><strong>'+money(projection.finalBalance)+'</strong></div>'+
 '<div class="row"><span>Déficit dans la période</span><strong>'+(projection.firstDeficit===null?'Non':'Semaine '+projection.firstDeficit)+'</strong></div>'+
 '<h3>Arbitrages possibles · comparaison sans engagement</h3>'+
 comparison.scenarios.map(x=>'<div class="row"><span>'+visualEscape(x.name)+'</span><strong>'+money(x.delta)+'</strong></div>').join('')+
 '<h3>Signer un sponsor additionnel</h3><p class="help">Les 160 000 € de partenaires déjà comptabilisés restent inchangés. Un seul nouveau contrat par saison, avant la 5e journée. Le bonus de signature est encaissé une seule fois ; les versements suivent les matchs.</p>'+
 (terms?'<div class="notice">Contrat signé : '+terms.label+' · '+money(terms.weekly)+'/semaine · '+money(terms.win)+' par victoire.</div>':
 Object.entries(CAREER_SPONSORS).map(([key,t])=>{
 const v=CDBoardPlanning.sponsorContract({weeklyPayment:t.weekly,signingBonus:t.signing,winBonus:t.win,weeks:remaining,wins:0});
 return '<div class="row"><span>'+t.label+'<small> · '+money(t.weekly)+'/sem. · avance '+money(t.signing)+
  ' · bonus victoire '+money(t.win)+' · garanti '+money(v.guaranteed)+' sur '+remaining+' journées garanties de championnat</small></span>'+
  '<button class="small dark" onclick="careerSponsorPick(\''+key+'\')" '+(S.live||S.phase!=='league'||S.round>4?'disabled':'')+'>Signer</button></div>';
 }).join(''))+
 '</section>';
}
function careerBoardPanel(){
 if(!careerIntegrated())return '';
 const c=S.careerManagement,team=club(),last=c.boardHistory[0];
 const goals=[['Victoires cette saison',CDBoardPlanning.objectiveProgress({direction:'minimum',target:8},team.won),team.won+'/8'],
  ['Trésorerie ≥ 0 €',CDBoardPlanning.objectiveProgress({direction:'minimum',target:0},team.cash),money(team.cash)],
  ['Promotions du centre',CDBoardPlanning.objectiveProgress({direction:'minimum',target:2},c.promotions),c.promotions+'/2']];
 return '<section class="card career-integration-card"><div class="cardtitle"><h2>Direction : engagements de saison</h2><span class="tag">'+S.trust+'/100 CONFIANCE</span></div>'+
 '<p class="help">Objectifs fictifs, vérifiés tous les cinq matchs de championnat. Correction de confiance plafonnée à ±2 lors du bilan, en complément de l’effet déjà lié au résultat de chaque match.</p>'+
 goals.map(([name,done,current])=>'<div class="row"><span>'+name+'</span><strong>'+current+' · '+(done.met?'Atteint':'En cours')+'</strong></div>').join('')+
 (last?'<p class="help">Dernier bilan S'+last.season+' J'+(last.round+1)+' : confiance '+last.previous+
 ' → '+last.after+'. Évaluation : résultats '+last.results+'/100, finances '+last.finances+'/100, jeunes '+last.youth+'/100.</p>':
 '<p class="help">Premier bilan après cinq rencontres de championnat.</p>')+
 '<button class="small" onclick="nav(\'finance\')">Décisions financières et sponsors</button></section>';
}
function careerAcademyPanel(){
 if(!careerIntegrated())return '';
 const c=S.careerManagement,academy=S.development.academy,remaining=Math.max(1,26-S.round);
 const ranked=CDAcademyPlanning.shortlist(academy.map(p=>({id:p.id,age:p.age,pos:p.pos,potential:p.dev.potential})));
 return '<section class="card career-integration-card"><div class="cardtitle"><h2>Budget du centre de formation</h2><span class="tag">'+money(c.academySpent)+' investis S'+S.season+'</span></div>'+
 '<p class="help">Décision hebdomadaire avant entraînement. Les fonds sont débités de la trésorerie fictive à la prochaine séance ; ils donnent un petit supplément d’expérience aux espoirs, sans relever leur potentiel maximum. Aucun effet si la trésorerie est insuffisante.</p>'+
 CAREER_ACADEMY_LEVELS.map(amount=>{
 const estimate=CDAcademyPlanning.developmentPlan({budget:Math.max(0,club().cash),weeklyInvestment:amount,weeks:remaining,academySize:academy.length});
 return '<div class="row"><span>'+({0:'Investissement nul',4000:'Accompagnement renforcé',12000:'Centre de formation prioritaire'})[amount]+
 ' · '+money(amount)+'/semaine <small> · coût maximal restant '+money(estimate.cost)+'</small></span>'+
 '<button class="small '+(c.academyInvestment===amount?'dark':'')+'" onclick="careerSetAcademyInvestment('+amount+')" '+
 (S.live||S.trained||S.phase!=='league'?'disabled':'')+'>'+
 (c.academyInvestment===amount?'Sélectionné':'Choisir')+'</button></div>';
 }).join('')+
 '<h3>Espoirs à suivre</h3>'+(ranked.slice(0,5).map(x=>{
 const p=academy.find(z=>z.id===x.id);return '<div class="row"><span>'+visualEscape(p?.name||x.id)+' · '+visualEscape(x.pos)+
 '</span><strong>'+x.potential+'/100 potentiel fictif</strong></div>';
 }).join('')||'<p>Plus aucun joueur au centre.</p>')+
 '<p class="help">Les besoins de poste réglementaires restent évalués par le système V30, notamment les spécialistes de première ligne. '+c.academyWeeks+' semaine(s) d’investissement financée(s).</p></section>';
}
function careerRecruitmentPanel(){
 if(!careerIntegrated())return '';
 const pool=managerPool();
 const seen=S.manager?.reports?.map(r=>({r,p:pool.find(p=>p.id===r.playerId)}))
  .filter(x=>x.p&&Number.isFinite(x.r.note)&&x.r.note>=0&&x.r.note<=100).slice(0,10)||[];
 if(!seen.length)return '<section class="card career-integration-card"><h2>Comparer des recrues observées</h2><p>Demandez un rapport de scouting pour comparer les coûts et les contraintes financières avant de négocier.</p><button class="small" onclick="nav(\'recruitment\')">Lancer une mission</button></section>';
 const candidates=seen.map(({r,p})=>({id:p.id,pos:p.pos,quality:r.note,weeklyWage:askingWage(p,'recruit'),
  fee:contractFee(p,'recruit')}));
 const scores=CDTransferPlanning.rankCandidates(candidates,{weeks:26});
 const cash=Math.max(0,club().cash),budget=Math.max(0,cash-300000),
  wageRoom=Math.max(0,300000-totalWages());
 return '<section class="card career-integration-card"><h2>Recrutement : capacité et comparaison</h2>'+
 '<p class="help">Uniquement joueurs déjà observés par le recruteur : note du rapport daté, salaire demandé du modèle et prime de signature. Coût sur 26 semaines et réserve de prudence de 300 000 €. Cette analyse ne remplace pas la négociation existante, qui reste la décision finale.</p>'+
 '<div class="row"><span>Enveloppe de primes après réserve de sécurité</span><strong>'+money(budget)+'</strong></div>'+
 '<div class="row"><span>Marge salariale indicative (plafond fictif 300 000 €/sem.)</span><strong>'+money(wageRoom)+'</strong></div>'+
 scores.map(row=>{
  const p=seen.find(x=>x.p.id===row.id)?.p,input=candidates.find(x=>x.id===row.id);
  const cost=CDTransferPlanning.affordability({cash,transferBudget:budget,wageRoom,
    fee:input.fee,weeklyWage:input.weeklyWage,weeks:26});
  const caution=cost.affordable?'Compatible avec l’enveloppe indicative':'Dépasse au moins une limite indicative';
  return '<div class="row"><span><strong>'+visualEscape(p?.name||row.id)+'</strong> · '+visualEscape(row.pos)+
   ' · rapport '+row.quality+'/100 <small> · prime '+money(cost.upFront)+' · salaire '+money(input.weeklyWage)+
   '/sem. · coût 26 sem. '+money(cost.total)+' · '+caution+'</small></span>'+
   '<button class="small" onclick="openContract(\''+row.id+'\')" '+(!cost.affordable||S.live?'disabled':'')+
   '>Négocier</button></div>';
 }).join('')+'</section>';
}
function careerHistoryView(){
 const c=S.careerManagement;
 return heading('PARCOURS DU MANAGER','Palmarès et décisions.', 'Les résultats et décisions confirmés restent conservés entre saisons.')+
 (!careerIntegrated()?'<section class="card"><p>Le journal intégré n’est pas actif sur cette ancienne carrière.</p><button onclick="careerEnable()">Activer le registre de carrière</button></section>':
 '<section class="card career-integration-card"><h2>Palmarès du championnat</h2>'+
 (CDCareerHistory.leaderboard(c.history).map(x=>{
 const id=Number(x.clubId.replace('club-',''));return '<div class="row"><span>'+
 visualEscape(S.clubs[id]?.name||x.clubId)+'</span><strong>'+x.count+' titre(s)</strong></div>';
 }).join('')||'<p>Les champions seront consignés à l’issue des finales futures.</p>')+
 '<h2 style="margin-top:22px">Journal persistant · '+c.history.length+' événement(s)</h2>'+
 (c.history.slice().reverse().slice(0,45).map(x=>
 '<div class="news"><small>Saison '+x.season+' · '+visualEscape(S.clubs[Number(x.clubId.slice(5))]?.abbr||x.clubId)+
 '</small><p>'+visualEscape(x.label)+'</p></div>').join('')||'<p>Les recrutements, partenariats, promotions et bilans saisonniers apparaîtront ici.</p>')+
 '</section>');
}

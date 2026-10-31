'use strict';
// Liaison V46–V50 : données de carrière réelles. V51 reste un laboratoire séparé.
// Aucun résultat sportif n'est généré ici : tous les classements viennent de S.history.
function worldActive(){return S?.worldVersion===1&&S?.worldManagement?.version===1}
function worldSetup(){
 if(!S||S.worldVersion!==1)return false;
 if(!S.worldManagement)S.worldManagement={version:1,
  clubInfo:S.clubs.map(c=>({id:c.id,reputation:clamp(Math.round(c.base),0,100),
   facilities:2,debt:0,coachConfidence:65,consecutiveLosses:0,coachChanges:0})),
  matches:[],yearbook:[],upgrades:[],awards:[],lastFinance:null,lastSeason:0,champion:null};
 return true;
}
function worldEnable(){
 if(!S||worldActive()||S.live||S.phase==='ended')return false;
 S.worldVersion=1;worldSetup();save();render();return true;
}
function worldClub(id){return worldActive()?S.worldManagement.clubInfo[id]:null}
function worldUpkeep(level){
 return Math.round(CDFacilities.maintenanceForecast({cash:0,levels:[level],weeks:1,baseWeekly:2000}).weekly);
}
function worldFacilityQuote(id){
 const info=worldClub(id),c=S.clubs[id];
 if(!info||info.facilities>=10)return null;
 const cost=450000+info.facilities*150000;
 return {cost,...CDFacilities.investment({cash:Math.max(0,c.cash-500000),level:info.facilities,
  cost,weeklyMaintenance:worldUpkeep(info.facilities+1),weeks:12})};
}
function worldUpgradeFacility(){
 if(!worldActive()||S.live||S.phase!=='league'||S.trained)return false;
 const v=S.worldManagement,i=worldClub(S.club),quote=worldFacilityQuote(S.club);
 if(!i||!quote||!quote.affordable||v.upgrades.some(x=>x.season===S.season&&x.id===S.club))return false;
 ledgerEntry('Investissement dans les installations du club',-quote.cost);
 i.facilities=quote.nextLevel;
 v.upgrades.push({season:S.season,id:S.club,level:i.facilities,cost:quote.cost});
 v.upgrades=v.upgrades.slice(-30);
 news('Installations portées au niveau '+i.facilities+'/10 pour '+money(quote.cost)+
  '. Entretien hebdomadaire : '+money(worldUpkeep(i.facilities))+'.');
 save();render();return true;
}
function worldFacilityTraining(){
 if(!worldActive())return 0;
 let improved=0;
 for(const c of S.clubs){
  const i=worldClub(c.id),bonus=Math.max(0,i.facilities-2)*.012;
  if(!bonus)continue;
  const juniors=c.id===S.club?[...c.players,...S.development.academy]:c.players;
  for(const p of juniors)if(p.age<=22&&!p.injury){
   growPlayer(p,bonus*ageGrowth(p),false);improved++;
  }
 }
 return improved;
}
function worldRecordResult(result){
 if(!worldActive()||!result||!Array.isArray(result.pair)||!Array.isArray(result.score))return false;
 const [h,a]=result.pair,match={season:S.season,round:S.round,phase:S.phase,
  home:'club-'+h,away:'club-'+a,homeScore:result.score[0],awayScore:result.score[1]};
 S.worldManagement.matches.push(match);
 S.worldManagement.matches=S.worldManagement.matches.slice(-180);
 for(let side=0;side<2;side++){
  const id=result.pair[side],info=worldClub(id);
  if(!info)continue;
  const score=result.score[side],other=result.score[1-side];
  info.consecutiveLosses=score<other?Math.min(20,info.consecutiveLosses+1):0;
 }
 return true;
}
function worldWeeklyEconomy(results){
 if(!worldActive())return false;
 const w=S.worldManagement,key=S.season+':'+S.phase+':'+S.round;
 if(w.lastFinance===key)return false;
 w.lastFinance=key;
 for(const c of S.clubs){
  const info=worldClub(c.id),upkeep=worldUpkeep(info.facilities);
  if(c.id===S.club){ledgerEntry(label()+' · Entretien des installations',-upkeep);continue}
  const home=results.find(r=>r.pair[0]===c.id);
  const own=results.find(r=>r.pair.includes(c.id));
  const won=own?own.score[own.pair.indexOf(c.id)]>own.score[1-own.pair.indexOf(c.id)]:false;
  const wage=c.players.reduce((sum,p)=>sum+p.salary,0);
  // Même barème hebdomadaire de base que le club humain ; billetterie à 360 k€ fictifs.
  c.cash+=160000-wage+(home?360000:0)+(won?80000:0)-upkeep;
 }
 return true;
}
function worldAIRecruitmentChoice(c,targets){
 if(!targets.length)return null;
 if(!worldActive())return targets[0];
 const info=worldClub(c.id),wages=c.players.reduce((n,p)=>n+p.salary,0);
 if(!info||c.cash<=300000||info.debt>=2000000)return null;
 const wageRoom=Math.max(0,Math.min(100000,300000-wages));
 const candidates=targets.filter(t=>CDReputation.recruitmentReach({
  clubReputation:info.reputation,playerReputation:clamp(Math.round(t.evidence.noteMin),0,100),tolerance:15
 })).filter(x=>x.reachable).map(t=>({id:t.p.id,pos:t.need.pos,
  fee:t.finance.fee,wage:t.p.salary,rating:clamp(Math.round(t.evidence.noteMin),0,100)}));
 const decision=CDClubAI.decideClub({cash:Math.max(0,c.cash-300000),
  wageRoom,needs:[...new Set(targets.map(t=>t.need.pos))],candidates});
 return decision.candidate?targets.find(t=>t.p.id===decision.candidate.id)||null:null;
}
function worldRecordChampion(id){
 if(!worldActive()||!Number.isInteger(id)||id<0||id>=14)return false;
 S.worldManagement.champion=id;return true;
}
function worldEndSeason(){
 if(!worldActive()||S.phase!=='ended'||S.worldManagement.lastSeason>=S.season)return false;
 const w=S.worldManagement,ranking=ranked();
 const winner=w.champion;
 const awards=CDRugbyWorld.awards(club().players.filter(p=>p.dev?.minutes>0)
  .map(p=>({id:p.id,rating:roleNote(p),minutes:p.dev.minutes,tries:0})));
 if(awards.length){
  const p=player(awards[0].id);
  w.awards.push({season:S.season,id:p.id,name:p.name});
  w.awards=w.awards.slice(-15);
  careerRecord('award','Distinction interne : '+p.name+' (note et minutes)',S.club,'world-award-'+S.season);
 }
 const standings=ranking.map((c,index)=>{
  const info=worldClub(c.id),next=CDReputation.update({
   current:info.reputation,leagueFinish:index+1,leagueSize:14,
   champion:c.id===winner,financeHealthy:c.cash>=0});
  info.reputation=next.next;
  const risk=CDCoachMarket.dismissalRisk({
   confidence:info.coachConfidence,consecutiveLosses:info.consecutiveLosses});
  if(c.id!==S.club&&risk.critical&&index>=8){
   info.coachConfidence=55;info.coachChanges++;
  }else info.coachConfidence=clamp(info.coachConfidence+(index<6?4:-3),0,100);
  return {id:c.id,position:index+1,cash:Math.round(c.cash),
   reputation:info.reputation,facilities:info.facilities,debt:Math.round(info.debt),
   coachRisk:risk.risk};
 });
 w.yearbook.push({season:S.season,champion:winner,standings});
 w.yearbook=w.yearbook.slice(-15);w.lastSeason=S.season;
 return true;
}
function worldNewSeason(){
 if(!worldActive())return false;
 const w=S.worldManagement;
 w.champion=null;w.lastFinance=null;
 for(const c of S.clubs){
  if(c.id===S.club)continue;
  const info=worldClub(c.id);
  // Une année économique couvre uniquement l'allocation d'intersaison : 4 % d'intérêt annuel.
  if(c.cash<0){info.debt+=-c.cash;c.cash=0}
  const outcome=CDFinancialRecovery.annual({cash:c.cash,debt:info.debt,wageRoom:100000},
   {revenue:2500000,baseCosts:0,repayment:Math.min(250000,info.debt)});
  c.cash=outcome.cash;info.debt=outcome.debt;
  if(info.facilities<7&&info.debt===0&&c.cash>4500000&&
   w.yearbook.at(-1)?.standings.find(x=>x.id===c.id)?.position<=7){
   const quote=worldFacilityQuote(c.id);
   if(quote?.affordable){c.cash-=quote.cost;info.facilities++;
    w.upgrades.push({season:S.season,id:c.id,level:info.facilities,cost:quote.cost});}
  }
 }
 w.upgrades=w.upgrades.slice(-30);
 return true;
}
function worldPanelActivation(){
 return '<section class="card"><h2>Vie des clubs et installations</h2>'+
 '<p class="help">Cette carrière est antérieure à la consolidation V46–V50. Aucune modification historique rétroactive : activation volontaire hors match.</p>'+
 '<button class="small" onclick="worldEnable()" '+(S.live||S.phase==='ended'?'disabled':'')+'>Activer la vie des clubs</button></section>';
}
function worldLeaguePanel(){
 if(!worldActive())return worldPanelActivation();
 const w=S.worldManagement,op=ranked().find(c=>c.id!==S.club),me=worldClub(S.club);
 const rivalry=op?CDRugbyWorld.rivalry('club-'+S.club,'club-'+op.id,w.matches):null;
 return '<section class="card"><div class="cardtitle"><h2>La vie du championnat</h2><span class="tag">V46–V50 · CLASSEMENTS RÉELS</span></div>'+
 '<p class="help">Réputation et infrastructure fictives ; positions tirées du calendrier et des résultats effectivement simulés dans la carrière. L’outil V51 est uniquement un banc d’essai hors du championnat.</p>'+
 '<div class="tablewrap"><table><thead><tr><th>CLUB</th><th>RÉPUTATION</th><th>INSTALLATIONS</th><th>TRÉSORERIE</th><th>DETTE</th></tr></thead><tbody>'+
 ranked().map(c=>{const i=worldClub(c.id);return '<tr><td>'+visualEscape(c.abbr)+'</td><td>'+
 i.reputation+'/100 · '+CDReputation.reputationTier(i.reputation)+'</td><td>'+i.facilities+
 '/10</td><td>'+money(c.cash)+'</td><td>'+money(i.debt)+'</td></tr>'}).join('')+'</tbody></table></div>'+
 (rivalry?'<p class="help">Face à '+visualEscape(op.abbr)+' sur les '+rivalry.matches+
 ' confrontation(s) conservée(s) : '+rivalry.winsA+' victoire(s), '+
 rivalry.winsB+' défaite(s), '+rivalry.draws+' nul(s).'+(rivalry.competitive?' Rivalité serrée.':'')+'</p>':'')+
 '<p class="help">Historique borné aux 180 derniers matchs de toutes les équipes. Les rétrogradations et promotions entre divisions ne sont pas simulées.</p></section>';
}
function worldFinancePanel(){
 if(!worldActive())return worldPanelActivation();
 const info=worldClub(S.club),q=worldFacilityQuote(S.club),w=S.worldManagement,
  used=w.upgrades.some(x=>x.season===S.season&&x.id===S.club);
 return '<section class="card"><h2>Investissements et entretien</h2>'+
 '<p>Installations : <strong>niveau '+info.facilities+'/10</strong> · entretien '+
 money(worldUpkeep(info.facilities))+' par semaine. Effet explicite sur la progression hebdomadaire des joueurs de 22 ans ou moins (+0,012 XP par niveau au-dessus de 2, modulé par leur âge).</p>'+
 (q?'<div class="row"><span>Projet de montée au niveau '+q.nextLevel+
 ' · coût immédiat '+money(q.cost)+' · 12 semaines d’entretien anticipées, réserve de 500 000 €</span>'+
 '<button class="small dark" onclick="worldUpgradeFacility()" '+
 (!q.affordable||used||S.trained||S.live||S.phase!=='league'?'disabled':'')+'>'+
 (used?'Déjà investi cette saison':'Investir')+'</button></div>':
 '<p>Niveau maximal atteint.</p>')+
 '<p class="help">Coûts et potentiel fictifs, un seul chantier par saison. L’IA finance les mêmes coûts d’entretien ; ses projets passent après vérification de trésorerie et de dette.</p></section>';
}
function worldOfficePanel(){
 if(!worldActive())return '';
 const info=worldClub(S.club),risk=CDCoachMarket.dismissalRisk({
  confidence:S.trust,consecutiveLosses:info.consecutiveLosses});
 const other=S.worldManagement.clubInfo.reduce((n,x)=>n+x.coachChanges,0);
 return '<section class="card"><h2>Réputation et situation du manager</h2>'+
 '<div class="row"><span>Réputation du club</span><strong>'+info.reputation+'/100</strong></div>'+
 '<div class="row"><span>Risque indicatif pour le manager</span><strong>'+risk.risk+
 '/100</strong></div><div class="row"><span>Changements de techniciens adverses consignés</span><strong>'+
 other+'</strong></div><p class="help">Risque calculé sur la confiance existante et les défaites réelles consécutives. Aucun licenciement automatique du joueur, faux entraîneur ou offre d’emploi attribuée. Marché complet des entraîneurs à intégrer ultérieurement.</p>'+
 '</section>';
}
function worldMarketPanel(){
 if(!worldActive())return '';
 const rep=worldClub(S.club).reputation;
 const rows=managerPool().slice(0,5).map(p=>{
  const observed=recruitmentEvidence(p),reach=CDReputation.recruitmentReach({
   clubReputation:rep,playerReputation:clamp(Math.round(observed.noteMin),0,100),tolerance:15});
  return '<div class="row"><span>'+visualEscape(p.name)+' · potentiel d’attraction indicatif'+
  '</span><strong>'+(reach.reachable?'Accessible selon l’estimation':'Plus difficile à convaincre')+'</strong></div>';
 }).join('');
 return '<section class="card"><h2>Attractivité et marché</h2>'+
 '<p class="help">Réputation du club : '+rep+'/100. Les fourchettes d’observation du marché, et jamais les notes cachées, alimentent cet indice. Les négociations existantes restent seules décisionnaires.</p>'+
 rows+'</section>';
}
function worldYearbookPanel(){
 if(!worldActive())return '';
 const w=S.worldManagement;
 return '<section class="card"><h2>Archives du championnat · '+w.yearbook.length+' saison(s)</h2>'+
 w.yearbook.slice().reverse().map(y=>'<div class="row"><span>Saison '+y.season+
 ' · '+visualEscape(S.clubs[y.champion]?.abbr||'Champion inconnu')+'</span><strong>'+
 y.standings.find(r=>r.id===S.club)?.position+'e · réputation '+
 y.standings.find(r=>r.id===S.club)?.reputation+'/100</strong></div>').join('')+
 (w.awards.length?'<h3>Distinctions internes</h3>'+w.awards.slice().reverse().map(x=>
 '<p>S'+x.season+' · '+visualEscape(x.name)+'</p>').join(''):'')+
 '<p class="help">Le palmarès reprend les finales vraiment disputées dans la carrière. Les récompenses internes reposent sur notes et minutes réellement enregistrées ; aucun essai individuel inventé.</p></section>';
}

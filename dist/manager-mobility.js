'use strict';
// V58 : mobilite native, volontaire et limitee a l'intersaison.
// S.club reste le seul titulaire du poste joueur. Aucun second salaire.
const MOBILITY_REASONS={offer:'La direction accepte votre candidature pour la saison suivante.',stable:'La direction souhaite conserver son technicien.',finances:'La situation financiere ne permet pas ce changement.',reputation:'Votre parcours ne correspond pas encore aux attentes de ce club.',declined:'Vous avez refuse cette offre.',cancelled:'Vous avez annule cette prise de poste.',expired:'La fenetre de cette intersaison est terminee.',completed:'Prise de poste effectuee.'};
function managerMobilityActive(){return S?.managerMobilityVersion===1&&S?.managerMobility?.version===1}
function managerMobilityWindow(){return managerMobilityActive()&&S.phase==='ended'&&!S.live}
function managerMobilityEnable(){
 if(!S||managerMobilityActive()||S.live||!worldActive()||!careerIntegrated()||!aiRosterActive())return false;
 const before=JSON.parse(JSON.stringify(S));
 try{S.managerMobilityVersion=1;S.managerMobility={version:1,originClub:S.club,enabledSeason:S.season,currentFrom:S.season,pending:null,applications:[],history:[],archives:[]};validateCareer(S)}catch(error){S=before;throw error}
 save();render();return true;
}
function managerMobilityProfile(){
 const position=ranked().findIndex(c=>c.id===S.club)+1;
 return clamp(Math.round(worldClub(S.club).reputation*.6+S.trust*.2+(15-position)/14*20),0,100);
}
function managerMobilityDecision(id){
 if(!managerMobilityWindow()||!Number.isInteger(id)||id<0||id>=S.clubs.length||id===S.club)return null;
 const c=S.clubs[id],w=worldClub(id),risk=CDCoachMarket.dismissalRisk({confidence:w.coachConfidence,consecutiveLosses:w.consecutiveLosses});
 const rank=ranked().findIndex(x=>x.id===id)+1,reputation=managerMobilityProfile(),budget=Math.max(0,c.cash-w.debt);
 // Affinite V48 reutilisee, sans inventer de remuneration ni paiement.
 const proposal=CDCoachMarket.jobOffers([{id:'club-'+id,vacant:true,budget,reputation:w.reputation}],{salary:0,reputation})[0];
 const reason=c.cash<0||w.debt>Math.max(c.cash,0)?'finances':risk.risk<35&&rank<8?'stable':reputation+15<w.reputation?'reputation':'offer';
 return {clubId:id,reason,accepted:reason==='offer',reputation,risk:risk.risk,affinity:proposal.affinity,coachChanges:w.coachChanges};
}
function managerMobilityApply(id){
 const decision=managerMobilityDecision(id),m=S?.managerMobility;
 if(!decision||m.pending||m.applications.some(a=>a.season===S.season&&a.clubId===id))return false;
 const a={id:'job-'+S.season+'-'+id,season:S.season,fromClub:S.club,clubId:id,status:decision.accepted?'offered':'rejected',reason:decision.reason,reputation:decision.reputation,risk:decision.risk,affinity:decision.affinity,coachChanges:decision.coachChanges};
 m.applications=m.applications.filter(x=>x.season>=S.season-2);m.applications.push(a);save();render();return true;
}
function managerMobilityDecline(id){
 if(!managerMobilityWindow()||S.managerMobility.pending)return false;
 const a=S.managerMobility.applications.find(x=>x.id===id&&x.season===S.season&&x.status==='offered');
 if(!a)return false;a.status='declined';a.reason='declined';save();render();return true;
}
function managerMobilityAccept(id){
 if(!managerMobilityWindow())return false;
 const m=S.managerMobility,a=m.applications.find(x=>x.id===id&&x.season===S.season&&x.status==='offered');
 if(!a||m.pending)return false;
 const decision=managerMobilityDecision(a.clubId);if(!decision?.accepted)return false;
 a.status='accepted';m.pending={offerId:a.id,fromClub:S.club,toClub:a.clubId,season:S.season,coachChanges:decision.coachChanges};
 for(const other of m.applications)if(other!==a&&other.status==='offered'){other.status='declined';other.reason='declined'}
 modal=null;save();render();return true;
}
function managerMobilityCancel(){
 if(!managerMobilityWindow()||!S.managerMobility.pending)return false;
 const m=S.managerMobility,a=m.applications.find(x=>x.id===m.pending.offerId);
 a.status='cancelled';a.reason='cancelled';m.pending=null;save();render();return true;
}
function managerMobilityConfirm(id){
 if(!managerMobilityWindow())return false;
 const a=S.managerMobility.applications.find(x=>x.id===id&&x.status==='offered');if(!a)return false;
 modal='<div class="modalback"><section class="modal" role="dialog" aria-modal="true" aria-label="Changer de club">'+
 '<h2>Rejoindre '+visualEscape(S.clubs[a.clubId].name)+' ?</h2>'+
 '<p>La prise de poste intervient au passage a la saison suivante. Les joueurs, espoirs, budgets et installations restent dans leurs clubs. Vous ne transfererez ni argent ni joueur.</p>'+
 '<p>Le bilan de la saison actuelle reste celui de votre club de depart. Vos dossiers de recrutement actifs sont clos lors du changement de bureau. Aucun salaire de manager ni indemnite ne sont factures dans cette premiere version.</p>'+
 '<div class="row"><button onclick="closeModal()">Rester sur cette page</button><button class="primary" onclick="managerMobilityAccept(\''+a.id+'\')">Confirmer la prise de poste</button></div></section></div>';
 render();return true;
}
function managerMobilityOnSeasonStart(){
 if(!managerMobilityActive())return false;
 const m=S.managerMobility,p=m.pending;
 for(const a of m.applications)if(a.status==='offered'&&a.season<S.season){a.status='expired';a.reason='expired'}
 if(!p){m.applications=m.applications.filter(a=>a.season>=S.season-2);return false}
 if(p.season+1!==S.season||p.fromClub!==S.club||p.toClub===S.club||S.phase!=='league'||S.round!==0||S.live)throw Error('Transition de poste incoherente.');
 const target=S.aiRoster.academies.find(a=>a.clubId===p.toClub);if(!target)throw Error('Centre de formation du nouveau club introuvable.');
 // APRES les comptes, contrats et promotions natifs. Aucun mouvement d'argent ou de professionnel.
 const oldId=S.club,archive=m.archives.find(a=>a.clubId===p.toClub);
 const departed={clubId:oldId,season:S.season,ledger:JSON.parse(JSON.stringify(S.ledger)),boardHistory:JSON.parse(JSON.stringify(S.careerManagement.boardHistory)),academyInvestment:S.careerManagement.academyInvestment};
 m.archives=m.archives.filter(a=>a.clubId!==oldId);m.archives.push(departed);
 const oldAcademy=S.development.academy;S.development.academy=target.players;target.players=oldAcademy;target.clubId=oldId;target.intakeSeason=S.season;S.development.intakeSeason=S.season;
 S.clubs[oldId].morale=S.morale;S.club=p.toClub;S.morale=clamp(S.clubs[S.club].morale??75,0,100);S.trust=60;
 S.ledger=archive?JSON.parse(JSON.stringify(archive.ledger)):[];
 S.careerManagement.boardHistory=archive?JSON.parse(JSON.stringify(archive.boardHistory)):[];
 S.careerManagement.academyInvestment=archive?.academyInvestment??0;
 // Les journaux globaux du marche et des transferts restent conserves.
 S.economy.talks={};S.economy.listings={};S.economy.offers=[];S.economy.objectives=[];S.economy.objectiveHistory=[];
 if(S.economy.relationLog)S.economy.relationLog=[];if(S.economy.moodLog)S.economy.moodLog=[];
 delete S.manager;setupManager();delete S.v39;v39Initialize();
 S.tactic='equilibre';S.training='normal';S.collectiveFocus='aucune';S.lastReport=null;S.lineup=[];S.reserves=[];
 // V48 reste proprietaire des compteurs de techniciens. Ne pas recompter son remplacement annuel.
 worldClub(oldId).coachConfidence=55;worldClub(oldId).coachChanges++;
 const info=worldClub(S.club);info.coachChanges=Math.max(info.coachChanges,p.coachChanges+1);info.coachConfidence=60;info.consecutiveLosses=0;
 m.history.push({fromClub:oldId,toClub:S.club,departureSeason:p.season,arrivalSeason:S.season,offerId:p.offerId});m.history=m.history.slice(-30);m.currentFrom=S.season;
 const accepted=m.applications.find(a=>a.id===p.offerId);accepted.status='completed';accepted.reason='completed';m.pending=null;m.applications=m.applications.filter(a=>a.season>=S.season-2);
 autoLineup();club().players.forEach(ensureSatisfaction);careerRecord('manager','Prise de poste a '+club().abbr,S.club,'mobilite');
 news('Vous rejoignez '+club().name+'. Les comptes, effectifs et espoirs de chaque club sont conserves.');return true;
}
function validateManagerMobility(s){
 if(s.managerMobilityVersion===undefined&&s.managerMobility===undefined)return;
 const m=s.managerMobility;
 saveCheck(s.managerMobilityVersion===1&&s.worldVersion===1&&s.integratedManagementVersion===1&&s.aiRosterVersion===1&&saveObject(m)&&m.version===1&&saveInt(m.originClub,0,13)&&saveInt(m.enabledSeason,1,s.season)&&saveInt(m.currentFrom,m.enabledSeason,s.season)&&saveArray(m.applications,39)&&saveArray(m.history,30)&&saveArray(m.archives,14));
 const ids=new Set(),keys=new Set();
 for(const a of m.applications){
  saveCheck(saveObject(a)&&saveId(a.id)&&a.id==='job-'+a.season+'-'+a.clubId&&saveInt(a.season,Math.max(m.enabledSeason,s.season-2),s.season)&&saveInt(a.fromClub,0,13)&&saveInt(a.clubId,0,13)&&a.clubId!==a.fromClub&&!ids.has(a.id)&&['offered','rejected','declined','accepted','cancelled','expired','completed'].includes(a.status)&&Object.prototype.hasOwnProperty.call(MOBILITY_REASONS,a.reason)&&saveInt(a.reputation,0,100)&&saveInt(a.risk,0,100)&&saveInt(a.affinity,0,100)&&saveInt(a.coachChanges,0,10000));
  if(['offered','accepted'].includes(a.status))saveCheck(a.season===s.season&&a.fromClub===s.club&&a.reason==='offer');
  if(a.status==='rejected')saveCheck(['stable','finances','reputation'].includes(a.reason));
  if(['declined','cancelled','expired','completed'].includes(a.status))saveCheck(a.reason===a.status);ids.add(a.id);
 }
 const accepted=m.applications.filter(a=>a.status==='accepted');
 if(m.pending===null)saveCheck(accepted.length===0);
 else{const p=m.pending;saveCheck(saveObject(p)&&s.phase==='ended'&&!s.live&&p.season===s.season&&p.fromClub===s.club&&saveInt(p.toClub,0,13)&&p.toClub!==s.club&&saveInt(p.coachChanges,0,10000)&&accepted.length===1&&accepted[0].id===p.offerId&&accepted[0].clubId===p.toClub)}
 let last=null;
 for(const h of m.history){saveCheck(saveObject(h)&&saveInt(h.fromClub,0,13)&&saveInt(h.toClub,0,13)&&h.toClub!==h.fromClub&&saveInt(h.departureSeason,m.enabledSeason,s.season-1)&&h.arrivalSeason===h.departureSeason+1&&h.offerId==='job-'+h.departureSeason+'-'+h.toClub&&(!last||h.departureSeason>=last.arrivalSeason&&h.fromClub===last.toClub));last=h}
 if(last)saveCheck(last.toClub===s.club&&last.arrivalSeason===m.currentFrom);else saveCheck(s.club===m.originClub&&m.currentFrom===m.enabledSeason);
 for(const a of m.archives){
  saveCheck(saveObject(a)&&saveInt(a.clubId,0,13)&&!keys.has(a.clubId)&&saveInt(a.season,m.enabledSeason,s.season)&&CAREER_ACADEMY_LEVELS.includes(a.academyInvestment)&&saveArray(a.ledger,100)&&saveArray(a.boardHistory,24));keys.add(a.clubId);
  for(const x of a.ledger)saveCheck(saveObject(x)&&typeof x.title==='string'&&saveNumber(x.amount));
  for(const x of a.boardHistory)saveCheck(saveObject(x)&&saveInt(x.season,1,s.season)&&saveInt(x.round,0,26)&&['previous','after','results','finances','youth','score'].every(k=>saveInt(x[k],0,100)));
 }
}
function managerMobilityPanel(){
 if(!S)return '';
 if(!managerMobilityActive())return '<section class="card"><h2>Carriere du manager</h2><p>Activez les candidatures volontaires et la mobilite entre clubs a l\'intersaison. Aucun changement automatique de club ni nouveau salaire.</p><button class="small dark" onclick="managerMobilityEnable()" '+(!worldActive()||!careerIntegrated()||!aiRosterActive()||S.live?'disabled':'')+'>Activer la mobilite</button><p class="help">Necessite les systemes carriere, monde et effectifs IA deja integres. Activation facultative, compatible avec les anciennes carrieres.</p></section>';
 const m=S.managerMobility;
 const rows=managerMobilityWindow()?CDCoachOpportunities.snapshot(S.clubs,S.worldManagement.clubInfo,S.club).map(c=>{
  const a=m.applications.find(x=>x.season===S.season&&x.clubId===c.id);
  return '<div class="row"><span>'+visualEscape(c.name)+' <small>Risque V48 : '+c.risk+'/100</small></span>'+(a?'<span>'+visualEscape(MOBILITY_REASONS[a.reason])+'</span>'+(a.status==='offered'&&!m.pending?'<button onclick="managerMobilityConfirm(\''+a.id+'\')">Examiner l\'offre</button><button onclick="managerMobilityDecline(\''+a.id+'\')">Refuser</button>':''):'<button onclick="managerMobilityApply('+c.id+')" '+(m.pending?'disabled':'')+'>Candidater</button>')+'</div>';
 }).join(''):'<p>Les candidatures ouvrent apres la finale, avant le passage a la saison suivante. Un risque eleve ne constitue pas a lui seul un poste vacant.</p>';
 return '<section class="card"><h2>Votre parcours de manager</h2>'+(m.pending?'<div class="notice">Prise de poste prevue a '+visualEscape(S.clubs[m.pending.toClub].name)+' en saison '+(S.season+1)+' au lancement de la prochaine saison. <button onclick="managerMobilityCancel()">Annuler</button></div>':'')+rows+'<p class="help">Decisions de simulation fondees sur le classement reel, la reputation, la confiance et les finances. Pas de garantie de recrutement. Les sommes et joueurs ne suivent jamais le manager.</p><h3>Clubs entraines</h3>'+(m.history.length?m.history.slice().reverse().map(h=>'<p>Saison '+h.arrivalSeason+' : '+visualEscape(S.clubs[h.fromClub].name)+' vers '+visualEscape(S.clubs[h.toClub].name)+'</p>').join(''):'<p>Premier mandat dans cette carriere.</p>')+'</section>';
}

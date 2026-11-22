'use strict';
// Executed in the headless engine context; helpers only receive player copies.
// No presentation identity is ever written into the career/save.
module.exports=function nativeModel(){
 const presentation=c=>c?{id:c.id,slug:c.slug,city:c.city,name:c.name,abbr:c.abbr,color:c.color,stadium:c.stadium,cityImage:c.cityImage,stadiumImage:c.stadiumImage}:null;
 const catalogue=CDFranceClubs.clubs.map(c=>({...presentation(c),division:c.division,playable:true,goal:c.goal,base:c.base,cashMillions:c.cashMillions}));
 const france=!!S&&CDFranceCompetition.active(S);
 const meta={prototype:true,rosterFoundation:S?.rosterFoundation??null,rosterSources:CDRosterFoundation.resolve(S?.rosterFoundation)?.sources??{},hasCareer:!!S,week:france?S.franceMode.week:S?.round??0,roundLabel:S?label():'',canAdvanceSeason:S?.phase==='ended'&&!S?.live,mode:S?.commonDatabase?'common':france?'france30':'fictional14',database:{id:CDCommonRosters.id,version:CDCommonRosters.version,snapshot:CDCommonRosters.snapshot,ratingsVersion:CDCommonRosters.ratingsVersion,playerCount:CDCommonRosters.playerCount,clubCount:CDCommonRosters.clubCount,active:!!S?.commonDatabase},engine:france?'native-rugby':'historical',leagueId:france?CDFranceCompetition.leagueId(S):'elite',competitionRules:france?'Format professionnel français 2026–2027 ; cadence fictive de 34 semaines, monde fermé sans Nationale.':null,dataDir:nativeDataDirectory,saveError:lastSaveError,catalogue,season:S?.season??null,round:S?.round??null,phase:S?.phase??null,trained:S?.trained??false,training:S?.training??null,morale:S?.morale??null,trust:S?.trust??null,rulesProfile:'XV adulte professionnel français 2025–2026 — abstractions du moteur historique'};
 if(S){const active=typeof aiRosterPopulationActive==='function'&&aiRosterPopulationActive(S);meta.population={version:S.aiRosterVersion??null,active,canEnable:typeof enablePopulationPolicy==='function'&&typeof aiRosterActive==='function'&&aiRosterActive()&&!active&&!S.live&&S.phase==='league'&&!Object.keys(S.economy?.talks||{}).length,requiresConfirmation:true,referenceAccessible:S.aiRoster?.population?.referenceAccessible??null,knownAccessible:typeof aiRosterAccessibleCount==='function'?aiRosterAccessibleCount(S):null,history:JSON.parse(JSON.stringify(S.aiRoster?.population?.history||[]))};}
 if(!S)return {protocol:1,club:null,league:[],squad:[],next:null,history:[],messages:[],ledger:[],live:null,meta};
 const sorted=ranked(),divisionRankings=france?Object.fromEntries(['elite','accession'].map(id=>[id,CDFranceCompetition.ranked(S,id)])):null;
 const summary=c=>({id:c.id,name:c.name,abbr:c.abbr,color:c.color,stadium:c.stadium,cash:c.cash,goal:c.goal,points:c.points-(france&&typeof CDJiff!=='undefined'?CDJiff.deduction(S,c.id):0),rank:rankedFor(c).findIndex(x=>x.id===c.id)+1,presentation:presentation(S.customCompetition?c:CDFranceClubs.forCareer(S,c.id))});
 const own=club();
 const withdrawnReason='Négociation close jusqu’à la prochaine journée.';
 const currentNegotiation=(id,kind)=>{
  const talk=S.economy?.talks?.[talkKey(id,kind)];
  if(talk?.status==='counter')return {status:talk.status,salary:talk.acceptedSalary,years:talk.years,attempts:talk.attempts};
  if(talk?.status==='withdrawn')return {status:talk.status};
  return null;
 };
 // Read-only ID projection; final order is stored, historical points are not.
 const archives={limit:15,seasons:(france?S.franceMode.yearbook:[]).slice(-15).map(y=>({season:y.season,champions:['elite','accession'].map((leagueId,i)=>({leagueId,clubId:y.champions[i]})),standings:Object.fromEntries(['elite','accession'].map(id=>[id,y.standings[id].slice()])),movement:{promoted:y.movement.promoted.slice(),relegated:y.movement.relegated.slice()}}))};
 const rankedFor=c=>france?divisionRankings[CDFranceCompetition.leagueId(S,c.id)]:sorted;
 // Vente de joueurs (vente-joueurs.cjs) : état de vente de chaque joueur (squad[].sale) ; prêts calculés une fois.
 const venteLoansVue=typeof venteVueJoueur==='function'&&S.economy?venteLoans():null;
 // Temps de jeu au contrat (idée FM 16, planche du 22/11/2026). Rôle promis : `p.roleContrat` {role, saison}, posé à la
 // signature ou à la prolongation (gestion.cjs, champ `role` de recruit / extend_contract). Sans rôle enregistré (contrats
 // antérieurs) : rôle de départ déduit de la hiérarchie au poste (rang de note dans l'effectif, places du XV au poste).
 // Satisfaction : les 10 derniers matchs du club (S.matchNotes.detail, saison en cours), un état par match :
 // tenu / manque / neutre (Espoir et Appoint : un match sans jouer est neutre ; Espoir : 4 d'affilée = manqué).
 const tempsJeu=(()=>{
  const SEUIL={titulaire:50,rotation:20,espoir:1,appoint:1};
  const detail=S.matchNotes?.detail||{},cles=new Map();
  for(const q of own.players)for(const r of detail[q.id]||[]){const k=r[0]+':'+r[1];if(!cles.has(k))cles.set(k,[r[0],r[1]]);}
  const matchs=[...cles.values()].sort((a,b)=>a[0]-b[0]).slice(-10);
  const parPoste={},places={};
  for(const q of own.players)(parPoste[q.pos]??=[]).push(q);
  for(const id of S.lineup){const q=own.players.find(x=>x.id===id);if(q)places[q.pos]=(places[q.pos]||0)+1;}
  const deduit=p=>{const rang=(parPoste[p.pos]||[p]).slice().sort((a,b)=>(b.rating??0)-(a.rating??0)).findIndex(x=>x.id===p.id),n=Math.max(1,places[p.pos]||1);
   return rang<n?'titulaire':rang<2*n?'rotation':p.age<=21?'espoir':'appoint';};
  return p=>{
   const fixe=p.roleContrat&&SEUIL[p.roleContrat.role]?p.roleContrat:null,role=fixe?fixe.role:deduit(p),lignes=detail[p.id]||[];
   let sec=0;
   const pastilles=matchs.map(([semaine,adv])=>{const r=lignes.find(x=>x[0]===semaine&&x[1]===adv),minutes=r?r[3]:0;sec=minutes>0?0:sec+1;
    const etat=role==='titulaire'||role==='rotation'?(minutes>=SEUIL[role]?'tenu':'manque'):minutes>0?'tenu':role==='espoir'&&sec>=4?'manque':'neutre';
    return {semaine,adversaireId:adv,adversaire:S.clubs[adv]?.name||'',minutes,note:r?r[4]/10:null,etat};});
   const tenus=pastilles.filter(x=>x.etat==='tenu').length,manques=pastilles.filter(x=>x.etat==='manque').length,comptes=tenus+manques;
   const humeur=comptes===0?'neutre':tenus/comptes>=.7?'content':tenus/comptes>=.4?'attentif':'mecontent';
   return {role,fixe:!!fixe,saison:fixe?fixe.saison:null,seuil:SEUIL[role],pastilles,tenus,manques,humeur};
  };
 })();
 const squad=own.players.map(source=>{
  const p=JSON.parse(JSON.stringify(source)),index=S.lineup.indexOf(p.id),bench=S.reserves.indexOf(p.id);
  let hash=2166136261;for(const ch of p.id){hash^=ch.charCodeAt(0);hash=Math.imul(hash,16777619);}const nativeId=/^p\d+-(\d+)-\d+$/.exec(p.id);
  const negotiation=currentNegotiation(p.id,'renew'),withdrawn=negotiation?.status==='withdrawn';
  // Pré-contrat signé ailleurs (calendrier-mutations.cjs) : plus de prolongation possible.
  const parti=typeof preContratRefusProlongation==='function'?preContratRefusProlongation(p.id):'';
  const renewal={available:!S.live&&!withdrawn&&!parti&&p.contractEnd<contractBase()+2&&careerContractYears(p)>=Math.max(1,p.contractEnd-contractBase()+2),
   salary:askingWage(p,'renew'),fee:contractFee(p,'renew'),minYears:Math.max(1,p.contractEnd-contractBase()+2),maxYears:Math.min(3,careerContractYears(p)),
   ...(negotiation?{negotiation}:{}),...(withdrawn?{reason:withdrawnReason}:parti?{reason:parti}:{})};
  return {...(p.appearanceBankVersion===undefined?{}:{appearanceBankVersion:p.appearanceBankVersion}),...(p.appearanceId===undefined?{}:{appearanceId:p.appearanceId}),rosterProfile:p.rosterProfile??null,...(p.espoirLoan?{calledUp:true}:{}),id:p.id,name:p.name,pos:p.pos,fam:p.fam,age:p.age,rating:p.rating,note:roleNote(p),potential:potentialAtRole(p),condition:p.condition,physicalLoad:physicalLoadValue(p),loadPlan:physicalPlan(p),injury:p.injury,...(typeof valeurFragilite==='function'?{fragilite:valeurFragilite(p),risqueBlessure:Math.round((p.condition<55?7:2.5)*facteurFragilite(p)*10)/10}:{}),...(p.injury>0?{rechute:Number.isFinite(p.injuryRelapse)?Math.max(0,Math.min(100,Math.round(p.injuryRelapse*(typeof facteurFragilite==='function'?facteurFragilite(p):1)))):0}:{}),...(p.injury>0&&p.injuryType?{injuryType:p.injuryType,...(p.injuryCause?{injuryCause:p.injuryCause}:{}),...(p.injuryDate?{injuryDate:p.injuryDate}:{})}:{}),...(p.commotion?{commotion:{n:p.commotion.n,derniere:p.commotion.hist[p.commotion.hist.length-1].date,retour:p.commotion.protocole?.retour??p.commotion.hist[p.commotion.hist.length-1].retour,enCours:!!p.commotion.protocole}}:{}),salary:p.salary,marketValue:typeof transferValue==='function'?Math.round(transferValue(JSON.parse(JSON.stringify(source)))):null,contractEnd:p.contractEnd??null,tempsJeu:tempsJeu(p),renewal,contractLabel:p.espoirLoan?'Appelé du centre de formation':p.contractEnd==null?'Sans contrat professionnel':contractLabel(p),minutes:p.dev?.minutes??0,appearances:p.dev?.appearances??0,status:p.injury?'Blessé':index>=0?'Titulaire':bench>=0?'Remplaçant':'Hors groupe',shirtNumber:index>=0?index+1:bench>=0?bench+16:null,...nativePlayerAttributes(p),attributes:Object.fromEntries(Object.keys(ATTR).map(k=>[k,skill(p,k)])),portraitIndex:nativeId?Number(nativeId[1])%32:(hash>>>0)%32,...(venteLoansVue?{sale:venteVueJoueur(source,venteLoansVue)}:{}),...(typeof preContratVueJoueur==='function'?preContratVueJoueur(source):{})};
 });
 const places=professionalPlaces(own),cash=own.cash;
 // Budget de transferts (budget-transferts.cjs) : contexte calculé une fois pour tous les devis ; null hors budget de saison.
 const transferBudget=typeof budgetTransfertsContexte==='function'?budgetTransfertsContexte():null;
 // Statut JIFF / EQP de la piste pour le club du manager (null hors championnat à quota).
 const quotaBadge=p=>typeof CDJiff!=='undefined'&&CDJiff&&typeof CDJiff.marketBadge==='function'&&S.jiff?.version===1?CDJiff.marketBadge(S,p):null;
 const calendrierFerme=typeof calendrierRefusRecrue==='function'?calendrierRefusRecrue():'';
 // Forme récente (5 dernières notes de match, adversaire et score : match-notes.cjs), null sans match noté.
 const formeRecente=id=>typeof CDMatchNotes!=='undefined'&&CDMatchNotes&&typeof CDMatchNotes.formeJoueur==='function'?CDMatchNotes.formeJoueur(id):null;
 // Prêt d'une piste du marché (rapport du recruteur, 22/11/2026) : son club le prêterait s'il a 23 ans ou moins
 // (« jeune ») ou s'il n'entre pas dans les 23 meilleures notes de son club (« hors des 23 ») ; sinon il compte
 // dans le groupe de son club (« cadre »). Piste sans club identifié : seul l'âge compte. Information seulement :
 // aucune commande de prêt entrant n'existe dans l'offre au joueur.
 const pretPiste=p=>{
  if(Number.isFinite(p.age)&&p.age<=23)return {possible:true,reason:'jeune'};
  const ci=p.population?.clubId,c=Number.isInteger(ci)?S.clubs[ci]:null;
  if(c&&Array.isArray(c.players)&&Number.isFinite(p.rating)){
   const meilleurs=c.players.filter(x=>x.id!==p.id&&Number.isFinite(x.rating)&&x.rating>p.rating).length;
   if(meilleurs>=23)return {possible:true,reason:'hors-23'};
  }
  return {possible:false,reason:'cadre'};
 };
 const market=S.market.map(source=>{
  const p=JSON.parse(JSON.stringify(source));
  const negotiation=currentNegotiation(p.id,'recruit'),maxYears=Math.min(3,careerContractYears(p));
  const withdrawn=negotiation?.status==='withdrawn';
  const fee=contractFee(p,'recruit'),horsBudget=transferBudget?budgetTransfertsRefus(fee,transferBudget):null;
  // Calendrier du recrutement (calendrier-mutations.cjs) : raison écrite avec la date de réouverture.
  const reason=S.live?'Match en cours':calendrierFerme?calendrierFerme:places<=0?'Effectif complet':cash<p.price?'Trésorerie insuffisante':horsBudget?horsBudget:maxYears<1?'Retraite prévue':withdrawn?withdrawnReason:'';
  const available=!S.live&&!calendrierFerme&&places>0&&cash>=p.price&&!horsBudget&&maxYears>=1&&!withdrawn;
  return {...(p.appearanceBankVersion===undefined?{}:{appearanceBankVersion:p.appearanceBankVersion}),...(p.appearanceId===undefined?{}:{appearanceId:p.appearanceId}),id:p.id,name:p.name,pos:p.pos,age:p.age,rating:p.rating,...nativePlayerAttributes(p),
   salary:askingWage(p,'recruit'),fee,minYears:1,maxYears,available,reason,loan:pretPiste(p),...(negotiation?{negotiation}:{}),...(quotaBadge(p)?{quota:quotaBadge(p)}:{}),...(formeRecente(p.id)?{formeRecente:formeRecente(p.id)}:{})};
 });
 const pair=nextMatch(),l=S.live;
 // Météo vue par le manager : libellé, conseil du staff (sans la phrase du vent, composée par l'écran avec
 // les noms affichés) et camp qui a le vent dans le dos à chaque période ([1re, 2e]), null sans vent orienté.
 const liveMeteo=l=>{if(typeof meteoLibelle!=='function')return null;const actif=meteoActive(l),m=actif?l.meteo:{};
  return {libelle:meteoLibelle(l),conseil:actif?meteoConseilBase(l,m):null,pluie:m.pluie||0,vent:m.vent||0,chaleur:m.chaleur||0,terrain:m.terrain||null,
   ventDos:ventSensActif(l)?[l.meteo.sens,1-l.meteo.sens]:null};};
 // Météo annoncée la veille du prochain match du club (world-career.cjs), même format que `live.meteo` : la
 // rencontre fictive porte les mêmes versions de règles que celle du coup d'envoi. null avant la veille.
 const nextMeteo=()=>{try{const m=typeof CDWorldCareer!=='undefined'&&typeof CDWorldCareer.meteoAnnoncee==='function'?CDWorldCareer.meteoAnnoncee(S):null;if(!m||!pair||typeof WEATHER_RULES==='undefined')return null;
  const f={pair,weather:m.weather,...(WEATHER_RULES?{weatherVersion:1,meteo:{pluie:m.pluie,vent:m.vent,chaleur:m.chaleur,terrain:m.terrain,sens:m.sens},...(typeof WIND_DIRECTION_RULES!=='undefined'&&WIND_DIRECTION_RULES?{windVersion:1}:{})}:{})};
  return {...liveMeteo(f),date:m.date};}catch(e){return null;}};
 const fixture=france?CDFranceCompetition.userFixture(S):null;
 const errors=sheetErrors(),all=[...S.lineup,...S.reserves];
 const selection={valid:errors.length===0,errors,slots:all.map((playerId,slot)=>({
  slot,
  ...(typeof nativePositionAptitudes==='undefined'?{}:{positionNumber:nativePositionAptitudes.positionNumber(slot)}),
  label:slot<15?POS[slot]:BENCH_LABELS[slot-15],
  playerId,
  eligibleIds:own.players.filter(p=>!p.injury&&(slot<15?slotEligible(p,slot):benchEligible(p,slot-15))).map(p=>p.id)
 }))};
 // Alerte de fatigue (Gabi) : titulaires de la feuille du prochain match sous 70 % de condition et remplaçants frais.
 if(!errors.length&&!l&&pair&&S.phase!=='ended'&&typeof nativePositionAptitudes!=='undefined'){const advice=nativePositionAptitudes.fatigueAdvice(own,S.lineup,S.reserves,70);if(advice)selection.fatigue=advice;}
 // Alerte de quota (Gabi) : JIFF (Top 14, Pro D2) ou EQP (Premiership) sous la trajectoire de la moyenne exigée.
 if(!errors.length&&!l&&pair&&S.phase==='league'&&typeof nativePositionAptitudes!=='undefined'&&typeof nativePositionAptitudes.quotaAdvice==='function'){const advice=nativePositionAptitudes.quotaAdvice(own,S.lineup,S.reserves);if(advice)selection.quota=advice;}
 // Avis du staff sur la feuille (match-actions.js, lot 3) : postes où il composerait autrement, avec sa raison.
 if(!errors.length&&!l&&pair&&typeof staffSheetAdvice==='function'){const avis=staffSheetAdvice();if(avis)selection.staffAdvice=avis;}
 if(errors.length&&!l&&S.phase!=='ended'){
  const team={...own,players:own.players.map(p=>({...p}))};
  const sheet=buildSheet(team,S.lineup,S.reserves);
  const slots=vacantMatchSlots(sheet.lineup,sheet.bench);
  if(slots.length){
   const places=professionalPlaces(own);
   const coverSalary=typeof budgetActif==='function'&&budgetActif()?budgetPlancherHebdo():COVER_WEEKLY_SALARY,quote={slots,places,weeklySalary:coverSalary,totalWeeklySalary:slots.length*coverSalary};
   if(!S.trained&&team.players.some(p=>p.injury===1)){
    const recovered={...team,players:team.players.map(p=>p.injury===1?{...p,injury:0}:p)};
    const after=buildSheet(recovered,S.lineup,S.reserves);
    if(vacantMatchSlots(after.lineup,after.bench).length<slots.length)quote.reviewAfterTraining=true;
   }
   selection.coverage=quote;
  }
 }
 // Feuille incomplète : jeune du centre proposé pour chaque place vide (espoirs-match.cjs), à côté du match à 22.
 if(errors.length&&!l&&S.phase!=='ended'&&typeof nativeSystems!=='undefined'){const espoirs=nativeSystems.domain('espoirsMatch')?.offers(S);if(espoirs)selection.espoirs=espoirs;}
 const tactics={attack:S.tactic,defense:S.defence||'equilibre',attacks:Object.entries(TACTICS).map(([id,[label,description]])=>({id,label,description})),defenses:Object.entries(DEFENCES).map(([id,[label,description]])=>({id,label,description})),penalty:S.live&&S.live.userSide>=0?(S.live.penaltyPolicies?.[S.live.userSide]||'auto'):'auto',penalties:Object.entries(PENALTY_POLICIES).map(([id,label])=>({id,label})),...(typeof playerRolesView==='function'?{roles:playerRolesView()}:{})};
 const row=c=>({...summary(c),played:c.played,won:c.won,drawn:c.drawn,lost:c.lost,pf:c.pf,pa:c.pa,bonus:c.bonus,form:c.form});
 const leagues=france?['elite','accession'].map(id=>({id,name:id==='elite'?'Élite — 14 clubs':'Accession — 16 clubs',phase:S.franceMode.leagues[id].phase,champion:S.franceMode.leagues[id].champion===null?null:summary(S.clubs[S.franceMode.leagues[id].champion]),finalist:S.franceMode.leagues[id].finalist===null?null:summary(S.clubs[S.franceMode.leagues[id].finalist]),rows:divisionRankings[id].map(row)})):[{id:'elite',name:'Ligue Première',rows:sorted.map(row)}];
 const leagueId=france?CDFranceCompetition.leagueId(S):'elite';
 const calendar=S.schedule.flatMap((pairs,r)=>pairs.filter(p=>p.includes(S.club)).map(p=>{const result=S.history.find(x=>x.phase==='league'&&x.round===r&&x.pair[0]===p[0]&&x.pair[1]===p[1]);return {id:result?.fixtureId||'calendar-'+r,label:'Journée '+(r+1),week:france?CDFranceCompetition.regularWeek(leagueId,r):r,home:summary(S.clubs[p[0]]),away:summary(S.clubs[p[1]]),score:result?.score||null,played:!!result,phase:'league',leagueId,neutral:false};}));
 for(const r of S.history.filter(x=>x.phase!=='league'&&x.pair.includes(S.club)))calendar.push({id:r.fixtureId||r.phase,label:r.phase,week:r.week??S.round,home:summary(S.clubs[r.pair[0]]),away:summary(S.clubs[r.pair[1]]),score:r.score,played:true,phase:r.phase,leagueId:r.leagueId||leagueId,neutral:r.neutral??['semi','final'].includes(r.phase)});
 if(fixture&&fixture.phase!=='league')calendar.push({id:fixture.fixtureId,label:label(),week:fixture.week,home:summary(S.clubs[fixture.pair[0]]),away:summary(S.clubs[fixture.pair[1]]),score:null,played:false,phase:fixture.phase,leagueId:fixture.leagueId,neutral:fixture.neutral});
 const resultDecision=l?.finished?(()=>{const winner=l.winner??(l.score[0]===l.score[1]?null:l.pair[l.score[0]>l.score[1]?0:1]),kind=l.decision?.method||(winner===null?'draw':'score'),reason={tries:'au nombre d’essais',penalties:'au nombre de pénalités réussies',drops:'au nombre de drops',redCards:'au nombre d’exclusions',shootout:'aux tirs au but'}[kind];return {...(l.decision||{}),kind,winner,label:winner===null?'Match nul.':(reason?'Qualification de ':'Victoire de ')+S.clubs[winner].name+(reason?' '+reason:'')+'.'};})():null;
 const livePlayer=id=>{const p=own.players.find(x=>x.id===id);return p?{...(p.appearanceBankVersion===undefined?{}:{appearanceBankVersion:p.appearanceBankVersion}),...(p.appearanceId===undefined?{}:{appearanceId:p.appearanceId}),id:p.id,name:p.name,pos:p.pos,condition:p.condition,injury:p.injury,rating:p.rating}:null;};
 let statsRows=[];
 if(l){const [a,b]=l.stats,total=a.possession+b.possession;statsRows=[
  ['Possession',total?Math.round(a.possession/total*100)+'%':'—',total?Math.round(b.possession/total*100)+'%':'—'],
  ['Territoire',total?Math.round(a.territory/total)+'%':'—',total?Math.round(b.territory/total)+'%':'—'],
  ['Mêlées conservées',a.scrumsWon+' / '+a.scrums,b.scrumsWon+' / '+b.scrums],
  ...(l.uncontestedScrums?.some(count=>count>0)?[['Dont non disputées',...l.uncontestedScrums]]:[]),
  // Arbitrage fin (dist/arbitrage.js) : sous le compte, une ligne courte par équipe (lancers pas droits ; pénalités par famille).
  ['Touches conservées',a.lineoutsWon+' / '+a.lineouts,b.lineoutsWon+' / '+b.lineouts,a.lineoutNotStraight||b.lineoutNotStraight?l.pair.map((ci,s)=>{const n=l.stats[s].lineoutNotStraight||0;return S.clubs[ci].abbr+' · '+(n?n+' lancer'+(n>1?'s':'')+' pas droit'+(n>1?'s':''):'aucun lancer pas droit')}):null],
  ['Pénalités concédées',a.penalties,b.penalties,typeof arbitrageResume==='function'&&a.penaltyFamilies&&b.penaltyFamilies?l.pair.map((ci,s)=>S.clubs[ci].abbr+' · '+arbitrageResume(l.stats[s])):null],['Cartons jaunes',a.yellows,b.yellows],
  ['Tirs de pénalité',a.goals+' / '+a.goalAttempts,b.goals+' / '+b.goalAttempts],
  ['Transformations',a.conversions+' / '+a.conversionAttempts,b.conversions+' / '+b.conversionAttempts]
 ].map(([label,home,away,detail])=>({label,home,away,...(detail?{detail}:{})}));}
 return {protocol:1,lineup:S.lineup.slice(),reserves:S.reserves.slice(),captain:null,kicker:typeof staffKickerId==='function'?staffKickerId():(S.playerRoles?.buteur&&S.lineup.includes(S.playerRoles.buteur)?S.playerRoles.buteur:chooseScorer(own,S.lineup)?.id)||null,selection,tactics,calendar,leagues,market,...(typeof venteVue==='function'?{sales:venteVue()}:{}),...(typeof calendrierVue==='function'?{mutations:calendrierVue()}:{}),figures:(()=>{
  // Chiffres lus par plusieurs écrans : une seule source (club-budget.cjs), jamais recalculés côté interface.
  const w=typeof chiffresMasse==='function'?chiffresMasse():{joueursHebdo:own.players.reduce((n,p)=>n+p.salary,0)};
  const c=typeof chiffresContrats==='function'?chiffresContrats():null;
  return {payroll:w,contracts:c?{season:c.saison,horizonSeason:c.horizonSaison,squadSize:c.effectif,endOfSeason:c.finDeSaison.length,byHorizon:c.horizon.length}:null};
 })(),groupHistory:Array.isArray(S.groupHistory)?S.groupHistory.map(x=>({...x})):[],finance:{cash:own.cash,wage:own.players.reduce((n,p)=>n+p.salary,0),ledger:S.ledger,cashHistory:Array.isArray(S.cashHistory)?S.cashHistory.map(x=>({...x})):[],...(typeof budgetTransfertsVue==='function'?{transferBudget:budgetTransfertsVue()}:{}),...(typeof santeClassement==='function'&&budgetActif()?{clubs:santeClassement(S.club),health:santeFiche(S.club)}:{}),...(typeof budgetActif==='function'&&budgetActif()?{notice:'Salaires dus sur 52 semaines, payés sur les '+wageForecastWeeks()+' semaines de la saison.',salaryFloor:budgetPlancherHebdo()}:{notice:'Montants fictifs. '+(france?'34 semaines payées par saison. Monde fermé sans Nationale.':'29 semaines payées par saison.')})},club:summary(own),league:sorted.map(c=>({...summary(c),played:c.played,won:c.won,drawn:c.drawn,lost:c.lost,pf:c.pf,pa:c.pa,bonus:c.bonus,form:c.form})),squad,
  next:pair?{pair,home:summary(S.clubs[pair[0]]),away:summary(S.clubs[pair[1]]),label:label(),round:S.round,week:meta.week,neutral:fixture?.neutral??['semi','final'].includes(S.phase),phase:fixture?.phase??S.phase,...(()=>{const m=nextMeteo();return m?{meteo:m}:{};})()}:null,
  archives,history:S.history,messages:S.news,ledger:S.ledger,
  live:l?{lineup:l.sheets[l.userSide].on.map(livePlayer),reserves:l.sheets[l.userSide].bench.map(livePlayer),substitutions:l.sheets[l.userSide].on.map((outId,i)=>({slot:i,label:POS[i],outId,inIds:l.paused&&!l.finished&&!presentationPending(l)?eligibleChanges(l,l.userSide,i).map(p=>p.id):[]})),tactics:{attack:l.tactics[l.userSide],defense:l.defences?.[l.userSide]||'equilibre'},decision:resultDecision,neutral:fixture?.neutral??false,minute:l.minute,period:l.flow?.period??(l.minute>40?2:1),score:l.score,tries:l.tries,paused:l.paused,finished:l.finished,halftime:l.halftime,atBreak:atHalftime(l),weather:l.weather,meteo:liveMeteo(l),pair:l.pair,teams:l.pair.map(id=>summary(S.clubs[id])),events:l.events,stats:l.stats,statsRows,...(typeof nativeSystems!=='undefined'&&nativeSystems.domain('matchIncidents')?nativeSystems.domain('matchIncidents').live(l):{}),...(typeof pilotageProjection==='function'&&l.pilotage?{pilotage:pilotageProjection(l)}:{}),scene:CDMatch3DAdapter.normalize(matchScene(l))}:null,meta};
};

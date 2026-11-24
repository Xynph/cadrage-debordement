'use strict';
// Executed in the game VM. Project facts, existing advice and bounded choices;
// never call a renderer, setter, random generator or persistence operation here.
module.exports=function nativeDecisions(){
 if(!S)return null;
 const own=club(),locked=!!S.live||S.phase==='ended',capacity=professionalCapacity(own);
 const needs=recruitmentNeeds(JSON.parse(JSON.stringify(own))).map(x=>({...x,qualityLabel:ATTR[x.quality]}));
 const availableIds=new Set(managerPool().map(p=>p.id));
 function assessment(r){
  const known=n=>Number.isFinite(n),date=Number.isInteger(r.season)&&Number.isInteger(r.week),age=date&&known(S.economy?.week)&&r.week<=S.economy.week?S.economy.week-r.week:null;
  const available=availableIds.has(r.playerId),stale=age===null?null:age>13;
  const need=Number.isInteger(r.family)?needs.find(n=>n.family===r.family):null;
  const source=date?'Saison '+(typeof libelleSaison==='function'?libelleSaison:String)(r.season)+' · semaine de suivi '+r.week:'Date du rapport non conservée';
  const observed=[],estimates=[],limits=['Qualités détaillées non archivées : aucune force technique précise ne peut être affirmée.'];
  if(known(r.age))observed.push(r.age+' ans à la date du rapport.');
  if(known(r.note))observed.push('Niveau au poste relevé : '+r.note+' / 100 à cette date.');else limits.push('Niveau au poste non conservé.');
  if(known(r.price))observed.push('Prime relevée : '+r.price.toLocaleString('fr-FR')+' € à cette date.');else limits.push('Prime non conservée.');
  if(known(r.salary))observed.push('Salaire relevé : '+r.salary.toLocaleString('fr-FR')+' € / semaine à cette date.');else limits.push('Salaire non conservé.');
  estimates.push(known(r.potential)?'Potentiel au poste : '+r.potential+' / 100.':'Potentiel inconnu.');
  const opinion={A:'À cette date, le recruteur y voyait un renfort potentiel du premier choix.',B:'À cette date, le recruteur y voyait un profil proche du premier choix, pour la concurrence.',C:'À cette date, le recruteur y voyait un profil de complément.'}[r.grade];
  if(opinion)estimates.push(opinion+' Le contexte de comparaison d’alors n’est pas archivé.');
  else limits.push('Appréciation comparative non conservée.');
  if(age!==null&&age>0)limits.push('Rapport établi il y a '+age+' semaine(s) de suivi : niveau, coûts et disponibilité ont pu évoluer.');
  if(age===null)limits.push('Ancienneté non vérifiable : demander une observation actualisée.');
  const fit=need?'Besoins actuels · '+need.pos+' : '+need.healthy+' solution(s) apte(s), '+need.durable+' durable(s). '+need.reasons.slice(0,2).join(' ; ')+'. Correspondance de famille de poste ; aptitude au rôle exact à confirmer.':'Famille de poste non rapprochée des besoins actuels : examiner la couverture de l’effectif avant de décider.';
  const availability=available?'Identifié dans le vivier actuel ; éligibilité, conditions et accord à revalider lors de la négociation.':'Ce joueur n’est plus identifié dans le vivier actuel. Le rapport reste une archive, sans disponibilité présumée.';
  return {source,age,stale,available,availability,fit,observed,estimates,limits,caution:stale?'Rapport ancien : actualiser les informations avant de décider.':'Avis daté à confronter à tes besoins ; aucune garantie de performance ou de signature.'};
 }
 function development(source){
  const p=JSON.parse(JSON.stringify(source)),d=p.dev||{};
  const annual=p.lnrRatingsVersion===1&&typeof nativeInSeasonDevelopment==='undefined',available=!locked&&!S.trained&&!annual;
  const releve=typeof p.rq==='string'?{releve:p.rq,...(()=>{let a=p.attributesV2;if(!(a&&typeof a==='object')&&typeof p.nativeAttributesV1==='string'&&typeof nativeAttributeStore!=='undefined'){try{a=nativeAttributeStore.project(p).attributesV2;}catch(e){a=null;}}return a&&typeof a==='object'?{attributesV2:a}:{};})()}:{}
  const fl=typeof CDReleveQualites!=='undefined'&&typeof CDReleveQualites.fleches==='function'?CDReleveQualites.fleches(source):null;if(fl)releve.fleches=fl;
  return {...releve,...(p.appearanceBankVersion===undefined?{}:{appearanceBankVersion:p.appearanceBankVersion}),...(p.appearanceId===undefined?{}:{appearanceId:p.appearanceId}),id:p.id,name:p.name,pos:p.pos,age:p.age,rating:p.rating,note:roleNote(p),potential:potentialAtRole(p),condition:p.condition,injury:p.injury,salary:p.salary,contractEnd:p.contractEnd??null,minutes:d.minutes||0,appearances:d.appearances||0,development:{focus:developmentFocusValue(p),available,reason:annual?'Évolution annuelle selon âge, entraînement et minutes ; spécialisation individuelle non active sur ce profil.':locked?'Match en cours ou saison terminée':S.trained?'Séance déjà effectuée':'',options:developmentFocusOptions(p).map(id=>({id,label:id==='equilibre'?'Équilibré':ATTR[id]})),history:(d.history||[]).slice(-6),retireAge:d.retireAge??null,seasonStart:d.seasonStart??p.rating}};
 }
 const d=!S.live?matchDossier():null;
 const preparation=d?{opponent:{id:d.opponent.id,name:d.opponent.name},domains:DOSSIER_DOMAINS.map(x=>({key:x.key,label:x.label,slot:x.slot,own:Math.round(d.own[x.key]),opponent:Math.round(d.other[x.key])})),recent:d.recent.map(r=>({phase:r.phase,round:r.round,score:r.score,side:r.side,opponentId:r.opponent})),headToHead:(d.headToHead||[]).map(r=>({score:r.score,side:r.side,home:r.home})),threats:d.threats.map(threat=>{const p=d.opponent.players.find(p=>p.id===threat.id);return {...threat,...(p?.appearanceBankVersion===undefined?{}:{appearanceBankVersion:p.appearanceBankVersion}),...(p?.age===undefined?{}:{age:p.age})};}),signals:dossierScoutSignals(d.recent),advice:d.advice,notice:'Ton XV sélectionné face à une projection adverse sur terrain sec. Les disponibilités, la météo et les choix adverses peuvent modifier ce rapport. Aucun bonus de résultat.'}:null;
 const collective={active:S.collectivePrepVersion===1,selected:S.collectiveFocus||'aucune',available:!locked&&!S.trained&&S.collectivePrepVersion===1,options:Object.entries(COLLECTIVE_FOCI).map(([id,[label,description]])=>({id,label,description,cost:id==='aucune'?'Aucune charge additionnelle':'+4 de charge avant récupération pour les spécialistes concernés',effect:id==='conquete'?'Jusqu’à +4 points de conservation':id==='defence'?'Jusqu’à −2,5 points d’avancée adverse':id==='pied'?'Jusqu’à +3 m au dégagement':'Aucun bonus spécifique'}))};
 const last=S.live?.finished?S.live:S.lastReport;
 const side=last?.pair?.indexOf(S.club)??-1;
 const report=last&&side>=0?{
  score:last.score,pair:last.pair,teams:last.pair.map(id=>({id,name:S.clubs[id]?.name??''})),side,
  weather:last.weather||null,preparation:last.preparation||null,notes:debriefNotes(last,side),
  plans:last.planUsage||null,tacticalStats:last.tacticalStats||null,stats:last.stats||null,
  // Compte rendu (idée FM n°19) : essais détaillés du moteur (minute, camp, origine j/b/m, zone de départ, marqueur), noms lus dans l'effectif.
  essais:(Array.isArray(last.essais)?last.essais:Array.isArray(last.essaisDetail)?(ev=>last.essaisDetail.map((e,i)=>[...e.slice(0,4),ev[i]?.scene?.team===e[1]?ev[i].scene.actor??null:null]))((Array.isArray(last.events)?last.events:[]).filter(e=>e&&e.type==='try'&&e.scene&&e.scene.kind==='try')):[]).filter(e=>Array.isArray(e)&&e.length>=4).map(([minute,camp,origine,zone,id])=>({minute,side:camp,id:id??null,name:id==null?null:S.clubs[last.pair[camp]]?.players?.find(p=>p.id===id)?.name||null,origin:origine,zone})),
  affluence:Number.isInteger(last.affluence)?last.affluence:null,
  // Analyse vidéo (revue FM27, idée 28) : domination minute par minute et entrées dans les 22, gardées à la clôture (worker.cjs).
  analyse:last.analyse||(last===S.live&&typeof nativeAnalyseVideo!=='undefined'?nativeAnalyseVideo.calculer(last):null),
  notice:'Situations de match différentes : le résultat ne dépend pas que de la consigne.'
 }:null;
 return {lineupDefence:Math.round(d?d.own.tackle:dossierMetrics(own,S.lineup).tackle),preparation,training:{advice:physicalStaffAdvice(),adviceState:(()=>{const xv=starters(),high=xv.filter(p=>physicalLoadValue(p)>=45).length;return high?{kind:'charge',count:high}:xv.length&&mean(xv.map(p=>p.condition))<70?{kind:'fatigue',count:xv.length}:{kind:'pret',count:0};})(),collective,...(typeof intensiteAutoRegle==='function'?{intensiteAuto:{seuils:INTENSITE_AUTO_SEUILS.slice(),regle:intensiteAutoRegle(),base:intensiteAutoBase(),chargeBasse:INTENSITE_AUTO_CHARGE_BASSE,available:!S.live}}:{})},difficulty:{selected:S.difficulty||'classique',available:!locked,options:Object.entries(DIFFICULTIES).map(([id,[label,description]])=>({id,label,description}))},delegation:{lineup:!!S.manager?.delegation.lineup,training:!!S.manager?.delegation.training,matchLineup:S.manager?.delegation.matchLineup!==false,...(typeof dsContratsMonde==='function'&&dsContratsMonde()?{contracts:S.manager.delegation.contracts!==false,contractsPolicy:dsContratsConsigne(),contractsPolicyLabel:nativeProlongations.CONSIGNES[dsContratsConsigne()].label,contractsDecided:(S.manager.contractDesk?.season===S.season?S.manager.contractDesk.decisions:[]).map(x=>({id:x.id,name:x.name,pos:x.pos,decision:x.d,state:x.etat,salary:x.salary,end:x.end}))}:{})},recruitment:{capacity,reserved:professionalLoanReservations(own).length,occupied:own.players.length+professionalLoanReservations(own).length,places:professionalPlaces(own),needs,expiring:(typeof chiffresContrats==='function'?chiffresContrats().finDeSaison:own.players.filter(p=>p.contractEnd===S.season)).map(p=>({id:p.id,name:p.name,pos:p.pos,end:p.contractEnd})),missions:(S.manager?.missions||[]).map(x=>({...x})),reports:(S.manager?.reports||[]).map(x=>({...x,assessment:assessment(x)})),missionAvailable:!locked&&own.cash>=5000&&(S.manager?.missions||[]).filter(x=>x.status!=='done').length<4},development:{academy:(S.development?.academy||[]).map(p=>({...development(p),...nativePlayerAttributes(p)})),professionals:own.players.map(development),promotionAvailable:!locked&&professionalPlaces(own)>0},liveAdvice:S.live?matchV61Advice(S.live):null,report};
};

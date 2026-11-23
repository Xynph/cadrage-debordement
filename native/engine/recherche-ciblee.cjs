'use strict';
// Recherche ciblée (revue FM27, idée 26 ; option B choisie par Léo le 23/11/2026) : une mission du recruteur sur un
// maillot du XV, payée 5 000 € à l'envoi (commande scout_mission, critères en plus), qui tourne dans la simulation
// puis repropose les profils déjà connus qui collent et de NOUVEAUX joueurs (ils deviennent observés : rapports du
// recruteur lus par player-knowledge.cjs).
// Critères, tous lus par le moteur :
//   maillot (1-15) : joueurs au moins « Correct » à ce poste (familiarité du moteur), note au poste (positionRatings) ;
//   rôle du poste (table ci-dessous, la même que l'écran ui/immersive08/fiche_roles.gd) : classement par la note du
//     rôle (clés × 2, utiles × 1) mêlée à la note au poste (60 / 40) ;
//   note au poste minimum, potentiel minimum, âge minimum et maximum, indemnité maximum, salaire maximum ;
//   priorité : Prioritaire = une semaine de travail au lieu de deux et 3 nouveaux joueurs ; Standard = deux semaines,
//     2 nouveaux ; Continue = tourne en fond : 1 nouveau par cycle de deux semaines, relancée sans frais en fin de file
//     jusqu'à 4 cycles dans la saison ;
//   recruteurs affectés : +1 nouveau joueur par recruteur en plus du premier (+2 au plus).
// Vivier : agents libres et marché (managerPool) ET joueurs sous contrat dans les autres clubs (rachat ou prêt ensuite
// par les écrans existants). Indemnité d'un joueur sous contrat : salaire repris sur la durée de son contrat (même
// règle que le marché entre clubs, plafonnée par calIndemnite) ; salaire demandé : + 5 %.
// Projection clubLife.rechercheCiblee : missions ciblées en cours et joueurs déjà observés (fourchettes du suivi), avec
// les estimations du recruteur (note au poste, note de rôle, potentiel) : centre de la fourchette relevée, jamais la
// valeur exacte. Clés françaises (nom, poste…) : la projection de la connaissance n'y greffe pas sa fiche complète.
// Aucun tirage au sort : tout est déterministe.
const files=Object.freeze([]),commands=Object.freeze([]);
function factory(){
 const COUT=5000,PRIORITES=Object.freeze(['prioritaire','standard','continue']);
 const NOUVEAUX=Object.freeze({prioritaire:3,standard:2,continue:1}),SEMAINES=Object.freeze({prioritaire:1,standard:2,continue:2});
 const CYCLES_CONTINUE=4,CONNUS_MAX=3,RECRUTEURS_MAX=5,BONUS_RECRUTEURS=2,LISTE_MAX=600,FAMILIARITE_MIN=2,AGENTS_LIBRES_MAX=60;
 // Famille du moteur de chaque maillot (dist/game.js FAMILIES) et famille de rôles de l'écran.
 const FAMILLES=Object.freeze([0,1,0,2,2,3,3,3,4,5,6,7,7,6,8]);
 const FAMILLE_ROLE=Object.freeze(['pilier','talonneur','pilier','deuxieme','deuxieme','aile','aile','huit','demi','ouvreur','ailier','centre','centre','ailier','arriere']);
 // [id, famille, 4 qualités clés, 4 qualités utiles] : copie de ui/immersive08/fiche_roles.gd (vérifiée par tests/recherche-ciblee.cjs).
 const ROLES=Object.freeze([
  ['pilier-conquerant','pilier',['scrumTechnique','strength','maul','endurance'],['lineoutLift','ruckClearout','tackling','discipline']],
  ['pilier-mobile','pilier',['ballCarry','workRate','tackling','endurance'],['offload','ruckClearout','receiving','acceleration']],
  ['pilier-deblayeur','pilier',['ruckClearout','strength','tackling','workRate'],['jackal','maul','explosiveness','discipline']],
  ['talon-lanceur','talonneur',['lineoutThrow','hooking','scrumTechnique','composure'],['maul','strength','discipline','decisions']],
  ['talon-gratteur','talonneur',['jackal','tackling','ballCarry','workRate'],['acceleration','offload','anticipation','ruckClearout']],
  ['talon-perforateur','talonneur',['ballCarry','strength','explosiveness','offload'],['hooking','lineoutThrow','endurance','evasion']],
  ['deux-sauteur','deuxieme',['lineoutJump','jumping','aerialAbility','decisions'],['lineoutLift','maul','receiving','anticipation']],
  ['deux-pousseur','deuxieme',['scrumTechnique','strength','ruckClearout','maul'],['tackling','endurance','lineoutLift','workRate']],
  ['deux-mobile','deuxieme',['workRate','ballCarry','tackling','endurance'],['offload','passing','acceleration','lineoutJump']],
  ['aile-gratteur','aile',['jackal','tackling','anticipation','workRate'],['positioning','ruckClearout','acceleration','discipline']],
  ['aile-perforateur','aile',['ballCarry','explosiveness','offload','strength'],['lineoutJump','workRate','evasion','endurance']],
  ['aile-plaqueur','aile',['tackling','workRate','endurance','positioning'],['anticipation','strength','ruckClearout','discipline']],
  ['huit-porteur','huit',['ballCarry','strength','offload','explosiveness'],['scrumTechnique','ballHandling','endurance','evasion']],
  ['huit-liant','huit',['ballHandling','decisions','passing','vision'],['teamwork','lineoutJump','receiving','offload']],
  ['huit-meneur','huit',['leadership','decisions','tackling','lineoutJump'],['discipline','composure','workRate','scrumTechnique']],
  ['demi-eclaireur','demi',['acceleration','evasion','anticipation','ballCarry'],['passing','decisions','agility','receiving']],
  ['demi-animateur','demi',['passing','decisions','vision','teamwork'],['kickAccuracy','leadership','composure','ballHandling']],
  ['demi-tacticien','demi',['kickDistance','kickAccuracy','passing','decisions'],['kickChase','composure','vision','positioning']],
  ['ouvreur-stratege','ouvreur',['kickDistance','kickAccuracy','decisions','vision'],['goalAccuracy','composure','positioning','leadership']],
  ['ouvreur-attaquant','ouvreur',['passing','vision','evasion','ballHandling'],['acceleration','decisions','offload','agility']],
  ['ouvreur-buteur','ouvreur',['goalAccuracy','kickAccuracy','composure','kickDistance'],['decisions','discipline','positioning','passing']],
  ['centre-perceur','centre',['ballCarry','strength','evasion','explosiveness'],['offload','tackling','acceleration','receiving']],
  ['centre-distributeur','centre',['passing','vision','ballHandling','decisions'],['kickDistance','receiving','offload','tackling']],
  ['centre-verrou','centre',['tackling','positioning','anticipation','jackal'],['workRate','strength','decisions','discipline']],
  ['ailier-finisseur','ailier',['topSpeed','acceleration','evasion','agility'],['receiving','ballCarry','composure','offload']],
  ['ailier-chasseur','ailier',['kickChase','aerialAbility','tackling','topSpeed'],['workRate','positioning','jumping','receiving']],
  ['ailier-perforateur','ailier',['ballCarry','strength','explosiveness','evasion'],['topSpeed','offload','receiving','tackling']],
  ['arriere-relanceur','arriere',['evasion','topSpeed','receiving','vision'],['passing','acceleration','agility','decisions']],
  ['arriere-rempart','arriere',['aerialAbility','positioning','tackling','receiving'],['kickDistance','composure','anticipation','jumping']],
  ['arriere-botteur','arriere',['kickDistance','kickAccuracy','aerialAbility','positioning'],['goalAccuracy','decisions','composure','kickChase']],
 ].map(r=>Object.freeze(r)));
 const ROLE=new Map(ROLES.map(r=>[r[0],r]));
 const CLES_CIBLE=Object.freeze(['position','role','minNote','minPotential','minAge','priority','scouts','cycle']);
 const object=x=>!!x&&typeof x==='object'&&!Array.isArray(x);
 const entier=(x,a,b)=>Number.isSafeInteger(x)&&x>=a&&x<=b;
 const nombre=x=>typeof x==='number'&&Number.isFinite(x);
 const identifiant=x=>typeof x==='string'&&/^[A-Za-z0-9:_.-]{1,180}$/.test(x);
 const check=(ok,message)=>{if(!ok)throw Error('Recherche ciblée : '+message+'.');};
 const borne=(v,a,b)=>Math.max(a,Math.min(b,v));
 const aptitudes=p=>typeof nativePositionAptitudes!=='undefined'?nativePositionAptitudes.project(p):null;
 const qualites=p=>{try{return typeof nativeAttributeStore!=='undefined'?nativeAttributeStore.project(p).attributesV2:null;}catch{return null;}};
 const potentiel=p=>nombre(p?.dev?.potential)?p.dev.potential:nombre(p?.potential)?p.potential:p.rating;
 function noteRole(attrs,role){
  if(!attrs||!role)return null;let total=0,poids=0;
  for(let k=0;k<2;k++)for(const cle of role[2+k]){const v=attrs[cle];if(!nombre(v))return null;total+=(k===0?2:1)*v;poids+=k===0?2:1;}
  return poids?total/poids:null;
 }
 // --- Recruteurs du club ---------------------------------------------------------------------------------------------
 function recruteurs(s){
  if(s?.staffCareer?.version!==1)return null;
  return s.staffCareer.people.flat().filter(p=>p&&p.role==='scout'&&p.clubId===s.club&&nombre(p.level)&&p.contractEnd>=s.season);
 }
 // --- Critères envoyés avec scout_mission ------------------------------------------------------------------------------
 // Payload sans « position » : ancienne mission (famille seule), rien de plus. Sinon critères validés → objet rangé sur la mission.
 function cible(payload,s=S){
  if(!object(payload)||!Object.hasOwn(payload,'position'))return null;
  const n=payload.position;check(entier(n,1,15),'maillot invalide');
  check(payload.family===FAMILLES[n-1],'famille et maillot incohérents');
  const role=payload.role??'';check(role===''||ROLE.has(role)&&ROLE.get(role)[1]===FAMILLE_ROLE[n-1],'rôle inconnu pour ce poste');
  const minNote=payload.minNote??0,minPotential=payload.minPotential??0,minAge=payload.minAge??18;
  check(entier(minNote,0,100)&&entier(minPotential,0,100),'note ou potentiel minimum invalide');
  check(entier(minAge,16,40)&&minAge<=payload.maxAge,'âge minimum invalide');
  const priority=payload.priority??'standard';check(PRIORITES.includes(priority),'priorité inconnue');
  const scouts=payload.scouts??[];
  check(Array.isArray(scouts)&&scouts.length<=RECRUTEURS_MAX&&scouts.every(identifiant)&&new Set(scouts).size===scouts.length,'recruteurs invalides');
  const club=recruteurs(s);
  if(club)check(scouts.every(id=>club.some(p=>p.id===id)),'recruteur absent du staff du club');
  return {position:n,role,minNote,minPotential,minAge,priority,scouts:scouts.slice(),cycle:1};
 }
 function valideCible(c){
  return object(c)&&Object.keys(c).length===CLES_CIBLE.length&&CLES_CIBLE.every(k=>Object.hasOwn(c,k))&&entier(c.position,1,15)&&
   (c.role===''||ROLE.has(c.role)&&ROLE.get(c.role)[1]===FAMILLE_ROLE[c.position-1])&&entier(c.minNote,0,100)&&entier(c.minPotential,0,100)&&
   entier(c.minAge,16,40)&&PRIORITES.includes(c.priority)&&Array.isArray(c.scouts)&&c.scouts.length<=RECRUTEURS_MAX&&c.scouts.every(identifiant)&&
   new Set(c.scouts).size===c.scouts.length&&entier(c.cycle,1,CYCLES_CONTINUE);
 }
 function validate(s){
  for(const j of s?.manager?.missions||[]){
   if(j.cible===undefined)continue;
   if(!valideCible(j.cible)||j.cible.minAge>j.maxAge||FAMILLES[j.cible.position-1]!==j.family)throw Error('Recherche ciblée : mission invalide.');
  }
  for(const r of s?.manager?.reports||[])if(r.cible!==undefined&&!(object(r.cible)&&Object.keys(r.cible).length===3&&typeof r.cible.connu==='boolean'&&(r.cible.club===null||entier(r.cible.club,0,100000))&&entier(r.cible.maillot,1,15)))throw Error('Recherche ciblée : rapport invalide.');
  return true;
 }
 // --- Vivier et estimation -------------------------------------------------------------------------------------------
 // Identifiants déjà suivis (registre de la connaissance : premier champ de chaque enregistrement compact).
 function suivis(s){const out=new Set();for(const bloc of s?.playerKnowledge?.records||[])for(const r of bloc)out.add(r[0]);return out;}
 function vivier(s){
  const rangs=[],vus=new Set(),own=s.clubs[s.club],nous=new Set((own?.players||[]).map(p=>p.id));
  const libres=typeof managerPool==='function'?managerPool():[...(s.market||[]),...(s.economy?.freeAgents||[])];
  for(const p of libres)if(p&&!nous.has(p.id)&&!vus.has(p.id)){vus.add(p.id);rangs.push({p,club:null});}
  for(const c of s.clubs||[]){if(!c||c.id===s.club)continue;for(const p of c.players||[])if(p&&!nous.has(p.id)&&!vus.has(p.id)){vus.add(p.id);rangs.push({p,club:c});}}
  return rangs;
 }
 function conditions(s,p,club){
  if(!club)return {indemnite:Math.max(0,Math.round(p.price||0)),salaire:Math.round(p.salary||0)};
  const semaines=typeof wageForecastWeeks==='function'?wageForecastWeeks(s):40,annees=Math.max(1,(p.contractEnd??s.season)-s.season+1);
  const brut=Math.max(20000,Math.ceil((p.salary||0)*semaines*annees/20000)*10000);
  return {indemnite:typeof calIndemnite==='function'?calIndemnite(p,brut):brut,salaire:Math.max(1000,Math.ceil((p.salary||0)*1.05/100)*100)};
 }
 const engage=p=>typeof calIAIndisponible==='function'&&!!calIAIndisponible(p.id,p);
 // Candidats qui passent tous les critères, classés (rôle choisi : 60 % note du rôle, 40 % note au poste).
 function candidats(s,job){
  const c=job.cible,n=c.position,role=c.role?ROLE.get(c.role):null,connus=suivis(s),out=[];
  for(const {p,club} of vivier(s)){
   if(!nombre(p.age)||p.age<c.minAge||p.age>job.maxAge||engage(p))continue;
   const a=aptitudes(p);if(!a||!(a.positionFamiliarityLevels?.[n-1]>=FAMILIARITE_MIN))continue;
   const note=a.positionRatings?.[n];if(!nombre(note)||note<c.minNote)continue;
   const pot=potentiel(p);if(!nombre(pot)||pot<c.minPotential)continue;
   const cond=conditions(s,p,club);if(cond.indemnite>job.budget||cond.salaire>job.maxWage)continue;
   const nr=role?noteRole(qualites(p),role):null;
   out.push({p,club,note,pot,...cond,score:role&&nr!==null?.6*nr+.4*note:note,connu:connus.has(p.id)});
  }
  return out.sort((x,y)=>y.score-x.score||y.pot-x.pot||(String(x.p.id)<String(y.p.id)?-1:1));
 }
 function nombreNouveaux(c){return NOUVEAUX[c.priority]+Math.min(BONUS_RECRUTEURS,Math.max(0,c.scouts.length-1));}
 // Fin d'une mission ciblée : rapports (nouveaux puis déjà connus), message, relance d'une recherche continue.
 function terminer(s,job){
  const m=s.manager,c=job.cible,n=c.position,week=s.economy.week;
  const liste=candidats(s,job),signales=new Set((m.reports||[]).filter(r=>r.cible).map(r=>r.playerId));
  const nouveaux=liste.filter(x=>!x.connu&&!signales.has(x.p.id)).slice(0,nombreNouveaux(c)),connus=liste.filter(x=>x.connu).slice(0,CONNUS_MAX);
  const nous=(s.clubs[s.club]?.players||[]).reduce((best,q)=>{const a=aptitudes(q);return Math.max(best,a?.positionRatings?.[n]??0);},0);
  for(const x of [...connus,...nouveaux].reverse()){
   const p=x.p;
   if(!x.club&&!s.economy.freeAgents.some(q=>q.id===p.id)&&s.economy.freeAgents.length<AGENTS_LIBRES_MAX){p.contractEnd=null;s.economy.freeAgents.push(p);}
   const gain=x.note-nous;
   m.reports.unshift({id:'report-'+(++m.serial),mission:job.id,playerId:p.id,name:p.name,pos:p.pos,family:p.fam,age:p.age,note:borne(Math.round(x.note),0,100),potential:borne(Math.round(x.pot),0,100),
    salary:x.salaire,price:x.indemnite,grade:gain>=4?'A':gain>=-3?'B':'C',week,season:s.season,cible:{connu:x.connu,club:x.club?x.club.id:null,maillot:n}});
  }
  m.reports=m.reports.slice(0,40);
  const poste=typeof POS!=='undefined'?POS[n-1]:'Poste '+n;
  if(typeof managerMessage==='function')managerMessage('Recherche ciblée · '+poste,nouveaux.length+' nouveau(x) · '+connus.length+' déjà connu(s)','recruitment','recruitment');
  if(c.priority==='continue'&&c.cycle<CYCLES_CONTINUE&&s.phase!=='ended'&&attente(s)<4){
   m.missions.push({id:'mission-'+(++m.serial),family:job.family,maxAge:job.maxAge,budget:job.budget,maxWage:job.maxWage,remaining:SEMAINES.continue,status:'queued',week,cible:{...c,scouts:c.scouts.slice(),cycle:c.cycle+1}});
   m.missions=m.missions.slice(-24);
  }
 }
 const attente=s=>[...(s?.manager?.missions||[]),...(s?.playerKnowledge?.jobs||[])].filter(j=>j.status!=='done').length;
 // --- Projection -----------------------------------------------------------------------------------------------------
 function decoder(s){
  const out=[];for(const bloc of s?.playerKnowledge?.records||[])for(const r of bloc)out.push({id:r[0],stage:r[1],season:r[2],week:r[3],rating:r[5],rr:[r[7],r[8]],pr:[r[9],r[10]]});
  return out.sort((a,b)=>b.season-a.season||(b.week??-1)-(a.week??-1)||(a.id<b.id?-1:1));
 }
 function connus(s){
  const parId=new Map();for(const x of vivier(s))parId.set(x.p.id,x);
  const out=[];
  for(const r of decoder(s)){
   if(out.length>=LISTE_MAX)break;
   const x=parId.get(r.id);if(!x)continue;
   const p=x.p,a=aptitudes(p);if(!a)continue;
   const niveaux=(a.positionFamiliarityLevels||[]).map(v=>borne(Math.round(v)||0,0,4));if(niveaux.length!==15)continue;
   // Estimation du recruteur : centre de la fourchette relevée, rapporté à la structure du joueur (note au poste, rôle).
   const centre=(r.rr[0]+r.rr[1])/2,echelle=centre/Math.max(1,p.rating||1),postes={},roles={},attrs=qualites(p);
   for(let n=1;n<=15;n++){
    if(niveaux[n-1]<FAMILIARITE_MIN)continue;
    postes[n]=borne(Math.round((a.positionRatings?.[n]??0)*echelle),0,100);
    for(const role of ROLES)if(role[1]===FAMILLE_ROLE[n-1]&&!Object.hasOwn(roles,role[0])){const v=noteRole(attrs,role);if(v!==null)roles[role[0]]=borne(Math.round(v*echelle),0,100);}
   }
   if(!Object.keys(postes).length)continue;
   const cond=conditions(s,p,x.club);
   out.push({id:p.id,nom:p.name,poste:p.pos,age:p.age,club:x.club?{id:x.club.id,nom:x.club.short||x.club.name||''}:null,indemnite:cond.indemnite,salaire:cond.salaire,
    maillots:(a.primaryPositions||[]).slice(),familiarite:niveaux,estime:{postes,roles,potentiel:Math.round((r.pr[0]+r.pr[1])/2)},suivi:r.stage,vu:{saison:r.season,semaine:r.week}});
  }
  return out;
 }
 function project(){
  if(typeof S==='undefined'||!S?.manager)return null;
  const s=S,locked=!!s.live||s.phase==='ended',club=recruteurs(s);
  return {cout:COUT,disponible:!locked&&(s.clubs[s.club]?.cash??0)>=COUT&&attente(s)<4,attente:attente(s),
   priorites:PRIORITES.map(id=>({id,semaines:SEMAINES[id],nouveaux:NOUVEAUX[id]})),
   recruteurs:club?club.map(p=>({id:p.id,nom:p.name,niveau:p.level})):null,
   missions:s.manager.missions.filter(j=>j.cible&&j.status!=='done').map(j=>({id:j.id,status:j.status,remaining:j.remaining,maillot:j.cible.position,role:j.cible.role,priorite:j.cible.priority,cycle:j.cible.cycle})),
   connus:connus(s)};
 }
 // --- Crochets -------------------------------------------------------------------------------------------------------
 let installe=false;
 function installHooks(){
  if(installe)return true;installe=true;
  if(typeof createScoutMission==='function'){
   const avant=createScoutMission;
   createScoutMission=function(family,maxAge,budget,maxWage,criteres){
    const result=avant.call(this,family,maxAge,budget,maxWage);
    if(result&&criteres&&typeof S!=='undefined'&&S?.manager){const job=S.manager.missions[S.manager.missions.length-1];job.cible=criteres;job.remaining=SEMAINES[criteres.priority];}
    return result;
   };
   Object.assign(createScoutMission,avant);
  }
  if(typeof managerWeek==='function'){
   const avant=managerWeek;
   // La fin d'une mission ciblée remplace le tri de l'ancienne mission (famille seule) : une semaine de travail de plus
   // est comptée le temps de l'ancien traitement, puis la mission est terminée ici.
   managerWeek=function(){
    const s=typeof S==='undefined'?null:S,m=s?.manager;
    const job=m&&s.economy.week>m.lastWeek?m.missions.find(x=>x.status==='active'&&x.cible):null,fin=!!job&&job.remaining===1;
    if(fin)job.remaining=2;
    const result=avant.apply(this,arguments);
    if(fin&&job.status==='active'&&job.remaining===1){
     job.remaining=0;job.status='done';terminer(s,job);
     if(!m.missions.some(x=>x.status==='active')){const q=m.missions.find(x=>x.status==='queued');if(q)q.status='active';}
    }else if(fin&&job.remaining===2)job.remaining=1;
    return result;
   };
   Object.assign(managerWeek,avant);
  }
  return true;
 }
 return {project,validate,execute(){throw Error('Recherche ciblée : aucune commande propre (scout_mission).');},installHooks,cible,
  _tests:{candidats,terminer,connus,nombreNouveaux,noteRole},ROLES,PRIORITES,NOUVEAUX,SEMAINES,COUT};
}
module.exports={files,commands,factory};

'use strict';
// Staff par service (revue FM27, idée n° 22 ; choix A de Léo du 23/11/2026).
//
// Quatre services : Entraîneurs (adjoint, avants, arrières, défense), Préparation physique (responsable, préparateur,
// réathlétisation), Médical (médecin, deux kinés), Recrutement et club (recruteur, analyste, formation, team manager,
// intendant). Postes MINIMUM : ceux de staff-completion.cjs (15). Chaque membre du staff du club du manager est placé
// sur un poste minimum par couplage maximal (même méthode que staff-completion.coverage), les meilleurs niveaux d'abord ;
// les autres sont « en plus » dans le service de leur fonction.
//
// Postes visés au-delà du minimum (commande staff_services_target, un clic = appliqué) : 0 à 3 par service, 0 par
// défaut (aucun effet ni coût pour les carrières existantes). Chaque poste visé tenu par un membre « en plus » donne un
// petit bonus réel au club du manager et coûte un salaire hebdomadaire (registre du club) :
//   Entraîneurs           : +5 % de progression à l'entraînement par poste (séances du club)        · 2 500 € / sem.
//   Préparation physique : −5 % de risque de blessure par poste (entraînement, match, incidents)   · 1 500 € / sem.
//   Médical               : +10 % de vitesse de soins par poste (jamais la dernière semaine)        · 2 000 € / sem.
//   Recrutement et club   : −10 % sur le coût d'une observation ciblée par poste (5 000 € → 3 500 €) · 1 200 € / sem.
// Au plus 3 postes en plus par service : +15 % / −15 % / +30 % / −30 %. Les membres « en plus » au-delà de la cible
// restent au club (en surnombre), sans bonus ni coût. Un membre déjà payé par l'emploi rémunéré du staff
// (staff-employment.cjs) n'est pas payé une seconde fois.
//
// Avis des dirigeants (un par service, déterministe) : niveau attendu = 21 + 0,6 × base du club + (ambition du
// président − 50) / 10, borné 45-80 (relevé sur les 116 clubs du Monde : niveau moyen d'un service ≈ 19 + 0,63 × base,
// écart type 4) ; note = 60 + 2 × (niveau moyen du service − attendu) [borné ±30] − 20 par poste
// minimum vacant + 4 par poste en plus tenu, bornée 0-100 ; Ravis ≥ 75, Satisfaits ≥ 55, Mitigés ≥ 40, sinon Inquiets.
//
// État (S.staffServices, absent tant qu'aucune cible n'a été posée) : {version, club, cibles: {service: 0-3},
// soins: {joueur: fraction de semaine gagnée}, paie: null | {season, week}}. Aucun tirage au sort.
const files=Object.freeze([]),commands=Object.freeze(['staff_services_target']);
function factory(){
 // Politique de staff-completion.cjs, recopiée dans la fabrique sérialisée (voir en bas).
 const completion=(function staffCompletionPolicy(){return null;})();
 const VERSION=1,MAX=3,OBSERVATION=5000;
 const SERVICES=Object.freeze([
  Object.freeze({id:'coaching',fonctions:Object.freeze(['assistant','forwards','backs','defence']),bonus:'progression',parPoste:.05,salaire:2500}),
  Object.freeze({id:'fitness',fonctions:Object.freeze(['fitnessLead','conditioning','rehab']),bonus:'prevention',parPoste:.05,salaire:1500}),
  Object.freeze({id:'medical',fonctions:Object.freeze(['doctor','physio']),bonus:'soins',parPoste:.10,salaire:2000}),
  Object.freeze({id:'club',fonctions:Object.freeze(['scout','analyst','formation','teamManager','equipment']),bonus:'observation',parPoste:.10,salaire:1200})]);
 const AVIS=Object.freeze({attendu:Object.freeze({constante:21,pente:.6,ambition:.1,min:45,max:80}),base:60,pente:2,ecart:30,vacant:20,renfort:4,seuils:Object.freeze([['ravis',75],['satisfaits',55],['mitiges',40]])});
 const RULES=Object.freeze({MAX,OBSERVATION,SERVICES,AVIS});
 const IDS=SERVICES.map(s=>s.id),serviceDe=new Map(SERVICES.flatMap(s=>s.fonctions.map(f=>[f,s.id])));
 const object=x=>!!x&&typeof x==='object'&&!Array.isArray(x);
 const int=(v,a,b)=>Number.isSafeInteger(v)&&v>=a&&v<=b;
 const borne=(x,a,b)=>Math.max(a,Math.min(b,x));
 const check=(ok,msg)=>{if(!ok)throw Error('Staff par service : '+msg+'.');};
 const etat=()=>typeof S==='undefined'?null:S;
 const week=s=>s.worldMode?.week??s.franceMode?.week??(s.phase==='league'?s.round:({barrage:26,semi:27,final:28,ended:29}[s.phase]??s.round));
 const actif=s=>s?.staffCareer?.version===1&&Array.isArray(s.staffCareer.people)&&s.staffCareer.completionPolicy===completion.POLICY;
 const membres=s=>s.staffCareer.people.flat().filter(p=>p&&p.clubId===s.club);
 const serviceDuRole=role=>role==='coach'||role==='assistant'?'coaching':role==='fitness'?'fitness':role==='medical'?'medical':'club';
 // Cibles en vigueur (postes visés en plus du minimum) : celles du club actuel du manager, sinon aucune.
 function cibles(s){
  const st=s?.staffServices;
  return Object.fromEntries(IDS.map(id=>[id,st&&st.club===s.club&&int(st.cibles?.[id],0,MAX)?st.cibles[id]:0]));
 }
 const aucuneCible=s=>IDS.every(id=>cibles(s)[id]===0);
 // Répartition du staff du club : {service: {fonctions: {cle: [personnes]}, enPlus: [...], surnombre: [...]}}.
 function repartition(s){
  const gens=membres(s).sort((a,b)=>(b.level||0)-(a.level||0)||(a.id<b.id?-1:a.id>b.id?1:0));
  const caps=gens.map(p=>completion.capabilities(p.roleLabel||p.role));
  const postes=[];for(const sv of SERVICES)for(const f of sv.fonctions)for(let i=0;i<completion.MINIMUM[f];i++)postes.push(f);
  const tenu=new Map();
  const placer=(poste,vus)=>{for(let i=0;i<gens.length;i++){if(vus.has(i)||!caps[i].includes(postes[poste]))continue;vus.add(i);const avant=tenu.get(i);if(avant===undefined||placer(avant,vus)){tenu.set(i,poste);return true;}}return false;};
  for(let k=0;k<postes.length;k++)placer(k,new Set());
  const vise=cibles(s),out={};
  for(const sv of SERVICES)out[sv.id]={fonctions:Object.fromEntries(sv.fonctions.map(f=>[f,[]])),enPlus:[],surnombre:[]};
  const libres={};for(const id of IDS)libres[id]=[];
  for(let i=0;i<gens.length;i++){
   if(tenu.has(i))out[serviceDe.get(postes[tenu.get(i)])].fonctions[postes[tenu.get(i)]].push(gens[i]);
   else libres[caps[i].length?serviceDe.get(caps[i][0]):serviceDuRole(gens[i].role)].push(gens[i]);
  }
  for(const id of IDS){out[id].enPlus=libres[id].slice(0,vise[id]);out[id].surnombre=libres[id].slice(vise[id]);}
  return out;
 }
 const paye=(s,p)=>(s.staffEmployment?.contracts||[]).some(c=>c.staffId===p.id&&c.clubId===s.club&&c.endSeason>=s.season);
 // Bonus du club du manager pour un type ('progression', 'prevention', 'soins', 'observation') : fraction (0,05 = 5 %).
 function bonus(type,s=etat()){
  if(!s||!actif(s)||aucuneCible(s))return 0;
  const sv=SERVICES.find(x=>x.bonus===type);if(!sv)return 0;
  return Math.round(repartition(s)[sv.id].enPlus.length*sv.parPoste*1000)/1000;
 }
 function salaireSemaine(s,r=repartition(s)){
  return SERVICES.reduce((n,sv)=>n+r[sv.id].enPlus.filter(p=>!paye(s,p)).length*sv.salaire,0);
 }
 function coutObservation(s=etat()){return Math.round(OBSERVATION*(1-bonus('observation',s))/100)*100;}
 function niveauAttendu(s){
  const origine=s.staffCareer?.completionOrigins?.find(o=>o.clubId===s.club),base=Number.isFinite(origine?.base)?origine.base:Number.isFinite(s.clubs?.[s.club]?.base)?s.clubs[s.club].base:65;
  const ambition=s.clubDirections?.clubs?.[s.club]?.president?.traits?.ambition,amb=Number.isFinite(ambition)?ambition:50;
  const a=AVIS.attendu;return borne(Math.round(a.constante+a.pente*base+(amb-50)*a.ambition),a.min,a.max);
 }
 // Avis des dirigeants sur un service : {verdict, note, moyenne, attendu, manque, renforts}.
 function avis(s,sv,r,attendu=niveauAttendu(s)){
  const tenus=Object.values(r.fonctions).flat().concat(r.enPlus),manque=sv.fonctions.reduce((n,f)=>n+Math.max(0,completion.MINIMUM[f]-r.fonctions[f].length),0);
  const moyenne=tenus.length?Math.round(tenus.reduce((n,p)=>n+(Number.isFinite(p.level)?p.level:0),0)/tenus.length):0;
  const note=borne(Math.round(AVIS.base+borne(AVIS.pente*(moyenne-attendu),-AVIS.ecart,AVIS.ecart)-AVIS.vacant*manque+AVIS.renfort*r.enPlus.length),0,100);
  return {verdict:(AVIS.seuils.find(([,seuil])=>note>=seuil)||['inquiets'])[0],note,moyenne,attendu,manque,renforts:r.enPlus.length};
 }
 function project(){
  const s=etat();if(!s)return null;
  if(!actif(s))return {available:false,max:MAX,services:[],salaireSemaine:0,coutObservation:OBSERVATION};
  const r=repartition(s),vise=cibles(s),attendu=niveauAttendu(s),ids=list=>list.map(p=>p.id);
  const services=SERVICES.map(sv=>{
   const x=r[sv.id],minimum=sv.fonctions.reduce((n,f)=>n+completion.MINIMUM[f],0),couverts=sv.fonctions.reduce((n,f)=>n+Math.min(completion.MINIMUM[f],x.fonctions[f].length),0);
   return {id:sv.id,minimum,cible:vise[sv.id],max:MAX,occupes:couverts+x.enPlus.length,vises:minimum+vise[sv.id],
    fonctions:sv.fonctions.map(f=>({cle:f,minimum:completion.MINIMUM[f],ids:ids(x.fonctions[f])})),enPlus:ids(x.enPlus),surnombre:ids(x.surnombre),
    bonus:{type:sv.bonus,parPoste:sv.parPoste,total:Math.round(x.enPlus.length*sv.parPoste*1000)/1000},
    salaire:{parPoste:sv.salaire,semaine:x.enPlus.filter(p=>!paye(s,p)).length*sv.salaire},avis:avis(s,sv,x,attendu)};
  });
  // Direction du club (club-directions.cjs) : mêmes noms que la fiche du club et les courriers, pour l'organigramme.
  const d=s.clubDirections?.clubs?.[s.club],nom=p=>typeof p?.name==='string'&&p.name?p.name:null;
  return {available:true,max:MAX,services,salaireSemaine:salaireSemaine(s,r),coutObservation:coutObservation(s),locked:!!(s.live&&!s.live.finished),
   direction:{president:nom(d?.president),director:nom(d?.director)}};
 }
 function assurer(s){
  if(!object(s.staffServices)||s.staffServices.club!==s.club)s.staffServices={version:VERSION,club:s.club,cibles:Object.fromEntries(IDS.map(id=>[id,0])),soins:{},paie:null};
  return s.staffServices;
 }
 function validate(s){
  const st=s?.staffServices;if(st===undefined)return true;
  const ok=object(st)&&Object.keys(st).length===5&&st.version===VERSION&&Number.isSafeInteger(st.club)&&st.club>=0
   &&object(st.cibles)&&Object.keys(st.cibles).length===IDS.length&&IDS.every(id=>int(st.cibles[id],0,MAX))
   &&object(st.soins)&&Object.keys(st.soins).length<=80&&Object.entries(st.soins).every(([k,v])=>k.length<=240&&typeof v==='number'&&v>=0&&v<1)
   &&(st.paie===null||object(st.paie)&&Object.keys(st.paie).length===2&&int(st.paie.season,1,100000)&&int(st.paie.week,0,200));
  check(ok,'état invalide');return true;
 }
 function execute(command,payload){
  check(command==='staff_services_target','commande inconnue');
  const s=etat();check(!!s,'carrière absente');check(!(s.live&&!s.live.finished),'termine le match avant de changer les postes');
  check(actif(s),'staff du club indisponible');
  check(object(payload)&&IDS.includes(payload.service)&&int(payload.cible,0,MAX),'service ou nombre de postes invalide');
  const st=assurer(s);st.cibles[payload.service]=payload.cible;validate(s);
  return {staffServicesAction:{service:payload.service,cible:payload.cible}};
 }
 // --- Effets (club du manager seulement) -------------------------------------------------------------------------
 const nosJoueurs=s=>s?.clubs?.[s.club]?.players||[];
 const estANous=(s,p)=>!!p&&nosJoueurs(s).some(x=>x===p||x.id===p.id);
 // Prévention : facteur appliqué au risque de blessure (facteurFragilite) des joueurs du club.
 function facteurPrevention(p,s=etat()){return s&&estANous(s,p)?1-bonus('prevention',s):1;}
 // Soins, après la séance de la semaine (trainWeek a déjà retiré une semaine) : chaque blessé du club à 2 semaines ou
 // plus gagne la fraction du bonus ; une semaine entière gagnée est retirée. Jamais la dernière semaine (le retour reste
 // au protocole médical habituel).
 function soigner(s=etat()){
  if(!s||!s.staffServices||s.staffServices.club!==s.club)return 0;
  const st=s.staffServices,b=bonus('soins',s),gardes={};let gagnees=0;
  if(b>0)for(const p of nosJoueurs(s)){
   if(!p||!(p.injury>=2))continue;
   let v=(st.soins[p.id]||0)+b;
   if(v>=1){p.injury-=1;v-=1;gagnees++;}
   v=Math.round(v*1000)/1000;
   if(p.injury>=2&&v>0)gardes[p.id]=v;
  }
  st.soins=gardes;return gagnees;
 }
 // Progression : part en plus de la séance du club, sur la même base que developmentTraining (dist/development.js).
 function progresser(p,mode,ci,s=etat()){
  if(!s||ci!==s.club||!p||p.injury||mode==='repos'||typeof growPlayer!=='function'||typeof ageGrowth!=='function')return 0;
  const b=bonus('progression',s);if(!(b>0))return 0;
  const fit=typeof growthFitnessFactor==='function'?growthFitnessFactor(p):1,xp=(mode==='intense'?.10:.055)*ageGrowth(p)*(p.condition<50?.5:1)*fit*b;
  if(xp>0)growPlayer(p,xp,false);
  return xp;
 }
 // Paie hebdomadaire des postes en plus, avec la séance de la semaine (trainWeek, une fois par semaine) : financeWeek est
 // remplacée après l'installation des domaines par le budget du club (club-budget.cjs), un crochet y serait perdu.
 function paie(s=etat()){
  if(!s||!s.staffServices||s.staffServices.club!==s.club||!actif(s))return 0;
  const st=s.staffServices,w=week(s);
  if(st.paie&&(st.paie.season>s.season||st.paie.season===s.season&&st.paie.week>=w))return 0;
  st.paie={season:s.season,week:w};
  const montant=salaireSemaine(s);
  if(montant>0&&typeof ledgerEntry==='function')ledgerEntry('Salaires du staff · postes en plus · semaine '+(w+1),-montant);
  return montant;
 }
 const api=Object.freeze({RULES,bonus,coutObservation,facteurPrevention});
 let installe=false;
 function installHooks(){
  globalThis.CDStaffServices=api;
  const base=globalThis.facteurFragilite;
  if(typeof base==='function'&&!base.__staffServices){const w=function(p){return base(p)*facteurPrevention(p);};w.__staffServices=true;globalThis.facteurFragilite=w;}
  if(installe)return true;installe=true;
  if(typeof trainWeek==='function'){
   const avant=trainWeek;
   trainWeek=function(){const deja=typeof S!=='undefined'&&S?!!S.trained:true;const r=avant.apply(this,arguments);if(!deja&&S?.trained){soigner();paie();}return r;};
   Object.assign(trainWeek,avant);
  }
  if(typeof developmentTraining==='function'){
   const avant=developmentTraining;
   developmentTraining=function(p,mode,ci){const pret=!!p&&!p.injury&&mode!=='repos';const r=avant.apply(this,arguments);if(pret)progresser(p,mode,ci);return r;};
   Object.assign(developmentTraining,avant);
  }
  return true;
 }
 return {project,validate,execute,installHooks,...api,
  // Pour les tests : règles pures sur un état fourni.
  _tests:{repartition,cibles,salaireSemaine,niveauAttendu,avis,soigner,progresser,paie,assurer}};
}
// Seule la politique locale de confiance est recomposée ici (même procédé que staff-career.cjs) ; aucun texte de
// sauvegarde ou de requête n'est évalué.
const serializedFactory=Function('return ('+factory.toString().replace('function staffCompletionPolicy(){return null;}',require('./staff-completion.cjs').factory.toString())+')')();
module.exports={files,commands,factory:serializedFactory};

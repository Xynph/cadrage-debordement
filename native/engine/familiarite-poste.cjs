'use strict';
// Familiarité au poste (revue FM27, idée « familiarite », choix de Léo du 23/11/2026 : les étoiles de poste sont
// remplacées par la note au poste /100 et la familiarité Naturel / Confirmé / Correct / Dépanne / Inadapté).
//
// Une valeur de 0 à 20 par joueur et par maillot (1 à 15), enregistrée sur le joueur (p.familiarite), donne 5 niveaux :
//   Inadapté < 5 ≤ Dépanne < 10 ≤ Correct < 14 ≤ Confirmé < 18 ≤ Naturel.
// Le niveau règle l'efficacité au poste du moteur (position-aptitudes.cjs) : note au poste = note de rôle du poste ×
//   100 % (Naturel) / 96 % (Confirmé) / 88 % (Correct) / 76 % (Dépanne) / 60 % (Inadapté).
// Valeur de départ (création du joueur ou ancienne sauvegarde) déduite des postes actuels : Naturel 20 (poste
//   principal), Confirmé 16 (autre poste maîtrisé), Correct 12 (famille voisine), Dépanne 7 (même ligne), Inadapté 2
//   (autre ligne). 1re ligne (1 à 3) sans qualification : bloquée à 0, sans progression ; qualifié : Confirmé au moins.
// Progression : +1 par match joué au poste (+0,5 sous 40 minutes), +0,25 par semaine d'entraînement au poste, × 1,5
//   jusqu'à 23 ans, × 0,5 dès 31 ans ; au plus un palier gagné par mois et par poste. Poste travaillé à l'entraînement :
//   club du manager, le poste choisi sur la fiche (« Apprendre un poste », commande set_position_learning, une seule
//   cible, enregistrée en c ; sans cible, rien à l'entraînement, même s'il joue ailleurs le week-end) ; autres clubs, le
//   poste du dernier match joué hors de son poste principal.
// Oubli : −1 par 10 semaines sans y jouer ni s'y entraîner, jamais sous la valeur de départ.
// Enregistrement compact : {d: niveaux de départ (15 chiffres), k: niveaux actuels (15 chiffres, absent s'ils valent d), v: valeurs qui
//   diffèrent du départ {maillot: valeur}, o: semaines sans y jouer {maillot: n}, m: mois du dernier palier gagné
//   {maillot: 'AAAA-MM'}, p: dernier maillot joué hors poste principal, c: poste à apprendre choisi par le manager}. Aucun tirage au sort : tout est déterministe.
// Fonctions globales de la VM (installHooks) : CDFamiliarite.{niveaux, valeurs, RULES} lues par position-aptitudes.cjs.
const files=Object.freeze([]),commands=Object.freeze(['set_position_learning']);
function factory(){
 const SEUILS=[5,10,14,18],DEPART=[2,7,12,16,20],MULT=[.60,.76,.88,.96,1],MAX=20,PAS=.125;
 const MATCH=1,MATCH_COURT=.5,MINUTES_COURT=40,ENTRAINEMENT=.25;
 const JEUNE_AGE=23,JEUNE=1.5,VETERAN_AGE=31,VETERAN=.5,OUBLI_SEMAINES=10,OUBLI=1;
 const RULES=Object.freeze({SEUILS:Object.freeze(SEUILS.slice()),DEPART:Object.freeze(DEPART.slice()),MULT:Object.freeze(MULT.slice()),MAX,MATCH,MATCH_COURT,MINUTES_COURT,ENTRAINEMENT,JEUNE_AGE,JEUNE,VETERAN_AGE,VETERAN,OUBLI_SEMAINES,OUBLI});
 const CHIFFRES=/^[0-4]{15}$/;
 const niveau=v=>v>=SEUILS[3]?4:v>=SEUILS[2]?3:v>=SEUILS[1]?2:v>=SEUILS[0]?1:0;
 const facteurAge=age=>typeof age==='number'&&age<=JEUNE_AGE?JEUNE:typeof age==='number'&&age>=VETERAN_AGE?VETERAN:1;
 const arrondi=v=>Math.round(v*1000)/1000;
 // Structure des postes du joueur (position-aptitudes.cjs) : 15 niveaux de départ, -1 = 1re ligne non qualifiée.
 // Remplaçable pour les tests (structureDe).
 let structureDe=p=>nativePositionAptitudes.structure(p);
 const valide=r=>!!r&&typeof r==='object'&&typeof r.d==='string'&&CHIFFRES.test(r.d)&&(r.k===undefined||typeof r.k==='string'&&CHIFFRES.test(r.k));
 // Niveaux actuels : k, absent tant qu'ils valent ceux du départ (enregistrement plus court).
 const actuels=r=>r.k||r.d;
 function creer(structure){return {d:structure.map(s=>s<0?0:s).join('')};}
 function assurer(p,structure){if(!valide(p.familiarite))p.familiarite=creer(structure||structureDe(p));return p.familiarite;}
 // Valeur enregistrée au maillot n (1-15), sans les règles de blocage.
 const brute=(r,n)=>r.v&&typeof r.v[n]==='number'?r.v[n]:DEPART[+r.d[n-1]];
 // Plancher au maillot : valeur de départ ; 1re ligne qualifiée hors poste principal : Confirmé au moins.
 const plancher=(r,n,s)=>Math.max(DEPART[+r.d[n-1]],n<=3&&s>=3?DEPART[3]:0);
 // Niveaux effectifs (15 entiers, -1 = bloqué) : poste principal toujours Naturel, 1re ligne selon la qualification.
 function niveaux(p,structure){
  const r=valide(p?.familiarite)?p.familiarite:null;
  return structure.map((s,i)=>{
   if(s<0)return -1;
   if(s===4)return 4;
   const l=r?+actuels(r)[i]:s;
   return i<3?Math.max(3,l):l;
  });
 }
 // Valeurs effectives (15 nombres 0-20) cohérentes avec niveaux().
 function valeurs(p,structure){
  const r=valide(p?.familiarite)?p.familiarite:null;
  return structure.map((s,i)=>{
   if(s<0)return 0;
   if(s===4)return MAX;
   const v=r?brute(r,i+1):DEPART[s];
   return i<3?Math.max(DEPART[3],v):v;
  });
 }
 function poser(r,n,valeur,s){
  const v=arrondi(Math.max(plancher(r,n,s),Math.min(MAX,valeur)));
  if(v===DEPART[+r.d[n-1]]){if(r.v){delete r.v[n];if(!Object.keys(r.v).length)delete r.v;}if(r.o){delete r.o[n];if(!Object.keys(r.o).length)delete r.o;}}
  else (r.v||(r.v={}))[n]=v;
  const k=actuels(r),nk=k.slice(0,n-1)+niveau(v)+k.slice(n);
  if(nk===r.d)delete r.k;else r.k=nk;
  return v;
 }
 const repos=(r,n)=>{if(r.o&&r.o[n]!==undefined){delete r.o[n];if(!Object.keys(r.o).length)delete r.o;}};
 // Gain au maillot n : montant de base (avant l'âge), mois courant ('AAAA-MM'). Renvoie la nouvelle valeur, ou null
 // quand le poste ne progresse pas (poste principal, 1re ligne non qualifiée).
 function gagner(p,n,montant,mois){
  if(!p||!(n>=1&&n<=15))return null;
  const structure=structureDe(p),s=structure[n-1];
  if(s<0||s===4)return null;
  const r=assurer(p,structure);
  repos(r,n);
  const actuelle=Math.max(brute(r,n),plancher(r,n,s));
  if(actuelle>=MAX)return actuelle;
  let v=Math.min(MAX,actuelle+montant*facteurAge(p.age));
  const l0=niveau(actuelle),l1=niveau(v);
  if(l1>l0){
   r.m=r.m||{};
   if(r.m[n]===mois)v=Math.max(actuelle,SEUILS[l0]-PAS); // palier déjà gagné ce mois-ci : on reste sous le seuil
   else{if(l1>l0+1)v=l0+1===4?MAX:SEUILS[l0+1]-PAS;r.m[n]=mois;}
  }
  return poser(r,n,v,s);
 }
 // Semaine : entraînement au poste puis oubli des postes non joués. `entrainement` : maillot ou null.
 function semaine(p,entrainement,mois,blesse=false){
  const structure=structureDe(p),r=assurer(p,structure);
  if(entrainement&&!blesse)gagner(p,entrainement,ENTRAINEMENT,mois);
  if(!r.v)return;
  for(const cle of Object.keys(r.v)){
   const n=+cle;if(n===entrainement&&!blesse)continue;
   const s=structure[n-1];
   if(s===4||s<0){poser(r,n,DEPART[+r.d[n-1]],s);repos(r,n);continue;}
   const o=((r.o&&r.o[n])||0)+1;
   if(o>=OUBLI_SEMAINES){repos(r,n);poser(r,n,brute(r,n)-OUBLI,s);}
   else (r.o||(r.o={}))[n]=o;
  }
 }
 // Match : un joueur a tenu le maillot n pendant `minutes`.
 function match(p,n,minutes,mois){
  if(!p||!(n>=1&&n<=15)||!(minutes>0))return null;
  const structure=structureDe(p),r=assurer(p,structure),s=structure[n-1];
  if(s===4){delete r.p;return null;}
  if(s<0)return null;
  r.p=n;
  return gagner(p,n,minutes<MINUTES_COURT?MATCH_COURT:MATCH,mois);
 }
 function moisCourant(){
  try{if(typeof CDWorldCareer!=='undefined'&&CDWorldCareer.active(S))return CDWorldCareer.calendarToday(S).slice(0,7);}catch(e){}
  return 'S'+(S?.season??0)+'-'+Math.floor((S?.worldMode?.week??S?.week??0)/4);
 }
 function* joueurs(s){
  for(const c of Object.values(s?.clubs||{}))for(const p of c?.players||[])yield p;
  for(const p of s?.economy?.freeAgents||[])yield p;
  for(const p of Array.isArray(s?.market)?s.market:[])yield p;
 }
 // Enregistre la familiarité des joueurs qui ne l'ont pas encore (création, ancienne sauvegarde).
 function observe(){
  if(typeof S==='undefined'||!S)return 0;
  let n=0;
  for(const p of joueurs(S)){if(p&&typeof p==='object'&&!valide(p.familiarite)){assurer(p);n++;}}
  return n;
 }
 // Semaine d'entraînement (avant trainWeek, qui soigne les blessés) : tous les joueurs des clubs.
 function apresSemaine(){
  if(typeof S==='undefined'||!S)return;
  const mois=moisCourant();
  for(const c of Object.values(S.clubs||{})){
   const nous=c&&c.id===S.club;
   for(const p of c?.players||[]){
    if(!p||typeof p!=='object')continue;
    const r=valide(p.familiarite)?p.familiarite:null;
    semaine(p,(nous?r&&r.c:r&&r.p)||null,mois,!!p.injury);
   }
  }
 }
 function apresMatch(l){
  if(!l||!Array.isArray(l.sheets)||typeof matchPlayer!=='function')return;
  const mois=moisCourant();
  for(let side=0;side<2;side++){
   const s=l.sheets[side];if(!s)continue;
   for(const id of s.used||[]){
    const p=matchPlayer(l,side,id);if(!p)continue;
    const minutes=Math.max(0,(s.minutes?.[id]||0)-(l.devBaseline?.[side]?.[id]||0));if(!minutes)continue;
    let slot=Array.isArray(s.on)?s.on.indexOf(id):-1;
    if(slot<0&&Array.isArray(s.initial))slot=s.initial.indexOf(id);
    if(slot>=0&&slot<15)match(p,slot+1,minutes,mois);
   }
  }
 }
 function validate(s){
  for(const p of joueurs(s)){
   const r=p?.familiarite;if(r===undefined)continue;
   const ok=valide(r)&&Object.keys(r).every(k=>['d','k','v','o','m','p','c'].includes(k))
    &&(r.v===undefined||r.v&&typeof r.v==='object'&&Object.entries(r.v).every(([n,v])=>+n>=1&&+n<=15&&typeof v==='number'&&v>=0&&v<=MAX))
    &&(r.o===undefined||r.o&&typeof r.o==='object'&&Object.entries(r.o).every(([n,v])=>+n>=1&&+n<=15&&Number.isInteger(v)&&v>=0&&v<OUBLI_SEMAINES))
    &&(r.m===undefined||r.m&&typeof r.m==='object'&&Object.entries(r.m).every(([n,v])=>+n>=1&&+n<=15&&typeof v==='string'&&v.length<=12))
    &&(r.p===undefined||Number.isInteger(r.p)&&r.p>=1&&r.p<=15)
    &&(r.c===undefined||Number.isInteger(r.c)&&r.c>=1&&r.c<=15);
   if(!ok)throw Error('Familiarité au poste invalide.');
  }
  return true;
 }
 // « Apprendre un poste » (fiche joueur) : une seule cible par joueur ; null/0 arrête. Ni poste principal, ni 1re
 // ligne sans qualification.
 function apprendre(p,numero){
  const structure=structureDe(p),r=assurer(p,structure);
  if(numero===null||numero===undefined||numero===0){delete r.c;return null;}
  if(!(Number.isInteger(numero)&&numero>=1&&numero<=15))throw Error('Poste à apprendre invalide.');
  const s=structure[numero-1];
  if(s===4)throw Error('Poste déjà naturel pour ce joueur.');
  if(s<0)throw Error('Première ligne : qualification requise.');
  r.c=numero;return numero;
 }
 function execute(command,payload){
  if(command!=='set_position_learning')throw Error('Commande de familiarité inconnue.');
  if(typeof S==='undefined'||!S||S.live&&!S.live.finished)throw Error('Apprendre un poste : indisponible pendant un match.');
  const club=S.clubs?.[S.club],p=club?.players?.find(x=>x.id===payload?.playerId);
  if(!p)throw Error('Apprendre un poste : joueur absent de ton effectif.');
  apprendre(p,payload.numero??null);
 }
 const api=Object.freeze({RULES,niveau,niveaux,valeurs,facteurAge});
 let installe=false;
 function installHooks(){
  globalThis.CDFamiliarite=api;
  if(installe)return true;installe=true;
  if(typeof trainWeek==='function'){
   const avant=trainWeek;
   trainWeek=function(){if(typeof S!=='undefined'&&S&&!S.trained)apresSemaine();return avant.apply(this,arguments);};
   Object.assign(trainWeek,avant);
  }
  if(typeof recordDevelopmentMatch==='function'){
   const avant=recordDevelopmentMatch;
   recordDevelopmentMatch=function(l){const premier=!!l&&!l.developmentRecorded,r=avant.apply(this,arguments);if(premier&&l.developmentRecorded)apresMatch(l);return r;};
   Object.assign(recordDevelopmentMatch,avant);
  }
  return true;
 }
 return {project(){return null;},validate,execute,installHooks,observe,
  // Pour les tests : règles pures sur un joueur, structure fournie.
  _tests:{gagner,semaine,match,creer,assurer,niveaux,valeurs,niveau,apresSemaine,apresMatch,moisCourant,apprendre,fixerStructure(f){structureDe=f;}},
  ...api};
}
module.exports={files,commands,factory};

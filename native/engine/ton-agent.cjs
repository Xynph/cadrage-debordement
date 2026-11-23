'use strict';
// Discussion avec l'agent d'une piste du marché (revue FM27, idée 24 ; choix de Léo du 23/11/2026) : même fenêtre que la
// discussion avec un joueur (idée 23). L'agent n'a pas de nom. On lui donne un ton, qui pèse sur la négociation de la
// journée avec ce joueur (recrue seulement) :
//  - À tout prix : demande +6 %, 4 propositions avant la rupture, relation avec l'agent +2 ;
//  - Enthousiaste : demande inchangée, 3 propositions, relation +1 ;
//  - Curieux : demande −3 %, 2 propositions, relation −1.
// Un ton par piste et par journée (S.economy.week), choisi avant la première proposition de la journée ; il ne se change
// plus ensuite. La demande (askingWage, donc aussi le minimum accepté reservationWage) suit l'écart.
// Relation avec l'agent : gardée d'une journée et d'une saison à l'autre, bornée à ±10, en 5 crans à l'écran (Froide ≤ −6
// < Distante ≤ −2 < Neutre < 2 ≤ Bonne < 6 ≤ Proche). Elle pèse aussi, en plus du ton (écarts additionnés) :
//  - Proche : demande −5 %, +1 proposition, minimum accepté −4 % ;
//  - Bonne : demande −2 %, minimum accepté −2 % ;
//  - Neutre : rien ;
//  - Distante : demande +3 %, minimum accepté +2 % ;
//  - Froide : demande +6 %, −1 proposition (au moins 1), minimum accepté +5 %.
// Elle évolue selon l'issue : accord +1 ; offre ridicule (moins de 70 % de la demande, une fois par journée) −1 ; rupture −1.
// Propositions (1 à 5) réglées autour de negotiateContract (gestion.cjs, commande recruit) sans toucher au format des talks
// (attempts reste entre 1 et 3 dans la sauvegarde) : le vrai compte de la journée est gardé dans S.tonAgent.jours.
// Sauvegarde : S.tonAgent = {version:1, tons:{id:{ton, saison, semaine}}, relations:{id: entier},
//  jours?:{id:{saison, semaine, n, vexe}}}.
// Commande : agent_ton {playerId, ton}. Projection : market[].agent (model.cjs) par tonAgentVue(id).
// Fonctions globales de la VM : tonAgentVue(id), tonAgentEssais(id), tonAgentNegocier(id, kind, fn, salaire).
const files=Object.freeze([]),commands=Object.freeze(['agent_ton']);
function factory(){
 const TONS=Object.freeze({
  tout_prix:Object.freeze({ecart:6,essais:4,relation:2}),
  enthousiaste:Object.freeze({ecart:0,essais:3,relation:1}),
  curieux:Object.freeze({ecart:-3,essais:2,relation:-1})});
 // Effet de chaque cran de relation (Froide, Distante, Neutre, Bonne, Proche) : demande (%), propositions, minimum accepté (%).
 const EFFETS=Object.freeze([
  Object.freeze({demande:6,essais:-1,seuil:5}),
  Object.freeze({demande:3,essais:0,seuil:2}),
  Object.freeze({demande:0,essais:0,seuil:0}),
  Object.freeze({demande:-2,essais:0,seuil:-2}),
  Object.freeze({demande:-5,essais:1,seuil:-4})]);
 const ESSAIS_BASE=3,ESSAIS_MIN=1,ESSAIS_MAX=5,BORNE=10,MAX_RELATIONS=400,RIDICULE=.7;
 const MOTS=Object.freeze(['','une','deux','trois','quatre','cinq']);
 const CRANS=Object.freeze([-6,-2,2,6]);
 const vm=()=>typeof S==='undefined'?null:S;
 const entier=x=>Number.isSafeInteger(x);
 // Cran 0..4 d'une relation (Froide, Distante, Neutre, Bonne, Proche).
 function cran(r){const v=Number(r)||0;return v<=CRANS[0]?0:v<=CRANS[1]?1:v<CRANS[2]?2:v<CRANS[3]?3:4;}
 const effet=r=>EFFETS[cran(r)];
 const borne=v=>Math.max(-BORNE,Math.min(BORNE,v));
 const tonValide=t=>!!t&&typeof t==='object'&&Object.keys(t).length===3&&Object.hasOwn(TONS,t.ton)&&entier(t.saison)&&entier(t.semaine);
 const jourValide=j=>!!j&&typeof j==='object'&&Object.keys(j).length===4&&entier(j.saison)&&entier(j.semaine)
  &&entier(j.n)&&j.n>=0&&j.n<=ESSAIS_MAX&&typeof j.vexe==='boolean';
 const dico=(x,ok)=>!!x&&typeof x==='object'&&!Array.isArray(x)&&Object.keys(x).length<=MAX_RELATIONS&&Object.entries(x).every(([id,v])=>id.length<=180&&ok(v));
 const etatValide=e=>!!e&&typeof e==='object'&&Object.keys(e).every(k=>['version','tons','relations','jours'].includes(k))&&e.version===1
  &&dico(e.tons,tonValide)&&dico(e.relations,r=>entier(r)&&r>=-BORNE&&r<=BORNE)&&(e.jours===undefined||dico(e.jours,jourValide));
 function etat(ecrire,s=vm()){
  if(etatValide(s?.tonAgent))return s.tonAgent;
  const neuf={version:1,tons:{},relations:{}};if(ecrire&&s)s.tonAgent=neuf;return neuf;
 }
 const semaine=s=>s?.economy?.week??s?.round??0;
 const duJour=(x,s)=>!!x&&x.saison===s.season&&x.semaine===semaine(s);
 // Ton de la journée en cours pour ce joueur ('' sinon).
 function ton(id,s=vm()){
  const t=s?.tonAgent?.tons?.[id];
  return t&&tonValide(t)&&duJour(t,s)?t.ton:'';
 }
 const relation=(id,s=vm())=>{const r=s?.tonAgent?.relations?.[id];return entier(r)?r:0;};
 // Propositions de la journée : ton (ou 3) + effet de la relation, entre 1 et 5.
 const essais=(id,s=vm())=>Math.max(ESSAIS_MIN,Math.min(ESSAIS_MAX,(TONS[ton(id,s)]?.essais??ESSAIS_BASE)+effet(relation(id,s)).essais));
 const cleTalk=(id,s)=>String(s.season)+':'+String(semaine(s))+':recruit:'+id;
 const talkDuJour=(id,s=vm())=>s?.economy?.talks?.[cleTalk(id,s)];
 const talkEnCours=(id,s=vm())=>!!talkDuJour(id,s);
 const jour=(id,s)=>{const j=s?.tonAgent?.jours?.[id];return j&&jourValide(j)&&duJour(j,s)?j:null;};
 // Propositions déjà faites cette journée (vrai compte, au-delà des 3 du moteur).
 function faites(id,s=vm()){
  const t=talkDuJour(id,s);if(!t)return 0;
  const j=jour(id,s);return j?j.n:Math.max(0,Math.min(ESSAIS_BASE,Number(t.attempts)||0));
 }
 const ecartTotal=id=>(TONS[ton(id)]?.ecart||0)+effet(relation(id)).demande;
 // Demande avec l'écart du ton et de la relation (arrondie à la dizaine, au moins 10 € d'écart).
 function demande(base,p,kind){
  if(kind!=='recruit'||!p||typeof p.id!=='string'||!Number.isFinite(base))return base;
  const e=ecartTotal(p.id);if(!e)return base;
  const v=Math.round(base*(100+e)/1000)*10;
  return v===base?base+(e>0?10:-10):v;
 }
 // Minimum accepté (seuil) selon la relation, arrondi à la centaine supérieure.
 function seuil(base,p,kind){
  if(kind!=='recruit'||!p||typeof p.id!=='string'||!Number.isFinite(base))return base;
  const e=effet(relation(p.id)).seuil;if(!e)return base;
  return Math.ceil(base*(100+e)/10000)*100;
 }
 // Vue de l'écran (market[].agent). effet : ce que la relation change (demande %, propositions, minimum %).
 function vue(id,s=vm()){
  if(!s)return null;
  const t=ton(id,s),r=relation(id,s),d=TONS[t];
  return {ton:t,essais:essais(id,s),ecart:d?d.ecart:0,relation:r,cran:cran(r),avant:d?borne(r-d.relation):r,
   effet:{...effet(r)},faites:faites(id,s),libre:!t&&!talkEnCours(id,s)&&!s.live};
 }
 const euros=v=>Math.round(v).toLocaleString('fr-FR')+' €';
 // Relation remise en fin de liste (les plus anciennes sortent au-delà de MAX_RELATIONS).
 function changerRelation(id,delta,s=vm()){
  if(!delta||!s)return;
  const e=etat(true,s),avant=relation(id,s);
  if(Object.hasOwn(e.relations,id))delete e.relations[id];
  const ids=Object.keys(e.relations);if(ids.length>=MAX_RELATIONS)for(const k of ids.slice(0,ids.length-MAX_RELATIONS+1))delete e.relations[k];
  e.relations[id]=borne(avant+delta);
 }
 function noterJour(id,n,vexe,s){
  const e=etat(true,s);if(!e.jours)e.jours={};
  for(const [k,j] of Object.entries(e.jours))if(!duJour(j,s))delete e.jours[k];
  e.jours[id]={saison:s.season,semaine:semaine(s),n,vexe};
 }
 // Négociation d'une recrue : propositions selon le ton et la relation (1 à 5 au lieu de 3), relation selon l'issue.
 function negocier(id,kind,fn,salaire){
  const s=vm();
  if(!s||kind!=='recruit'||typeof id!=='string')return fn();
  const max=essais(id,s),key=cleTalk(id,s),avant=s.economy?.talks?.[key],deja=faites(id,s),j=jour(id,s);
  const p=Array.isArray(s.market)?s.market.find(x=>x&&x.id===id):null;
  const ridicule=!!p&&Number.isFinite(salaire)&&typeof askingWage==='function'&&salaire<askingWage(p,'recruit')*RIDICULE;
  // Au-delà de la 3e : la 3e contre-offre reste ouverte, le moteur compte cet essai comme le 3e.
  const suite=deja>=ESSAIS_BASE&&deja<max&&avant?.status==='counter'&&avant.attempts===ESSAIS_BASE;
  if(suite)avant.attempts=ESSAIS_BASE-1;
  let ok;
  try{ok=fn();}finally{if(suite&&s.economy.talks[key]===avant)avant.attempts=ESSAIS_BASE;}
  const t=s.economy.talks[key];
  if(!ok||!t||t===avant)return ok;
  const n=deja+1;
  if(t.status==='counter'||t.status==='withdrawn'){
   if(n>=max){
    if(t.status!=='withdrawn'||n!==ESSAIS_BASE){
     t.status='withdrawn';
     t.message=(n===1?'La proposition a échoué.':`Les ${MOTS[n]} propositions ont échoué.`)+' Le joueur met fin aux échanges pour cette journée.';
    }
   }else if(t.status==='withdrawn'){
    t.status='counter';t.message=`Le joueur refuse et demande ${euros(t.acceptedSalary)} par semaine sur ${t.years} saison(s). Proposition ${n}/${max}.`;
   }else t.message=String(t.message).replace(/\d+\/3\.$/,n+'/'+max+'.');
  }
  const vexe=ridicule&&!j?.vexe;
  noterJour(id,n,!!j?.vexe||vexe,s);
  changerRelation(id,(t.status==='ready'||t.status==='signed'?1:0)+(vexe?-1:0)+(t.status==='withdrawn'?-1:0),s);
  return ok;
 }
 function choisir(payload){
  const s=vm();if(!s)throw Error('Aucune carrière.');
  if(s.live&&!s.live.finished)throw Error('Agent : indisponible pendant un match.');
  const id=payload?.playerId,choix=payload?.ton;
  if(typeof id!=='string'||!Array.isArray(s.market)||!s.market.some(p=>p&&p.id===id))throw Error('Agent : joueur absent du marché.');
  if(!Object.hasOwn(TONS,choix))throw Error('Agent : ton inconnu.');
  if(ton(id,s))throw Error('Agent : ton déjà donné pour cette journée.');
  if(talkEnCours(id,s))throw Error('Agent : négociation déjà commencée cette journée.');
  const e=etat(true,s),sem=semaine(s);
  for(const [k,t] of Object.entries(e.tons))if(!(t.saison===s.season&&t.semaine===sem))delete e.tons[k];
  e.tons[id]={ton:choix,saison:s.season,semaine:sem};
  changerRelation(id,TONS[choix].relation,s);
  return undefined;
 }
 function execute(command,payload){
  if(command!=='agent_ton')throw Error('Commande d’agent inconnue.');
  return choisir(payload);
 }
 function validate(s){
  if(s&&s.tonAgent!==undefined&&!etatValide(s.tonAgent))throw Error('Discussion avec l’agent invalide.');
  return true;
 }
 let installe=false;
 function installHooks(){
  globalThis.tonAgentVue=id=>vue(id);
  globalThis.tonAgentEssais=id=>essais(id);
  globalThis.tonAgentNegocier=(id,kind,fn,salaire)=>negocier(id,kind,fn,salaire);
  if(installe)return true;installe=true;
  if(typeof askingWage==='function'){
   const ask=askingWage;
   askingWage=function(p,kind){return demande(ask.apply(this,arguments),p,kind);};
   Object.assign(askingWage,ask);
  }
  if(typeof reservationWage==='function'){
   const reserve=reservationWage;
   reservationWage=function(p,kind){return seuil(reserve.apply(this,arguments),p,kind);};
   Object.assign(reservationWage,reserve);
  }
  return true;
 }
 return {project(){return null;},validate,execute,installHooks,TONS,EFFETS,ESSAIS_BASE,BORNE,RIDICULE,cran,effet,ton,relation,essais,faites,vue,demande,seuil,negocier,etatValide};
}
const pur=factory();
module.exports={files,commands,factory,TONS:pur.TONS,EFFETS:pur.EFFETS,RIDICULE:pur.RIDICULE,cran:pur.cran,effet:pur.effet,etatValide:pur.etatValide};

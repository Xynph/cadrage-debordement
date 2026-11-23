'use strict';
// Discussion avec l'agent d'une piste du marché (revue FM27, idée 24 ; choix de Léo du 23/11/2026) : même fenêtre que la
// discussion avec un joueur (idée 23). L'agent n'a pas de nom. On lui donne un ton, qui pèse sur la négociation de la
// journée avec ce joueur (recrue seulement) :
//  - À tout prix : demande +6 %, 4 propositions avant la rupture, relation avec l'agent +2 ;
//  - Enthousiaste : demande inchangée, 3 propositions, relation +1 ;
//  - Curieux : demande −3 %, 2 propositions, relation −1.
// Un ton par piste et par journée (S.economy.week), choisi avant la première proposition de la journée ; il ne se change
// plus ensuite. La demande (askingWage, donc aussi le minimum accepté reservationWage) suit l'écart. Le nombre de
// propositions est réglé autour de negotiateContract (gestion.cjs, commande recruit) sans toucher au format des talks
// (attempts reste entre 1 et 3 dans la sauvegarde) : 4e essai = le 3e compté une seconde fois ; 2 essais = rupture
// après la 2e contre-offre.
// Relation avec l'agent : gardée d'une journée et d'une saison à l'autre, bornée à ±10, en 5 crans à l'écran (Froide ≤ −6
// < Distante ≤ −2 < Neutre < 2 ≤ Bonne < 6 ≤ Proche).
// Sauvegarde : S.tonAgent = {version:1, tons:{id:{ton, saison, semaine}}, relations:{id: entier}}.
// Commande : agent_ton {playerId, ton}. Projection : market[].agent (model.cjs) par tonAgentVue(id).
// Fonctions globales de la VM : tonAgentVue(id), tonAgentEssais(id), tonAgentNegocier(id, kind, fn).
const files=Object.freeze([]),commands=Object.freeze(['agent_ton']);
function factory(){
 const TONS=Object.freeze({
  tout_prix:Object.freeze({ecart:6,essais:4,relation:2}),
  enthousiaste:Object.freeze({ecart:0,essais:3,relation:1}),
  curieux:Object.freeze({ecart:-3,essais:2,relation:-1})});
 const ESSAIS_BASE=3,BORNE=10,MAX_RELATIONS=400;
 const CRANS=Object.freeze([-6,-2,2,6]);
 const vm=()=>typeof S==='undefined'?null:S;
 const entier=x=>Number.isSafeInteger(x);
 // Cran 0..4 d'une relation (Froide, Distante, Neutre, Bonne, Proche).
 function cran(r){const v=Number(r)||0;return v<=CRANS[0]?0:v<=CRANS[1]?1:v<CRANS[2]?2:v<CRANS[3]?3:4;}
 const borne=v=>Math.max(-BORNE,Math.min(BORNE,v));
 const tonValide=t=>!!t&&typeof t==='object'&&Object.keys(t).length===3&&Object.hasOwn(TONS,t.ton)&&entier(t.saison)&&entier(t.semaine);
 const etatValide=e=>!!e&&typeof e==='object'&&Object.keys(e).every(k=>['version','tons','relations'].includes(k))&&e.version===1
  &&e.tons&&typeof e.tons==='object'&&!Array.isArray(e.tons)&&Object.entries(e.tons).every(([id,t])=>id.length<=180&&tonValide(t))
  &&e.relations&&typeof e.relations==='object'&&!Array.isArray(e.relations)&&Object.keys(e.relations).length<=MAX_RELATIONS
  &&Object.entries(e.relations).every(([id,r])=>id.length<=180&&entier(r)&&r>=-BORNE&&r<=BORNE);
 function etat(ecrire,s=vm()){
  if(etatValide(s?.tonAgent))return s.tonAgent;
  const neuf={version:1,tons:{},relations:{}};if(ecrire&&s)s.tonAgent=neuf;return neuf;
 }
 const semaine=s=>s?.economy?.week??s?.round??0;
 // Ton de la journée en cours pour ce joueur ('' sinon).
 function ton(id,s=vm()){
  const t=s?.tonAgent?.tons?.[id];
  return t&&tonValide(t)&&t.saison===s.season&&t.semaine===semaine(s)?t.ton:'';
 }
 const relation=(id,s=vm())=>{const r=s?.tonAgent?.relations?.[id];return entier(r)?r:0;};
 const essais=id=>TONS[ton(id)]?.essais??ESSAIS_BASE;
 const cleTalk=(id,s)=>String(s.season)+':'+String(semaine(s))+':recruit:'+id;
 const talkEnCours=(id,s=vm())=>!!s?.economy?.talks?.[cleTalk(id,s)];
 // Demande avec l'écart du ton (arrondie à la dizaine, au moins 10 € d'écart).
 function demande(base,p,kind){
  if(kind!=='recruit'||!p||typeof p.id!=='string'||!Number.isFinite(base))return base;
  const e=TONS[ton(p.id)]?.ecart||0;if(!e)return base;
  const v=Math.round(base*(1+e/100)/10)*10;
  return v===base?base+(e>0?10:-10):v;
 }
 // Vue de l'écran (market[].agent).
 function vue(id,s=vm()){
  if(!s)return null;
  const t=ton(id,s),r=relation(id,s),d=TONS[t];
  return {ton:t,essais:d?d.essais:ESSAIS_BASE,ecart:d?d.ecart:0,relation:r,cran:cran(r),avant:d?borne(r-d.relation):r,
   libre:!t&&!talkEnCours(id,s)&&!s.live};
 }
 const euros=v=>Math.round(v).toLocaleString('fr-FR')+' €';
 // Négociation d'une recrue avec le ton de la journée : 4 ou 2 propositions au lieu de 3.
 function negocier(id,kind,fn){
  const s=vm(),max=kind==='recruit'?essais(id):ESSAIS_BASE;
  if(!s||max===ESSAIS_BASE)return fn();
  const key=cleTalk(id,s),avant=s.economy?.talks?.[key];
  // 4e proposition : la 3e contre-offre reste ouverte, le moteur compte cet essai comme le 3e.
  const quatrieme=max===4&&avant?.status==='counter'&&avant.attempts===3;
  if(quatrieme)avant.attempts=2;
  let ok;
  try{ok=fn();}finally{if(quatrieme&&s.economy.talks[key]===avant)avant.attempts=3;}
  const t=s.economy.talks[key];
  if(!ok||!t||t===avant)return ok;
  if(max===4){
   if(quatrieme&&t.status==='withdrawn')t.message='Les quatre propositions ont échoué. Le joueur met fin aux échanges pour cette journée.';
   else if(!quatrieme&&t.status==='withdrawn'&&t.attempts===3){t.status='counter';t.message=`Le joueur refuse et demande ${euros(t.acceptedSalary)} par semaine sur ${t.years} saison(s). Proposition 3/4.`;}
   else if(t.status==='counter')t.message=String(t.message).replace(/\/3\.$/,'/4.');
  }else if(max===2&&t.status==='counter'){
   if(t.attempts>=2){t.status='withdrawn';t.message='Les deux propositions ont échoué. Le joueur met fin aux échanges pour cette journée.';}
   else t.message=String(t.message).replace(/\/3\.$/,'/2.');
  }
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
  // Relation remise en fin de liste (les plus anciennes sortent au-delà de MAX_RELATIONS).
  const avant=relation(id,s);
  if(Object.hasOwn(e.relations,id))delete e.relations[id];
  const ids=Object.keys(e.relations);if(ids.length>=MAX_RELATIONS)for(const k of ids.slice(0,ids.length-MAX_RELATIONS+1))delete e.relations[k];
  e.relations[id]=borne(avant+TONS[choix].relation);
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
  globalThis.tonAgentNegocier=(id,kind,fn)=>negocier(id,kind,fn);
  if(installe)return true;installe=true;
  if(typeof askingWage==='function'){
   const ask=askingWage;
   askingWage=function(p,kind){return demande(ask.apply(this,arguments),p,kind);};
   Object.assign(askingWage,ask);
  }
  return true;
 }
 return {project(){return null;},validate,execute,installHooks,TONS,ESSAIS_BASE,BORNE,cran,ton,relation,essais,vue,demande,negocier,etatValide};
}
const pur=factory();
module.exports={files,commands,factory,TONS:pur.TONS,cran:pur.cran,etatValide:pur.etatValide};

'use strict';
// Discussion avec l'agent d'une piste du marché (revue FM27, idée 24 ; choix de Léo du 23/11/2026, retouche « incertitude ») :
// même fenêtre que la discussion avec un joueur (idée 23). L'agent n'a pas de nom. Rien de chiffré n'est montré au manager :
// le ton, la relation et le caractère font PENCHER la négociation en moyenne, sans rien garantir.
//  - Ton (un par piste et par journée, avant la première proposition) : À tout prix (demande plus haute, agent plus patient,
//    relation +2), Enthousiaste (relation +1), Curieux (demande plus basse, agent moins patient, relation −1).
//  - Relation avec l'agent : gardée d'une journée et d'une saison à l'autre, bornée à ±10, 5 crans à l'écran (Froide ≤ −6
//    < Distante ≤ −2 < Neutre < 2 ≤ Bonne < 6 ≤ Proche) ; elle pèse sur la demande, la patience et le minimum accepté.
//    Issue : accord +1 ; offre ridicule (moins de 70 % de la demande, une fois par journée) −1 ; rupture −1.
//  - Caractère caché de l'agent (Gourmand, Pressé, Fidèle à son joueur, Joueur de poker, Arrangeant) : tiré au sort par
//    la graine du monde et l'identifiant du joueur, gardé dans la sauvegarde dès qu'on parle à l'agent ou qu'on négocie.
//    Il module demande, patience et minimum. Le manager peut découvrir le MOT (jamais ses effets) : au 2e tour de la
//    discussion (commande agent_question), dès une première négociation avec lui (pour toujours), ou si le recruteur a observé
//    le joueur.
//  - Hasard de la journée (graine du monde, saison, semaine, joueur) : demande ±4 %, minimum ±3 %, patience −1/0/+1.
//  - Patience cachée (2 à 5 propositions : jamais de rupture dès la 1re) : seul indice, l'humeur de l'agent (calme, agacé, tendu ; brouillée une fois sur
//    trois vers plus tendu) et ses répliques qui se durcissent.
// Propositions réglées autour de negotiateContract (gestion.cjs, commande recruit) sans toucher au format des talks
// (attempts reste entre 1 et 3 dans la sauvegarde) : le vrai compte de la journée est gardé dans S.tonAgent.jours.
// Sauvegarde : S.tonAgent = {version:1, tons:{id:{ton, saison, semaine}}, relations:{id: entier},
//  jours?:{id:{saison, semaine, n, vexe}}, agents?:{id:{car, connu}}}.
// Commandes : agent_ton {playerId, ton}, agent_question {playerId}. Projection : market[].agent (model.cjs) par tonAgentVue(id).
// Fonctions globales de la VM : tonAgentVue(id), tonAgentNegocier(id, kind, fn, salaire).
const files=Object.freeze([]),commands=Object.freeze(['agent_ton','agent_question']);
function factory(){
 // Tendances (moteur seulement, jamais affichées) : écart de demande (%), patience (propositions), relation.
 const TONS=Object.freeze({
  tout_prix:Object.freeze({ecart:6,patience:1,relation:2}),
  enthousiaste:Object.freeze({ecart:0,patience:0,relation:1}),
  curieux:Object.freeze({ecart:-3,patience:-1,relation:-1})});
 // Effet de chaque cran de relation (Froide, Distante, Neutre, Bonne, Proche) : demande (%), patience, minimum accepté (%).
 const EFFETS=Object.freeze([
  Object.freeze({demande:6,patience:-1,seuil:5}),
  Object.freeze({demande:3,patience:0,seuil:2}),
  Object.freeze({demande:0,patience:0,seuil:0}),
  Object.freeze({demande:-2,patience:0,seuil:-2}),
  Object.freeze({demande:-5,patience:1,seuil:-4})]);
 // Caractères cachés : mot affiché une fois découvert, effets jamais montrés.
 const CARACTERES=Object.freeze({
  gourmand:Object.freeze({mot:'Gourmand',demande:5,patience:0,seuil:3}),
  presse:Object.freeze({mot:'Pressé',demande:0,patience:-1,seuil:-2}),
  fidele:Object.freeze({mot:'Fidèle à son joueur',demande:2,patience:1,seuil:2}),
  poker:Object.freeze({mot:'Joueur de poker',demande:7,patience:0,seuil:-3}),
  arrangeant:Object.freeze({mot:'Arrangeant',demande:-3,patience:1,seuil:-2})});
 const LISTE=Object.freeze(Object.keys(CARACTERES));
 const PATIENCE_BASE=3,PATIENCE_MIN=2,PATIENCE_MAX=5,BORNE=10,MAX_RELATIONS=400,RIDICULE=.7,BRUIT_DEMANDE=4,BRUIT_SEUIL=3;
 const HUMEURS=Object.freeze(['calme','agace','tendu']);
 const CRANS=Object.freeze([-6,-2,2,6]);
 const vm=()=>typeof S==='undefined'?null:S;
 const entier=x=>Number.isSafeInteger(x);
 // FNV-1a 32 bits (comme seedHash de dist/rugby.js), pour que le module pur tourne aussi hors de la VM.
 function hache(texte){let h=0x811c9dc5;for(const c of String(texte)){h^=c.codePointAt(0);h=Math.imul(h,0x01000193)>>>0;}return h>>>0;}
 const graine=s=>Number.isInteger(s?.careerVariation?.seed)?s.careerVariation.seed:0;
 // Tirage dans [-n, n] pour une clé de la journée.
 const tirage=(cle,n)=>hache(cle)%(2*n+1)-n;
 // Cran 0..4 d'une relation (Froide, Distante, Neutre, Bonne, Proche).
 function cran(r){const v=Number(r)||0;return v<=CRANS[0]?0:v<=CRANS[1]?1:v<CRANS[2]?2:v<CRANS[3]?3:4;}
 const effet=r=>EFFETS[cran(r)];
 const borne=v=>Math.max(-BORNE,Math.min(BORNE,v));
 const tonValide=t=>!!t&&typeof t==='object'&&Object.keys(t).length===3&&Object.hasOwn(TONS,t.ton)&&entier(t.saison)&&entier(t.semaine);
 const jourValide=j=>!!j&&typeof j==='object'&&Object.keys(j).length===4&&entier(j.saison)&&entier(j.semaine)
  &&entier(j.n)&&j.n>=0&&j.n<=PATIENCE_MAX&&typeof j.vexe==='boolean';
 const agentValide=a=>!!a&&typeof a==='object'&&Object.keys(a).length===2&&Object.hasOwn(CARACTERES,a.car)&&typeof a.connu==='boolean';
 const dico=(x,ok)=>!!x&&typeof x==='object'&&!Array.isArray(x)&&Object.keys(x).length<=MAX_RELATIONS&&Object.entries(x).every(([id,v])=>id.length<=180&&ok(v));
 const etatValide=e=>!!e&&typeof e==='object'&&Object.keys(e).every(k=>['version','tons','relations','jours','agents'].includes(k))&&e.version===1
  &&dico(e.tons,tonValide)&&dico(e.relations,r=>entier(r)&&r>=-BORNE&&r<=BORNE)&&(e.jours===undefined||dico(e.jours,jourValide))
  &&(e.agents===undefined||dico(e.agents,agentValide));
 function etat(ecrire,s=vm()){
  if(etatValide(s?.tonAgent))return s.tonAgent;
  const neuf={version:1,tons:{},relations:{}};if(ecrire&&s)s.tonAgent=neuf;return neuf;
 }
 const semaine=s=>s?.economy?.week??s?.round??0;
 const duJour=(x,s)=>!!x&&x.saison===s.season&&x.semaine===semaine(s);
 const cleJour=(id,s,quoi)=>graine(s)+':'+s.season+':'+semaine(s)+':agent:'+quoi+':'+id;
 // Ton de la journée en cours pour ce joueur ('' sinon).
 function ton(id,s=vm()){
  const t=s?.tonAgent?.tons?.[id];
  return t&&tonValide(t)&&duJour(t,s)?t.ton:'';
 }
 const relation=(id,s=vm())=>{const r=s?.tonAgent?.relations?.[id];return entier(r)?r:0;};
 // Caractère : gardé dans la sauvegarde, sinon celui que le tirage donnera (même graine, même joueur).
 function caractere(id,s=vm()){
  const a=s?.tonAgent?.agents?.[id];
  return agentValide(a)?a.car:LISTE[hache(graine(s)+':agent:caractere:'+id)%LISTE.length];
 }
 // Joueurs observés par le recruteur (registre de connaissance, anciens rapports) : cache par registre.
 let observes={cle:null,ids:new Set()};
 function observe(id,s){
  const rec=s?.playerKnowledge?.records,rap=s?.manager?.reports;
  if(observes.cle!==rec||observes.rap!==rap){
   const ids=new Set();
   for(const b of Array.isArray(rec)?rec:[])for(const r of Array.isArray(b)?b:[])if(Array.isArray(r))ids.add(r[0]);
   for(const r of Array.isArray(rap)?rap:[])if(r&&typeof r.playerId==='string')ids.add(r.playerId);
   observes={cle:rec,rap,ids};
  }
  return observes.ids.has(id);
 }
 const connu=(id,s=vm())=>!!s?.tonAgent?.agents?.[id]?.connu||observe(id,s);
 // Patience de la journée : 3 + ton + relation + caractère + hasard, entre 2 et 5. Jamais projetée.
 function patience(id,s=vm()){
  const brut=PATIENCE_BASE+(TONS[ton(id,s)]?.patience||0)+effet(relation(id,s)).patience+CARACTERES[caractere(id,s)].patience+tirage(cleJour(id,s,'patience'),1);
  return Math.max(PATIENCE_MIN,Math.min(PATIENCE_MAX,brut));
 }
 const cleTalk=(id,s)=>String(s.season)+':'+String(semaine(s))+':recruit:'+id;
 const talkDuJour=(id,s=vm())=>s?.economy?.talks?.[cleTalk(id,s)];
 const talkEnCours=(id,s=vm())=>!!talkDuJour(id,s);
 const jour=(id,s)=>{const j=s?.tonAgent?.jours?.[id];return j&&jourValide(j)&&duJour(j,s)?j:null;};
 // Propositions déjà faites cette journée (vrai compte, au-delà des 3 du moteur).
 function faites(id,s=vm()){
  const t=talkDuJour(id,s);if(!t)return 0;
  const j=jour(id,s);return j?j.n:Math.max(0,Math.min(PATIENCE_BASE,Number(t.attempts)||0));
 }
 // Humeur : selon la patience qui reste, brouillée une fois sur trois vers plus tendu.
 function humeur(id,s=vm()){
  if(talkDuJour(id,s)?.status==='withdrawn')return 'rompu';
  const n=faites(id,s),reste=patience(id,s)-n;
  let h=reste>=3?0:reste===2?1:2;
  if(h<2&&hache(cleJour(id,s,'humeur:'+n))%3===0)h++;
  return HUMEURS[h];
 }
 const ecartDemande=(id,s=vm())=>(TONS[ton(id,s)]?.ecart||0)+effet(relation(id,s)).demande+CARACTERES[caractere(id,s)].demande+tirage(cleJour(id,s,'demande'),BRUIT_DEMANDE);
 const ecartSeuil=(id,s=vm())=>effet(relation(id,s)).seuil+CARACTERES[caractere(id,s)].seuil+tirage(cleJour(id,s,'seuil'),BRUIT_SEUIL);
 // Pistes du marché (joueurs libres, avec un agent) : les joueurs d'autres clubs (marché entre clubs) ne sont pas touchés.
 let pistes={cle:null,n:-1,ids:new Set()};
 function surMarche(id,s=vm()){
  const m=s?.market;if(!Array.isArray(m))return false;
  if(pistes.cle!==m||pistes.n!==m.length)pistes={cle:m,n:m.length,ids:new Set(m.map(x=>x?.id))};
  return pistes.ids.has(id);
 }
 // Demande avec l'écart (arrondie à la dizaine, au moins 10 € d'écart).
 function demande(base,p,kind){
  if(kind!=='recruit'||!p||typeof p.id!=='string'||!Number.isFinite(base)||!vm()||!surMarche(p.id))return base;
  const e=ecartDemande(p.id);if(!e)return base;
  const v=Math.round(base*(100+e)/1000)*10;
  return v===base?base+(e>0?10:-10):v;
 }
 // Minimum accepté (seuil), arrondi à la centaine supérieure.
 function seuil(base,p,kind){
  if(kind!=='recruit'||!p||typeof p.id!=='string'||!Number.isFinite(base)||!vm()||!surMarche(p.id))return base;
  const e=ecartSeuil(p.id);if(!e)return base;
  return Math.ceil(base*(100+e)/10000)*100;
 }
 // Vue de l'écran (market[].agent) : rien de chiffré sur la négociation (ni patience, ni écart, ni valeur de relation).
 function vue(id,s=vm()){
  if(!s)return null;
  const t=ton(id,s),r=relation(id,s),d=TONS[t],c=connu(id,s);
  return {ton:t,cran:cran(r),avant:cran(d?borne(r-d.relation):r),caractere:c?CARACTERES[caractere(id,s)].mot:'',
   humeur:humeur(id,s),faites:faites(id,s),libre:!t&&!talkEnCours(id,s)&&!s.live};
 }
 const euros=v=>Math.round(v).toLocaleString('fr-FR')+' €';
 // Répliques de l'agent qui se durcissent avec l'humeur.
 const REPLIQUES=Object.freeze({calme:'On peut encore en parler.',agace:'Mon client commence à s’impatienter.',tendu:'Ne me faites pas perdre mon temps.'});
 // Relation remise en fin de liste (les plus anciennes sortent au-delà de MAX_RELATIONS).
 function changerRelation(id,delta,s=vm()){
  if(!delta||!s)return;
  const e=etat(true,s),avant=relation(id,s);
  if(Object.hasOwn(e.relations,id))delete e.relations[id];
  const ids=Object.keys(e.relations);if(ids.length>=MAX_RELATIONS)for(const k of ids.slice(0,ids.length-MAX_RELATIONS+1))delete e.relations[k];
  e.relations[id]=borne(avant+delta);
 }
 // Caractère gardé (et éventuellement découvert) : les plus anciens sortent au-delà de MAX_RELATIONS.
 function noterAgent(id,decouvert,s=vm()){
  if(!s)return;
  const e=etat(true,s);if(!e.agents)e.agents={};
  const avant=e.agents[id],car=caractere(id,s),vu=!!avant?.connu||!!decouvert;
  if(avant&&avant.car===car&&avant.connu===vu)return;
  delete e.agents[id];
  const ids=Object.keys(e.agents);if(ids.length>=MAX_RELATIONS)for(const k of ids.slice(0,ids.length-MAX_RELATIONS+1))delete e.agents[k];
  e.agents[id]={car,connu:vu};
 }
 function noterJour(id,n,vexe,s){
  const e=etat(true,s);if(!e.jours)e.jours={};
  for(const [k,j] of Object.entries(e.jours))if(!duJour(j,s))delete e.jours[k];
  e.jours[id]={saison:s.season,semaine:semaine(s),n,vexe};
 }
 // Négociation d'une recrue : patience cachée (2 à 5 propositions au lieu de 3), relation selon l'issue.
 function negocier(id,kind,fn,salaire){
  const s=vm();
  if(!s||kind!=='recruit'||typeof id!=='string')return fn();
  const max=patience(id,s),key=cleTalk(id,s),avant=s.economy?.talks?.[key],deja=faites(id,s),j=jour(id,s);
  const p=Array.isArray(s.market)?s.market.find(x=>x&&x.id===id):null;
  const ridicule=!!p&&Number.isFinite(salaire)&&typeof askingWage==='function'&&salaire<askingWage(p,'recruit')*RIDICULE;
  // Au-delà de la 3e : la 3e contre-offre reste ouverte, le moteur compte cet essai comme le 3e.
  const suite=deja>=PATIENCE_BASE&&deja<max&&avant?.status==='counter'&&avant.attempts===PATIENCE_BASE;
  if(suite)avant.attempts=PATIENCE_BASE-1;
  let ok;
  try{ok=fn();}finally{if(suite&&s.economy.talks[key]===avant)avant.attempts=PATIENCE_BASE;}
  const t=s.economy.talks[key];
  if(!ok||!t||t===avant)return ok;
  const n=deja+1;
  // Première proposition faite : le caractère de l'agent est connu pour toujours (gardé dans la sauvegarde).
  noterAgent(id,true,s);
  if(t.status==='counter'||t.status==='withdrawn'){
   if(n>=max){
    t.status='withdrawn';
    t.message='L’agent coupe court. Le joueur met fin aux échanges pour cette journée.';
   }else{
    if(t.status==='withdrawn')t.status='counter';
    t.message=`Le joueur refuse et demande ${euros(t.acceptedSalary)} par semaine sur ${t.years} saison(s).`;
   }
  }
  const vexe=ridicule&&!j?.vexe;
  noterJour(id,n,!!j?.vexe||vexe,s);
  if(t.status==='counter')t.message+=' '+REPLIQUES[humeur(id,s)];
  changerRelation(id,(t.status==='ready'||t.status==='signed'?1:0)+(vexe?-1:0)+(t.status==='withdrawn'?-1:0),s);
  return ok;
 }
 function piste(s,payload){
  if(s.live&&!s.live.finished)throw Error('Agent : indisponible pendant un match.');
  const id=payload?.playerId;
  if(typeof id!=='string'||!Array.isArray(s.market)||!s.market.some(p=>p&&p.id===id))throw Error('Agent : joueur absent du marché.');
  return id;
 }
 function choisir(payload){
  const s=vm();if(!s)throw Error('Aucune carrière.');
  const id=piste(s,payload),choix=payload?.ton;
  if(!Object.hasOwn(TONS,choix))throw Error('Agent : ton inconnu.');
  if(ton(id,s))throw Error('Agent : ton déjà donné pour cette journée.');
  if(talkEnCours(id,s))throw Error('Agent : négociation déjà commencée cette journée.');
  const e=etat(true,s),sem=semaine(s);
  for(const [k,t] of Object.entries(e.tons))if(!(t.saison===s.season&&t.semaine===sem))delete e.tons[k];
  e.tons[id]={ton:choix,saison:s.season,semaine:sem};
  changerRelation(id,TONS[choix].relation,s);
  noterAgent(id,false,s);
  return undefined;
 }
 // Deuxième tour de la discussion : l'agent se dévoile (caractère découvert).
 function questionner(payload){
  const s=vm();if(!s)throw Error('Aucune carrière.');
  noterAgent(piste(s,payload),true,s);
  return undefined;
 }
 function execute(command,payload){
  if(command==='agent_ton')return choisir(payload);
  if(command==='agent_question')return questionner(payload);
  throw Error('Commande d’agent inconnue.');
 }
 function validate(s){
  if(s&&s.tonAgent!==undefined&&!etatValide(s.tonAgent))throw Error('Discussion avec l’agent invalide.');
  return true;
 }
 let installe=false;
 function installHooks(){
  globalThis.tonAgentVue=id=>vue(id);
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
 return {project(){return null;},validate,execute,installHooks,TONS,EFFETS,CARACTERES,PATIENCE_BASE,BORNE,RIDICULE,
  cran,effet,ton,relation,caractere,connu,patience,humeur,faites,vue,demande,seuil,negocier,etatValide,ecartDemande,ecartSeuil};
}
const pur=factory();
module.exports={files,commands,factory,TONS:pur.TONS,EFFETS:pur.EFFETS,CARACTERES:pur.CARACTERES,RIDICULE:pur.RIDICULE,cran:pur.cran,effet:pur.effet,etatValide:pur.etatValide};

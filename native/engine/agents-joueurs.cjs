'use strict';
// Agents de joueurs nommés (retour de Léo du 23/11/2026 sur l'idée 24 : « On a l'impression de parler avec le joueur…
// Donne un nom à chaque agent. Chaque agent gère un ou plusieurs joueurs comme dans la réalité »).
//  - Annuaire des agents tiré une fois par la graine du monde et gardé dans la sauvegarde (S.agentsJoueurs) : nom
//    fictif (générateur de noms du staff, staff-completion.cjs, par culture FR / EN / JP), agence fictive, âge, pays,
//    rang (grande agence internationale, agence moyenne, agent indépendant) et caractère caché (ceux de ton-agent.cjs).
//  - Chaque joueur de 18 ans et plus a un agent ; les jeunes du centre de moins de 18 ans n'en ont pas encore.
//    L'agent d'un joueur ne dépend que de la graine, de l'annuaire et de l'identifiant du joueur (empreinte stable) :
//    il ne change ni avec un transfert ni d'une sauvegarde à l'autre, et tout joueur créé plus tard (jeunes promus,
//    recrues du marché, joueurs des packs) en reçoit un sans écriture sur les joueurs.
//  - Répartition : 35 % des joueurs chez les agents des cinq grandes agences internationales (4 à 8 agents chacune),
//    20 % chez des agences moyennes de leur culture (≈ 24 clients), 45 % chez des agents indépendants (≈ 3 clients,
//    la plupart entre 1 et 5).
//  - Migration (observe(), après chaque commande) : annuaire créé sur les anciennes carrières ; la relation et le
//    caractère de l'idée 24, gardés par joueur (S.tonAgent version 1), passent à l'agent (version 2) : relations
//    additionnées par agent (bornées à ±10), caractère gardé repris par l'agent, découverte gardée.
// Fonctions globales de la VM : agentJoueurId(idJoueur, age?), agentJoueur(idAgent), agentJoueurNom(idJoueur),
// agentJoueurCaractere(idAgent). Projection : clubLife.agentsJoueurs = {joueurs:{idJoueur:idAgent}, agents:{idAgent:
// {id, nom, agence, age, pays, rang, rangMot, cran, caractere, total, clients:[[id, nom, poste, âge, club, idClub, où]…12]}}} pour l'effectif, le marché et le courrier.
const files=Object.freeze([]),commands=Object.freeze([]);
function factory(){
 const noms=(function staffCompletionPolicy(){return null;})();
 const VERSION=1,AGE_MIN=18,MAX_CLIENTS=12,MAX_AGENTS=3000;
 const CARS=Object.freeze(['gourmand','presse','fidele','poker','arrangeant']);
 const RANGS=Object.freeze(['grande','moyenne','petite']);
 const PAYS=Object.freeze(['FR','EN','JP']);
 // Grandes agences internationales (fictives) : cinq tirées par la graine.
 const GRANDES=Object.freeze(['Touche Management','Grand Large Sports','Ovalie Partners','Pacific Rugby Group','Les Quatre Vents','Haka Talent','Stade Bleu Agency','Sakura Sports Agency']);
 const SUFFIXES=Object.freeze({
  moyenne:{FR:['Associés','Sports','Rugby Conseil'],EN:['Rugby Management','Sports Group','Partners'],JP:['Sports Japan','Athlete Office','Rugby Partners']},
  petite:{FR:['Conseil','Sport Agence','Gestion'],EN:['Sports Agency','Rugby Agency','Player Care'],JP:['Office','Sports','Agency']}});
 const vm=()=>typeof S==='undefined'?null:S;
 function hache(texte){let h=0x811c9dc5;for(const c of String(texte)){h^=c.codePointAt(0);h=Math.imul(h,0x01000193)>>>0;}h^=h>>>16;h=Math.imul(h,0x85ebca6b)>>>0;h^=h>>>13;return h>>>0;}
 const graine=s=>Number.isInteger(s?.careerVariation?.seed)?s.careerVariation.seed:0;
 const norm=x=>String(x||'').normalize('NFD').replace(/[̀-ͯ]/g,'').toLowerCase();
 // Culture des noms d'un joueur : France, Japon, sinon anglophone (nation d'origine, player-facts.cjs).
 function culture(id){
  let o='';try{o=typeof nativeFacts!=='undefined'&&nativeFacts?.origin?String(nativeFacts.origin(id)||''):'';}catch{o='';}
  return o==='FRA'?'FR':o==='JPN'?'JP':o?'EN':'FR';
 }
 // Tous les joueurs de la carrière : clubs, marché (joueurs libres) ; chacun une fois.
 function* joueurs(s){
  const vus=new Set();
  for(const c of Array.isArray(s?.clubs)?s.clubs:Object.values(s?.clubs||{}))for(const p of c?.players||[])if(p&&typeof p.id==='string'&&!vus.has(p.id)){vus.add(p.id);yield [p,c];}
  for(const p of Array.isArray(s?.market)?s.market:[])if(p&&typeof p.id==='string'&&!vus.has(p.id)){vus.add(p.id);yield [p,null];}
  for(const p of Array.isArray(s?.economy?.freeAgents)?s.economy.freeAgents:[])if(p&&typeof p.id==='string'&&!vus.has(p.id)){vus.add(p.id);yield [p,null];}
 }
 const agentValide=a=>!!a&&typeof a==='object'&&Object.keys(a).length===8&&typeof a.id==='string'&&/^ag-\d{1,5}$/.test(a.id)
  &&typeof a.nom==='string'&&a.nom.length>0&&a.nom.length<=80&&typeof a.agence==='string'&&a.agence.length>0&&a.agence.length<=80
  &&Number.isInteger(a.age)&&a.age>=25&&a.age<=75&&PAYS.includes(a.pays)&&RANGS.includes(a.rang)&&CARS.includes(a.car)&&Number.isInteger(a.g)&&a.g>=0&&a.g<GRANDES.length;
 const etatValide=e=>!!e&&typeof e==='object'&&!Array.isArray(e)&&Object.keys(e).length===3&&e.version===VERSION&&Number.isInteger(e.graine)
  &&Array.isArray(e.agents)&&e.agents.length>0&&e.agents.length<=MAX_AGENTS&&e.agents.every(agentValide)&&new Set(e.agents.map(a=>a.id)).size===e.agents.length;
 // Nom d'une personne (générateur du staff, sans double nom) ; unique dans l'annuaire.
 function personne(cle,pays,utilises){
  for(let sel=0;sel<400;sel++){
   const p=noms.profile(cle+':'+sel,{function:'teamManager',country:pays});
   const nom=pays==='JP'?p.name:p.name.replace(/-[^ ]+$/,'');
   if(!utilises.has(norm(nom))){utilises.add(norm(nom));return nom;}
  }
  throw Error('Noms d’agents épuisés.');
 }
 const nomDeFamille=nom=>nom.split(' ').slice(-1)[0];
 // Annuaire tiré par la graine, à la taille du monde (joueurs par culture).
 function tirer(s){
  const G=graine(s),n={FR:0,EN:0,JP:0};
  for(const [p] of joueurs(s))n[culture(p.id)]++;
  const agents=[],utilises=new Set();
  const ajouter=(rang,pays,agence,g,cle)=>{
   const id='ag-'+(agents.length+1),nom=personne(G+':agent:nom:'+cle,pays,utilises);
   agents.push({id,nom,agence:agence||'',age:32+hache(G+':agent:age:'+cle)%30,pays,rang,car:CARS[hache(G+':agent:car:'+cle)%CARS.length],g});
   return agents[agents.length-1];
  };
  // Grandes agences : cinq parmi huit, 4 à 8 agents chacune, cultures mêlées selon le monde.
  const ordre=GRANDES.map((x,i)=>i).sort((a,b)=>hache(G+':grande:'+a)-hache(G+':grande:'+b)||a-b).slice(0,5);
  const total=n.FR+n.EN+n.JP||1;
  for(const g of ordre){
   const k=4+hache(G+':grande:taille:'+g)%5;
   for(let i=0;i<k;i++){
    const u=hache(G+':grande:pays:'+g+':'+i)%total,pays=u<n.FR?'FR':u<n.FR+n.EN?'EN':'JP';
    ajouter('grande',pays,GRANDES[g],g,'g'+g+':'+i);
   }
  }
  for(const pays of PAYS){
   const moyennes=Math.max(1,Math.round(n[pays]*.2/24)),petites=Math.max(2,Math.round(n[pays]*.45/3));
   for(let i=0;i<moyennes;i++){
    const a=ajouter('moyenne',pays,'',0,'m'+pays+':'+i),suf=SUFFIXES.moyenne[pays];
    a.agence=nomDeFamille(a.nom)+' '+suf[hache(G+':suffixe:'+a.id)%suf.length];
   }
   for(let i=0;i<petites;i++){
    const a=ajouter('petite',pays,'',0,'p'+pays+':'+i),suf=SUFFIXES.petite[pays];
    a.agence=nomDeFamille(a.nom)+' '+suf[hache(G+':suffixe:'+a.id)%suf.length];
   }
  }
  return {version:VERSION,graine:G,agents};
 }
 // Index de l'annuaire (par identifiant, par rang et culture), recalculé quand l'annuaire change.
 let index={cle:null};
 function indexer(e){
  if(index.cle===e)return index;
  const parId=new Map(),grandes=[],listes={};
  for(const pays of PAYS)listes[pays]={moyenne:[],petite:[]};
  for(const a of e.agents){parId.set(a.id,a);if(a.rang==='grande')grandes.push(a);else listes[a.pays][a.rang].push(a);}
  index={cle:e,parId,grandes,listes,choix:new Map(),clients:null};
  return index;
 }
 // Annuaire valide de la carrière (validé une fois par objet : l'index en garde la trace).
 const annuaire=(s=vm())=>{const e=s?.agentsJoueurs;return !e?null:index.cle===e||etatValide(e)?e:null;};
 // Agent d'un joueur (identifiant) : rang tiré (35 / 20 / 45 %), puis un agent de ce rang (de sa culture hors grandes agences).
 function agentId(id,age,s=vm()){
  if(typeof id!=='string'||!id)return null;
  if(Number.isFinite(age)&&age<AGE_MIN)return null;
  const e=annuaire(s);if(!e)return null;
  const ix=indexer(e);
  if(ix.choix.has(id))return ix.choix.get(id);
  const G=e.graine,u=hache(G+':client:rang:'+id)%100,pays=culture(id);
  let liste=u<35?ix.grandes:u<55?ix.listes[pays].moyenne:ix.listes[pays].petite;
  if(!liste.length)liste=ix.grandes.length?ix.grandes:e.agents;
  const a=liste[hache(G+':client:agent:'+id)%liste.length];
  if(ix.choix.size>20000)ix.choix.clear();
  ix.choix.set(id,a.id);
  return a.id;
 }
 const agent=(id,s=vm())=>{const e=annuaire(s);return e?indexer(e).parId.get(id)||null:null;};
 // Clients de chaque agent : index des joueurs de la carrière (club actuel), refait à chaque lecture.
 function clients(s=vm()){
  const map=new Map();if(!annuaire(s))return map;
  for(const [p,c] of joueurs(s)){
   const a=agentId(p.id,p.age,s);if(!a)continue;
   if(!map.has(a))map.set(a,[]);
   map.get(a).push([p,c]);
  }
  return map;
 }
 // Annuaire des carrières neuves et anciennes ; relation et caractère de l'idée 24 rapportés à l'agent.
 function observe(){
  const s=vm();if(!s||!Array.isArray(s.clubs)||!s.clubs.length)return 0;
  let n=0;
  if(!annuaire(s)){s.agentsJoueurs=tirer(s);n++;}
  if(s.tonAgent&&s.tonAgent.version===1){migrer(s);n++;}
  return n;
 }
 function migrer(s){
  const v=s.tonAgent,rel={},connus={},cars={};
  for(const [id,r] of Object.entries(v.relations||{})){const a=agentId(id,undefined,s);if(a&&Number.isInteger(r))rel[a]=(rel[a]||0)+r;}
  for(const [id,x] of Object.entries(v.agents||{})){
   const a=agentId(id,undefined,s);if(!a||!x)continue;
   if(x.connu===true)connus[a]=true;
   if(CARS.includes(x.car)&&(!cars[a]||x.connu===true&&!cars[a].connu))cars[a]={car:x.car,connu:x.connu===true};
  }
  const ix=indexer(s.agentsJoueurs);
  for(const [a,c] of Object.entries(cars)){const ag=ix.parId.get(a);if(ag)ag.car=c.car;}
  const relations={};for(const [a,r] of Object.entries(rel))relations[a]=Math.max(-10,Math.min(10,r));
  s.tonAgent={version:2,tons:v.tons||{},relations,...(v.jours?{jours:v.jours}:{}),...(Object.keys(connus).length?{connus}:{})};
 }
 const MOT_RANG=Object.freeze({grande:'Grande agence',moyenne:'Agence',petite:'Indépendant'});
 // Fiche projetée d'un agent : identité, relation (cran 0..4), caractère (mot si découvert), clients (les meilleurs d'abord).
 function fiche(a,map,s){
  // Lignes compactes [id, nom, poste, âge, club, idClub, où] (où : effectif, club ou marché) : notre effectif, puis les
  // meilleurs (la note sert au tri seulement : jamais montrée).
  const note=p=>Number.isFinite(p.rating)?p.rating:0;
  const liste=(map.get(a.id)||[]).sort(([p,c],[q,d])=>(c?.id===s.club?0:1)-(d?.id===s.club?0:1)||note(q)-note(p)||(p.id<q.id?-1:1))
   .map(([p,c])=>[p.id,p.name,p.pos,p.age,c?String(c.name||''):'',c&&Number.isSafeInteger(c.id)?c.id:null,c?(c.id===s.club?'effectif':'club'):'marche']);
  const relation=typeof tonAgentRelationCran==='function'?tonAgentRelationCran(a.id):2,car=typeof tonAgentCaractereMot==='function'?tonAgentCaractereMot(a.id):'';
  return {id:a.id,nom:a.nom,agence:a.agence,age:a.age,pays:a.pays,rang:a.rang,rangMot:MOT_RANG[a.rang],cran:relation,caractere:car,total:liste.length,clients:liste.slice(0,MAX_CLIENTS)};
 }
 function project(){
  const s=vm();if(!s||!annuaire(s))return null;
  const map=clients(s),joueursVus={},agentsVus={};
  const noter=(id,age)=>{const a=agentId(id,age,s);if(a){joueursVus[id]=a;agentsVus[a]=true;}};
  const club=(s.clubs||[]).find(c=>c&&c.id===s.club);
  for(const p of club?.players||[])noter(p.id,p.age);
  for(const p of Array.isArray(s.market)?s.market:[])if(p)noter(p.id,p.age);
  for(const m of Array.isArray(s.clubMail?.mails)?s.clubMail.mails.slice(-80):[])if(m&&m.type==='agent'&&typeof m.player==='string')noter(m.player);
  const agents={};
  for(const id of Object.keys(agentsVus)){const a=agent(id,s);if(a)agents[id]=fiche(a,map,s);}
  return {joueurs:joueursVus,agents};
 }
 function validate(s){
  if(s&&s.agentsJoueurs!==undefined&&!etatValide(s.agentsJoueurs))throw Error('Annuaire des agents invalide.');
  return true;
 }
 // Mesure de la répartition (tests) : nombre d'agents, clients par agent et par agence.
 function repartition(s=vm()){
  const map=clients(s),parAgence={},tailles=[];
  for(const a of annuaire(s)?.agents||[]){const k=(map.get(a.id)||[]).length;tailles.push(k);parAgence[a.agence]=(parAgence[a.agence]||0)+k;}
  return {agents:tailles.length,tailles,parAgence};
 }
 function installHooks(){
  globalThis.agentJoueurId=(id,age)=>agentId(id,age);
  globalThis.agentJoueur=id=>agent(id);
  globalThis.agentJoueurNom=id=>{const a=agent(agentId(id));return a?a.nom:'';};
  globalThis.agentJoueurCaractere=id=>agent(id)?.car||'';
  globalThis.agentsJoueursRepartition=()=>repartition();
  globalThis.agentsJoueursObserver=()=>observe();
  return true;
 }
 return {project,validate,execute(){throw Error('Aucune commande d’agent nommé.');},installHooks,observe,tirer,agentId,agent,clients,repartition,etatValide,CARS,GRANDES};
}
// Seule la source locale de confiance est composée ici (générateur de noms du staff) ; aucun texte de sauvegarde n'est évalué.
const serializedFactory=Function('return ('+factory.toString().replace('function staffCompletionPolicy(){return null;}',require('./staff-completion.cjs').factory.toString())+')')();
module.exports={files,commands,factory:serializedFactory};

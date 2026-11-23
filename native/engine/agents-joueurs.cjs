'use strict';
// Agents de joueurs nommés (retour de Léo du 23/11/2026 sur l'idée 24 : « On a l'impression de parler avec le joueur…
// Donne un nom à chaque agent. Chaque agent gère un ou plusieurs joueurs comme dans la réalité »).
//  - Annuaire des agents tiré une fois par la graine du monde et gardé dans la sauvegarde (S.agentsJoueurs) : nom
//    fictif (générateur de noms du staff, staff-completion.cjs, par culture FR / EN / JP), agence fictive, âge, pays,
//    rang (grande agence internationale, agence moyenne, petite agence, agent indépendant) et caractère caché (ceux de
//    ton-agent.cjs).
//  - Chaque joueur de 18 ans et plus a un agent ; les jeunes du centre de moins de 18 ans n'en ont pas encore.
//    L'agent d'un joueur ne dépend que de la graine, de l'annuaire et de l'identifiant du joueur (empreinte stable) :
//    il ne change ni avec un transfert ni d'une sauvegarde à l'autre, et tout joueur créé plus tard (jeunes promus,
//    recrues du marché, joueurs des packs) en reçoit un sans écriture sur les joueurs.
//  - Répartition (calée sur le monde réel : une agence compte plusieurs agents, la plus grosse ≈ 100-150 joueurs, aucun
//    agent au-delà de ~30 clients) : 10 % des joueurs chez les agents des cinq grandes agences internationales (9 à 11
//    agents chacune, ≈ 12 clients par agent), 30 % chez des agences moyennes de leur culture (4 à 6 agents, ≈ 8 clients
//    chacun), 50 % dans de petites agences (2 ou 3 agents, ≈ 5 clients chacun), 10 % chez des agents indépendants
//    (≈ 5 clients). Le choix est un tirage « meilleur score » : chaque joueur classe les agents de son rang par empreinte,
//    donc retirer un agent ne déplace que ses propres clients ; à la création, un agent trop chargé reçoit un collègue
//    dans son agence et les agents sans client sont retirés de l'annuaire.
//  - Migration (observe(), après chaque commande) : annuaire créé sur les anciennes carrières ; annuaire de la première
//    version (35 / 20 / 45 %, agences trop grosses) refait à la nouvelle répartition, les agents d'origine qui existent
//    encore (même nom, même pays) gardant leur caractère, leur relation et leur découverte ; la relation et le caractère
//    de l'idée 24, gardés par joueur (S.tonAgent version 1), passent à l'agent (version 2) : relations additionnées par
//    agent (bornées à ±10), caractère gardé repris par l'agent, découverte gardée.
// Fonctions globales de la VM : agentJoueurId(idJoueur, age?), agentJoueur(idAgent), agentJoueurNom(idJoueur),
// agentJoueurCaractere(idAgent). Projection : clubLife.agentsJoueurs = {joueurs:{idJoueur:idAgent}, agents:{idAgent:
// {id, nom, agence, age, pays, rang, rangMot, cran, caractere, total, clients:[[id, nom, poste, âge, club, idClub, où]…12]}}} pour l'effectif, le marché et le courrier.
const files=Object.freeze([]),commands=Object.freeze([]);
function factory(){
 const noms=(function staffCompletionPolicy(){return null;})();
 const VERSION=2,AGE_MIN=18,MAX_CLIENTS=12,MAX_AGENTS=3000,PLAFOND=26;
 const CARS=Object.freeze(['gourmand','presse','fidele','poker','arrangeant']);
 const RANGS=Object.freeze(['grande','moyenne','petite','independant']);
 const PAYS=Object.freeze(['FR','EN','JP']);
 // Part des joueurs par rang (en %, cumulée dans l'ordre RANGS) et clients visés par agent.
 const PARTS=Object.freeze({grande:10,moyenne:30,petite:50,independant:10}),VISE=Object.freeze({grande:12,moyenne:8,petite:5,independant:5});
 // Grandes agences internationales (fictives) : cinq tirées par la graine.
 const GRANDES=Object.freeze(['Touche Management','Grand Large Sports','Ovalie Partners','Pacific Rugby Group','Les Quatre Vents','Haka Talent','Stade Bleu Agency','Sakura Sports Agency']);
 const SUFFIXES=Object.freeze({
  moyenne:{FR:['Associés','Sports','Rugby Conseil'],EN:['Rugby Management','Sports Group','Partners'],JP:['Sports Japan','Athlete Office','Rugby Partners']},
  petite:{FR:['Conseil','Sport Agence','Gestion'],EN:['Sports Agency','Rugby Agency','Player Care'],JP:['Office','Sports','Agency']},
  independant:{FR:['Conseil','Gestion','Sport Agence'],EN:['Sports Agency','Player Care','Rugby Agency'],JP:['Office','Agency','Sports']}});
 const vm=()=>typeof S==='undefined'?null:S;
 function hache(texte){let h=0x811c9dc5;for(const c of String(texte)){h^=c.codePointAt(0);h=Math.imul(h,0x01000193)>>>0;}h^=h>>>16;h=Math.imul(h,0x85ebca6b)>>>0;h^=h>>>13;return h>>>0;}
 // Score d'un agent pour un joueur (deux empreintes mêlées) : le plus haut score gagne.
 function score(hj,ha){let x=(hj^Math.imul(ha,0x9e3779b1))>>>0;x=Math.imul(x^(x>>>16),0x85ebca6b)>>>0;x=Math.imul(x^(x>>>13),0xc2b2ae35)>>>0;return (x^(x>>>16))>>>0;}
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
 const etatBrut=(e,v)=>!!e&&typeof e==='object'&&!Array.isArray(e)&&Object.keys(e).length===3&&e.version===v&&Number.isInteger(e.graine)
  &&Array.isArray(e.agents)&&e.agents.length>0&&e.agents.length<=MAX_AGENTS&&e.agents.every(agentValide)&&new Set(e.agents.map(a=>a.id)).size===e.agents.length;
 const etatValide=e=>etatBrut(e,VERSION);
 // Annuaire de la première version (avant le recalage des agences) : lisible seulement pour être refait par observe().
 const ancienValide=e=>etatBrut(e,1)&&e.agents.every(a=>a.rang!=='independant');
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
 // Index des agents : par identifiant, par rang (et culture hors grandes agences), avec l'empreinte de chacun.
 function construire(agents,G){
  const parId=new Map(),grandes=[],listes={};
  for(const pays of PAYS){listes[pays]={};for(const r of RANGS)if(r!=='grande')listes[pays][r]=[];}
  for(const a of agents){
   parId.set(a.id,a);
   const e={a,h:hache(G+':agent:score:'+a.id)};
   if(a.rang==='grande')grandes.push(e);else listes[a.pays][a.rang].push(e);
  }
  return {parId,grandes,listes,tout:agents.map(a=>({a,h:hache(G+':agent:score:'+a.id)}))};
 }
 // Rang tiré pour un joueur (10 / 30 / 50 / 10 %), puis le meilleur score parmi les agents de ce rang.
 function choisir(ix,G,id,pays){
  const u=hache(G+':client:rang:'+id)%100;
  let cumul=0,rang='independant';
  for(const r of RANGS){cumul+=PARTS[r];if(u<cumul){rang=r;break;}}
  let liste=rang==='grande'?ix.grandes:ix.listes[pays][rang];
  if(!liste.length)liste=ix.grandes.length?ix.grandes:ix.tout;
  const hj=hache(G+':client:agent:'+id);
  let meilleur=null,top=-1;
  for(const e of liste){const v=score(hj,e.h);if(v>top){top=v;meilleur=e.a;}}
  return meilleur;
 }
 // Annuaire tiré par la graine, à la taille du monde (joueurs par culture). Les clés de nom ('g…', 'm…', 'p…') restent
 // celles de la première version : un agent d'origine retrouve son nom, donc sa place (migration).
 function tirer(s){
  const G=graine(s),n={FR:0,EN:0,JP:0},na={FR:0,EN:0,JP:0},ids=[];
  for(const [p] of joueurs(s)){const c=culture(p.id);n[c]++;if(!(Number.isFinite(p.age)&&p.age<AGE_MIN)){na[c]++;ids.push([p.id,c]);}}
  const adultes=ids.length||1;
  const agents=[],utilises=new Set(),agences=new Set();
  const ajouter=(rang,pays,agence,g,cle)=>{
   const id='ag-'+(agents.length+1),nom=personne(G+':agent:nom:'+cle,pays,utilises);
   agents.push({id,nom,agence:agence||'',age:32+hache(G+':agent:age:'+cle)%30,pays,rang,car:CARS[hache(G+':agent:car:'+cle)%CARS.length],g});
   return agents[agents.length-1];
  };
  // Tailles des agences d'un rang (nombre d'agents entre min et max), la dernière agence jamais réduite à un seul agent.
  const tailles=(total,min,max,cle)=>{
   const t=[];let reste=total;
   for(let j=0;reste>0;j++){const k=Math.min(reste,min+hache(G+':taille:'+cle+':'+j)%(max-min+1));t.push(k);reste-=k;}
   if(t.length>1&&t.at(-1)<2)t[t.length-2]+=t.pop();
   return t;
  };
  // Nom d'agence unique : nom de famille d'un de ses agents et un suffixe de la culture.
  const nommer=(groupe,rang,pays)=>{
   const suf=SUFFIXES[rang][pays],dep=hache(G+':suffixe:'+groupe[0].id);
   let nom='';
   for(const a of groupe){for(let i=0;i<suf.length&&!nom;i++){const c=nomDeFamille(a.nom)+' '+suf[(dep+i)%suf.length];if(!agences.has(c))nom=c;}if(nom)break;}
   if(!nom){let k=2;do{nom=nomDeFamille(groupe[0].nom)+' '+suf[dep%suf.length]+' '+k++;}while(agences.has(nom));}
   agences.add(nom);for(const a of groupe)a.agence=nom;
  };
  // Grandes agences : cinq parmi huit, 9 à 11 agents chacune (moins dans un petit monde), cultures mêlées selon le monde.
  const ordre=GRANDES.map((x,i)=>i).sort((a,b)=>hache(G+':grande:'+a)-hache(G+':grande:'+b)||a-b).slice(0,5);
  const total=n.FR+n.EN+n.JP||1,base=Math.max(3,Math.min(10,Math.round(adultes*PARTS.grande/100/5/VISE.grande)));
  for(const g of ordre){
   const k=Math.max(2,base-1+hache(G+':grande:taille:'+g)%3);
   for(let i=0;i<k;i++){
    const u=hache(G+':grande:pays:'+g+':'+i)%total,pays=u<n.FR?'FR':u<n.FR+n.EN?'EN':'JP';
    ajouter('grande',pays,GRANDES[g],g,'g'+g+':'+i);
    agences.add(GRANDES[g]);
   }
  }
  for(const pays of PAYS){
   // Agences moyennes (4 à 6 agents) et petites agences (2 ou 3 agents) : agents regroupés dans l'ordre du tirage.
   for(const [rang,min,max,lettre] of [['moyenne',4,6,'m'],['petite',2,3,'p']]){
    const nb=Math.max(rang==='moyenne'?1:2,Math.round(na[pays]*PARTS[rang]/100/VISE[rang]));
    let i=0;
    for(const k of tailles(nb,min,max,rang+pays)){
     const groupe=[];
     for(let j=0;j<k;j++)groupe.push(ajouter(rang,pays,'',0,lettre+pays+':'+(i++)));
     nommer(groupe,rang,pays);
    }
   }
   // Indépendants : chacun son cabinet.
   const nbi=Math.max(1,Math.round(na[pays]*PARTS.independant/100/VISE.independant));
   for(let i=0;i<nbi;i++){const a=ajouter('independant',pays,'',0,'i'+pays+':'+i);nommer([a],'independant',pays);}
  }
  // Charge réelle : un agent trop chargé reçoit un collègue dans son agence (autres clients redistribués par le tirage),
  // puis les agents sans client sont retirés (retirer un agent sans client ne déplace personne).
  let compte=new Map();
  for(let tour=0;;tour++){
   const ix=construire(agents,G);compte=new Map();
   for(const [id,pays] of ids){const a=choisir(ix,G,id,pays);compte.set(a.id,(compte.get(a.id)||0)+1);}
   const trop=agents.filter(a=>compte.get(a.id)>PLAFOND);
   if(!trop.length||tour>=8)break;
   for(const a of trop)ajouter(a.rang,a.pays,a.agence,a.g,'x'+tour+':'+a.id);
  }
  const gardes=agents.filter(a=>compte.get(a.id)>0);
  return {version:VERSION,graine:G,agents:gardes.length?gardes:agents.slice(0,1)};
 }
 // Index de l'annuaire (par identifiant, par rang et culture), recalculé quand l'annuaire change.
 let index={cle:null};
 function indexer(e){
  if(index.cle===e)return index;
  index=Object.assign(construire(e.agents,e.graine),{cle:e,choix:new Map(),clients:null});
  return index;
 }
 // Annuaire valide de la carrière (validé une fois par objet : l'index en garde la trace).
 const annuaire=(s=vm())=>{const e=s?.agentsJoueurs;return !e?null:index.cle===e||etatValide(e)?e:null;};
 // Agent d'un joueur (identifiant) : rang tiré (10 / 30 / 50 / 10 %), puis le meilleur score parmi les agents de ce rang.
 function agentId(id,age,s=vm()){
  if(typeof id!=='string'||!id)return null;
  if(Number.isFinite(age)&&age<AGE_MIN)return null;
  const e=annuaire(s);if(!e)return null;
  const ix=indexer(e);
  if(ix.choix.has(id))return ix.choix.get(id);
  const a=choisir(ix,e.graine,id,culture(id));
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
  if(!annuaire(s)){
   if(ancienValide(s.agentsJoueurs))migrerAnnuaire(s);else s.agentsJoueurs=tirer(s);
   n++;
  }
  if(s.tonAgent&&s.tonAgent.version===1){migrer(s);n++;}
  return n;
 }
 // Annuaire de la première version : refait à la nouvelle répartition ; l'agent d'origine qui existe encore (même nom et
 // même pays) garde son caractère, sa relation (S.tonAgent version 2) et sa découverte ; les autres sont oubliés.
 function migrerAnnuaire(s){
  const ancien=s.agentsJoueurs,neuf=tirer(s),parNom=new Map(neuf.agents.map(a=>[norm(a.nom)+'|'+a.pays,a])),carte={};
  for(const o of ancien.agents){const a=parNom.get(norm(o.nom)+'|'+o.pays);if(a){carte[o.id]=a.id;a.car=o.car;}}
  s.agentsJoueurs=neuf;
  const t=s.tonAgent;
  if(t&&t.version===2){
   const relations={},connus={};
   for(const [o,r] of Object.entries(t.relations||{}))if(carte[o]&&Number.isInteger(r)&&r!==0)relations[carte[o]]=Math.max(-10,Math.min(10,r));
   for(const o of Object.keys(t.connus||{}))if(carte[o]&&t.connus[o]===true)connus[carte[o]]=true;
   s.tonAgent={version:2,tons:t.tons||{},relations,...(t.jours?{jours:t.jours}:{}),...(Object.keys(connus).length?{connus}:{})};
  }
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
 const MOT_RANG=Object.freeze({grande:'Grande agence',moyenne:'Agence',petite:'Petite agence',independant:'Indépendant'});
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
  if(s&&s.agentsJoueurs!==undefined&&!etatValide(s.agentsJoueurs)&&!ancienValide(s.agentsJoueurs))throw Error('Annuaire des agents invalide.');
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
 return {project,validate,execute(){throw Error('Aucune commande d’agent nommé.');},installHooks,observe,tirer,agentId,agent,clients,repartition,etatValide,ancienValide,CARS,GRANDES};
}
// Seule la source locale de confiance est composée ici (générateur de noms du staff) ; aucun texte de sauvegarde n'est évalué.
const serializedFactory=Function('return ('+factory.toString().replace('function staffCompletionPolicy(){return null;}',require('./staff-completion.cjs').factory.toString())+')')();
module.exports={files,commands,factory:serializedFactory};

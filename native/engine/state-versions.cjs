'use strict';
// Versions des sections de la carrière (clés de premier niveau de S) pour la projection de l'interface.
//
// La mémoire des projections par domaine (native-systems.cjs, projectParts) compare, pour chaque domaine lourd, les
// sections de S lues lors du dernier calcul. Elle recevait jusqu'ici le texte JSON de chaque section : toute la
// carrière (~22 Mo) était donc resérialisée à chaque réponse, même pour une consigne de jeu. Elle reçoit désormais un
// jeton de version par section : le texte d'une section n'est recalculé que si la commande a pu la modifier.
//
// Sections légères (tout sauf HEAVY, quelques centaines de ko au total) : resérialisées à chaque projection et
// comparées au texte précédent (aucune déclaration nécessaire). Sections lourdes (HEAVY) : resérialisées sauf si la
// commande est déclarée ne pas les toucher (UNTOUCHED ci-dessous), ou si l'état est resté le même objet sans commande
// entre deux (lectures). Une carrière remplacée (création, import, annulation d'une commande refusée) est toujours
// entièrement relue : seuls les textes comptent, jamais l'identité des objets.
//
// Vérification (CD_VERIFIER_PROJECTION=1, option verifyProjection) : toutes les sections sont resérialisées et une
// section déclarée intacte qui a changé lève une erreur nommant la commande et la section.

// Sections lourdes de S (carrière Monde neuve : clubs ~14 Mo, aiRoster ~4 Mo, staffCareer ~1,7 Mo,
// potentialEvolution ~0,8 Mo, worldMode ~0,5 Mo, matchNotes ~0,1 Mo).
const HEAVY = Object.freeze(['clubs', 'aiRoster', 'staffCareer', 'potentialEvolution', 'worldMode', 'matchNotes']);

// Sections lourdes qu'une commande ne modifie pas (relevé sur le scénario de référence en carrière Monde, puis
// vérifié par tests/reactivite-projection.cjs en mode vérification). Absente de cette table, une commande relit tout.
const NONE = HEAVY;
const except = (...keys) => Object.freeze(HEAVY.filter(key => !keys.includes(key)));
const UNTOUCHED = Object.freeze({
  // Lectures et consultations.
  snapshot: NONE, club_sheet: NONE, epcr_preview: NONE, competition_editor_preview: NONE,
  club_preview: NONE, start_challenges: NONE, academy_groups_preview: NONE, interclub_negotiate: NONE, save: NONE,
  // Réglages, consignes, rendez-vous, causeries : sections légères seulement.
  set_tactics: NONE, set_penalty_policy: NONE, set_consignes: NONE, appliquer_staff: NONE, set_role_direct: NONE, cri: NONE, set_collective_focus: NONE, set_opponent_level: NONE,
  set_intensite_auto: NONE, set_delegation: NONE, press_policy: NONE, club_follow: NONE, set_lineup: NONE, auto_lineup: NONE,
  club_meeting_ack: NONE, club_meeting_continue: NONE, pause: NONE, match_talk_decide: NONE, match_incident_choice: NONE,
  manager_recruitment_watch: NONE, regen_shortlist: NONE,
  // Rallonge du conseil (budget-transferts.cjs) : budgetTransferts, confiance et nouvelles (sections légères).
  transfer_budget_extension: NONE,
  // Séance d'un jour remplacée (calendar-planning.cjs swapSession) : planning des entraînements (section légère).
  calendar_session: NONE,
  // Décisions sur les joueurs du club : la section des clubs est relue.
  set_player_load: except('clubs'), appliquer_avis_kine: except('clubs'), set_development_focus: except('clubs'), training_plan: except('clubs'),
  // Poste à apprendre (familiarite-poste.cjs) : un champ du joueur du club, appliqué aux prochaines séances.
  set_position_learning: except('clubs'),
  staff_meeting: except('clubs'), relationship_conversation: except('clubs'), observe_player: except('clubs'),
  scout_mission: except('clubs'), extend_contract: except('clubs'), press_conference: except('clubs'),
  recruit: except('clubs', 'aiRoster', 'potentialEvolution'), league_detail_set: except('worldMode'),
  train: except('clubs', 'aiRoster', 'potentialEvolution'),
  // Réponse au courrier du club (club-mail.cjs, apply) : moral, confiance, presse, séance, caisse et journal (sections
  // légères), joueur du club ou jeune promu dans l'effectif du club du manager seulement (contrôlé par tests/club-mail.cjs).
  club_mail_reply: except('clubs'),
});

function untouched(command, payload) {
  // Causerie d'après-match : elle clôt la rencontre (PRESS_PROGRESSION côté worker) ; tout est relu.
  if (command === 'match_talk_continue') return payload && payload.phase === 'post' ? [] : NONE;
  return UNTOUCHED[command] || [];
}

// Décisions sur un joueur du club (charge, axe de progression, plan de travail, prolongation de contrat), réunion du
// staff et observation ciblée (prime ou coût débité au club) : parmi les sections lourdes, elles ne touchent que le club
// du manager dans `clubs` (S.clubs[S.club], S.club inchangé). Les autres clubs (~13,8 Mo) ne sont alors pas
// resérialisés ; le club du manager l'est, joueur par joueur et champ par champ (voir SOURCE, parties de la section des
// clubs). Vérifié en mode vérification (les autres clubs sont relus et comparés).
const OWN_CLUB = Object.freeze(new Set(['set_player_load', 'appliquer_avis_kine', 'set_development_focus', 'set_position_learning', 'training_plan', 'extend_contract', 'staff_meeting', 'observe_player', 'club_mail_reply']));
const ownClubOnly = command => OWN_CLUB.has(command);

// Commandes sans effet sur la note et les qualités des joueurs, même si elles touchent la section des clubs (consigne de
// charge, axe de progression : appliqués à la prochaine séance).
const PLAYERS_STABLE = Object.freeze(new Set(['set_player_load', 'appliquer_avis_kine', 'set_development_focus', 'set_position_learning']));

// Commande sans effet sur aucune section lourde (clubs et centres compris), ou déclarée sans effet sur les qualités : la
// note et les qualités des joueurs ne bougent pas ; la complétion des attributs détaillés n'a pas à relever leurs
// qualités (player-attributes.cjs, mode `stable`). Vérifié en mode vérification (toute progression constatée lève une
// erreur).
const playersUntouched = (command, payload) => PLAYERS_STABLE.has(command) || untouched(command, payload).length === HEAVY.length;

// Code exécuté dans la VM de la carrière : `nativeStateVersions.refresh(trusted, verify, ownClub)` rend une Map
// clé → jeton (« clé#n »), à passer à nativeSystems.projectParts.
//
// Parties de sections (jetons « section~partie ») : une lecture ne dépend que de ce qu'elle lit vraiment.
//   - clubs : `clubs~others` (tous les clubs sauf celui du manager), `clubs~own` (club du manager sans ses joueurs),
//     `clubs~roster` (liste des clés de chaque joueur du club, dans l'ordre), `clubs~p:<champ>` (valeurs d'un champ pour
//     les joueurs du club). Sans club du manager exploitable, la section garde un seul jeton `clubs`.
//   - manager : `manager~keys` (clés) et `manager~.<clé>` (valeur de chaque clé).
// Le relevé des lectures (trace) passe par des mandataires sur S, S.clubs, le club du manager, ses joueurs et S.manager.
// Lire un champ absent rend aussi dépendant de la liste des clés (un champ qui apparaît périme la lecture) ; une
// énumération (clés, JSON, copie) dépend de la liste des clés et de chaque valeur lue.
const SOURCE = `const nativeStateVersions=(()=>{
 const HEAVY=new Set(${JSON.stringify(HEAVY)});
 let state=null,counter=0,current=new Map();const texts=new Map(),versions=new Map(),dirty=new Set(),partsOf=new Map();
 let verifying=false;const memos=new Map(),computed=Object.create(null),later=new Map();
 const plain=v=>!!v&&typeof v==='object'&&!Array.isArray(v);
 const isIndex=k=>typeof k==='string'&&/^(0|[1-9][0-9]*)$/.test(k);
 // Club du manager isolable dans la section des clubs (sinon null : jeton unique pour la section).
 function ownClub(s){
  const clubs=s.clubs,o=s.club;
  if(!Array.isArray(clubs)||!Number.isSafeInteger(o)||o<0||o>=clubs.length||!Object.hasOwn(clubs,o))return null;
  const c=clubs[o];if(!plain(c)||!Object.hasOwn(c,'players')||!Array.isArray(c.players))return null;
  for(let i=0;i<c.players.length;i++)if(!Object.hasOwn(c.players,i)||!plain(c.players[i]))return null;
  return c;
 }
 // Champs objets des joueurs du club suivis clé par clé ; SUBSPLIT : sous-objets suivis un niveau plus bas (axe de
 // progression : focus et XP changent au choix d'un axe, les bonus acquis seulement à la séance).
 const NESTED=new Set(['dev']),SUBSPLIT=new Set(['dev.specialization']);
 // Jetons d'un champ objet (chemin « dev » ou « dev.specialization ») : nature par joueur, clés, puis valeur clé par clé.
 const ABSENT={};
 function fieldParts(out,path,values){
  const obj=v=>v!==ABSENT&&plain(v);
  out.set('clubs~p:'+path+'~kind',JSON.stringify(values.map(v=>v===ABSENT?0:obj(v)?1:'v'+JSON.stringify(v))));
  out.set('clubs~p:'+path+'~keys',JSON.stringify(values.map(v=>obj(v)?Object.keys(v):0)));
  const inner=new Set();for(const v of values)if(obj(v))for(const k of Object.keys(v))inner.add(k);
  for(const k of inner){
   const sub=path+'.'+k;
   if(SUBSPLIT.has(sub)){fieldParts(out,sub,values.map(v=>obj(v)&&Object.hasOwn(v,k)?v[k]:ABSENT));continue;}
   out.set('clubs~p:'+sub,JSON.stringify(values.map(v=>obj(v)&&Object.hasOwn(v,k)?v[k]:undefined)));
  }
 }
 // Sections de la sauvegarde encore exactes pour s (S inchangé depuis nativeSaveText) ; jamais en vérification.
 function savedSections(s){
  if(verifying||typeof nativeSectionsFresh==='undefined'||!nativeSectionsFresh||typeof nativeSaveSections==='undefined')return null;
  return nativeSaveSections&&nativeSaveSections.state===s?nativeSaveSections:null;
 }
 function clubParts(s,c,others){
  const out=new Map(),o=s.club,players=c.players;
  if(others){
   // Textes de la sauvegarde qui vient d'être assemblée (worker.cjs, nativeSaveText) : même carrière, même texte.
   const saved=savedSections(s);
   if(saved&&saved.clubs&&saved.clubs.length===s.clubs.length){const list=saved.clubs.slice();list[o]='0';out.set('clubs~others','['+list.join(',')+']');}
   else out.set('clubs~others',JSON.stringify(s.clubs.map((x,i)=>i===o?0:x)));
  }
  const shell={};for(const k of Object.keys(c))shell[k]=k==='players'?0:c[k];
  out.set('clubs~own',JSON.stringify([o,shell]));
  const keys=players.map(p=>Object.keys(p)),fields=new Set();for(const list of keys)for(const k of list)fields.add(k);
  out.set('clubs~roster',JSON.stringify(keys));
  for(const f of fields){
   if(!NESTED.has(f)){out.set('clubs~p:'+f,JSON.stringify(players.map(p=>Object.hasOwn(p,f)?p[f]:undefined)));continue;}
   // Champ objet découpé un niveau plus bas (dev : progression, potentiel, axe de travail…).
   fieldParts(out,f,players.map(p=>Object.hasOwn(p,f)?p[f]:ABSENT));
  }
  return out;
 }
 function objectParts(key,v){
  const out=new Map();
  if(!plain(v)){out.set(key+'~keys','v'+JSON.stringify(v));return out;}
  out.set(key+'~keys',JSON.stringify(Object.keys(v)));
  for(const k of Object.keys(v))out.set(key+'~.'+k,String(JSON.stringify(v[k])));
  return out;
 }
 const SPLIT=new Set(['manager']);
 const changed=(key,command)=>Error('Section de carrière modifiée par une commande déclarée sans effet sur elle : '+key+' ('+command+').');
 function refresh(trustedList,verify,ownList){
  const trusted=new Set(trustedList||[]),own=new Set(ownList||[]),same=S===state,out=new Map();verifying=!!verify;
  const command=typeof nativeCommand==='string'?nativeCommand:'lecture';
  if(!S){state=null;current=out;return out;}
  const put=(key,parts,check)=>{
   const list=[];
   for(const [k,text] of parts){
    if(check&&check(k)&&text!==texts.get(k))throw changed(k,command);
    if(texts.get(k)!==text){texts.set(k,text);versions.set(k,k+'#'+(++counter));}
    out.set(k,versions.get(k));list.push(k);
   }
   partsOf.set(key,list);
  };
  for(const key of Object.keys(S)){
   const known=partsOf.get(key);
   // Section lourde touchée pendant le direct sans être relue : nouveau jeton à chaque projection (tout ce qui la lit
   // est recalculé), texte relu à la prochaine projection complète.
   if(same&&known&&dirty.has(key)&&trusted.has(key)&&!verify){for(const k of known){versions.set(k,k+'#'+(++counter)+'~');out.set(k,versions.get(k));}continue;}
   const keep=same&&!!known&&HEAVY.has(key)&&trusted.has(key)&&!dirty.has(key);
   if(keep&&!verify){for(const k of known)out.set(k,versions.get(k));continue;}
   if(key==='clubs'){
    const c=ownClub(S);
    if(c){
     // Décision sur le club du manager : les autres clubs gardent leur jeton (relus et comparés en vérification).
     const ownOnly=!keep&&same&&own.has(key)&&!dirty.has(key)&&!!known&&known.includes('clubs~others');
     if(ownOnly&&!verify){out.set('clubs~others',versions.get('clubs~others'));put(key,[['clubs~others',texts.get('clubs~others')],...clubParts(S,c,false)]);}
     else put(key,clubParts(S,c,true),keep?()=>true:ownOnly?k=>k==='clubs~others':null);
     dirty.delete(key);continue;
    }
   }
   if(SPLIT.has(key)&&!HEAVY.has(key)){put(key,objectParts(key,S[key]));continue;}
   const saved=savedSections(S),text=saved&&saved.texts.has(key)?saved.texts.get(key):JSON.stringify(S[key]);
   if(text===undefined){partsOf.delete(key);continue;}
   put(key,[[key,text]],keep?()=>true:null);dirty.delete(key);
  }
  for(const key of [...partsOf.keys()])if(!Object.hasOwn(S,key)||!partsOf.get(key).every(k=>out.has(k)))partsOf.delete(key);
  for(const key of [...texts.keys()])if(!out.has(key)){texts.delete(key);versions.delete(key);}
  state=S;current=out;return out;
 }
 // Relevé des lectures : pile de collecteurs actifs (un calcul mémorisé, éventuellement imbriqué dans un autre via part) ;
 // chaque jeton lu va dans tous les collecteurs de la pile. « fast » retient les jetons déjà notés depuis le dernier
 // changement de pile (les mandataires sont sur des chemins chauds : salaires, devis…).
 const stack=[];let fast=Object.create(null),fastField=Object.create(null),fineDepth=0;
 const FK=Object.create(null),MK=Object.create(null);
 const note=k=>{if(fast[k]===1)return;fast[k]=1;for(const c of stack)c.read.add(k);};
 const resetFast=()=>{fast=Object.create(null);fastField=Object.create(null);};
 const push=fine=>{const c={read:new Set(),all:false,fine};stack.push(c);if(fine)fineDepth++;resetFast();return c;};
 const pop=c=>{const i=stack.lastIndexOf(c);if(i>=0)stack.splice(i,1);if(c.fine)fineDepth--;resetFast();};
 const noteAll=()=>{for(const c of stack)c.all=true;};
 // Mandataire de real (S) pour un calcul mémorisé : lectures notées partie par partie si les versions courantes
 // décrivent real (après refresh, dans la même projection), sinon par section de premier niveau. done() referme le relevé.
 function trace(real){
  const fine=real===state,c=push(fine);
  const clubsKeys=fine?partsOf.get('clubs'):null;
  const own=clubsKeys&&clubsKeys.includes('clubs~others')?ownClub(real):null;
  // Tableaux ou objets figés : pas de mandataire (invariants des Proxy), section lue en entier.
  const club=own&&Object.isExtensible(real.clubs)&&Object.isExtensible(own)&&Object.isExtensible(own.players)?own:null;
  const managerFine=fine&&!!partsOf.get('manager')&&plain(real.manager)&&Object.isExtensible(real.manager);
  const addAll=filter=>{for(const k of clubsKeys)if(filter(k))note(k);};
  const everything=()=>addAll(()=>true),playersAll=()=>addAll(k=>k==='clubs~roster'||k.startsWith('clubs~p:'));
  const roster=()=>{if(fast['clubs~roster']!==1)note('clubs~roster');};
  let clubsP=null,ownP=null,playersP=null,managerP=null;const pp=new Map();
  const nested=new Map(),NK=Object.create(null);
  // Sous-objet suivi clé par clé (chemin f : « dev », « dev.specialization ») ; un sous-objet de SUBSPLIT est mandaté à
  // son tour, sinon (valeur non objet ou figée) toutes ses parties sont lues.
  const inner=(f,v)=>{let x=nested.get(v);if(!x){const keys='clubs~p:'+f+'~keys';x=new Proxy(v,{
   get(t,k){
    if(typeof k==='string'){
     const sub=f+'.'+k;
     if(!Object.hasOwn(t,k))note(keys);
     if(SUBSPLIT.has(sub)){const w=t[k];note('clubs~p:'+sub+'~kind');if(!plain(w))return w;if(Object.isExtensible(w))return inner(sub,w);addAll(x=>x.startsWith('clubs~p:'+sub+'.')||x==='clubs~p:'+sub+'~keys');return w;}
     note(NK[sub]??=('clubs~p:'+sub));
    }
    return t[k];},
   has(t,k){note(keys);return k in t;},
   ownKeys(t){note(keys);return Reflect.ownKeys(t);},
   getOwnPropertyDescriptor(t,k){note(keys);return Reflect.getOwnPropertyDescriptor(t,k);}});nested.set(v,x);}return x;};
  const player=p=>{let x=pp.get(p);if(!x){x=new Proxy(p,{
   get(t,k){
    if(typeof k==='string'&&NESTED.has(k)){
     if(!Object.hasOwn(t,k))roster();
     // Valeur non objet (champ absent compris) : entièrement décrite par le jeton « ~kind ».
     const v=t[k];note('clubs~p:'+k+'~kind');
     if(!plain(v))return v;
     if(Object.isExtensible(v))return inner(k,v);
     addAll(x=>x.startsWith('clubs~p:'+k+'.')||x==='clubs~p:'+k+'~keys');return v;
    }
    if(typeof k==='string'&&fastField[k]!==1){
     if(fast['clubs~roster']!==1&&!Object.hasOwn(t,k)){note('clubs~roster');}
     else fastField[k]=1;
     note(FK[k]??=('clubs~p:'+k));
    }
    return t[k];
   },
   has(t,k){roster();return k in t;},
   ownKeys(t){roster();return Reflect.ownKeys(t);},
   getOwnPropertyDescriptor(t,k){roster();return Reflect.getOwnPropertyDescriptor(t,k);}});pp.set(p,x);}return x;};
  const players=()=>playersP??=new Proxy(club.players,{
   get(t,k){if(typeof k==='string'){roster();if(isIndex(k)){const v=t[k];return plain(v)&&Object.isExtensible(v)?player(v):(playersAll(),v);}}return t[k];},
   has(t,k){roster();return k in t;},
   ownKeys(t){roster();return Reflect.ownKeys(t);},
   getOwnPropertyDescriptor(t,k){roster();if(isIndex(k))playersAll();return Reflect.getOwnPropertyDescriptor(t,k);}});
  const ownClubP=()=>ownP??=new Proxy(club,{
   get(t,k){if(k==='players')return players();if(typeof k==='string')note('clubs~own');return t[k];},
   has(t,k){note('clubs~own');return k in t;},
   ownKeys(t){note('clubs~own');return Reflect.ownKeys(t);},
   getOwnPropertyDescriptor(t,k){note('clubs~own');if(k==='players')playersAll();return Reflect.getOwnPropertyDescriptor(t,k);}});
  const o=club?String(real.club):null;
  const clubs=()=>clubsP??=new Proxy(real.clubs,{
   get(t,k){if(k===o)return ownClubP();if(typeof k==='string'&&fast['clubs~others']!==1)note('clubs~others');return t[k];},
   has(t,k){note('clubs~others');return k in t;},
   ownKeys(t){everything();return Reflect.ownKeys(t);},
   getOwnPropertyDescriptor(t,k){note('clubs~others');if(k===o)everything();return Reflect.getOwnPropertyDescriptor(t,k);}});
  const managerKeys=()=>{for(const k of partsOf.get('manager'))note(k);};
  const manager=()=>managerP??=new Proxy(real.manager,{
   get(t,k){if(typeof k==='string'){note(MK[k]??=('manager~.'+k));if(!Object.hasOwn(t,k))note('manager~keys');}return t[k];},
   has(t,k){note('manager~keys');return k in t;},
   ownKeys(t){note('manager~keys');return Reflect.ownKeys(t);},
   getOwnPropertyDescriptor(t,k){note('manager~keys');return Reflect.getOwnPropertyDescriptor(t,k);}});
  const proxy=new Proxy(real,{
   get(t,k){
    if(typeof k==='string'){
     if(k==='clubs'){if(club)return clubs();if(own)everything();else note(k);}
     else if(k==='manager'){if(managerFine)return manager();note(k);}
     else note(k);
    }
    return Reflect.get(t,k,t);
   },
   has(t,k){if(typeof k==='string'){if(k==='clubs'&&own)note('clubs~others');else if(k==='manager'&&managerFine)note('manager~keys');else note(k);}return Reflect.has(t,k);},
   ownKeys(t){noteAll();return Reflect.ownKeys(t);},
   getOwnPropertyDescriptor(t,k){if(typeof k==='string'){if(k==='clubs'&&own)everything();else if(k==='manager'&&managerFine)managerKeys();else note(k);}return Reflect.getOwnPropertyDescriptor(t,k);}
  });
  return {proxy,read:c.read,all:()=>c.all,done:()=>pop(c)};
 }
 // Partie d'un calcul mémorisé (dans un relevé fin en cours) reprise tant que les jetons qu'elle a lus n'ont pas changé ;
 // ses lectures sont reportées au calcul englobant. Hors relevé fin : calcul direct. Valeur JSON seulement.
 const partMemos=new Map();
 function part(name,compute){
  if(!fineDepth||!stack.length||!stack[stack.length-1].fine&&!stack.some(c=>c.fine))return compute();
  const hit=partMemos.get(name);
  if(hit&&!hit.all&&hit.deps.every(([k,v])=>current.get(k)===v)&&!verifying){for(const [k] of hit.deps)note(k);return JSON.parse(hit.text);}
  const c=push(true);let text;
  try{text=JSON.stringify(compute());}finally{pop(c);}
  if(c.all)noteAll();
  if(hit&&verifying&&!hit.all&&hit.deps.every(([k,v])=>current.get(k)===v)&&text!==hit.text)throw Error('Mémoire de projection périmée : '+name+'.');
  partMemos.set(name,{text,all:c.all,deps:[...c.read].map(k=>[k,current.get(k)])});
  return text===undefined?undefined:JSON.parse(text);
 }
 return {
  refresh,trace,part,
  current(){return current;},
  // Nombre de calculs (hors reprise) de chaque texte mémorisé par memoText (tests).
  computed(){return {...computed};},
  // Texte JSON de compute(S) repris tant que les jetons lus lors du dernier calcul n'ont pas changé (relevé par trace).
  // Fonctions de S seulement : à n'utiliser qu'après refresh, dans la même projection. En vérification, recalcul et
  // comparaison.
  // \`stringify\` (facultatif) : mise en texte de la valeur, identique à JSON.stringify pour elle.
  memoText(name,compute,stringify=JSON.stringify){
   const hit=memos.get(name);
   if(hit&&!hit.all&&hit.deps.every(([k,v])=>current.get(k)===v)){
    if(verifying){const fresh=stringify(compute(S));if(fresh!==hit.text)throw Error('Mémoire de projection périmée : '+name+'.');}
    return hit.text;
   }
   const real=S,t=trace(real);computed[name]=(computed[name]||0)+1;
   let text;S=t.proxy;
   try{text=stringify(compute(t.proxy));}finally{S=real;t.done();}
   memos.set(name,{text,all:t.all(),deps:[...t.read].map(k=>[k,current.get(k)])});
   return text;
  },
  // Comme memoText, sans relevé au calcul : sur une mémoire périmée, calcul direct (sans mandataires, environ deux fois
  // plus rapide) et relevé différé, fait par warm() après la réponse si la carrière n'a pas bougé entre-temps. En
  // vérification, relevé immédiat (memoText).
  memoTextLater(name,compute,stringify=JSON.stringify){
   const hit=memos.get(name);
   if(verifying||hit&&!hit.all&&hit.deps.every(([k,v])=>current.get(k)===v))return this.memoText(name,compute,stringify);
   computed[name]=(computed[name]||0)+1;
   const text=stringify(compute(S));
   later.set(name,{compute,stringify,state:S,current,text});
   return text;
  },
  // Relevés différés (après la réponse) : seulement sur la même carrière et les mêmes versions qu'au calcul direct,
  // sinon abandonnés. Le texte relevé doit être celui du calcul direct.
  warm(){
   for(const [name,w] of later){
    later.delete(name);
    if(w.state!==S||w.current!==current||!S)continue;
    memos.delete(name);
    if(this.memoText(name,w.compute,w.stringify)!==w.text){memos.delete(name);throw Error('Mémoire de projection : relevé différé différent du calcul direct ('+name+').');}
   }
  },
  dropLater(){later.clear();},
  hasLater(){return later.size>0;},
  // Sections lourdes modifiées sans être relues (direct du match) : relues à la prochaine projection complète.
  markDirty(keys){for(const key of keys)dirty.add(key);},
  // Carrière rétablie à l'identique (commande refusée, état relu depuis son texte d'avant) : les textes connus la décrivent.
  adopt(){if(S)state=S;},
  reset(){state=null;memos.clear();later.clear();partMemos.clear();texts.clear();versions.clear();dirty.clear();partsOf.clear();current=new Map();}
 };
})();`;

module.exports = { HEAVY, UNTOUCHED, OWN_CLUB, untouched, ownClubOnly, playersUntouched, SOURCE };

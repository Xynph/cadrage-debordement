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
  academy_groups_preview: NONE, interclub_negotiate: NONE, save: NONE,
  // Réglages, consignes, rendez-vous, causeries : sections légères seulement.
  set_tactics: NONE, set_penalty_policy: NONE, set_collective_focus: NONE, set_opponent_level: NONE,
  set_delegation: NONE, press_policy: NONE, club_follow: NONE, set_lineup: NONE, auto_lineup: NONE,
  club_meeting_ack: NONE, club_meeting_continue: NONE, pause: NONE, match_talk_decide: NONE,
  manager_recruitment_watch: NONE, regen_shortlist: NONE,
  // Décisions sur les joueurs du club : la section des clubs est relue.
  set_player_load: except('clubs'), set_development_focus: except('clubs'), training_plan: except('clubs'),
  staff_meeting: except('clubs'), relationship_conversation: except('clubs'), observe_player: except('clubs'),
  scout_mission: except('clubs'), extend_contract: except('clubs'), press_conference: except('clubs'),
  recruit: except('clubs', 'aiRoster', 'potentialEvolution'), league_detail_set: except('worldMode'),
  train: except('clubs', 'aiRoster', 'potentialEvolution'),
});

function untouched(command, payload) {
  // Causerie d'après-match : elle clôt la rencontre (PRESS_PROGRESSION côté worker) ; tout est relu.
  if (command === 'match_talk_continue') return payload && payload.phase === 'post' ? [] : NONE;
  return UNTOUCHED[command] || [];
}

// Commande sans effet sur aucune section lourde (clubs et centres compris) : la note et les qualités des joueurs ne
// bougent pas ; la complétion des attributs détaillés n'a pas à relever leurs qualités (player-attributes.cjs, mode
// `stable`). Vérifié en mode vérification (toute progression constatée lève une erreur).
const playersUntouched = (command, payload) => untouched(command, payload).length === HEAVY.length;

// Code exécuté dans la VM de la carrière : `nativeStateVersions.refresh(trusted, dirty, verify)` rend une Map
// clé → jeton (« clé#n »), à passer à nativeSystems.projectParts.
const SOURCE = `const nativeStateVersions=(()=>{
 const HEAVY=new Set(${JSON.stringify(HEAVY)});
 let state=null,counter=0,current=new Map();const texts=new Map(),versions=new Map(),dirty=new Set();
 let verifying=false;const memos=new Map();
 function refresh(trustedList,verify){
  const trusted=new Set(trustedList||[]),same=S===state,out=new Map();verifying=!!verify;
  if(!S){state=null;current=out;return out;}
  for(const key of Object.keys(S)){
   // Section lourde touchée pendant le direct sans être relue : nouveau jeton à chaque projection (tout ce qui la lit
   // est recalculé), texte relu à la prochaine projection complète.
   if(same&&dirty.has(key)&&trusted.has(key)&&!verify){versions.set(key,key+'#'+(++counter)+'~');out.set(key,versions.get(key));continue;}
   const keep=same&&HEAVY.has(key)&&trusted.has(key)&&texts.has(key)&&!dirty.has(key);
   if(keep&&!verify){out.set(key,versions.get(key));continue;}
   const text=JSON.stringify(S[key]);
   if(text===undefined){texts.delete(key);versions.delete(key);continue;}
   if(keep&&text!==texts.get(key))throw Error('Section de carrière modifiée par une commande déclarée sans effet sur elle : '+key+' ('+(typeof nativeCommand==='string'?nativeCommand:'lecture')+').');
   if(texts.get(key)!==text){texts.set(key,text);versions.set(key,key+'#'+(++counter));}
   out.set(key,versions.get(key));dirty.delete(key);
  }
  for(const key of [...texts.keys()])if(!out.has(key)){texts.delete(key);versions.delete(key);}
  state=S;current=out;return out;
 }
 return {
  refresh,
  current(){return current;},
  // Texte JSON de compute(S) repris tant que les sections de S lues lors du dernier calcul gardent leur version
  // (relevé par un mandataire sur S, comme la mémoire des domaines). Fonctions de S seulement : à n'utiliser
  // qu'après refresh, dans la même projection. En vérification, recalcul et comparaison.
  memoText(name,compute){
   const hit=memos.get(name);
   if(hit&&!hit.all&&hit.deps.every(([k,v])=>current.get(k)===v)){
    if(verifying){const fresh=JSON.stringify(compute(S));if(fresh!==hit.text)throw Error('Mémoire de projection périmée : '+name+'.');}
    return hit.text;
   }
   const real=S,read=new Set();let all=false;
   const traced=new Proxy(real,{get(t,k){if(typeof k==='string')read.add(k);return Reflect.get(t,k,t);},has(t,k){if(typeof k==='string')read.add(k);return Reflect.has(t,k);},ownKeys(t){all=true;return Reflect.ownKeys(t);},getOwnPropertyDescriptor(t,k){if(typeof k==='string')read.add(k);return Reflect.getOwnPropertyDescriptor(t,k);}});
   let text;S=traced;
   try{text=JSON.stringify(compute(traced));}finally{S=real;}
   memos.set(name,{text,all,deps:[...read].map(k=>[k,current.get(k)])});
   return text;
  },
  // Sections lourdes modifiées sans être relues (direct du match) : relues à la prochaine projection complète.
  markDirty(keys){for(const key of keys)dirty.add(key);},
  // Carrière rétablie à l'identique (commande refusée, état relu depuis son texte d'avant) : les textes connus la décrivent.
  adopt(){if(S)state=S;},
  reset(){state=null;memos.clear();texts.clear();versions.clear();dirty.clear();current=new Map();}
 };
})();`;

module.exports = { HEAVY, UNTOUCHED, untouched, playersUntouched, SOURCE };

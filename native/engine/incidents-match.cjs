'use strict';
// Incidents de match (carrière Monde, règles du rugby pro, comme le protocole commotion de club-support.cjs) :
//  - blessure : le joueur sort pour de bon, le remplaçant le plus apte au poste entre (choix du staff) ; la durée
//    d'indisponibilité est tirée pendant le match mais appliquée après la rencontre (applyMatchInjuries, rugby.js) ;
//  - saignement (loi 3, remplacement temporaire) : le joueur se fait soigner hors du terrain et revient au bout de 4 à
//    15 minutes de jeu si son poste le permet, sinon il reste sur le banc ; une fois sur dix, il ne revient pas.
// Fréquences (hypothèses prudentes, deux équipes réunies) : 0,5 blessure et 0,3 saignement par match. Gravité des
// blessures : 1 semaine (30 %), 2 (25 %), 3 (20 %), 4 (12 %), 6 (8 %), 8 (5 %).
// Tirages sans aléa du moteur (empreinte de la carrière, de la rencontre et de la minute) : le flux Math.random ne
// change pas. Les matchs commencés avant cette version (sans `incidentsVersion`) restent tels quels.
//
// Choix du manager : sur un remplacement forcé de son équipe (blessure, saignement, HIA, commotion, couverture de
// première ligne), le staff choisit d'abord ; `l.incidentChoix` propose ensuite au manager les autres joueurs permis
// (commande `match_incident_choice`, payload {cle, id}), sauf si le match est délégué. Sans réponse, le choix du staff reste.
const files=Object.freeze([]),commands=Object.freeze(['match_incident_choice']);
function factory(){
 const INCIDENTS=Object.freeze({blessure:.5/80,saignement:.3/80,semaines:Object.freeze([[1,.30],[2,.25],[3,.20],[4,.12],[6,.08],[8,.05]]),soinMin:4,soinMax:15,sansRetour:.1,historique:60});
 const KINDS=Object.freeze(['blessure','saignement']),CHOICE_KINDS=Object.freeze(['blessure','saignement','hia','commotion','premiere-ligne']);
 // Motif du remplacement (l.subs) de chaque sorte d'incident.
 const REASON=Object.freeze({blessure:'blessure',saignement:'saignement',hia:'hia',commotion:'commotion','premiere-ligne':'frontcover'});
 const check=(ok,message='Choix d’incident invalide.')=>{if(!ok)throw Error(message);};
 const obj=x=>!!x&&typeof x==='object'&&!Array.isArray(x),int=(x,a,b)=>Number.isInteger(x)&&x>=a&&x<=b;
 const exact=(x,list)=>obj(x)&&Object.keys(x).length===list.length&&list.every(k=>Object.hasOwn(x,k));
 function mix(text){let h=0x811c9dc5;for(let i=0;i<text.length;i++){h^=text.charCodeAt(i);h=Math.imul(h,0x01000193)>>>0;}h^=h>>>16;h=Math.imul(h,0x85ebca6b)>>>0;h^=h>>>13;h=Math.imul(h,0xc2b2ae35)>>>0;h^=h>>>16;return h>>>0;}
 const careerSalt=s=>String(s?.careerVariation?.seed??s?.leagueDetail?.salt??s?.commonDatabase?.id??'cd');
 const draw=key=>mix('incident|'+careerSalt(S)+'|'+key)/4294967296;
 const world=()=>typeof CDWorldCareer!=='undefined'&&CDWorldCareer.active(S);
 const matchKey=l=>l?.worldContext?.id?[S.season,l.worldContext.id,l.pair.join('-')].join('|'):null;
 const nameOf=(l,side,id)=>matchPlayer(l,side,id)?.name||'Le joueur',abbrOf=(l,side)=>S.clubs[l.pair[side]].abbr;
 const delegated=()=>{try{return typeof nativeSystems!=='undefined'&&nativeSystems.domain('matchDelegation')?.actif?.()===true;}catch(e){return false;}};
 const staffOrder=slot=>(a,b)=>fitScore(b,FAMILIES[slot])-fitScore(a,FAMILIES[slot])||String(a.id).localeCompare(String(b.id));
 const severity=u=>{let acc=0;for(const [w,p] of INCIDENTS.semaines){acc+=p;if(u<acc)return w;}return INCIDENTS.semaines.at(-1)[0];};
 // Même échange que le protocole commotion : le sortant va sur le banc, l'entrant est compté une fois.
 function swap(l,side,slot,incoming,reason){
  const sh=l.sheets[side],out=sh.on[slot],returning=sh.used.includes(incoming);
  sh.bench=sh.bench.filter(id=>id!==incoming);sh.bench.push(out);sh.on[slot]=incoming;
  if(frontRowRules(l))sh.front.held=sh.front.held.filter(h=>h.id!==incoming);
  if(!returning)sh.used.push(incoming);
  sh.subs++;l.subs.push({minute:l.minute,side,out,in:incoming,reason,returning});
 }
 // Blessé (sortie définitive) ou saignement en cours de soins : il ne peut pas revenir par un changement.
 function blocked(l,side,id){return l?.incidentsVersion===1&&Array.isArray(l.incidents)&&l.incidents.some(x=>x.side===side&&x.id===id&&(x.etat==='en_cours'||x.etat==='definitif'));}
 function matchMinute(l){
  if(!l||l.finished||!world())return;
  if(l.incidentsVersion===undefined){if(l.minute!==1||!l.worldContext||!revisedRules(l))return;l.incidentsVersion=1;l.incidents=[];}
  if(l.incidentsVersion!==1)return;
  if(l.incidentChoix&&!choiceState(l))delete l.incidentChoix;
  for(const x of l.incidents)if(x.kind==='saignement'&&x.etat==='en_cours'&&x.until<=l.minute)resolveBlood(l,x);
  const key=matchKey(l);if(!key)return;
  for(const kind of KINDS){
   if(draw(kind+'|'+key+'|'+l.minute)>=INCIDENTS[kind])continue;
   const cands=[];
   for(const side of [0,1]){const sh=l.sheets[side];for(const p of activePlayers(l,side)){const slot=sh.on.indexOf(p.id);if(slot>=0&&eligibleChanges(l,side,slot).length)cands.push({side,slot});}}
   if(!cands.length)continue;
   const v=cands[Math.min(cands.length-1,Math.floor(draw(kind+'-joueur|'+key+'|'+l.minute)*cands.length))];
   start(l,v.side,v.slot,kind);
  }
 }
 // Incident du joueur du poste `slot` à la minute en cours ; rend l'entrée ajoutée, ou null.
 function start(l,side,slot,kind){
  if(l?.incidentsVersion!==1||l.finished||!KINDS.includes(kind))return null;
  const sh=l.sheets[side],p=matchPlayer(l,side,sh.on[slot]);
  if(!p||sh.cards.some(c=>c.id===p.id&&c.until>l.minute)||l.incidents.length>=INCIDENTS.historique)return null;
  const options=eligibleChanges(l,side,slot).sort(staffOrder(slot)),repl=options[0];
  if(!repl)return null;
  swap(l,side,slot,repl.id,kind);
  const key=matchKey(l)||'',x={n:l.incidents.length,side,id:p.id,slot,minute:l.minute,kind,repl:repl.id,until:null,etat:'definitif'};
  if(kind==='blessure')x.semaines=severity(draw('gravite|'+key+'|'+l.minute+'|'+p.id));
  else{x.until=l.minute+INCIDENTS.soinMin+Math.min(INCIDENTS.soinMax-INCIDENTS.soinMin,Math.floor(draw('soins|'+key+'|'+l.minute+'|'+p.id)*(INCIDENTS.soinMax-INCIDENTS.soinMin+1)));x.etat='en_cours';}
  l.incidents.push(x);
  addEvent(l,kind==='blessure'?`${abbrOf(l,side)} · Blessure : ${p.name} doit quitter le terrain, ${repl.name} le remplace.`:`${abbrOf(l,side)} · Saignement : ${p.name} sort se faire soigner, ${repl.name} le remplace temporairement.`,'sub',{team:side,actor:p.id,incident:kind});
  offer(l,{type:'entrant',kind,side,slot,sortant:p.id,entrant:repl.id,options:options.map(q=>q.id)});
  return x;
 }
 // Fin des soins (15 minutes au plus, loi 3) : retour à son poste s'il est libre et permis, sinon il reste sur le banc.
 function resolveBlood(l,x,silent=false){
  if(x.etat!=='en_cours')return;
  const sh=l.sheets[x.side],key=matchKey(l)||'';
  if(draw('sans-retour|'+key+'|'+x.minute+'|'+x.id)<INCIDENTS.sansRetour){x.etat='definitif';if(!silent)addEvent(l,`${abbrOf(l,x.side)} · ${nameOf(l,x.side,x.id)} ne reviendra pas : le saignement n’a pas pu être arrêté.`,'sub',{team:x.side,actor:x.id,incident:'saignement'});return;}
  const current=sh.on[x.slot],p=matchPlayer(l,x.side,x.id);
  const free=!silent&&!l.finished&&current&&p&&!sh.cards.some(c=>c.id===current&&c.until>l.minute)&&sh.bench.includes(x.id)&&!sh.sentOff.includes(x.id)&&slotEligible(p,x.slot)&&!(frontRowRules(l)&&x.slot<3&&sh.front.exclusions.some(e=>e.slot===x.slot&&!e.closed));
  if(free){x.etat='retour';swap(l,x.side,x.slot,x.id,'saignement-retour');addEvent(l,`${abbrOf(l,x.side)} · ${p.name}, soigné, revient en jeu à la place de ${nameOf(l,x.side,current)}.`,'sub',{team:x.side,actor:x.id,incident:'saignement'});}
  else{x.etat='apte';if(!silent)addEvent(l,`${abbrOf(l,x.side)} · ${nameOf(l,x.side,x.id)} est soigné mais reste sur le banc.`,'sub',{team:x.side,actor:x.id,incident:'saignement'});}
 }
 // Après le match (fin de applyMatchInjuries) : soins en cours clos, durée des blessures appliquée.
 function afterMatch(l){
  if(l?.incidentsVersion!==1)return 0;
  delete l.incidentChoix;
  let n=0;
  for(const x of l.incidents){
   if(x.kind==='saignement'){resolveBlood(l,x,true);continue;}
   const p=matchPlayer(l,x.side,x.id);if(!p)continue;
   const before=Number(p.injury)||0;p.injury=Math.max(before,x.semaines);n++;
   if(p.injury>before&&l.pair[x.side]===S.club&&typeof news==='function')news(`${p.name} s’est blessé pendant la rencontre : ${p.injury} semaine${p.injury>1?"s":""} d’indisponibilité.`);
  }
  return n;
 }
 // --- Choix du manager --------------------------------------------------------------------------------------
 // `o` : {type:'entrant'|'sortant', kind, side, slot, sortant, entrant, options} juste après le choix du staff
 // (dernier évènement du journal). Équipe du manager seulement, jamais en match délégué.
 function offer(l,o){
  if(l?.incidentsVersion!==1||l.finished||o.side!==l.userSide||delegated()||!CHOICE_KINDS.includes(o.kind))return null;
  const current=o.type==='entrant'?o.entrant:o.sortant,options=[current,...o.options.filter(id=>id!==current)].filter((id,i,a)=>a.indexOf(id)===i);
  const evenement=l.events.length-1;
  l.incidentChoix={cle:'incident-'+(l.worldContext?.id??'match')+'-'+evenement,type:o.type,kind:o.kind,side:o.side,slot:o.slot,sortant:o.sortant,entrant:o.entrant,options,evenement,minute:l.minute};
  return l.incidentChoix;
 }
 // Joueurs qui peuvent sortir pour laisser entrer un spécialiste de première ligne (frontrow.js, avant l'échange).
 function sortants(l,side,incoming,slot){
  const sh=l.sheets[side];
  return sh.on.map((id,s)=>({id,s})).filter(x=>x.s>=3&&x.id&&frontAvailable(l,side,x.id)&&matchQuotaAllows(l,side,x.id,incoming,slot)).map(x=>x.id);
 }
 function frontCover(l,side,slot,donor,incoming,options){
  if(!Array.isArray(options))return null;
  return offer(l,{type:'sortant',kind:'premiere-ligne',side,slot,sortant:donor,entrant:incoming,options:[donor,...options]});
 }
 const touches=(l,from,side,id)=>l.subs.slice(from).some(s=>s.side===side&&(s.in===id||s.out===id));
 // Choix encore applicable : enregistrement du remplacement, options encore permises ; null sinon.
 function choiceState(l){
  const c=l?.incidentChoix;if(!c||l.finished||l.incidentsVersion!==1)return null;
  const sh=l.sheets[c.side];if(!sh)return null;
  let r=-1;for(let i=l.subs.length-1;i>=0;i--){const s=l.subs[i];if(s.side===c.side&&s.out===c.sortant&&s.in===c.entrant&&s.reason===REASON[c.kind]){r=i;break;}}
  if(r<0||touches(l,r+1,c.side,c.entrant)||touches(l,r+1,c.side,c.sortant))return null;
  if(c.type==='entrant'){
   if(sh.on[c.slot]!==c.entrant)return null;
   return {r,held:null,options:c.options.filter(id=>id===c.entrant||!touches(l,r+1,c.side,id)&&legalChange(l,c.side,c.slot,id))};
  }
  const held=frontRowRules(l)?sh.front.held.find(h=>h.id===c.sortant&&h.mode==='cover'):null;
  if(!held||sh.on[held.slot]!==null||!sh.bench.includes(c.sortant)||sh.on[c.slot]!==c.entrant)return null;
  return {r,held,options:c.options.filter(id=>id===c.sortant||!touches(l,r+1,c.side,id)&&sh.on.indexOf(id)>=3&&frontAvailable(l,c.side,id)&&matchQuotaAllows(l,c.side,id,c.sortant,held.slot))};
 }
 function applyChoice(l,c,st,id){
  const sh=l.sheets[c.side],rec=l.subs[st.r],abbr=abbrOf(l,c.side);
  if(c.type==='entrant'){
   const auto=c.entrant,before=sh.initial.includes(id)||l.subs.slice(0,st.r).some(s=>s.side===c.side&&s.in===id);
   sh.on[c.slot]=id;sh.bench=sh.bench.filter(x=>x!==id);sh.bench.push(auto);
   if(frontRowRules(l))sh.front.held=sh.front.held.filter(h=>h.id!==id);
   // L'entrant du staff retourne sur le banc sans compter de changement de plus.
   if(!rec.returning)sh.used=sh.used.filter(x=>x!==auto);
   if(!before&&!sh.used.includes(id))sh.used.push(id);
   rec.in=id;rec.returning=before;
   const list=c.kind==='hia'||c.kind==='commotion'?l.hia||[]:l.incidents;
   const x=list.find(h=>h.side===c.side&&h.id===c.sortant&&h.repl===auto&&h.minute===rec.minute);if(x)x.repl=id;
   addEvent(l,`${abbr} · Choix du manager : ${nameOf(l,c.side,id)} entre à la place de ${nameOf(l,c.side,auto)}.`,'sub',{team:c.side,actor:id});
   return;
  }
  const held=st.held,from=sh.on.indexOf(id),donor=c.sortant;
  sh.on[held.slot]=donor;sh.bench=sh.bench.filter(x=>x!==donor);sh.on[from]=null;sh.bench.push(id);
  held.id=id;held.slot=from;
  const e=sh.front.exclusions[held.caseIndex];if(e)e.releaseSlot=from;
  rec.out=id;
  addEvent(l,`${abbr} · Choix du manager : ${nameOf(l,c.side,id)} sort à la place de ${nameOf(l,c.side,donor)}, qui reste en jeu.`,'sub',{team:c.side,actor:id});
 }
 function execute(command,payload){
  check(command==='match_incident_choice','Commande d’incident inconnue.');
  check(!!S&&!!S.live&&!S.live.finished,'Aucun match en cours.');
  check(exact(payload,['cle','id'])&&typeof payload.cle==='string'&&(typeof payload.id==='string'||Number.isInteger(payload.id)),'Choix d’incident invalide.');
  const l=S.live,c=l.incidentChoix;
  check(!!c&&c.cle===payload.cle,'Choix d’incident périmé.');
  const st=choiceState(l);check(!!st,'Choix d’incident périmé : la situation a changé.');
  check(st.options.includes(payload.id),'Ce joueur ne peut pas être choisi.');
  const current=c.type==='entrant'?c.entrant:c.sortant;
  if(payload.id!==current)applyChoice(l,c,st,payload.id);
  delete l.incidentChoix;
  return {incidentChoice:{cle:payload.cle,id:payload.id,applique:payload.id!==current}};
 }
 // Direct (model.cjs) : choix en attente (options présentées) et derniers incidents.
 function live(l){
  if(l?.incidentsVersion!==1)return {};
  const st=choiceState(l),c=l.incidentChoix;
  const option=id=>{const p=matchPlayer(l,c.side,id);return {id,nom:p?.name||'',poste:p?.pos||'',energie:Math.round(p?.condition??0),actuel:id===(c.type==='entrant'?c.entrant:c.sortant)};};
  const choix=st?{cle:c.cle,type:c.type,kind:c.kind,side:c.side,slot:c.slot,sortant:c.sortant,entrant:c.entrant,evenement:c.evenement,minute:c.minute,options:st.options.map(option)}:null;
  const incidents=l.incidents.slice(-10).map(x=>({side:x.side,id:x.id,nom:nameOf(l,x.side,x.id),kind:x.kind,minute:x.minute,etat:x.etat,remplacant:x.repl,...(x.until===null?{}:{retour:x.until}),...(l.finished&&x.semaines?{semaines:x.semaines}:{})}));
  return {incidentChoix:choix,incidents};
 }
 // Sauvegarde du direct : incidents et choix en attente (les motifs de remplacement sont admis par dist/saves.js).
 function validate(s){
  const l=s?.live;if(!l||l.incidentsVersion===undefined){check(!l||l.incidents===undefined&&l.incidentChoix===undefined,'Incidents de match sans version.');return true;}
  check(l.incidentsVersion===1&&Array.isArray(l.incidents)&&l.incidents.length<=INCIDENTS.historique,'Incidents de match invalides.');
  l.incidents.forEach((x,n)=>{
   const sh=l.sheets?.[x?.side];
   check(exact(x,x?.kind==='blessure'?['n','side','id','slot','minute','kind','repl','until','etat','semaines']:['n','side','id','slot','minute','kind','repl','until','etat'])&&x.n===n&&sh&&sh.nominated.includes(x.id)&&sh.nominated.includes(x.repl)&&x.id!==x.repl&&int(x.slot,0,14)&&int(x.minute,1,l.minute)&&KINDS.includes(x.kind)&&['en_cours','retour','apte','definitif'].includes(x.etat),'Incident de match invalide.');
   if(x.kind==='blessure')check(x.until===null&&x.etat==='definitif'&&INCIDENTS.semaines.some(([w])=>w===x.semaines),'Blessure en match invalide.');
   else check(int(x.until,x.minute+INCIDENTS.soinMin,x.minute+INCIDENTS.soinMax)&&(x.etat!=='en_cours'||l.finished||x.until>l.minute),'Saignement invalide.');
   check(l.subs.some(r=>r.side===x.side&&r.minute===x.minute&&r.out===x.id&&r.in===x.repl&&r.reason===x.kind),'Remplacement d’incident introuvable.');
   if(x.etat==='en_cours'||x.etat==='definitif')check(!sh.on.includes(x.id),'Joueur blessé ou en soins revenu en jeu.');
   if(x.etat==='retour')check(l.subs.some(r=>r.side===x.side&&r.minute>=x.until&&r.in===x.id&&r.reason==='saignement-retour'),'Retour après saignement introuvable.');
  });
  for(const r of l.subs.filter(r=>['blessure','saignement'].includes(r.reason)))check(l.incidents.some(x=>x.side===r.side&&x.minute===r.minute&&x.id===r.out&&x.kind===r.reason),'Remplacement d’incident sans incident.');
  for(const r of l.subs.filter(r=>r.reason==='saignement-retour'))check(l.incidents.some(x=>x.side===r.side&&x.kind==='saignement'&&x.etat==='retour'&&x.id===r.in&&x.until<=r.minute),'Retour après saignement sans incident.');
  if(l.incidentChoix!==undefined){
   const c=l.incidentChoix,sh=l.sheets?.[c?.side];
   check(exact(c,['cle','type','kind','side','slot','sortant','entrant','options','evenement','minute'])&&typeof c.cle==='string'&&c.cle.startsWith('incident-')&&c.cle.length<=240&&['entrant','sortant'].includes(c.type)&&CHOICE_KINDS.includes(c.kind)&&(c.type==='sortant')===(c.kind==='premiere-ligne')&&c.side===l.userSide&&sh&&int(c.slot,0,14)&&sh.nominated.includes(c.sortant)&&sh.nominated.includes(c.entrant)&&c.sortant!==c.entrant&&Array.isArray(c.options)&&c.options.length>=1&&c.options.length<=23&&new Set(c.options).size===c.options.length&&c.options.every(id=>sh.nominated.includes(id))&&c.options[0]===(c.type==='entrant'?c.entrant:c.sortant)&&int(c.evenement,0,l.events.length-1)&&int(c.minute,1,l.minute),'Choix d’incident invalide.');
  }
  return true;
 }
 const api=Object.freeze({RULES:INCIDENTS,minute:matchMinute,start,afterMatch,blocked,offer,sortants,frontCover,choiceState,live,resolveBlood});
 return {project(){return null;},validate,execute,installHooks(){return true;},...api};
}
module.exports={files,commands,factory};

'use strict';
// Début de carrière Monde au lundi 13 juillet 2026 (décision de Léo, 13/11/2026) : la carrière
// commence avec la reprise des premiers clubs, cinq semaines avant l'ouverture du calendrier du
// moteur (lundi 17 août 2026, semaine 0). Entre les deux, une avant-saison vécue jour par jour :
// la date affichée avance, rien d'autre ne change (aucun tirage, aucun effet sportif). Toute
// commande qui fait avancer le calendrier du moteur (finir une semaine, jouer, s'entraîner,
// préparation sans match) ouvre d'abord le calendrier : les séquences du moteur sont identiques
// à celles d'une carrière ouverte le 17 août. Détail : docs/debut-13-juillet-20261113.md.
const files=Object.freeze([]),commands=Object.freeze(['preseason_advance']);
const FIRST_DAY='2026-07-13';
function factory(){
 const g=globalThis,DAY=86400000,FIRST_DAY='2026-07-13';
 const object=x=>!!x&&typeof x==='object'&&!Array.isArray(x);
 const dayOf=iso=>Math.floor(Date.parse(iso+'T00:00:00Z')/DAY);
 const iso=day=>new Date(day*DAY).toISOString().slice(0,10);
 const valid=x=>typeof x==='string'&&/^\d{4}-\d{2}-\d{2}$/.test(x)&&iso(dayOf(x))===x;
 const W=()=>typeof CDWorldCareer!=='undefined'?CDWorldCareer:null;
 const world=s=>!!s&&!!W()&&W().active(s)&&W().edition(s)?.mode==='world-champ';
 // Ouverture du calendrier du moteur : premier jour de la semaine 0 de la saison en cours.
 const opening=s=>W().calendarToday({...s,round:0,worldMode:{...s.worldMode,day:0}});
 function pending(s){return world(s)&&object(s.preseason)&&s.round===0&&!(s.worldMode.day>0)?s.preseason:null;}
 function create(s){
  if(!world(s)||s.season!==1||s.round!==0)return null;
  if(dayOf(FIRST_DAY)>=dayOf(opening(s)))return null;
  s.preseason={version:1,today:FIRST_DAY};
  return s.preseason;
 }
 function open(s){if(s&&s.preseason!==undefined)delete s.preseason;return true;}
 function advanceDay(s,from){
  const st=pending(s);if(!st)throw Error('Aucune avant-saison en cours.');
  if(from!==st.today)throw Error('La date de carrière a changé.');
  const next=dayOf(st.today)+1;
  if(next>=dayOf(opening(s)))open(s);else st.today=iso(next);
  return true;
 }
 function advance(s,payload){
  const st=pending(s);if(!st)throw Error('Aucune avant-saison en cours.');
  if(!object(payload)||payload.fromDate!==st.today||!['semaine','saison'].includes(payload.until))throw Error('Avance d’avant-saison invalide.');
  const goal=payload.until==='saison'?dayOf(opening(s)):dayOf(st.today)+7;
  if(goal>=dayOf(opening(s)))open(s);else st.today=iso(goal);
  return {preseasonAdvance:{today:pending(s)?.today??null}};
 }
 function execute(command,payload){
  if(command==='preseason_advance')return advance(S,payload);
  throw Error('Commande d’avant-saison inconnue.');
 }
 function project(){
  const s=typeof S==='undefined'?null:S,st=pending(s);
  return st?{active:true,today:st.today,opening:opening(s)}:{active:false};
 }
 // Projection : la date du jour de l'avant-saison remplace celle de la semaine 0.
 function decorate(s,m){
  const st=pending(s);if(!st||!m?.meta)return m;
  m.meta.calendarToday=st.today;
  // Cadence jour par jour seulement si la carrière l'utilise (Godot) ; en cadence hebdomadaire,
  // finir la semaine ouvre directement le calendrier.
  if(s.worldMode.day!==undefined)m.meta.calendarCadence={day:(new Date(st.today+'T00:00:00Z').getUTCDay()+6)%7,matchReady:false,canAdvance:true,preseason:true};
  m.meta.preseason={today:st.today,opening:opening(s)};
  return m;
 }
 function validate(s){
  const st=s?.preseason;if(st===undefined)return true;
  if(!(object(st)&&Object.keys(st).length===2&&st.version===1&&valid(st.today)&&s.season===1&&s.round===0&&!s.live&&st.today>=FIRST_DAY&&dayOf(st.today)<dayOf(opening(s))))throw Error('Avant-saison : état invalide.');
  return true;
 }
 // Toute avance du calendrier du moteur (entraînement de la semaine, fin de semaine), y compris
 // par un outil interne, ouvre d'abord le calendrier.
 let installed=false;
 function installHooks(){
  if(installed)return true;installed=true;
  for(const name of ['trainWeek','finishRound']){const original=g[name];if(typeof original!=='function')continue;
   const wrapped=function(){const s=typeof S==='undefined'?null:S;if(s&&s.preseason!==undefined)open(s);return original.apply(this,arguments);};
   Object.assign(wrapped,original);g[name]=wrapped;}
  return true;
 }
 const api=Object.freeze({FIRST_DAY,create,pending,open,advanceDay,decorate,opening});
 g.CDPreseason=api;
 return {project,validate,execute,installHooks};
}
module.exports={files,commands,factory,FIRST_DAY};

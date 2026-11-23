'use strict';

const DAY = 86400000;
const activation = [0,'speed','Activation'];
const recovery = [2,'recovery','Récupération'];
const scrum = [-4,'team','Ateliers par poste','Mêlée','Lancements'];
const lineout = [-3,'team','Ateliers par poste','Touche','Jeu de ligne'];
const programmes = {
 standard:{label:'Semaine standard', slots:[
  [-5,'strength','Force'],scrum,[-3,'video','Vidéo'],[-3,'kicking','Jeu au pied'],
  [-2,'skills','Plaquage'],[-1,'tactics','Mise en place'],activation,recovery
 ]},
 away:{label:'Long déplacement',slots:[
  [-5,'strength','Puissance'],[-4,'video','Analyse adverse'],lineout,
  [-2,'tactics','Transitions'],[-1,'skills','Passes légères'],activation,recovery
 ]},
 congested:{label:'Matchs rapprochés',slots:[
  [-2,'tactics','Mise en place légère'],[-1,'video','Vidéo'],activation,[1,'recovery','Récupération']
 ]},
 break:{label:'Reprise après la trêve',slots:[
  [-10,'recovery','Mobilité'],[-8,'strength','Reprise physique'],[-6,'speed','Vitesse'],
  scrum,[-2,'skills','Passes et appuis'],[-1,'tactics','Mise en place'],activation,recovery
 ]}
};
const kinds = new Set(['team','strength','speed','tactics','skills','recovery','video','kicking']);
// Séances au choix pour remplacer UNE séance d'un jour (idée FM27 n° 25, 23/11/2026) : chaque séance distincte des
// semaines types et des blocs d'entraînement (famille + nom), sans les groupes avants / arrières des ateliers.
const REGULAR = [[0,'strength','Force'],[2,'team','Ateliers par poste','Conquête','Circulation'],[4,'skills','Passes et appuis']];
const CATALOGUE = Object.freeze([...new Map([...Object.values(programmes).flatMap(({slots})=>slots),...REGULAR]
 .map(([,kind,label])=>[kind+'|'+label,Object.freeze({kind,label})])).values()]);
const inCatalogue = (kind,label) => CATALOGUE.some(item=>item.kind === kind && item.label === label);
const isRecord = value => value !== null && typeof value === 'object' && !Array.isArray(value);
const owns = (record,key) => Object.hasOwn(record,key);
const validFixtureId = value => typeof value === 'string' && value.length > 0 && value.length <= 160
 && !['__proto__','constructor','prototype'].includes(value);
const programmeExists = id => typeof id === 'string' && owns(programmes,id);

function isDate(value) {
 if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
 const time = Date.parse(value);
 return Number.isFinite(time) && new Date(time).toISOString().slice(0,10) === value;
}

function dayOffset(date, days) {
 return new Date(Date.parse(date)+days*DAY).toISOString().slice(0,10);
}

function dayGap(first, last) {
 return (Date.parse(last)-Date.parse(first))/DAY;
}

function seasonOf(model) {
 return Number.isSafeInteger(model?.meta?.season) && model.meta.season > 0 ? model.meta.season : 1;
}

function dateOf(model, date) {
 return [date,model?.meta?.today,model?.meta?.date].find(isDate) ?? null;
}

function fixturesOf(model) {
 const clubId = model?.club?.id;
 return (model?.calendar ?? []).filter(fixture=>isRecord(fixture)
  && isDate(fixture.date) && validFixtureId(fixture.id)
  && (clubId == null || fixture.home?.id === clubId || fixture.away?.id === clubId));
}

function activeState(model, state) {
 return state?.season === seasonOf(model) ? state.fixtures : {};
}

function anchorIndex(anchors) {
 return new Map(anchors.filter(anchor=>validFixtureId(anchor?.fixtureId) && isDate(anchor?.date))
  .map(anchor=>[anchor.fixtureId,anchor.date]));
}

function defaultProgramme(fixture, previous, model) {
 if (previous) {
  const gap = dayGap(previous.anchor,fixture.anchor);
  if (gap <= 4) return 'congested';
  if (gap >= 15) return 'break';
 }
 return fixture.away?.id === model?.club?.id && !fixture.neutral ? 'away' : 'standard';
}

function makeSession(fixtureId, date, slot, index) {
 const [,kind,label,forwards,backs] = slot;
 return {
  id:fixtureId ? `${fixtureId}:${date}:${kind}:${index}` : `club:${date}:${kind}`,
  date,kind,label,
  ...(fixtureId ? {fixtureId} : {}),
  ...(forwards ? {forwards,backs} : {})
 };
}

function freeSessions(first, last) {
 // A date gap between known matches is a training block. The week before
 // the next fixture is reserved for that fixture's own programme.
 const gap = dayGap(first,last);
 if (gap < 15) return [];
 const sessions = [];
 for (let week=4; week < gap-10 && week <= 70; week+=7) {
  for (const slot of REGULAR) {
   const offset = week+slot[0];
   if (offset < gap-10) sessions.push(makeSession(null,dayOffset(first,offset),slot,0));
  }
 }
 return sessions;
}

function preparation(model, state, today, anchors, chosen = null) {
 const stored = activeState(model,state);
 const saved = state?.season === seasonOf(model) ? state : null;
 const anchorByFixture = anchorIndex(anchors);
 const fixtures = fixturesOf(model).map(fixture=>{
  const override = owns(stored,fixture.id) ? stored[fixture.id] : null;
  return {...fixture,anchor:anchorByFixture.get(fixture.id) ?? override?.date ?? fixture.date,override};
 }).sort((a,b)=>a.anchor.localeCompare(b.anchor) || a.id.localeCompare(b.id));
 const matchDates = new Set(fixtures.map(fixture=>fixture.anchor));
 const sessionsByDate = new Map();
 function add(session) {
  if (!isDate(session.date) || (saved?.through && session.date < saved.through)) return;
  const sessions = sessionsByDate.get(session.date) ?? [];
  sessions.push(session);
  sessionsByDate.set(session.date,sessions);
 }
 for (const [index,fixture] of fixtures.entries()) {
  const previous = fixtures[index-1];
  if (previous) freeSessions(previous.anchor,fixture.anchor).forEach(add);
  const programme = fixture.override?.template ?? defaultProgramme(fixture,previous,model);
  if (chosen) chosen[fixture.id] = programme;
  programmes[programme].slots.forEach((slot,slotIndex)=>{
   const [offset] = slot;
   const date = dayOffset(fixture.anchor,offset);
   if (offset !== 0 && matchDates.has(date)) return;
   // During a short turnaround, only the recovery and the new fixture's
   // preparation survive. Work already performed is preserved separately.
   if (previous && offset < 0 && date <= previous.anchor) return;
   add(makeSession(fixture.id,date,slot,slotIndex));
  });
 }
 const displayed = [...(saved?.history ?? [])];
 for (const sessions of sessionsByDate.values()) {
  const recuperation = sessions.find(session=>session.kind === 'recovery');
  if (recuperation) displayed.push(recuperation,...sessions.filter(session=>session.kind === 'video'));
  else displayed.push(...sessions);
 }
 const swaps = saved?.swaps ?? {};
 return [...new Map(displayed.map(session=>[session.id,session])).values()]
  .map(session=>(saved?.through && session.date < saved.through) || !owns(swaps,session.id) ? session : swapped(session,swaps[session.id]))
  .sort((a,b)=>a.date.localeCompare(b.date) || (a.sourceId ?? a.id).localeCompare(b.sourceId ?? b.id))
  .map(session=>({...session,completed:today !== null && session.date < today}));
}

// Séance remplacée : même jour, même place (identifiant d'origine dans sourceId, ordre du jour inchangé), nouvelle
// famille et nouveau nom ; l'identifiant suit la famille (format de l'historique : <match>:<date>:<famille>:<rang>).
function swapped(session, {kind,label}) {
 const {forwards,backs,...rest} = session;
 const id = session.fixtureId ? session.id.replace(/:[a-z]+:(\d)$/,`:${kind}:$1`) : `club:${session.date}:${kind}`;
 return {...rest,id,kind,label,sourceId:session.id,swapped:true};
}

// Effets des séances sur la semaine (22/11/2026, Entraînement › Mois, choix de Léo) : chaque séance du programme
// jour par jour agit sur la semaine simulée du club. Effet par séance (points de fatigue, de condition, % de progression
// des avants / des arrières, % d'organisation collective), en écart à une semaine de référence (REFERENCE) : une semaine
// au niveau de la référence laisse la semaine simulée d'avant (seule charge hebdomadaire) intacte.
// La charge choisie dans l'onglet Semaine (repos / normale / intensive) garde son rôle : l'intensité de la semaine ;
// le programme en règle le contenu, sans compter deux fois le même effet.
const EFFETS = Object.freeze({
 strength:{fatigue:3,condition:-1,avants:4,arrieres:2,cohesion:0,blessure:2,moral:-1},
 speed:{fatigue:1,condition:0,avants:1,arrieres:3,cohesion:0,blessure:2,moral:0},
 team:{fatigue:2,condition:-1,avants:4,arrieres:0,cohesion:0,blessure:2,moral:0},
 skills:{fatigue:1,condition:0,avants:2,arrieres:3,cohesion:0,blessure:1,moral:1},
 kicking:{fatigue:1,condition:0,avants:0,arrieres:3,cohesion:0,blessure:0,moral:1},
 tactics:{fatigue:0,condition:0,avants:0,arrieres:0,cohesion:2,blessure:0,moral:0},
 video:{fatigue:-1,condition:1,avants:0,arrieres:0,cohesion:2,blessure:0,moral:0},
 recovery:{fatigue:-4,condition:3,avants:0,arrieres:0,cohesion:0,blessure:-2,moral:1}
});
// Risque de blessure (blessure) et effet moral (moral) par séance (idée FM27 n° 25, choix de Léo du 23/11/2026) :
// points de risque de la semaine (contact, intensité ; la récupération en retire) et points de moral du groupe
// (séances ludiques ou au ballon : +, force et vidéo : −). Appliqués à la séance collective du club du manager
// (programme-semaine.cjs) : le risque pèse sur les blessures à l'entraînement, le moral sur le moral du groupe.
const AXES = ['fatigue','condition','avants','arrieres','cohesion','blessure','moral'];
const BORNES = Object.freeze({fatigue:8,condition:5,avants:12,arrieres:12,cohesion:6,blessure:4,moral:2});
// Semaine de référence = la semaine moyenne du programme proposé par le staff sur une saison Monde (sonde du 22/11/2026,
// scripts/sonde-programme-entrainement.cjs) : sur une saison au programme par défaut, la simulation reste en moyenne
// celle d'avant. Une semaine type standard en reste à un ou deux points (avec la séance de force du lundi : +1 de
// fatigue, +2 % de progression ; sans elle, quand la récupération d'après-match tombe le lundi : -2 de fatigue, +1 de
// condition, -2 % pour les avants). Risque et moral (23/11/2026) : même méthode (scripts/sonde-seance-effets.cjs).
const REFERENCE = Object.freeze({fatigue:2,condition:2,avants:9,arrieres:9,cohesion:4,blessure:4,moral:1});

function weekStart(date) {
 const weekday = new Date(Date.parse(date)).getUTCDay();
 return dayOffset(date,-((weekday+6)%7));
}

// Semaine (lundi → dimanche) qui contient `today` : séances comptées par famille et effets bornés, écart à la semaine
// standard (zéro pour une semaine sans séance). null sans date du jour.
function weekEffects(sessions, today) {
 if (!isDate(today)) return null;
 const lundi = weekStart(today), dimanche = dayOffset(lundi,6);
 const counts = Object.fromEntries(Object.keys(EFFETS).map(kind=>[kind,0]));
 for (const session of sessions ?? []) {
  if (!isRecord(session) || !isDate(session.date) || session.date < lundi || session.date > dimanche) continue;
  if (owns(counts,session.kind)) counts[session.kind]++;
 }
 return {weekStart:lundi,counts,effects:effectsOf(counts)};
}

// Effets bornés d'une semaine comptée par famille, en écart à la semaine standard. Semaine sans aucune séance au
// programme (avant-saison, trêve sans plan) : zéro, la semaine simulée reste celle d'avant.
function effectsOf(counts) {
 const planned = Object.values(counts).some(Boolean);
 const effects = {};
 for (const axe of AXES) {
  if (!planned) { effects[axe] = 0; continue; }
  const total = Object.entries(counts).reduce((n,[kind,count])=>n+(EFFETS[kind]?.[axe] ?? 0)*count,0);
  effects[axe] = Math.max(-BORNES[axe],Math.min(BORNES[axe],total-REFERENCE[axe]));
 }
 return effects;
}

function weeksEffects(sessions) {
 const starts = new Set((sessions ?? []).filter(session=>isRecord(session) && isDate(session.date)).map(session=>weekStart(session.date)));
 return Object.fromEntries([...starts].sort().map(start=>[start,weekEffects(sessions,start).effects]));
}

function project(model, state, date, {anchors = []} = {}) {
 const today = dateOf(model,date);
 const stored = activeState(model,state);
 const appliedTemplates = Object.fromEntries(fixturesOf(model)
  .filter(fixture=>!fixture.played && owns(stored,fixture.id))
  .map(fixture=>[fixture.id,stored[fixture.id].template]));
 // Modèle de semaine en vigueur pour chaque rencontre (choisi ou proposé par le staff) : vue Mois de l'entraînement.
 const programmeByFixture = {};
 const sessions = today ? preparation(model,state,today,anchors,programmeByFixture) : [];
 return {
  today,
  sessions,
  week:weekEffects(sessions,today),
  appliedTemplates,
  programmeByFixture,
  // Effets de chaque semaine du programme (lundi → effets) et de chaque semaine type (séances J-x… J+1) : lisibles
  // dans Entraînement › Mois avant de choisir.
  weeks:weeksEffects(sessions),
  sessionEffects:EFFETS,
  sessionCatalogue:CATALOGUE,
  templates:Object.entries(programmes).map(([id,{label,slots}])=>({id,label,
   slots:slots.map(([offset,kind,name])=>({offset,kind,label:name})),
   effects:effectsOf(Object.fromEntries(Object.keys(EFFETS).map(kind=>[kind,slots.filter(slot=>slot[1]===kind).length])))}))
 };
}

function editableFixture(model, fixtureId, today) {
 const fixture = fixturesOf(model).find(item=>item.id === fixtureId);
 if (!fixture || !isDate(today) || fixture.played || fixture.date < today) {
  throw Error('La rencontre ne permet plus de modifier la préparation.');
 }
 return fixture;
}

function previousModel(model, fixtureId, date) {
 return {...model,calendar:model.calendar.map(item=>item.id === fixtureId ? {...item,date} : item)};
}

function changeState(model,state,fixtureId,entry,completed,swaps) {
 const saved = state?.season === seasonOf(model) ? state : null;
 const history = completed ?? (saved?.through ? {through:saved.through,history:saved.history} : {});
 const kept = swaps ?? saved?.swaps;
 const fixtures = fixtureId ? {...activeState(model,state),[fixtureId]:entry} : {...activeState(model,state)};
 const result = {version:1,season:seasonOf(model),fixtures,...history,...(kept && Object.keys(kept).length ? {swaps:kept} : {})};
 validateState(result);
 return result;
}

function remember(model,state,today,anchors) {
 const previous = state?.season === seasonOf(model) ? state.through : null;
 const through = previous > today ? previous : today;
 const history = project(model,state,through,{anchors}).sessions
  .filter(session=>session.completed).map(({completed,sourceId,swapped,...session})=>session);
 return {through,history};
}

function lookup(model,state,id) {
 const entries = activeState(model,state);
 return owns(entries,id) ? entries[id] : null;
}

function defaultAt(model,state,fixture) {
 const stored = activeState(model,state);
 const previous = fixturesOf(model)
  .filter(item=>item.id !== fixture.id)
  .map(item=>({anchor:owns(stored,item.id) ? stored[item.id].date : item.date}))
  .filter(item=>item.anchor < fixture.date)
  .sort((a,b)=>b.anchor.localeCompare(a.anchor))[0];
 return defaultProgramme({...fixture,anchor:fixture.date},previous,model);
}

function applyTemplate(model,state,{fixtureId,template},date,{anchors = []} = {}) {
 if (!programmeExists(template)) throw Error('Programme d’entraînement inconnu.');
 const today = dateOf(model,date);
 const fixture = editableFixture(model,fixtureId,today);
 const prior = lookup(model,state,fixtureId);
 const anchor = anchorIndex(anchors).get(fixtureId) ?? prior?.date ?? fixture.date;
 if (anchor < today) throw Error('La rencontre doit être recalée avant de choisir un nouveau programme.');
 const saved = state?.season === seasonOf(model) ? state : null;
 const swaps = Object.fromEntries(Object.entries(saved?.swaps ?? {}).filter(([id])=>!id.startsWith(fixtureId+':')));
 return changeState(model,state,fixtureId,{date:anchor,template},remember(model,state,today,anchors),swaps);
}

// Remplace UNE séance d'un jour (Entraînement › Mois, fiche de séance) : {sessionId (identifiant d'origine), kind,
// label} pris dans le catalogue. Séance du jour ou à venir seulement ; reprendre la séance d'origine annule le
// remplacement. Le choix compte dans la semaine simulée (weekEffects : fatigue, condition, progression, organisation,
// risque de blessure, moral), lue par la séance collective du club (programme-semaine.cjs).
function swapSession(model,state,{sessionId,kind,label} = {},date,{anchors = [],trained = false} = {}) {
 if (typeof sessionId !== 'string' || !inCatalogue(kind,label)) throw Error('Séance inconnue.');
 const today = dateOf(model,date);
 if (!isDate(today)) throw Error('La planification est indisponible.');
 const sessions = project(model,state,today,{anchors}).sessions;
 const target = sessions.find(session=>(session.sourceId ?? session.id) === sessionId);
 if (!target || target.completed) throw Error('Cette séance ne peut plus être changée.');
 if (trained && weekStart(target.date) === weekStart(today)) throw Error('La séance collective de la semaine est déjà faite.');
 const saved = state?.season === seasonOf(model) ? state : null;
 const live = new Set(sessions.filter(session=>!session.completed).map(session=>session.sourceId ?? session.id));
 const swaps = Object.fromEntries(Object.entries(saved?.swaps ?? {}).filter(([id])=>live.has(id) && id !== sessionId));
 const plain = saved ? (({swaps:ignored,...rest})=>rest)(saved) : state;
 const source = project(model,plain,today,{anchors}).sessions.find(session=>session.id === sessionId);
 if (!source || source.kind !== kind || source.label !== label) swaps[sessionId] = {kind,label};
 return changeState(model,state,null,null,remember(model,state,today,anchors),swaps);
}

function describeChange(model,state,change,date) {
 const {fixtureId,fromDate,toDate} = change;
 const today = dateOf(model,date);
 const fixture = editableFixture(model,fixtureId,today);
 if (!isDate(fromDate) || fixture.date !== toDate) throw Error('La date de la rencontre a changé.');
 const prior = lookup(model,state,fixtureId);
 const oldModel = previousModel(model,fixtureId,fromDate);
 return {today,fixtureId,toDate,prior,oldModel,template:prior?.template ?? defaultAt(oldModel,state,{...fixture,date:fromDate})};
}

function keepSchedule(model,state,change,date) {
 const {fixtureId,prior,template} = describeChange(model,state,change,date);
 if (prior) return state;
 return changeState(model,state,fixtureId,{date:change.fromDate,template});
}

function reschedule(model,state,change,date,{anchors = []} = {}) {
 const {today,fixtureId,toDate,prior,oldModel,template} = describeChange(model,state,change,date);
 if (prior?.date === toDate) return state;
 return changeState(model,state,fixtureId,{date:toDate,template},remember(oldModel,state,today,anchors));
}

function validateState(state) {
 if (state === undefined) return;
 const invalid = ()=>{ throw Error('Planning des entraînements invalide.'); };
 if (!isRecord(state) || state.version !== 1 || !Number.isSafeInteger(state.season) || state.season < 1
  || !isRecord(state.fixtures) || Object.keys(state.fixtures).length > 200
  || Object.keys(state).some(key=>!['version','season','fixtures','through','history','swaps'].includes(key))) invalid();
 if (state.swaps !== undefined) {
  if (!isRecord(state.swaps) || Object.keys(state.swaps).length > 400) invalid();
  for (const [id,swap] of Object.entries(state.swaps)) {
   if (!validFixtureId(id) || !isRecord(swap) || Object.keys(swap).some(key=>!['kind','label'].includes(key))
    || !inCatalogue(swap.kind,swap.label)) invalid();
  }
 }
 for (const [id,entry] of Object.entries(state.fixtures)) {
  if (!validFixtureId(id) || !isRecord(entry) || !isDate(entry.date) || !programmeExists(entry.template)
   || Object.keys(entry).some(key=>!['date','template'].includes(key))) invalid();
 }
 if (state.through === undefined && state.history === undefined) return;
 if (!isDate(state.through) || !Array.isArray(state.history) || state.history.length > 1800) invalid();
 const ids = new Set();
 for (const session of state.history) {
  if (!isRecord(session) || typeof session.id !== 'string' || ids.has(session.id)
   || !isDate(session.date) || session.date >= state.through || !kinds.has(session.kind)
   || typeof session.label !== 'string' || !session.label || session.label.length > 80
   || Object.keys(session).some(key=>!['id','fixtureId','date','kind','label','forwards','backs'].includes(key))) invalid();
  const suffix = `${session.date}:${session.kind}`;
  if (session.fixtureId === undefined) {
   if (session.id !== 'club:'+suffix) invalid();
  } else {
   if (!validFixtureId(session.fixtureId)) invalid();
   const prefix = `${session.fixtureId}:${suffix}:`;
   if (!session.id.startsWith(prefix) || !/^\d$/.test(session.id.slice(prefix.length))) invalid();
  }
  if (session.forwards !== undefined || session.backs !== undefined) {
   if (session.kind !== 'team' || ![session.forwards,session.backs].every(label=>typeof label === 'string' && label.length > 0 && label.length <= 80)) invalid();
  }
  ids.add(session.id);
 }
}

module.exports = {project,applyTemplate,swapSession,reschedule,keepSchedule,validateState,weekEffects,EFFETS,CATALOGUE};

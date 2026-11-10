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
 const regular = [[0,'strength','Force'],[2,'team','Ateliers par poste','Conquête','Circulation'],[4,'skills','Passes et appuis']];
 const sessions = [];
 for (let week=4; week < gap-10 && week <= 70; week+=7) {
  for (const slot of regular) {
   const offset = week+slot[0];
   if (offset < gap-10) sessions.push(makeSession(null,dayOffset(first,offset),slot,0));
  }
 }
 return sessions;
}

function preparation(model, state, today, anchors) {
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
 return [...new Map(displayed.map(session=>[session.id,session])).values()]
  .sort((a,b)=>a.date.localeCompare(b.date) || a.id.localeCompare(b.id))
  .map(session=>({...session,completed:today !== null && session.date < today}));
}

function project(model, state, date, {anchors = []} = {}) {
 const today = dateOf(model,date);
 const stored = activeState(model,state);
 const appliedTemplates = Object.fromEntries(fixturesOf(model)
  .filter(fixture=>!fixture.played && owns(stored,fixture.id))
  .map(fixture=>[fixture.id,stored[fixture.id].template]));
 return {
  today,
  sessions:today ? preparation(model,state,today,anchors) : [],
  appliedTemplates,
  templates:Object.entries(programmes).map(([id,{label}])=>({id,label}))
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

function changeState(model,state,fixtureId,entry,completed) {
 const saved = state?.season === seasonOf(model) ? state : null;
 const history = completed ?? (saved?.through ? {through:saved.through,history:saved.history} : {});
 const result = {version:1,season:seasonOf(model),fixtures:{...activeState(model,state),[fixtureId]:entry},...history};
 validateState(result);
 return result;
}

function remember(model,state,today,anchors) {
 const previous = state?.season === seasonOf(model) ? state.through : null;
 const through = previous > today ? previous : today;
 const history = project(model,state,through,{anchors}).sessions
  .filter(session=>session.completed).map(({completed,...session})=>session);
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
 return changeState(model,state,fixtureId,{date:anchor,template},remember(model,state,today,anchors));
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
  || Object.keys(state).some(key=>!['version','season','fixtures','through','history'].includes(key))) invalid();
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

module.exports = {project,applyTemplate,reschedule,keepSchedule,validateState};

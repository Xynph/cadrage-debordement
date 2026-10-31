'use strict';
const assert=require('node:assert/strict');
const {context}=require('./harness.cjs');
const ui=require('../dist/ui03-scout-data.js');

const g=context();g.run('start(0)');
const source=JSON.parse(g.run('JSON.stringify({pool:managerPool(),reports:S.manager.reports,missions:S.manager.missions,watch:S.manager.watch,needs:recruitmentNeeds(),season:S.season,week:S.economy.week})'));
const deps={evidence:g.run('recruitmentEvidence')};
assert.ok(source.pool.length>0,'Native managerPool contains candidates');
assert.equal(source.needs.length,15);
const saved=g.run('JSON.stringify(S)'),storage=g.store['bdt-v1'];
const original=JSON.stringify(source);
const center=ui.buildCenter(source,deps);
assert.equal(center.version,1);
assert.equal(center.candidates.length,source.pool.length);
assert.equal(center.needs.length,15);
assert.ok(center.needs.every(x=>x.score>=0&&x.score<=100));
assert.equal(center.totals.reports,0);
assert.ok(center.candidates.every(x=>!x.observed&&x.potentialMin===null&&x.potentialMax===null&&x.grade===null));
const initial=center.candidates[0];
const native=g.run('recruitmentEvidence(managerPool()[0])');
assert.equal(initial.noteMin,native.noteMin);
assert.equal(initial.noteMax,native.noteMax);
assert.equal(initial.evidenceLabel,native.label);
assert.ok(!Object.hasOwn(initial,'rating'));
assert.ok(!Object.hasOwn(initial,'skills'));
assert.ok(!Object.hasOwn(initial,'dev'));
assert.ok(!Object.hasOwn(initial,'potential'));
assert.ok(!JSON.stringify(center).includes('"skillBase"'));
assert.equal(JSON.stringify(source),original);
assert.equal(g.run('JSON.stringify(S)'),saved,'projection mutated career');
assert.equal(g.store['bdt-v1'],storage,'projection wrote native save');

const tampered=JSON.parse(JSON.stringify(source));
tampered.pool[0].rating=99;tampered.pool[0].skills={speed:99,tackle:99};
tampered.pool[0].dev={potential:99,retireAge:99};
const beforeModel=ui.buildCenter(tampered,deps);
assert.deepEqual(beforeModel.candidates[0],center.candidates[0],
  'unobserved hidden attributes changed a public estimate');
const raw=ui.publicPlayer(tampered.pool[0]);
assert.deepEqual(Object.keys(raw),['id','name','position','family','age','salary','price']);
assert.ok(!Object.hasOwn(raw,'rating'));
assert.deepEqual(ui.candidateTable(center,{search:initial.name.toUpperCase()}).rows.map(x=>x.id),
  center.candidates.filter(x=>x.name.toLowerCase()===initial.name.toLowerCase()).map(x=>x.id));
assert.ok(ui.candidateTable(center,{family:initial.family}).rows.every(x=>x.family===initial.family));
assert.ok(ui.candidateTable(center,{maxSalary:0}).rows.every(x=>x.salary<=0));
assert.ok(ui.candidateTable(center,{maxFee:0}).rows.every(x=>x.price<=0));
for(const sort of ui.SORTS){
 const rows=ui.candidateTable(center,{sortBy:sort,direction:'asc'}).rows;
 assert.equal(rows.length,center.candidates.length);
}
assert.throws(()=>ui.candidateTable(center,{sortBy:'secretRating'}),/Tri invalide/);
assert.throws(()=>ui.candidateTable(center,{family:99}),/Poste invalide/);
assert.throws(()=>ui.candidateTable(center,{maxFee:-5}),/financier invalide/);

// Actual native mission generates native reports after two manager weeks.
const s=context();s.run('start(0)');
s.run('var target=S.market[0];S.market=[target];S.economy.freeAgents=[]');
assert.equal(s.run('createScoutMission(target.fam,40,10000000,100000)'),true);
assert.equal(s.run('S.manager.missions[0].remaining'),2);
let before=s.run('JSON.stringify(S)');
let pub=JSON.parse(s.run('JSON.stringify({pool:managerPool(),reports:S.manager.reports,missions:S.manager.missions,watch:S.manager.watch,needs:recruitmentNeeds(),season:S.season,week:S.economy.week})'));
let projected=ui.buildCenter(pub,{evidence:s.run('recruitmentEvidence')});
assert.equal(projected.totals.active,1);
assert.equal(projected.missions[0].remaining,2);
assert.equal(projected.reports.length,0);
assert.equal(s.run('JSON.stringify(S)'),before);
s.run('S.economy.week++;managerWeek();S.economy.week++;managerWeek()');
assert.ok(s.run('S.manager.reports.length')>0);
assert.equal(s.run('S.manager.missions[0].status'),'done');
s.run('watchPlayer(target.id)');
before=s.run('JSON.stringify(S)');
pub=JSON.parse(s.run('JSON.stringify({pool:managerPool(),reports:S.manager.reports,missions:S.manager.missions,watch:S.manager.watch,needs:recruitmentNeeds(),season:S.season,week:S.economy.week})'));
projected=ui.buildCenter(pub,{evidence:s.run('recruitmentEvidence')});
const row=projected.candidates.find(x=>x.id===pub.pool[0].id);
assert.ok(row.observed&&row.watched);
assert.equal(row.stale,false);
assert.ok(row.potentialMin!==null&&row.potentialMax!==null);
assert.ok(projected.reports.some(r=>r.playerId===row.id&&r.grade!==null&&r.available));
assert.equal(projected.totals.watch,1);
assert.equal(ui.candidateTable(projected,{observedOnly:true,watchedOnly:true}).total,1);
assert.equal(s.run('JSON.stringify(S)'),before,'report projection mutated career');
assert.ok(s.run('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'));
s.run('S.economy.week+=20');
pub.week=s.run('S.economy.week');
const outdated=ui.buildCenter(pub,{evidence:s.run('recruitmentEvidence')});
assert.equal(outdated.candidates[0].stale,true,'native stale evidence must pass through');
assert.ok(outdated.candidates[0].noteMax>row.noteMax);
const absent=JSON.parse(JSON.stringify(pub));absent.pool=[];
const missing=ui.buildCenter(absent,{evidence:s.run('recruitmentEvidence')});
assert.equal(missing.reports[0].available,false,'historical report must survive removed player');
assert.equal(missing.watch[0].available,false,'followed player missing from market stays identified');
assert.equal(missing.watch[0].noteMin,null,'no invented up-to-date estimate');
console.log(JSON.stringify({passed:true,checks:[
 'native manager pool and 15 needs','public scouting range','hidden values never exported',
 'no career or save mutation','stable native filters and sorting','mission real two-week queue',
 'native report discovery','watched and observed cohorts','obsolete report precision',
 'missing player preserved historically','native save roundtrip']}));
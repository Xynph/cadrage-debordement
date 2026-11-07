'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs');
const adapter='../tools/rugby-real-v16/audit.cjs';
test('V16 adapter exists: a verified hooker cannot remain eligible as a loosehead on a shadow copy',()=>{
 assert.ok(fs.existsSync(require('node:path').resolve(__dirname,adapter)),'missing shadow audit adapter');
 const V=require(adapter),g=V.boot(105),before=V.read(g,'S'),control=V.clone(before);
 const mismatch=V.mismatches(g);assert.equal(mismatch.length,16);
 V.applyPositions(control);const massa=control.clubs.flatMap(c=>c.players).find(p=>p.id==='lnr:862');
 assert.equal(massa.pos,'Talonneur');assert.equal(massa.fam,1);
 assert.equal(JSON.stringify(V.read(g,'S')),JSON.stringify(before),'original career unchanged');
});
const V=require(adapter),path=require('node:path');
const save=(name,value)=>{if(process.env.V16_RESULTS_DIR){fs.mkdirSync(process.env.V16_RESULTS_DIR,{recursive:true});fs.writeFileSync(path.join(process.env.V16_RESULTS_DIR,name+'.json'),JSON.stringify(value));}};
test('V16 source corroboration distinguishes LNR group, official roles and uncertain precise sides',()=>{
 const g=V.boot(),before=V.frame(g),rows=V.roleRows(g);
 assert.equal(rows.length,16);assert.equal(rows.filter(r=>r.club==='clermont').length,9);assert.equal(rows.filter(r=>r.club==='bayonne').length,7);
 assert.equal(V.spec.positions.filter(p=>p.applyShadow).length,13);
 assert.equal(rows.find(r=>r.id==='lnr:184').nativeNote,55);assert.equal(rows.find(r=>r.id==='lnr:184').shadowNote,69);
 assert.equal(V.spec.positions.find(r=>r.id==='lnr:657').evidenceRole,'Talonneur');
 assert.equal(V.spec.positions.find(r=>r.id==='lnr:655').evidenceRole,'Pilier gauche');
 assert.equal(JSON.stringify(V.frame(g)),JSON.stringify(before),'diagnostic must be read-only');
 V.compact('ROLES',{frontRowCount:207,discordances:rows});save('positions',rows);
});
test('V16 36-to-11 corrections preserve strict control and include downward sensitivity',()=>{
 const source=V.signature(),g=V.boot(),s=V.applyPositions(V.frame(g)),original=V.clone(s);V.put(g,s);
 const dossiers=V.dossier(g);assert.equal(dossiers.length,9);
 for(const d of dossiers){const p=s.clubs.flatMap(c=>c.players).find(p=>p.id===d.id);assert.deepEqual(V.clone(p),p);
  for(const dose of [-1,1,2]){const next=V.candidate(p,dose);assert.equal(next.attributes.length,36);assert.equal(next.skills.length,11);assert.ok(next.attributes.every(x=>x.to>=20&&x.to<=97));assert.deepEqual(next.player.skills,require('../tools/rugby-real-v12/review.cjs').project(next.player));assert.equal(next.player.rating,p.rating);assert.equal(next.player.potential,p.potential);}
  V.compact('DOSSIER',{id:d.id,name:d.name,decision:d.decision,role:d.role,note:d.note,tier:d.tier,age:d.age,peers:d.peers,history:d.history,candidates:d.candidates.map(c=>({dose:c.dose,note:c.note,attributes:c.attributes.filter(a=>a.delta),skills:c.skills.filter(a=>a.delta)}))});
 }
 assert.deepEqual(s,original);assert.equal(V.signature(),source);save('dossiers',dossiers);
});
test('V16 verified position scenarios alter actual native eligibility, sheets and substitutions',{timeout:170000},()=>{
 const before=V.signature(),r=V.runPositions();assert.equal(r.players.length,16);assert.equal(r.results.length,4);
 assert.ok(r.results.some(row=>JSON.stringify(row.changes[0].lineup)!==JSON.stringify(row.changes[1].lineup)),'correcting positions must exercise selection');
 assert.ok(r.results.some(row=>JSON.stringify(row.actualFixture.control)!==JSON.stringify(row.actualFixture.position)),'actual match starters must change');assert.equal(V.signature(),before);save('position-matches',r);
});
test('V16 read-only match instrumentation captures actual managers while preserving state and random stream',()=>{
 const a=V.boot(204),b=V.boot(204);V.instrument(b);V.setSeed(a,919);V.setSeed(b,919);a.run('trainWeek();finishRound()');b.run('trainWeek();finishRound()');
 assert.deepEqual(V.frame(a),V.frame(b),'sidecar must not change a native round');assert.equal(a.run('Math.random()'),b.run('Math.random()'));
 const actual=V.read(b,'__v16Observed');assert.equal(actual.length,7);assert.ok(actual.every(l=>l.sheets.every(s=>s.initial.length===15&&s.nominated.length===23)));assert.ok(actual.some(l=>l.sheets.some(s=>Object.values(s.minutes).some(m=>m>0))));
});
test('V16 hierarchy keeps all30 catalogue clubs and separates14 native clubs from laboratoryPRO D2',()=>{
 const report=V.clubHierarchy();assert.equal(report.nativeTOP14.length,14);assert.equal(report.catalogue30.length,30);assert.equal(report.catalogue30.reduce((n,c)=>n+c.players,0),1592);assert.equal(report.catalogue30.filter(c=>c.league==='prod2').length,16);V.compact('CLUBS',report);save('clubs',report);
});
test('V16 long-career protocol must include native preparation to heal injuries and recover fatigue',()=>{
 const g=V.boot();g.run('S.clubs[1].players[0].injury=2;S.clubs[1].players[0].condition=40;ensurePhysicalLoad(S.clubs[1].players[0]).fatigue=80');
 g.run('finishRound()');assert.equal(g.run('S.clubs[1].players[0].injury'),2,'finishRound alone never heals');
 g.run('trainWeek()');assert.equal(g.run('S.clubs[1].players[0].injury'),1);assert.ok(g.run('S.clubs[1].players[0].condition')>40);assert.ok(g.run('physicalLoadValue(S.clubs[1].players[0])')<80);
});
test('V16 native sensitivity sentinel proves full projected copy perturbations reach match outcomes',()=>{
 const g=V.boot(),control=V.frame(g),changed=V.clone(control),C=require('../tools/rugby-real-v12/review.cjs');
 for(const p of changed.clubs[0].players){for(const key of Object.keys(p.attributesV2))p.attributesV2[key]=Math.min(97,p.attributesV2[key]+10);p.skills=C.project(p);}
 const margins=[];for(let k=0;k<12;k++){const a=V.match(g,control,0,4,5721+k),b=V.match(g,changed,0,4,5721+k);margins.push(b.margin-a.margin);}
 assert.ok(margins.some(n=>n!==0),'native scores must respond to a large sentinel, which is never a recommended candidate');V.compact('SENTINEL',{diagnosticOnly:true,recommended:false,nativeMatches:24,...V.ci(margins)});
});

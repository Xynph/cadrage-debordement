'use strict';
const {refuseSavePublication}=require('./helpers/save-publication-refusal.cjs');
// Controlled incidents use the actual native rules; the worker receives valid saves.
const assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {test}=require('node:test'),{spawnSync}=require('node:child_process');
const {context}=require('./france-harness.cjs'),{createBridge}=require('../native/engine/worker.cjs');
const projection=require('../native/engine/model.cjs');
const root=fs.mkdtempSync(path.join(os.tmpdir(),'cd-godot-final-fixes-'));
let serial=0;
function harness(club=29){const h=context();h.run(`const nativeModel=${projection.toString()};
 // Historical v1 fixture: preserve its real RNG/calendar baseline, not new v2 pools.
 const fixtureBaseAiSetup=aiRosterSetup;
 aiRosterSetup=function(){const result=fixtureBaseAiSetup();if(S?.aiRoster){S.aiRosterVersion=1;S.aiRoster.version=1;delete S.aiRoster.population;}return result;};
 start(${club},'france');`);assert.equal(h.run('S.aiRosterVersion'),1);assert.equal(h.run('S.aiRoster.population'),undefined);return h;}

function capture(h){h.run('if(S.live)syncMatchPresentation(S.live);validateCareer(S)');return {model:JSON.parse(h.run('JSON.stringify(nativeModel())')),text:h.run('JSON.stringify(createSaveDocument())')};}
function advance(h,n){h.run(`S.live.paused=false;for(let i=0;i<${n};i++)advanceRugby(S.live);pauseMatch();`);}
function incident(slots){const h=harness();h.run('beginMatch()');for(const slot of slots)assert.equal(h.run(`giveMatchCard(S.live,S.live.userSide,S.live.sheets[S.live.userSide].on[${slot}],'red20')`),true);return h;}
const one=incident([8]);advance(one,19);const before20=capture(one);advance(one,2);const after20=capture(one);
const two=incident([5,6]);advance(two,21);const twoVacancies=capture(two);
const clock=harness();clock.run('beginMatch();while(!S.live.paused&&!S.live.finished)advanceRugby(S.live)');const halftime=capture(clock);
clock.run('continueMatch();for(let i=0;i<25;i++)advanceRugby(S.live)');const resumed=capture(clock);
clock.run('pauseMatch()');const tactical=capture(clock);
// Real simulated season and real tied knockout. No score/result is fabricated.
const season=harness(0);season.run('for(let w=0;w<30;w++){autoLineup();finishRound();}if(!nextMatch())finishRound();autoLineup();');
const knockout=season.state();season.run('beginMatch();var initialMatch=JSON.stringify(S);var tied=false;for(let attempt=0;attempt<40&&!tied;attempt++){S=JSON.parse(initialMatch);for(let steps=0;steps<120&&!S.live.finished;steps++){if(S.live.paused)continueMatch();advanceRugby(S.live);if(S.live.knockout){tied=true;break;}}}');
assert.equal(season.run('tied'),true,'seeded native knockout reaches a real extra time');
const extraStart=capture(season);season.run('pauseMatch()');const extraPause=capture(season);season.run('continueMatch();while(!S.live.finished&&S.live.knockout.period===1)advanceRugby(S.live)');const extraSecond=capture(season);
season.run('while(!S.live.finished){if(S.live.paused)continueMatch();advanceRugby(S.live)}');const finished=capture(season);
// Venue view cases use actual fixtures and native club summaries from this season.
// They are presentation inputs only, never imported as an altered career.
season.ctx.originalSeason=knockout;season.run('S=originalSeason');
const offices=[];
function office(leagueId,phase){const fixture=JSON.parse(season.run(`JSON.stringify(CDFranceCompetition.currentFixtures(S).find(f=>f.leagueId==='${leagueId}'&&f.phase==='${phase}'))`));const m=capture(season).model,clubs=m.leagues.flatMap(l=>l.rows);m.next={...fixture,home:clubs.find(c=>c.id===fixture.pair[0]),away:clubs.find(c=>c.id===fixture.pair[1]),label:m.meta.roundLabel};offices.push(m);}
season.run('finishRound()');office('elite','semi');office('accession','semi');season.run('finishRound()');office('accession','final');season.run('finishRound()');office('access','access');
const fixtures={before20,after20,twoVacancies,halftime,resumed,tactical,extraStart,extraPause,extraSecond,finished,offices};
const fixtureFile=path.join(root,'fixtures.json');fs.writeFileSync(fixtureFile,JSON.stringify(fixtures));
console.log('Native fixture receipts: '+JSON.stringify({root,halftime:halftime.model.live.minute,resumed:resumed.model.live.minute,extraStart:extraStart.model.live.minute,extraSecond:extraSecond.model.live.minute}));
function worker(name,fn){const b=createBridge({dataDir:path.join(root,name),seed:827381,now:1700000000000});const call=(command,payload={})=>b.handle({id:++serial,command,payload});const good=(command,payload)=>{const r=call(command,payload);assert.equal(r.ok,true,r.error);return r.model;};try{return fn({b,call,good});}finally{b.close();}}
function unchangedRefusal(api,payload){const before=api.good('export').meta.exportText,file=path.join(api.good('snapshot').meta.dataDir,'donnees.json'),bytes=fs.readFileSync(file);const r=api.call('substitute',payload);assert.equal(r.ok,false,'must refuse '+JSON.stringify(payload));assert.ok(r.error);assert.equal(api.good('export').meta.exportText,before);assert.deepEqual(fs.readFileSync(file),bytes);assert.equal(api.good('snapshot').meta.saveError,false);}

test('Clearing two compatible selection slots removes both players and preserves all other assignments/export',()=>worker('clear',({good})=>{
 const first=good('new_career',{club:29,mode:'france'}),original=[...first.lineup,...first.reserves];
 good('set_lineup',{slot:16,playerId:null});const m=good('set_lineup',{slot:0,playerId:null}),expected=original.slice();expected[16]=null;expected[0]=null;
 assert.deepEqual([...m.lineup,...m.reserves],expected);assert.equal(m.squad.find(p=>p.id===original[0]).status,'Hors groupe');
 const state=JSON.parse(good('export').meta.exportText).state;assert.deepEqual([...state.lineup,...state.reserves],expected);
}));
test('A real eligible player still swaps into the previous compatible slot',()=>worker('swap',({good})=>{
 const m=good('new_career',{club:29,mode:'france'}),a=m.lineup[0],b=m.reserves[1];const result=good('set_lineup',{slot:0,playerId:b});assert.equal(result.lineup[0],b);assert.equal(result.reserves[1],a);
}));
test('Every substitution option carries its exact slot and native position, including vacancies',()=>{
 assert.deepEqual(after20.model.live.substitutions.map(s=>s.slot),Array.from({length:15},(_,i)=>i));
 assert.equal(after20.model.live.substitutions[8].label,'Demi de mêlée');assert.equal(after20.model.live.lineup[8],null);assert.ok(after20.model.live.substitutions[8].inIds.length);
});
test('Vacant changes revalidate delay, slot bounds, identity, running/finished states and roll back refusals',()=>worker('refusals',api=>{
 const incoming=after20.model.live.substitutions[8].inIds[0];api.good('import',{text:before20.text});assert.equal(api.good('snapshot').live.substitutions[8].inIds.length,0);unchangedRefusal(api,{slot:8,outId:null,inId:incoming});
 api.good('import',{text:after20.text});
 for(const payload of [{outId:null,inId:incoming},{inId:incoming},...[-1,15,1.5,'8',null].map(slot=>({slot,inId:incoming})),{slot:8,outId:'stale',inId:incoming},{slot:8,inId:'absent'}])unchangedRefusal(api,payload);
 api.good('pause',{paused:false});unchangedRefusal(api,{slot:8,inId:incoming});api.good('import',{text:finished.text});unchangedRefusal(api,{slot:8,inId:incoming});
}));
test('Post-red20 change targets the chosen vacancy; old non-null outId payload remains usable',()=>worker('changes',api=>{
 let m=api.good('import',{text:after20.text});const incoming=m.live.substitutions[8].inIds[0];m=api.good('substitute',{slot:8,outId:null,inId:incoming});assert.equal(m.live.lineup[8].id,incoming);
 unchangedRefusal(api,{slot:8,outId:null,inId:incoming}); // Vacancy became occupied since the displayed decision.
 m=api.good('import',{text:twoVacancies.text});const replacement=m.live.substitutions[6].inIds[0];assert.ok(replacement);assert.ok(m.live.substitutions[5].inIds.includes(replacement));
 m=api.good('substitute',{slot:6,inId:replacement});assert.equal(m.live.lineup[5],null);assert.equal(m.live.lineup[6].id,replacement);
 const other=m.live.substitutions.find(s=>s.outId&&s.inIds.length);assert.ok(other);m=api.good('substitute',{outId:other.outId,inId:other.inIds[0]});assert.equal(m.live.lineup[other.slot].id,other.inIds[0]);
 const exported=api.good('export').meta.exportText;assert.equal(api.good('import',{text:exported}).live.lineup[6].id,replacement);
}));
test('Disk refusal of a legal vacant change restores the match before retry',()=>worker('disk',api=>{
 const m=api.good('import',{text:after20.text}),before=api.good('export').meta.exportText,file=path.join(m.meta.dataDir,'donnees.json'),bytes=fs.readFileSync(file);
 const p={slot:8,inId:m.live.substitutions[8].inIds[0]},r=refuseSavePublication(file,()=>api.call('substitute',p));assert.equal(r.ok,false);assert.match(r.error,/sauvegarde/);assert.equal(api.good('export').meta.exportText,before);assert.deepEqual(fs.readFileSync(file),bytes);assert.equal(api.good('substitute',p).live.lineup[8].id,p.inId);
}));
test('Projection distinguishes real halftime from historical marker, tactical pause and real extra-time transitions',()=>{
 assert.equal(halftime.model.live.minute,42);assert.equal(resumed.model.live.minute,67);
 for(const [name,fixture,atBreak] of [['halftime',halftime,true],['resumed',resumed,false],['tactical',tactical,false],['extra start',extraStart,false],['extra pause',extraPause,false],['extra second',extraSecond,false]]){
  assert.equal(fixture.model.live.halftime,true,name+' preserves historical marker');assert.equal(fixture.model.live.atBreak,atBreak,name+' actual break');
  assert.equal(JSON.parse(fixture.text).state.live.halftime,true);assert.equal(Object.hasOwn(JSON.parse(fixture.text).state.live,'atBreak'),false,'projection is not written into saves');
 }
 assert.ok(extraStart.model.live.events.some(e=>e.type==='break'&&e.text.includes('Prolongation')));assert.ok(extraSecond.model.live.events.some(e=>e.type==='break'&&e.text.includes('Changement de camp')));
});
test('Actual Godot bench, clock and venue views consume native fixture projections',{skip:!process.env.CD_GODOT_EXECUTABLE&&'Set CD_GODOT_EXECUTABLE to exercise Godot'},()=>{
 const result=spawnSync(process.env.CD_GODOT_EXECUTABLE,[...(process.env.CD_GODOT_FINAL_RENDER==='1'?[]:['--headless']),'--max-fps','120','--path','native/godot','--script',path.resolve(__dirname,'godot-career-final-fixes.gd')],{cwd:path.resolve(__dirname,'..'),env:{...process.env,CD_NODE_EXECUTABLE:process.execPath,CD_GODOT_SELF_TEST:'0',CD_GODOT_DATA_DIR:path.join(root,'ui'),CD_GODOT_FIXTURES:fixtureFile},windowsHide:true,encoding:'utf8',timeout:60000});
 const output=(result.stdout||'')+(result.stderr||'');console.log(output.trim());fs.writeFileSync(path.join(root,'godot.log'),output);assert.equal(result.status,0,result.error?.message||output);assert.doesNotMatch(output,/SCRIPT ERROR|Parse Error|ERROR:/);
});

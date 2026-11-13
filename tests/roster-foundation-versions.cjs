'use strict';
const {settleClubMeetings}=require('./helpers/club-meetings.cjs');
const { assertLegacyProfessionals } = require('./helpers/assert-legacy-professionals.cjs');
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),zlib=require('node:zlib'),crypto=require('node:crypto');
const data=require('../dist/rugby-roster-foundation.js'),{createBridge}=require('../native/engine/worker.cjs');
assert.equal(data.version,2,'new careers use registry v2');
const v1=data.resolve({id:data.marker.id,version:1});assert.equal(v1.version,1);assert.equal(data.resolve(data.marker),data);assert.equal(data.resolve({...data.marker,extra:1}),null);assert.equal(data.resolve({...data.marker,version:99}),null);assert.equal(data.resolve({id:'unknown',version:1}),null);
const fixture=fs.readFileSync(path.join(__dirname,'fixtures/roster-foundation-v1-s2.json.gz')),text=zlib.gunzipSync(fixture).toString(),original=JSON.parse(text);
assert.equal(crypto.createHash('sha256').update(fixture).digest('hex'),'92374c5b242f003649feecf029f4d9d4863fc98a22b83016583ba996510f3e99','unchanged real delivered export');
assert.equal(original.state.season,2);assert.equal(original.state.rosterFoundation.version,1);
// Compare actual v1 continuation under its archived catalogue and the v2 bundle.
const harness=require('./france-harness.cjs'),contexts=[true,false].map(archived=>harness.context(827381,{source:file=>{
 const source=fs.readFileSync(path.join(__dirname,'../dist',file),'utf8');
 if(!archived||file!=='rugby-roster-foundation.js')return source;
 return fs.readFileSync(path.join(__dirname,'../data/roster-foundation/archive/v1/runtime.js'),'utf8')+";Object.defineProperty(CDRosterFoundation,'resolve',{value:m=>m&&Object.keys(m).length===2&&m.id===CDRosterFoundation.marker.id&&m.version===1?CDRosterFoundation:null});";
}}));
for(const h of contexts){h.ctx.fixtureText=text;h.run('pendingSave=parseSaveDocument(fixtureText);if(!confirmSaveImport())throw Error("import");S.training="normal";trainWeek();validateCareer(S)');}
assert.deepEqual(contexts[0].state(),contexts[1].state(),'v1 continuation matches archived catalogue exactly');assert.equal(contexts[0].seed(),contexts[1].seed(),'v1 RNG continuation unchanged');
const root=fs.mkdtempSync(path.join(process.env.CD_ROSTER_TEST_ROOT||require('node:os').tmpdir(),'cd-roster-version-'));
let bridge=createBridge({dataDir:root,seed:827381,now:1700000000000}),n=0;
const call=(command,payload={})=>bridge.handle({id:++n,command,payload});
const good=(command,payload={})=>{const r=call(command,payload);assert.equal(r.ok,true,command+': '+r.error);return r.model;};
const state=()=>JSON.parse(good('export').meta.exportText).state;
try{
 good('import',{text});assertLegacyProfessionals(state(),original.state);
 assert.deepEqual(good('snapshot').meta.rosterSources,v1.sources,'model resolves saved v1 sources');
 const disk=path.join(root,'PrototypeGodot','donnees.json'),before=fs.readFileSync(disk),exported=good('export').meta.exportText;
 const reject=mutate=>{const d=JSON.parse(exported);mutate(d.state);const refused=call('import',{text:JSON.stringify(d)});assert.equal(refused.ok,false);assert.doesNotMatch(refused.error,/modifié ou endommagé/,'v1 metadata checked before checksum');assert.equal(good('export').meta.exportText,exported);assert.deepEqual(fs.readFileSync(disk),before,'invalid import does not write');};
 reject(s=>s.rosterFoundation.version=2);reject(s=>s.rosterFoundation.version=99);reject(s=>s.rosterFoundation.extra=true);reject(s=>s.clubs[0].players[0].rosterProfile=data.players[s.clubs[0].players[0].id]);reject(s=>s.clubs[0].players[0].rosterProfile.position.qualifications.push('Talonneur'));reject(s=>s.clubs[0].players[0].rosterProfile.contract.optionEndYear=2035);reject(s=>s.clubs[0].players[0].pos='Talonneur');
 settleClubMeetings(good('train',{mode:'normal'}),(command,payload)=>good(command,payload));const continued=state();assert.equal(continued.rosterFoundation.version,1);for(const c of continued.clubs)for(const p of c.players)if(p.rosterProfile)assert.deepEqual(p.rosterProfile,v1.players[p.id]);
 const continuation=good('export').meta.exportText;good('import',{text:continuation});assert.equal(good('export').meta.exportText,continuation);
 const persisted=fs.readFileSync(disk);bridge.close();bridge=createBridge({dataDir:root,seed:1,now:1700000000000});assert.deepEqual(state(),continued,'v1 reload after restart preserves state');assert.deepEqual(fs.readFileSync(disk),persisted,'reload does not rewrite save');
 settleClubMeetings(good('new_career',{mode:'world-champ',club:6}),(command,payload)=>good(command,payload));assert.equal(state().rosterFoundation.version,2);assert.deepEqual(good('snapshot').meta.rosterSources,data.sources);
 const current=good('export').meta.exportText;good('import',{text:current});assert.equal(good('export').meta.exportText,current);
 console.log(JSON.stringify({passed:true,fixtureSha256:crypto.createHash('sha256').update(fixture).digest('hex'),fixtureBytes:Buffer.byteLength(text),checks:['real v1 S2 import','v1 provenance','rejection without disk/state writes','continuation','export/import','restart','new v2']}));
}finally{bridge.close();fs.rmSync(root,{recursive:true,force:true});}

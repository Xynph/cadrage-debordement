'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const {auditEdition,auditAll,loadProductionInputs}=require('../ci/staff-contract-quality-audit.cjs');
function fixture(){return {edition:{id:'fixture-v5',version:5,mode:'world-champ',playable:[0,1],registry:{id:'fixture-v5',clubs:[{id:0,leagueId:'champ',players:[{id:'world:player:a',contractEnd:1}]},{id:1,leagueId:'champ',players:[{id:'world:player:b',contractEnd:2}]}],worldProfiles:{'world:player:a':{contract:{basis:'estimated',endSeason:1,endYear:2027}},'world:player:b':{contract:{basis:'official',sourceRef:'opaque-ref',endSeason:2,endYear:2028}}}}},staffRegistry:{clubs:[{id:0,members:[{id:'staff:a',clubId:0,role:'Rôle libre documenté',historical:false,sourceDate:'2026-08-31T15:24:48+00:00',observedAt:'2026-11-09'}]},{id:1,members:[{id:'staff:b',clubId:1,role:'Head Coach',historical:true,sourceSeason:'2025/26',sourceDate:null,observedAt:'2026-11-09'}]}]},opening:{schema:'world-initial-contracts-v1',databaseId:'fixture-v5',asOf:'2026-11-08',players:{'world:player:b':{clubId:1,endSeason:1,endType:'minimum-season-end'}},inactiveAliases:{}}};}
const codes=r=>r.errors.map(e=>e.code),warning=(r,code)=>r.warnings.find(w=>w.code===code);
function freeze(x){if(x&&typeof x==='object'){Object.values(x).forEach(freeze);Object.freeze(x);}return x;}
test('known estimates, historical staff and missing sources remain warnings, not fabricated errors',()=>{
 const f=fixture();f.staffRegistry.clubs[0].members[0].sourceDate=null;
 const r=auditEdition(f);assert.equal(r.valid,true);assert.equal(r.counts.contractEstimated,1);assert.equal(warning(r,'staff-source-unknown').count,1);assert.equal(warning(r,'staff-historical').count,1);assert.equal(r.counts.openingChanges,0,'minimum must not lower an existing two-season term');
 f.edition.registry.worldProfiles['world:player:a'].contract={};const unknown=auditEdition(f);assert.equal(unknown.counts.contractUnknown,1);assert.ok(codes(unknown).includes('invalid-contract-season'),'a malformed numeric term is distinct from missing provenance');
 delete f.edition.registry.worldProfiles['world:player:a'].contract;assert.equal(auditEdition(f).valid,true,'absence is acknowledged, not invented');
});
test('contradictory membership, dangling records, malformed roles and duplicate identities are certain failures',()=>{
 const f=fixture();f.staffRegistry.clubs[1].members[0].id='staff:a';f.staffRegistry.clubs[0].members[0].clubId=1;f.staffRegistry.clubs[0].members[0].role='';f.edition.registry.clubs[1].players.push({id:'world:player:a'});f.edition.registry.worldProfiles['world:missing']={};f.staffRegistry.clubs.push({id:99,members:[]});
 const r=auditEdition(f);for(const code of ['duplicate-staff-id','staff-club-mismatch','invalid-staff-role','duplicate-player-id','dangling-world-profile','dangling-staff-club'])assert.ok(codes(r).includes(code),code);
});
test('opening aliases remain inactive including transfers, and chains or reintroduced alias terms fail',()=>{
 const f=fixture();f.opening.inactiveAliases={'world:player:a':{clubId:0,canonicalId:'world:player:b'}};
 const r=auditEdition(f);assert.equal(r.valid,true);assert.equal(r.counts.prospectiveActivePlayers,1);assert.equal(r.counts.aliasCrossClub,1);
 f.opening.players['world:player:a']={clubId:0,endSeason:1,endType:'season-end'};assert.ok(codes(auditEdition(f)).includes('opening-inactive-alias'));
 f.opening.inactiveAliases['world:player:b']={clubId:1,canonicalId:'world:player:a'};assert.ok(codes(auditEdition(f)).includes('inactive-alias-chain'));
});
test('source metadata contradictions and wrong override targets are detected without leaking evidence',()=>{
 const f=fixture();f.edition.registry.worldProfiles['world:player:b'].contract.endYear=2030;f.edition.registry.worldProfiles['world:player:a'].contract.endSeason=3;f.opening.players['world:private:url']={clubId:99,endSeason:0,endType:'wrong'};
 const r=auditEdition(f);for(const code of ['contract-year-season-mismatch','contract-profile-roster-mismatch','dangling-opening-player','invalid-opening-term'])assert.ok(codes(r).includes(code),code);
 const g=fixture();g.edition.registry.clubs[0].players[0].id='https://private.invalid/person-secret';g.staffRegistry.clubs[0].members[0].name='PRIVATE NAME';g.staffRegistry.clubs[0].members[0].role='PRIVATE ROLE URL';g.edition.registry.worldProfiles['world:player:a'].contract.sourceRef='https://private.invalid/contract';g.edition.registry.clubs.push({id:'PRIVATE CLUB',players:[]});
 const text=JSON.stringify(auditEdition(g));for(const value of ['private.invalid','PRIVATE NAME','PRIVATE ROLE','PRIVATE CLUB'])assert.equal(text.includes(value),false);
});
test('fixtures are immutable and report output is deterministic across repeated audit',()=>{
 const f=freeze(fixture()),before=JSON.stringify(f),one=JSON.stringify(auditEdition(f));assert.equal(JSON.stringify(auditEdition(f)),one);assert.equal(JSON.stringify(f),before);
 assert.equal(auditEdition(null).valid,false);assert.equal(auditEdition({edition:{}}).valid,false);
});
test('all production edition builders and staff selectors produce reproducible anonymous coverage',()=>{
 const inputs=loadProductionInputs(),digest=()=>crypto.createHash('sha256').update(JSON.stringify(inputs)).digest('hex'),before=digest();
 const a=auditAll(inputs),b=auditAll(inputs);assert.deepEqual(a,b);assert.equal(digest(),before);assert.equal(a.valid,true,JSON.stringify(a.editions.flatMap(e=>e.errors)));
 assert.deepEqual(a.editions.map(e=>e.counts.playableClubs),[56,66,86,100,114]);
 const last=a.editions.at(-1);assert.equal(last.counts.players,5884);assert.equal(last.counts.prospectiveActivePlayers,5878);assert.equal(last.counts.inactiveAliases,6);assert.equal(last.counts.staffMembers,2160);
 assert.ok(last.counts.contractOfficialDeclared>0&&last.counts.contractEstimated>0);assert.ok(warning(last,'staff-source-unknown').count>0);assert.equal(last.counts.openingActiveTerms,114);assert.equal(last.counts.openingExact,96);assert.equal(last.counts.openingMinimum,18);assert.equal(last.counts.openingChanges,71);
 const text=JSON.stringify(a);assert.equal(/https?:\/\//.test(text),false);assert.equal(text.includes(inputs.staffByDatabase[inputs.editions.at(-1).id].clubs[0].members[0].name),false);
});
test('missing or partial opening source never certifies active counts or zero aliases for v5',()=>{
 const f=fixture();f.opening=null;
 const missing=auditEdition(f);assert.equal(missing.status,'unknown');assert.equal(missing.valid,false);assert.equal(missing.opening.status,'missing');assert.equal(missing.opening.applies,true);assert.equal(missing.errors.length,0);assert.ok(warning(missing,'opening-register-missing'));
 for(const key of ['prospectiveActivePlayers','inactiveAliases','openingChanges'])assert.equal(missing.counts[key],null,key);
 assert.ok(missing.clubs.every(c=>c.prospectiveActivePlayers===null));assert.equal(missing.counts.players,2,'catalogue count remains known');
 for(const field of ['players','inactiveAliases','databaseId','asOf']){const partial=fixture();delete partial.opening[field];const r=auditEdition(partial);assert.equal(r.valid,false);assert.equal(r.status,'invalid');assert.equal(r.opening.status,'invalid');assert.equal(r.counts.prospectiveActivePlayers,null);assert.equal(r.counts.inactiveAliases,null);assert.ok(codes(r).includes('invalid-opening-register'));}
 const bad=fixture();bad.opening.inactiveAliases={'world:player:a':{clubId:0,canonicalId:'world:missing'}};assert.equal(auditEdition(bad).counts.prospectiveActivePlayers,null,'contradictory alias provenance does not yield a certified active count');
});
test('edition identity/version/mode contradictions cannot select an inapplicable opening policy',()=>{
 const f=fixture();f.edition.registry.version=5;f.edition.registry.marker={id:'fixture-v5',version:5};
 const mismatch=structuredClone(f);mismatch.edition.version=4;mismatch.edition.mode='world-nationale';const r=auditEdition(mismatch);
 assert.equal(r.status,'invalid');assert.equal(r.opening.status,'unknown');assert.equal(r.opening.applies,null);assert.equal(r.counts.prospectiveActivePlayers,null);assert.ok(codes(r).includes('edition-registry-version-mismatch'));
 for(const [alter,code] of [
  [x=>x.edition.id='different-edition','edition-registry-id-mismatch'],
  [x=>x.edition.registry.marker.id='other-marker','registry-marker-id-mismatch'],
  [x=>x.edition.registry.marker.version=4,'registry-marker-version-mismatch'],
  [x=>x.edition.mode='world-nationale','edition-mode-version-mismatch']
 ]){const x=structuredClone(f);alter(x);assert.ok(codes(auditEdition(x)).includes(code),code);assert.equal(auditEdition(x).counts.inactiveAliases,null);}
 const unknown=fixture();delete unknown.edition.version;assert.equal(auditEdition(unknown).status,'unknown');assert.equal(auditEdition(unknown).opening.applies,null);
 const old=fixture();old.edition.version=4;old.edition.mode='world-nationale';old.opening=null;const nonApplicable=auditEdition(old);assert.equal(nonApplicable.valid,true);assert.equal(nonApplicable.opening.status,'not-applicable');assert.equal(nonApplicable.opening.applies,false);assert.equal(nonApplicable.counts.prospectiveActivePlayers,2);
});
test('CLI exits one with a redacted stable report when production input files are missing',()=>{
 const fs=require('node:fs'),path=require('node:path'),os=require('node:os'),{spawnSync}=require('node:child_process'),dir=fs.mkdtempSync(path.join(os.tmpdir(),'staff-contract-missing-private-'));
 try{fs.mkdirSync(path.join(dir,'ci'));const copied=path.join(dir,'ci','audit.cjs');fs.copyFileSync(require.resolve('../ci/staff-contract-quality-audit.cjs'),copied);const run=spawnSync(process.execPath,[copied],{encoding:'utf8'});assert.equal(run.status,1);assert.deepEqual(JSON.parse(run.stdout),{schema:'staff-contract-quality-v1',valid:false,errors:[{code:'production-inputs-unavailable'}]});assert.equal(run.stderr,'');assert.equal(run.stdout.includes(dir),false);}finally{fs.rmSync(dir,{recursive:true,force:true});}
});

'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const zlib=require('node:zlib');
const root=path.resolve(__dirname,'..');
const files=['data/world/foreign-inputs.json','native/engine/world-registry.json','native/engine/world-japan-extension.json','native/engine/world-nationale-extension.json','dist/rugby-common-rosters.js'];
test('les bases publiques ne transportent aucune date de naissance complète',()=>{
 for(const file of files){
  const text=fs.readFileSync(path.join(root,file),'utf8');
  assert.ok(!/["']birthDate["']\s*:\s*["']\d{4}-\d{2}-\d{2}/.test(text),file+' contient une date complète');
 }
 const ctx=vm.createContext({});
 vm.runInContext(fs.readFileSync(path.join(root,'dist/lnr-birthyears-data.js'),'utf8')+';globalThis.births=LNR_BIRTHYEARS_DATA.byId;',ctx);
 assert.equal(Object.keys(ctx.births).length,1592);
 assert.ok(Object.values(ctx.births).every(value=>typeof value==='number'||value&&Number.isInteger(value.birthYear)&&Number.isInteger(value.ageAtSeasonStart)&&!Object.hasOwn(value,'birthDate')));
 const file='tests/fixtures/roster-foundation-v1-s2.json.gz';
 const doc=JSON.parse(zlib.gunzipSync(fs.readFileSync(path.join(root,file))));
 assert.ok(!/"birthDate"\s*:\s*"\d{4}-\d{2}-\d{2}/.test(JSON.stringify(doc)),file);
 const checksumSource=fs.readFileSync(path.join(root,'dist/saves.js'),'utf8').split('\n').find(line=>line.startsWith('function saveChecksum(state)'));
 const isolated=vm.createContext({state:doc.state});
 vm.runInContext(checksumSource+';globalThis.sum=saveChecksum(state)',isolated);
 assert.equal(doc.checksum,isolated.sum,'la fixture reste intègre sans démarrer de carrière héritée');
});

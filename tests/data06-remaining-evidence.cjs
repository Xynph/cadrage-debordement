'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'..'),tool=path.join(root,'tools/data06-remaining-evidence.cjs');
function api(){assert.ok(fs.existsSync(tool),'Expected supplement validator');return require(tool)}
const read=p=>JSON.parse(fs.readFileSync(path.join(root,p),'utf8'));
test('all 378 missing identities are individually sourced, unique, and close the exact coverage gap',()=>{
 const {build}=api(),before=read('modding/data06/itsrugby-browser-reconciliation-2026-10-31.json'),d=build(root);
 assert.equal(d.players.length,378);assert.deepEqual(new Set(d.players.map(p=>p.id)),new Set(before.remainingIds));
 assert.equal(d.summary.previouslyCovered,1214);assert.equal(d.summary.totalCovered,1592);assert.equal(d.summary.remainingIdentityProfiles,0);
 assert.equal(d.summary.clubs,30);assert.ok(d.players.every(p=>p.sourceType==='lnr-individual-snapshot'&&p.position&&p.ageReported&&p.nationalityAsPublished));
});
test('compact browser transfer reproduces both raw bytes and the observed URL/name/club identity SHA256',()=>{
 const {build}=api(),d=build(root);
 assert.equal(d.integrity.rawSha256,'df405275851f7fa24366c561e7c926862d4010e76d5073d43ce381215a844431');
 assert.equal(d.integrity.identitySha256,'79184e3ec813e867fc802b7c7233c055acb1b8497e145b7b87899051e1bf4287');
 assert.ok(d.players.every(p=>p.rawProfileText&&p.sourceUrl.includes('/joueur/'+p.id.slice(4)+'-')));
});
test('published measures are converted to cm and absent measures stay null',()=>{
 const {build,parseRow}=api(),d=build(root),get=id=>d.players.find(p=>p.id===id);
 assert.equal(get('lnr:711').heightCm,198);assert.equal(get('lnr:711').weightKg,109);
 assert.equal(get('lnr:13514').heightCm,null);assert.equal(get('lnr:13514').weightKg,null);
 assert.equal(get('lnr:1009').weightKg,156);assert.ok(get('lnr:1009').qualityFlags.includes('weight-above-145kg-review'));
 assert.throws(()=>parseRow('711|ASM Clermont|2ème ligne|1m98|109 kg|28 ans|France|invented'),/Invalid/);
 assert.throws(()=>parseRow('711|ASM Clermont|2ème ligne|1m98|999 kg|28 ans|France'),/Invalid/);
 assert.throws(()=>parseRow('711|ASM Clermont|2ème ligne|1m98|109 kg|99 ans|France'),/Invalid/);
});
test('corrupt, duplicate, unknown and incomplete browser batches fail closed',()=>{
 const {validateRows,loadInputs}=api(),i=loadInputs(root);
 assert.throws(()=>validateRows(i.rawText.replace('109 kg','108 kg'),i.roster,i.baseline),/integrity/i);
 const duplicate=i.rawText.trimEnd()+'\n'+i.rawText.split('\n')[0]+'\n';
 assert.throws(()=>validateRows(duplicate,i.roster,i.baseline),/integrity|duplicate/i);
 assert.throws(()=>validateRows(i.rawText,i.roster.map(p=>p.id==='lnr:711'?{...p,name:'Someone Else'}:p),i.baseline),/identity/i);
 assert.throws(()=>validateRows(i.rawText,i.roster.map(p=>p.id==='lnr:711'?{...p,club:'bayonne'}:p),i.baseline),/identity|club/i);
 assert.throws(()=>validateRows(i.rawText,i.roster,{...i.baseline,remainingIds:i.baseline.remainingIds.slice(1)}),/remaining|coverage/i);
 const changed=structuredClone(i.baseline);changed.players[0].heightCm=199;
 assert.throws(()=>validateRows(i.rawText,i.roster,changed),/integrity/i);
});
test('supplement never overwrites prior data and performs zero network calls',()=>{
 const {build}=api(),files=['modding/data06/all-players-2026-2027.json','modding/data06/itsrugby-browser-reconciliation-2026-10-31.json','modding/data06/itsrugby-browser-capture-2026-10-31.json'];
 const sha=f=>crypto.createHash('sha256').update(fs.readFileSync(path.join(root,f))).digest('hex'),before=files.map(sha);
 const previousFetch=global.fetch;let calls=0;
 try {global.fetch=()=>{calls++;throw Error('Network forbidden')};const d=build(root);
 assert.equal(calls,0);assert.ok(d.players.every(p=>p.birthDate===null&&p.jiff===null&&p.contractEnd===null&&p.salary===null&&p.validAtCareerStart===null));
 assert.equal(d.summary.completeBiographies,0);assert.deepEqual(files.map(sha),before);
 } finally {global.fetch=previousFetch}
});
test('checked-in supplement is byte-for-byte reproducible',()=>{
 const {build}=api();assert.equal(fs.readFileSync(path.join(root,'modding/data06/remaining-lnr-profiles-2026-10-31.json'),'utf8'),JSON.stringify(build(root),null,2)+'\n');
});

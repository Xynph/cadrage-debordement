'use strict';
process.env.CD_MODES_HERITES='1'; // Anciens modes de carrière (non-Monde) : test à migrer vers le mode Monde.
const {settleClubMeetings}=require('./helpers/club-meetings.cjs');
const { assertLegacyProfessionals } = require('./helpers/assert-legacy-professionals.cjs');
const {test}=require('node:test'),a=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path'),zlib=require('node:zlib');
const {createBridge}=require('../native/engine/worker.cjs'),portraits=require('../native/engine/portraits.cjs');
function fixture(t){const root=fs.mkdtempSync(path.join(os.tmpdir(),'cd-academy-bank-'));let b=createBridge({dataDir:root,seed:13,now:1700000000000}),id=0;t.after(()=>{b.close();fs.rmSync(root,{recursive:true,force:true});});const send=(command,payload={})=>b.handle({id:++id,command,payload}),go=(command,payload)=>{const r=send(command,payload);a.equal(r.ok,true,command+': '+r.error);return r.model;};settleClubMeetings(go('new_career',{mode:'common',club:29}),(command,payload)=>go(command,payload));return {go,send,file:path.join(root,'PrototypeGodot/donnees.json'),state:()=>JSON.parse(go('export').meta.exportText).state,export:()=>go('export').meta.exportText,restart:()=>{b.close();b=createBridge({dataDir:root,seed:1,now:1});}};}
function documentWith(text,change){const d=JSON.parse(text);change(d.state);const v=JSON.stringify(d.state);let h=2166136261;for(let i=0;i<v.length;i++)h=Math.imul(h^v.charCodeAt(i),16777619);d.checksum=(h>>>0).toString(16).padStart(8,'0');return JSON.stringify(d);}
const disk=f=>fs.readFileSync(f.file),privateState=f=>JSON.parse(disk(f));
function activate(f){const m=f.go('snapshot');return f.go('academy_activate',{...m.clubLife.academyPathways.context,confirmed:true});}
function exactRestart(f){const text=f.export(),bytes=disk(f);f.restart();a.equal(f.export(),text);a.deepEqual(disk(f),bytes);f.go('import',{text});a.equal(f.export(),text);}
test('Real academy activation accepts new bank2 guests and preserves person portraits without consuming RNG',t=>{
 const f=fixture(t),prior=f.state(),seed=privateState(f).seed,clock=privateState(f).clock;let m=activate(f);const s=f.state();a.deepEqual(s.clubs,prior.clubs);a.equal(privateState(f).seed,seed);a.equal(privateState(f).clock,clock);const guests=s.nativeAcademy.centers.filter(c=>c.clubId===null);a.equal(guests.length,14);a.ok(guests.every(c=>c.players.every(p=>p.appearanceBankVersion===2)));
 for(const p of m.clubLife.academyPathways.players){const original=s.development.academy.find(q=>q.id===p.id);a.equal(p.appearanceBankVersion,original.appearanceBankVersion);a.equal(p.appearanceBankVersion,2);/* Carrure : la projection peut ajouter appearanceBuild (et un identifiant salé) sans toucher à la sauvegarde. */a.deepEqual(portraits.describe(p),portraits.describe({...original,...(p.appearanceId===undefined?{}:{appearanceId:p.appearanceId}),appearanceBuild:p.appearanceBuild}));}
 for(const p of m.clubLife.academyPathways.seniors){const original=s.clubs[s.club].players.find(q=>q.id===p.id);a.equal(p.appearanceBankVersion,original.appearanceBankVersion);}
 // Initial centres have exactly fifteen players. Build one legal duplicate with
 // the real constructor for this short scouting/projection fixture; no score or season is injected.
 const h=require('./france-harness.cjs').context(),extra=JSON.parse(h.run('JSON.stringify(academyPlayer(100,0,1,20000))'));
 m=f.go('import',{text:documentWith(f.export(),state=>state.nativeAcademy.centers.find(c=>c.id==='guest:0').players.push(extra))});
 m=f.go('academy_center_scout',{...m.clubLife.academyPathways.context,centerId:'guest:0',confirmed:true});const candidates=m.clubLife.academyPathways.centers.find(c=>c.id==='guest:0').candidates;a.ok(candidates.length);a.ok(candidates.every(p=>p.appearanceBankVersion===2));for(const p of candidates)a.equal(portraits.describe(p).bankVersion,2);
 const text=f.export(),bytes=disk(f);f.go('snapshot');a.equal(f.export(),text);a.deepEqual(disk(f),bytes);exactRestart(f);
});
test('Actual legacy v1 save keeps absent bank markers while newly activated guests use bank2',t=>{
 const f=fixture(t),old=zlib.gunzipSync(fs.readFileSync(path.join(__dirname,'fixtures/roster-foundation-v1-s2.json.gz'))).toString();f.go('import',{text:old});const before=f.state();a.equal(before.development.academy[0].appearanceBankVersion,undefined);const prior=privateState(f);const m=activate(f),after=f.state();a.deepEqual(after.clubs,before.clubs);a.equal(privateState(f).seed,prior.seed);a.equal(privateState(f).clock,prior.clock);a.ok(m.clubLife.academyPathways.players.every(p=>p.appearanceBankVersion===undefined));a.ok(after.nativeAcademy.centers.filter(c=>c.clubId===null).every(c=>c.players.every(p=>p.appearanceBankVersion===2)));exactRestart(f);
});
test('Guest marker absence and explicit1/2 round-trip; bank3, wrong types and unrelated fields refuse atomically',t=>{
 const f=fixture(t);activate(f);const initial=f.export();for(const value of [undefined,1,2]){const text=documentWith(initial,s=>{const p=s.nativeAcademy.centers.find(c=>c.clubId===null).players[0];if(value===undefined)delete p.appearanceBankVersion;else p.appearanceBankVersion=value;});f.go('import',{text});a.equal(f.state().nativeAcademy.centers.find(c=>c.clubId===null).players[0].appearanceBankVersion,value);a.equal(f.export(),text);}
 const before=f.export(),bytes=disk(f);for(const value of [3,0,'2',null]){const text=documentWith(before,s=>{s.nativeAcademy.centers.find(c=>c.clubId===null).players[0].appearanceBankVersion=value;});a.equal(f.send('import',{text}).ok,false);a.equal(f.export(),before);a.deepEqual(disk(f),bytes);}
 const text=documentWith(before,s=>{s.nativeAcademy.centers.find(c=>c.clubId===null).players[0].unrelatedField=true;});a.equal(f.send('import',{text}).ok,false);a.equal(f.export(),before);a.deepEqual(disk(f),bytes);
});

test('Historical junior player records accept only absent or bank1/2 without opening their closed schema',t=>{
 const {make}=require('./native-academy.cjs'),h=make(0,'fiction'),r=h.run;
 r('CDEspoirsV73.setup(S);CDEspoirsAccessionV74.setup(S);CDEspoirsMovementV75.ensure(S);for(const api of [CDEspoirsScoutingV76,CDEspoirsProV77,CDEspoirsPathwaysV78V81,CDEspoirsCareerV82V85,CDEspoirsFollowupV86V89,CDEspoirsDynamicsV90V94,CDEspoirsStrategyV95V100,CDEspoirsCoachingV101V104])api.ensure(S);');
 const f=fixture(t);for(const version of [undefined,1,2]){h.ctx.bank=version;r('if(bank===undefined)delete S.v74Accession.centers[0].players[0].appearanceBankVersion;else S.v74Accession.centers[0].players[0].appearanceBankVersion=bank;');const before=r('JSON.stringify(S)'),seed=h.seed();r('A.validate(S)');a.equal(r('JSON.stringify(S)'),before);a.equal(h.seed(),seed);const text=r('JSON.stringify(createSaveDocument())');f.go('import',{text});assertLegacyProfessionals(f.state(),JSON.parse(text).state);}
 const before=f.export(),bytes=disk(f);for(const change of [p=>p.appearanceBankVersion=3,p=>p.appearanceBankVersion='2',p=>p.extra=true]){const text=documentWith(before,s=>change(s.v74Accession.centers[0].players[0]));a.equal(f.send('import',{text}).ok,false);a.equal(f.export(),before);a.deepEqual(disk(f),bytes);}exactRestart(f);
});

'use strict';
const {settleClubMeetings}=require('./helpers/club-meetings.cjs');
const {test}=require('node:test'),a=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {createBridge}=require('../native/engine/worker.cjs'),portraits=require('../native/engine/portraits.cjs');
// Carrière Monde (world-champ) : les Espoirs du club (development.academy) et ceux des centres de l'ordinateur
// (aiRoster.academies) portent le marqueur de banque d'apparence 2 ; la projection ne le modifie pas.
function fixture(t){const root=fs.mkdtempSync(path.join(os.tmpdir(),'cd-academy-bank-'));let b=createBridge({dataDir:root,seed:13,now:1700000000000}),id=0;t.after(()=>{b.close();fs.rmSync(root,{recursive:true,force:true});});const send=(command,payload={})=>b.handle({id:++id,command,payload}),go=(command,payload)=>{const r=send(command,payload);a.equal(r.ok,true,command+': '+r.error);return r.model;};settleClubMeetings(go('new_career',{mode:'world-champ',club:0}),(command,payload)=>go(command,payload));return {go,send,file:path.join(root,'PrototypeGodot/donnees.json'),state:()=>JSON.parse(go('export').meta.exportText).state,export:()=>go('export').meta.exportText,restart:()=>{b.close();b=createBridge({dataDir:root,seed:1,now:1});}};}
function documentWith(text,change){const d=JSON.parse(text);change(d.state);const v=JSON.stringify(d.state);let h=2166136261;for(let i=0;i<v.length;i++)h=Math.imul(h^v.charCodeAt(i),16777619);d.checksum=(h>>>0).toString(16).padStart(8,'0');return JSON.stringify(d);}
const disk=f=>fs.readFileSync(f.file),privateState=f=>JSON.parse(disk(f));
function exactRestart(f){const text=f.export(),bytes=disk(f);f.restart();a.equal(f.export(),text);a.deepEqual(disk(f),bytes);f.go('import',{text});a.equal(f.export(),text);}
const guestPlayer=s=>s.aiRoster.academies.find(c=>c.players.length).players[0];
test('Carrière Monde : tous les Espoirs portent la banque 2 et la projection garde les portraits sans consommer le RNG',t=>{
 const f=fixture(t),s=f.state(),seed=privateState(f).seed,clock=privateState(f).clock;
 a.ok(s.aiRoster.academies.length>=100,'centres de l’ordinateur du Monde');
 a.ok(s.aiRoster.academies.every(c=>c.players.every(p=>p.appearanceBankVersion===2)));
 a.ok(s.development.academy.length>0&&s.development.academy.every(p=>p.appearanceBankVersion===2));
 const m=f.go('snapshot');a.ok(m.clubLife.academyPathways.players.length>0);
 for(const p of m.clubLife.academyPathways.players){const original=s.development.academy.find(q=>q.id===p.id);a.ok(original);a.equal(p.appearanceBankVersion,original.appearanceBankVersion);a.equal(p.appearanceBankVersion,2);/* Carrure : la projection peut ajouter appearanceBuild (et un identifiant salé) sans toucher à la sauvegarde. */a.deepEqual(portraits.describe(p),portraits.describe({...original,...(p.appearanceId===undefined?{}:{appearanceId:p.appearanceId}),appearanceBuild:p.appearanceBuild}));a.equal(portraits.describe(p).bankVersion,2);}
 for(const p of m.decisions.development.academy)a.equal(p.appearanceBankVersion,2);
 const text=f.export(),bytes=disk(f);f.go('snapshot');a.equal(f.export(),text);a.deepEqual(disk(f),bytes);a.equal(privateState(f).seed,seed);a.equal(privateState(f).clock,clock);exactRestart(f);
});
// Chaque import valide garde une copie de secours de la carrière (limite de 8 copies) : une carrière par emplacement.
for(const [name,player] of [['centre de l’ordinateur',guestPlayer],['Espoirs du club',s=>s.development.academy[0]]])
test('Marqueur de banque, '+name+' : absence et valeurs 1/2 font l’aller-retour ; banque 3, 0, null et types erronés refusent atomiquement',t=>{
 const f=fixture(t),initial=f.export();
 for(const value of [undefined,1,2]){const text=documentWith(initial,s=>{const p=player(s);if(value===undefined)delete p.appearanceBankVersion;else p.appearanceBankVersion=value;});f.go('import',{text});a.equal(player(f.state()).appearanceBankVersion,value);a.equal(f.export(),text);}
 const before=f.export(),bytes=disk(f);for(const value of [3,0,'2',null]){const text=documentWith(before,s=>{player(s).appearanceBankVersion=value;});const refus=f.send('import',{text});a.equal(refus.ok,false,String(value));a.match(refus.error,/banque de portraits/);a.equal(f.export(),before);a.deepEqual(disk(f),bytes);}
});

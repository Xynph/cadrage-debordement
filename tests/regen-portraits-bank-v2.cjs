'use strict';
const {test}=require('node:test'),a=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {describe}=require('../native/engine/portraits.cjs');
test('Legacy descriptors remain byte-for-byte identical without an explicit bank version',()=>{
 for(const {person,profile} of require('./fixtures/regen-portraits-legacy-v1.json')){
  a.equal(JSON.stringify(describe(person)),JSON.stringify(profile));
  a.equal(JSON.stringify(describe({...person,appearanceBankVersion:1})),JSON.stringify(profile));
 }
});
test('Bank2 reaches exactly160 player bases and40 staff bases in four stable age bands',()=>{
 const players=new Set(),staff=new Set();
 for(let i=0;i<5000;i++){
  const p=describe({id:'bank:'+i,appearanceBankVersion:2,age:21});players.add(p.cell);a.equal(p.bankVersion,2);a.match(p.baseId,/^players:/);a(p.assetCell>=0&&p.assetCell<p.columns*p.rows);
  for(const age of [40,50,60,70]){const s=describe({id:'staff:'+i,portraitRole:'staff',appearanceAge:age,age,appearanceBankVersion:2});staff.add(s.cell);a.equal(Math.floor(s.cell/10),(age-40)/10);}
 }
 a.equal(players.size,160);a.equal(staff.size,40);
});
test('Bank2 never changes face geometry or bank on promotion, renaming or player-to-staff conversion',()=>{
 const person={id:'academy:stable',appearanceBankVersion:2,age:19},p=describe(person),s=describe({id:'staff:other',sourcePlayerId:person.id,appearanceBankVersion:2,portraitRole:'staff',age:52,appearanceAge:19});
 for(const key of Object.keys(p))if(!['maturity','ageBasis','referenceAge'].includes(key))a.deepEqual(s[key],p[key],key);
 a.deepEqual(describe({...person,name:'Changed',clubId:99}),p);
 a.equal(describe({...person,age:45}).baseId,p.baseId);
});
test('The200-base catalogue counts original files, cells and exact immutable asset bytes',{skip:process.env.CD_REGEN_ASSETS_PENDING==='1'&&'assets not delivered yet'},()=>{
 const m=require('../native/godot/art/regen-bank-v2/catalogue.json');
 a.equal(m.total,200);a.equal(m.bases.length,200);a.equal(new Set(m.bases.map(b=>b.id)).size,200);
 a.equal(m.bases.filter(b=>b.kind==='player').length,160);a.equal(m.bases.filter(b=>b.kind==='staff').length,40);
 for(const asset of m.assets){const bytes=fs.readFileSync(path.resolve(__dirname,'..',asset.file));a.equal(crypto.createHash('sha256').update(bytes).digest('hex'),asset.sha256);if(asset.file.endsWith('.png')){a.equal(bytes.subarray(1,4).toString(),'PNG');a(bytes.readUInt32BE(16)/asset.grid[0]>=256);a(bytes.readUInt32BE(20)/asset.grid[1]>=256);}}
 for(const b of m.bases){const asset=m.assets.find(x=>x.id===b.asset);a(asset);a(b.cell>=0&&b.cell<asset.grid[0]*asset.grid[1]);}
});
test('Visual trait receipts separate observations from prompts and retain uncertainty for eye colours',{skip:process.env.CD_REGEN_ASSETS_PENDING==='1'&&'trait receipts not delivered yet'},()=>{
 const m=require('../native/godot/art/regen-bank-v2/catalogue.json'),rows=m.bases.filter(b=>b.kind==='player'&&Number(b.id.split(':')[1])>=32);a.equal(rows.length,128);
 for(const row of rows){a(row.observedTraits);a.equal(row.observedTraits.eyeConfidence,'visual-estimate');a.equal(row.observedTraits.faceComplete,true);a.equal(row.traitConfidence,'visual-estimate');}
 for(const [key,values] of Object.entries({hairCategory:['bald','short','medium','long'],beardCategory:['none','stubble','short','long'],build:['slender','average','powerful','heavyset']})){const actual=new Set(rows.map(r=>r.observedTraits[key]));for(const value of values)a(actual.has(value));}
 const features=rows.flatMap(r=>r.observedTraits.features).join(' ');a.match(features,/mole/);a.match(features,/scar/);
});

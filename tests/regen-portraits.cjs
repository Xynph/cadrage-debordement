'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const {describe,hash}=require('../native/engine/portraits.cjs');
test('portrait identity is deterministic and independent from names, clubs and match state',()=>{
 const player=Object.freeze({id:'academy-regen-123',name:'Private Name',clubId:0,age:22});
 const profile=describe(player);assert.deepEqual(describe(player),profile);
 assert.deepEqual(describe({...player,name:'Other',clubId:113,condition:8,rating:88}),profile);
 assert.notEqual(describe({id:'academy-regen-124'}).seed,profile.seed);
 assert.equal(hash('abc'),440920331);assert.equal(describe({}).appearanceId,'anonymous');
 assert.equal(describe({id:'a',appearanceId:'appearance:b'}).appearanceId,'appearance:b');
});
test('player-to-staff conversion preserves the visual origin and face geometry',()=>{
 const player=describe({id:'academy-regen-123',age:22});
 const staff=describe({id:'staff:career:123',sourcePlayerId:'academy-regen-123',appearanceAge:22,age:49,portraitRole:'staff'});
 for(const field of ['appearanceId','seed','origin','atlas','cell','faceWidth','eyeSpacing','noseWidth','jawWidth','zoom','cropX','cropY','saturation','exposure','shirt','mirror'])assert.deepEqual(staff[field],player[field],field);
 assert.ok(staff.maturity>player.maturity);
});
test('staff appearance age anchors the crop; current age only changes the age treatment',()=>{
 const staff=describe({id:'staff:regen:1',portraitRole:'staff',appearanceAge:54,age:54});
 const older=describe({id:'staff:regen:1',portraitRole:'staff',appearanceAge:54,age:75});
 assert.equal(staff.atlas,'staff');assert.equal(staff.ageBand,1);assert.equal(staff.cell,older.cell);
 assert.equal(staff.seed,older.seed);assert.ok(older.maturity>staff.maturity);
 const missing=describe({id:'staff:regen:2',portraitRole:'staff'});assert.equal(missing.ageBasis,'illustrative');assert.equal(missing.referenceAge,null);
});
test('variation ranges remain subtle and outputs never copy private fields',()=>{
 const signatures=new Set(),cells=new Set();
 for(let i=0;i<200;i++){
  const p=describe({id:'regen:'+i,privateToken:'secret',name:'Private Name'});
  signatures.add(JSON.stringify(p));cells.add(p.cell);
  assert.ok(p.faceWidth>=.965&&p.faceWidth<=1.035);assert.ok(Math.abs(p.eyeSpacing)<=.01);
  assert.ok(Math.abs(p.noseWidth)<=.012&&Math.abs(p.jawWidth)<=.012);
  assert.ok(p.zoom>=1.005&&p.zoom<=1.03&&Math.abs(p.cropX)<=.008&&Math.abs(p.cropY)<=.006);
  assert.ok(p.cell>=0&&p.cell<32);assert.equal(JSON.stringify(p).includes('secret'),false);assert.equal(JSON.stringify(p).includes('Private Name'),false);
 }
 assert.equal(signatures.size,200);assert.ok(cells.size>24);
 // Distinct parameters are not a mathematical guarantee of perceptual uniqueness.
});
test('portrait source manifest names the pre-generated AI assets and exact source bytes',()=>{
 const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
 const manifest=require('../native/godot/art/regen-portraits-manifest.json');
 assert.equal(manifest.runtimeInference,false);assert.equal(manifest.visualUniquenessGuaranteed,false);
 assert.equal(manifest.assets.length,3);
 for(const asset of manifest.assets){const file=path.resolve(__dirname,'..',asset.file);assert.equal(crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex'),asset.sha256);assert.equal(asset.fictional,true);assert.deepEqual(asset.grid,[4,4]);assert.equal(asset.cells,16);}
});

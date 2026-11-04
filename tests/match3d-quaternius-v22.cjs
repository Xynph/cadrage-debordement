'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'../dist');
const file=p=>fs.readFileSync(path.join(root,p));
test('v22 CC0 glb contains a real skinned humanoid, detailed materials and clips',()=>{
 const bin=file('match3d/assets/quaternius-rugby-athlete.glb');
 assert.equal(bin.toString('ascii',0,4),'glTF');
 assert.equal(bin.readUInt32LE(4),2);
 assert.equal(bin.readUInt32LE(8),bin.length);
 const json=JSON.parse(bin.subarray(20,20+bin.readUInt32LE(12)).toString().trim());
 assert.ok(json.skins.length>=1);
 assert.ok(json.meshes.length>=1);
 assert.ok(json.materials.length>=7);
 assert.ok(json.animations.length>=8);
 for(const name of ['Man_Run','Man_Walk','Man_Idle','Man_Death']){
  assert.ok(json.animations.some(a=>(a.name||'').endsWith(name)),name);
 }
 assert.ok(json.nodes.some(n=>n.name==='UpperArm.L'));
 assert.ok(json.nodes.some(n=>n.name==='LowerLeg.R'));
 assert.ok(json.nodes.some(n=>n.skin!==undefined));
});
test('v22 local script is loaded before renderer and tracks fallback',()=>{
 const html=file('index.html').toString();
 const main=file('match3d/match3d.js').toString();
 const code=file('match3d/rugby-player-v22.js').toString();
 assert.ok(html.indexOf('rugby-player-v22.js')>html.indexOf('asset-player.js'));
 assert.ok(html.indexOf('rugby-player-v22.js')<html.indexOf('match3d/match3d.js'));
 assert.match(main,/CDMatch3DRugbyPlayer\|\|window.CDMatch3DAssetPlayer/);
 assert.match(code,/quaternius-rugby-athlete\.glb/);
 assert.match(code,/fallback\.build/);
 assert.match(code,/crossFadeTo/);
 assert.doesNotMatch(code,/(?:fetch\s*\(|https?:\/\/)/);
});
test('v22 CC0 provenance is retained with embedded asset',()=>{
 const license=file('match3d/assets/QUATERNIUS-CC0-v22.md').toString();
 assert.match(license,/Quaternius/);
 assert.match(license,/CC0 1\.0/);
 assert.match(license,/2faab1ed245bbe2b28153151d3b301913a216f69/);
});

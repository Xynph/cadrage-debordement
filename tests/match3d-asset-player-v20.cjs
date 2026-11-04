'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const root=path.resolve(__dirname,'../dist');
const read=p=>fs.readFileSync(path.join(root,p));
test('v20: bundled offline glTF has skin, animation and local buffer',()=>{
 const json=JSON.parse(read('match3d/assets/cesium-athlete.gltf').toString());
 assert.equal(json.asset.version,'2.0');
 assert.ok(json.skins.length>=1);
 assert.ok(json.animations.length>=1);
 assert.ok(json.meshes.length>=1);
 assert.ok(json.buffers.every(b=>b.uri&&!/^https?:/i.test(b.uri)&&read('match3d/assets/'+b.uri).length>=b.byteLength));
 assert.ok(!json.images||json.images.length===0);
});
test('v20: local loader and athlete scripts precede renderer',()=>{
 const html=read('index.html').toString();
 for(const name of ['match3d/vendor/GLTFLoader-r149.js','match3d/asset-player.js','match3d/match3d.js'])
  assert.ok(html.includes(name),name);
 assert.ok(html.indexOf('match3d/asset-player.js')<html.indexOf('match3d/match3d.js'));
 const js=read('match3d/match3d.js').toString();
 assert.match(js,/asset\.load\(T\)/);
 assert.match(js,/model\.build\(T,p\)/);
 assert.match(js,/diagnostics:/);
});

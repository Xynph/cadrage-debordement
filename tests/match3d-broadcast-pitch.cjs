'use strict';
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const broadcast=require('../dist/match3d/broadcast-pitch.js');
for(const kind of ['shadow','grass']){
 const a=broadcast.pixels(kind),b=broadcast.pixels(kind);
 assert.deepEqual(a,b);
 assert.equal(a.length,64*64*4);
 assert.ok(a.every(v=>v>=0&&v<=255));
}
const turf=broadcast.pixels('grass');
assert.notEqual(turf[1],turf[(5*64+13)*4+1]);
const shadow=broadcast.pixels('shadow');
assert.equal(shadow[3],0);
assert.ok(shadow[(32*64+32)*4+3]>100);
class Obj{
 constructor(){this.children=[];this.position={x:0,y:0,z:0};this.rotation={};this.scale={setScalar:v=>{this.scaleValue=v}};}
 add(o){this.children.push(o)}
 remove(o){this.children=this.children.filter(x=>x!==o)}
}
class Geo{dispose(){this.disposed=true}}
class Mat{constructor(x){Object.assign(this,x)}dispose(){this.disposed=true}}
class Texture{constructor(data,w,h){this.data=data;this.width=w;this.height=h;this.repeat={set:(a,b)=>{this.repeats=[a,b]}}}dispose(){this.disposed=true}}
class Mesh extends Obj{constructor(g,m){super();this.geometry=g;this.material=m}}
const T={DataTexture:Texture,PlaneGeometry:Geo,MeshBasicMaterial:Mat,MeshLambertMaterial:Mat,Mesh,
 RGBAFormat:1,UnsignedByteType:2,LinearFilter:3,LinearMipmapLinearFilter:4,RepeatWrapping:5,DoubleSide:6};
const grass=broadcast.grassMaterial(T);
assert.deepEqual(grass.map.repeats,[32,23]);
assert.equal(grass.map.needsUpdate,true);
const scene=new Obj(),effect=broadcast.create(scene,T);
const athletes=new Map();
for(let id=0;id<30;id++)athletes.set(id,{position:{x:id-15,y:id%3*.1,z:id/2}});
effect.sync(athletes);
assert.equal(effect.count(),30);
assert.equal(scene.children.length,30);
const initial=scene.children[0];
assert.equal(initial.position.x,-15);
assert.equal(initial.position.y,.029);
athletes.get(0).position.x=8;
effect.sync(athletes);
assert.equal(effect.count(),30);
assert.equal(scene.children[0],initial);
assert.equal(initial.position.x,8);
athletes.delete(0);
effect.sync(athletes);
assert.equal(effect.count(),29);
effect.dispose();
assert.equal(scene.children.length,0);
assert.equal(effect.count(),0);
const renderer=fs.readFileSync(path.join(__dirname,'../dist/match3d/match3d.js'),'utf8');
const html=fs.readFileSync(path.join(__dirname,'../dist/index.html'),'utf8');
assert.ok(renderer.includes('CDMatch3DBroadcast.grassMaterial(T)'));
assert.ok(renderer.includes('CDMatch3DBroadcast.create(scene,T)'));
assert.ok(renderer.includes('instance.broadcast.sync(instance.players)'));
assert.ok(renderer.includes('i.broadcast.dispose()'));
assert.equal(html.split('match3d/broadcast-pitch.js').length-1,1);
assert.ok(html.indexOf('match3d/broadcast-pitch.js')<html.indexOf('match3d/match3d.js'));
console.log('MATCH 3D broadcast textured turf, 30 shadows and lifecycle OK');

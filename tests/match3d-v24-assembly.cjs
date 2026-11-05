const assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const sandbox={};vm.runInNewContext(fs.readFileSync('dist/match3d/assets/rugby-v24/assembly.js','utf8'),sandbox);
assert.equal(typeof sandbox.CDV24Assembly.load,'function');
const api=sandbox.CDV24Assembly;
assert.throws(()=>api.matchBones([{name:'missing'}],[]),/missing/);
const bones=[{name:'hip'},{name:'arm'}];assert.equal(api.matchBones([{name:'arm'}],bones)[0],bones[1]);
console.log('PASS assembly API, matching by bone name, missing bone rejected');
const THREE=require('../dist/match3d/vendor/three-r149.min.js');
const position=new THREE.Float32BufferAttribute([0,1,0],3);
const delta=new THREE.Int16BufferAttribute([16384,0,-16384],3,true);
assert.equal(typeof api.bakePosition,'function','lecture des morphs normalisés disponible');
const baked=api.bakePosition(THREE,position,[delta],{male:0},{male:1});
assert.ok(Math.abs(baked.getX(0)-16384/32767)<1e-6,'delta Int16 décodé');
assert.equal(baked.getY(0),1);
assert.ok(Math.abs(baked.getZ(0)+16384/32767)<1e-6);
console.log('PASS morph Int16 normalisé : delta métrique et position conservés');
const sparse=new THREE.Int16BufferAttribute(new Int16Array(6),3,true);
sparse.setX(1,16384); // Reproduit le chargement sparse normalisé du loader r149.
assert.equal(typeof api.restoreSparseValues,'function');
api.restoreSparseValues(sparse,new Uint16Array([1]),new Int16Array([16384,0,-16384]));
assert.ok(Math.abs(sparse.getX(1)-16384/32767)<1e-6);
assert.equal(sparse.getX(0),0);
console.log('PASS sparse normalisé : valeurs brutes restaurées sans double conversion');

const root=new THREE.Group(),skeletonBones=Array.from({length:53},(_,i)=>{const b=new THREE.Bone();b.name='b'+i;return b;});
root.add(skeletonBones[0]);for(let i=1;i<skeletonBones.length;i++)skeletonBones[i-1].add(skeletonBones[i]);
const skeleton=new THREE.Skeleton(skeletonBones);
function mesh(name,geo){const m=new THREE.SkinnedMesh(geo,new THREE.MeshStandardMaterial());m.name=name;root.add(m);m.bind(skeleton);return m;}
const bodyGeo=new THREE.BoxGeometry(.6,1.7,.3,10,20,4);bodyGeo.translate(0,.85,0);
const shirtGeo=new THREE.BoxGeometry(.75,.95,.42);shirtGeo.translate(0,1.15,0);
const bodyMesh=mesh('Body',bodyGeo),shirtMesh=mesh('Cloth_tshirt',shirtGeo);
const before=bodyGeo.index.count/3,first=api.coverSkinByShirt(THREE,root);
assert.ok(first.removed>8,'Real covered skin triangles removed');
assert.ok(first.remaining<before,'Anatomical surface cropped under shirt');
assert.equal(shirtMesh.geometry.index.count,36,'Garment unaffected');
assert.equal(first.remaining,bodyMesh.geometry.index.count/3);
const noShirt=new THREE.Group();noShirt.add(bodyMesh);
assert.equal(api.coverSkinByShirt(THREE,noShirt).removed,0,'Missing shirt leaves original body intact');
console.log('PASS covered torso skin culled only under shirt, with missing-shirt fallback');

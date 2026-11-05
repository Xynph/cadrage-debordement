'use strict';
// Offline geometry/weight transfer. No body mask, shader or material changes.
const THREE=require('../dist/match3d/vendor/three-r149.min.js');
function fitShirt(shirt,body,clearance=.012){
 if(!shirt.positions?.every(Number.isFinite)||!body.positions?.every(Number.isFinite)||!body.indices?.length)throw Error('Invalid finite surface required');
 const points=body.positions,triangles=[];
 for(let i=0;i<body.indices.length;i+=3){
  const ids=body.indices.slice(i,i+3),v=ids.map(id=>new THREE.Vector3().fromArray(points,id*3));
  const tri=new THREE.Triangle(...v),normal=tri.getNormal(new THREE.Vector3());
  if(normal.lengthSq()>.5)triangles.push({ids,tri,normal});
 }
 if(!triangles.length)throw Error('Invalid body triangles');
 const positions=[],joints=[],weights=[];let moved=0,maxMove=0,weightChanges=0;
 const p=new THREE.Vector3(),q=new THREE.Vector3(),nearest=new THREE.Vector3(),bary=new THREE.Vector3();
 for(let i=0;i<shirt.positions.length/3;i++){
  p.fromArray(shirt.positions,i*3);let distance=Infinity,best;
  for(const t of triangles){t.tri.closestPointToPoint(p,q);const d=q.distanceToSquared(p);if(d<distance){distance=d;best=t;nearest.copy(q);}}
  const signed=p.clone().sub(nearest).dot(best.normal),shift=Math.max(0,clearance-signed);
  // Reject a mismatched coordinate system instead of destroying the garment.
  if(Math.sqrt(distance)>.15||shift>.08)throw Error('Shirt/body correspondence outside safety bound at '+i);
  const fitted=p.clone().addScaledVector(best.normal,shift);positions.push(...fitted.toArray());
  if(shift>1e-6)moved++;maxMove=Math.max(maxMove,shift);
  best.tri.getBarycoord(nearest,bary);const blend=new Map();
  best.ids.forEach((id,k)=>{for(let c=0;c<4;c++){const bone=body.joints[id*4+c],w=body.weights[id*4+c]*bary.getComponent(k);blend.set(bone,(blend.get(bone)||0)+w);}});
  const ordered=[...blend].filter(x=>x[1]>1e-8).sort((a,b)=>b[1]-a[1]).slice(0,4),sum=ordered.reduce((n,x)=>n+x[1],0);
  if(sum<.5)throw Error('Invalid skin weights');
  for(let k=0;k<4;k++){joints.push(ordered[k]?.[0]||0);weights.push((ordered[k]?.[1]||0)/sum);}
  if(shirt.joints?.[i*4]!==joints[i*4])weightChanges++;
 }
 return {positions,joints,weights,moved,maxMove,weightChanges};
}
module.exports={fitShirt};
if(require.main===module)(async()=>{
 const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
 const {NodeIO}=require('@gltf-transform/core'),{ALL_EXTENSIONS}=require('@gltf-transform/extensions');
 const io=new NodeIO().registerExtensions(ALL_EXTENSIONS);
 const morphs={gender_male:1,muscle_max:.8,weight_max:.15,corr_gender_male__muscle_max:.8,corr_gender_male__weight_max:.15,corr_weight_max__muscle_max:.12};
 function baked(mesh,prim){const a=prim.getAttribute('POSITION'),names=mesh.getExtras().targetNames||[],targets=prim.listTargets();const positions=[];
  for(let i=0;i<a.getCount();i++){const p=a.getElement(i,[]);for(const [name,w]of Object.entries(morphs)){const t=targets[names.indexOf(name)]?.getAttribute('POSITION');if(t){const d=t.getElement(i,[]);for(let k=0;k<3;k++)p[k]+=w*d[k];}}positions.push(...p);}return positions;}
 function values(a){const out=[];for(let i=0;i<a.getCount();i++)out.push(...a.getElement(i,[]));return out;}
 const dir='dist/match3d/assets/rugby-v24/lod',report={method:'nearest body triangle clearance and barycentric skin weights; athletic morph baked into shirt only',clearance:.012,levels:[]};
 for(let lod=0;lod<3;lod++){
  const file=path.join(dir,'clothing_tshirt-lod'+lod+'.glb'),original=fs.readFileSync(file);
  const body=await io.read(path.join(dir,'base_body_anim-lod'+lod+'.glb')),shirt=await io.read(file);
  const bm=body.getRoot().listNodes().find(n=>n.getName()==='Body').getMesh(),bp=bm.listPrimitives()[0],sm=shirt.getRoot().listMeshes()[0],sp=sm.listPrimitives()[0];
  if(sm.getExtras().cdAthleticFit)throw Error('Already fitted: regenerate pristine LOD inputs before fitting');
  const skin=shirt.getRoot().listSkins()[0],bs=body.getRoot().listSkins()[0];
  const a=skin.getInverseBindMatrices().getArray(),b=bs.getInverseBindMatrices().getArray();
  if(a.length!==b.length||a.some((v,i)=>Math.abs(v-b[i])>1e-5))throw Error('Inverse bind mismatch');
  const input={positions:baked(sm,sp),joints:values(sp.getAttribute('JOINTS_0')),weights:values(sp.getAttribute('WEIGHTS_0'))};
  const r=fitShirt(input,{positions:baked(bm,bp),indices:values(bp.getIndices()),joints:values(bp.getAttribute('JOINTS_0')),weights:values(bp.getAttribute('WEIGHTS_0'))});
  const buffer=shirt.getRoot().listBuffers()[0];
  for(const [semantic,type,array]of [['POSITION','VEC3',new Float32Array(r.positions)],['JOINTS_0','VEC4',new Uint16Array(r.joints)],['WEIGHTS_0','VEC4',new Float32Array(r.weights)]]){
   sp.setAttribute(semantic,shirt.createAccessor().setType(type).setArray(array).setBuffer(buffer));
  }
  // Fixed athletic derivative: leave no active morph that would be applied twice.
  for(const target of sp.listTargets())sp.removeTarget(target);
  sm.setWeights([]);sm.setExtras({...sm.getExtras(),targetNames:[],cdAthleticFit:true});
  await io.write(file,shirt);
  report.levels.push({lod,vertices:r.positions.length/3,moved:r.moved,maxMove:r.maxMove,weightChanges:r.weightChanges,sourceSHA256:crypto.createHash('sha256').update(original).digest('hex'),outputSHA256:crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex')});
 }
 fs.writeFileSync(path.join(dir,'shirt-fit-report.json'),JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report));
})().catch(e=>{console.error(e);process.exitCode=1;});

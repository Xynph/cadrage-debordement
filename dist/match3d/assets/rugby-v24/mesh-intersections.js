'use strict';
/* Lot 24: exact segment/triangle intersections on deterministic samples of
 * REAL deformed skinned Body triangles. Isolated qualification only.
 * A zero count is NOT proof that unexamined triangles cannot intersect. */
(function(root){
 function triangles(THREE,rig,limit=900){
  const out=[];
  rig.body.updateMatrixWorld(true);
  const chest=rig.bones.find(b=>b.name==='spine_03').getWorldPosition(new THREE.Vector3());
  rig.body.traverse(mesh=>{
   if(!mesh.isSkinnedMesh||mesh.name!=='Body')return;
   const geom=mesh.geometry,pos=geom.getAttribute('position'),idx=geom.index;
   if(!pos)return;
   const total=Math.floor((idx?idx.count:pos.count)/3);
   const stride=Math.max(1,Math.ceil(total/limit));
   const cache=new Map();
   function vertex(i){
    if(!cache.has(i)){
     const v=new THREE.Vector3().fromBufferAttribute(pos,i);
     mesh.boneTransform(i,v);mesh.localToWorld(v);cache.set(i,v);
    }
    return cache.get(i);
   }
   for(let t=0;t<total;t+=stride){
    const a=vertex(idx?idx.getX(t*3):t*3),b=vertex(idx?idx.getX(t*3+1):t*3+1),
      c=vertex(idx?idx.getX(t*3+2):t*3+2);
    const center=a.clone().add(b).add(c).multiplyScalar(1/3);
    if(center.distanceTo(chest)>.55)continue;
    out.push([a.clone(),b.clone(),c.clone()]);
   }
  });
  return out;
 }
 function segmentTriangle(THREE,a,b,tri,epsilon=1e-8){
  const [v0,v1,v2]=tri,e1=v1.clone().sub(v0),e2=v2.clone().sub(v0),
   d=b.clone().sub(a),h=new THREE.Vector3().crossVectors(d,e2);
  const det=e1.dot(h);
  if(Math.abs(det)<epsilon)return false; // parallel/coplanar: not certified
  const inv=1/det,s=a.clone().sub(v0),u=inv*s.dot(h);
  if(u<epsilon||u>1-epsilon)return false;
  const q=new THREE.Vector3().crossVectors(s,e1),v=inv*d.dot(q);
  if(v<epsilon||u+v>1-epsilon)return false;
  const t=inv*e2.dot(q);
  return t>epsilon&&t<1-epsilon;
 }
 function intersects(THREE,a,b){
  for(const [u,v] of [[0,1],[1,2],[2,0]])
   if(segmentTriangle(THREE,a[u],a[v],b)||segmentTriangle(THREE,b[u],b[v],a))return true;
  return false;
 }
 function bounds(t){
  return {min:[0,1,2].map(i=>Math.min(t[0].getComponent(i),t[1].getComponent(i),t[2].getComponent(i))),
   max:[0,1,2].map(i=>Math.max(t[0].getComponent(i),t[1].getComponent(i),t[2].getComponent(i)))};
 }
 function probe(THREE,tackler,carrier,limit=900){
  const left=triangles(THREE,tackler,limit),right=triangles(THREE,carrier,limit);
  const boxes=right.map(bounds);let candidates=0,intersections=0;
  const examples=[];
  left.forEach((a,i)=>{
   const ba=bounds(a);
   right.forEach((b,j)=>{
    const bb=boxes[j];
    if([0,1,2].some(k=>ba.max[k]<bb.min[k]||bb.max[k]<ba.min[k]))return;
    candidates++;
    if(intersects(THREE,a,b)){intersections++;if(examples.length<8)examples.push([i,j]);}
   });
  });
  return {tacklerTriangles:left.length,carrierTriangles:right.length,
   aabbCandidatePairs:candidates,properTriangleIntersections:intersections,
   examples,scope:'Deterministic subset of real deformed Body triangles near spine_03; parallel/coplanar contacts and unsampled faces excluded; no full collision certification'};
 }
 root.CDMatch3DV24MeshIntersections=Object.freeze({probe,intersects});
})(typeof window!=='undefined'?window:globalThis);

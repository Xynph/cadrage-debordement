'use strict';
/* MATCH 3D premium lot 05: deterministic, low-draw-call decorative crowd. */
(function(root,factory){
 const api=factory();
 if(typeof module==='object'&&module.exports)module.exports=api;
 if(root)root.CDMatch3DCrowd=api;
})(typeof globalThis!=='undefined'?globalThis:null,function(){
 const PALETTE=Object.freeze([0x86a7a2,0xd7b576,0x487568,0xb87b56,0xd6d9c7,0x66828e]);
 function plan(perRing=256){
  const n=Number.isFinite(perRing)?Math.max(8,Math.min(384,Math.floor(perRing))):256;
  const seats=[];
  for(let ring=0;ring<3;ring++){
   const radius=87+ring*11, height=3.5+ring*3.2;
   for(let i=0;i<n;i++){
    const angle=(i+(ring%2)*.5)*Math.PI*2/n;
    const jitter=((i*37+ring*71)%13-6)*.075;
    seats.push(Object.freeze({
     x:Math.cos(angle)*(radius+jitter),
     y:height+((i*11+ring)%5)*.08,
     z:Math.sin(angle)*(radius+jitter),
     color:PALETTE[(i*7+ring*3+Math.floor(i/11))%PALETTE.length]
    }));
   }
  }
  return Object.freeze(seats);
 }
 function build(scene,T,perRing=256){
  if(!scene||typeof scene.add!=='function'||!T||!T.InstancedMesh||!T.Object3D)throw Error('Three.js instancing required');
  const seats=plan(perRing);
  const mesh=new T.InstancedMesh(
   new T.SphereGeometry(.43,5,4),
   new T.MeshLambertMaterial({color:0xffffff,roughness:1}),
   seats.length
  );
  const dummy=new T.Object3D();
  seats.forEach((p,i)=>{
   dummy.position.set(p.x,p.y,p.z);
   dummy.updateMatrix();
   mesh.setMatrixAt(i,dummy.matrix);
   mesh.setColorAt(i,new T.Color(p.color));
  });
  mesh.instanceMatrix.needsUpdate=true;
  if(mesh.instanceColor)mesh.instanceColor.needsUpdate=true;
  mesh.frustumCulled=false;
  scene.add(mesh);
  return mesh;
 }
 return Object.freeze({plan,build});
});

'use strict';
/* MATCH 3D premium lot 04 — procedural stadium scenery, render-only. */
(function(root,factory){
 const api=factory();
 if(typeof module==='object'&&module.exports)module.exports=api;
 if(root)root.CDMatch3DStadium=api;
})(typeof globalThis!=='undefined'?globalThis:null,function(){
 function layout(){
  return Object.freeze([
   Object.freeze({radius:83,height:2,width:8,color:0x334947}),
   Object.freeze({radius:94,height:5,width:8,color:0x3a5452}),
   Object.freeze({radius:105,height:8,width:7,color:0x2d403f})
  ]);
 }
 function build(scene,T){
  if(!scene||!T||!T.Mesh||!T.RingGeometry||!T.MeshStandardMaterial)throw Error('Three.js scene required');
  const bands=[];
  for(const band of layout()){
   const mesh=new T.Mesh(
    new T.RingGeometry(band.radius,band.radius+band.width,96),
    new T.MeshStandardMaterial({color:band.color,roughness:1,metalness:0,side:T.DoubleSide})
   );
   mesh.rotation.x=-Math.PI/2;
   mesh.position.y=band.height;
   scene.add(mesh);
   bands.push(mesh);
  }
  // Stadium floodlights: local objects only, decorative and independent of match simulation.
  const lamps=[];
  for(const x of [-52,52])for(const z of [-44,44]){
   const pole=new T.Mesh(new T.CylinderGeometry(.27,.36,23,8),new T.MeshStandardMaterial({color:0x64746f,roughness:.7}));
   pole.position.set(x,11.5,z);scene.add(pole);
   const light=new T.PointLight(0xe9f4ff,.6,95,2);
   light.position.set(x,24,z);scene.add(light);
   lamps.push({pole,light});
  }
  return Object.freeze({bands:Object.freeze(bands),lamps:Object.freeze(lamps)});
 }
 return Object.freeze({layout,build});
});

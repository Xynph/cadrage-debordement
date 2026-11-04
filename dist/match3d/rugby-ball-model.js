'use strict';
/* MATCH 3D lot 12: procedural rugby ball, fully offline and presentation-only. */
(function(root,factory){
 const api=factory();
 if(typeof module==='object'&&module.exports)module.exports=api;
 if(root)root.CDMatch3DBallModel=api;
})(typeof globalThis!=='undefined'?globalThis:null,function(){
 const detail=Object.freeze({length:1.55,width:.70,laceCount:5});
 function build(T){
  const root=new T.Group();
  const shell=new T.MeshStandardMaterial({color:0xf2e6c9,roughness:.92});
  const seam=new T.MeshStandardMaterial({color:0xa18d6d,roughness:1});
  const stripe=new T.MeshStandardMaterial({color:0x304c43,roughness:.9});
  const lace=new T.MeshStandardMaterial({color:0xfefbf0,roughness:.85});
  // Prolate ellipsoid aligned with the local X axis: rugby silhouette rather than football sphere.
  const body=new T.Mesh(new T.SphereGeometry(1,20,14),shell);
  body.scale.set(detail.length/2,detail.width/2,detail.width/2);
  root.add(body);
  // Two slim circumference bands, laid onto the elongated surface.
  for(const x of [-.52,.52]){
   const radius=(detail.width/2)*Math.sqrt(Math.max(0,1-(x/(detail.length/2))**2))+.013;
   const band=new T.Mesh(new T.TorusGeometry(radius,.026,5,32),stripe);
   band.rotation.y=Math.PI/2;
   band.position.x=x;
   root.add(band);
  }
  // Two longitudinal seams subtly follow the profile.
  for(const angle of [0,Math.PI]){
   const points=[];
   for(let k=1;k<16;k++){
    const x=-.72+k*(1.44/16);
    const r=(detail.width/2)*Math.sqrt(Math.max(0,1-(x/(detail.length/2))**2))+.008;
    points.push(new T.Vector3(x,Math.sin(angle)*r,Math.cos(angle)*r));
   }
   const line=new T.Line(new T.BufferGeometry().setFromPoints(points),new T.LineBasicMaterial({color:0xa18d6d}));
   root.add(line);
  }
  // Centered stitches on the upper surface, geometry-only (no textures or fonts).
  for(let i=0;i<detail.laceCount;i++){
   const x=(i-(detail.laceCount-1)/2)*.105;
   const y=(detail.width/2)*Math.sqrt(1-(x/(detail.length/2))**2)+.015;
   const stitch=new T.Mesh(new T.BoxGeometry(.025,.016,.115),lace);
   stitch.position.set(x,y,0);
   root.add(stitch);
  }
  root.userData.renderOnlyBall=true;
  root.userData.ballDetail=detail;
  return root;
 }
 return Object.freeze({detail,build});
});

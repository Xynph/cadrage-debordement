'use strict';
/* MATCH 3D lot 09 — lightweight, deterministic visual-only turf at existing contact cues. */
(function(root,factory){
 const api=factory();
 if(typeof module==='object'&&module.exports)module.exports=api;
 if(root)root.CDMatch3DImpact=api;
})(typeof globalThis!=='undefined'?globalThis:null,function(){
 const count=12;
 const clamp=(v,a,b)=>Math.max(a,Math.min(b,Number.isFinite(v)?v:a));
 function sample(i,t){
  const angle=i*Math.PI*2/count;
  const speed=.9+(i%4)*.26;
  const radius=t*speed;
  return Object.freeze({
   x:Math.cos(angle)*radius,
   y:Math.max(.04,Math.sin(Math.PI*t)*(0.3+(i%3)*.19)-t*t*.17),
   z:Math.sin(angle)*radius,
   opacity:clamp((1-t)*.52,0,.52)
  });
 }
 function active(pair,elapsed,players){
  if(!pair||!players||!Number.isFinite(elapsed)||elapsed<110||elapsed>750)return null;
  const a=players.get(pair.lead),b=players.get(pair.other);
  if(!a||!b||!a.position||!b.position)return null;
  const ax=a.position.x,az=a.position.z,bx=b.position.x,bz=b.position.z;
  if(![ax,az,bx,bz].every(Number.isFinite))return null;
  return Object.freeze({x:(ax+bx)/2,z:(az+bz)/2,t:clamp((elapsed-110)/640,0,1)});
 }
 function create(scene,T){
  const group=new T.Group();group.visible=false;scene.add(group);
  const dust=new T.MeshBasicMaterial({color:0xa5b18a,transparent:true,opacity:.4,depthWrite:false});
  const grass=new T.MeshBasicMaterial({color:0x537d4a,transparent:true,opacity:.4,depthWrite:false});
  const geometry=new T.SphereGeometry(.10,5,4);
  const particles=[];
  for(let i=0;i<count;i++){
   const obj=new T.Mesh(geometry,i%3===0?grass:dust);
   group.add(obj);particles.push(obj);
  }
  const ringMaterial=new T.MeshBasicMaterial({
   color:0xc6bf94,transparent:true,opacity:0,depthWrite:false,side:T.DoubleSide
  });
  const ring=new T.Mesh(new T.RingGeometry(.84,1,28),ringMaterial);
  ring.rotation.x=-Math.PI/2;group.add(ring);
  function tick(pair,elapsed,players){
   const frame=active(pair,elapsed,players);
   group.visible=!!frame;
   if(!frame)return;
   group.position.set(frame.x,0,frame.z);
   for(let i=0;i<count;i++){
    const s=sample(i,frame.t),obj=particles[i];
    obj.position.set(s.x,s.y,s.z);
    obj.scale.setScalar(.75+(i%3)*.2);
    obj.visible=s.opacity>.015;
   }
   ring.position.y=.035;
   ring.scale.setScalar(.3+frame.t*1.55);
   ringMaterial.opacity=(1-frame.t)*.16;
   dust.opacity=(1-frame.t)*.46;
   grass.opacity=(1-frame.t)*.53;
  }
  function dispose(){
   scene.remove(group);
   geometry.dispose();
   dust.dispose();grass.dispose();
   ring.geometry.dispose();ringMaterial.dispose();
  }
  return Object.freeze({tick,dispose,group});
 }
 return Object.freeze({count,sample,active,create});
});

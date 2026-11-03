'use strict';
/* MATCH 3D premium lot 06: render-only, bounded instanced crowd movement. */
(function(root,factory){
 const api=factory();
 if(typeof module==='object'&&module.exports)module.exports=api;
 if(root)root.CDMatch3DCrowdAnimation=api;
})(typeof globalThis!=='undefined'?globalThis:null,function(){
 const duration=2600,interval=65;
 const finite=(n,fallback=0)=>Number.isFinite(n)?n:fallback;
 function isTry(scene){
  if(!scene||typeof scene!=='object')return false;
  return /^(try|essai|try-scored|essai-marque)$/i.test(String(scene.kind||'').trim()) ||
   /\b(?:essai marqué|essai marque|try scored)\b/i.test(String(scene.stage||''));
 }
 function offset(index,now,celebration=0){
  const phase=finite(now)*.0026+index*.79;
  const idle=.045*Math.sin(phase);
  const cheer=Math.max(0,Math.min(1,finite(celebration)))*(.32+.22*Math.sin(phase*2.8));
  return Math.max(-.08,Math.min(.65,idle+cheer));
 }
 function create(mesh,T,seats){
  if(!mesh||typeof mesh.setMatrixAt!=='function'||!T||typeof T.Object3D!=='function'||!Array.isArray(seats))throw new TypeError('Instanced crowd required');
  const dummy=new T.Object3D();
  let lastFrame=-Infinity,lastKey=null,cheerStart=-Infinity,closed=false;
  function event(scene,now){
   if(!scene||scene.key==null)return;
   const key=String(scene.key);
   if(key===lastKey)return;
   lastKey=key;
   if(isTry(scene))cheerStart=finite(now);
  }
  function tick(now){
   if(closed)return false;
   now=finite(now);
   if(now-lastFrame<interval)return false;
   lastFrame=now;
   const elapsed=now-cheerStart,cheer=elapsed>=0&&elapsed<duration?1-elapsed/duration:0;
   seats.forEach((p,i)=>{
    dummy.position.set(p.x,p.y+offset(i,now,cheer),p.z);
    dummy.updateMatrix();
    mesh.setMatrixAt(i,dummy.matrix);
   });
   mesh.instanceMatrix.needsUpdate=true;
   return true;
  }
  return Object.freeze({event,tick,dispose(){closed=true;}});
 }
 return Object.freeze({isTry,offset,create});
});

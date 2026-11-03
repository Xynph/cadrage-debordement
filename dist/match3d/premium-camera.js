'use strict';
/* MATCH 3D lot 03 — visual-only TV camera smoothing; never mutates match data. */
(function(root,factory){
 const api=factory();
 if(typeof module==='object'&&module.exports)module.exports=api;
 if(root)root.CDMatch3DCamera=api;
})(typeof globalThis!=='undefined'?globalThis:null,function(){
 const finite=(value,fallback=0)=>Number.isFinite(value)?value:fallback;
 const clamp=(value,min,max)=>Math.max(min,Math.min(finite(value),max));
 function target(ball){
  const x=clamp(ball&&ball.x,-40,40),z=clamp(ball&&ball.z,-25,25);
  return Object.freeze({x:x*.42,y:0,z:z*.4});
 }
 function smooth(current,next,deltaMs){
  const dt=clamp(deltaMs,0,100);
  const alpha=1-Math.exp(-dt/260);
  return finite(current)+ (finite(next)-finite(current))*alpha;
 }
 function tvPosition(focus){
  return Object.freeze({x:8+focus.x,y:68,z:85+focus.z});
 }
 return Object.freeze({target,smooth,tvPosition});
});

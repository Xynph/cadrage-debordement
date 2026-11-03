'use strict';
/* MATCH 3D premium — render-only motion helpers; no game-state writes. */
(function(root,factory){
 const api=factory();
 if(typeof module==='object'&&module.exports)module.exports=api;
 if(root)root.CDMatch3DMotion=api;
})(typeof globalThis!=='undefined'?globalThis:null,function(){
 const clamp=(n,a,b)=>Math.max(a,Math.min(b,Number.isFinite(n)?n:a));
 function pose(previous,next,progress,clock,seed=0){
  const before=previous||next,dx=next.x-before.x,dy=next.y-before.y;
  const distance=Math.hypot(dx,dy);
  const pace=clamp(distance/9,0,1);
  const phase=(Number.isFinite(clock)?clock:0)*.013+seed*.83;
  const envelope=Math.sin(Math.PI*clamp(progress,0,1))*.72+.28;
  const stride=Math.sin(phase)*pace*envelope;
  const direction=distance>.01?Math.atan2(dy,dx):0;
  return Object.freeze({
   stride:clamp(stride,-1,1),
   armSwing:clamp(-stride*.78,-1,1),
   torsoLean:pace*.09*envelope,
   bounce:Math.abs(stride)*.12,
   direction,
   pace
  });
 }
 return Object.freeze({pose});
});

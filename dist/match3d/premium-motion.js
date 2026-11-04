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
  const phase=(Number.isFinite(clock)?clock:0)*(.011+pace*.006)+seed*.83;
  const progressBounded=clamp(progress,0,1);
  const envelope=progressBounded===0||progressBounded===1?0:Math.sin(Math.PI*progressBounded);
  const stride=pace===0||envelope===0?0:Math.sin(phase)*Math.sqrt(pace)*envelope;
  const kneeBend=Object.freeze([0,Math.PI].map(offset=>clamp(Math.max(0,Math.sin(phase+offset))*.84*Math.sqrt(pace)*envelope,0,.84)));
  const direction=distance>.01?Math.atan2(dy,dx):0;
  // Secondary gait cues remain visual only: no access to simulation decisions.
  const elbowFlex=Object.freeze([0,Math.PI].map(offset=>
   clamp(.16+Math.max(0,Math.sin(phase+offset))*.55*Math.sqrt(pace)*envelope,.16,.71)));
  const hipSway=clamp(Math.sin(phase)*Math.sqrt(pace)*envelope*.085,-.085,.085);
  const landing=clamp(Math.max(0,Math.cos(phase))*pace*envelope,0,1);
  return Object.freeze({
   stride:clamp(stride,-1,1),
   armSwing:clamp(-stride*.78,-1,1),
   torsoLean:pace*.13*envelope,
   bounce:Math.abs(stride)*.17,
   direction,
   kneeBend,
   elbowFlex,
   hipSway,
   landing,
   pace
  });
 }
 return Object.freeze({pose});
});

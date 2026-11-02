'use strict';
/* MATCH 3D — read-only scene projection; no mutations of match state or saves. */
(function(root,factory){
 const api=factory();
 if(typeof module==='object'&&module.exports)module.exports=api;
 if(root)root.CDMatch3DAdapter=api;
})(typeof globalThis!=='undefined'?globalThis:null,function(){
 const bounded=(n,min,max)=>Math.max(min,Math.min(max,Number.isFinite(n)?n:min));
 const point=p=>({x:bounded(p?.x,0,100),y:bounded(p?.y,0,70)});
 function normalize(scene){
  if(!scene||!Array.isArray(scene.players))throw new TypeError('Scène de match indisponible');
  const players=scene.players.filter(p=>p&&p.id!=null&&[0,1].includes(p.side)).slice(0,30)
   .map(p=>({id:String(p.id),side:p.side,slot:bounded(p.slot,0,14),x:bounded(p.x,0,100),y:bounded(p.y,0,70),featured:!!p.featured}));
  return {key:String(scene.key??''),kind:String(scene.kind||'message'),stage:String(scene.stage||''),period:scene.period===2?2:1,
   players,ball:point(scene.ball),origin:point(scene.origin||scene.ball),possession:scene.possession===1?1:0};
 }
 const world=p=>({x:p.x-50,z:p.y-35});
 function trajectory(previous,next,progress){
  const t=bounded(progress,0,1),a=previous||next;
  return {x:a.x+(next.x-a.x)*t,y:a.y+(next.y-a.y)*t};
 }
 function frame(before,after,t){
  const previous=new Map((before?.players||[]).map(p=>[p.id,p]));
  return {players:after.players.map(p=>({...p,...trajectory(previous.get(p.id),p,t)})),
   ball:trajectory(t===0?after.origin:before?.ball||after.origin,after.ball,t)};
 }
 return Object.freeze({normalize,world,trajectory,frame});
});

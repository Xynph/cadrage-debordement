'use strict';
/* MATCH 3D — read-only scene projection; no mutations of match state or saves. */
(function(root,factory){
 const api=factory();
 if(typeof module==='object'&&module.exports)module.exports=api;
 if(root)root.CDMatch3DAdapter=api;
})(typeof globalThis!=='undefined'?globalThis:null,function(){
 const bounded=(n,min,max)=>Math.max(min,Math.min(max,Number.isFinite(n)?n:min));
 const point=p=>({x:bounded(p?.x,0,100),y:bounded(p?.y,0,70)});
 const inPitch=p=>p&&Number.isFinite(p.x)&&p.x>=1.5&&p.x<=98.5&&Number.isFinite(p.y)&&p.y>=2&&p.y<=68;
 function projectedCut(scene,players){
  const event=scene.event,action=event?.scene;
  if(scene.kind!=='carry'||action?.kind!=='carry'||action.style!=='equilibre'||action.move||
     action.actor==null||![0,1].includes(action.team)||action.team!==action.possession||
     action.team!==scene.possession||!Number.isSafeInteger(event.min)||event.min<1)return undefined;
  const from=action.from?.x,to=action.to?.x;
  if(!Number.isFinite(from)||!Number.isFinite(to)||(to-from)*(action.team===0?1:-1)<8)return undefined;
  const carrier=String(action.actor),featured=players.filter(player=>player.featured);
  if(featured.length!==1||featured[0].id!==carrier||featured[0].side!==action.team||
     players.filter(player=>player.id===carrier).length!==1)return undefined;
  return {carrier,side:event.min%2===0?1:-1};
 }
 function projectedPass(scene,players){
  const action=scene.event?.scene,team=scene.possession;
  if(scene.kind!=='carry'||action?.kind!=='carry'||action.style!=='large'||action.move==='maul'||
     ![0,1].includes(team)||action.team!==team||action.possession!==team||!inPitch(action.to))return undefined;
  const lineup=action.on?.[team];
  if(!Array.isArray(lineup)||lineup.length!==15)return undefined;
  const present=id=>players.filter(player=>player.id===id);
  const receivers=present(action.actor),receiver=receivers[0];
  if(receivers.length!==1||receiver.side!==team||!receiver.featured||lineup[receiver.slot]!==receiver.id||
     players.filter(player=>player.side===team&&player.featured).length!==1)return undefined;
  const direction=team===0?1:-1;
  if(!Number.isFinite(action.from?.x)||(action.to.x-action.from.x)*direction<3.5)return undefined;
  // Begin near the start of the recorded progression. Use the historical XV
  // and pick the half-back or centre nearest the valid release position.
  const releaseX=action.from.x+direction*3;
  const catchPoint={x:releaseX-direction*2.25,y:action.to.y};
  if(!inPitch(catchPoint))return undefined;
  let selected,best=Infinity;
  for(const slot of [8,9,11,12]){
   const teammates=present(lineup[slot]);
   const player=teammates[0];
   if(teammates.length!==1||player.side!==team||player.slot!==slot||player.id===receiver.id)continue;
   const lateral=player.y>=catchPoint.y?5.5:-5.5;
   const from={x:releaseX,y:catchPoint.y+lateral};
   if(!inPitch(from))from.y=catchPoint.y-lateral;
   if(!inPitch(from))continue;
   const distance=Math.hypot(player.x-from.x,player.y-from.y);
   if(distance>=best)continue;
   best=distance;
   selected={fromId:player.id,toId:receiver.id,from,catch:catchPoint};
  }
  return selected;
 }
 function normalize(scene){
  if(!scene||!Array.isArray(scene.players))throw new TypeError('Scène de match indisponible');
  const players=scene.players.filter(p=>p&&p.id!=null&&[0,1].includes(p.side)).slice(0,30)
   .map(p=>({id:String(p.id),side:p.side,slot:bounded(p.slot,0,14),x:bounded(p.x,0,100),y:bounded(p.y,0,70),featured:!!p.featured}));
  const eventKey=scene.key&&typeof scene.key==='object'?JSON.stringify([scene.key.min,scene.key.text,scene.key.scene?.kind,scene.key.scene?.to]):String(scene.key??'');
  const cut=projectedCut(scene,players);
  const transfer=projectedPass(scene,players);
  return {key:eventKey,kind:String(scene.kind||'message'),stage:String(scene.stage||''),period:scene.period===2?2:1,
   players,ball:point(scene.ball),origin:point(scene.origin||scene.ball),possession:scene.possession===1?1:0,
   ...(cut?{cut}:{}),...(transfer?{pass:transfer}:{})};
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

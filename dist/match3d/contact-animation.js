'use strict';
/* MATCH 3D lot 08 — deterministic presentation cues, never rugby decisions. */
(function(root,factory){
 const api=factory();
 if(typeof module==='object'&&module.exports)module.exports=api;
 if(root)root.CDMatch3DContact=api;
})(typeof globalThis!=='undefined'?globalThis:null,function(){
 const clamp=(v,min,max)=>Math.max(min,Math.min(max,Number.isFinite(v)?v:min));
 const smooth=t=>{t=clamp(t,0,1);return t*t*(3-2*t);};
 const valid=p=>p&&p.id!=null&&(p.side===0||p.side===1)&&Number.isFinite(p.x)&&Number.isFinite(p.y);
 const allowed=new Set(['carry','turnover']);
 function plan(scene){
  if(!scene||!allowed.has(scene.kind)||!Array.isArray(scene.players))return null;
  const players=scene.players.filter(valid),ball=scene.ball||{};
  const attackers=players.filter(p=>p.side===scene.possession);
  const defenders=players.filter(p=>p.side!==scene.possession);
  if(!attackers.length||!defenders.length)return null;
  // Use the closest real display positions only; never manufacture an official tackle.
  const byBall=(a,b)=>Math.hypot(a.x-ball.x,a.y-ball.y)-Math.hypot(b.x-ball.x,b.y-ball.y);
  const leads=attackers.slice().sort((a,b)=>Number(b.featured)-Number(a.featured)||byBall(a,b)).slice(0,4);
  let best=null;
  for(const lead of leads)for(const other of defenders){
   const distance=Math.hypot(lead.x-other.x,lead.y-other.y);
   if(distance>9)continue;
   const candidate={lead:String(lead.id),other:String(other.id),distance,kind:scene.kind};
   if(!best||distance<best.distance)best=candidate;
  }
  if(!best)return null;
  return Object.freeze(best);
 }
 function pose(contact,id,elapsed){
  const zero=Object.freeze({lean:0,roll:0,fall:0,bracing:0});
  if(!contact||String(id)!==contact.lead&&String(id)!==contact.other)return zero;
  const t=clamp(elapsed/800,0,1);
  const hit=smooth(t/.30)*(1-smooth((t-.40)/.60));
  const bracing=smooth(t/.27)*(1-smooth((t-.55)/.45));
  const strength=clamp(1-contact.distance/13,.24,.90);
  const victim=String(id)===contact.other;
  const fall=contact.kind==='turnover'&&victim?
    strength*1.18*smooth((t-.18)/.33)*(1-smooth((t-.77)/.23)):0;
  return Object.freeze({
   lean:(victim?-1:1)*hit*.24*strength,
   roll:(victim?1:-1)*hit*.18*strength,
   fall:clamp(fall,0,1.1),
   bracing:clamp(bracing*strength,0,1)
  });
 }
 return Object.freeze({plan,pose});
});
'use strict';
// V45 : registre externe de carrière, pour nouvelles intégrations futures.
(function(root,factory){const api=factory();if(typeof module==='object'&&module.exports)module.exports=api;if(root)root.CDCareerHistory=api})(typeof globalThis==='object'?globalThis:null,function(){
 const allowed=new Set(['trophy','promotion','relegation','award','record','manager']);
 function append(history,event,{limit=200}={}){
  if(!Array.isArray(history)||!Number.isInteger(limit)||limit<1||limit>2000||
   !event||!allowed.has(event.type)||typeof event.label!=='string'||!event.label.trim()||
   !Number.isInteger(event.season)||event.season<0||
   typeof event.clubId!=='string'||!event.clubId)
   throw new RangeError('Événement invalide');
  const item={type:event.type,label:event.label.trim().slice(0,160),season:event.season,clubId:event.clubId};
  const id=event.id??[item.season,item.clubId,item.type,item.label].join(':');
  if(typeof id!=='string'||!id||id.length>250)throw new RangeError('Identifiant invalide');
  item.id=id;
  if(history.some(x=>x&&x.id===id))return history.slice(-limit).map(x=>({...x}));
  return [...history.map(x=>({...x})),item].slice(-limit);
 }
 function summary(history,{clubId=null}={}){
  if(!Array.isArray(history)||!(clubId===null||typeof clubId==='string'))
   throw new RangeError('Historique invalide');
  const entries=history.filter(e=>e&&allowed.has(e.type)&&(clubId===null||e.clubId===clubId));
  const byType={};
  for(const e of entries)byType[e.type]=(byType[e.type]||0)+1;
  const seasons=[...new Set(entries.map(e=>e.season).filter(n=>Number.isInteger(n)))].sort((a,b)=>a-b);
  return {count:entries.length,byType,seasons,latestSeason:seasons.length?seasons[seasons.length-1]:null};
 }
 function leaderboard(history,type='trophy'){
  if(!Array.isArray(history)||!allowed.has(type))throw new RangeError('Classement invalide');
  const counts=new Map();
  for(const e of history)if(e&&e.type===type&&typeof e.clubId==='string')
   counts.set(e.clubId,(counts.get(e.clubId)||0)+1);
  return [...counts].map(([clubId,count])=>({clubId,count})).sort((a,b)=>b.count-a.count||a.clubId.localeCompare(b.clubId));
 }
 return Object.freeze({append,summary,leaderboard});
});

'use strict';
const fs=require('node:fs'),path=require('node:path');
const normalized=x=>String(x||'').normalize('NFKD').replace(/[\u0300-\u036f]/g,'').replace(/[^a-zA-Z0-9]/g,'').toLowerCase();
function loadRoster(root){return ['top14-a','top14-b','prod2-a','prod2-b'].flatMap(f=>JSON.parse(fs.readFileSync(path.join(root,'modding/data03',f+'.json'),'utf8')).clubs).flatMap(c=>c.players.map(p=>({...p,club:c.club})))}
function reconcile(data,roster){
 const ids=new Set(),matches=[],unresolved=[];
 if(data.season!=='2026-2027')throw Error('Season mismatch');
 for(const c of data.clubs){
  if(!c.sourceUrl||!/^https:\/\/(?:top14|prod2)\.lnr\.fr\/club\//.test(c.sourceUrl))throw Error('Invalid LNR source');
  for(const p of c.players){
   if(!p.name||!p.position||![p.matches,p.minutes,p.points].every(x=>x===null))throw Error('Invalid published player statistics');
   const hits=roster.filter(x=>x.club===c.club&&normalized(x.name)===normalized(p.name));
   if(hits.length!==1){unresolved.push({name:p.name,club:c.club,reason:hits.length?'ambiguous-identity':'not-in-reference-roster',sourceUrl:c.sourceUrl});continue}
   if(ids.has(hits[0].id))throw Error('Duplicate player ID');
   ids.add(hits[0].id);matches.push({id:hits[0].id,name:hits[0].name,club:c.club,position:p.position,matches:null,minutes:null,points:null,sourceUrl:c.sourceUrl,kind:'official-roster-position-only',gameRating:null,historicalAsOfJuly1Verified:false});
  }
 }
 return {summary:{published:data.clubs.reduce((n,c)=>n+c.players.length,0),matched:matches.length,unresolved:unresolved.length},matches,unresolved};
}
function load(root=path.resolve(__dirname,'..')){return JSON.parse(fs.readFileSync(path.join(root,'modding/data06/official-roster-batch.json'),'utf8'))}
if(require.main===module){const root=path.resolve(__dirname,'..');const output=reconcile(load(root),loadRoster(root));console.log(JSON.stringify(output.summary,null,2))}
module.exports={normalized,loadRoster,reconcile,load};

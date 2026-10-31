'use strict';
const fs=require('node:fs'),path=require('node:path');
const norm=s=>String(s||'').normalize('NFKD').replace(/[\u0300-\u036f]/g,'').toLowerCase().replace(/[^a-z0-9]/g,'');
function distance(a,b){a=norm(a);b=norm(b);const previous=Array.from({length:b.length+1},(_,i)=>i);for(let i=1;i<=a.length;i++){let prev=previous[0];previous[0]=i;for(let j=1;j<=b.length;j++){const old=previous[j];previous[j]=Math.min(previous[j]+1,previous[j-1]+1,prev+(a[i-1]===b[j-1]?0:1));prev=old}}return previous[b.length]}
function triage(unresolved,roster,{maxDistance=3}={}){
 if(!Array.isArray(unresolved)||!Array.isArray(roster))throw Error('Expected arrays');
 if(!Number.isInteger(maxDistance)||maxDistance<0||maxDistance>5)throw Error('Invalid maxDistance');
 const ids=new Set();for(const p of roster){if(!p.id||ids.has(p.id))throw Error('Duplicate or missing roster ID');ids.add(p.id)}
 return unresolved.map(entry=>{
  if(!entry.name||!entry.arrivalClub)throw Error('Incomplete transfer');
  if(entry.mappedId||entry.autoImported)throw Error('Only unresolved transfers may be triaged');
  const candidates=roster.map(p=>({id:p.id,name:p.name,club:p.club,score:distance(entry.name,p.name)})).filter(x=>x.score<=maxDistance).sort((a,b)=>a.score-b.score||a.name.localeCompare(b.name)).slice(0,10);
  return {name:entry.name,arrivalClub:entry.arrivalClub,sourceUrl:entry.sourceUrl,candidates,decision:'manual-review',linkedId:null,autoImported:false};
 });
}
function loadRoster(root){return ['top14-a','top14-b','prod2-a','prod2-b'].flatMap(file=>JSON.parse(fs.readFileSync(path.join(root,'modding/data03',file+'.json'),'utf8')).clubs).flatMap(c=>c.players.map(p=>({id:p.id,name:p.name,club:c.club})))}
if(require.main===module){
 const source=process.argv[2];if(!source)throw Error('Provide DATA-06 reconciliation JSON path from PR #142; never guess source');
 const data=JSON.parse(fs.readFileSync(source,'utf8'));
 const list=data.records.filter(x=>x.status!=='exact-club-match');
 const output=triage(list,loadRoster(path.resolve(__dirname,'..')));
 console.log(JSON.stringify({count:output.length,manualReview:output},null,2));
}
module.exports={norm,distance,triage,loadRoster};

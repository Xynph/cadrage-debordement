'use strict';
function validatePlan({total=1592,cached=0,limit=0,budget=0,concurrency=1,delayMs=1200,confirmed=false}={}){
 for(const [name,value] of Object.entries({total,cached,limit,budget,concurrency,delayMs})) if(!Number.isSafeInteger(value)||value<0) throw Error('Invalid '+name);
 if(total!==1592||cached>total)throw Error('Invalid roster/cache size');
 if(concurrency<1||concurrency>2||delayMs<1000)throw Error('Unsafe request rate');
 if(limit>total-cached)throw Error('Limit exceeds missing profiles');
 if(budget>limit)throw Error('Paid-call budget exceeds attempted profiles');
 if(limit>0&&!confirmed)throw Error('LNR access confirmation required');
 return {catalogue:total,cached,remaining:total-cached,planned:limit,firecrawlMaximumAttempts:budget,dryRun:limit===0};
}
function checkCache(players,roster){
 const map=new Map(roster.map(x=>[x.id,x]));const seen=new Set();
 for(const p of players){const s=map.get(p.id);if(!s||seen.has(p.id)||s.url!==p.url||s.club!==p.club||!p.name)throw Error('Invalid cached profile '+p.id);seen.add(p.id);}
 return {valid:seen.size,remaining:roster.length-seen.size};
}
module.exports={validatePlan,checkCache};

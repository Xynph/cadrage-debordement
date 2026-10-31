'use strict';
const fs=require('node:fs');
const EXPECTED={top14:{clubs:14,rounds:26,games:182,perRound:7},prod2:{clubs:16,rounds:30,games:240,perRound:8}};
function inspect(dataset,{requireComplete=false}={}){
 const errors=[],counts={top14:0,prod2:0},rounds={top14:{},prod2:{}},teams={top14:new Set(),prod2:new Set()},ids=new Set(),pairs={top14:new Map(),prod2:new Map()};
 if(!dataset||!Array.isArray(dataset.fixtures))return {ok:false,errors:['fixtures array required']};
 if(dataset.careerStart!=='2026-07-01')errors.push('Career must start 2026-07-01');
 for(const x of dataset.fixtures){
  if(!x||!Object.hasOwn(EXPECTED,x.competition)){errors.push('Unknown competition');continue}
  const e=EXPECTED[x.competition];
  if(!Number.isInteger(x.round)||x.round<1||x.round>e.rounds)errors.push('Invalid round');
  if(!x.id||ids.has(x.id))errors.push('Duplicate/missing fixture ID');ids.add(x.id);
  if(typeof x.home!=='string'||typeof x.away!=='string'||!x.home||!x.away||x.home===x.away)errors.push('Invalid pairing');
  if(!/^202[67]-\d\d-\d\d$/.test(x.windowStart||'')||!/^202[67]-\d\d-\d\d$/.test(x.windowEnd||'')||x.windowStart>x.windowEnd)errors.push('Invalid official window');
  if(x.kickoff!==null&&x.kickoff!==undefined&&!/^\d{4}-\d\d-\d\dT\d\d:\d\d:00[+-]\d\d:\d\d$/.test(x.kickoff))errors.push('Kickoff needs verified timezone');
  if(x.score!==null)errors.push('Real-world result must never initialize simulation');
  if(!x.sourceUrl||!x.sourceUrl.startsWith('https://assets.lnr.fr/'))errors.push('Missing primary source PDF');
  counts[x.competition]++;rounds[x.competition][x.round]=(rounds[x.competition][x.round]||0)+1;
  teams[x.competition].add(x.home);teams[x.competition].add(x.away);
  const directed=x.home+'|'+x.away;pairs[x.competition].set(directed,(pairs[x.competition].get(directed)||0)+1);
 }
 for(const [k,e] of Object.entries(EXPECTED)){
  for(const [round,n] of Object.entries(rounds[k]))if(n>e.perRound)errors.push(k+' round '+round+' exceeds '+e.perRound);
  if(requireComplete){
   if(counts[k]!==e.games)errors.push(k+' incomplete '+counts[k]+'/'+e.games);
   if(teams[k].size!==e.clubs)errors.push(k+' club count '+teams[k].size);
   for(let i=1;i<=e.rounds;i++)if(rounds[k][i]!==e.perRound)errors.push(k+' round '+i+' incomplete');
   for(const n of pairs[k].values())if(n!==1)errors.push(k+' repeated directed fixture');
   if(pairs[k].size!==e.games)errors.push(k+' incomplete ordered pairs');
  }
 }
 return {ok:errors.length===0,complete:counts.top14===182&&counts.prod2===240,counts,errors}
}
if(require.main===module){
 const target=process.argv[2];if(!target){console.error('Usage: node tools/calendrier01-validate.cjs file.json [--complete]');process.exit(2)}
 const result=inspect(JSON.parse(fs.readFileSync(target,'utf8')),{requireComplete:process.argv.includes('--complete')});
 console.log(JSON.stringify(result,null,2));if(!result.ok)process.exitCode=1;
}
module.exports={inspect,EXPECTED};

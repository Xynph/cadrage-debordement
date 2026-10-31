'use strict';
const assert=require('node:assert/strict');
const ai=require('../dist/club-ai.js'),rep=require('../dist/reputation.js'),coach=require('../dist/coach-market.js'),fac=require('../dist/facilities.js'),world=require('../dist/rugby-world.js'),bridge=require('../dist/world-finance.js');
const seeds=Array.from({length:40},(_,i)=>997+i*7001),strengths=[.15,.25,1],profiles=[false,true];
const base={coachRisk:coach.dismissalRisk,facility:fac.investment,recruitment:ai.decideClub,world:world.awards};
function fixture(uneven){return Array.from({length:14},(_,i)=>({id:'c'+i,cash:uneven?(i<4?500000:i<10?110000:-45000):160000,debt:uneven&&i>=10?65000:0,reputation:uneven?40+i*3:60,wageRoom:15000,facilities:3,coachConfidence:60}));}
const round=x=>Math.round(x*10000)/10000;
const results=[];
for(const uneven of profiles)for(const strength of strengths){
 const adapt={...base,reputation:p=>{const r=rep.update(p);return {...r,next:Math.max(0,Math.min(100,p.current+(r.next-p.current)*strength))}}};
 let champions=0,dominant=0,deficit=0,restricted=0,paid=0,facilityEvents=0,coachEvents=0,coachFlags=0,recruitmentDecisions=0,transfers=0,saves=0;
 const years=Array.from({length:15},(_,i)=>({season:i+1,deficits:0,restrictions:0,invested:0,coachChanges:0}));
 for(const seed of seeds){
  const clubs=fixture(uneven),original=JSON.stringify(clubs),options={clubs,seed,seasons:15,adapters:adapt},r=bridge.simulate(options),titles=new Map();
  assert.equal(JSON.stringify(clubs),original,'entrees modifiees');
  assert.equal(r.history.length,15);
  for(let index=0;index<15;index++){
   const year=r.history[index],ids=new Set(),ranks=new Set();
   assert.equal(year.standings.length,14);
   titles.set(year.champion,(titles.get(year.champion)||0)+1);
   for(const row of year.standings){
    assert.ok(!ids.has(row.clubId)&&!ranks.has(row.finish));ids.add(row.clubId);ranks.add(row.finish);
    assert.ok(Number.isFinite(row.cash)&&Number.isFinite(row.debt)&&row.debt>=0);
    assert.ok(Number.isFinite(row.investmentPaid)&&row.investmentPaid>=0);
    assert.ok(Number.isFinite(row.investmentDeferred)&&row.investmentDeferred>=0);
    assert.ok(row.reputation>=0&&row.reputation<=100&&row.facilities>=1&&row.facilities<=10);
    assert.ok(row.investmentPaid===0||row.restriction==='normal','investissement sous restriction');
    deficit+=Number(row.cash<0);restricted+=Number(row.restriction!=='normal');paid+=row.investmentPaid;
    years[index].deficits+=Number(row.cash<0);years[index].restrictions+=Number(row.restriction!=='normal');years[index].invested+=row.investmentPaid;
    recruitmentDecisions+=Number(typeof row.recruitmentDecision==='string');
    coachFlags+=Number(row.coachChanged===true);
   }
   assert.equal(year.standings.find(x=>x.finish===1).clubId,year.champion);
  }
  dominant+=Math.max(...titles.values())/15;champions+=titles.size;
  for(const event of r.events){assert.ok(event.season>=1&&event.season<=15);if(event.type==='facility')facilityEvents++;if(event.type==='coachChange'){coachEvents++;years[event.season-1].coachChanges++;}}
  assert.equal(r.history.reduce((n,y)=>n+y.standings.filter(x=>x.investmentPaid>0).length,0),r.events.filter(e=>e.type==='facility').length);
  assert.equal(r.history.reduce((n,y)=>n+y.standings.filter(x=>x.coachChanged===true).length,0),r.events.filter(e=>e.type==='coachChange').length);
  // Le simulateur V51 ne signe aucun transfert. Mesurer l'absence plutot que revendiquer des recrutements reels.
  transfers+=r.events.filter(e=>e.type==='transferSigned').length;
  const checkpoint=bridge.simulate({...options,seasons:8}).checkpoint;
  const resumed=bridge.simulate({...options,checkpoint});
  assert.deepEqual(resumed.history,r.history);assert.deepEqual(resumed.events,r.events);assert.deepEqual(resumed.clubs,r.clubs);saves++;
 }
 assert.equal(transfers,0,'les transferts reels ne sont pas fournis dans V51');
 assert.equal(coachEvents,coachFlags,'changements coach et flags incompatibles');
 assert.ok(recruitmentDecisions===40*15*14,'decisions recrutement absentes');
 results.push({strength,uneven,careerSeeds:40,seasons:600,dominantTitleShare:round(dominant/40),uniqueChampions:round(champions/40),deficitRate:round(deficit/(40*15*14)),restrictionRate:round(restricted/(40*15*14)),investmentTotal:paid,facilityEvents,coachChanges:coachEvents,recruitmentDecisions,confirmedTransfers:transfers,checkpointReplays:saves,years});
}
assert.equal(results.length,6);
const report={schemaVersion:1,note:'Laboratoire fictif: decisions recrutement non synonymes de signatures; coachChange non synonyme de licenciement reel',results};
if(process.env.CD_V53_REPORT)require('node:fs').writeFileSync(process.env.CD_V53_REPORT,JSON.stringify(report,null,2)+'\n');
console.log('V53 AUDIT OK '+JSON.stringify(results.map(({years,...rest})=>rest)));

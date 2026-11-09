'use strict';

const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const repo=path.resolve(__dirname,'..');
const {test}=require('node:test');
const engine=path.join(repo,'native','engine'),dist=path.join(repo,'dist');
const {context}=require(path.join(repo,'tests','france-harness.cjs'));
const quota=require(path.join(engine,'japan-quota-runtime.cjs')).factory;
const eligibility=require(path.join(engine,'japan-eligibility.cjs')).factory;
function verify(carence){
const h=context(827381,{source:name=>fs.readFileSync(path.join(dist,name),'utf8')});
h.ctx.forceCarence=carence;
h.run('start(0)');
h.run(`const l=createRugbyMatch(nextMatch());S.live=l;l.worldContext={competitionId:'jlo-d1',phase:'league'};
const side=l.userSide,sh=l.sheets[side],redSlot=0,yellowSlot=1;
const red=sh.on[redSlot],yellow=sh.on[yellowSlot];
const find=(slot,exclude)=>sh.bench.find(p=>p&&p!==exclude&&slotEligible(matchPlayer(l,side,p),slot));
const redCover=find(redSlot),yellowCover=find(yellowSlot,redCover);
if(!redCover||!yellowCover)throw Error('Banc de première ligne incomplet dans la fixture');
const redDonor=sh.on[4],yellowDonor=sh.on[5];
const categories={};
const set=(id,category)=>categories[id]={category,basis:'estimated'};
const a1Slots=[redSlot,5,...sh.on.map((_,i)=>i).filter(i=>![redSlot,yellowSlot,4,5].includes(i))].slice(0,8);
sh.on.forEach((id,i)=>set(id,a1Slots.includes(i)?'A-1':'A-2'));
sh.bench.forEach(id=>set(id,id===redCover?'A-2':'A-1'));
l.sheets[1-side].nominated.forEach(id=>set(id,'A-1'));
S.worldMode={version:3,leagues:{'jlo-d1':{members:l.pair},'jlo-d2':{members:[]}}};
const CDWorldCareer={edition(s){return s.worldMode?.version===3?{version:3,registry:{japanCategories:categories}}:null;},sourcePlayer(){return null;}};
const CDWorldJapanQuota=(${quota.toString()})((${eligibility.toString()})());
CDWorldJapanQuota.installHooks();
const field=()=>{const ids=activePlayers(l,side).map(p=>p.id);return {a1:ids.filter(id=>categories[id].category==='A-1').length,
 others:ids.filter(id=>categories[id].category!=='A-1').length,carence:sh.front.uncontested};};
const report={initial:field()};CDWorldJapanQuota.validate(S);
const originalFit=fitScore,flow=advanceFlowPlay;
fitScore=(p,...args)=>p.id===redDonor?-3000:p.id===yellowDonor?-2000:p.id===redCover||p.id===yellowCover?3000:originalFit(p,...args);
if(forceCarence)for(const id of sh.bench){const p=matchPlayer(l,side,id);if(p&&slotEligible(p,redSlot))p.injury=1;}
l.minute=1;report.red=giveMatchCard(l,side,red,'red20');prepareFrontRows(l);report.afterRed=field();
l.minute=15;report.yellow=giveMatchCard(l,side,yellow,'yellow');prepareFrontRows(l);report.afterYellow=field();
fitScore=(p,...args)=>p.id===redDonor?4000:originalFit(p,...args);
l.minute=21;restoreRedReplacements(l,side);report.beforeYellowReturn=field();CDWorldJapanQuota.validate(S);
fitScore=originalFit;advanceFlowPlay=()=>{};l.minute=24;
try{advanceRugby(l)}finally{advanceFlowPlay=flow}
report.afterYellowReturn=field();report.minute=l.minute;
report.redFilled=sh.redCards[0].filled;report.yellowReturned=sh.on.includes(yellow);
report.coverAndReturn=l.subs.filter(m=>['frontcover','frontreturn','frontrelease','red20'].includes(m.reason)).map(m=>m.reason);
try{CDWorldJapanQuota.validate(S)}catch(e){report.error=e.message;}
`);
const report=JSON.parse(h.run('JSON.stringify(report)'));
assert.equal(report.red,true);
assert.equal(report.yellow,true);
assert.equal(report.minute,25);
if (carence) {
  assert.equal(report.afterRed.carence,true);
  assert.equal(report.yellowReturned,true);
  assert.equal(report.error,undefined,JSON.stringify(report));
}
else assert.deepEqual(report.afterYellowReturn,{a1:8,others:7,carence:false});
assert.equal(report.error,undefined,JSON.stringify(report));
return report;
}
test('Retour de jaune et rouge temporisés en première ligne sans dépasser les quotas',()=>verify(false));
test('Retour du jaune après carence en première ligne valide au chargement',()=>verify(true));

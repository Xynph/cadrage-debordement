'use strict';

const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const repo=path.resolve(__dirname,'..');
const {test}=require('node:test');
const engine=path.join(repo,'native','engine'),dist=path.join(repo,'dist');
const {context}=require(path.join(repo,'tests','monde-harness.cjs'));
const quota=require(path.join(engine,'japan-quota-runtime.cjs')).factory;
const eligibility=require(path.join(engine,'japan-eligibility.cjs')).factory;
// Une seule carrière Monde (club de League One, semaine de son premier match) ; chaque cas en repart.
let shared=null,base=null;
require('node:test').after(()=>shared?.close());
function verify(carence){
if(!shared){shared=context(827381,{club:68}).toMatch();base=shared.checkpoint();}
const h=shared.restore(base);
h.ctx.forceCarence=carence;
h.run(`// Carrière Monde réelle d'un club de League One (68) : catégories japonaises de l'édition, quota natif.
var l=createRugbyMatch(nextMatch());S.live=l;l.worldContext={competitionId:'jlo-d1',phase:'league'};
var side=l.userSide,sh=l.sheets[side],redSlot=0,yellowSlot=1;
var red=sh.on[redSlot],yellow=sh.on[yellowSlot];
var find=(slot,exclude)=>sh.bench.find(p=>p&&p!==exclude&&slotEligible(matchPlayer(l,side,p),slot));
var redCover=find(redSlot),yellowCover=find(yellowSlot,redCover);
if(!redCover||!yellowCover)throw Error('Banc de première ligne incomplet dans la fixture');
var redDonor=sh.on[4],yellowDonor=sh.on[5];
var categories=CDWorldCareer.edition(S).registry.japanCategories;
var set=(id,category)=>categories[id]={category,basis:'estimated'};
var a1Slots=[redSlot,5,...sh.on.map((_,i)=>i).filter(i=>![redSlot,yellowSlot,4,5].includes(i))].slice(0,8);
sh.on.forEach((id,i)=>set(id,a1Slots.includes(i)?'A-1':'A-2'));
sh.bench.forEach(id=>set(id,id===redCover?'A-2':'A-1'));
l.sheets[1-side].nominated.forEach(id=>set(id,'A-1'));
var field=()=>{const ids=activePlayers(l,side).map(p=>p.id);return {a1:ids.filter(id=>categories[id].category==='A-1').length,
 others:ids.filter(id=>categories[id].category!=='A-1').length,carence:sh.front.uncontested};};
var report={initial:field()};CDWorldJapanQuota.validate(S);
var originalFit=fitScore,flow=advanceFlowPlay;
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

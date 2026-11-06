'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const A=require('../ci/economy-v2-e32-adapter.cjs'),P=require('../ci/economy-v2-e30-playability.cjs');
const clubs=Array.from({length:14},(_,id)=>({id,name:'Club '+id,cash:1000+id,debt:20+id,
 wageWeekly:30,expiring:1,contractTermsObserved:12,missingEnd:0,planning29Weeks:870,
 bookedPayable:null}));
const native={source:'native-game-actual',version:'e24',profile:'reference',seed:827381,
 series:Array.from({length:15},(_,i)=>({season:i+1,clubs:structuredClone(clubs)}))};
const initial={clubs:clubs.map(c=>({id:c.id,facilities:5,reputation:42}))};
const sim=P.compare({openingCash:70,income:[25,25,25,25,25,25],
 required:[20,20,20,20,20,20],optional:[70,25,20,0,0,0],targetReserve:35});
const advisory={stage:'E3.1',profile:'reference',seed:827381,
 observation:{source:'native-E2.9-read-only',seasons:15,saveParity:true,pressure:1,recovery:1},
 cases:{optionalInvestmentOverreach:sim}};
test('E3.2 14 clubs times 15 seasons of native facts and preserved unknowns',()=>{
 const r=A.adapt(native,initial);
 assert.equal(r.clubs.length,14);
 assert.equal(r.clubs.reduce((n,c)=>n+c.years.length,0),210);
 assert.equal(r.clubs[0].initialFacilities,5);
 assert.equal(r.clubs[0].years[0].wageWeekly,30);
 assert.equal(r.clubs[0].years[0].duePayable,null);
 assert.equal(r.clubs[0].years[0].optionalProjectCost,null);
 assert.equal(r.unknown.futureConfirmedRevenue,null);
 assert.equal(r.readsOnly,true);assert.equal(r.gameplayChanged,false);
});
test('E3.2 fail closed rather than mislabel due amounts as known',()=>{
 const corrupted=structuredClone(native);corrupted.series[0].clubs[0].bookedPayable=0;
 assert.throws(()=>A.adapt(corrupted,initial),/Unknown payable/);
 const corruptFacility=structuredClone(initial);corruptFacility.clubs[0].facilities=99;
 assert.throws(()=>A.adapt(native,corruptFacility));
});
test('E3.2 source strictness and no mutation',()=>{
 const before=JSON.stringify({native,initial});
 assert.throws(()=>A.adapt({...native,source:'synthetic'},initial));
 A.adapt(native,initial);assert.equal(JSON.stringify({native,initial}),before);
});
test('E3.2 HTML native selection and E3.1 synthetic decisions remain distinct',()=>{
 const html=A.render(A.adapt(native,initial),advisory);
 for(const marker of ['id="e32-native"','id="nativeClub"','id="nativeRows"',
  'id="nativeDebt"','id="nativeFacilities"','id="choices"','Scénarios entièrement synthétiques',
  'Non disponibles','factures exigibles datées'])assert.ok(html.includes(marker),marker);
 assert.ok(!html.includes('<script src='));
 assert.ok(!html.includes('localStorage'));
 assert.ok(!html.includes('fetch('));
});
test('E3.2 JSON protection from HTML injection in native club names',()=>{
 const dirty=structuredClone(native);
 dirty.series[0].clubs[0].name='</script><script>alert(9)</script>';
 const html=A.render(A.adapt(dirty,initial),advisory);
 assert.ok(!html.includes('</script><script>alert(9)</script>'));
});

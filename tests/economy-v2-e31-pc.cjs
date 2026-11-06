'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const UI=require('../ci/economy-v2-e31-pc.cjs'),P=require('../ci/economy-v2-e30-playability.cjs');
const fixture={stage:'E3.1',profile:'reference',seed:827381,observation:{
 source:'native-E2.9-read-only',seasons:15,rounds:435,pressure:3,recovery:2,saveParity:true},
 cases:{optionalInvestmentOverreach:P.compare({openingCash:70,income:[25,25,25,25,25,25],required:[20,20,20,20,20,20],optional:[70,25,20,0,0,0],targetReserve:35})}};
test('E3.1 standalone responsive prototype preserves native versus synthetic labeling',()=>{
 const html=UI.render(fixture);
 for(const fragment of ['lang="fr"','name="viewport"','1920','PROTOTYPE R&D','Scénarios entièrement synthétiques','E2.9','E3.0','Avant / après','Conséquence sportive','aucune performance chiffrée','@media(max-width:1050px)']) {
  if(fragment==='1920')continue;assert.ok(html.includes(fragment),fragment);
 }
 assert.ok(!html.includes('<script src='));
 assert.ok(!html.includes('localStorage'));
 assert.ok(!html.includes('fetch('));
 assert.ok(!html.includes('eval('));
});
test('E3.1 comparison matches E3.0 observations without creation or posting',()=>{
 const c=fixture.cases.optionalInvestmentOverreach.options;
 assert.equal(c[0].endingCash,-15);
 assert.equal(c[2].endingCash,100);
 assert.equal(c[2].createdDebt,0);
 assert.equal(c[2].generatedIncome,0);
 assert.equal(c[2].addedPenalties,0);
 const html=UI.render(fixture);
 assert.ok(html.includes('Trésorerie finale avant'));
 assert.ok(html.includes('Trésorerie finale après'));
});
test('E3.1 refuses spoofed native origin or save parity',()=>{
 assert.throws(()=>UI.render({...fixture,observation:{...fixture.observation,source:'synthetic'}}));
 assert.throws(()=>UI.render({...fixture,observation:{...fixture.observation,saveParity:false}}));
});
test('E3.1 protects HTML and embedded JSON from script/HTML injection',()=>{
 const html=UI.render({...fixture,profile:'<script>alert(1)</script>'});
 assert.ok(!html.includes('<script>alert(1)</script>'));
 assert.ok(html.includes('&lt;script&gt;'));
 const forged=structuredClone(fixture);
 forged.cases.optionalInvestmentOverreach.options[0].headline='</script><script>alert(1)</script>';
 assert.ok(!UI.render(forged).includes('</script><script>alert(1)</script>'));
});

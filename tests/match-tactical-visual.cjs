'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const {tacticalVisualSummary,tacticalVisualHtml}=require('../dist/match-tactical-visual.js');
const scene={kind:'carry',possession:0,ball:{x:50,y:35},event:{scene:{kind:'carry'}},players:[
 {id:'a',side:0,x:50,y:35},{id:'b',side:0,x:58,y:35},{id:'c',side:0,x:60,y:60},
 {id:'d',side:1,x:52,y:34},{id:'e',side:1,x:80,y:10}
]};
test('native geometry creates reproducible pressure and lane observations',()=>{
 const before=JSON.stringify(scene),v=tacticalVisualSummary(scene);
 assert.equal(v.attackNear,2);assert.equal(v.defenceNear,1);assert.equal(v.attackCount,3);
 assert.equal(v.defenceCount,2);assert.equal(v.pressure,'Soutien offensif');assert.equal(typeof v.longitudinalGap,'number');assert.equal(v.wings.length,3);assert.equal(v.hasActualEvent,true);
 assert.equal(JSON.stringify(scene),before);assert.deepEqual(tacticalVisualSummary(scene),v);
});
test('legacy match without geometry stays safe and read-only',()=>{
 const v=tacticalVisualSummary({possession:1,players:[],ball:{},kind:'message'});
 assert.equal(v.attackNear,0);assert.equal(v.attackLine,null);assert.equal(v.longitudinalGap,null);assert.equal(v.hasActualEvent,false);
 assert.match(tacticalVisualHtml({players:[]}),/Aucune géométrie historique/);
});
test('presentation escapes labels and does not require a mutable career',()=>{
 const html=tacticalVisualHtml(scene);
 assert.match(html,/Espaces et soutiens/);assert.match(html,/Action native synchronisée/);
 assert.match(html,/Aucune décision tactique ni sauvegarde modifiée/);
});

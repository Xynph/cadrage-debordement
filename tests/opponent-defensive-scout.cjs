'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');
const source=fs.readFileSync(path.join(__dirname,'../dist/rugby.js'),'utf8');
const block=source.slice(source.indexOf('function opponentDefensiveScout('),source.indexOf('function aiSubs(',source.indexOf('function opponentDefensiveScout(')));
assert.ok(block.startsWith('function opponentDefensiveScout('),'native implementation must exist');
const events=[],players=Array.from({length:15},()=>({condition:90}));
const ctx={tacticalRules:l=>l.tacticalVersion===1,matchMinute:l=>l.minute,activePlayers:()=>players,
 mean:a=>a.reduce((s,v)=>s+v,0)/(a.length||1),addEvent:(...x)=>events.push(x),
 S:{clubs:[{abbr:'ABC'},{abbr:'DEF'}]},DEFENCES:{pression:['Montée agressive'],prudente:['Glissée prudente'],equilibre:['Équilibrée']}};
vm.runInNewContext(block+';this.scout=opponentDefensiveScout',ctx);
const scout=ctx.scout;
function state(extra={}){return {tacticalVersion:1,userSide:0,minute:30,pair:[0,1],defences:['equilibre','equilibre'],
 stats:[{penalties:0},{penalties:1}],tacticalStats:[{carries:10,advances:8},{carries:8,advances:3}],...extra}}
test('detects sustained opposing gains using native counts',()=>{const l=state();assert.equal(scout(l,1),true);assert.equal(l.defences[1],'pression');assert.equal(events.at(-1)[3].team,1)});
test('backs away from pressure after penalties',()=>{const l=state({defences:['equilibre','pression'],stats:[{}, {penalties:6}]});assert.equal(scout(l,1),true);assert.equal(l.defences[1],'prudente')});
test('preserves prior saves and never chooses for player',()=>{const l=state({tacticalVersion:0});const before=JSON.stringify(l);assert.equal(scout(l,1),false);assert.equal(JSON.stringify(l),before);assert.equal(scout(state(),0),false)});
test('non-interval frames are read-only',()=>{const l=state({minute:31});const before=JSON.stringify(l);assert.equal(scout(l,1),false);assert.equal(JSON.stringify(l),before)});
test('300 varied inputs, no unbounded choices',()=>{for(let i=0;i<300;i++){const l=state({minute:i%81,tacticalStats:[{carries:8+i%13,advances:i%9},{carries:10,advances:3}]});scout(l,1);assert.ok(['equilibre','pression','prudente'].includes(l.defences[1]));}});

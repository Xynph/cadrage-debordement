import test from 'node:test';
import assert from 'node:assert/strict';
import {expandRankings} from './pagination.mjs';
const page=({changes=true,buttons=1}={})=>{let n=0;return {locator:()=>({innerText:async()=>changes?String(n):'unchanged'}),getByText:()=>({count:async()=>buttons,nth:()=>({click:async()=>{n++}})}),waitForTimeout:async()=>{}}};
test('stops after progress stall',async()=>{const r=await expandRankings(page({changes:false}),{rounds:30,delay:0});assert.equal(r.complete,true);assert.equal(r.history.length,1);});
test('bounded active pagination reports incomplete',async()=>{const r=await expandRankings(page(),{rounds:3,delay:0});assert.equal(r.complete,false);assert.equal(r.history.length,3);});
test('no more button is complete',async()=>{const r=await expandRankings(page({buttons:0}),{rounds:10,delay:0});assert.equal(r.complete,true);});
test('unbounded rounds rejected',async()=>{await assert.rejects(expandRankings(page(),{rounds:101}),/Invalid/);});

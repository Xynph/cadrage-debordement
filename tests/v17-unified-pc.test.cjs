'use strict';
const test=require('node:test');const assert=require('node:assert/strict');const engine=require('../dist/v17-v10-engine.js');const unified=require('../dist/v17-unified-pc.js');
const data={players:[{id:'a',name:'<script>',condition:90,age:22,injury:0,fatigue:10,dev:{minutes:110}}],fixtures:[],matches:[]};
test('huit sections unifiees',()=>assert.equal(unified.PANELS.length,8));
test('lecture des donnees natives sans mutation',()=>{const before=JSON.stringify(data);const ui=unified.create({snapshot:()=>data,engine});const x=ui.snapshot();assert.equal(x.analysis.readonly,true);assert.equal(JSON.stringify(data),before)});
test('echappement du nom de joueur',()=>{const ui=unified.create({snapshot:()=>data,engine});assert.equal(ui.render().includes('<script>'),false);assert.equal(ui.render().includes('&lt;script&gt;'),true)});
test('erreur explicite sans connecteur natif',()=>assert.throws(()=>unified.create({engine}),/snapshot/));
test('preferences limitees aux panneaux connus',()=>{const ui=unified.create({snapshot:()=>data,engine});ui.setPreferences({enabled:['staff','untrusted'],density:'comfortable'});assert.deepEqual(ui.getPreferences(),{enabled:['staff'],density:'comfortable'})});
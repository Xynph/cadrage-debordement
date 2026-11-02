#!/usr/bin/env node
'use strict';
const assert=require('node:assert/strict');
const fs=require('node:fs'),os=require('node:os'),path=require('node:path'),cp=require('node:child_process');
const dir=fs.mkdtempSync(path.join(os.tmpdir(),'rugby-estimate-'));
try{
const base={schema:'rugby-master-sports-v6',players:[{id:'A',club:'toulouse',league:'top14',rating:65,potential:75,attributesV2:{passing:60},ratingKind:'estimated'}],rugbyDataObservations:[{observationKey:'unique',value:3}]};
const layer={schema:'rugby-v6-estimated-overrides-v1',model:'test',sourceBlob:'test',summary:{players:1},players:[{id:'A',club:'toulouse',league:'top14',rating:67,potential:78,ratingKind:'estimated',potentialKind:'estimated',model:'test',attributesV2:{passing:61},evidence:{individualMinutes2025_26:null,individualMinutes2024_25:null,individualMatches2025_26:null,teamTry2025_26:100}}]};
const a=path.join(dir,'a.json'),b=path.join(dir,'b.json'),out=path.join(dir,'out.json');
fs.writeFileSync(a,JSON.stringify(base));fs.writeFileSync(b,JSON.stringify(layer));
const app=path.join(__dirname,'apply.cjs');
assert.equal(cp.spawnSync(process.execPath,[app,a,b,out],{encoding:'utf8'}).status,0);
const data=JSON.parse(fs.readFileSync(out,'utf8'));
assert.equal(data.players[0].rating,67);
assert.equal(data.players[0].potential,78);
assert.equal(data.players[0].attributesV2.passing,61);
assert.deepEqual(data.rugbyDataObservations,base.rugbyDataObservations);
assert.equal(JSON.parse(fs.readFileSync(a,'utf8')).players[0].rating,65);
layer.players[0].club='other';fs.writeFileSync(b,JSON.stringify(layer));
assert.notEqual(cp.spawnSync(process.execPath,[app,a,b,out],{encoding:'utf8'}).status,0);
console.log('PASS: application, potential, attributes, observation preservation, original untouched, invalid identity rejected');
}finally{fs.rmSync(dir,{recursive:true,force:true});}

'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'..');
const batch=JSON.parse(fs.readFileSync(path.join(root,'modding/data06/itsrugby-clermont-verified-physical.json'),'utf8'));
const roster=JSON.parse(fs.readFileSync(path.join(root,'modding/data03/top14-a.json'),'utf8')).clubs.find(c=>c.club==='clermont').players;
const normalize=s=>String(s).normalize('NFKD').replace(/[\u0300-\u036f]/g,'').replace(/[^a-z0-9]/gi,'').toLowerCase();
test('nine physically sourced observations strictly link to Clermont LNR IDs',()=>{
 assert.equal(batch.players.length,9);
 assert.equal(new Set(batch.players.map(p=>p.id)).size,9);
 for(const player of batch.players){
   const target=roster.find(r=>r.id===player.id);
   assert.ok(target,'unmatched LNR id '+player.id);
   assert.equal(normalize(target.name),normalize(player.name),'mismatched identity for '+player.id);
   assert.ok(Number.isInteger(player.heightCm)&&player.heightCm>=140&&player.heightCm<=230);
   assert.ok(Number.isInteger(player.weightKg)&&player.weightKg>=55&&player.weightKg<=200);
 }
});
test('provenance and snapshot remain explicit',()=>{
 assert.match(batch.source,/^https:\/\/itsrugby\.fr\/equipes\/clermont\//);
 assert.equal(batch.historicalAsOfJuly1Verified,false);
 assert.equal(batch.season,'2026-27');
 assert.ok(batch.observedAt);
});

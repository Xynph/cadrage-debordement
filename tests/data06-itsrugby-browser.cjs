'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const bulk=require('../tools/data06-itsrugby-bulk.cjs');
const capture=players=>({season:'2026-27',historicalJuly2026:false,clubs:[{slug:'clermont',lnrClub:'clermont',sourceUrl:'https://itsrugby.fr/equipes/clermont/?saison=2026-27#sec-effectif',capturedAt:'2026-10-31',players}]});
const player=(name,id,extra={})=>({name,sourceRecordId:id,position:'Talonneur',heightCm:180,weightKg:103,ageAsPublished:22,dateOfBirth:null,nationality:null,...extra});
test('only exact unique names and mapped clubs can produce supplemental LNR observations',()=>{
 assert.equal(typeof bulk.reconcileBrowserCapture,'function');
 const c=capture([player('Barnabé Massa','53641'),player('Thibault Lanen','44997'),player('Unknown Player','99999')]);
 const roster=[{id:'lnr:862',name:'Barnabé MASSA',club:'clermont'},{id:'lnr:711',name:'Thibaud LANEN',club:'clermont'}];
 const before=JSON.stringify([c,roster]);const r=bulk.reconcileBrowserCapture(c,roster,[]);
 assert.deepEqual(r.players.map(p=>p.id),['lnr:862']);assert.equal(r.review.length,2);
 assert.deepEqual(r.remainingIds,['lnr:711']);assert.equal(JSON.stringify([c,roster]),before);
 assert.equal(r.players[0].validAtCareerStart,null);assert.equal(r.players[0].dateOfBirth,null);
});
test('homonyms, repeated source IDs, repeated target IDs and club mismatches stay in review',()=>{
 assert.equal(typeof bulk.reconcileBrowserCapture,'function');
 const roster=[{id:'lnr:1',name:'John Smith',club:'clermont'},{id:'lnr:2',name:'John Smith',club:'pau'},{id:'lnr:3',name:'Jack Doe',club:'clermont'}];
 const c=capture([player('John Smith','1'),player('Jack Doe','2'),player('Jack Doe','3')]);
 assert.equal(bulk.reconcileBrowserCapture(c,roster,[]).players.length,0);
 const d=capture([player('Jack Doe','2')]);d.clubs.push({...d.clubs[0],slug:'pau',lnrClub:'pau',sourceUrl:'https://itsrugby.fr/equipes/pau/?saison=2026-27'});
 assert.equal(bulk.reconcileBrowserCapture(d,roster,[]).players.length,0);
 const wrong=capture([player('John Smith','1')]);wrong.clubs[0].lnrClub='bayonne';wrong.clubs[0].slug='bayonne';wrong.clubs[0].sourceUrl='https://itsrugby.fr/equipes/bayonne/?saison=2026-27';roster.push({id:'lnr:4',name:'Other Player',club:'bayonne'});
 assert.equal(bulk.reconcileBrowserCapture(wrong,roster,[]).players.length,0);
});
test('previous profiles are preserved and conflicting fields do not silently replace them',()=>{
 assert.equal(typeof bulk.reconcileBrowserCapture,'function');
 const previous=[{id:'lnr:862',name:'Barnabé MASSA',heightCm:180,weightKg:101}];
 const before=JSON.stringify(previous);
 const r=bulk.reconcileBrowserCapture(capture([player('Barnabé Massa','53641')]),[{id:'lnr:862',name:'Barnabé MASSA',club:'clermont'}],previous);
 assert.equal(JSON.stringify(previous),before);assert.equal(r.summary.additionalProfiles,0);
 assert.equal(r.players[0].weightKg,null);assert.equal(r.conflicts[0].observed,103);
 assert.equal(r.players[0].heightCm,180);assert.equal(r.summary.totalCovered,1);
});
test('invalid period, units, identities and unknown clubs cannot enter the published supplement',()=>{
 assert.equal(typeof bulk.reconcileBrowserCapture,'function');
 const roster=[{id:'lnr:1',name:'Jack Doe',club:'clermont'}];
 for(const extra of [{weightKg:0},{heightCm:999},{dateOfBirth:'2000-01-01'},{nationality:'inferred'}])
  assert.throws(()=>bulk.reconcileBrowserCapture(capture([player('Jack Doe','1',extra)]),roster,[]));
 const c=capture([player('Jack Doe','1')]);c.season='2025-26';assert.throws(()=>bulk.reconcileBrowserCapture(c,roster,[]));
 c.season='2026-27';c.clubs[0].lnrClub='invented';assert.throws(()=>bulk.reconcileBrowserCapture(c,roster,[]));
});
test('HTTP 403 stops the batch and leaves an explicit unattempted tail',async()=>{
 const out=fs.mkdtempSync(path.join(os.tmpdir(),'data06-stop-'));let requests=0;
 try{const r=await bulk.collect({slugs:['clermont','brive','stade-toulousain'],out,paceMs:0,fetchFn:async()=>{requests++;return {ok:false,status:403}}});
 assert.equal(requests,1);assert.equal(r.results[0].status,403);assert.equal(r.results[1].attempted,false);assert.equal(r.stopped,true);
 }finally{fs.rmSync(out,{recursive:true,force:true})}
});
test('roster keywords alone are not a captured roster',async()=>{
 const out=fs.mkdtempSync(path.join(os.tmpdir(),'data06-shell-'));
 try{const r=await bulk.collect({slugs:['clermont'],out,fetchFn:async()=>({ok:true,status:200,text:async()=>'<html>'+'Effectif Joueurs '.repeat(100)+'</html>'})});assert.equal(r.results[0].ok,false)}
 finally{fs.rmSync(out,{recursive:true,force:true})}
});
test('30 real captures reproduce the supplement and preserve the 240 source profiles byte for byte',()=>{
 const root=path.resolve(__dirname,'..'),crypto=require('node:crypto');
 const c=require('../modding/data06/itsrugby-browser-capture-2026-10-31.json');
 const published=require('../modding/data06/itsrugby-browser-reconciliation-2026-10-31.json');
 const result=bulk.buildBrowserReport(root,c);
 assert.deepEqual(result,published);
 assert.deepEqual(result.summary,{target:1592,clubs:30,observedRows:1539,uniqueSourcePlayers:1506,rowsWithMeasurements:1431,matched:1174,matchedWithFields:1171,review:365,fieldConflicts:153,previousProfiles:240,additionalProfiles:974,totalCovered:1214,remaining:378});
 assert.equal(new Set(c.clubs.map(x=>x.lnrClub)).size,30);
 assert.equal(new Set(result.players.map(x=>x.id)).size,result.players.length);
 assert.equal(result.players.length+result.review.length,1539);
 for(const s of published.existingSources)assert.equal(crypto.createHash('sha256').update(fs.readFileSync(path.join(root,s.file))).digest('hex'),s.sha256);
 const all=c.clubs.flatMap(club=>club.players);
 assert.equal(all.find(p=>p.sourceRecordId==='50363').heightCm,null);
 assert.equal(all.find(p=>p.sourceRecordId==='50363').weightKg,107);
 assert.equal(all.find(p=>p.sourceRecordId==='60636').heightCm,null);
 for(const p of all){
  const raw=p.measurementsAsPublished;
  assert.equal(p.heightCm,raw?.match(/(\d+) cm/)?.[1]?Number(raw.match(/(\d+) cm/)[1]):null);
  assert.equal(p.weightKg,raw?.match(/(\d+) kg/)?.[1]?Number(raw.match(/(\d+) kg/)[1]):null);
  assert.equal(p.dateOfBirth,null);assert.equal(p.nationality,null);
 }
 for(const p of result.players){
  assert.equal(p.validAtCareerStart,null);
  if(p.position||p.heightCm!==null||p.weightKg!==null||p.ageAsPublished!==null)assert.ok(!result.remainingIds.includes(p.id));
  assert.equal(all.filter(s=>s.sourceRecordId===p.sourceRecordId).length,1);
  assert.equal(bulk.nameKey(p.sourceName),bulk.nameKey(p.name));
 }
});

'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const {context}=require('./france-harness.cjs');
const install=require('../native/engine/nationale-squad.cjs');

test('La feuille tactique incomplète est réparée avant un vrai coup d’envoi des éditions v4 et suivantes',()=>{
 const h=context(35280);
 const bt=String.fromCharCode(10);
 h.run([
  'start(0);',
  'var matchPair=nextMatch(); var opposition=S.clubs[matchPair.find(id=>id!==S.club)];',
  'var roster=JSON.stringify(opposition.players.map(p=>p.id));',
  'var ordinary=managerSheet(opposition,S.clubs[S.club],"Sec","classique");',
  'var omit=true;managerSheet=function(){return omit?{lineup:ordinary.lineup.slice(),bench:ordinary.bench.map((id,i)=>i===2?null:id)}:ordinary;};',
  'const CDWorldEditions={forState:s=>s.worldMode||null};',
  '('+install.toString()+')();',
  'S.worldMode={version:3};var historical=managerSheet(opposition,S.clubs[S.club],"Sec","classique");',
  'S.worldMode={version:4};var repaired=managerSheet(opposition,S.clubs[S.club],"Sec","classique");',
  'var match=createRugbyMatch(matchPair);var opposingSheet=match.sheets[1-match.userSide];',
  'omit=false;var unchanged=managerSheet(opposition,S.clubs[S.club],"Sec","classique");',
 ].join(bt));
 assert.equal(h.run('historical.bench[2]===null'),true);
 assert.equal(h.run('new Set([...repaired.lineup,...repaired.bench]).size===23 && repaired.bench.every(Boolean)'),true);
 assert.equal(h.run('opposingSheet.nominated.length===23 && opposingSheet.bench.every(Boolean)'),true);
 assert.equal(h.run('unchanged===ordinary'),true);
 assert.equal(h.run('roster===JSON.stringify(opposition.players.map(p=>p.id))'),true);
});

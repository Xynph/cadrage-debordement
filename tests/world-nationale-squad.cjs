'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const {context}=require('./monde-harness.cjs');
const install=require('../native/engine/nationale-squad.cjs');

test('La feuille tactique incomplète est réparée avant un vrai coup d’envoi de la carrière Monde',()=>{
 // Carrière world-champ réelle : CDWorldEditions est celui du moteur ; le crochet est réinstallé autour
 // d’une feuille tactique incomplète simulée.
 const h=context(35280).toMatch();
 const bt=String.fromCharCode(10);
 h.run([
  'var matchPair=nextMatch(); var opposition=S.clubs[matchPair.find(id=>id!==S.club)];',
  'var roster=JSON.stringify(opposition.players.map(p=>p.id));',
  'var ordinary=managerSheet(opposition,S.clubs[S.club],"Sec","classique");',
  'var omit=true;managerSheet=function(){return omit?{lineup:ordinary.lineup.slice(),bench:ordinary.bench.map((id,i)=>i===2?null:id)}:ordinary;};',
  '('+install.toString()+')();',
  'var repaired=managerSheet(opposition,S.clubs[S.club],"Sec","classique");',
  'var match=createRugbyMatch(matchPair);var opposingSheet=match.sheets[1-match.userSide];',
  'omit=false;var unchanged=managerSheet(opposition,S.clubs[S.club],"Sec","classique");',
 ].join(bt));
 assert.equal(h.run('new Set([...repaired.lineup,...repaired.bench]).size===23 && repaired.bench.every(Boolean)'),true);
 assert.equal(h.run('opposingSheet.nominated.length===23 && opposingSheet.bench.every(Boolean)'),true);
 assert.equal(h.run('unchanged===ordinary'),true);
 assert.equal(h.run('roster===JSON.stringify(opposition.players.map(p=>p.id))'),true);
});

'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const {analyze,stats,correlation,findPlayers}=require('../tools/rugby-real-attributes36-audit.cjs');
function players(n=1592){return Array.from({length:n},(_,i)=>({id:'p-'+i,position:i%2?'Pilier':'Ailier',league:i%3?'TOP 14':'PRO D2',potential:75,hiddenTraitsV2:Object.fromEntries(Array.from({length:6},(_,j)=>['t'+j,50])),attributesV2:Object.fromEntries(Array.from({length:36},(_,j)=>['a'+j,20+(i*7+j*3)%78]))}));}
test('repère les joueurs dans les structures imbriquées',()=>assert.equal(findPlayers({clubs:[{players:players(2)}]}).length,2));
test('statistiques et corrélations reproductibles',()=>{assert.equal(stats([1,2,3]).median,2);assert.equal(correlation([[1,2],[2,4],[3,6]]),1);});
test('audite 1592 joueurs, 36 attributs sans mutation',()=>{const input={players:players()};const before=JSON.stringify(input);const report=analyze(input);assert.equal(report.status,'schema-ok');assert.equal(report.playerCount,1592);assert.equal(report.attributeCount,36);assert.equal(JSON.stringify(input),before);});
test('détecte doublon et attribut manquant',()=>{const input={players:players()};input.players[1].id=input.players[0].id;delete input.players[2].attributesV2.a5;const report=analyze(input);assert.equal(report.status,'review-required');assert.equal(report.checks.duplicateIds,1);assert.ok(report.checks.missingValues>0);});

test('controle réellement les six traits cachés V2 et leur presence',()=>{const input={players:players()};delete input.players[0].hiddenTraitsV2;input.players[1].hiddenTraitsV2.t0=200;const report=analyze(input);assert.equal(report.status,'review-required');assert.equal(report.checks.missingHiddenTraits,1);assert.equal(report.checks.invalidHiddenTraits,1);});
test('distingue le poste gameplay estimé de l inconnu',()=>{const input={players:players()};for(const p of input.players){p.position='Inconnu';p.gameplayPosition='Ailier';p.gameplayPositionEstimated=true;}const report=analyze(input);assert.equal(report.checks.estimatedGameplayPositions,1592);assert.ok(Object.keys(report.groups).some(k=>k.includes('Ailier')));});

'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const {merge}=require('../modding/tools/rugby-incremental-import.cjs');
const person={id:'lnr:1',realName:'Jean ÉTÉ',club:'toulouse',league:'top14',rating:65,potential:80,skills:{pass:50},attributesV2:{passing:55}};
const initial=()=>({schema:'rugby-master-sports-v6',players:[structuredClone(person)],rugbyDataObservations:[]});
const observation=()=>({competition:'TOP 14',season:'2025-2026',phase:'Phase régulière',type:'Joueur',entityId:'lnr:1',indicator:'Essais marqués',unit:'Essais',value:3,scope:'Phase régulière',sourceUrl:'https://rugbydata.fr/statistics/panel/51'});
const batch=(observations=[],playerUpdates=[])=>({schema:'rugby-incremental-batch-v1',observations,playerUpdates});
test('import unique et second passage idempotent',()=>{
 const a=merge(initial(),batch([observation()]));
 assert.equal(a.report.inserted,1);
 assert.equal(a.db.rugbyDataObservations.length,1);
 const b=merge(a.db,batch([observation()]));
 assert.equal(b.report.inserted,0);assert.equal(b.report.unchanged,1);
 assert.deepEqual(b.db,a.db);
});
test('ne modifie pas les joueurs sans recalibrage',()=>{
 const base=initial();const a=merge(base,batch([observation()]));
 assert.deepEqual(a.db.players,base.players);assert.equal(base.rugbyDataObservations.length,0);
});
test('refuse une correction silencieuse de statistique',()=>{
 const a=merge(initial(),batch([observation()]));
 assert.throws(()=>merge(a.db,batch([{...observation(),value:9}])),/Correction/);
});
test('refuse les doublons dans un lot',()=>assert.throws(()=>merge(initial(),batch([observation(),observation()])),/répétée/));
test('refuse un joueur absent ou non vérifié',()=>assert.throws(()=>merge(initial(),batch([{...observation(),entityId:'lnr:404'}])),/non rapprochée/));
test('exige correspondance stricte identité en recalibrage',()=>{
 assert.throws(()=>merge(initial(),batch([],[{id:'lnr:1',club:'castres',rating:70,reason:'source'}])),/Club incohérent/);
 assert.throws(()=>merge(initial(),batch([],[{realName:'Jean ETE',club:'toulouse',league:'prod2',rating:70,reason:'source'}])),/absente ou ambiguë/);
});
test('recalibrage ciblé et borné',()=>{
 const a=merge(initial(),batch([],[{id:'lnr:1',realName:'Jean ETE',rating:67,attributesV2:{passing:60},reason:'Évaluation documentée'}]));
 assert.equal(a.report.playersChanged,1);assert.equal(a.db.players[0].rating,67);
 assert.equal(a.db.players[0].attributesV2.passing,60);assert.equal(a.db.players[0].skills.pass,50);
 assert.throws(()=>merge(initial(),batch([],[{id:'lnr:1',potential:21,reason:'test'}])),/Potentiel inférieur/);
});
test('préserve historique multi-saison et distingue les phases',()=>{
 const old=observation();
 const newer={...old,season:'2026-2027',value:7};
 const final=merge(initial(),batch([old,newer]));
 assert.equal(final.report.inserted,2);assert.equal(final.db.rugbyDataObservations.length,2);
});
test('refuse source non HTTPS et valeur inventée/non numérique',()=>{
 assert.throws(()=>merge(initial(),batch([{...observation(),sourceUrl:'http://example.org'}])),/HTTPS/);
 assert.throws(()=>merge(initial(),batch([{...observation(),value:null}])),/Valeur/);
});

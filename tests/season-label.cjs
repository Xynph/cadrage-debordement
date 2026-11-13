'use strict';
// Libellé de saison (décision de Léo du 13/11/2026) : le jeu commence à la pré-saison 2026-2027 ;
// il n'y a pas de « saison 1 » à l'écran. Le numéro interne `season` reste dans les données.
const assert=require('node:assert/strict');
const fs=require('node:fs');
const os=require('node:os');
const path=require('node:path');
const test=require('node:test');
const {libelleSaison,SEASON_START_YEAR}=require('../dist/season-label.js');
const {createBridge}=require('../native/engine/worker.cjs');

test('libelleSaison : saison interne 1 → 2026-2027, 2 → 2027-2028',()=>{
 assert.equal(SEASON_START_YEAR,2026);
 assert.equal(libelleSaison(1),'2026-2027');
 assert.equal(libelleSaison(2),'2027-2028');
 assert.equal(libelleSaison(5),'2030-2031');
 assert.equal(libelleSaison('3'),'2028-2029');
 for(const bad of [0,-1,1.5,null,undefined,'','x',NaN,Infinity])assert.equal(libelleSaison(bad),'—');
 assert.equal(globalThis.libelleSaison===undefined||globalThis.libelleSaison(1)==='2026-2027',true);
});

test('Monde : première journée de carrière, libellé exposé et aucun « Saison 1 » à l’écran',()=>{
 const root=fs.mkdtempSync(path.join(process.env.CD_WORLD_TEST_ROOT||os.tmpdir(),'cd-season-label-'));
 try{
  const bridge=createBridge({dataDir:root,seed:827381,now:1794178800000});
  let serial=0;
  const go=(command,payload={})=>{const r=bridge.handle({id:++serial,command,payload});assert.equal(r.ok,true,command+' : '+r.error);return r.model;};
  go('snapshot');
  const model=go('new_career',{mode:'world-champ',club:102});
  assert.equal(model.meta.season,1,'le numéro interne reste 1');
  assert.equal(model.meta.seasonStartYear,2026);
  assert.equal(model.meta.seasonLabel,'2026-2027');
  assert.match(model.meta.competitionRules,/^Saison 2026-2027/);
  assert.doesNotMatch(model.meta.competitionRules,/–/,'un seul tiret pour les saisons');
  // Date de départ : la carrière commence pendant la pré-saison 2026-2027 (été 2026), avant tout match.
  // La date exacte relève du chantier « reprise choisie » ; ici seul l'encadrement est vérifié.
  assert.match(model.meta.calendarToday,/^2026-0[78]-\d\d$/,'départ en juillet ou août 2026');
  const firstMatch=model.calendar.map(f=>f.date).sort()[0];
  assert.ok(firstMatch>model.meta.calendarToday,'aucun match avant le premier jour : '+firstMatch);
  const text=JSON.stringify(model);
  assert.doesNotMatch(text,/\b[Ss]aison [0-9]\b|\bSAISON [0-9]\b/,'aucun « Saison N » dans le modèle');
 }finally{fs.rmSync(root,{recursive:true,force:true});}
});

'use strict';
// Cartons réalistes (docs/cartons-realistes-20261118.md) : un Top 14 compte ~0,6 à 0,8 jaune par équipe et par match et un
// rouge (ou deuxième jaune) rare. Moyennes d'échantillon (graines fixes), jamais le résultat exact d'un match.
//  1. Affiches de Top 14 IA contre IA (vrais effectifs, calendrier du Monde) : la cible.
//  2. Match du joueur (carrière Monde, deux clubs de deuxième division très fautifs, ~12 pénalités chacun), rejoué depuis le
//     coup d'envoi : plus de fautes, donc plus de cartons, mais ni avalanche ni rouge fréquent.
const assert = require('node:assert/strict');
const { context } = require('./monde-harness.cjs');
const { ouvrir, creer, jusquAuMatch } = require('./helpers/carriere-monde.cjs');

// 1. Top 14. `reds` : une exclusion définitive figure à la fois dans `sentOff` et dans `redCards`, comptée une fois ici.
const h = context(20261118);
try {
  h.start(102);
  const top14 = JSON.parse(h.run(`(()=>{const fx=S.worldMode.fixtures.filter(f=>f.competitionId==='elite'&&f.phase==='league');
    let x=4242;const alea=()=>{x=(Math.imul(x,1664525)+1013904223)>>>0;return x/4294967296};let j=0,ex=0,pen=0,n=0;
    for(let i=0;i<160;i++){const g=fx[Math.floor(alea()*fx.length)];
      for(const id of [g.homeId,g.awayId]){CDFranceCareer.ensureAISheet(S.clubs[id]);for(const p of S.clubs[id].players){p.condition=100;p.injury=0;p.suspension=0}}
      const f={...g,id:'cartons-'+i,week:S.round};S.worldMode.fixtures.push(f);
      try{const l=createRugbyMatch([g.homeId,g.awayId],null,true);for(let k=0;!l.finished&&k<700;k++){l.paused=false;advanceRugby(l)}
        for(const s of [0,1]){j+=l.stats[s].yellows||0;ex+=l.sheets[s].sentOff.length;pen+=l.stats[s].penalties||0;n++}}
      finally{S.worldMode.fixtures.splice(S.worldMode.fixtures.indexOf(f),1)}}
    return JSON.stringify({jaunes:j/n,exclusions:ex/n,penalites:pen/n})})()`, 1200000));
  console.log('Top 14, par équipe et par match :', JSON.stringify(top14));
  // Avant le 19/11/2026 : ~0,2 jaune par équipe (2,5 avant le 18/11). Mesuré ~0,65 sur 1 000 affiches.
  assert.ok(top14.jaunes > 0.5 && top14.jaunes < 0.85, 'Top 14 : jaunes dans la cible : ' + top14.jaunes);
  assert.ok(top14.exclusions > 0.005 && top14.exclusions < 0.1, 'Top 14 : rouges rares mais présents : ' + top14.exclusions);
  assert.ok(top14.penalites > 6 && top14.penalites < 16, 'Top 14 : pénalités inchangées en ordre de grandeur : ' + top14.penalites);
} finally { h.close(); }

// 2. Match du joueur.
const jeu = ouvrir({ hebdomadaire: true, testVm: true });
try {
  let m = jusquAuMatch(jeu, creer(jeu));
  if (m.selection?.errors?.length) m = jeu.call('auto_lineup');
  jeu.call('begin_match');
  const vm = jeu.bridge.vm;
  vm.run('globalThis.__base=JSON.stringify(S.live);');
  const r = JSON.parse(vm.run(`(()=>{let j=0,ex=0,pen=0,n=0;for(let i=0;i<80;i++){S.live=JSON.parse(__base);const l=S.live;
    Math.random=(()=>{let x=(i*7919+17)>>>0;return()=>{x=(Math.imul(x,1664525)+1013904223)>>>0;return x/4294967296}})();
    let k=0;while(!l.finished&&k++<400){l.paused=false;advanceRugby(l)}
    for(const s of [0,1]){j+=l.stats[s].yellows;ex+=l.sheets[s].sentOff.length;pen+=l.stats[s].penalties;n++}}
    S.live=JSON.parse(__base);delete globalThis.__base;return JSON.stringify({jaunes:j/n,exclusions:ex/n,penalites:pen/n})})()`, 600000));
  console.log('match du joueur, par équipe et par match :', JSON.stringify(r));
  // Mesuré ~1,1 (12 pénalités par équipe) ; ~2,6 avant le 18/11.
  assert.ok(r.jaunes > 0.5 && r.jaunes < 1.4, 'jaunes crédibles pour deux équipes fautives : ' + r.jaunes);
  assert.ok(r.exclusions > 0.005 && r.exclusions < 0.12, 'rouges rares mais présents : ' + r.exclusions);
  assert.ok(r.penalites > 8 && r.penalites < 16, 'pénalités inchangées en ordre de grandeur : ' + r.penalites);
  console.log('cartons-realistes : OK');
} finally { jeu.fermer(); }

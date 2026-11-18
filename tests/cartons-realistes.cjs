'use strict';
// Cartons réalistes (docs/cartons-realistes-20261118.md) : en carrière Monde, ~0,6 jaune par équipe et par match et un
// rouge (ou deuxième jaune) rare, comme en Top 14. Moyennes d'échantillon (match rejoué depuis le coup d'envoi), jamais
// le résultat exact d'un match.
const assert = require('node:assert/strict');
const { ouvrir, creer, jusquAuMatch } = require('./helpers/carriere-monde.cjs');

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
  console.log('par équipe et par match :', JSON.stringify(r));
  assert.ok(r.jaunes > 0.35 && r.jaunes < 0.95, 'jaunes crédibles : ' + r.jaunes);
  assert.ok(r.exclusions > 0.005 && r.exclusions < 0.12, 'rouges rares mais présents : ' + r.exclusions);
  assert.ok(r.penalites > 8 && r.penalites < 16, 'pénalités inchangées en ordre de grandeur : ' + r.penalites);
  console.log('cartons-realistes : OK');
} finally { jeu.fermer(); }

'use strict';
// Matchs complets du moteur pour les tests de sélection (temps forts, importance, courses) : un seul contexte, une graine par match.
// Les graines ne sont pas « choisies » : n'importe quelles graines conviennent, les tests portent sur des règles ou sur des
// moyennes d'échantillon (tests/helpers/tirages.cjs), jamais sur le résultat exact d'un match.
const assert = require('node:assert/strict');
const { context } = require('../harness.cjs');

// Joue n matchs (club joué = i mod 10, graine = base + i × 7919) et renvoie { camp, events, score, tries } pour chacun.
function matchs(n, { base = 1, max = 900, reglages = '' } = {}) {
  const h = context();
  const out = [];
  for (let i = 0; i < n; i++) {
    h.setSeed(base * 100003 + i * 7919 + 17);
    h.run(`start(${i % 10}); ${reglages} beginMatch(); continueMatch();`);
    for (let k = 0; k < max && !h.run('S.live.finished'); k++) h.run('if (S.live.paused) continueMatch(); presentationTick(S.live);');
    assert.equal(h.run('S.live.finished'), true, `match ${i} terminé`);
    out.push(JSON.parse(h.run('JSON.stringify({camp:S.live.userSide,events:S.live.events,score:S.live.score,tries:S.live.tries})')));
  }
  return out;
}
module.exports = { matchs };

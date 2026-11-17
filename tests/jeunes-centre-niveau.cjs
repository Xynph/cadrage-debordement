'use strict';
// Jeunes du centre (carrière Monde) : la note au poste d'un jeune est celle de son niveau, comme pour un pro.
// Avant le 16/11/2026, les qualités (niveau + profil du poste) donnaient +12 en moyenne et jusqu'à +19
// (docs/jeunes-centre-niveau-20261116.md). Le plafond tiré au poste reste atteignable : potentiel ≥ niveau.
const assert = require('node:assert/strict');
const { test } = require('node:test');
const M = require('./helpers/carriere-monde.cjs');

test('Jeunes du centre (Monde) : note au poste égale au niveau, potentiel au-dessus du niveau', () => {
  const jeu = M.ouvrir({ hebdomadaire: true, testVm: true });
  try {
    M.creer(jeu);
    const jeunes = JSON.parse(jeu.bridge.vm.run(`JSON.stringify([
      ...(S.development.academy||[]),
      ...(S.aiRoster?.academies??[]).flatMap(c=>c.players||[]),
    ].filter(p=>p.academy&&/^youth-/.test(p.id)).map(p=>({id:p.id,pos:p.pos,rating:p.rating,role:roleNote(p),potential:p.dev?.potential})))`));
    assert.ok(jeunes.length >= 60, 'jeunes du centre : ' + jeunes.length);
    const ecarts = jeunes.map(j => j.role - j.rating);
    const pire = jeunes[ecarts.map(Math.abs).indexOf(Math.max(...ecarts.map(Math.abs)))];
    assert.ok(Math.max(...ecarts.map(Math.abs)) <= 1, 'note au poste = niveau (pire : ' + JSON.stringify(pire) + ')');
    assert.ok(jeunes.every(j => j.potential >= j.rating), 'potentiel au moins égal au niveau');
  } finally { jeu.fermer(); }
});

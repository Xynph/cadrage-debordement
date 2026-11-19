'use strict';
// Mesure longue du chrono des arrêts de jeu (scripts/mesure-chrono-arrets.cjs, ≈ 15 min), seulement à la demande en
// ligne : bash ci/en-ligne.sh --ref <branche> --suites mesure-chrono-arrets (CD_EL_SUITES la nomme). Ailleurs, dont la
// CI, la suite est sautée. Le tableau est dans le journal des suites (suites.log du run).
const { test } = require('node:test');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const demande = String(process.env.CD_EL_SUITES || '').split(/\s+/)
  .some(s => s.replace(/^tests\//, '').replace(/\.cjs$/, '') === 'mesure-chrono-arrets');
const parametres = String(process.env.CD_MESURE_CHRONO || '').split(/\s+/).filter(Boolean);

test('Mesure du chrono des arrêts de jeu (à la demande en ligne)', { skip: !demande && 'mesure longue, seulement à la demande en ligne' }, () => {
  const r = spawnSync(process.execPath, ['--max-old-space-size=1400', path.join(__dirname, '../scripts/mesure-chrono-arrets.cjs'), ...parametres], { stdio: 'inherit' });
  if (r.status !== 0) throw Error('mesure en échec (code ' + r.status + ')');
});

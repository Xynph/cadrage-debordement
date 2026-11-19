'use strict';
// Fins de match à la 72e sur 1 200 rejeux par consigne (scripts/mesure-bonus-fin-de-match.cjs) : −8, −6 et −4 (bonus
// défensif en poche). Seulement à la demande en ligne : bash ci/en-ligne.sh --ref <branche> --suites mesure-bonus-1200.
const { test } = require('node:test');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const demande = String(process.env.CD_EL_SUITES || '').split(/\s+/)
  .some(s => s.replace(/^tests\//, '').replace(/\.cjs$/, '') === 'mesure-bonus-1200');

test('Fins de match à la 72e, 1 200 rejeux par consigne (à la demande en ligne)', { skip: !demande && 'mesure longue, seulement à la demande en ligne' }, () => {
  const r = spawnSync(process.execPath, ['--max-old-space-size=1400', path.join(__dirname, '../scripts/mesure-bonus-fin-de-match.cjs'), '1200', '--minute=72', '--situations=defensif,six,tenu'], { stdio: 'inherit' });
  if (r.status !== 0) throw Error('mesure en échec (code ' + r.status + ')');
});

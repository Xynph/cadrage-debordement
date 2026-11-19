'use strict';
// Remesure longue après le chrono des arrêts (#937) : jeu au large contre « Équilibré » sur 1 200 matchs (XV identiques)
// et mené de 8 à la 72e sur 1 200 fins de match par consigne (bonus défensif). Même script que mesure-chrono-arrets,
// paramètres figés ici ; seulement à la demande en ligne : bash ci/en-ligne.sh --ref <branche> --suites mesure-chrono-1200.
const { test } = require('node:test');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const demande = String(process.env.CD_EL_SUITES || '').split(/\s+/)
  .some(s => s.replace(/^tests\//, '').replace(/\.cjs$/, '') === 'mesure-chrono-1200');
const parametres = ['--parties=styles,bonus', '--styles=1200', '--liste-styles=large', '--bonus=1200', '--minutes-bonus=72'];

test('Remesure 1 200 matchs : jeu au large et bonus défensif (à la demande en ligne)', { skip: !demande && 'mesure longue, seulement à la demande en ligne' }, () => {
  const r = spawnSync(process.execPath, ['--max-old-space-size=1400', path.join(__dirname, '../scripts/mesure-chrono-arrets.cjs'), ...parametres], { stdio: 'inherit' });
  if (r.status !== 0) throw Error('mesure en échec (code ' + r.status + ')');
});

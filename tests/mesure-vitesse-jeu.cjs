'use strict';
// Mesure (pas verdict) des coûts de référence de la jauge « Vitesse de jeu estimée » : lance deux fois
// tools/vitesse-jeu-recalage.cjs (championnat du club seul suivi, puis tous suivis), déduit baseWeekMs et detailedMatchMs
// ramenés à la référence et imprime « CD_RECALAGE_FINAL {...} ». Passe toujours ; sautée sans CD_GODOT_EXECUTABLE.
// Lancer en ligne : bash ci/en-ligne.sh --ref <branche> --suites "tests/mesure-vitesse-jeu.cjs".
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const LD = require('../native/engine/league-detail.cjs');
if (!process.env.CD_GODOT_EXECUTABLE) { console.log('SKIP mesure-vitesse-jeu : CD_GODOT_EXECUTABLE absent (mesure manuelle, voir tools/vitesse-jeu-recalage.cjs)'); process.exit(0); }
const lancer = suivis => {
  const r = spawnSync(process.execPath, ['--max-old-space-size=2048', path.resolve(__dirname, '../tools/vitesse-jeu-recalage.cjs'), '--suivis', suivis, '--semaines', process.env.CD_RECALAGE_SEMAINES || '3'], { encoding: 'utf8', timeout: 420000, maxBuffer: 1 << 26 });
  const ligne = (r.stdout || '').split('\n').find(l => l.startsWith('CD_RECALAGE '));
  console.log(ligne || ('Pas de mesure pour ' + suivis + ' : ' + (r.stderr || '').slice(-1500)));
  return ligne ? JSON.parse(ligne.slice('CD_RECALAGE '.length)) : null;
};
const a = lancer('club'), b = lancer('tous');
if (a && b) {
  const R = LD.REFERENCE, compute = (a.benchmark.facteurCalcul + b.benchmark.facteurCalcul) / 2, serial = (a.benchmark.facteurSerie + b.benchmark.facteurSerie) / 2;
  const wa = a.semaineMs / a.machine.contention, wb = b.semaineMs / b.machine.contention;
  const WEEKS = 46, q = R.quickMatchMs;
  const detailedMatchMs = q + WEEKS * (wb - wa) / (b.suivisN - a.suivisN) / compute;
  const baseWeekMs = (wa - (a.suivisN * detailedMatchMs + a.loinN * q) * compute / WEEKS) / serial;
  console.log('CD_RECALAGE_FINAL ' + JSON.stringify({ baseWeekMs: Math.round(baseWeekMs), detailedMatchMs: Math.round(detailedMatchMs * 10) / 10, semaineClubMs: a.semaineMs, semaineToutMs: b.semaineMs, facteurs: { serial: +serial.toFixed(3), compute: +compute.toFixed(3) }, anciennes: { baseWeekMs: R.baseWeekMs, detailedMatchMs: R.detailedMatchMs } }));
}
process.exit(0);

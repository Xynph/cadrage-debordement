'use strict';
// Sonde : chaque crochet de fin de semaine tourne-t-il, en vraie carrière Monde, en cadence journalière
// (advance_day, le vrai rythme du jeu) comme en cadence hebdomadaire (finish_round, celle des anciens tests) ?
// Compte, par semaine du monde close, les déclenchements de chaque crochet (scripts/sonde-crochets.cjs).
// Usage : node scripts/sonde-semaine-quotidienne.cjs [semaines=14] [journalier|hebdomadaire|les-deux] [--json]
const { instrumenter, INSTALLER_VM } = require('../tests/helpers/sonde-crochets.cjs');
instrumenter();
const { ouvrir, jouerLeMatch } = require('../tests/helpers/carriere-monde.cjs');

const SEMAINES = Number(process.argv[2] || 14);
const QUOI = process.argv[3] || 'les-deux';
const JSON_SORTIE = process.argv.includes('--json');

function sonder(journalier) {
  const jeu = ouvrir(journalier ? { testVm: true } : { hebdomadaire: true, testVm: true });
  const run = src => jeu.bridge.vm.run(src);
  run(INSTALLER_VM);
  // Charge utile de l'écran de création du vrai jeu (entry_screens.gd) : départ « premiers clubs » par défaut.
  let model = jeu.regler(jeu.call('new_career', { mode: 'world-champ', club: 102, start: 'premiers-clubs', varyCurrent: true }));
  // Chaîne complète des crochets : enveloppe la plus externe de finishRound.
  run("{const f=finishRound;finishRound=function(){__sonde('chaine:finishRound');return f.apply(this,arguments)};Object.assign(finishRound,f);}");
  run('__sondeLog.length=0');
  const semaines = []; let semaine = run('S.worldMode.week'), garde = 0;
  const t0 = Date.now();
  while (semaines.length < SEMAINES && garde++ < SEMAINES * 12 + 160) {
    model = jeu.regler(model);
    if (journalier) {
      if (model.meta.calendarCadence?.matchReady && model.next) model = jouerLeMatch(jeu, model);
      else model = jeu.call('advance_day', { fromDate: model.meta.calendarToday });
    } else if (model.next) model = jouerLeMatch(jeu, model);
    else model = jeu.call('finish_round');
    const w = run('S.worldMode.week');
    if (w !== semaine) {
      const log = JSON.parse(run('JSON.stringify(__sondeLog.splice(0))'));
      const comptes = {};
      for (const [k] of log) comptes[k] = (comptes[k] || 0) + 1;
      semaines.push({ semaine: semaine, phase: run('S.phase'), round: run('S.round'), reprise: run('!!S.reprise'), politique: run('S.academyGroupPolicy??null'), comptes });
      semaine = w;
    }
  }
  jeu.fermer();
  return { semaines, duree: Date.now() - t0 };
}

const resultats = {};
for (const mode of QUOI === 'les-deux' ? ['hebdomadaire', 'journalier'] : [QUOI]) {
  resultats[mode] = sonder(mode === 'journalier');
  console.error(mode, resultats[mode].semaines.length, 'semaines closes en', resultats[mode].duree, 'ms');
}
if (JSON_SORTIE) { console.log(JSON.stringify(resultats)); process.exit(0); }
// Synthèse : pour chaque crochet, nombre de semaines où il a tourné 0 fois, 1 fois, 2 fois ou plus.
const cles = new Set();
for (const r of Object.values(resultats)) for (const s of r.semaines) for (const k of Object.keys(s.comptes)) cles.add(k);
const modes = Object.keys(resultats);
console.log('crochet'.padEnd(34) + modes.map(m => (m + ' 0/1/2+').padStart(22)).join(''));
for (const k of [...cles].sort()) {
  console.log(k.padEnd(34) + modes.map(m => {
    const n = [0, 0, 0];
    for (const s of resultats[m].semaines) n[Math.min(s.comptes[k] || 0, 2)]++;
    return n.join('/').padStart(22);
  }).join(''));
}

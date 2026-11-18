'use strict';
// Non-régression : en carrière Monde, la clôture de semaine du calendrier JOURNALIER (advance_day, le vrai rythme
// du jeu) fait tourner chaque crochet de fin de semaine des modules UNE fois, comme la cadence hebdomadaire
// (finish_round). Avant le correctif, CDWorldCareer.advanceDay appelait finishWeek directement : centre de
// formation, espoirs, stratégie du club, fiche club, promesses de presse, JIFF… ne tournaient jamais, et les
// notes de match ne closaient la journée qu'au premier match de la semaine suivante.
const assert = require('node:assert/strict');
const { instrumenter, INSTALLER_VM } = require('./helpers/sonde-crochets.cjs');
instrumenter();
const { ouvrir, jouerLeMatch } = require('./helpers/carriere-monde.cjs');

// Crochets branchés sur finishRound : chacun doit tourner exactement une fois par semaine close.
const UNE_FOIS = ['chaine:finishRound', 'academy:finishRound', 'academy-intake:finishRound', 'academy-follow-up:finishRound',
  'avant-saison:finishRound', 'club-meetings:finishRound', 'club-sheet:finishRound', 'club-strategy:finishRound',
  'espoirs-match:finishRound', 'espoirs-own:finishRound', 'jiff:finishRound', 'match-notes:finishRound',
  'press-promises:finishRound', 'reprise:finishRound', 'youth-matches:finishRound', 'youth-national:finishRound'];
// Crochets de l'entraînement de la semaine (finishWeek commence par trainWeek ; l'entraînement peut aussi être lancé
// avant, sans effet en double grâce à S.trained) : au moins une fois.
const AU_MOINS_UNE_FOIS = ['academy:trainWeek', 'youth-matches:trainWeek', 'youth-national:trainWeek'];

function semaines(journalier, n) {
  const jeu = ouvrir(journalier ? { testVm: true } : { hebdomadaire: true, testVm: true });
  try {
    const run = src => jeu.bridge.vm.run(src);
    run(INSTALLER_VM);
    // Charge utile de l'écran de création du vrai jeu (départ « premiers clubs », par défaut).
    let model = jeu.regler(jeu.call('new_career', { mode: 'world-champ', club: 102, start: 'premiers-clubs', varyCurrent: true }));
    run("{const f=finishRound;finishRound=function(){__sonde('chaine:finishRound');return f.apply(this,arguments)};Object.assign(finishRound,f);}");
    run('__sondeLog.length=0');
    const vues = []; let semaine = run('S.worldMode.week');
    for (let garde = 0; vues.length < n && garde < n * 10 + 160; garde++) {
      model = jeu.regler(model);
      if (journalier) {
        if (model.meta.calendarCadence?.matchReady && model.next) model = jouerLeMatch(jeu, model);
        else model = jeu.call('advance_day', { fromDate: model.meta.calendarToday });
      } else if (model.next) model = jouerLeMatch(jeu, model);
      else model = jeu.call('finish_round');
      const w = run('S.worldMode.week');
      if (w === semaine) continue;
      const comptes = {};
      for (const [k] of JSON.parse(run('JSON.stringify(__sondeLog.splice(0))'))) comptes[k] = (comptes[k] || 0) + 1;
      vues.push({ semaine, comptes, annoncee: run('S.matchNotes?.semaine?.annoncee===true'), jiff: run('Object.values(S.jiff?.counts||{}).reduce((a,r)=>a+r[0],0)') });
      semaine = w;
    }
    assert.equal(vues.length, n, n + ' semaines closes');
    return vues;
  } finally { jeu.fermer(); }
}

for (const [mode, journalier, n] of [['journalier', true, 3], ['hebdomadaire', false, 2]]) {
  const vues = semaines(journalier, n);
  for (const v of vues) {
    for (const k of UNE_FOIS) assert.equal(v.comptes[k] || 0, 1, `${mode}, semaine ${v.semaine} : ${k} doit tourner une fois (${JSON.stringify(v.comptes)})`);
    for (const k of AU_MOINS_UNE_FOIS) assert.ok((v.comptes[k] || 0) >= 1, `${mode}, semaine ${v.semaine} : ${k} n'a pas tourné`);
    // La journée est close (équipe-type annoncée) à la fin de sa semaine, pas au premier match de la suivante.
    assert.equal(v.comptes['match-notes:nouvelle-journee'] || 0, 0, `${mode}, semaine ${v.semaine} : journée close en retard`);
    assert.equal(v.annoncee, true, `${mode}, semaine ${v.semaine} : journée des notes de match non close`);
  }
  // Quotas JIFF (correctif de #925 pour le seul JIFF, ici par la chaîne commune) : feuilles comptées en journalier.
  // En hebdomadaire, les premières semaines closes sont celles de la préparation, sans feuille de match.
  if (journalier) assert.ok(vues.at(-1).jiff > 0, `${mode} : aucune feuille JIFF comptée`);
  console.log(`world-semaine-quotidienne : ${mode} OK (${n} semaines)`);
}

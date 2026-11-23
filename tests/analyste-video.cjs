'use strict';
// Rapport de l'analyste vidéo après le match (revue FM27, idée 28 ; choix de Léo du 23/11/2026) :
//   - fin du match : la domination minute par minute et les entrées dans les 22 adverses (datées) du journal entier sont
//     lues dans le rapport (`decisions.report.analyse`), puis gardées dans la carrière à la clôture (`S.lastReport.analyse`)
//     et contrôlées à la validation de la sauvegarde ;
//   - les chiffres viennent du vrai match : entrées datées = compte des entrées, essais du rapport = score d'essais ;
//   - un message « Analyse vidéo » de l'analyste arrive en Réception après le match (son propre courrier, sans réponse).
// Carrière Monde (`world-champ`), un match délégué.
const assert = require('node:assert/strict');
const { test } = require('node:test');
const M = require('./helpers/carriere-monde.cjs');
const matchDirect = require('../native/engine/match-direct.cjs');

function controler(a, quoi) {
  assert.ok(a && a.version === matchDirect.ANALYSE_VERSION, quoi + ' : analyse présente');
  assert.ok(Array.isArray(a.domination) && a.domination.length >= 70 && a.domination.every(n => Number.isInteger(n) && n >= -100 && n <= 100), quoi + ' : domination minute par minute');
  assert.ok(a.domination.some(n => n > 0) && a.domination.some(n => n < 0), quoi + ' : les deux équipes dominent à un moment');
  assert.ok(Array.isArray(a.occasions), quoi + ' : occasions');
  for (const camp of [0, 1]) assert.equal(a.occasions.filter(o => o[1] === camp).length, a.zone22.entrees[camp], quoi + ' : entrées datées = entrées comptées');
  assert.ok(a.occasions.every((o, i) => i === 0 || o[0] >= a.occasions[i - 1][0]), quoi + ' : occasions dans l’ordre du match');
  assert.ok(a.zone22.entrees[0] + a.zone22.entrees[1] > 0, quoi + ' : au moins une entrée dans les 22');
}

test('Carrière Monde : analyse vidéo gardée après le match, message « Analyse vidéo » en Réception', { timeout: 900000 }, () => {
  const jeu = M.ouvrir({ testVm: true, mandatoryPress: false });
  try {
    let m = M.creer(jeu);
    m = M.jusquAuMatch(jeu, m);
    m = M.jouerLeMatch(jeu, m);
    const vm = jeu.bridge.vm;
    // Direct terminé, journée pas encore close : l'analyse est lue sur le direct.
    const report = m.decisions.report;
    assert.ok(report, 'rapport du match');
    controler(report.analyse, 'direct terminé');
    const essais = report.essais.reduce((t, e) => { t[e.side]++; return t; }, [0, 0]);
    assert.deepEqual(essais, JSON.parse(vm.run('JSON.stringify(S.live.tries)')), 'essais du rapport = essais du match');
    m = M.jusquALaSemaineSuivante(jeu, m);
    // Journée close : l'analyse est gardée dans la carrière, identique.
    const garde = JSON.parse(vm.run('JSON.stringify(S.lastReport&&S.lastReport.analyse)'));
    controler(garde, 'après clôture');
    assert.deepEqual(garde, report.analyse, 'même analyse avant et après la clôture');
    assert.deepEqual(m.decisions.report.analyse, garde, 'rapport lu dans la carrière');
    // Sauvegarde : l'analyse est contrôlée ; une analyse abîmée est refusée.
    vm.run('validateCareer(S)');
    assert.throws(() => vm.run('(()=>{const a=S.lastReport.analyse,v=a.domination[0];a.domination[0]=500;try{validateCareer(S)}finally{a.domination[0]=v}})()'), /analyste vidéo/);
    // Message de l'analyste, propre au match, sans réponse attendue.
    const mail = m.clubLife.clubMail.mails.find(x => x.type === 'analyse_video');
    assert.ok(mail, 'message « Analyse vidéo » reçu');
    assert.equal(mail.categorieLabel, 'Analyse vidéo');
    assert.equal(mail.expediteur, 'L\'analyste vidéo');
    assert.match(mail.sujet, /^(Analyse vidéo : |Vidéo du match contre )/);
    assert.equal(mail.reponses.length, 0, 'aucune réponse demandée');
    const adverse = report.pair[1 - report.side];
    assert.equal(String(mail.club), String(adverse), 'message rattaché à l’adversaire du match');
  } finally {
    jeu.fermer();
  }
});

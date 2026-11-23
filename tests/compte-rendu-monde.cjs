'use strict';
// Compte rendu du match en carte (idée n° 19 de la revue FM27, choix de Léo du 23/11/2026), côté moteur, carrière Monde :
//  1. affluence enregistrée pour chaque rencontre de l'historique (`affluence` : spectateurs au stade du club qui
//     reçoit, entre 35 et 97 % de sa capacité) ; terrain neutre : pas d'affluence ;
//  2. le compte rendu du dernier match (`decisions.report`) reprend l'affluence du match du manager et ses essais
//     détaillés (minute, camp, origine, zone, ceux de l'historique) avec le marqueur ;
//  3. sauvegarde : relue telle quelle ; ancienne sauvegarde sans affluence relue sans erreur (pas de chiffre affiché).
const assert = require('node:assert/strict');
const fs = require('node:fs'), os = require('node:os'), path = require('node:path');
const { test } = require('node:test');
const M = require('./helpers/carriere-monde.cjs');

const lire = (jeu, expr) => JSON.parse(jeu.bridge.vm.run('JSON.stringify(' + expr + ')'));

test('Compte rendu : affluence de chaque match, essais détaillés avec marqueur, sauvegarde', { timeout: 900000 }, () => {
  const dataDir = fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-compte-rendu-'));
  try {
    let report, historique;
    const jeu = M.ouvrir({ hebdomadaire: true, testVm: true, dataDir });
    try {
      let model = M.creer(jeu, 0);
      model = M.jouer(jeu, model, 3);
      historique = lire(jeu, 'S.history');
      const capacites = lire(jeu, 'Object.fromEntries(Object.keys(S.clubs).map(id=>[id,Number.isFinite(S.clubs[id].stadiumCapacity)?S.clubs[id].stadiumCapacity:(typeof CDWorldStadiumCapacities!=="undefined"&&Number.isInteger(CDWorldStadiumCapacities[id])?CDWorldStadiumCapacities[id]:12000)]))');
      assert.ok(historique.length >= 10, 'rencontres jouées : ' + historique.length);
      for (const r of historique) {
        if (r.neutral) { assert.equal('affluence' in r, false, 'terrain neutre sans affluence (' + r.fixtureId + ')'); continue; }
        const cap = capacites[r.pair[0]];
        assert.ok(Number.isInteger(r.affluence), 'affluence entière (' + r.fixtureId + ')');
        assert.ok(r.affluence >= Math.floor(cap * .25) - 10 && r.affluence <= cap, 'affluence ' + r.affluence + ' / capacité ' + cap);
      }
      assert.ok(new Set(historique.map(r => r.affluence)).size > 3, 'affluences variées');

      // Compte rendu du dernier match du manager.
      report = model.decisions.report;
      assert.ok(report, 'compte rendu disponible');
      const own = historique.filter(r => r.pair.includes(0)).at(-1);
      assert.deepEqual(report.score, own.score, 'compte rendu du dernier match');
      assert.equal(report.affluence, own.affluence ?? null, 'affluence du match du manager');
      assert.ok(Array.isArray(own.essais), 'match du manager détaillé');
      assert.equal(report.essais.length, own.essais.length, 'autant d’essais que l’historique');
      report.essais.forEach((e, i) => {
        const [minute, camp, origine, zone] = own.essais[i];
        assert.deepEqual([e.minute, e.side, e.origin, e.zone], [minute, camp, origine, zone], 'essai ' + i + ' : données de l’historique');
      });
      // Marqueurs : sur les quatre derniers matchs du manager, des noms connus des deux clubs.
      const noms = report.essais.filter(e => e.name);
      assert.ok(noms.length >= report.essais.length - 1, 'marqueurs nommés : ' + noms.length + ' / ' + report.essais.length);
      for (const e of noms) {
        const joueurs = lire(jeu, 'S.clubs[' + report.pair[e.side] + '].players.map(p=>p.id)');
        assert.ok(joueurs.includes(e.id), 'marqueur ' + e.name + ' du bon club');
      }
      jeu.call('save');
    } finally { jeu.fermer(); }

    const repris = M.ouvrir({ hebdomadaire: true, testVm: true, dataDir });
    try {
      const model = repris.call('snapshot');
      assert.deepEqual(model.decisions.report.essais, report.essais, 'essais relus');
      assert.equal(model.decisions.report.affluence, report.affluence, 'affluence relue');
      assert.deepEqual(lire(repris, 'S.history'), historique, 'historique relu tel quel');
      // Ancienne sauvegarde : ni affluence ni essais détaillés dans le compte rendu.
      repris.bridge.vm.run('for(const r of S.history)delete r.affluence;if(S.lastReport){delete S.lastReport.affluence;delete S.lastReport.essais}');
      repris.call('save');
    } finally { repris.fermer(); }
    const ancienne = M.ouvrir({ hebdomadaire: true, testVm: true, dataDir });
    try {
      const model = ancienne.call('snapshot');
      assert.equal(model.decisions.report.affluence, null, 'ancienne sauvegarde : pas d’affluence');
      assert.deepEqual(model.decisions.report.essais, [], 'ancienne sauvegarde : pas d’essais détaillés');
      const suite = M.jouer(ancienne, model, 1);
      assert.ok(Number.isInteger(suite.decisions.report.affluence) || lire(ancienne, 'S.history').filter(r => r.pair.includes(0)).at(-1).neutral, 'match suivant : affluence');
    } finally { ancienne.fermer(); }
  } finally { fs.rmSync(dataDir, { recursive: true, force: true }); }
});

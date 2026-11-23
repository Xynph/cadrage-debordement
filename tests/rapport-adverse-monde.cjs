'use strict';
// Rapport sur l'adversaire (idée n° 10 de la revue FM27, choix de Léo du 23/11/2026), côté moteur, carrière Monde :
//  1. chaque essai d'un match joué avec le moteur complet est gardé dans l'historique (`essais` : minute, camp,
//     origine j / b / m, profondeur du départ de l'action en mètres de la ligne visée), autant que `tries` ;
//  2. la fiche du club (`club_sheet`, lecture seule) en tire `rapport` : essais marqués / encaissés du club,
//     titulaires par maillot (trois au plus, du plus fréquent au moins fréquent), feuilles comptées ;
//  3. sauvegarde : relue telle quelle après fermeture et réouverture ; ancienne sauvegarde sans `essais`
//     (matchs joués avant la mise à jour) relue sans erreur, rapport vide pour ces matchs, aucune réécriture.
const assert = require('node:assert/strict');
const fs = require('node:fs'), os = require('node:os'), path = require('node:path');
const { test } = require('node:test');
const M = require('./helpers/carriere-monde.cjs');

const lire = (jeu, expr) => JSON.parse(jeu.bridge.vm.run('JSON.stringify(' + expr + ')'));

test('Rapport adverse : essais détaillés dans l’historique, fiche du club, sauvegarde et ancienne sauvegarde', { timeout: 900000 }, () => {
  const dataDir = fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-rapport-adverse-'));
  try {
    let historique, rapport, adverse;
    const jeu = M.ouvrir({ hebdomadaire: true, testVm: true, dataDir });
    try {
      let model = M.creer(jeu, 0);
      model = M.jouer(jeu, model, 3);
      historique = lire(jeu, 'S.history');
      const detailles = historique.filter(r => Array.isArray(r.essais));
      assert.ok(detailles.length >= 10, 'matchs au moteur complet détaillés : ' + detailles.length + ' / ' + historique.length);
      assert.ok(detailles.some(r => r.pair.includes(0)), 'le match du manager est détaillé');
      let total = 0;
      for (const r of detailles) {
        assert.equal(r.essais.length, r.tries[0] + r.tries[1], 'autant d’essais détaillés que d’essais marqués (' + r.fixtureId + ')');
        for (let side = 0; side < 2; side++) assert.equal(r.essais.filter(e => e[1] === side).length, r.tries[side], 'essais du camp ' + side);
        let avant = -1;
        for (const e of r.essais) {
          assert.equal(e.length, 4, 'essai : [minute, camp, origine, profondeur]');
          const [minute, camp, origine, profondeur] = e;
          assert.ok(Number.isInteger(minute) && minute >= 0 && minute <= 110, 'minute ' + minute);
          assert.ok(minute >= avant, 'essais dans l’ordre du match');
          avant = minute;
          assert.ok(camp === 0 || camp === 1, 'camp ' + camp);
          assert.ok(['j', 'b', 'm'].includes(origine), 'origine ' + origine);
          assert.ok(Number.isInteger(profondeur) && profondeur >= 0 && profondeur <= 100, 'profondeur ' + profondeur);
        }
        total += r.essais.length;
      }
      assert.ok(total >= 40, 'essais détaillés : ' + total);
      const origines = new Set(detailles.flatMap(r => r.essais.map(e => e[2])));
      assert.ok(origines.has('j') && origines.size >= 2, 'plusieurs origines observées : ' + [...origines]);
      const profondeurs = detailles.flatMap(r => r.essais.map(e => e[3]));
      assert.ok(profondeurs.some(p => p > 22) && profondeurs.some(p => p <= 22), 'départs proches et lointains');

      // Fiche du club adverse : rapport recalculé à la main depuis l'historique.
      adverse = model.leagues.find(l => l.id === 'elite').rows.map(r => r.id).find(id => id !== 0);
      const avantFiche = jeu.bridge.vm.run('JSON.stringify(S)');
      const r1 = jeu.brut('club_sheet', { club: adverse });
      assert.equal(r1.ok, true, r1.error);
      assert.equal(jeu.bridge.vm.run('JSON.stringify(S)'), avantFiche, 'fiche en lecture seule');
      rapport = r1.model.clubSheet.rapport;
      const siens = historique.filter(r => r.pair.includes(adverse));
      const attendus = [];
      for (const r of siens.filter(r => Array.isArray(r.essais))) {
        const side = r.pair.indexOf(adverse);
        for (const e of r.essais) attendus.push({ minute: e[0], for: e[1] === side, origin: e[2], depth: e[3], opponent: r.pair[1 - side], fixtureId: r.fixtureId, date: r.date ?? null, score: [r.score[side], r.score[1 - side]] });
      }
      assert.equal(rapport.matches, siens.length, 'matchs du club');
      assert.equal(rapport.detailed, siens.filter(r => Array.isArray(r.essais)).length, 'matchs détaillés du club');
      assert.deepEqual(rapport.essais, attendus, 'essais du club : marqués et encaissés, minute, origine, zone, score');
      assert.equal(rapport.essais.filter(e => e.for).length, siens.reduce((a, r) => a + (Array.isArray(r.essais) ? r.tries[r.pair.indexOf(adverse)] : 0), 0), 'marqués');
      assert.equal(rapport.sheets, r1.model.clubSheet.xv.matches, 'feuilles comptées = XV type');
      assert.equal(rapport.maillots.length, 15, 'quinze maillots');
      const effectif = new Set(r1.model.clubSheet.squad.map(p => p.id));
      for (const [i, choix] of rapport.maillots.entries()) {
        assert.ok(choix.length >= 1 && choix.length <= 3, 'maillot ' + (i + 1) + ' : un à trois titulaires');
        assert.ok(choix.every(c => effectif.has(c.id) && c.starts >= 1 && c.starts <= rapport.sheets), 'maillot ' + (i + 1) + ' : joueurs du club, titularisations bornées');
        for (let k = 1; k < choix.length; k++) assert.ok(choix[k - 1].starts >= choix[k].starts, 'maillot ' + (i + 1) + ' : du plus au moins fréquent');
      }
      const total15 = rapport.maillots.reduce((a, c) => a + c.reduce((b, x) => b + x.starts, 0), 0);
      assert.ok(total15 <= 15 * rapport.sheets, 'titularisations cohérentes avec les feuilles');
      assert.deepEqual(jeu.brut('club_sheet', { club: adverse }).model.clubSheet.rapport, rapport, 'déterministe');
      jeu.call('save');
    } finally { jeu.fermer(); }

    // Sauvegarde relue : historique détaillé et rapport identiques.
    const repris = M.ouvrir({ hebdomadaire: true, testVm: true, dataDir });
    try {
      assert.deepEqual(lire(repris, 'S.history'), historique, 'historique détaillé relu tel quel');
      const r = repris.brut('club_sheet', { club: adverse });
      assert.equal(r.ok, true, r.error);
      assert.deepEqual(r.model.clubSheet.rapport, rapport, 'rapport identique après réouverture');
      // Ancienne sauvegarde : matchs joués avant la mise à jour, sans `essais`.
      repris.bridge.vm.run('for(const r of S.history)delete r.essais');
      repris.call('save');
    } finally { repris.fermer(); }
    const ancienne = M.ouvrir({ hebdomadaire: true, testVm: true, dataDir });
    try {
      assert.equal(lire(ancienne, 'S.history.some(r=>"essais" in r)'), false, 'ancienne sauvegarde sans essais détaillés');
      const r = ancienne.brut('club_sheet', { club: adverse });
      assert.equal(r.ok, true, r.error);
      const vieux = r.model.clubSheet.rapport;
      assert.equal(vieux.detailed, 0);
      assert.deepEqual(vieux.essais, []);
      assert.equal(vieux.matches, rapport.matches, 'matchs toujours comptés');
      assert.deepEqual(vieux.maillots, rapport.maillots, 'XV habituel intact (feuilles de match)');
      assert.equal(lire(ancienne, 'S.history.some(r=>"essais" in r)'), false, 'aucune réécriture à la lecture');
      // Le match suivant est détaillé à nouveau.
      let model = ancienne.call('snapshot');
      model = M.jouer(ancienne, model, 1);
      assert.ok(lire(ancienne, 'S.history').some(h => Array.isArray(h.essais) && h.pair.includes(0)), 'match joué après la mise à jour : détaillé');
    } finally { ancienne.fermer(); }
  } finally { fs.rmSync(dataDir, { recursive: true, force: true }); }
});

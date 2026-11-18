'use strict';
// Défis de départ (création de carrière Monde) : calculés sur la vraie base, appliqués à la création
// (objectif du président + objectif de classement au conseil), refusés s'ils ne correspondent pas au club,
// conservés à la sauvegarde et à la reprise.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { createBridge } = require('../native/engine/worker.cjs');
const defis = require('../native/engine/defis-depart.cjs');

const dataDir = fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-defis-'));
const ouvrir = () => createBridge({ dataDir, seed: 4242, now: 1794315600000, dailyCalendar: true, mandatoryPress: true, internationalCareer: true });
let bridge = ouvrir(), id = 0;
const brut = (command, payload = {}) => bridge.handle({ id: ++id, command, payload });
const call = (command, payload = {}) => { const r = brut(command, payload); assert.equal(r.ok, true, command + ' : ' + r.error); return r.model; };
try {
  const liste = call('start_challenges').meta.startChallenges;
  const catalogue = call('snapshot').meta.champCatalogue;
  const parId = new Map(catalogue.map(c => [c.id, c]));
  assert.deepEqual(liste.map(d => d.id), ['douceur', 'promu', 'nationale', 'petit-budget', 'geant'], 'les cinq défis sont proposés');
  for (const defi of liste) {
    assert.ok(defi.titre && defi.accroche && defi.clubs.length >= 1 && defi.clubs.length <= 3, defi.id);
    for (const offre of defi.clubs) {
      const club = parId.get(offre.club);
      assert.ok(club && club.playable !== false, 'club jouable ' + offre.club);
      assert.ok(Number.isInteger(offre.difficulte) && offre.difficulte >= 1 && offre.difficulte <= 5);
      assert.equal(offre.niveau, defis.LIBELLES[offre.difficulte]);
      assert.ok(offre.rang >= 1 && offre.objectif.length > 0 && offre.raison.length > 0);
      if (defi.id === 'nationale') assert.equal(club.division, 'nationale');
      if (defi.id === 'promu') assert.ok(club.history.results.some(r => r.year === defis.ANNEE_DEPART && r.titles > 0), 'promu de la saison passée');
      if (defi.id === 'geant') assert.ok(club.history.results.some(r => r.titles >= 3), 'palmarès lourd');
    }
  }
  // Déterminisme.
  assert.deepEqual(call('start_challenges').meta.startChallenges, liste);

  // Défi qui ne correspond pas au club : refusé, sans carrière créée.
  const promu = liste.find(d => d.id === 'promu').clubs[0];
  const autre = catalogue.find(c => c.division === 'elite' && c.id !== promu.club);
  const refus = brut('new_career', { mode: 'world-champ', club: autre.id, challenge: { id: 'promu', club: autre.id } });
  assert.equal(refus.ok, false); assert.match(refus.error, /pas proposé/);
  assert.equal(brut('new_career', { mode: 'world-champ', club: autre.id, challenge: { id: 'promu', club: promu.club } }).ok, false, 'club du défi ≠ club choisi');

  // Défi accepté : objectif du président et du conseil.
  const model = call('new_career', { mode: 'world-champ', club: promu.club, challenge: { id: 'promu', club: promu.club } });
  assert.equal(model.club.goal, 'Maintien');
  const objectifs = JSON.stringify(model).match(/"defi:1:\d+:rank"[^}]*/g) || [];
  assert.equal(objectifs.length, 1, 'objectif de classement posé au conseil');
  assert.match(objectifs[0], new RegExp('"type":"rank","target":' + promu.rang + ','));
  call('save');
  bridge.close();
  bridge = ouvrir();
  const repris = call('snapshot');
  assert.equal(repris.meta.hasCareer, true, 'carrière reprise');
  assert.equal(repris.club.goal, 'Maintien', 'objectif conservé à la reprise');
  console.log('defis-depart : ok (' + liste.map(d => d.id + ':' + d.clubs.length).join(', ') + ')');
} finally {
  try { bridge.close(); } catch { /* fermé */ }
  fs.rmSync(dataDir, { recursive: true, force: true });
}

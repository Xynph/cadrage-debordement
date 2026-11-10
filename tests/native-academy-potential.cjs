
'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { test } = require('node:test');
const { createBridge } = require('../native/engine/worker.cjs');
const { context } = require('./france-harness.cjs');

test('Formation Toulouse : les U21 du vrai DTO couvrent plusieurs plafonds et les exceptions d’élite restent rares', t => {
  const dir = fs.mkdtempSync(path.join(process.env.CD_ACADEMY_POTENTIAL_TEMP || os.tmpdir(), 'academy-potential-'));
  const bridge = createBridge({ dataDir: dir, seed: 437493, now: 1788134400000 });
  t.after(() => {
    bridge.close();
    if (!process.env.CD_ACADEMY_POTENTIAL_TEMP) fs.rmSync(dir, { recursive: true, force: true });
  });
  const result = bridge.handle({ id: 1, command: 'new_career', payload: { mode: 'common', club: 0 } });
  assert.equal(result.ok, true, result.error);
  const academy = result.model.decisions.development.academy;
  const u21 = academy.filter(player => player.age >= 19 && player.age <= 21);
  const potentials = u21.map(player => player.potential);
  console.log(JSON.stringify({ profile: dir, u21: potentials, u18: academy.filter(p => p.age <= 18).map(p => p.potential) }));
  assert.equal(u21.length, 30);
  const originalU21 = u21.filter(player => /^youth-0-1-\d{1,2}$/.test(player.id));
  assert.equal(originalU21.length, 5);
  assert.ok(originalU21.filter(player => player.potential > 90).length <= 1);
  assert.ok(potentials.filter(potential => potential > 90).length <= 3, String(potentials));
  assert.ok(new Set(potentials).size >= 3);
  assert.ok(Math.min(...potentials) <= 80);
  assert.ok(academy.every(player => player.potential > player.note));
});

test('Génération : la queue supérieure est rare à travers postes, clubs et saisons', () => {
  const { run, seed } = context(437493);
  const rng = seed();
  const sample = JSON.parse(run(`JSON.stringify(Array.from({length:30}, (_, club) =>
    Array.from({length:12}, (_, year) => POS.map((_, slot) => {
      const player = academyPlayer(club, slot, year+1, slot);
      return [player.fam, player.rating, roleNote(player), player.dev.potential, potentialAtRole(player)];
    }))).flat(2))`));
  const shown = sample.map(row => row[4]).sort((a,b) => a-b);
  const elite = shown.filter(value => value > 90).length;
  console.log(JSON.stringify({ sample: shown.length, min: shown[0], p10: shown[Math.floor(shown.length*.1)], median: shown[Math.floor(shown.length*.5)], p90: shown[Math.floor(shown.length*.9)], max: shown.at(-1), elite }));
  assert.equal(seed(), rng, 'La génération ne consomme pas le RNG de simulation');
  assert.equal(shown.length, 5400);
  assert.ok(sample.every(([,rating,note,cap,potential]) => cap >= rating + 3 && cap <= 99 && potential > note));
  assert.ok(elite / shown.length >= .015 && elite / shown.length <= .05, 'Part de potentiels au poste > 90 : '+elite/shown.length);
  assert.ok(shown[0] >= 64 && shown.at(-1) <= 94);
  assert.ok(shown[Math.floor(shown.length*.5)] >= 72 && shown[Math.floor(shown.length*.5)] <= 82);
});

test('Migration : les points acquis, la majoration historique et les profils documentés restent protégés', () => {
  const h = context(437493);
  h.run(`start(0);
    delete S.development.academyPotentialVersion;
    const [boosted, advanced, documented] = S.development.academy;
    const legacyPotential = p => 76 + seedHash(p.id)%19;
    for (const p of S.development.academy) p.dev.potential=legacyPotential(p);
    boosted.dev.potential+=3;
    advanced.rating=advanced.dev.potential-1;
    advanced.dev.xp=.75;
    advanced.dev.minutes=80;
    advanced.dev.careerMinutes=160;
    advanced.dev.appearances=1;
    documented.attributesV2={ documented:true };
  `);
  const before = h.state().development.academy;
  const capWithBonus = h.run('Math.min(boosted.dev.potential,academyPotential(boosted)+3)');
  assert.equal(h.run('normalizeAcademyPotential(S)'), true);
  const after = h.state().development.academy;
  assert.equal(after[0].dev.potential, capWithBonus);
  assert.deepEqual(after[1], before[1], 'Un prochain point accessible protège l’XP déjà acquise');
  assert.deepEqual(after[2], before[2], 'Un dossier source conserve son plafond');
  assert.equal(h.run('normalizeAcademyPotential(S)'), false);
  assert.deepEqual(h.state().development.academy, after);
});

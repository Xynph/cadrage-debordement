'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { test } = require('node:test');
const { createBridge } = require('../native/engine/worker.cjs');
const { context } = require('./monde-harness.cjs');

test('Formation Toulouse : les U21 du vrai DTO couvrent plusieurs plafonds et les exceptions d’élite restent rares', t => {
  const dir = fs.mkdtempSync(path.join(process.env.CD_ACADEMY_POTENTIAL_TEMP || os.tmpdir(), 'academy-potential-'));
  const bridge = createBridge({ dataDir: dir, seed: 437493, now: 1788134400000 });
  t.after(() => {
    bridge.close();
    if (!process.env.CD_ACADEMY_POTENTIAL_TEMP) fs.rmSync(dir, { recursive: true, force: true });
  });
  const result = bridge.handle({ id: 1, command: 'new_career', payload: { mode: 'world-champ', club: 0 } });
  assert.equal(result.ok, true, result.error);
  const academy = result.model.decisions.development.academy;
  const u21 = academy.filter(player => player.age >= 18 && player.age <= 21);
  const saved = JSON.parse(JSON.parse(fs.readFileSync(path.join(result.model.meta.dataDir, 'donnees.json'))).store['bdt-v1']);
  const source = new Map(saved.development.academy.map(player => [player.id, player]));
  const potentials = u21.map(player => source.get(player.id).dev.potential);
  console.log(JSON.stringify({ u21: potentials, publicRanges: u21.map(p => p.potentialRange) }));
  assert.equal(u21.length, 30);
  const originalU21 = u21.filter(player => /^youth-0-1-\d{1,2}$/.test(player.id));
  assert.equal(originalU21.length, 10);
  assert.ok(originalU21.filter(player => source.get(player.id).dev.potential > 90).length <= 1);
  assert.ok(potentials.filter(potential => potential > 90).length <= 3, String(potentials));
  assert.ok(new Set(potentials).size >= 3);
  assert.ok(Math.min(...potentials) <= 80);
  assert.ok(academy.every(player => player.potential === null && player.potentialRange.max-player.potentialRange.min === 4));
  assert.ok(academy.every(player => player.potentialRange.min <= source.get(player.id).dev.potential && player.potentialRange.max >= source.get(player.id).dev.potential));
  assert.ok(academy.every(player => source.get(player.id).dev.potential >= player.rating));
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

test('Les centres formateurs et les grands clubs ont un avantage sans exclure les surprises', () => {
  const h = context(437493);
  const result = JSON.parse(h.run(`
    S.commonDatabase = CDCommonRosters.marker;
    const tracked = [0, 3, 25, 26];
    const distribution = Object.fromEntries(tracked.map(id => {
      const club = S.clubs[id];
      const scores = Array.from({length:100}, (_, year) => POS.map((_, slot) =>
        potentialAtRole(academyPlayer(id, slot, year+1, slot, false, club)))).flat();
      return [id, {weight:academyRecruitmentWeight(club), elite:scores.filter(score => score > 90).length,
        prospects:scores.filter(score => score >= 83).length, max:Math.max(...scores)}];
    }));
    const baseline = academyPlayer(0, 10, 1, 72);
    const emergency = academyPlayer(0, 10, 1, 72, true, S.clubs[0]);
    const legacyEmergency = academyPlayer(0, 10, 1, 72, true);
    delete S.commonDatabase;
    JSON.stringify({distribution, baseline:baseline.dev.potential, ordinary:academyPotential(baseline),
      emergency:emergency.dev.potential, legacyEmergency:legacyEmergency.dev.potential,
      fictional:academyRecruitmentWeight({id:0,base:60}), shared:academyFacilitiesBonus({id:0})+academyFormationStaffBonus({id:0})});`));
  const { distribution } = result;
  console.log(JSON.stringify({ generatedPerClub:1500, ...distribution }));
  assert.ok(distribution[0].elite > distribution[3].elite);
  assert.ok(distribution[25].elite > distribution[3].elite);
  assert.ok(distribution[3].elite > distribution[26].elite);
  assert.ok(distribution[26].elite > 0);
  assert.ok(distribution[0].prospects > distribution[26].prospects);
  assert.ok(Object.values(distribution).every(club => club.max <= 94 && club.elite < 150));
  assert.equal(result.baseline, result.ordinary);
  assert.equal(result.emergency, result.legacyEmergency);
  assert.equal(result.fictional, result.shared, 'Un club sans repère de formation ne reçoit que les bonus des installations et du responsable de formation de la carrière');
});

test('Migration : les points acquis, la majoration historique et les profils documentés restent protégés', () => {
  const h = context(437493);
  h.run(`
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

test('Qualité des fournées : pays, installations et responsable de la formation déplacent le potentiel', () => {
  const h = context(437493);
  const result = JSON.parse(h.run(`
    const base = {id:3, base:72, abbr:'ZZZ'};
    const careerStaff = S.staffCareer;
    delete S.staffCareer; // la mesure isole l'effet du responsable de formation : pas de staff de carrière au départ
    const sample = club => Array.from({length:60}, (_, year) => POS.map((_, slot) =>
      potentialAtRole(academyPlayer(club.id, slot, year+1, slot, false, club)))).flat();
    const stats = club => { const scores = sample(club); return {
      weight:academyRecruitmentWeight(club), mean:scores.reduce((a,b)=>a+b,0)/scores.length,
      prospects:scores.filter(score => score >= 83).length }; };
    const france = stats({...base, country:'FR'});
    const japan = stats({...base, country:'JP'});
    S.staffCareer = {version:1, people:[[{id:'f1', clubId:3, role:'formation', level:75}]]};
    const goodStaff = stats({...base, country:'FR'});
    S.staffCareer.people = [[{id:'f2', clubId:3, role:'formation', level:45}]];
    const weakStaff = stats({...base, country:'FR'});
    S.staffCareer = careerStaff;
    JSON.stringify({france, japan, goodStaff, weakStaff,
      bounded:[academyRecruitmentWeight({id:9, base:99, abbr:'TCX', country:'FR'}), academyRecruitmentWeight({id:9, base:40, abbr:'X', country:'GE'})]});`));
  console.log(JSON.stringify(result));
  assert.ok(result.japan.weight < result.france.weight);
  assert.ok(result.japan.mean < result.france.mean);
  assert.ok(result.goodStaff.weight > result.france.weight && result.goodStaff.prospects > result.france.prospects);
  assert.ok(result.weakStaff.weight < result.france.weight && result.weakStaff.prospects < result.france.prospects);
  assert.ok(result.japan.prospects > 0, 'Un petit pays de rugby garde des surprises');
  assert.ok(result.bounded.every(weight => weight >= 0 && weight <= 6));
});

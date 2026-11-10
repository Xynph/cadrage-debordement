'use strict';

// Prototype de génération pour le seul club humain. Le remplacement de la
// fenêtre annuelle est limité à la VM de ce banc, sans activation en jeu.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { context } = require('./france-harness.cjs');
const { createBridge } = require('../native/engine/worker.cjs');

const output = process.argv[2];
assert.ok(path.isAbsolute(output ?? ''), 'Indiquer un dossier d’audit absolu.');
fs.mkdirSync(output, { recursive: true });
const audit = fs.mkdtempSync(path.join(output, 'pilote-'));
let vm = context(827381);
let run = vm.run;

function intakeGroups({ initial = false } = {}) {
  const academy = S.development;
  if (!initial && academy.intakeSeason === S.season) return;
  const additions = [];
  const positions = [...new Set(POS)];
  const groups = [
    { name: 'u18', owns: age => age <= 18, ages: [17, 18] },
    { name: 'u21', owns: age => age >= 19 && age <= 21, ages: [19, 20, 21] },
  ];
  let serial = 60000;
  for (const { name, owns, ages } of groups) {
    for (const pos of positions) {
      const slots = POS.flatMap((position, slot) => position === pos ? [slot] : []);
      const current = academy.academy.filter(player => player.pos === pos && owns(player.age));
      const counts = ages.map(age => current.filter(player => player.age === age).length);
      for (let missing = current.length; missing < 2 * slots.length; missing++) {
        let index = 0;
        if (initial || name === 'u18') {
          for (let i = 1; i < counts.length; i++) {
            if (counts[i] < counts[index]) index = i;
          }
        }
        const player = academyPlayer(S.club, slots[missing % slots.length], S.season, serial++);
        player.age = ages[index];
        counts[index]++;
        additions.push(player);
      }
    }
  }
  if (academy.academy.length + additions.length > 75) throw Error('Appoint au-delà du plafond de 75.');
  academy.academy.push(...additions);
  academy.intakeSeason = S.season;
}

function groupReport(state) {
  const positions = JSON.parse(run('JSON.stringify(POS)'));
  const players = state.development.academy;
  assert.ok(players.length <= 75);
  const u18 = players.filter(player => player.age <= 18);
  const u21 = players.filter(player => player.age >= 19 && player.age <= 21);
  assert.equal(u18.length + u21.length, players.length);
  assert.equal(new Set(players.map(p => p.id)).size, players.length);
  for (const group of [u18, u21]) {
    assert.ok(group.length >= 30);
    for (const pos of new Set(positions)) {
      assert.ok(group.filter(p => p.pos === pos).length >= 2 * positions.filter(p => p === pos).length, pos);
    }
  }
  return { u18: u18.length, u21: u21.length };
}

function verifyIdentities(state) {
  const contracted = state.clubs.flatMap(c => c.players);
  const pool = state.economy.freeAgents;
  const active = [...contracted, ...pool, ...state.development.academy, ...state.aiRoster.academies.flatMap(a => a.players)];
  assert.equal(new Set(active.map(p => p.id)).size, active.length);
  assert.ok(pool.every(p => p.contractEnd === null && !p.academy));
  assert.ok(pool.length <= run('aiRosterFreeAgentLimit()'));
  const byId = new Map(active.map(p => [p.id, p]));
  for (const candidate of state.market) assert.deepEqual(byId.get(candidate.id), candidate);
  return { active: active.length, market: state.market.length };
}

function verifyWorkerRoundTrip(archive, label, seed) {
  const options = { dataDir: path.join(audit, label), seed, now: 1794178800000 };
  fs.mkdirSync(options.dataDir);
  let bridge = createBridge(options);
  let sequence = 0;
  function request(command, payload = {}) {
    const result = bridge.handle({ id: ++sequence, command, payload });
    assert.equal(result.ok, true, `${command}: ${result.error}`);
    return result.model;
  }
  try {
    request('import', { text: archive });
    const saved = request('export').meta.exportText;
    const state = JSON.parse(saved).state;
    for (const key of ['development', 'clubs', 'market', 'aiRoster']) {
      assert.deepEqual(state[key], JSON.parse(archive).state[key]);
    }
    bridge.close();
    bridge = createBridge(options);
    assert.equal(request('export').meta.exportText, saved);
    return saved;
  } finally {
    bridge.close();
  }
}

function resumePilot(archive, seed) {
  const resumed = context(seed);
  resumed.ctx.pilotArchive = archive;
  resumed.run(`pendingSave = parseSaveDocument(pilotArchive);
    if (!confirmSaveImport()) throw Error('Reprise VM du pilote refusée.');
    intakeYouth = (${intakeGroups.toString()});`);
  return resumed;
}

run('start(0)');
const initial = vm.state();
assert.equal(initial.development.academy.length, 15);
const initialIds = new Set(initial.development.academy.map(player => player.id));
run(`const intakeGroups = (${intakeGroups.toString()}); intakeGroups({initial:true}); intakeYouth = intakeGroups;`);
assert.deepEqual(vm.state().development.academy.filter(p => initialIds.has(p.id)), initial.development.academy);
assert.deepEqual(vm.state().clubs, initial.clubs);
assert.deepEqual(vm.state().market, initial.market);

const results = [];
const graduatesSeen = new Set();
for (let season = 1; season <= 4; season++) {
  const before = vm.state();
  const groups = groupReport(before);
  assert.equal(run('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'), true);
  const supply = verifyIdentities(before);
  for (const player of before.economy.freeAgents) {
    if (player.population?.origin === 'academy' && player.population.clubId === before.club) graduatesSeen.add(player.id);
  }
  results.push({ season, ...groups, ...supply, graduatesSeen: graduatesSeen.size });
  if (season === 4) break;
  if (season === 2) {
    const archive = run('JSON.stringify(createSaveDocument())');
    const seed = vm.seed();
    const saved = verifyWorkerRoundTrip(archive, 'profil-s2', seed);
    vm = resumePilot(saved, seed);
    run = vm.run;
    for (const key of ['development', 'clubs', 'market', 'aiRoster']) {
      assert.deepEqual(vm.state()[key], before[key]);
    }
    assert.equal(vm.seed(), seed);
  }
  run('while(S.phase!=="ended")finishRound();');
  const end = vm.state();
  run('advanceSeason();');
  const after = vm.state();
  assert.equal(after.season, season + 1);
  const stillInAcademy = new Map(after.development.academy.map(p => [p.id, p]));
  for (const player of end.development.academy.filter(p => p.age < 21)) {
    const survivor = stillInAcademy.get(player.id);
    assert.ok(survivor, player.id);
    assert.equal(survivor.age, player.age + 1);
    assert.equal(survivor.appearanceBankVersion, player.appearanceBankVersion);
  }
  for (const player of end.development.academy.filter(p => p.age === 21)) {
    assert.equal(stillInAcademy.has(player.id), false);
    assert.ok(after.economy.freeAgents.some(p => p.id === player.id) || after.clubs.some(c => c.players.some(p => p.id === player.id)), player.id);
  }
}
assert.ok(graduatesSeen.size > 0);

const saved = verifyWorkerRoundTrip(run('JSON.stringify(createSaveDocument())'), 'profil-s4', vm.seed());
const receipt = { fourSeasons: results, workerImportAndReopen: [2, 4], continuedFromWorkerSave: 2,
  bytes: Buffer.byteLength(saved),
  scope: 'Pilotage local du centre humain en Fiction. Le worker reçoit deux fixtures. La politique de génération n’est activée dans aucun produit.' };
fs.writeFileSync(path.join(audit, 'rapport.json'), JSON.stringify(receipt, null, 2) + '\n');
console.log(JSON.stringify(receipt));
console.log(path.join(audit, 'rapport.json'));

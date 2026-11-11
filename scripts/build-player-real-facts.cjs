'use strict';

const fs = require('node:fs');
const path = require('node:path');

const root = path.join(__dirname, '..');
const read = file => JSON.parse(fs.readFileSync(path.join(root, file), 'utf8'));
const target = path.join(root, 'native/engine/player-real-facts.json');
const fields = new Set(['heightCm', 'weightKg', 'nationality', 'flagCode', 'seniorCaps', 'seniorNation', 'eligibilityNations']);
const snapshot = '2026-11-10';
const countryCode = /^[a-z]{2}$|^gb-(eng|sct|wls)$/;
const teamCode = /^[A-Z]{3}$/;
const datePattern = /^20\d{2}-\d{2}-\d{2}$/;
const digest = /^[a-f0-9]{64}$/;
const sourceCode = /^[a-z][a-z0-9-]{1,55}$/;
const inRange = (value, low, high) => Number.isInteger(value) && value >= low && value <= high;
const object = value => value && typeof value === 'object' && !Array.isArray(value);

function knownIds() {
  const registries = ['world-registry', 'world-pacific-extension', 'world-japan-extension', 'world-nationale-extension', 'world-champ-extension'];
  return new Set(registries.flatMap(registry => read(`native/engine/${registry}.json`).clubs
    .flatMap(club => club.players.map(player => player.id))));
}

function validFacts(facts) {
  return Object.keys(facts).length > 0 && Object.keys(facts).every(field => fields.has(field)) &&
    (!('heightCm' in facts) || inRange(facts.heightCm, 140, 235)) &&
    (!('weightKg' in facts) || inRange(facts.weightKg, 50, 190)) &&
    (!('nationality' in facts) || typeof facts.nationality === 'string' && /^[\p{L} .’'-]{2,56}$/u.test(facts.nationality)) &&
    (!('flagCode' in facts) || typeof facts.flagCode === 'string' && countryCode.test(facts.flagCode) && 'nationality' in facts) &&
    (!('seniorCaps' in facts) || inRange(facts.seniorCaps, 0, 300)) &&
    (facts.seniorCaps > 0 ? typeof facts.seniorNation === 'string' && teamCode.test(facts.seniorNation) : !('seniorNation' in facts)) &&
    (!('eligibilityNations' in facts) || Array.isArray(facts.eligibilityNations) && facts.eligibilityNations.length > 0 &&
      facts.eligibilityNations.every(code => typeof code === 'string' && teamCode.test(code)) &&
      facts.eligibilityNations.length === new Set(facts.eligibilityNations).size);
}

function build(evidence = read('data/player-real-facts/observations.json')) {
  if (!object(evidence) || evidence.schemaVersion !== 1 || evidence.snapshot !== snapshot || !object(evidence.sources) || !Array.isArray(evidence.observations)) {
    throw Error('Dossier de preuves des joueurs invalide.');
  }
  for (const [id, source] of Object.entries(evidence.sources)) {
    if (!sourceCode.test(id) || !object(source) || !datePattern.test(source.observedOn) || source.observedOn > snapshot ||
      typeof source.publisher !== 'string' || !['club-profile', 'league-profile', 'national-xv'].includes(source.scope)) {
      throw Error(`Source des joueurs invalide : ${id}`);
    }
  }
  const ids = knownIds();
  const players = new Map();
  for (const row of evidence.observations) {
    if (!Array.isArray(row) || row.length < 3 || row.length > 4) throw Error('Observation joueur invalide.');
    const [id, source, facts, sha256] = row;
    if (!ids.has(id) || !Object.hasOwn(evidence.sources, source) || !object(facts) || !validFacts(facts) ||
      (sha256 !== undefined && (typeof sha256 !== 'string' || !digest.test(sha256))) ||
      (('seniorCaps' in facts || 'eligibilityNations' in facts) && evidence.sources[source].scope !== 'national-xv')) {
      throw Error(`Observation joueur invalide : ${id}`);
    }
    const previous = players.get(id) ?? {};
    if (Object.keys(facts).some(field => Object.hasOwn(previous, field))) {
      throw Error(`Champ joueur renseigné plusieurs fois : ${id}`);
    }
    players.set(id, { ...previous, ...facts });
  }
  const sorted = [...players].sort(([a], [b]) => Number(a > b) - Number(a < b));
  return { schemaVersion: 1, snapshot, players: Object.fromEntries(sorted) };
}

function serialize({ schemaVersion, snapshot: day, players }) {
  const rows = Object.entries(players).map(([id, facts]) => `    ${JSON.stringify(id)}: ${JSON.stringify(facts)}`);
  return `{"schemaVersion":${schemaVersion},"snapshot":${JSON.stringify(day)},"players":{\n${rows.join(',\n')}\n}}\n`;
}

if (require.main === module) {
  const output = serialize(build());
  if (process.argv.includes('--check')) {
    if (fs.readFileSync(target, 'utf8').replace(/\r\n/g, '\n') !== output) throw Error('Catalogue des faits joueurs périmé.');
  } else {
    fs.writeFileSync(target, output);
  }
}

module.exports = { build, knownIds };

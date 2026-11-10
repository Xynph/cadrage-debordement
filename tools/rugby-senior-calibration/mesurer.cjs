'use strict';

const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const { anchors, prepare, roleNote } = require('./prototype.cjs');

const [input, overridesFile, evidenceRoot] = process.argv.slice(2);
assert.ok(input && overridesFile && evidenceRoot, 'Usage : mesurer.cjs sauvegarde-neuve dérogations dossier-preuves');
const original = fs.readFileSync(input);
const envelope = JSON.parse(original);
const state = JSON.parse(envelope.store['bdt-v1']);
const overrides = JSON.parse(fs.readFileSync(overridesFile, 'utf8'));
const variant = prepare(state, overrides);
const output = fs.mkdtempSync(path.join(path.resolve(evidenceRoot), 'comparaison-'));
const directory = path.join(output, 'PrototypeGodot');
fs.mkdirSync(directory);
const candidate = path.join(directory, 'donnees.json');
fs.writeFileSync(candidate, JSON.stringify({ ...envelope, store: { ...envelope.store, 'bdt-v1': JSON.stringify(variant) } }), { flag: 'wx' });

function stats(values) {
  const sorted = values.slice().sort((a, b) => a - b);
  const q = percentile => sorted[Math.floor((sorted.length - 1) * percentile)];
  return {
    count: sorted.length, min: q(0), p10: q(.1), median: q(.5), p90: q(.9), p95: q(.95), max: q(1),
    spread: q(.9) - q(.1), upperSpread: q(.95) - q(.1), gt90: sorted.filter(v => v > 90).length,
    mean: Math.round(100 * sorted.reduce((total, value) => total + value, 0) / sorted.length) / 100,
  };
}

const players = (source, filter = () => true) => source.clubs.flatMap(club =>
  club.players.filter(p => filter(p, club.id)));
function compare(filter) {
  const before = players(state, filter), after = players(variant, filter);
  return {
    rating: [stats(before.map(p => p.rating)), stats(after.map(p => p.rating))],
    note: [stats(before.map(p => roleNote(p))), stats(after.map(p => roleNote(p)))],
  };
}
const leagues = Object.fromEntries(Object.entries(state.worldMode.leagues).map(
  ([league, division]) => [league, compare((_, club) => division.members.includes(club))]
));
const roles = Object.fromEntries([...new Set(players(state).map(p => p.pos))].map(
  role => [role, compare(p => p.pos === role)]
));
const byScore = p => ({ id: p.id, rating: p.rating, note: roleNote(p), pos: p.pos });
const report = {
  source: input, candidate, sourceSha256: crypto.createHash('sha256').update(original).digest('hex'),
  anchors, global: compare(), leagues, roles,
  topGlobal: players(variant).map(byScore).sort((a, b) => b.rating - a.rating || a.id.localeCompare(b.id)).slice(0, 20),
  topRole: players(variant).map(byScore).sort((a, b) => b.note - a.note || a.id.localeCompare(b.id)).slice(0, 20),
  overrides: Object.keys(overrides).map(id => [state, variant].map(s => {
    const all = players(s), target = all.find(p => p.id === id);
    const sameRole = all.filter(p => p.pos === target.pos);
    return { ...byScore(target), globalRank: 1 + sameRole.filter(p => p.rating > target.rating).length,
      roleRank: 1 + sameRole.filter(p => roleNote(p) > roleNote(target)).length,
      skills: target.skills, attributes: target.attributesV2 };
  })),
};
assert.deepEqual(fs.readFileSync(input), original);
fs.writeFileSync(path.join(output, 'mesures.json'), JSON.stringify(report, null, 2));
console.log(JSON.stringify({ candidate, output, global: report.global, overrides: report.overrides.map(group =>
  group.map(({ rating, note, globalRank, roleRank }) => ({ rating, note, globalRank, roleRank }))) }, null, 2));

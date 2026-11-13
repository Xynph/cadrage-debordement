'use strict';
process.env.CD_MODES_HERITES='1'; // Anciens modes de carrière (non-Monde) : test à migrer vers le mode Monde.
const {settleClubMeetings}=require('./helpers/club-meetings.cjs');

const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const {test} = require('node:test');
const {createBridge} = require('../native/engine/worker.cjs');
const {crc32} = require('../native/engine/media-packs.cjs');
const world = require('../native/engine/world-registry.json');

const club = world.clubs[30];
const player = club.players[0];
const pixel = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/l9sAAAAASUVORK5CYII=', 'base64');
const hash = crypto.createHash('sha256').update(pixel).digest('hex');

function zip(entries) {
 const local = [];
 const central = [];
 let offset = 0;
 for (const [filename, data] of entries) {
  const name = Buffer.from(filename);
  const head = Buffer.alloc(30);
  const record = Buffer.alloc(46);
  const crc = crc32(data);
  head.writeUInt32LE(0x04034b50);
  head.writeUInt16LE(20, 4);
  head.writeUInt32LE(crc, 14);
  head.writeUInt32LE(data.length, 18);
  head.writeUInt32LE(data.length, 22);
  head.writeUInt16LE(name.length, 26);
  record.writeUInt32LE(0x02014b50);
  record.writeUInt16LE(20, 6);
  record.writeUInt32LE(crc, 16);
  record.writeUInt32LE(data.length, 20);
  record.writeUInt32LE(data.length, 24);
  record.writeUInt16LE(name.length, 28);
  record.writeUInt32LE(offset, 42);
  local.push(head, name, data);
  central.push(record, name);
  offset += head.length + name.length + data.length;
 }
 const directory = Buffer.concat(central);
 const end = Buffer.alloc(22);
 end.writeUInt32LE(0x06054b50);
 end.writeUInt16LE(entries.length, 8);
 end.writeUInt16LE(entries.length, 10);
 end.writeUInt32LE(directory.length, 12);
 end.writeUInt32LE(offset, 16);
 return Buffer.concat([...local, directory, end]);
}

function withPack(verify) {
 const parent = fs.realpathSync.native(process.env.CD_WORLD_TEST_ROOT || os.tmpdir());
 const root = fs.realpathSync.native(fs.mkdtempSync(path.join(parent, 'cd-world-media-adversarial-')));
 assert.equal(path.dirname(root), parent);
 assert.match(path.basename(root), /^cd-world-media-adversarial-[a-z0-9]+$/i);
 let bridge;
 try {
  const profile = path.join(root, 'profile');
  bridge = createBridge({dataDir: profile, seed: 741, now: 1794178800000});
  let seq = 0;
  const call = (command, payload = {}) => bridge.handle({id: ++seq, command, payload});
  const go = (command, payload = {}) => {
   const result = call(command, payload);
   assert.equal(result.ok, true, command + ' : ' + result.error);
   return result.model;
  };
  const manifest = {
   schema: 'cd-identity-pack-v2', id: 'world-adversarial', name: 'Pack témoin',
   version: '1', databaseId: world.id, rightsStatus: 'test-local',
   clubs: [{id: club.id, name: 'Club du pack', abbr: 'CDP', logo: 'pixel'}],
   players: [{id: player.id, name: 'Joueur du pack', portrait: 'pixel', synthetic: true}],
   staff: [], assets: [{id: 'pixel', path: 'image.png', sha256: hash, bytes: pixel.length}],
  };
  const archive = path.join(root, 'pack.zip');
  fs.writeFileSync(archive, zip([['pack.json', Buffer.from(JSON.stringify(manifest))], ['image.png', pixel]]));
  const model = settleClubMeetings(go('new_career', {mode: 'world', club: club.id}),(command,payload)=>go(command,payload));
  const preview = go('pack_inspect', {path: archive, mode: 'world'}).packs.preview;
  go('pack_install', {path: archive, digest: preview.digest, mode: 'world'});
  const folder = path.join(model.meta.dataDir, 'packs', preview.id);
  verify({call, go, packId: preview.id, manifestFile: path.join(folder, 'manifest.json'), imageFile: path.join(folder, hash + '.png')});
 } finally {
  if (bridge) bridge.close();
  fs.rmSync(root, {recursive: true, force: true});
 }
}

test('Un pack mondial inactif ne relit pas les médias à chaque projection', () => withPack(({go, packId, imageFile}) => {
 const warm = go('snapshot');
 assert.equal(warm.packs.career, 'base');
 assert.equal(warm.meta.worldPackCreation, 'base');
 assert.ok(warm.packs.installed.some(p => p.id === packId));
 const target = path.resolve(imageFile);
 const original = fs.lstatSync;
 let calls = 0;
 fs.lstatSync = function tracked(file, ...args) {
  if (typeof file === 'string' && path.resolve(file) === target) calls++;
  return original.call(this, file, ...args);
 };
 let snapshot;
 try {
  snapshot = go('snapshot');
 } finally {
  fs.lstatSync = original;
 }
 assert.ok(snapshot.packs.installed.some(p => p.id === packId));
 assert.equal(calls, 0, 'L’inventaire inactif ne consulte pas le fichier image');
}));

for (const [field, corrupt] of [
 ['joueur', manifest => { manifest.players[player.id].portraitStatus = 'nonexistent'; }],
 ['club', manifest => { manifest.clubs[club.id].abbr = 'INVALIDE!'; }],
]) {
 test(`Un manifeste installé avec un ${field} invalide est écarté`, () => withPack(({go, packId, manifestFile}) => {
  const active = settleClubMeetings(go('pack_select', {scope: 'career', id: packId}),(command,payload)=>go(command,payload));
  assert.equal(active.club.name, 'Club du pack');
  const installed = JSON.parse(fs.readFileSync(manifestFile, 'utf8'));
  corrupt(installed);
  fs.writeFileSync(manifestFile, JSON.stringify(installed));
  const fallback = go('snapshot');
  assert.ok(!fallback.packs.installed.some(p => p.id === packId), 'Le manifeste invalide disparaît des packs installés');
  assert.equal(fallback.club.name, club.name);
  assert.equal(fallback.squad.find(p => p.id === player.id).name, player.name);
  assert.equal(fallback.packs.career, packId, 'La référence de carrière peut être réparée par réimport');
  assert.ok(fallback.packs.missing.length > 0);
 }));
}

test('Sélection, carrière et création contrôlent le contenu du média', () => withPack(({call, go, packId, imageFile}) => {
 const corrupt = Buffer.from(pixel);
 corrupt[corrupt.length - 1] ^= 1;
 fs.writeFileSync(imageFile, corrupt);
 const rejected = call('pack_select', {scope: 'career', id: packId});
 assert.equal(rejected.ok, false, 'Sélection refusée après corruption de taille identique');
 fs.writeFileSync(imageFile, pixel);
 assert.equal(settleClubMeetings(go('pack_select', {scope: 'career', id: packId}),(command,payload)=>go(command,payload)).club.name, 'Club du pack');
 fs.unlinkSync(imageFile);
 assert.equal(go('snapshot').club.name, club.name, 'Repli si le média actif disparaît');
 fs.writeFileSync(imageFile, pixel);
 settleClubMeetings(go('pack_select', {scope: 'career', id: 'base'}),(command,payload)=>go(command,payload));
 assert.equal(settleClubMeetings(go('pack_select', {scope: 'creation', mode: 'world', id: packId}),(command,payload)=>go(command,payload)).meta.worldCatalogue[club.id].name, 'Club du pack');
 fs.writeFileSync(imageFile, corrupt);
 const fallback = go('snapshot');
 assert.equal(fallback.meta.worldCatalogue[club.id].name, club.name, 'Repli si le média de création est corrompu');
 assert.ok(fallback.packs.missing.length > 0);
}));

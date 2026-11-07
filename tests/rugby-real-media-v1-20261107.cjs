'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const root = path.resolve(__dirname, '..');
const read = p => fs.readFileSync(path.join(root, p));
const master = JSON.parse(read('modding/data06/rugby-master-2026-2027.json'));
const m = JSON.parse(read('data/scouting/media-v1-20261107.json'));
assert.equal(m.schema, 'rugby-real-media-originals-v1');
assert.equal(m.productionAssetsChanged, false);
assert.equal(m.referenceRosterSha256, crypto.createHash('sha256').update(read('modding/data06/rugby-master-2026-2027.json')).digest('hex'));
const players = m.entries.filter(e => e.kind === 'portrait');
const logos = m.entries.filter(e => e.kind === 'logo');
assert.equal(players.length, 1592); assert.equal(logos.length, 30);
assert.equal(new Set(players.map(e => e.id)).size, players.length);
assert.equal(new Set(logos.map(e => e.club)).size, 30);
const map = new Map(players.map(e => [e.id,e]));
for (const p of master.players) {
 const e = map.get(p.id); assert.ok(e, p.id); assert.equal(e.name,p.realName); assert.equal(e.club,p.club); assert.equal(e.league,p.league);
}
assert.deepEqual(new Set(logos.map(e => e.club)), new Set(master.players.map(p => p.club)));
const paths = new Set(), hashes = new Set(); let real=0, missing=0, club=0, bytes=0;
for (const e of m.entries) {
 assert.equal(e.rightsStatus,'not-cleared-for-public-distribution');
 assert.ok(/^https:\/\//.test(e.sourcePage), e.id+' source');
 if (e.status === 'downloaded') {
  assert.ok(/^https:\/\//.test(e.url)); assert.ok(/^[a-f0-9]{64}$/.test(e.sha256));
  assert.ok(Number.isInteger(e.width) && e.width>0 && Number.isInteger(e.height) && e.height>0); assert.ok(e.bytes>0);
  assert.ok(/^(players|logos)\/[a-z0-9-]+\/[a-z0-9-]+\/[a-z0-9-]+\.(webp|png|jpg|gif|avif)$/.test(e.path));
  assert.ok(!paths.has(e.path)); paths.add(e.path); bytes+=e.bytes;
  if (e.kind==='portrait') {
   assert.equal(e.available,true); assert.notEqual(e.sha256,'60a0c0dc2df281db65ad3183dc7aa79ea1ee0d14bb583ff0d0cbc086cf5fd406');
   assert.ok(!e.url.includes('no-avatar')); assert.ok(!hashes.has(e.sha256),'same image assigned twice'); hashes.add(e.sha256); real++;
   assert.ok(e.identityMatch && e.jerseyStatus && e.portraitStyle); if(e.sourceKind==='official-club')club++;
  }
 } else {
  assert.equal(e.kind,'portrait'); assert.equal(e.status,'unavailable'); assert.equal(e.available,false); assert.equal(e.path,null); assert.ok(e.reason); missing++;
 }
}
assert.equal(missing,m.missing.length); assert.deepEqual(new Set(m.missing.map(e=>e.id)),new Set(players.filter(e=>!e.available).map(e=>e.id)));
assert.equal(real,m.summary.realPortraits); assert.equal(missing,m.summary.playersUnresolved); assert.equal(club,m.summary.officialClubFallbacks);assert.equal(bytes,m.summary.bytes);
assert.equal(real+missing,1592); assert.equal(m.summary.logosDownloaded,30);
console.log('RUGBY_REAL_MEDIA_QA '+JSON.stringify({clubs:30,players:1592,realPortraits:real,unresolved:missing,officialClubFallbacks:club,productionAssetsChanged:false}));

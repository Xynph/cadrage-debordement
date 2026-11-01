'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const read = p => JSON.parse(fs.readFileSync(path.join(root, p), 'utf8'));
const wiki = read('modding/data06/birthyears-six-clubs-verified-2026-11-01.json');
const its = read('modding/data06/birthyears-itsrugby-verified-2026-11-01.json');
const records = [...wiki.records, ...its.records];
const decode = s => s.replace(/&#0*39;/g, "'").replace(/&amp;/g, '&');
const key = s => decode(s).normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase().replace(/[^a-z0-9]+/g, ' ').trim();
const catalog = ['top14-a','top14-b','prod2-a','prod2-b'].flatMap(f => read('modding/data03/' + f + '.json').clubs.flatMap(c => c.players.map(p => ({...p, club:c.club}))));
const previous = read('modding/data06/rugbydata-birthyear-coverage-audit-2026-11-01.json').linked;
const diogo = read('modding/data06/rugbydata-birthyear-dax-diogo-2026-11-01.json').records;
const known = new Set([...previous, ...diogo].map(p => p.lnrId));

test('each new year has exactly one existing LNR identity, club and canonical URL', () => {
  assert.equal(catalog.length, 1592);
  assert.equal(new Set(catalog.map(p => p.id)).size, 1592);
  for (const r of records) {
    const matches = catalog.filter(p => p.id === r.lnrId);
    assert.equal(matches.length, 1, r.lnrId);
    assert.equal(r.club, matches[0].club);
    assert.equal(key(r.lnrName), key(matches[0].name));
    assert.equal(r.lnrUrl, matches[0].url);
  }
});

test('the two supplements add only previously missing years, without duplicate IDs', () => {
  assert.equal(known.size, 895);
  assert.equal(new Set(records.map(p => p.lnrId)).size, records.length);
  for (const r of records) assert.equal(known.has(r.lnrId), false, r.lnrId);
});

test('each retained year is an explicit source fact, with no contradictory evidence', () => {
  for (const r of records) {
    assert.ok(Number.isInteger(r.birthYear) && r.birthYear >= 1980 && r.birthYear <= 2011);
    assert.ok(r.evidence.length > 0);
    for (const e of r.evidence) {
      assert.equal(e.birthYear, r.birthYear, r.lnrId);
      assert.ok(e.dateAsPublished.includes(String(r.birthYear)), r.lnrId);
    }
    assert.equal(r.validAtCareerStart, null);
  }
});

test('six permanent revisions explicitly identify the season and retain verifiable receipts', () => {
  const sources = wiki.sources.filter(s => s.kind === 'wikipedia-roster-permalink');
  assert.equal(sources.length, 6);
  assert.deepEqual(sources.map(s => s.club).sort(), ['angouleme','dax','narbonne','nevers','nice','valence-romans']);
  for (const s of sources) {
    assert.equal(s.seasonAsPublished, '2026-2027');
    assert.equal(s.heading, 'Effectif 2026-2027');
    assert.equal(s.currentAndPermanentRowsEqual, true);
    assert.match(s.revisionId, /^\d+$/);
    assert.ok(s.url.includes('oldid=' + s.revisionId));
    assert.ok(s.pageModified.startsWith('2026-'));
  }
  for (const s of wiki.sources) {
    assert.match(s.htmlSha256, /^[a-f0-9]{64}$/);
    assert.equal(s.observedDate, '2026-11-01');
  }
});

test('every Wikipedia or official observation resolves to its source and exact name or explicit full name', () => {
  const sources = new Map(wiki.sources.map(s => [s.id,s]));
  assert.equal(sources.size, wiki.sources.length);
  for (const r of wiki.records) {
    for (const e of r.evidence) assert.ok(sources.has(e.sourceId), r.lnrId);
    if (r.identityMethod === 'explicit-full-name') {
      assert.equal(key(r.identityNameAsPublished), key(r.lnrName));
    } else {
      assert.equal(r.identityMethod, 'exact-normalized-name-and-club');
      for (const e of r.evidence) assert.equal(key(e.nameAsPublished), key(r.lnrName));
    }
  }
});

test('Levron is resolved by the official club and the unresolved Idrissi duplicate is excluded', () => {
  const r = records.find(p => p.lnrId === 'lnr:1932');
  assert.equal(r.birthYear, 2000);
  assert.ok(wiki.sources.some(s => s.kind === 'official-club' && s.url.includes('section-paloise.com') && r.evidence.some(e => e.sourceId === s.id)));
  assert.equal(records.some(p => p.lnrId === 'lnr:11779'), false);
  assert.ok(wiki.conflicts.some(c => c.lnrId === 'lnr:11779' && c.status === 'unresolved-excluded'));
});

test('ItsRugby individual schema names, valid dates and stable source IDs agree with the roster identity', () => {
  const ids = new Set();
  for (const r of its.records) {
    assert.equal(r.identityMethod, 'exact-normalized-name-club-and-source-id');
    assert.equal(ids.has(r.sourceRecordId), false);
    ids.add(r.sourceRecordId);
    const e = r.evidence[0];
    assert.equal(e.schemaType, 'Person');
    assert.equal(key(e.nameAsPublished), key(r.lnrName));
    assert.equal(key(r.sourceRosterObservation.name), key(r.lnrName));
    assert.equal(r.sourceRosterObservation.club, r.club);
    assert.equal(r.sourceRosterObservation.sourceRecordId, r.sourceRecordId);
    assert.match(e.dateAsPublished, /^(19\d{2}|200\d|201[01])-\d{2}-\d{2}$/);
    const date = new Date(e.dateAsPublished + 'T00:00:00.000Z');
    assert.equal(date.toISOString().slice(0,10), e.dateAsPublished);
    assert.equal(date.getUTCFullYear(), r.birthYear);
    assert.ok(e.sourceUrl.endsWith('-' + r.sourceRecordId + '/'));
    assert.match(e.htmlSha256, /^[a-f0-9]{64}$/);
    assert.equal(e.observedDate, '2026-11-01');
    assert.equal(r.sourceRosterEvidence.pr, 155);
    assert.equal(r.sourceRosterEvidence.copiedUnchangedInPr, 158);
  }
});

test('all 210 attempted profiles are accounted for, and rejected dates cannot enter the supplement', () => {
  assert.equal(its.attempts.length, 210);
  assert.equal(new Set(its.attempts.map(a => a.lnrId)).size, 210);
  assert.equal(its.summary.attempted, its.attempts.length);
  assert.equal(its.summary.newYears, its.records.length);
  assert.equal(Object.values(its.summary.outcomes).reduce((a,b) => a+b, 0), its.attempts.length);
  for (const a of its.attempts) {
    assert.notEqual(a.status, 'not-completed');
    assert.equal(its.records.some(r => r.lnrId === a.lnrId), a.status === 'new-verified-year');
  }
});

test('repeated source IDs across clubs only identify one exact LNR name and never imply historical membership', () => {
  const repeated = its.records.filter(r => r.sourceRosterOccurrences.length > 1);
  assert.equal(repeated.length, 13);
  for (const r of repeated) {
    assert.equal(catalog.filter(p => key(p.name) === key(r.lnrName)).length, 1);
    for (const source of r.sourceRosterOccurrences) {
      assert.equal(key(source.name), key(r.lnrName));
      assert.equal(source.sourceRecordId, r.sourceRecordId);
    }
    assert.equal(r.validAtCareerStart, null);
  }
});

test('the supplements preserve the baseline and produce a bounded coverage total', () => {
  assert.equal(previous.length, 894);
  assert.ok(records.length > 200);
  const total = known.size + records.length;
  assert.ok(total <= 1592);
  console.log(JSON.stringify({newYears:records.length, linkedYears:total, missingYears:1592-total}));
});

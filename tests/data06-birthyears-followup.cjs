'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const read = f => JSON.parse(fs.readFileSync(path.join(root, f), 'utf8'));
const data = read('modding/data06/birthyears-followup-2026-11-01.json');
const decode = s => s.replace(/&#0*39;/g, "'").replace(/&amp;/g, '&');
const key = s => decode(s).normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase().replace(/[^a-z0-9]+/g, ' ').trim();
const catalog = ['top14-a','top14-b','prod2-a','prod2-b'].flatMap(f => read('modding/data03/' + f + '.json').clubs.flatMap(c => c.players.map(p => ({...p, club:c.club}))));
const previous = data.baselineFiles.flatMap(f => {const d=read('modding/data06/'+f);return d.records || d.linked;});
const known = new Set(previous.map(r => r.lnrId));
function explicitComponents(lnr, published) {
  const expected = key(lnr).split(' '), actual = key(published).split(' ');
  if (expected.length < 2 || expected[0] !== actual[0]) return false;
  let start = 0;
  for (const name of expected) {
    const index = actual.indexOf(name, start);
    if (index < 0) return false;
    start = index + 1;
  }
  return true;
}
function identity(lnr, published) {
  return key(lnr) === key(published) || key(lnr).replaceAll(' ','') === key(published).replaceAll(' ','') || explicitComponents(lnr, published);
}

test('every new birth year has one exact catalog ID, club, name and URL', () => {
  assert.equal(catalog.length, 1592);
  assert.equal(new Set(catalog.map(p => p.id)).size, 1592);
  for (const r of data.records) {
    const matches = catalog.filter(p => p.id === r.lnrId);
    assert.equal(matches.length, 1);
    assert.equal(matches[0].club, r.club);
    assert.equal(key(matches[0].name), key(r.lnrName));
    assert.equal(matches[0].url, r.lnrUrl);
  }
});

test('the followup adds only previously missing LNR years and no duplicate identity or source ID', () => {
  assert.equal(known.size, 1245);
  assert.equal(new Set(data.records.map(r => r.lnrId)).size, data.records.length);
  const sourceIds = data.records.filter(r => r.rugbyDataId).map(r => r.rugbyDataId);
  assert.equal(new Set(sourceIds).size, sourceIds.length);
  for (const r of data.records) assert.equal(known.has(r.lnrId), false, r.lnrId);
});

test('published full names independently resolve to one LNR identity, including additional middle names', () => {
  const allowed = new Set(['exact-normalized-published-name','same-name-typography-only','explicit-published-name-components']);
  for (const r of data.records) {
    assert.ok(allowed.has(r.identityMethod));
    const matches = catalog.filter(p => identity(p.name, r.identityNameAsPublished));
    assert.deepEqual(matches.map(p => p.id), [r.lnrId]);
    if (r.identityMethod === 'exact-normalized-published-name') assert.equal(key(r.lnrName),key(r.identityNameAsPublished));
    if (r.identityMethod === 'same-name-typography-only') assert.equal(key(r.lnrName).replaceAll(' ',''),key(r.identityNameAsPublished).replaceAll(' ',''));
    if (r.identityMethod === 'explicit-published-name-components') assert.ok(explicitComponents(r.lnrName,r.identityNameAsPublished));
  }
  assert.equal(identity('Giorgi Zazadze','Rati Zazadze'),false);
  assert.equal(identity('Sandro Dubois Martin','Karl Martin'),false);
  assert.equal(identity('Harrison Asi','Braxton Lua Asi'),false);
  assert.equal(identity('Jason-colin Fraser','Jason-Collin Fraser'),false);
});

test('every year is literally published and all retained source years agree; no exact date is manufactured', () => {
  for (const r of data.records) {
    assert.ok(Number.isInteger(r.birthYear) && r.birthYear >= 1980 && r.birthYear <= 2011);
    assert.equal(r.birthDate, null);
    assert.equal(r.validAtCareerStart, null);
    assert.ok(r.evidence.length > 0);
    for (const e of r.evidence) {
      assert.equal(e.birthYear, r.birthYear, r.lnrId);
      assert.ok(e.dateAsPublished.includes(String(r.birthYear)),r.lnrId);
      assert.equal(e.observedDate,'2026-11-01');
      assert.ok(e.url.startsWith('https://'));
      if (e.htmlSha256) assert.match(e.htmlSha256,/^[a-f0-9]{64}$/);
      if (e.pdfSha256) assert.match(e.pdfSha256,/^[a-f0-9]{64}$/);
    }
  }
});

test('Rugby Data evidence binds the observed profile ID to a published full name and original roster', () => {
  const attempts = new Map(data.rugbyDataAttempts.map(a=>[a.lnrId,a]));
  for (const r of data.records.filter(r => r.rugbyDataId)) {
    const a = attempts.get(r.lnrId);
    assert.equal(a.status,'new-year-verified');
    assert.equal(a.sourceRecordId,r.rugbyDataId);
    const e = r.evidence.find(e=>e.kind==='rugbydata-individual-profile');
    assert.equal(e.url,'https://www.rugbydata.fr/players/view/'+r.rugbyDataId);
    assert.equal(e.fullNameAsPublished,r.identityNameAsPublished);
    assert.equal(e.sourceRecordId,r.rugbyDataId);
    assert.ok(r.sourceClubAsPublished.startsWith('https://www.rugbydata.fr/club/effectif/panel/'));
    assert.ok(r.sourceRosterNameAsPublished.length>0);
    assert.match(e.dateAsPublished,/^\d{2}\/\d{2}\/(19\d{2}|200\d|201[01])$/);
    const [day,month,year]=e.dateAsPublished.split('/');
    assert.equal(new Date(`${year}-${month}-${day}T00:00:00.000Z`).toISOString().slice(0,10),`${year}-${month}-${day}`);
    assert.equal(e.januaryFirstAsPublished,e.dateAsPublished.startsWith('01/01/'));
  }
});

test('ItsRugby corroborations use exact source display names and agree on year', () => {
  const confirmed = data.records.filter(r=>r.rugbyDataId && r.evidence.some(e=>e.kind==='itsrugby-person-jsonld'));
  assert.equal(confirmed.length,data.summary.rugbyDataYearsCorroboratedByExactDisplayNameItsRugby);
  for (const r of confirmed) {
    const primary = r.evidence.find(e=>e.kind==='rugbydata-individual-profile');
    for (const e of r.evidence.filter(e=>e.kind==='itsrugby-person-jsonld')) {
      assert.equal(key(e.nameAsPublished),key(primary.nameAsPublished));
      assert.ok(e.url.endsWith('-'+e.sourceRecordId+'/'));
      assert.match(e.dateAsPublished,/^(19\d{2}|200\d|201[01])-\d{2}-\d{2}$/);
      assert.equal(Number(e.dateAsPublished.slice(0,4)),r.birthYear);
    }
  }
});

test('unresolved official contradictions and false alias proposals remain excluded', () => {
  for (const id of ['lnr:11779','lnr:13497','lnr:13834','lnr:13234','lnr:13539','lnr:25028','lnr:13660']) assert.equal(data.records.some(r=>r.lnrId===id),false,id);
  for (const r of data.records.filter(r=>r.lnrAgeCrossCheck)) {
    assert.ok([0,1].includes(2026-r.birthYear-r.lnrAgeCrossCheck.ageAsPublished));
    assert.equal(r.lnrAgeCrossCheck.yearDerivedFromAge,false);
  }
});

test('all 175 Rugby Data candidates have an explicit outcome; excluded rows contribute no year', () => {
  assert.equal(data.rugbyDataAttempts.length,175);
  assert.equal(new Set(data.rugbyDataAttempts.map(a=>a.lnrId)).size,175);
  const actual={};
  for (const a of data.rugbyDataAttempts) actual[a.status]=(actual[a.status]||0)+1;
  assert.deepEqual(actual,data.summary.rugbyDataOutcomeCounts);
  assert.equal(Object.values(actual).reduce((a,b)=>a+b,0),175);
  for (const a of data.rugbyDataAttempts) assert.equal(data.records.some(r=>r.lnrId===a.lnrId && r.rugbyDataId),a.status==='new-year-verified');
});

test('U20 dates require a permanent revision and explicit club mapping; federation rows retain page provenance', () => {
  const clubs={'Nevers Espoirs':'nevers','RC Toulonnais Espoirs':'toulon','Lyon Espoirs':'lyon'};
  for (const r of data.records) for (const e of r.evidence) {
    if (e.kind==='wikipedia-u20-roster-permalink') {
      assert.ok(e.url.includes('oldid='+e.revisionId));
      assert.equal(clubs[e.clubAsPublished],r.club);
      assert.equal(key(e.nameAsPublished),key(r.lnrName));
    }
    if (e.kind==='official-federation-pdf') {
      assert.ok(Number.isInteger(e.page) && e.page>0);
      assert.equal(e.visualRowVerified,true);
    }
    if (e.kind==='indexed-public-sports-profile') {
      assert.equal(e.retrievalMethod,'web-indexed-public-profile');
      assert.ok(e.retrievedFactText.includes(String(r.birthYear)));
      assert.equal(e.htmlSha256,undefined);
    }
  }
  assert.ok(data.records.find(r=>r.lnrId==='lnr:11941').evidence.some(e=>e.kind==='official-federation-pdf'));
  assert.ok(data.records.find(r=>r.lnrId==='lnr:25020').evidence.some(e=>e.kind==='official-federation-pdf'));
});

test('summary counts are independently reproduced against all earlier evidence', () => {
  assert.equal(data.summary.baselineLnrWithYear,known.size);
  assert.equal(data.summary.newLnrWithYear,data.records.length);
  assert.equal(data.summary.totalLnrWithYear,known.size+data.records.length);
  assert.equal(data.summary.remainingLnrWithoutYear,1592-known.size-data.records.length);
  assert.ok(data.records.length>=100);
  console.log(JSON.stringify(data.summary));
});

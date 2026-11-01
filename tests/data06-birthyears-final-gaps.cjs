'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'..');
const read=f=>JSON.parse(fs.readFileSync(path.join(root,f),'utf8'));
const data=read('modding/data06/birthyears-final-gaps-2026-11-01.json');
const key=s=>s.replace(/&#0*39;/g,"'").replace(/&amp;/g,'&').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase().replace(/[^a-z0-9]+/g,' ').trim();
const clubs=['top14-a','top14-b','prod2-a','prod2-b'].flatMap(f=>read('modding/data03/'+f+'.json').clubs);
const catalog=clubs.flatMap(c=>c.players.map(p=>({...p,club:c.club})));
const known=new Set(data.baselineFiles.flatMap(f=>{const p=read('modding/data06/'+f);return (p.records||p.linked).map(r=>r.lnrId)}));
const groups=()=>Object.groupBy(data.records,r=>r.identityMethod);
function omission(legal,short){
 const a=key(legal).split(' '),b=key(short).split(' ');
 if(b.length<2||b.length>=a.length||a[0]!==b[0]||a.at(-1)!==b.at(-1))return false;
 let start=0;for(const token of b){const index=a.indexOf(token,start);if(index<0)return false;start=index+1;}return true;
}

test('new records have a unique existing LNR ID, original club, name and URL',()=>{
 assert.equal(catalog.length,1592);
 assert.equal(new Set(catalog.map(p=>p.id)).size,1592);
 for(const r of data.records){
  const p=catalog.filter(p=>p.id===r.lnrId);assert.equal(p.length,1);
  assert.equal(r.club,p[0].club);assert.equal(key(r.lnrName),key(p[0].name));assert.equal(r.lnrUrl,p[0].url);
 }
});

test('every year is new relative to all five prior datasets and no ID is counted twice',()=>{
 assert.equal(known.size,1367);
 assert.equal(new Set(data.records.map(r=>r.lnrId)).size,data.records.length);
 for(const r of data.records)assert.equal(known.has(r.lnrId),false,r.lnrId);
});

test('all retained evidence literally publishes the same year; precise dates and historical club claims stay unknown',()=>{
 for(const r of data.records){
  assert.ok(Number.isInteger(r.birthYear)&&r.birthYear>=1980&&r.birthYear<=2011);
  assert.equal(r.birthDate,null);assert.equal(r.validAtCareerStart,null);assert.ok(r.birthEvidence.length>0);
  for(const e of r.birthEvidence){
   assert.equal(e.birthYear,r.birthYear,r.lnrId);assert.ok(e.dateAsPublished.includes(String(r.birthYear)));
   assert.equal(e.observedDate,'2026-11-01');assert.ok(e.url.startsWith('https://'));
   if(e.htmlSha256)assert.match(e.htmlSha256,/^[a-f0-9]{64}$/);
   if(e.retrievalMethod){assert.equal(e.retrievalMethod,'web-indexed-public-content');assert.equal(e.htmlSha256,undefined);assert.ok(e.retrievedFactText||e.kind==='wikipedia-u20-roster-permalink');}
  }
 }
});

test('each exact Espoirs row is attached to one missing LNR name in its explicit club',()=>{
 assert.equal(data.exactRosterFacts.length,108);
 assert.equal(new Set(data.exactRosterFacts.map(p=>p.sourceRecordId)).size,108);
 for(const p of data.exactRosterFacts){
  assert.equal(known.has(p.id),false);
  const matches=catalog.filter(q=>q.club===p.club&&key(q.name)===key(p.sourceName));
  assert.deepEqual(matches.map(q=>q.id),[p.id]);assert.equal(p.sourceSeason,'2026-27');
  assert.ok(p.sourceUrl.endsWith('-'+p.sourceRecordId+'/'));assert.match(p.sourceRosterSha256,/^[a-f0-9]{64}$/);
 }
});

test('Espoirs birthday evidence keeps the exact published name and linked stable profile ID',()=>{
 const facts=new Map(data.exactRosterFacts.map(p=>[p.id,p]));
 for(const r of groups()['exact-espoirs-roster-name-club-and-profile-id']||[]){
  const p=facts.get(r.lnrId),i=r.identityEvidence;assert.ok(p);
  assert.equal(key(i.rosterNameAsPublished),key(r.lnrName));assert.equal(i.rosterClub,r.club);
  assert.equal(i.rosterSeasonAsPublished,'2026-27');assert.equal(i.sourceRecordId,p.sourceRecordId);
  assert.equal(i.linkedProfileUrl,p.sourceUrl);assert.equal(i.rosterHtmlSha256,p.sourceRosterSha256);
  const e=r.birthEvidence[0];assert.equal(e.kind,'itsrugby-person-jsonld');assert.equal(key(e.nameAsPublished),key(r.lnrName));
  assert.equal(e.url,i.linkedProfileUrl);assert.equal(e.sourceRecordId,i.sourceRecordId);
  assert.match(e.dateAsPublished,/^(19\d{2}|200\d|201[01])-\d{2}-\d{2}$/);
  assert.equal(new Date(e.dateAsPublished+'T00:00:00.000Z').toISOString().slice(0,10),e.dateAsPublished);
 }
});

test('reviewed middle-name omissions require unique first and last names and all short-name components',()=>{
 const manual=groups()['reviewed-omitted-name-components']||[];assert.ok(manual.length>=20);
 for(const r of manual){
  const i=r.identityEvidence;assert.equal(i.reviewedLegalId,r.lnrId);assert.ok(omission(r.lnrName,i.publishedShortName));
  assert.deepEqual(catalog.filter(p=>omission(p.name,i.publishedShortName)).map(p=>p.id),[r.lnrId]);
  const e=r.birthEvidence.find(e=>e.kind==='rugbydata-individual-profile');assert.ok(e);
  assert.ok([e.nameAsPublished,...e.publishedAliases].some(n=>key(n)===key(i.publishedShortName)));
 }
 assert.equal(omission('Sandro Dubois Martin','Karl Martin'),false);
 assert.equal(omission('Harrison Asi','Braxton Asi'),false);
 assert.equal(omission('Giorgi Zazadze','Rati Zazadze'),false);
 assert.equal(omission('Jules Martin Bonnard','Roméo Bonnard Martin'),false);
 assert.equal(omission('Jason-colin Fraser','Jason-Collin Fraser'),false);
});

test('reviewed omissions have official LNR full-name/club/age proof and two distinct birth publishers',()=>{
 for(const r of groups()['reviewed-omitted-name-components']||[]){
  const i=r.identityEvidence,o=i.officialLnr,c=clubs.find(c=>c.club===r.club);
  assert.equal(key(o.nameAsPublished),key(r.lnrName));assert.equal(o.url,r.lnrUrl);
  assert.equal(o.clubUrl.replace(/\/$/,''),c.source.replace(/\/effectif-staff$/,''));
  assert.equal(i.sourceRosterClub,r.club);assert.ok(i.sourceRosterUrl.startsWith('https://www.rugbydata.fr/club/effectif/panel/'));
  assert.match(o.htmlSha256,/^[a-f0-9]{64}$/);assert.ok(o.positionAsPublished.length>0);
  assert.ok([0,1].includes(2026-r.birthYear-o.ageAsPublished));
  assert.ok(r.birthEvidence.length>=2);
  assert.equal(new Set(r.birthEvidence.map(e=>new URL(e.url).hostname.replace(/^www\./,''))).size,r.birthEvidence.length);
  for(const e of r.birthEvidence)assert.equal(e.birthYear,r.birthYear);
 }
});

test('the young Giorgi Zazadze is resolved only through his own current club/national-team bridge',()=>{
 const r=data.records.find(r=>r.lnrId==='lnr:13834');assert.ok(r);assert.equal(r.birthYear,2007);
 assert.equal(r.identityMethod,'exact-name-national-team-and-current-club-bridge');
 assert.equal(r.identityEvidence.bridgeClubAsPublished,'Nevers');assert.equal(r.identityEvidence.bridgeNationalTeamAsPublished,'Georgie U20');
 assert.ok(r.identityEvidence.bridgeUrl.endsWith('-67888/'));
 for(const e of r.birthEvidence){assert.equal(key(e.nameAsPublished),'giorgi zazadze');assert.equal(e.url.includes('/players/view/2065'),false);assert.equal(e.birthYear,2007);}
 assert.equal(r.dayMonthDisagreement,true);assert.equal(r.birthDate,null);
 assert.ok(r.birthEvidence.some(e=>e.dateAsPublished.includes('June')));
 assert.ok(r.birthEvidence.some(e=>e.dateAsPublished.includes('Jul')));
});

test('unresolved year contradictions stay excluded and ages are used only to reject incompatible years',()=>{
 for(const id of ['lnr:11779','lnr:13497'])assert.equal(data.records.some(r=>r.lnrId===id),false,id);
 for(const r of data.records.filter(r=>r.officialAgeCrossCheck)){
  assert.equal(r.officialAgeCrossCheck.yearDerivedFromAge,false);
  assert.ok([0,1].includes(2026-r.birthYear-r.officialAgeCrossCheck.publishedAge));
 }
 assert.equal(data.records.some(r=>r.lnrId==='lnr:25056'),false,'Noah Brown date conflicts with official age');
});

test('roster receipts account for all pages, rate-limited pages and actual 2026-27 rows',()=>{
 assert.equal(data.rosterSources.length,30);
 const counts={};for(const s of data.rosterSources){counts[s.httpStatus]=(counts[s.httpStatus]||0)+1;if(s.httpStatus==='200'){assert.equal(s.title.length,1);assert.match(s.title[0],/Espoirs/i);assert.match(s.htmlSha256,/^[a-f0-9]{64}$/);assert.ok(s.rows>0);}}
 assert.deepEqual(counts,{'200':27,'429':3});assert.deepEqual(counts,data.summary.rosterStatusCounts);
 assert.equal(data.rosterSources.reduce((n,s)=>n+(s.rows||0),0),1195);
 assert.equal(data.transportPolicy.profileBackoffSecondsMinimum,180);assert.ok(data.transportPolicy.profileMinimumGapSeconds>=3.2);
 assert.equal(data.transportPolicy.paidServices,0);
});

test('every candidate profile is accounted for and rejected dates contribute no records',()=>{
 assert.equal(data.profileAttempts.length,108,'all queued profiles must finish before publication');
 assert.equal(new Set(data.profileAttempts.map(a=>a.lnrId)).size,108);
 const outcomes={};for(const a of data.profileAttempts){outcomes[a.status]=(outcomes[a.status]||0)+1;const r=data.records.find(r=>r.lnrId===a.lnrId&&r.identityMethod==='exact-espoirs-roster-name-club-and-profile-id');assert.equal(Boolean(r),a.status==='new-year-verified');}
 assert.deepEqual(outcomes,data.summary.profileOutcomes);assert.equal(data.summary.profilesProcessed,108);
});

test('published coverage totals reproduce the union with every earlier dataset',()=>{
 assert.equal(data.summary.baselineLnrWithYear,known.size);assert.equal(data.summary.newLnrWithYear,data.records.length);
 assert.equal(data.summary.totalLnrWithYear,known.size+data.records.length);
 assert.equal(data.summary.remainingLnrWithoutYear,1592-known.size-data.records.length);
 assert.ok(data.records.length>40);console.log(JSON.stringify(data.summary));
});

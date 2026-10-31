'use strict';
const assert=require('node:assert/strict');
const data=require('../modding/data01/fr-rugby-2026-2027.research.json');
assert.equal(data.datasetType,'optional-real-rugby-mod-research');
assert.equal(data.distributionStatus,'research-only-rights-not-established');
assert.equal(data.competitions.length,2);
assert.equal(data.clubs.length,30);
const ids=new Set(data.clubs.map(x=>x.id));
assert.equal(ids.size,30,'stable unique club IDs');
for(const competition of data.competitions){
 const teams=data.clubs.filter(x=>x.competitionId===competition.id);
 assert.equal(teams.length,competition.clubsExpected,competition.name);
 assert.ok(competition.source.startsWith('https://'));
}
for(const c of data.clubs){
 assert.ok(c.stadium.name&&c.verifiedFrom.startsWith('https://'),c.name);
 assert.equal(c.stadium.photo,null,'no unlicensed image');
 assert.equal(c.budgetEur,null,'no invented budget');
 assert.equal(c.rosterComplete,false,'no full-roster claim');
}
assert.equal(data.transfers.length,10);
for(const t of data.transfers){
 assert.ok(ids.has(t.toClubId));
 assert.ok(t.source.startsWith('https://'));
 assert.equal(t.status,'source-listed-arrival-not-full-contract');
}
assert.equal(data.visualAssets.length,0);
console.log(JSON.stringify({passed:true,clubCount:data.clubs.length,competitionCount:data.competitions.length,transferExamples:data.transfers.length}));

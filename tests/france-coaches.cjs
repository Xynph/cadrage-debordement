'use strict';
const assert=require('node:assert/strict'),{context}=require('./france-harness.cjs');
for(const critical of [false,true]){
 const h=context();h.run("start(7,'france');S.phase='ended';var firstElite=CDFranceCompetition.ranked(S,'elite')[0].id;var lastElite=CDFranceCompetition.ranked(S,'elite').at(-1).id;var d2=CDFranceCompetition.ranked(S,'accession'),firstD2=d2[0].id,lastD2=d2.at(-1).id,tenthD2=d2[9].id,eleventhD2=d2[10].id;S.worldManagement.clubInfo.forEach(c=>{c.coachConfidence=60;c.consecutiveLosses=0});");
 if(critical)h.run('for(const id of [lastElite,firstD2,lastD2,tenthD2,eleventhD2]){worldClub(id).coachConfidence=0;worldClub(id).consecutiveLosses=10}');
 h.run('worldEndSeason()');
 assert.equal(h.run('worldClub(firstElite).coachConfidence'),64);
 assert.equal(h.run('worldClub(firstD2).coachConfidence'),critical?4:64,'premier D2 évalué dans sa division');
 assert.equal(h.run('worldClub(firstD2).coachChanges'),0,'le rang global15 ne licencie pas le premier D2');
 if(critical){for(const name of ['lastElite','lastD2','eleventhD2']){assert.equal(h.run('worldClub('+name+').coachChanges'),1);assert.equal(h.run('worldClub('+name+').coachConfidence'),55);}assert.equal(h.run('worldClub(tenthD2).coachChanges'),0,'dixième D2 hors des six derniers');}
 else for(const name of ['lastElite','lastD2'])assert.equal(h.run('worldClub('+name+').coachConfidence'),57);
 assert.equal(h.run('S.worldManagement.yearbook.at(-1).standings.find(c=>c.id===firstD2).position'),1);
}
console.log('Entraîneurs France : rang propre à chaque division, six qualifiés et six derniers PASS');

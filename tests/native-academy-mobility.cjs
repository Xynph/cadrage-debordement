'use strict';
const assert=require('node:assert/strict');const {make}=require('./native-academy.cjs');const t=make(29),r=t.run;
r('A.execute("academy_activate",{season:1,week:0,club:29,confirmed:true});managerMobilityEnable()');
for(let w=0;w<34;w++)r('finishRound()');r('A.validate(S);validateCareer(S)');
r('S.clubs[0].cash=10000000;worldClub(0).debt=0;worldClub(0).reputation=0;worldClub(0).coachConfidence=0');
const old=r('JSON.stringify(S.nativeAcademy.centers.map(c=>({id:c.id,clubId:c.clubId})))'),target=r('S.clubs.filter(c=>c.id!==S.club).map(c=>managerMobilityDecision(c.id)).find(c=>c.accepted).clubId');t.ctx.destination=target;
r('managerMobilityApply(destination);managerMobilityAccept("job-1-"+destination);advanceSeason();A.validate(S);validateCareer(S)');assert.equal(r('S.club'),target);assert.equal(r('A.project().centerId'),'club:'+target);assert.equal(r('JSON.stringify(S.nativeAcademy.centers.map(c=>({id:c.id,clubId:c.clubId})))'),old);assert.equal(r('Object.keys(S.nativeAcademy.offices).join()'),'29');assert.equal(r('S.v101to104.archive.length'),0,'nouveau club sans fausse génération héritée');assert.equal(r('S.nativeAcademy.offices[29].v101to104.archive.length'),1);
r('S=parseSaveDocument(JSON.stringify(createSaveDocument())).state;finishRound();A.validate(S)');assert.equal(r('S.nativeAcademy.club'),target);console.log('PASS formation mobilité : club29 vers'+target+', centre stable, archives dans ancien club, intersaison/import/journée suivante');


'use strict';
const assert=require('node:assert/strict');const {make}=require('./native-academy.cjs');
const t=make(),r=t.run;r('A.execute("academy_activate",{season:1,week:0,club:29,confirmed:true})');
function bad(source){const before=r('JSON.stringify(S)');r(source);assert.throws(()=>r('A.validate(S)'),/formation/i,source);t.ctx.restore=before;r('S=JSON.parse(restore)');}
for(const source of ['S.nativeAcademy.centers[30].players[0].extra=1','S.nativeAcademy.centers[30].players[0].dev.xp=-1','S.v101to104.paths.push({id:"inconnu",createdSeason:1,updatedSeason:1,strategy:"minutes",startRating:60})','S.v95to100.network.players[0].lastReport={season:99,recruiter:"x",reliability:90}','S.v86to89.history.push({season:1,targets:[{id:"x",extra:true}]})','S.v73Espoirs.fixtures[0][0]=[0,1]','S.v74Accession.groups.reverse()'])bad(source);
console.log('PASS formation hostile : joueurs invités, références, calendriers et archives imbriquées fermées');

'use strict';
const assert=require('node:assert/strict');const {make}=require('./native-academy.cjs');
const t=make(29),r=t.run;
r('A.execute("academy_activate",{season:S.season,week:0,club:29,confirmed:true})');
const cmd=(command,extra={})=>{t.ctx.payload=extra;r('A.execute('+JSON.stringify(command)+',{season:S.season,week:S.franceMode.week,club:S.club,...payload})');};
cmd('academy_plan',{playerId:r('S.development.academy[0].id'),target:'minutes'});cmd('academy_target',{playerId:r('S.development.academy[0].id'),minutes:480});cmd('academy_specialize',{playerId:r('S.development.academy[0].id'),kind:'technique'});cmd('academy_load',{playerId:r('S.development.academy[0].id'),load:'intensive'});cmd('academy_path',{playerId:r('S.development.academy[0].id'),strategy:'minutes'});cmd('academy_contract',{playerId:r('S.development.academy[0].id'),years:2,confirmed:true});cmd('academy_scout',{confirmed:true});
let max=0;const years=Number(process.env.CD_ACADEMY_YEARS||1);for(let year=1;year<=years;year++){
 for(let w=0;w<34;w++){r('finishRound()');r('A.validate(S)');if([10,20,34].includes(w+1)){const data=r('JSON.stringify(S)'),bytes=Buffer.byteLength(data);max=Math.max(max,bytes);assert.ok(bytes<5*1024*1024,bytes+' bytes');let nodes=0;function count(x){nodes++;if(x&&typeof x==='object')Object.values(x).forEach(count)}count(JSON.parse(data));console.log(JSON.stringify({season:year,week:w+1,bytes,nodes,juniorRound:r('S.v73Espoirs.round'),juniors:r('S.nativeAcademy.centers.reduce((n,c)=>n+(c.players?.length||0),0)')}));t.ctx.copy=data;r('S=parseSaveDocument(JSON.stringify(createSaveDocument())).state;A.validate(S)');}
 }
 assert.equal(r('S.v73Espoirs.results.length'),202);assert.equal(r('S.v74Accession.results.length'),187);assert.ok(r('S.development.academy.some(p=>(S.v73Espoirs.minutes[p.id]||0)>0)'));
 r('advanceSeason();A.validate(S)');assert.equal(r('S.season'),year+1);assert.equal(r('S.v101to104.archive.length'),Math.min(year,15));assert.equal(r('S.v73Espoirs.round'),0);
 const before=r('JSON.stringify(S.development.academy.map(p=>p.id))');r('beginDevelopmentSeason();A.validate(S)');assert.equal(r('JSON.stringify(S.development.academy.map(p=>p.id))'),before,'génération annuelle unique');
}
console.log('PASS formation : '+years+' saisons réellement simulées, reprise par le vrai parseur aux checkpoints, archive/générations uniques, maximum '+max+' octets');

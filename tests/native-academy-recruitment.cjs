'use strict';
const assert=require('node:assert/strict');const {make}=require('./native-academy.cjs');const t=make(29),r=t.run;
r('A.execute("academy_activate",{season:1,week:0,club:29,confirmed:true})');
// Keep the same34weeks; each real weekly call retains the normal15s VM guard.
for(let week=0;week<34;week++)r('finishRound()');
r('advanceSeason()');
const act=(command,extra={})=>{t.ctx.payload=extra;return r('A.execute('+JSON.stringify(command)+',{season:S.season,week:S.franceMode.week,club:S.club,confirmed:true,...payload})')};
const beforeCash=r('S.clubs[29].cash'),beforeBudget=r('A.project().recruitBudget');
for(const sourceId of ['guest:0','club:28']){
 act('academy_center_scout',{centerId:sourceId});
 const candidate=r('A.project().centers.find(c=>c.id==='+JSON.stringify(sourceId)+').candidates[0]');assert.ok(candidate,'candidat disponible '+sourceId);
 t.ctx.pid=candidate.id;t.ctx.sourceId=sourceId;
 const original=r('JSON.stringify(CDEspoirsScoutingV76.players(S,CDEspoirsScoutingV76.centers(S).find(c=>c.id===sourceId)).find(p=>p.id===pid))');
 const sourceCount=r('A.project().centers.find(c=>c.id===sourceId).count');
 const prior=r('JSON.stringify(S)');assert.throws(()=>act('academy_recruit',{playerId:candidate.id,offer:candidate.fee-1}),/refus/);assert.equal(r('JSON.stringify(S)'),prior,'offre insuffisante sans mutation');
 act('academy_recruit',{playerId:candidate.id,offer:candidate.fee});
 assert.equal(r('JSON.stringify(S.development.academy.find(p=>p.id===pid))'),original,'identité et attributs exacts du joueur déplacé');
 assert.equal(r('A.project().centers.find(c=>c.id===sourceId).count'),sourceCount-1);assert.ok(sourceCount-1>=15);
 assert.equal(r('[...S.clubs.flatMap(c=>c.players),...S.development.academy,...S.aiRoster.academies.flatMap(a=>a.players),...S.nativeAcademy.centers.flatMap(c=>c.players||[])].filter(p=>p.id===pid).length'),1,'joueur unique');
 assert.throws(()=>act('academy_recruit',{playerId:candidate.id,offer:candidate.fee}),/refus/);
 r('A.validate(S);S=parseSaveDocument(JSON.stringify(createSaveDocument())).state;A.validate(S)');
}
assert.equal(r('S.clubs[29].cash'),beforeCash,'détection financée par enveloppe junior distincte');assert.equal(r('A.project().recruitBudget'),beforeBudget-r('S.v76Scouting.spent'));assert.equal(r('S.v76Scouting.recruited.length'),2);
console.log('PASS recrutement centres : invité et club28 vers29, prix minimum, coût enveloppe, objet intact, unicité, XV source et import réel');

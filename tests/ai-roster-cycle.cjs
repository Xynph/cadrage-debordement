'use strict';
const assert=require('node:assert/strict');
const reception=require('./helpers/gestion-reception.cjs');
const {engineContext}=require('./harness.cjs');
const {planningContext}=require('./helpers/gestion-domaines.cjs');
const {settleClubMeetings}=require('./helpers/club-meetings.cjs');
// Politique v1 : APIs publiques sur DONNÉES copiées, jamais une ancienne carrière.
const context=()=>planningContext(null,{aiV1Market:true});
let validationIndex=0;
const valid=run=>{validationIndex++;try{return run('validatePopulationPolicy(S);!!componentParse(JSON.stringify(componentDocument()))')}catch(e){throw new Error('Sauvegarde invalide au contrôle '+validationIndex+' : '+e.message,{cause:e})}};
console.log('AI données : contrats, budget et cohortes historiques');
const historicData=(()=>{
const t=context(),r=t.run;
r('S.clubs[1].cash=2500000');
assert.equal(r('aiRosterActive()'),true);
assert.equal(r('S.aiRoster.academies.length'),13);
assert.equal(r('S.aiRoster.reports.length'),0);
assert.ok(r('aiRosterPanel().includes("Observatoire des effectifs IA")'));
assert.ok(valid(r));
const old=r('JSON.stringify(S)'),storage=r('JSON.stringify(componentDocument())');
const baseLimit=r('aiRosterWageLimit(S.clubs[1])');
r('S.clubs[1].cash-=1000000');
assert.ok(baseLimit-r('aiRosterWageLimit(S.clubs[1])')>=11000,'salary capacity must scale with net cash');
r('S.clubs[1].cash+=1000000');
r('worldClub(1).debt=900000');
assert.ok(baseLimit-r('aiRosterWageLimit(S.clubs[1])')>=9900,'debt must reduce wage room');
r('worldClub(1).debt=0');
r('aiRosterPanel();aiRosterPanel();aiRosterPanel()');
assert.ok(r('JSON.stringify(S)')===old,'dashboard stays read-only');
assert.equal(r('JSON.stringify(componentDocument())'),storage);
// Expirations: keep valuable/protected positions, release older low-ranked extras, pay renewal fees.
r('var c=S.clubs[1],initialCash=c.cash;for(const p of c.players.slice(12,24)){p.contractEnd=S.season;p.age=33;p.rating=55;p.dev.potential=Math.max(p.dev.potential,55);p.dev.retireAge=40;}var beforeIds=c.players.map(p=>p.id);var initialWages=aiRosterPayroll(c)');
assert.equal(r('aiRosterContracts()'),true);
assert.equal(r('aiRosterContracts()'),false,'settlement is idempotent');
assert.ok(r('S.aiRoster.reports.find(x=>x.clubId===1).renewed')>=1);
assert.ok(r('S.aiRoster.reports.find(x=>x.clubId===1).released')>=1);
assert.equal(r('c.players.length>=27'),true);
assert.ok(r('S.economy.freeAgents.some(p=>beforeIds.includes(p.id))'));
assert.ok(r('c.cash<initialCash'),'renewals charge actual fees');
assert.equal(r('new Set(S.economy.freeAgents.map(p=>p.id)).size'),r('S.economy.freeAgents.length'));
assert.ok(valid(r));
// Youth academy: stored cohorts, progressive promotion and qualified emergency coverage.
r('S.season=2;S.phase="league";S.round=0;S.economy.settled=1');
assert.equal(r('aiRosterYouthIntake()'),true);
assert.equal(r('aiRosterYouthIntake()'),false);
assert.ok(r('S.aiRoster.academies.every(a=>a.intakeSeason===2&&a.players.length<=75)'));
assert.ok(r('S.clubs.filter(c=>c.id!==S.club).every(c=>buildSheet(c).lineup.every(Boolean)&&buildSheet(c).bench.every(Boolean))'));
assert.equal(r('S.aiRoster.reports.some(x=>x.season===2)'),true);
assert.ok(valid(r));
const data=JSON.parse(r('JSON.stringify(S)'));t.close();return data;
})();
console.log('AI données : fenêtre de mercato et plafond six');
// Recruiting uses current transfer pool and respects the weekly salary cap.
(()=>{
const market=context(),m=market.run;
m('S.round=13;var buyer=S.clubs[1];var buyerCash=buyer.cash;buyer.players=buyer.players.filter(p=>p.pos!==POS[0]);var forced=makePlayer(99,0,75);forced.id="test-ai-prospect";forced.age=24;forced.rating=75;forced.salary=3000;forced.price=10000;forced.contractEnd=null;ensureDevelopment(forced);forced.dev.retireAge=40;S.market=[forced];S.economy.freeAgents=[];var ownCash=club().cash;var poolBefore=new Set([...S.market,...S.economy.freeAgents].map(p=>p.id))');
const signed=m('aiRosterRecruitmentWeek()');
assert.ok(signed>=1&&signed<=6);
assert.equal(m('aiRosterRecruitmentWeek()'),0);
assert.equal(m('S.economy.aiRecruitmentWindow'),'1:13');
assert.ok(m('S.aiRoster.reports.some(x=>x.recruited>0)'));
assert.equal(m('club().cash'),m('ownCash'));
assert.ok(m('S.clubs.filter(c=>c.id!==S.club).every(c=>new Set(c.players.map(p=>p.id)).size===c.players.length)'));
assert.ok(valid(m));market.close();
})();
console.log('AI données : insolvabilité');
(()=>{
const poor=context(),pr=poor.run;
pr('S.round=13;for(const c of S.clubs){if(c.id!==S.club){c.cash=0;worldClub(c.id).debt=2000000}}');
assert.equal(pr('aiRosterRecruitmentWeek()'),0);
assert.ok(valid(pr));poor.close();
})();
console.log('AI données : ancien format et initialiseur public');
// Métadonnées anciennes, en DONNÉES : initialiseur public sans IO. Le wrapper
// aiRosterEnable/save/render n’a pas de branche de succès World valide sans AI,
// confirmé par le probe prégroupes ; cette branche héritée n’est pas simulée.
(()=>{
 const legacy=planningContext(historicData),l=legacy.run;
 l('delete S.aiRosterVersion;delete S.aiRoster');
 assert.equal(l('aiRosterActive()'),false);assert.equal(l('aiRosterContracts()'),false);
 assert.ok(l('!!componentParse(JSON.stringify(componentDocument()))'));
 l('S.live={minute:0,paused:true}');const before=l('JSON.stringify(S)');
 assert.equal(l('aiRosterEnable()'),false);assert.ok(l('JSON.stringify(S)')===before);
 l('S.live=null');assert.equal(l('aiRosterSetup()'),true);
 assert.equal(l('S.aiRosterVersion'),2);assert.equal(l('S.aiRoster.academies.length'),13);
 assert.ok(l('S.aiRoster.academies.every(a=>a.clubId!==S.club&&a.players.length===0)'));
 assert.ok(valid(l));legacy.close();
})();
console.log('AI World : création native, reprise, import atomique et direct');
// Succès actuel : vraie création World active2, stockage/export/reprise, puis
// refus idempotents réels. L’absence AI est importée avec checksum/cap valides
// et refusée pour la provenance ciblée, sans mutation de S/store/RNG.
(()=>{
 const h=engineContext(),r=h.run;h.start(0);h.command('save');
 assert.equal(r('S.worldMode.version'),5);assert.equal(r('S.clubs.length'),116);
 assert.equal(r('S.aiRosterVersion'),2);assert.equal(r('S.aiRoster.version'),2);
 assert.equal(r('S.aiRoster.academies.length'),115);
 assert.ok(r('S.aiRoster.academies.every(a=>a.clubId!==S.club&&a.players.length===60)'));
 assert.equal(r('new Set([...S.clubs.flatMap(c=>c.players),...S.development.academy,...S.aiRoster.academies.flatMap(a=>a.players)].map(p=>p.id)).size'),r('S.clubs.reduce((n,c)=>n+c.players.length,0)+S.development.academy.length+S.aiRoster.academies.reduce((n,a)=>n+a.players.length,0)'));
 const checkRefusal=()=>{r('save()');const cp=h.checkpoint(),stored=h.store['bdt-v1'];assert.equal(r('aiRosterEnable()'),false);assert.ok(r('JSON.stringify(S)')===cp.text);assert.equal(h.store['bdt-v1'],stored);assert.equal(h.seed(),cp.seed);assert.ok(r('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'));};
 checkRefusal();const saved=h.state(),reopened=engineContext(saved);assert.ok(reopened.run('JSON.stringify(S)')===JSON.stringify(saved));assert.ok(reopened.run('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'));reopened.close();
 h.command('save');const cp=h.checkpoint(),stored=h.store['bdt-v1'];
 const doc=JSON.parse(r('JSON.stringify(createSaveDocument())')),bad=JSON.parse(cp.text);
 delete bad.aiRosterVersion;delete bad.aiRoster;doc.exportVersion=1;doc.state=bad;
 h.ctx.aiMissingState=bad;try{doc.checksum=r('saveChecksum(aiMissingState)');}finally{delete h.ctx.aiMissingState;}
 const text=JSON.stringify(doc);h.ctx.aiMissingText=text;
 try{assert.ok(r('saveUtf8Bytes(aiMissingText)<=worldSaveLimits(S).saveBytes'),'vraie enveloppe sous le plafond World24Mio');assert.throws(()=>h.command('import',{text}),error=>error.message==='import : Provenance des petits clubs invalide.');}
 finally{delete h.ctx.aiMissingText;}
 assert.ok(r('JSON.stringify(S)')===cp.text,'import refusé atomiquement');assert.equal(h.store['bdt-v1'],stored);assert.equal(h.seed(),cp.seed);
 h.deferSaves();h.toMatch();r('beginMatch();pauseMatch()');assert.ok(r('S.live&&!S.live.finished&&S.live.paused'));checkRefusal();h.close();
})();
console.log('AI World : rapports corrompus');
(()=>{
 const corrupt=engineContext(),bad=corrupt.run;corrupt.start(0);bad('S.aiRoster.reports=[{clubId:99}]');assert.throws(()=>bad('validateCareer(S)'));corrupt.close();
})();
console.log('AI World : doublons du centre');
(()=>{
 const corrupt=engineContext(),q=corrupt.run;corrupt.start(0);q('S.aiRoster.academies[0].players.push(club().players[0])');assert.throws(()=>q('validateCareer(S)'));corrupt.close();
})();
// 12 seasons of the *real match engine*, not the V51 synthetic rankings.
const sim=engineContext(),s=sim.run;s('start(0)');sim.deferSaves();reception.traceValidation(sim);
const validWorld=run=>run('!!parseSaveDocument(JSON.stringify(createSaveDocument()))');
const initialBases=JSON.parse(s('JSON.stringify(S.clubs.map(c=>c.base))'));
let totalNew=0,totalPromoted=0,totalLeft=0,totalRetired=0,lowest=Infinity,highest=-Infinity;
for(let season=1;season<=12;season++){
 console.log('Effectifs IA World : saison '+season+' / 12');sim.season();
 assert.equal(s('S.season'),season);
 assert.equal(s('S.worldManagement.champion!==null'),true);
 assert.ok(validWorld(s));
 const report=JSON.parse(s('JSON.stringify(S.aiRoster.reports)'));
 totalNew=report.reduce((n,x)=>n+x.recruited,0);
 totalPromoted=report.reduce((n,x)=>n+x.promoted+x.emergency,0);
 totalLeft=report.reduce((n,x)=>n+x.released,0);
 totalRetired=report.reduce((n,x)=>n+x.retired,0);
 const cash=JSON.parse(s('JSON.stringify(S.clubs.map(c=>c.cash))'));
 lowest=Math.min(lowest,...cash);highest=Math.max(highest,...cash);
 assert.ok(s('S.aiRoster.academies.every(a=>a.players.length<=75)'));
 assert.ok(s('S.clubs.every(c=>c.players.length<=professionalCapacity(c,S)&&new Set(c.players.map(p=>p.id)).size===c.players.length)'));
 if(season<12){reception.checkpoint(sim,'ai-roster-end-'+season,{completedRealSeasons:season});const model=sim.command('next_season',{confirmed:true});settleClubMeetings(model,(command,payload)=>sim.command(command,payload));sim.deferSaves();assert.equal(s('S.season'),season+1);assert.ok(validWorld(s));}
}
assert.ok(totalNew>0,'AI must recruit across real league fixtures');
assert.ok(totalPromoted>0,'AI academy and emergency prospects must feed squads');
assert.ok(totalLeft>0,'expiring contracts must lead to actual departures');
assert.ok(totalRetired>0,'real players retire across long careers');
const finalBases=JSON.parse(s('JSON.stringify(S.clubs.map(c=>c.base))'));
assert.ok(finalBases.some((base,id)=>id!==s('S.club')&&base!==initialBases[id]),'AI club hierarchy must evolve against its actual World creation');
assert.ok(s('S.aiRoster.reports.length<=196&&S.aiRoster.events.length<=180'));
assert.ok(s('S.worldManagement.yearbook.length>=11'));
assert.ok(s('S.worldManagement.yearbook.every(y=>y.standings.length===116)'));
assert.ok(s('S.worldManagement.clubInfo.every(x=>x.debt>=0&&Number.isFinite(x.debt))'));
assert.ok(validWorld(s));
const storedSim=JSON.parse(s('JSON.stringify(S)'));
const reopened=engineContext(storedSim);assert.ok(validWorld(reopened.run),'real league save roundtrip');reopened.close();sim.close();
console.log(JSON.stringify({passed:true,realSeasons:12,counterScope:'last retained AI report collection, capped at 196, matching the original contract',recruited:totalNew,promoted:totalPromoted,released:totalLeft,retired:totalRetired,minimumCash:lowest,maximumCash:highest,checks:['contracts and fees','market windows','debts and wage limits','academy cohorts','rugby lineup','native mandatory AI activation and guarded data initializer','live lock','corrupt saves','actual rugby fixtures','twelve seasons','real league hierarchy','financial and player invariants']}));

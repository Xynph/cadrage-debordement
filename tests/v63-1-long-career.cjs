'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs');
const {engineContext:context}=require('./harness.cjs');
const checks=[],snapshots=[],startTime=Date.now();
function check(name,fn){fn();checks.push(name)}
let current=context(),run=current.run;run('start(0)');current.deferSaves();
const verified=()=>run('!!parseSaveDocument(JSON.stringify(createSaveDocument()))');
check('carriere reellement initialisee',()=>{assert.equal(run('worldActive()'),true);assert.equal(run('careerIntegrated()'),true);assert.equal(run('S.clubs.length'),116)});
check('modules IA et coaches natifs charges',()=>{assert.equal(run('typeof CDClubAI.planSeason'), 'function');assert.equal(run('typeof CDCoachMarket.dismissalRisk'),'function')});
check('recrutement cible repond aux contraintes',()=>{let result=run('CDClubAI.planSeason({cash:1000000,wageRoom:4000,needs:["Pilier","Centre"],candidates:[{id:"a",pos:"Pilier",fee:100000,wage:2000,rating:80},{id:"b",pos:"Centre",fee:100000,wage:2000,rating:75}]})');assert.equal(result.targets.length,2);assert.equal(run('CDClubAI.planSeason({cash:100,wageRoom:0,needs:["Pilier"],candidates:[{id:"a",pos:"Pilier",fee:100000,wage:2000,rating:80}]}).targets.length'),0)});
check('marché coaches natif utilise la confiance',()=>assert.equal(run('CDCoachMarket.dismissalRisk({confidence:10,consecutiveLosses:4}).critical'),true));
check('investissement debite une seule fois',()=>{const start=run('club().cash'),quote=run('worldFacilityQuote(S.club).cost');assert.equal(run('worldUpgradeFacility()'),true);assert.equal(run('club().cash'),start-quote);assert.equal(run('worldUpgradeFacility()'),false);assert.equal(run('club().cash'),start-quote)});
check('validation de sauvegarde native apres investissement',()=>assert.equal(verified(),true));
check('rejet sauvegarde malveillante',()=>{
 const bad=JSON.parse(run('JSON.stringify(S)'));bad.worldManagement.clubInfo[0].reputation=999;
 // Le constructeur de reprise traite son erreur en affichant l'écran d'accueil.
 // Le contrat testé est le rejet par le vrai validateur, sans charger le candidat.
 current.ctx.maliciousWorldText=JSON.stringify(bad);
 try{assert.throws(()=>run('validateCareer(JSON.parse(maliciousWorldText))'));}
 finally{delete current.ctx.maliciousWorldText;}
});
const seasons=12;let replays=0;
for(let year=1;year<=seasons;year++){
  run=current.run;
  assert.equal(run('S.season'),year);
  const before=run('S.round');
  for(let week=0;run('S.phase')!=='ended'&&week<80;week++)run('finishRound()');
  assert.equal(run('S.phase'),'ended','saison Monde complète');
  assert.equal(run('S.season'),year);
  assert.ok(run('S.worldManagement.champion!==null'));
  assert.ok(verified());
  check('saison '+year+' : champions et archives disponibles',()=>{
    assert.ok(run('S.worldManagement.matches.length')<=180);
    assert.ok(run('S.worldManagement.clubInfo.every(c=>Number.isFinite(c.reputation)&&c.reputation>=0&&c.reputation<=100&&c.debt>=0)'));
    assert.ok(run('S.ledger.every(x=>Number.isFinite(x.amount))'));
  });
  console.log('V63.1 YEAR PASS '+year+'/'+seasons);
  snapshots.push({season:year,champion:run('S.worldManagement.champion'),cash:run('club().cash'),ledger:run('S.ledger.length'),matches:run('S.worldManagement.matches.length')});
  if(year<seasons){
    run('advanceSeason()');assert.equal(run('S.season'),year+1);assert.ok(verified());
    if([4,8].includes(year)){
      const save=JSON.parse(run('JSON.stringify(S)'));
      const previous=current;current=context(save);run=current.run;current.deferSaves();previous.close();
      assert.equal(run('S.season'),year+1);assert.equal(run('worldActive()'),true);assert.ok(verified());replays++;
      check('reprise native apres saison '+year,()=>assert.equal(run('S.worldManagement.yearbook.length'),year));
    }
  }
}
run=current.run;
check('historique annuel 12 saisons',()=>{assert.equal(run('S.worldManagement.yearbook.length'),11);assert.equal(run('S.worldManagement.yearbook.every(x=>x.standings.length===116)'),true)});
check('fin de saison idempotente',()=>{assert.equal(run('worldEndSeason()'),true);assert.equal(run('worldEndSeason()'),false);assert.equal(run('S.worldManagement.yearbook.length'),12)});
check('taille sauvegarde sous plafond',()=>{assert.ok(run('JSON.stringify(S).length/S.clubs.length')<5000000/14,'densité brute par club sous le plafond historique');assert.ok(Buffer.byteLength(run('JSON.stringify(createSaveDocument())'),'utf8')<=run('worldSaveLimits(S).saveBytes'));assert.equal(verified(),true)});

const report={type:'native-real-rugby-match-engine',years:seasons,checkpoints:replays,checks,passed:checks.length,durationMs:Date.now()-startTime,snapshots,limitations:['not Windows-native','checkpoint continuation recreates RNG; validates state, not identical outcomes','does not replace the separate V58-V61 feature suites']};
if(process.env.CD_V631_REPORT)fs.writeFileSync(process.env.CD_V631_REPORT,JSON.stringify(report,null,2)+'\n');
current.close();console.log('V63.1 NATIVE LONG CAREER PASS '+JSON.stringify({years:seasons,checkpoints:replays,passed:checks.length,durationMs:report.durationMs}));

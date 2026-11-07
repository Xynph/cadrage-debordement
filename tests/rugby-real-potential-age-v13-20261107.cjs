'use strict';
const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const root = path.resolve(__dirname, '..');
const read = p => fs.readFileSync(path.join(root,p),'utf8');
const candidate = JSON.parse(read('data/scouting/review-v12/candidate.json'));
const audit = JSON.parse(read('data/scouting/audit-potential-v13-20261107.json'));
const active = vm.runInNewContext(read('dist/lnr-ratings-v12.js')+'\n;LNR_V12_PLAYER_DATA;');
const age = vm.runInNewContext(read('dist/lnr-v11-aging.js')+'\n;LNR_V11_AGE;');
const sorted = list => [...list].sort((a,b)=>a.localeCompare(b));
function records() {
 return candidate.rows.map(row => {
  const tuple=active.players[row.playerId];
  assert.ok(tuple,'Absent de la BDD active : '+row.playerId);
  return {id:row.playerId,role:row.role,league:row.league,rating:tuple[0],potential:tuple[2],delta:tuple[2]-tuple[0],
   flagged:row.flags.includes('legacy-potential-scale-differs-from-role-ability'),tuple,row};
 });
}
test('audit de potentiel reproductible sur 1592 identifiants sans mutation', () => {
 const all=records(), flagged=all.filter(x=>x.flagged), neg=all.filter(x=>x.delta<0);
 assert.equal(all.length,1592);
 assert.equal(new Set(all.map(x=>x.id)).size,1592);
 assert.equal(neg.length,audit.activePotentialBelowRating);
 assert.equal(flagged.length,audit.flaggedHistorical);
 assert.equal(neg.filter(x=>x.flagged).length,audit.activeBelowAmongFlagged);
 assert.equal(neg.filter(x=>!x.flagged).length,audit.activeBelowNotFlagged);
 assert.equal(flagged.filter(x=>x.delta>=0).length,audit.flaggedNotBelow);
 assert.equal(all.filter(x=>x.delta===0).length,audit.activePotentialEqual);
 assert.equal(all.filter(x=>x.delta>0).length,audit.activePotentialAbove);
 assert.equal(audit.activePotentialBelowRating,393);
 assert.equal(audit.activeBelowNotFlagged,65);
 for(const [role,summary] of Object.entries(audit.byRole)) {
  const group=all.filter(x=>x.role===role);
  assert.equal(group.length,summary.players,role);
  assert.equal(group.filter(x=>x.delta<0).length,summary.belowPotential,role);
  assert.equal(group.filter(x=>x.flagged).length,summary.alerts,role);
 }
 for(const [league,summary] of Object.entries(audit.byDivision)){
  const group=all.filter(x=>x.league===league);
  assert.equal(group.length,summary.players,league);
  assert.equal(group.filter(x=>x.delta<0).length,summary.below,league);
 }
 const priority=neg.sort((a,b)=>a.delta-b.delta||a.id.localeCompare(b.id)).slice(0,40);
 assert.deepEqual(priority.map(x=>x.id),audit.reviewPriority.map(x=>x.id));
 console.log('RUGBY_REAL_POTENTIAL_QA '+JSON.stringify({players:all.length,alerts:flagged.length,potentialBelow:neg.length,unflaggedBelow:audit.activeBelowNotFlagged,roles:Object.keys(audit.byRole).length}));
});
test('36 attributs / 11 compétences : aucune note invalide, identité conservée',()=>{
 const all=records();
 assert.equal(active.attributeKeys.length,36);
 assert.equal(active.skillKeys.length,11);
 for(const x of all){
  assert.equal(x.tuple[3].length,36,x.id);
  assert.equal(x.tuple[4].length,11,x.id);
  assert.equal(x.tuple[5],x.role,x.id);
  for(const v of [...x.tuple[3],...x.tuple[4]]) assert.ok(Number.isFinite(v)&&v>=20&&v<=97,x.id);
  assert.ok(Number.isFinite(x.potential)&&x.potential>=20&&x.potential<=97,x.id);
 }
});
test('11 postes : physique après maturité décline plus vite que décision, potentiel conservé',()=>{
 const all=records();const quick=['acceleration','topSpeed','agility','explosiveness'];
 let processed=0;
 for(const role of sorted(new Set(all.map(x=>x.role)))){
  const x=all.find(p=>p.role===role);
  const profile={id:x.id,gameplayPosition:role,attributesV2:Object.fromEntries(active.attributeKeys.map(key=>[key,65])),
   potential:90,hiddenTraitsV2:{...x.tuple[6],professionalism:65}};
  const before=JSON.stringify(profile);
  const options={minutes:1600,training:1,injuryWeeks:0,load:0};
  const young=age.step(profile,{playerId:x.id,age:20,season:1},options);
  assert.ok(young.player.attributesV2.strength>=65,role+' force jeune');
  const old=age.step(profile,{playerId:x.id,age:38,season:1},options);
  const quickLoss=quick.reduce((n,k)=>n+65-old.player.attributesV2[k],0)/quick.length;
  const mentalLoss=65-old.player.attributesV2.decisions;
  assert.ok(quickLoss>mentalLoss,role+' déclin physique > décisions');
  assert.ok(old.player.attributesV2.topSpeed<65,role+' vitesse après 35');
  assert.equal(old.player.potential,90,role+' potentiel');
  assert.equal(JSON.stringify(profile),before,role+' entrée immuable');
  const rerun=age.step(old.player,{...old.state,lastSeason:1},options);
  assert.equal(JSON.stringify(rerun.player),JSON.stringify(old.player),role+' pas de double vieillissement');
  processed++;
 }
 assert.equal(processed,11);
 console.log('RUGBY_REAL_AGE_QA '+JSON.stringify({roles:processed,youngAge:20,oldAge:38,physicalDeclineVerified:true,doubleAgeingDetected:false}));
});

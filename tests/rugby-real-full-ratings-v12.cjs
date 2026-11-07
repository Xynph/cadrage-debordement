'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const R=require('../tools/rugby-real-v12/review.cjs');
const master=require('../modding/data06/rugby-master-2026-2027.json');
const evidence=require('../data/scouting/review-v12/season-evidence.json');
const extra=require('../data/scouting/review-v12/extra-evidence.json');
const careers=require('../data/scouting/review-v12/career-evidence.json');
test('V12 les 1592x36 attributs sont revus sans mutation du master ou du potentiel',()=>{
 const before=JSON.stringify(master),r=R.review(master,evidence,extra,careers),copy=R.apply(master,r);
 assert.equal(r.rows.length,1592);assert.equal(r.summary.reviewedAttributes,57312);assert.equal(JSON.stringify(master),before);
 for(let i=0;i<1592;i++){const p=master.players[i],q=copy.players[i];for(const k of ['id','club','league','birthYear','potential','hiddenTraitsV2','gameplayPosition'])assert.deepEqual(q[k],p[k]);assert.equal(Object.keys(q.attributesV2).length,36);assert.ok(Object.values(q.attributesV2).every(v=>Number.isInteger(v)&&v>=20&&v<=97));assert.equal(Object.keys(q.skills).length,11);assert.ok(q.ratingV12>=20&&q.ratingV12<=97);}
 assert.throws(()=>R.apply(copy,r),/baseline/);
 assert.equal(Object.keys(r.groups).length,11);assert.ok(Object.values(r.groups).every(g=>g.gapAfter>0));
});
test('V12 nom et ordre ne créent aucune compétence ; joueurs non observés restent estimés',()=>{
 const a=R.review(master,evidence,extra);const reversed=structuredClone(master);reversed.players.reverse();const b=R.review(reversed,evidence,extra);
 const map=new Map(b.rows.map(x=>[x.playerId,x]));for(const row of a.rows)assert.deepEqual(row,map.get(row.playerId));
 const unknown=a.rows.find(x=>x.evidenceRecordCount===0);assert.ok(unknown);assert.equal(unknown.quality,'gameplay-estimate');
 assert.equal(a.method.usesNameOrIdNoise,false);assert.equal(a.method.stacksPreviousCandidates,false);
});
test('V12 un faible temps de jeu ne donne ni blessure inventée ni malus, les taux ont un dénominateur',()=>{
 const a=R.buildEvidence(master,evidence,extra);assert.ok(a.summary.strictMatched>=426);
 const rates=[...a.byId.values()].filter(x=>x.kicking);assert.ok(rates.length>10);
 assert.ok(rates.every(r=>r.kicking.attempted>=r.kicking.made));
 const bad=structuredClone(extra);bad.lists[0].rows[0].observed.nbConversionMade='999';assert.throws(()=>R.buildEvidence(master,evidence,bad),/kicking/);
});
test('V12 exposition et but sont séparés du physique et des traits cachés',()=>{
 const a=R.buildEvidence(master,evidence,extra),r=R.review(master,evidence,extra),p=master.players.find(p=>p.realName==='Thomas RAMOS');
 assert.equal(a.byId.get(p.id).kicking.attempted,80);assert.equal(a.byId.get(p.id).kicking.made,66);
 const row=r.rows.find(x=>x.playerId===p.id);assert.ok(row.attributes[R.KEYS.indexOf('goalAccuracy')]>p.attributesV2.goalAccuracy);
 const altered=structuredClone(extra);altered.lists=altered.lists.filter(l=>l.league!=='top14');const b=R.review(master,evidence,altered).rows.find(x=>x.playerId===p.id);
 for(const key of ['strength','topSpeed','acceleration','endurance'])assert.equal(row.attributes[R.KEYS.indexOf(key)],b.attributes[R.KEYS.indexOf(key)]);
});
test('V12 rejette les carrières incomplètes, candidats altérés et périodes futures',()=>{
 assert.throws(()=>R.review(master,evidence,extra,{schema:'rugby-real-v12-public-careers',completed:false}),/Incomplete/);
 const r=R.review(master,evidence,extra);r.rows[0].attributes[0]=Infinity;assert.throws(()=>R.apply(master,r),/Invalid/);
 const bad=structuredClone(extra);bad.performanceAssessments[0].season='2026-2027';assert.throws(()=>R.review(master,evidence,bad),/assessment/);
});
const N=require('../tools/rugby-real-v12/native.cjs');
test('V12 projection native consomme les notes revues et reste déterministe',()=>{
 const reviewed=R.apply(master,R.review(master,evidence,extra,careers)),lab=N.laboratory(reviewed),a=lab.clubs[0],b=lab.clubs.find(c=>c.league==='prod2');
 const x=lab.match(a,b,774);assert.deepEqual(lab.match(a,b,774),x);assert.ok(x.duration>=80);assert.equal(x.engine,2);
 const swapped={...a,league:'prod2'};assert.deepEqual(lab.match(swapped,b,774),x);
 const base=N.laboratory(master);assert.notDeepEqual(base.match(base.clubs[0],base.clubs.find(c=>c.league==='prod2'),774),x);
});

test('V12 collecte totale distingue 1592 tentatives et statistiques réellement disponibles',()=>{
 const e=R.buildEvidence(master,evidence,extra,careers);
 assert.equal(careers.records.length,1592);assert.equal(careers.completed,true);assert.equal(e.summary.careerAttempted,1592);
 assert.ok(e.summary.careerPlayers202526>300);assert.ok(e.summary.careerPlayers3Seasons>300);
 assert.ok(careers.records.some(r=>r.status==='unknown'&&r.reason.includes('403')));
 for(const r of careers.records.filter(r=>r.status==='unknown'))assert.equal(r.seasons.length,0);
 const bad=structuredClone(careers);bad.records[0].name='Wrong identity';assert.throws(()=>R.buildEvidence(master,evidence,extra,bad),/identity/);
});
test('V12 import candidat refuse clés, compétences dérivées, rôle et note incohérents',()=>{
 const r=R.review(master,evidence,extra,careers);
 for(const change of [r=>r.attributeKeys.reverse(),r=>r.skillKeys.reverse(),r=>r.rows[0].ratingV12=999,r=>r.rows[0].skills[0]=21,r=>r.rows[0].role='Arrière']){const bad=structuredClone(r);change(bad);assert.throws(()=>R.apply(master,bad),/Invalid|mismatch/);}
});
test('V12 les stars PRO D2 restent dans la distribution TOP14 sans bonus de promotion',()=>{
 const r=R.review(master,evidence,extra,careers),a=r.rows.filter(x=>x.league==='top14').map(x=>x.ratingV12),b=r.rows.filter(x=>x.league==='prod2').map(x=>x.ratingV12);
 assert.ok(Math.max(...b)>R.mean(a));assert.ok(Object.values(r.groups).every(g=>g.gapAfter<12));
 const p=master.players.find(p=>p.realName==='Setareki BITUNIYATA'),row=r.rows.find(x=>x.playerId===p.id);assert.equal(row.domainEvidence.honours,1);assert.ok(row.flags.includes('bounded-qualitative-performance-anchor-not-measured-attributes'));
});

test('V12 une distinction collective ne réécrit pas le taux de but observé',()=>{
 const r=R.review(master,evidence,extra,careers),stripped=structuredClone(extra);stripped.honours=[];stripped.performanceAssessments=[];
 const b=R.review(master,evidence,stripped,careers),byId=new Map(b.rows.map(r=>[r.playerId,r])),i=R.KEYS.indexOf('goalAccuracy');
 for(const row of r.rows)assert.equal(row.attributes[i],byId.get(row.playerId).attributes[i]);
});

test('V12 les identifiants observés et statistiques partielles corrompus sont rejetés',()=>{
 const a=structuredClone(extra);a.lists[0].rows[0].lnrId='999999';assert.throws(()=>R.buildEvidence(master,evidence,a),/identity/);
 const b=structuredClone(evidence);b.observations[0].stats.tacklesMade=-20;assert.throws(()=>R.buildEvidence(master,b,extra),/partial/);
});

test('V12 peu de minutes n’invente pas de faiblesse et nom/ID ne donnent pas de points',()=>{
 const a=R.review(master,evidence,extra),unknown=a.rows.find(r=>r.evidenceRecordCount===0),p=master.players.find(p=>p.id===unknown.playerId);
 const central=structuredClone(evidence);central.careerSeasonRows.push({name:p.realName,season:'2025-2026',competition:'TOP 14',sourceUrl:'https://top14.lnr.fr/joueur/synthetic-test-only',stats:{matches:2,minutes:80,tries:0,points:0}});
 const low=R.review(master,central,extra).rows.find(r=>r.playerId===p.id);assert.deepEqual(low.attributes,unknown.attributes);
 const renamed=structuredClone(master),q=renamed.players.find(q=>q.id===p.id);q.id='lnr:999999999';q.realName='Synthetic unobserved test player';const b=R.review(renamed,evidence,extra).rows.find(r=>r.playerId===q.id);
 assert.deepEqual(b.attributes,unknown.attributes);assert.deepEqual(b.skills,unknown.skills);
});
test('V12 maturité distincte : vitesse décline plus tôt que force, jeunes non déjà à maturité',()=>{
 const f=(age,k)=>R.maturity({ageApprox:age},k);
 assert.ok(f(18,'strength')<f(25,'strength'));assert.ok(f(18,'decisions')<f(28,'decisions'));
 assert.ok(f(32,'topSpeed')<f(28,'topSpeed'));assert.equal(f(32,'strength'),f(28,'strength'));
 assert.ok(f(37,'strength')<f(32,'strength'));assert.ok(f(37,'topSpeed')<f(37,'strength'));
});

test('V12 diagnostic de profondeur et sensibilité : même moteur, 15+8, cinq mouvements, deux domiciles',()=>{
 const M=require('../tools/rugby-real-v12/calibration.cjs');
 const r=M.run({seeds:2});assert.equal(r.matchCount,60);
 assert.equal(r.variants.length,3);assert.deepEqual(r.variants.map(v=>v.coefficient),[.004,.008,.012]);
 assert.equal(r.selection.incoming.length,5);assert.equal(r.selection.leaving.length,5);
 assert.equal(r.change.departures.replacementStarters.length,5);
 assert.equal(r.change.recruited.replacementStarters.length,5);
 for(const name of Object.keys(r.rosters)){assert.equal(r.rosters[name].lineup.length,15);assert.equal(r.rosters[name].bench.length,8);}
 for(const v of r.variants)for(const s of Object.values(v.scenarios)){assert.equal(s.matches,4);assert.ok(Number.isFinite(s.margin));assert.ok(Number.isFinite(s.winPct));}
});

test('V12 profondeur: 1592 IDs invariants, 36 attributs, potentiel et six traits préservés',()=>{
 const D=require('../tools/rugby-real-v12/depth.cjs');
 const base=R.apply(master,require('../data/scouting/review-v12/candidate.json'));
 const original=JSON.stringify(base);
 const a=D.build(base,'mild'),b=D.build(base,'pronounced');
 assert.equal(JSON.stringify(base),original);
 for(const d of [a,b]){
  assert.equal(d.changes.length,1592);
  assert.equal(d.tiers.length,1592);
  assert.equal(new Set(d.tiers.map(x=>x.id)).size,1592);
  for(let i=0;i<base.players.length;i++){
   const p=base.players[i],q=d.master.players[i];
   for(const k of ['id','club','league','birthYear','potential','hiddenTraitsV2','gameplayPosition','ageApprox','rating'])assert.deepEqual(q[k],p[k]);
   assert.equal(Object.keys(q.attributesV2).length,36);
   assert.ok(Object.values(q.attributesV2).every(v=>Number.isInteger(v)&&v>=20&&v<=97));
   assert.deepEqual(q.skills,R.project(q));
   assert.equal(q.ratingV12,Math.round(R.ability(q.attributesV2,q.gameplayPosition)));
   const changed=new Set(R.ROLES[p.gameplayPosition]);
   for(const k of R.KEYS)if(!changed.has(k))assert.equal(q.attributesV2[k],p.attributesV2[k]);
  }
  assert.ok(d.audit.some(x=>x.eligible15x8));
 }
 assert.throws(()=>D.build(base,'invalid'),/variant/);
});
test('V12 profondeur: trois variantes, mouvements figés, 15+8 et vrai moteur déterministe',()=>{
 const Q=require('../tools/rugby-real-v12/depth-campaign.cjs');
 const r=Q.run({seeds:2});
 assert.equal(r.matchCount,60);
 assert.deepEqual(r.variants.map(x=>x.variant),['baseline','mild','pronounced']);
 assert.equal(r.fixedRecruits.length,5);assert.equal(r.fixedDepartures.length,5);
 for(const v of r.variants){
  assert.equal(v.roster.promoted.lineup.length,15);
  assert.equal(v.roster.promoted.bench.length,8);
  assert.equal(v.roster.lost.lineup.length,15);
  assert.equal(v.roster.lost.bench.length,8);
  assert.equal(Object.keys(v.summary).length,5);
  for(const s of Object.values(v.summary)){assert.equal(s.matches,4);assert.ok(Number.isFinite(s.margin));}
 }
 for(const name of ['mild','pronounced']){
  assert.ok(r.tierAudits[name].roleAbilityMeanDelta.star>0);
  assert.ok(r.tierAudits[name].roleAbilityMeanDelta.bench<0);
  assert.ok(r.tierAudits[name].roleAbilityMeanDelta.rotation<0);
 }
});

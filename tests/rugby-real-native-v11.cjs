'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const C=require('../tools/rugby-real-v11/calibration.cjs');
const master=require('../modding/data06/rugby-master-2026-2027.json');
test('V11 consolidation non destructive, préconditions et intégrité 36/6/potentiel',()=>{
 const before=JSON.stringify(master),r=C.consolidate(master),copy=C.apply(master,r);
 assert.equal(JSON.stringify(master),before);assert.equal(r.candidates.length,1592);
 for(let i=0;i<1592;i++){
  assert.equal(copy.players[i].id,master.players[i].id);
  assert.deepEqual(copy.players[i].hiddenTraitsV2,master.players[i].hiddenTraitsV2);
  assert.equal(copy.players[i].potential,master.players[i].potential);
  assert.equal(Object.keys(copy.players[i].attributesV2).length,36);
  if(master.players[i].league==='prod2')assert.deepEqual(copy.players[i],master.players[i]);
 }
 assert.throws(()=>C.apply(copy,r),/baseline|already|precondition/);
 assert.ok(Object.values(r.roleAudit).every(x=>x.gapAfter>x.gapBefore));
});
test('V11 projection utilise 36 attributs, jamais la division actuelle',()=>{
 const p=master.players[0],a=C.project(p);
 assert.deepEqual(C.project({...p,league:'prod2',club:'test'}),a);
 assert.equal(Object.keys(a).length,11);
 const used=new Set();for(const weights of Object.values(C.PROJECTION))for(const k of Object.keys(weights))used.add(k);
 assert.equal(used.size,36);
 for(const k of used){const q=structuredClone(p);q.attributesV2[k]=q.attributesV2[k]>80?20:97;assert.notDeepEqual(C.project(q),a,k+' ignored');}
});
const N=require('../tools/rugby-real-v11/native.cjs');
test('V11 vrai moteur, déterminisme, domicile alterné, état frais et effet des attributs',()=>{
 const lab=N.laboratory(master,'projected'),clubs=lab.clubs;
 const top=clubs.filter(c=>c.league==='top14')[0],pro=clubs.filter(c=>c.league==='prod2')[0];
 const a=lab.match(top,pro,42),b=lab.match(top,pro,42);
 assert.deepEqual(a,b);assert.equal(a.engine,2);assert.ok(a.duration>=80);assert.equal(a.minutes.length,2);
 assert.ok(a.minutes.every(x=>x>900));assert.ok(a.conditionLoss.every(x=>x>0));
 assert.ok(a.tacticalStats[0].carries>0);
 const weak=structuredClone(top);for(const p of weak.players)for(const k in p.skills)p.skills[k]=20;
 assert.notDeepEqual(lab.match(weak,pro,42),a);
 const renamed={...top,league:'prod2'};assert.deepEqual(lab.match(renamed,pro,42),a);
});
test('V11 recrues ciblées et départs effectifs sans joueur dupliqué',()=>{
 const lab=N.laboratory(C.apply(master,C.consolidate(master)),'projected'),top=lab.clubs.filter(c=>c.league==='top14'),pro=lab.clubs.find(c=>c.league==='prod2');
 const recruitment=N.recruit(pro,top,5,lab);
 assert.equal(recruitment.moves.length,5);assert.equal(recruitment.club.players.length,pro.players.length+5);
 assert.equal(new Set(recruitment.club.players.map(p=>p.id)).size,recruitment.club.players.length);
 assert.ok(recruitment.moves.every(m=>m.gain>0));
 const departed=N.depart(top[0],5,lab);assert.equal(departed.moves.length,5);assert.equal(departed.club.players.length,top[0].players.length-5);
});
const H=require('../tools/rugby-real-v11/history.cjs');
const collection=require('../data/scouting/performance-2025-26-v11.json');
test('V11 collecte historique centralisée, inconnus explicites et absence de double cumul',()=>{
 const before=JSON.stringify(collection),r=H.audit(master,collection);
 assert.equal(r.rankingRows,800);assert.ok(r.distinctMatched>122);assert.ok(r.newMatchedSinceV8V9>100);
 assert.equal(r.careerRows,6);assert.equal(r.midseasonObservations,3);assert.equal(r.ambiguous.length,0);
 assert.ok(r.lowMinuteCareerRows>=5);assert.ok(r.forwardPlayers>50);assert.ok(r.youngPlayers>20);
 assert.equal(JSON.stringify(collection),before);
 const bad=structuredClone(collection);bad.lists[0].season='2026-2027';assert.throws(()=>H.audit(master,bad),/season/);
 const negative=structuredClone(collection);negative.lists[0].ranking[0].stats.minutes=-1;assert.throws(()=>H.audit(master,negative),/stat/);
});
const seasons=require('../tools/rugby-real-v11/seasons.cjs');
test('V11 ancien état LNR 15 ans : échec natif reproduit et proposition isolée stricte',()=>{
 const g=seasons.boot(),p=g.run('S.clubs.flatMap(c=>c.players).find(p=>p.age===15).id');
 assert.ok(p);g.ctx.__id=p;
 g.run("S.clubs.flatMap(c=>c.players).find(p=>p.id===__id).dev.history.push({season:1,age:15,start:70,end:70,minutes:0,appearances:0})");
 const parse=()=>g.run('parseSaveDocument(JSON.stringify(createSaveDocument()))');
 assert.throws(parse,/incohérentes/);
 seasons.applySaveProposal(g);assert.doesNotThrow(parse);
 g.run('S.clubs.flatMap(c=>c.players).find(p=>p.id===__id).dev.history[0].age=14');assert.throws(parse,/incohérentes/);
 const {context}=require('./harness.cjs'),f=context();f.run('start(0)');seasons.applySaveProposal(f);
 f.run('club().players[0].dev.history.push({season:1,age:15,start:70,end:70,minutes:0,appearances:0})');
 assert.throws(()=>f.run('parseSaveDocument(JSON.stringify(createSaveDocument()))'),/incohérentes/);
});
test('V11 compétences projetées compatibles avec le format natif sans nouveaux champs',()=>{
 const g=seasons.boot();g.ctx.__skills=C.project(master.players[0]);
 g.run('club().players[0].skills=__skills');
 const doc=JSON.parse(g.run('JSON.stringify(createSaveDocument())'));
 g.ctx.__doc=JSON.stringify(doc);g.run('pendingSave=parseSaveDocument(__doc)');
 assert.equal(g.run('confirmSaveImport()'),true);assert.deepEqual(JSON.parse(g.run('JSON.stringify(club().players[0].skills)')),C.project(master.players[0]));
});
test('V11 réponse au niveau : proposition ne dépend que des compétences dans le vrai moteur',()=>{
 const response=N.laboratory(master,'projected',{qualityCoefficient:.012});
 const normal=N.laboratory(master,'projected');
 const top=response.clubs.find(c=>c.league==='top14'),pro=response.clubs.find(c=>c.league==='prod2');
 assert.notDeepEqual(response.match(top,pro,12345),normal.match(top,pro,12345));
 assert.deepEqual(response.match({...top,league:'prod2'},pro,12345),response.match(top,pro,12345));
 assert.throws(()=>N.laboratory(master,'projected',{qualityCoefficient:2}),/coefficient/);
});
const A=require('../tools/rugby-real-v11/aging.cjs');
test('V11 vieillissement différencié : jeune progresse, vétéran perd surtout son physique',()=>{
 const p=structuredClone(master.players.find(p=>p.gameplayPosition==='Ailier'));for(const k in p.attributesV2)p.attributesV2[k]=65;p.potential=90;
 const before=JSON.stringify(p),young=A.step(p,{age:19,season:1},{minutes:1600,training:1});
 const old=A.step(p,{age:35,season:1},{minutes:1600,training:1});
 assert.ok(C.mean(Object.values(young.player.attributesV2))>65);
 assert.ok(old.player.attributesV2.acceleration<65);assert.ok(old.player.attributesV2.topSpeed<65);
 assert.ok(old.player.attributesV2.strength>old.player.attributesV2.acceleration);
 assert.ok(old.player.attributesV2.decisions>=65);assert.ok(old.player.attributesV2.passing>old.player.attributesV2.acceleration);
 assert.equal(JSON.stringify(p),before);assert.deepEqual(old.player.hiddenTraitsV2,p.hiddenTraitsV2);assert.equal(old.player.potential,90);
 assert.deepEqual(A.step(young.player,young.state,{minutes:1600,training:1}).player,young.player);
 const rested=A.step(p,{age:19,season:1},{minutes:0,training:0});assert.deepEqual(rested.player.attributesV2,p.attributesV2);
 assert.throws(()=>A.step(p,{age:19,season:1},{minutes:-3,training:1}),/exposure/);
 assert.equal(Object.keys(A.CURVES).length,11);
});
test('V11 maturité par poste, bornes 20-97 et trajectoires déterministes 18→40',()=>{
 const trajectories=A.trajectories(master);
 assert.equal(trajectories.length,11);assert.ok(trajectories.every(t=>t.years.length===23));
 for(const t of trajectories){assert.ok(t.years.at(-1).physical<t.years.find(y=>y.age===27).physical);assert.ok(t.peakAge>18&&t.peakAge<40);}
 assert.deepEqual(A.trajectories(master),trajectories);
});
test('V11 période des observations carrière vérifiée et âge malformé refusé',()=>{
 const bad=structuredClone(collection);bad.careerSeasonRows[0].season='2026-2027';assert.throws(()=>H.audit(master,bad),/season/);
 bad.careerSeasonRows[0].season='2025-2026';bad.careerSeasonRows[0].sourceUrl='https://example.com/fake';assert.throws(()=>H.audit(master,bad),/identity/);
 const p=structuredClone(master.players[0]);p.attributesV2.topSpeed=NaN;assert.throws(()=>A.step(p,{age:20,season:1}),/attributes/);
 assert.throws(()=>A.step(master.players[0],{age:20,season:2,playerId:'wrong'}),/identity/);
});
test('V11 intervalles regroupés par graine et idempotence saison typée',()=>{
 const {summarize}=require('../tools/rugby-real-v11/campaign.cjs');
 const lab=N.laboratory(master),a=lab.clubs[0],b=lab.clubs[1];
 const rows=[];for(const seed of [0,1,2,3])for(const home of [0,1])rows.push({seed,home,...lab.match(a,b,seed,{home})});
 const r=summarize(rows);assert.equal(r.matches,8);assert.match(r.winIntervalMethod,/seed-cluster/);assert.ok(r.win95[0]>=0&&r.win95[1]<=100);
 const p=master.players[0];assert.throws(()=>A.step(p,{age:20,season:1,lastSeason:'1'}),/lastSeason/);
});
test('V11 la boucle observée rend les mêmes scores que rugbySimulate natif',()=>{
 const lab=N.laboratory(master),a=lab.clubs[0],b=lab.clubs[1],seed=421;
 const expected=lab.match(a,b,seed);lab.g.ctx.__players=[structuredClone(a.players),structuredClone(b.players)];
 lab.g.run('for(let i=0;i<2;i++){S.clubs[i].players=__players[i];S.clubs[i].players.forEach(p=>{ensureDevelopment(p);ensurePhysicalLoad(p)})}');
 lab.g.ctx.__seed=seed;const actual=JSON.parse(lab.g.run('JSON.stringify((()=>{let value=__seed;Math.random=()=>{value=(Math.imul(value,1664525)+1013904223)>>>0;return value/4294967296};return rugbySimulate([0,1])})())'));
 for(const key of ['score','tries','stats','weather','duration'])assert.deepEqual(actual[key],expected[key],key);
});
test('V11 candidat livré reproductible et patchs inactifs dans les sources natives',()=>{
 assert.deepEqual(C.consolidate(master),require('../data/scouting/consolidated-v11.json'));
 const fs=require('node:fs');assert.ok(fs.readFileSync(__dirname+'/../dist/tactical-plans.js','utf8').includes('(attack-defence)*.004'));
 assert.ok(fs.readFileSync(__dirname+'/../dist/saves.js','utf8').includes('saveInt(h.age,16,60)'));
 assert.ok(!fs.readFileSync(__dirname+'/../dist/lnr-career.js','utf8').includes('attributesV2'));
});

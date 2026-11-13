'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const root=path.resolve(__dirname,'..'),builderPath=path.join(root,'scripts/build-world-registry.cjs');
assert.ok(fs.existsSync(builderPath),'Le compilateur mondial autorisé doit exister.');
const api=require(builderPath),common=require('../dist/rugby-common-rosters.js');
const clone=x=>JSON.parse(JSON.stringify(x));
const world=api.build(),all=world.clubs.flatMap(c=>c.players),old=new Map(common.clubs.flatMap(c=>c.players).map(p=>[p.id,p]));
assert.equal(world.id,'rugby-world-2026-11-08-v1');assert.equal(world.version,1);assert.equal(world.snapshot,'2026-11-08');assert.equal(world.clubCount,58);assert.equal(world.clubs.length,58);assert.deepEqual(world.clubs.map(c=>c.id),Array.from({length:58},(_,i)=>i));
assert.deepEqual(world.initialEurope?.champions?.map(p=>p.length),[6,6,6,6],'Quatre poules Champions sourcées');assert.deepEqual(world.initialEurope?.challenge?.map(p=>p.length),[6,6,6],'Trois poules Challenge sourcées');assert.equal(new Set([...world.initialEurope.champions.flat(),...world.initialEurope.challenge.flat()]).size,42);
const urc=world.initialFixtures?.urc;assert.equal(urc?.length,144,'144 dates URC publiées');
assert.equal(new Set(urc.map(x=>x.sourceFixtureId)).size,144,'Rencontres source uniques');
assert.deepEqual(world.initialKnockoutDates.urc,{quarter:'2027-05-28',semi:'2027-06-05',final:'2027-06-19'});
for(const c of world.clubs.filter(c=>c.leagueId==='urc')){assert.equal(urc.filter(x=>x.homeId===c.id).length,9);assert.equal(urc.filter(x=>x.awayId===c.id).length,9);}
for(let round=0;round<18;round++){const rows=urc.filter(x=>x.round===round);assert.equal(rows.length,8);assert.equal(new Set(rows.flatMap(x=>[x.homeId,x.awayId])).size,16,'Un match par club et journée URC');}
assert.ok(urc.every(x=>Object.keys(x).length===11&&x.scheduleSource==='official-snapshot'&&x.sourceRef==='urc-202627-matchstats-20261108'),'Source explicite et aucun résultat réel importé');
assert.equal(world.initialFixtures.champions?.length,48,'48 dates Champions Cup publiées');
assert.equal(world.initialFixtures.challenge?.length,36,'36 dates Challenge Cup publiées');
const prem=world.initialFixtures.prem;
assert.equal(prem?.length,90,'90 rencontres de PREM avec les dates source');
assert.deepEqual(world.initialKnockoutDates.prem,{semi:'2027-06-12',final:'2027-06-19'});
const shifted=prem.filter(x=>x.scheduleSource==='game-adjusted-from-official');
assert.deepEqual(shifted.map(x=>[x.sourceFixtureId,x.sourceDate,x.date]),[[294947,'2026-12-28','2026-12-27']]);
assert.equal(prem.filter(x=>x.scheduleSource==='official-snapshot-provisional').length,45);
for(const c of world.clubs.filter(c=>c.leagueId==='prem')){assert.equal(prem.filter(x=>x.homeId===c.id).length,9);assert.equal(prem.filter(x=>x.awayId===c.id).length,9);}
assert.deepEqual(world.initialFixtures.challenge.filter(x=>x.scheduleSource==='official-snapshot-provisional').map(x=>x.sourceFixtureId),[293415]);
const combined=Object.values(world.initialFixtures).flat(),appearances=combined.flatMap(x=>[x.homeId,x.awayId].map(id=>id+':'+Math.floor((Date.parse(x.date)+3*86400000)/604800000)));
assert.equal(combined.length,318);assert.equal(new Set(appearances).size,appearances.length,'Aucune collision hebdomadaire entre PREM, URC et coupes');
for(const k of ['champions','challenge'])for(const [i,pool] of world.initialEurope[k].entries())for(const id of pool){const xs=world.initialFixtures[k].filter(x=>x.poolId===i);assert.equal(xs.filter(x=>x.homeId===id).length,2);assert.equal(xs.filter(x=>x.awayId===id).length,2);}
assert.equal(new Set(world.clubs.map(c=>c.key)).size,58);assert.equal(new Set(all.map(p=>p.id)).size,all.length);assert.equal(world.playerCount,all.length);
for(const [id,p] of old){const copies=all.filter(q=>q.id===id);assert.equal(copies.length,1,id+' unique');assert.deepEqual(copies[0],p,id+' profil français inchangé');}
for(const p of all.filter(p=>p.id.startsWith('world:'))){assert.equal(p.worldRatingsVersion,1,'Modèle mondial V12 explicite');assert.equal(Object.hasOwn(p,'lnrRatingsVersion'),false,'Pas de provenance LNR étrangère');}
assert.equal(world.clubs.slice(0,30).every((c,i)=>c.key===common.clubs[i].slug),true);
assert.deepEqual(world.leagues.map(x=>x.id),['elite','accession','prem','urc','guest']);
for(const c of world.clubs){assert.ok(['FR','GB','IE','IT','ZA','GE'].includes(c.country));assert.ok(c.players.length>=23,c.key+' effectif source minimal pour une feuille');}
const game=fs.readFileSync(path.join(root,'dist/game.js'),'utf8');
const positions=game.split(/\r?\n/).filter(line=>/^const (?:POS|FAMILIES)=/.test(line)).join('\n');
const engine=fs.readFileSync(path.join(root,'dist/rugby.js'),'utf8');
const buildSheet=vm.runInNewContext(positions+'\n'+engine+'\nbuildSheet',{clamp:(x,a,b)=>Math.max(a,Math.min(b,x)),focusedBonus:()=>0});
for(const c of world.clubs.slice(30)){const {lineup,bench}=buildSheet(c);const ids=[...lineup,...bench];assert.equal(ids.filter(Boolean).length,23,c.key+' doit fournir une feuille initiale avec le sélecteur du jeu');assert.equal(new Set(ids).size,23,c.key+' feuille initiale sans doublon');}
const foreign=all.filter(p=>!old.has(p.id));assert.ok(foreign.length>900,'Nouveaux effectifs étrangers substantiels');
const salaryPolicy = world.provenance.premStartingSalary;
assert.deepEqual(salaryPolicy, {
  rule: 'world-prem-starting-payroll-v1', percentage: 85, basis: 'fictional-game-parameter'
});
for (const club of world.clubs) {
  for (const player of club.players.filter(p => !old.has(p.id))) {
    const baseline = Math.round(1800 + Math.max(0, player.rating - 45) ** 2 * 6);
    const expected = club.leagueId === 'prem' ? Math.round(baseline * 85 / 100) : baseline;
    assert.equal(player.salary, expected, `${club.key} ${player.id} suit le barème salarial de son groupe`);
  }
}
for(const p of foreign){const term=world.worldProfiles[p.id].contract;assert.ok(Number.isInteger(p.contractEnd)&&p.contractEnd>=1);assert.equal(term.endSeason,p.contractEnd);assert.equal(term.endYear,2026+p.contractEnd);assert.ok(['official','estimated'].includes(term.basis));}
for(const p of foreign.filter(p=>world.worldProfiles[p.id].factConflicts.includes('birth-date-conflict'))){assert.equal(p.ageEstimated,true);assert.equal(Object.hasOwn(p,'birthDate'),false,'Une DOB contradictoire ne devient pas un fait publié dans le jeu');}
const attr=Object.keys(common.clubs[0].players[0].attributesV2),skills=Object.keys(common.clubs[0].players[0].skills),traits=Object.keys(common.clubs[0].players[0].hiddenTraitsV2),dev=Object.keys(common.clubs[0].players[0].dev);
const oldVectors=new Set([...old.values()].map(p=>JSON.stringify(p.attributesV2))),newVectors=new Set();
for(const p of foreign){assert.match(p.id,/^world:/);assert.ok(Number.isInteger(p.age)&&p.age>=15&&p.age<=60);assert.deepEqual(Object.keys(p.attributesV2),attr);assert.deepEqual(Object.keys(p.skills),skills);assert.deepEqual(Object.keys(p.hiddenTraitsV2),traits);assert.deepEqual(Object.keys(p.dev),dev);assert.ok(Object.values(p.attributesV2).every(x=>Number.isFinite(x)&&x>=20&&x<=97));assert.ok(Object.values(p.skills).every(x=>Number.isFinite(x)&&x>=15&&x<=99));assert.ok(p.potential>=p.rating&&p.potential<=97);assert.equal(p.dev.potential,p.potential);assert.deepEqual(p.skills,api.projectSkills(p.attributesV2,p.gameplayPosition));assert.equal(p.skillBase,p.rating);assert.ok(!oldVectors.has(JSON.stringify(p.attributesV2)),'pas de clone français '+p.id);newVectors.add(JSON.stringify(p.attributesV2));assert.ok(world.worldProfiles[p.id],p.id+' estimation documentée');assert.equal(world.worldProfiles[p.id].rating.basis,'estimated');assert.equal(world.worldProfiles[p.id].potential.basis,'estimated');}
assert.ok(newVectors.size>foreign.length*.98,'Profils individuels distincts');
assert.ok(!/https?:\/\/|\.(?:webp|png|jpg)|[A-Z]:\\/.test(JSON.stringify([world.clubs.slice(30),world.worldProfiles,api.readInputs()])),'Aucun lien nominatif ou asset privé dans les données mondiales nouvelles');
const first=JSON.stringify(world),input=api.readInputs(),reversed=clone(input);reversed.players.reverse();
assert.equal(JSON.stringify(api.build({inputs:reversed})),first,'Indépendant de l’ordre de collecte');
const random=Math.random,now=Date.now;try{Math.random=()=>{throw Error('RNG de carrière interdit')};Date.now=()=>{throw Error('Horloge ambiante interdite')};assert.equal(JSON.stringify(api.build()),first,'Pas de RNG/horloge ambiante');}finally{Math.random=random;Date.now=now;}
const normal=api.normalizeExposure({minutes:0,matches:0,status:'unusable_zero_placeholder'});assert.equal(normal.minutes,null);assert.equal(normal.matches,null);assert.equal(normal.per80Allowed,false);
const hook=Object.fromEntries(attr.map(k=>[k,60]));hook.lineoutThrow=90;assert.equal(api.projectSkills(hook,'Talonneur').lineout,79.5);assert.equal(api.projectSkills(hook,'Deuxième ligne').lineout,61.5);
// Garde-fous de calibration génériques (sans donnée nominative) : élite > accession
// à chaque poste, écart borné avec recouvrement des meilleurs joueurs d'accession,
// et potentiel jamais inférieur à la note sur toute la base Monde.
{
  const mean=a=>a.reduce((n,v)=>n+v,0)/a.length,byRole=new Map();
  for(const c of world.clubs){if(c.id>=30)continue;for(const p of c.players){const role=p.gameplayPosition||p.pos;if(!byRole.has(role))byRole.set(role,{elite:[],accession:[]});byRole.get(role)[c.id<14?'elite':'accession'].push(p.rating);}}
  assert.equal(byRole.size,11,'Onze postes dans les deux divisions françaises');
  for(const [role,g] of byRole){assert.ok(g.elite.length>=30&&g.accession.length>=30,role+' : effectif trop faible');const gap=mean(g.elite)-mean(g.accession);assert.ok(gap>=3&&gap<12,`${role} : écart élite/accession ${gap.toFixed(2)} hors de [3 ; 12[`);}
  const elite=[...byRole.values()].flatMap(g=>g.elite),accession=[...byRole.values()].flatMap(g=>g.accession);
  assert.ok(Math.max(...accession)>mean(elite),'Les meilleurs joueurs d’accession restent compétitifs en élite');
  for(const p of all){const potential=p.dev?.potential??p.potential;assert.ok(Number.isFinite(potential)&&potential>=p.rating&&potential<=99,p.id+' : potentiel incohérent avec la note');}
}
const malicious=clone(world);malicious.clubs[30].players[0].skills.tackle=NaN;assert.throws(()=>api.validate(malicious),/profil|compétence|fini|nombre|qualité/i);
const bad=clone(world);bad.clubs[31].players[0].id=bad.clubs[30].players[0].id;assert.throws(()=>api.validate(bad),/dupliqué|unique|identifiant/i);
const collision=clone(world);const conflicting=collision.initialFixtures.champions.find(x=>x.homeId>=40||x.awayId>=40);const overlap=conflicting.homeId>=40?conflicting.homeId:conflicting.awayId;conflicting.date=urc.find(x=>x.homeId===overlap||x.awayId===overlap).date;assert.throws(()=>api.validate(collision),/Collision de calendrier/);
const importedResult=clone(world);importedResult.initialFixtures.challenge[0].score=[15,3];assert.throws(()=>api.validate(importedResult),/Rencontre européenne invalide/);
api.write(true);assert.equal(fs.readFileSync(path.join(root,'native/engine/world-registry.json'),'utf8'),api.serialize(world));
console.log(JSON.stringify({passed:true,clubs:world.clubs.length,players:all.length,frenchProfiles:old.size,foreignProfiles:foreign.length,distinctForeignProfiles:newVectors.size,bytes:Buffer.byteLength(first),checks:['France1592 exact global','58 fixed club IDs','28 initial match sheets 23/23','318 source fixtures, no score or collision','schema, estimates and contracts','36→11 exact projection','no profile clones','input order + ambient seed/time independence','placeholder exposure unknown','duplicate/NaN refusal','compiled JSON current','elite>accession per role, potential>=rating']}));

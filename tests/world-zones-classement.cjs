'use strict';
// Zones de classement de la carrière Monde (world-champ) : les zones publiées par le modèle
// (native/engine/world-standings-zones.json, projetées par world-model.cjs) décrivent ce que le moteur
// de fin de saison applique réellement. Une saison complète est jouée (graine fixe), puis la saison 2
// est ouverte ; on compare le classement final, les têtes de série, les barrages et les archives
// (S.worldMode.yearbook) aux zones annoncées.
const assert=require('node:assert/strict');
const {context}=require('./monde-harness.cjs');
const DATA=require('../native/engine/world-standings-zones.json');

const KINDS={bye:'★',playoff:'●','promotion-playoff':'▲','relegation-playoff':'◆',relegation:'▼',repechage:'○'};
const LEAGUES=['elite','accession','prem','urc','srp','jlo-d1','jlo-d2','nationale','champ'];
const CUPS=['champions','challenge'];
const sameSet=(a,b,message)=>assert.deepEqual([...a].sort((x,y)=>x-y),[...b].sort((x,y)=>x-y),message);
const ranksOf=(league,...kinds)=>league.zones.filter(z=>kinds.includes(z.kind)).flatMap(z=>Array.from({length:z.to-z.from+1},(_,i)=>z.from+i));
// Clubs du classement final (ordre de la saison régulière) aux rangs donnés.
const at=(standing,ranks)=>ranks.map(rank=>standing[rank-1]);

// 1. La donnée elle-même : symboles, rangs cohérents, libellés courts (fiche UX 16 §13 : 22 caractères).
assert.deepEqual(DATA.symbols,KINDS,'six types de zone et leur symbole');
assert.deepEqual(Object.keys(DATA.competitions).sort(),[...LEAGUES,...CUPS].sort(),'une entrée par compétition de la carrière');
for(const [id,c]of Object.entries(DATA.competitions)){
 assert.ok(typeof c.source==='string'&&c.source.length>0,id+' : source interne');
 assert.ok(c.note===undefined||typeof c.note==='string'&&c.note.length>0,id+' : note absente ou phrase');
 let previous=0;
 for(const z of c.zones){
  assert.ok(KINDS[z.kind],id+' : type de zone connu '+z.kind);
  assert.ok(Number.isInteger(z.from)&&Number.isInteger(z.to)&&z.from>previous&&z.to>=z.from,id+' : rangs croissants et disjoints');
  assert.ok(z.label.length>0&&z.label.length<=22,id+' : libellé de zone de 22 caractères au plus ('+z.label+')');
  previous=z.to;
 }
}

const h=context(4242,{club:0});
try{
 // 2. Avant la 1re journée : zones de chaque compétition publiées (l'enjeu), avec symbole.
 const opening=h.command('snapshot');
 assert.deepEqual(opening.leagues.map(l=>l.id).sort(),[...LEAGUES,...CUPS].sort(),'onze classements Monde');
 for(const league of opening.leagues){
  const data=DATA.competitions[league.id];
  assert.deepEqual(league.zones,data.zones.map(z=>({...z,symbol:KINDS[z.kind]})),league.id+' : zones projetées depuis la donnée');
  assert.equal(league.zoneNote,data.note??null,league.id+' : note');
  const size=league.pools?Math.max(...league.pools.map(p=>p.rows.length)):league.rows.length;
  assert.ok(league.zones.every(z=>z.to<=size),league.id+' : zones dans le tableau');
  for(const row of league.rows){
   const zone=league.zones.find(z=>row.rank>=z.from&&row.rank<=z.to);
   assert.deepEqual(row.zone,zone?{kind:zone.kind,label:zone.label,symbol:zone.symbol}:null,league.id+' : zone de la ligne '+row.rank);
  }
 }

 // 3. Saison complète.
 h.season();
 const S=h.state(),w=S.worldMode,final=h.command('snapshot');
 const leagues=Object.fromEntries(final.leagues.map(l=>[l.id,l]));
 const standing=Object.fromEntries(LEAGUES.map(id=>[id,leagues[id].rows.map(r=>r.id)]));
 for(const id of LEAGUES){
  // Les rangs du modèle sont ceux de la saison régulière (archive identique au tableau publié).
  assert.deepEqual(leagues[id].rows.map(r=>r.rank),leagues[id].rows.map((_,i)=>i+1),id+' : rangs 1..n');
  for(const row of leagues[id].rows)assert.equal(row.zone?.kind??null,leagues[id].zones.find(z=>row.rank>=z.from&&row.rank<=z.to)?.kind??null,id+' : zone finale du rang '+row.rank);
 }
 // (d) Qualifiés réels = rangs « bye » et « playoff » ; les exemptés de premier tour = rangs « bye ».
 for(const id of LEAGUES.filter(id=>id!=='jlo-d2')){
  const seeds=w.leagues[id].seeds;
  assert.ok(Array.isArray(seeds),id+' : têtes de série tirées');
  assert.deepEqual(seeds,at(standing[id],ranksOf(leagues[id],'bye','playoff')),id+' : qualifiés = zones bye + playoff, dans l’ordre');
 }
 // D2 japonaise : ses deux premiers sont exactement les clubs du barrage de montée.
 assert.deepEqual(w.leagues['jlo-d2'].seeds,at(standing['jlo-d2'],ranksOf(leagues['jlo-d2'],'promotion-playoff')),'D2 : barrage de montée = rangs 1-2');

 // (b) Barrages. Access Match : 13e du Top 14 contre le finaliste de Pro D2, chez ce dernier.
 assert.deepEqual(ranksOf(leagues.elite,'relegation-playoff'),[13]);
 assert.deepEqual(w.access.seeds,[standing.elite[12],leagues.accession.finalist.id],'Access Match : 13e du Top 14 contre le finaliste de Pro D2');
 const access=w.fixtures.find(f=>f.competitionId==='access');
 assert.equal(access.homeId,leagues.accession.finalist.id,'Access Match chez le finaliste de Pro D2');
 // Barrage Pro D2 / Nationale : 15e de Pro D2 chez le finaliste de Nationale.
 assert.deepEqual(ranksOf(leagues.accession,'relegation-playoff'),[15]);
 const lower=w.nationale.access.fixture;
 assert.equal(lower.awayId,standing.accession[14],'barrage de Nationale : 15e de Pro D2');
 assert.equal(lower.homeId,leagues.nationale.finalist.id,'barrage de Nationale : chez le finaliste de Nationale');
 // Japon : 11e et 12e de D1 contre 2e et 1er de D2.
 assert.deepEqual(ranksOf(leagues['jlo-d1'],'relegation-playoff'),[11,12]);
 assert.deepEqual(w.japan.pairs.map(p=>[p.upperId,p.lowerId]),[[standing['jlo-d1'][10],standing['jlo-d2'][1]],[standing['jlo-d1'][11],standing['jlo-d2'][0]]],'barrage Japon : 11e-2e et 12e-1er');

 // Coupes : les trois premiers de chaque poule passent ; les autres qualifiés et transférés viennent de la zone de repêchage.
 for(const id of CUPS){
  const cup=leagues[id],own=new Set(cup.rows.map(r=>r.id)),rank=new Map(cup.rows.map(r=>[r.id,r.rank]));
  const qualified=w.europe[id].seeds.filter(club=>own.has(club));
  sameSet(cup.rows.filter(r=>r.zone?.kind==='playoff').map(r=>r.id),qualified.filter(club=>rank.get(club)<=3),id+' : rangs 1-3 tous qualifiés');
  const repechage=new Set(ranksOf(cup,'repechage'));
  assert.ok(qualified.filter(club=>rank.get(club)>3).every(club=>repechage.has(rank.get(club))),id+' : repêchés pris dans la zone de repêchage');
  assert.ok(qualified.every(club=>cup.rows.find(r=>r.id===club).zone!==null),id+' : aucun qualifié hors zone');
 }
 assert.equal(w.europe.champions.transfers.length,4,'quatre transférés en Challenge');
 for(const club of w.europe.champions.transfers)assert.equal(leagues.champions.rows.find(r=>r.id===club).zone.kind,'repechage','transféré pris dans la zone de repêchage');

 // 4. Saison 2 : mouvements appliqués.
 const before=Object.fromEntries(LEAGUES.map(id=>[id,w.leagues[id].members.slice()]));
 const next=h.command('next_season',{confirmed:true});
 assert.equal(next.meta.season,2,'saison 2 ouverte');
 const S2=h.state(),archive=S2.worldMode.yearbook.at(-1),members=Object.fromEntries(LEAGUES.map(id=>[id,S2.worldMode.leagues[id].members]));
 assert.equal(archive.season,1);
 for(const id of LEAGUES)assert.deepEqual(archive.standings[id],standing[id],id+' : archive = classement publié');
 // (a) Relégation directe : 14e du Top 14 en Pro D2, 16e de Pro D2 en Nationale.
 assert.deepEqual(ranksOf(leagues.elite,'relegation'),[14]);
 assert.deepEqual(ranksOf(leagues.accession,'relegation'),[16]);
 assert.ok(members.accession.includes(standing.elite[13])&&!members.elite.includes(standing.elite[13]),'14e du Top 14 relégué en Pro D2');
 assert.ok(members.nationale.includes(standing.accession[15])&&!members.accession.includes(standing.accession[15]),'16e de Pro D2 relégué en Nationale');
 assert.ok(archive.movement.relegated.includes(standing.elite[13]),'archive : relégation du 14e');
 assert.ok(archive.nationale.access.relegated.includes(standing.accession[15]),'archive : relégation du 16e de Pro D2');
 // Un relégué vient toujours d'une zone de relégation ou de barrage.
 const relegatedFromElite=archive.movement.relegated.map(club=>standing.elite.indexOf(club)+1);
 assert.ok(relegatedFromElite.every(rank=>ranksOf(leagues.elite,'relegation','relegation-playoff').includes(rank)),'Top 14 : relégués des rangs 13-14 seulement');
 const relegatedFromProD2=archive.nationale.access.relegated.map(club=>standing.accession.indexOf(club)+1);
 assert.ok(relegatedFromProD2.every(rank=>ranksOf(leagues.accession,'relegation','relegation-playoff').includes(rank)),'Pro D2 : relégués des rangs 15-16 seulement');
 const japanDown=archive.japan.outcomes.filter(o=>o.promoted).map(o=>standing['jlo-d1'].indexOf(o.lowerNext)+1);
 assert.ok(japanDown.every(rank=>[11,12].includes(rank)),'D1 : descendus des rangs 11-12 seulement');
 for(const pair of archive.japan.pairs){
  const outcome=archive.japan.outcomes.find(o=>[pair.upperId,pair.lowerId].includes(o.winner));
  assert.ok(members['jlo-d1'].includes(outcome.winner)&&members['jlo-d2'].includes(outcome.lowerNext),'barrage Japon : vainqueur en D1, perdant en D2');
 }
 // (c) Sans relégation : membres inchangés.
 for(const id of ['prem','urc','srp','champ'])sameSet(members[id],before[id],id+' : ligue sans mouvement');
 const natUp=archive.nationale.access.promoted,natDown=archive.nationale.access.relegated;
 sameSet(members.nationale,before.nationale.filter(club=>!natUp.includes(club)).concat(natDown),'Nationale : seuls les promus et relégués du barrage français changent');
 assert.ok(natUp.every(club=>[leagues.nationale.champion.id,leagues.nationale.finalist.id].includes(club)),'Nationale : promus = champion et finaliste au plus');
 // Les zones restent publiées en saison 2 avant la 1re journée.
 const opening2=h.command('snapshot');
 for(const league of opening2.leagues)assert.equal(league.zones.length,DATA.competitions[league.id].zones.length,league.id+' : zones en saison 2');
 console.log('world-zones-classement PASS '+JSON.stringify({access:w.access.champion===w.access.seeds[1]?'finaliste Pro D2 promu':'13e maintenu',nationale:natUp.length+' promu(s)',japon:archive.japan.outcomes.map(o=>o.promoted?'montée':'maintien')}));
}finally{h.close();}

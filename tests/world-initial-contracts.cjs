'use strict';
const {test}=require('node:test'),a=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path'),os=require('node:os');
const engine='../native/engine/';
const {createBridge}=require(engine+'worker.cjs');
const compose=require(engine+'world-pacific-registry.cjs');
const base=require(engine+'world-registry.json');
const pacific=compose.extendWorldRegistry(base,require(engine+'world-pacific-extension.json'));
const japan=compose.extendJapanRegistry(pacific,require(engine+'world-japan-extension.json'));
const nat=compose.extendNationaleRegistry(japan,require(engine+'world-nationale-extension.json'));
const world=compose.extendChampRegistry(nat,require(engine+'world-champ-extension.json'));
const terms=require(engine+'world-initial-contracts.json');

test('Le registre d’échéances n’inclut que des IDs du bon effectif et aucune identité',()=>{
 a.equal(terms.schema,'world-initial-contracts-v1');
 a.equal(terms.databaseId,world.id);
 const ids=new Set(), leagues={prem:0,urc:0}, types={'season-end':0,'minimum-season-end':0};
 for(const [id,t] of Object.entries(terms.players)){
  a.match(id,/^world:(?:prem|urc):/);
  a.deepEqual(Object.keys(t).sort(),['clubId','endSeason','endType']);
  a.ok(Number.isInteger(t.endSeason)&&t.endSeason>=1&&t.endSeason<=6);
  const club=world.clubs[t.clubId];
  a.ok(club?.players.some(p=>p.id===id));
  a.ok(Object.hasOwn(leagues,club.leagueId)&&Object.hasOwn(types,t.endType));
  a.ok(!ids.has(id));ids.add(id);leagues[club.leagueId]++;types[t.endType]++;
 }
 a.deepEqual(leagues,{prem:20,urc:69});
 a.deepEqual(types,{'season-end':71,'minimum-season-end':18});
});

function contracts(mode,t){
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'cd-world-contracts-'));
 const config={dataDir:dir,seed:318,now:1788134400000};
 let b=createBridge(config),n=0;
 t.after(()=>{b.close();fs.rmSync(dir,{recursive:true,force:true});});
 const act=(command,payload={})=>{const res=b.handle({id:++n,command,payload});a.equal(res.ok,true,res.error);return res.model;};
 act('new_career',{mode,club:30});
 const first=act('export').meta.exportText;
 if(mode==='world-champ'){
  b.close();b=createBridge(config);
  a.deepEqual(JSON.parse(act('export').meta.exportText).state,JSON.parse(first).state);
 }
 return new Map(JSON.parse(first).state.clubs.flatMap(c=>c.players.map(p=>[p.id,p.contractEnd])));
}

test('Les échéances précises et bornes ne s’appliquent qu’aux créations Monde complet',t=>{
 const current=contracts('world-champ',t),prior=contracts('world-nationale',t);
 a.equal(current.size,5884);
 let changes=0;
 for(const club of world.clubs.filter(c=>c.leagueId==='prem'||c.leagueId==='urc')){
  for(const p of club.players){
   const baseline=p.contractEnd,row=terms.players[p.id];
   const expected=!row?baseline:row.endType==='season-end'?row.endSeason:Math.max(row.endSeason,baseline);
   a.equal(current.get(p.id),expected,p.id);
   if(prior.has(p.id))a.equal(prior.get(p.id),baseline,p.id+' édition antérieure');
   changes+=Number(expected!==baseline);
  }
 }
 a.equal(changes,55);
});
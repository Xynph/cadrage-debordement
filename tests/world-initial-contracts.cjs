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
 const ids=new Set(), leagues={prem:0,urc:0,champ:0}, types={'season-end':0,'minimum-season-end':0};
 for(const [id,t] of Object.entries(terms.players)){
  a.match(id,/^(?:world:(?:prem|urc):[a-z0-9:-]+|world:champ:[0-9a-f]{20})$/);
  a.deepEqual(Object.keys(t).sort(),['clubId','endSeason','endType']);
  a.ok(Number.isInteger(t.endSeason)&&t.endSeason>=1&&t.endSeason<=6);
  const club=world.clubs[t.clubId];
  a.ok(club?.players.some(p=>p.id===id));
  a.ok(Object.hasOwn(leagues,club.leagueId)&&Object.hasOwn(types,t.endType));
  a.ok(!ids.has(id));ids.add(id);leagues[club.leagueId]++;types[t.endType]++;
 }
 a.deepEqual(leagues,{prem:20,urc:69,champ:25});
 a.deepEqual(types,{'season-end':96,'minimum-season-end':18});
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
 a.equal(current.size,5881);
 const changed={premAndUrc:0,champ:0};
 const aliases=terms.inactiveAliases;
 a.equal(Object.keys(aliases).length,3);
 for(const club of world.clubs.filter(c=>['prem','urc','champ'].includes(c.leagueId))){
  for(const p of club.players){
   const baseline=p.contractEnd,row=terms.players[p.id];
   if(Object.hasOwn(aliases,p.id)){
    a.equal(current.has(p.id),false,p.id);
    continue;
   }
   const expected=!row?baseline:row.endType==='season-end'?row.endSeason:Math.max(row.endSeason,baseline);
   a.equal(current.get(p.id),expected,p.id);
   if(prior.has(p.id))a.equal(prior.get(p.id),baseline,p.id+' édition antérieure');
   changed[club.leagueId==='champ'?'champ':'premAndUrc']+=Number(expected!==baseline);
  }
 }
 a.equal(changed.premAndUrc,55);
 a.ok(changed.champ>0&&changed.champ<=25);
});
test('Seules les trois variantes attestées sont désactivées au départ, dans deux clubs du Champ',()=>{
 const aliases=Object.entries(terms.inactiveAliases),canonicals=new Set(),affected=new Set();
 a.equal(aliases.length,3);
 for(const [id,row] of aliases){
  a.match(id,/^world:champ:[0-9a-f]{20}$/);a.match(row.canonicalId,/^world:champ:[0-9a-f]{20}$/);
  a.deepEqual(Object.keys(row).sort(),['canonicalId','clubId']);
  a.notEqual(row.canonicalId,id);
  a.ok(!Object.hasOwn(terms.inactiveAliases,row.canonicalId));
  a.ok(!Object.hasOwn(terms.players,id));
  a.ok(!canonicals.has(row.canonicalId));
  canonicals.add(row.canonicalId);
  const club=world.clubs[row.clubId],p=club?.players.find(p=>p.id===id),canonical=club?.players.find(p=>p.id===row.canonicalId);
  a.equal(club?.leagueId,'champ');
  a.ok(p&&canonical);
  a.equal(p.pos,canonical.pos);
  affected.add(club.id);
 }
 a.equal(affected.size,2);
});

'use strict';
const test=require('node:test'), assert=require('node:assert/strict');
const {createUniverse}=require('../modding/r5/universe-contract.cjs');
const {createRugbyRealBirthyearPack,installRugbyRealBirthyears}=require('../modding/data06/r5-birthyears-pack.cjs');
test('pack R5 : 1592 identifiants LNR, pas de doublons',()=>{
 const p=createRugbyRealBirthyearPack();
 assert.equal(p.records.players.length,1592);
 assert.equal(new Set(p.records.players.map(x=>x.id)).size,1592);
});
test('R5 : univers fictif immuable, installation inactive par defaut',()=>{
 const base={players:[{id:'fiction:1',name:'Joueur fictif'}],clubs:[]};
 const world=createUniverse(base);
 installRugbyRealBirthyears(world);
 assert.equal(world.snapshot().players.length,1);
 assert.deepEqual(world.active(),[]);
 assert.equal(world.select(['rugby-real-birthyears-2026']).players.length,1593);
 assert.equal(base.players.length,1);
 assert.equal(world.reset().players.length,1);
});
test('R5 : anciennes sauvegardes non modifiees et signature de nouvelle carriere',()=>{
 const world=createUniverse({players:[]});
 installRugbyRealBirthyears(world);
 const legacy={season:1,team:'fiction:1'};
 assert.equal(world.checkCareer(legacy).ok,true);
 world.select(['rugby-real-birthyears-2026']);
 assert.equal(world.checkCareer(legacy).ok,false);
 const fresh=world.prepareNewCareer({season:'2026-2027',startDate:'2026-07-01'});
 assert.equal(world.checkCareer(fresh).ok,true);
 assert.equal(fresh.modBinding.mods[0].id,'rugby-real-birthyears-2026');
 world.reset();
 assert.equal(world.checkCareer(legacy).ok,true);
 assert.deepEqual(legacy,{season:1,team:'fiction:1'});
});
test('R5 : les trois dates utilisateur sont reprises',()=>{
 const players=createRugbyRealBirthyearPack().records.players;
 for(const [id,date] of [['lnr:13725','2007-03-10'],['lnr:13497','2005-01-01'],['lnr:11779','2003-02-14']]){
 const p=players.find(x=>x.id===id);assert(p);assert.equal(p.birthDate,date);assert.equal(p.historicalConflictRetained,true);
 }
});

'use strict';
const assert=require('node:assert/strict');
const {createCareer,planResume}=require('../modding/r4/career-bridge.cjs');
// Reproduce public R5 contract without requiring an unmerged PR.
function fakeWorld(){
 const state={active:[],versions:{'fiction-pack':'1.0.0'}};
 const make=()=>({clubs:[{id:'base',name:'Fictif'},...state.active.map(id=>({id,name:id}))]});
 return {
  active:()=>state.active.slice(),select(ids){for(const id of ids)if(!state.versions[id])throw Error('Mod manquant');state.active=ids.slice();return make()},
  reset(){state.active=[];return make()},
  binding(){return {schema:1,mods:state.active.map(id=>({id,version:state.versions[id]}))}},
  prepareNewCareer(c){return {...c,modBinding:this.binding()}},
  checkCareer(s){return {ok:JSON.stringify(s.modBinding)===JSON.stringify(this.binding()),reason:'Versions divergentes'}}
 };
}
const world=fakeWorld();
const career=createCareer(world,['fiction-pack'],{season:1},(options,snapshot)=>({...options,teams:snapshot.clubs.length}));
assert.equal(career.teams,2);assert.deepEqual(career.modBinding.mods,[{id:'fiction-pack',version:'1.0.0'}]);
assert.equal(planResume(world,career).ok,true);
const older={season:0,clubs:['base']};const oldRaw=JSON.stringify(older);
const legacy=planResume(world,older);
assert.equal(legacy.ok,true);assert.equal(legacy.legacy,true);
assert.deepEqual(world.active(),[]);
assert.equal(JSON.stringify(older),oldRaw);
const invalid={...career,modBinding:{schema:1,mods:[{id:'fiction-pack',version:'9.9.9'}]}};
assert.equal(planResume(world,invalid).ok,false);
assert.deepEqual(world.active(),[]);
const before=world.active();
assert.throws(()=>createCareer(world,['fiction-pack'],{season:2},()=>({season:2})),/signature/);
assert.deepEqual(world.active(),before);
assert.throws(()=>createCareer(world,['missing'],{season:2},x=>x),/manquant/);
assert.deepEqual(world.active(),before);
const modded=planResume(world,career);
assert.equal(modded.ok,true);assert.deepEqual(world.active(),['fiction-pack']);
assert.equal(planResume(world,{modBinding:{schema:8,mods:[]}}).ok,false);
assert.deepEqual(world.active(),['fiction-pack']);
console.log(JSON.stringify({passed:true,checks:['new career explicit','save binding','resume','legacy exact','missing version','failed new creation rollback','unknown pack','failed resume rollback']}));

'use strict';
const assert=require('node:assert/strict');
const {createUniverse,validatePack}=require('../modding/r5/universe-contract.cjs');
const base={clubs:[{id:'club:fictional',name:'Club fictif'}],players:[]};
const pack=(id,more={})=>({manifest:{schema:1,id,version:'1.0.0',kind:'dataset',...more},records:{clubs:[{id:'club:'+id,name:'Club '+id}]}});
for(const invalid of [
 pack('bad',{dependencies:[{id:'../../escape',version:'1.0.0'}]}),
 pack('bad',{conflicts:['../other']}),
 pack('bad',{dependencies:'not-an-array'}),
 pack('bad',{conflicts:'not-an-array'}),
 pack('bad',{dependencies:[{id:'bad',version:'1.0.0'}]})
])assert.throws(()=>validatePack(invalid));
assert.throws(()=>createUniverse([]),/invalide/);
const u=createUniverse(base);u.install(pack('alpha'));
assert.throws(()=>u.select([null]),/invalide/);
assert.throws(()=>u.select(['alpha','alpha']),/doublon/);
assert.throws(()=>u.select(['missing']),/manquant/);
assert.equal(u.active().length,0);
const one=u.select(['alpha']);one.clubs[0].name='changed';
assert.equal(u.snapshot().clubs[0].name,'Club fictif','copies independent');
const save=u.prepareNewCareer({season:3});
assert.equal(u.checkCareer(save).ok,true);
assert.equal(u.checkCareer({season:3}).ok,false);
for(const modBinding of [
 {schema:1,mods:[null]},
 {schema:1,mods:[{id:'../../escape',version:'1.0.0'}]},
 {schema:1,mods:[{id:'alpha',version:'bad'}]},
 {schema:9,mods:[]}
])assert.equal(u.checkCareer({modBinding}).ok,false);
const before=JSON.stringify(save);u.reset();
assert.equal(u.checkCareer({season:3}).ok,true);
assert.equal(u.checkCareer(save).ok,false);
assert.equal(JSON.stringify(save),before,'save not mutated');
assert.equal(JSON.stringify(base),JSON.stringify({clubs:[{id:'club:fictional',name:'Club fictif'}],players:[]}));
console.log(JSON.stringify({passed:true,checks:['manifest deps','conflicts','invalid selection','rollback','snapshot isolation','legacy saves','version binding','no mutation']}));

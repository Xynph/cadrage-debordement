'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');

// S2 composition with four qualifiers from one URC shield, from a packaged
// career. A node budget detects the regression without a wall-clock SLA.
const participants=[9,4,0,1,12,7,3,8,35,33,31,36,39,37,34,30,48,53,40,51,45,50,44,47];
const shields={40:'ireland',44:'scotland-italy',45:'scotland-italy',47:'wales',48:'wales',50:'scotland-italy',51:'scotland-italy',53:'south-africa'};
const clubs=participants.map((id,i)=>i<16?{id,leagueId:i<8?'elite':'prem'}:{id,leagueId:'urc',shield:shields[id]});
const source=fs.readFileSync(require.resolve('../native/engine/world-competitions.cjs'),'utf8');
const hook='function visit(index) {';
const bounded=source.replace(hook,hook+' if(++visits>5000)throw Error("budget de tirage dépassé");');
assert.notEqual(bounded,source,'ancre du compteur de parcours');

const cases=[
 {
  label:'quatre têtes, quatre clubs du même bouclier URC',
  protectedIds:[48,0,35,31],
  order:[48,0,35,31,53,40,47,9,4,1,12,7,3,8,33,36,39,37,34,30,51,45,50,44],
  expected:[[48,9,4,33,36,51],[0,53,1,39,37,45],[35,40,12,7,34,50],[31,47,3,8,30,44]]
 },
 {
  label:'trois têtes, doublé PREM/Europe, finaliste non qualifié',
  protectedIds:[0,35,48],
  order:[48,0,35,53,40,47,9,33,4,31,1,36,12,39,7,37,3,34,8,30,51,45,50,44],
  expected:[[48,9,33,4,31,51],[0,53,1,36,39,45],[35,40,12,7,37,50],[47,3,34,8,30,44]]
 }
];
for(const {label,protectedIds,order,expected} of cases)test('Champions Cup : tirage borné · '+label,()=>{
 const fixture={competitionId:'champions',clubs,participants,protectedIds,order};
 const ctx=vm.createContext({fixture,module:{exports:{}},visits:0});
 vm.runInContext(bounded,ctx);
 const pools=JSON.parse(vm.runInContext('JSON.stringify(module.exports.factory().drawPools(fixture))',ctx,{timeout:4000}));
 assert.deepEqual(pools,expected);
 assert.equal(new Set(pools.flat()).size,24);
 assert.deepEqual(pools.slice(0,protectedIds.length).map(p=>p[0]),order.filter(id=>protectedIds.includes(id)));
});

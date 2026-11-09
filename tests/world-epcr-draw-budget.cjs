'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');

test('Champions Cup : un tirage dense reste borné et garde ses têtes de série',()=>{
 // S2 composition with four qualifiers from one URC shield, from a packaged
 // career. This alternative valid order does not depend on a wall-clock SLA.
 const participants=[9,4,0,1,12,7,3,8,35,33,31,36,39,37,34,30,48,53,40,51,45,50,44,47];
 const shields={40:'ireland',44:'scotland-italy',45:'scotland-italy',47:'wales',48:'wales',50:'scotland-italy',51:'scotland-italy',53:'south-africa'};
 const clubs=participants.map((id,i)=>i<16?{id,leagueId:i<8?'elite':'prem'}:{id,leagueId:'urc',shield:shields[id]});
 const protectedIds=[48,0,35,31],order=[48,0,35,31,53,40,47,9,4,1,12,7,3,8,33,36,39,37,34,30,51,45,50,44];
 const fixture={competitionId:'champions',clubs,participants,protectedIds,order};
 const source=fs.readFileSync(require.resolve('../native/engine/world-competitions.cjs'),'utf8');
 const hook='function visit(index) {';
 const bounded=source.replace(hook,hook+' if(++visits>5000)throw Error("budget de tirage dépassé");');
 assert.notEqual(bounded,source,'ancre du compteur de parcours');
 const ctx=vm.createContext({fixture,module:{exports:{}},visits:0});
 vm.runInContext(bounded,ctx);
 const pools=JSON.parse(vm.runInContext('JSON.stringify(module.exports.factory().drawPools(fixture))',ctx,{timeout:4000}));
 assert.deepEqual(pools,[[48,9,4,33,36,51],[0,53,1,39,37,45],[35,40,12,7,34,50],[31,47,3,8,30,44]]);
 assert.equal(new Set(pools.flat()).size,24);
 assert.deepEqual(pools.map(p=>p[0]),protectedIds);
});

'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const dist=path.join(__dirname,'../dist');
const source=fs.readFileSync(path.join(dist,'lnr-career.js'),'utf8');
const birth=fs.readFileSync(path.join(dist,'lnr-birthyears-data.js'),'utf8');
const catalog=fs.readFileSync(path.join(dist,'lnr-catalogue-data.js'),'utf8');
const ageCode=source.slice(source.indexOf('function lnrBirthAge'),source.indexOf('function lnrGamePlayers'));
const catalogueCode=source.slice(source.indexOf('function lnrCatalogueView'));
test('catalogue: 1592 ages calculables, sans inventer dates',()=>{
 const sandbox={};
 vm.runInNewContext(birth+'\n'+ageCode+'\n;globalThis.getAge=lnrBirthAge;globalThis.raw=LNR_BIRTHYEARS_DATA;',sandbox);
 assert.equal(Object.keys(sandbox.raw.byId).length,1592);
 for(const id of Object.keys(sandbox.raw.byId)){
  const a=sandbox.getAge(id);
  assert(Number.isInteger(a.age)&&a.age>=15&&a.age<=60,id);
  assert(Number.isInteger(a.birthYear),id);
  if(a.ageEstimated)assert.equal(a.birthDate,undefined,id);
 }
 assert.equal(sandbox.getAge('lnr:13725').age,19);
 assert.equal(sandbox.getAge('lnr:13725').ageEstimated,false);
});
test('catalogue: âge affiché et estimation explicitement signalée',()=>{
 assert(source.includes('const rows=c[3].map(p=>{const born=lnrBirthAge(p[0]);'));
 assert(source.includes("born.ageEstimated?' (estimé)':''"));
 assert(source.includes('<th>Âge au 01/07/2026</th>'));
 assert(source.includes('Âges au 01/07/2026 ;'));
 assert(!source.includes('birthDate||'));
});

'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');
const root=path.join(__dirname,'../dist');
const source=fs.readFileSync(path.join(root,'lnr-birthyears-data.js'),'utf8');
const lnr=fs.readFileSync(path.join(root,'lnr-career.js'),'utf8');
const html=fs.readFileSync(path.join(root,'index.html'),'utf8');
function resolve(){const sandbox={};vm.runInNewContext(source+'\n'+lnr.slice(lnr.indexOf('function lnrBirthAge'),lnr.indexOf('function lnrGamePlayers'))+'\n;globalThis.ageFn=lnrBirthAge;',sandbox);return sandbox.ageFn;}
test('1592 ID LNR avec années et sans doublons',()=>{const s={};vm.runInNewContext(source+';globalThis.data=LNR_BIRTHYEARS_DATA;',s);assert.equal(Object.keys(s.data.byId).length,1592);assert.equal(s.data.count,1592);for(const [id,date] of Object.entries(s.data.byId)){assert(/^lnr:[0-9]+$/.test(id));assert(typeof date==='number'||/^\d{4}-\d{2}-\d{2}$/.test(date));}});
test('ordonnancement navigateur',()=>{assert(html.indexOf('lnr-birthyears-data.js')>=0);assert(html.indexOf('lnr-birthyears-data.js')<html.indexOf('lnr-career.js'));});
test('dates exactes, âge 2026 au 1er juillet',()=>{const age=resolve();assert.equal(age('lnr:13725').age,19);assert.equal(age('lnr:13497').age,21);assert.equal(age('lnr:11779').age,23);assert.equal(age('lnr:13725').ageEstimated,false);});
test('année seule conservatrice sans inventer une date',()=>{const age=resolve();const a=age('lnr:862');assert.equal(a.age,2026-a.birthYear-1);assert.equal(a.ageEstimated,true);assert.equal(a.birthDate,undefined);});
test('seule la construction de nouveaux joueurs LNR change',()=>{assert(lnr.includes('...birthday,rating'));assert(!lnr.includes('age:21+(seed%14)'));assert(html.includes('main-menu-v3.js'));});

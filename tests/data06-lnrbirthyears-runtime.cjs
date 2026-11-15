'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');
const root=path.join(__dirname,'../dist');
const source=fs.readFileSync(path.join(root,'lnr-birthyears-data.js'),'utf8');
const lnr=fs.readFileSync(path.join(root,'lnr-career.js'),'utf8');
const html=fs.readFileSync(path.join(root,'index.html'),'utf8');
function resolve(){const sandbox={};vm.runInNewContext(source+'\n'+lnr.slice(lnr.indexOf('function lnrBirthAge'),lnr.indexOf('function lnrGamePlayers'))+'\n;globalThis.ageFn=lnrBirthAge;',sandbox);return sandbox.ageFn;}
test('1592 ID LNR avec années et sans doublons',()=>{const s={};vm.runInNewContext(source+';globalThis.data=LNR_BIRTHYEARS_DATA;',s);assert.equal(Object.keys(s.data.byId).length,1592);assert.equal(s.data.count,1592);for(const [id,date] of Object.entries(s.data.byId)){assert(/^lnr:[0-9]+$/.test(id));assert(typeof date==='number'||date&&typeof date==='object'&&Number.isInteger(date.birthYear)&&Number.isInteger(date.ageAtSeasonStart)&&date.birthDate===undefined);}});
test('ordonnancement navigateur',()=>{assert(html.indexOf('lnr-birthyears-data.js')>=0);assert(html.indexOf('lnr-birthyears-data.js')<html.indexOf('lnr-career.js'));});
test('âges de référence 2026 sans dates complètes publiques',()=>{const age=resolve();assert.equal(age('lnr:13725').age,19);assert.equal(age('lnr:13497').age,21);assert.equal(age('lnr:11779').age,23);assert.equal(age('lnr:13725').ageEstimated,false);});
test('année seule conservatrice sans inventer une date',()=>{const age=resolve();const a=age('lnr:862');assert.equal(a.age,2026-a.birthYear-1);assert.equal(a.ageEstimated,true);assert.equal(a.birthDate,undefined);});
test('seule la construction de nouveaux joueurs LNR change',()=>{assert(lnr.includes('...birthday,rating'));assert(lnr.includes("typeof LNR_BIRTHYEARS_DATA==='undefined'?{age:21+(seedHash(id)%14),ageEstimated:true}:lnrBirthAge(id)"));assert(html.includes('main-menu-v3.js'));});

test('Monde : références jeunes à 15 ans et autres professionnels à 16 ans',()=>{
 const {engineContext}=require('./harness.cjs');
 const g=engineContext();g.start(0);
 try{
  const original=g.run('JSON.stringify(createSaveDocument())');
  for(const [kind,minimum] of [['reference',15],['ordinary',16]]){
   const id=g.run(kind==='reference'?'S.clubs.flatMap(c=>c.players).find(p=>CDWorldCareer.sourcePlayer(S,p.id)?.age===15).id':'S.clubs.flatMap(c=>c.players).find(p=>CDWorldCareer.sourcePlayer(S,p.id)?.age>15).id');
   for(const age of [minimum-1,minimum,minimum+1]){
    g.ctx.ageProbeText=original;g.ctx.ageProbeId=id;
    g.run(`globalThis.ageProbeDoc=JSON.parse(ageProbeText);ageProbeDoc.state.clubs.flatMap(c=>c.players).find(p=>p.id===ageProbeId).age=${age};ageProbeDoc.checksum=saveChecksum(ageProbeDoc.state)`);
    const parse=()=>g.run('parseSaveDocument(JSON.stringify(ageProbeDoc))');
    if(age<minimum)assert.throws(parse,/incohérentes/,kind+' refuse un âge inférieur');
    else assert.doesNotThrow(parse,kind+' accepte la borne et au-dessus');
   }
  }
 }finally{g.close();}
});

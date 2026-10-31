'use strict';
const test=require('node:test');const assert=require('node:assert/strict');const path=require('node:path');
const load=n=>require(path.join(__dirname,'../modding/data05-bulk2/',n));
test('DATA05-BULK2 60 fiches uniques, source officielle, pas de date inventee',()=>{
 const selected=load('selection.json').clubs.flatMap(c=>c.players.map(p=>({...p,club:c.club})));
 assert.equal(selected.length,150);
 const known=new Map(selected.map(p=>[p.id,p]));
 const entries=['01','02','03','04','05'].flatMap(n=>load('profiles-'+n+'.json').players);
 assert.equal(entries.length,60);assert.equal(new Set(entries.map(p=>p.id)).size,60);
 assert.equal(new Set(entries.map(p=>p.club)).size,12);
 for(const p of entries){
  const ref=known.get(p.id);assert.ok(ref);assert.equal(p.club,ref.club);assert.equal(p.sourceUrl,ref.url);
  assert.ok(p.name&&p.position&&p.nationality);assert.equal(p.error,null);
  assert.match(p.sourceUrl,/^https:\/\/(?:top14|prod2)\.lnr\.fr\/joueur\/\d+-/);
  assert.equal(p.birthDate,null);assert.equal(p.verifiedAtJuly1,false);
  if(p.heightCm!==null)assert.ok(p.heightCm>=150&&p.heightCm<=225);
  if(p.weightKg!==null)assert.ok(p.weightKg>=60&&p.weightKg<=180);
 }
 assert.equal(entries.filter(p=>p.heightCm&&p.weightKg&&p.age).length,43);
});

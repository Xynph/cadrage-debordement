const {test}=require('node:test');
const assert=require('node:assert/strict');
const data=require('../dist/france-clubs.js');
test('trente identités stables et deux partitions complètes',()=>{
 assert.equal(data.clubs.length,30);assert.equal(data.division('elite').length,14);assert.equal(data.division('accession').length,16);
 for(const key of ['id','slug','name','abbr'])assert.equal(new Set(data.clubs.map(c=>c[key])).size,30,key);
 data.clubs.forEach((c,i)=>{assert.equal(c.id,i);assert.ok(c.name.includes(c.city.split('-')[0]));assert.ok(c.cityImage.endsWith(c.slug+'-city.webp'));assert.ok(c.stadiumImage.endsWith(c.slug+'-stadium.webp'));assert.match(c.color,/^#[0-9a-f]{6}$/i);assert.ok(Object.isFrozen(c));});
 assert.ok(Object.isFrozen(data.clubs));assert.equal(data.get('toulouse').id,0);assert.equal(data.get(29).slug,'valence-romans');assert.equal(data.get(80),null);
});
test('les correspondances historiques et réelles ne se confondent pas',()=>{
 const legacy={clubs:[{id:0,name:'Stade des Brumes'}]},real={...legacy,lnrMode:{version:1,scope:'top14'}},france={clubs:Array.from({length:30},(_,id)=>({id})),franceMode:{version:1,catalogue:'france-territories-2026-10-31-v1'}};
 const before=JSON.stringify([legacy,real,france]);assert.equal(data.forCareer(legacy,0).slug,'toulouse');assert.equal(data.forCareer(real,0).slug,'clermont');assert.equal(data.forCareer(france,29).slug,'valence-romans');assert.equal(data.forCareer(legacy,29),null);assert.equal(JSON.stringify([legacy,real,france]),before);
});

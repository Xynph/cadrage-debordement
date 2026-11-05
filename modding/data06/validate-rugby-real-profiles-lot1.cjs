'use strict';
// Exécuter : node modding/data06/validate-rugby-real-profiles-lot1.cjs
const fs=require('node:fs');
const path=require('node:path');
const assert=require('node:assert/strict');
const dir=__dirname;
const original=JSON.parse(fs.readFileSync(path.join(dir,'consolidated-birthyears-1592-2026-11-01.json'),'utf8'));
const index=JSON.parse(fs.readFileSync(path.join(dir,'rugby-real-player-profiles-lot1-2026-11-02.json'),'utf8'));
const existing=new Map(original.players.map(p=>[p.id,p]));
assert.equal(original.players.length,1592);
assert.equal(existing.size,1592);
assert.equal(index.schema,'rugby-real-profile-evidence-v1');
assert.equal(index.season,original.season);
assert.equal(index.players.length,1592);
const seen=new Set();
const known={birthDate:0,heightCm:0,weightKg:0,primaryPosition:0,secondaryPositions:0};
for(const p of index.players){
  assert(!seen.has(p.id),'ID dupliqué '+p.id);
  seen.add(p.id);
  const orig=existing.get(p.id);
  assert(orig,'ID LNR étranger '+p.id);
  assert(p.evidence && typeof p.evidence==='object' && !Array.isArray(p.evidence));
  for(const field of Object.keys(known)){
    const v=p[field];
    assert.notEqual(v,undefined,'champ absent '+field+' / '+p.id);
    if(v===null){
      assert.equal(p.evidence[field],undefined,'source ambiguë pour champ inconnu');
      continue;
    }
    known[field]++;
    if(field==='birthDate'){
      assert.match(v,/^\d{4}-\d{2}-\d{2}$/);
      const date=new Date(v+'T00:00:00Z');
      assert(!Number.isNaN(date.getTime()));
      assert.equal(date.toISOString().slice(0,10),v);
      assert.equal(Number(v.slice(0,4)),orig.birthYear,'contradiction année historique');
    }else if(field==='heightCm'){
      assert(Number.isInteger(v)&&v>=135&&v<=230);
    }else if(field==='weightKg'){
      assert(Number.isInteger(v)&&v>=50&&v<=200);
    }else if(field==='primaryPosition'){
      assert(typeof v==='string' && v.length>2);
    }else if(field==='secondaryPositions'){
      assert(Array.isArray(v)&&v.length>0);
    }
    if(field!=='secondaryPositions'){
      assert.match(p.evidence[field],/^https:\/\//,'URL de provenance manquante '+p.id+' '+field);
    }
  }
  if(Object.keys(p.evidence).length){
    assert.equal(p.observedAt,'2026-11-02','date d’observation manquante');
  }else{
    assert.equal(p.observedAt,null);
  }
}
assert.equal(seen.size,existing.size);
assert.deepEqual(known,{birthDate:4,heightCm:4,weightKg:4,primaryPosition:4,secondaryPositions:0});
const unknown=Object.fromEntries(Object.entries(known).map(([k,v])=>[k,1592-v]));
console.log('PASS: 1592 identifiants LNR préservés ; couverture '+JSON.stringify(known));
console.log('Inconnus explicites : '+JSON.stringify(unknown));

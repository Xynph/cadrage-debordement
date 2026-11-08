'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const folder=path.join(__dirname,'../native/godot/guide');
const content=JSON.parse(fs.readFileSync(path.join(folder,'dialogues.json'),'utf8'));
const fragments=content.pages.flatMap(p=>p.fragments);
assert.equal(fragments.length,74);assert.equal(new Set(fragments.map(f=>f.id)).size,74);
for(const f of fragments){
 assert.ok(f.text.length<=181,'Petite bulle : '+f.id);
 assert.doesNotMatch(f.text,/anonymis|fictif|simulat|implément|licen[cs]e|crédits? des images|montants de jeu|vrais clubs|ancienne carrière/i,'Gabi reste dans son monde : '+f.id);
}
const personality=JSON.parse(fs.readFileSync(path.join(folder,'gabi_personality.json'),'utf8'));
assert.equal(personality.name,content.coach.name);assert.equal(personality.nickname,'Gabi');assert.equal(personality.age,68);
assert.ok(personality.flaws.length>=3&&personality.values.length>=3&&personality.relationshipArc.length>=3);
assert.ok(personality.speechRules.length>=5&&personality.memories.length>=3);
const manifest=JSON.parse(fs.readFileSync(path.join(folder,'assets/voice/manifest.json'),'utf8'));
const active=fragments.filter(f=>manifest.clips.some(c=>c.id===f.id&&c.text===f.text));
for(const f of fragments)assert.equal(f.audioStatus==='pending',!active.includes(f),'Une nouvelle parole exige un nouvel enregistrement : '+f.id);
assert.equal(active.length,74,'Chaque réplique validée possède sa nouvelle prise exacte');
assert.equal(manifest.voice.id,'xzXYWXH0dYPY9VdmuYZE','La voix choisie reste Gabi');
assert.equal(manifest.model.id,'eleven_v4');
assert.equal(manifest.licence.status,'generated-during-paid-subscription');
assert.ok(fragments.some(f=>/menuisier/.test(f.text))&&fragments.some(f=>/tort/.test(f.text)),'Passé et défaut assumé apparaissent réellement dans les paroles');
console.log('GABI_PERSONNALITE06_PASS '+fragments.length+' fragments exacts, '+active.length+' prises Gabi, '+(fragments.length-active.length)+' à enregistrer');

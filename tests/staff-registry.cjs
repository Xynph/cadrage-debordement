'use strict';
// Registre du staff français : compilé à partir de data/staff/verified.json, source à identités réelles du
// dépôt privé rugby-reel-donnees (scripts/sources-privees.cjs). Sans elle, le registre publié est contrôlé
// par son empreinte et par les noms de base ; avec elle (copie posée ou CD_SOURCES_PRIVEES), la compilation
// complète et l'absence de toute identité réelle sont vérifiées.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'..'),target=path.join(root,'native/engine/staff-registry.json');
assert.ok(fs.existsSync(target),'Le registre anonymisé du staff doit être embarqué.');
const compiler=require('../scripts/build-staff-registry.cjs'),privees=require('../scripts/sources-privees.cjs'),baseNames=require('../scripts/base-names.cjs');
const published=JSON.parse(fs.readFileSync(target,'utf8'));
assert.equal(published.clubs.length,30);assert.ok(published.clubs.every((c,i)=>c.id===i&&Array.isArray(c.members)));
const people=published.clubs.flatMap(c=>c.members),ids=new Set(people.map(p=>p.id)),text=JSON.stringify(published),names=baseNames.frenchStaff();
assert.equal(people.length,428);assert.equal(ids.size,people.length);
for(const p of people){assert.match(p.id,/^staff:\d{1,2}:[a-f0-9]{16}$/);assert.equal(p.name,baseNames.nameOf(names,p.id));assert.ok(p.role&&p.observedAt);assert.equal(p.portraitStatus,'anonymous');}
assert.doesNotMatch(text,/https?:|localPath|[A-Z]:[\\/]|portraitUrl|sourceUrl/,'Pas de lien ou média privé distribué.');
// Le registre publié est celui dont l'empreinte est publiée ; toute retouche sans les sources est refusée.
privees.verifyCompiled(compiler.TARGET);
const tmp=fs.mkdtempSync(path.join(require('node:os').tmpdir(),'cd-staff-empreinte-'));
try{const copy=path.join(tmp,'staff-registry.json');fs.writeFileSync(copy,fs.readFileSync(target,'utf8').replace(people[0].name,people[1].name));assert.throws(()=>privees.verifyCompiled(compiler.TARGET,copy),/modifié sans ses sources privées/);}
finally{fs.rmSync(tmp,{recursive:true,force:true});}
let mode='empreinte';
const sourceFile=privees.locate(compiler.SOURCE);
if(sourceFile){
 mode='sources';
 const source=JSON.parse(fs.readFileSync(sourceFile,'utf8'));
 const a=compiler.build(source),b=compiler.build(source);assert.deepEqual(a,b,'Compilation déterministe sans RNG.');
 assert.deepEqual(published,a,'Registre publié à jour.');
 const real=new Set(source.people.map(p=>p.name.normalize('NFKC').toLocaleLowerCase('fr')));
 for(const p of people)assert.ok(!real.has(p.name.normalize('NFKC').toLocaleLowerCase('fr')));
 for(const p of source.people)assert.ok(!text.includes(JSON.stringify(p.name).slice(1,-1)),'Identité réelle absente : '+p.id);
 assert.equal(people.length,source.people.filter(p=>p.importEligible).length);
 assert.equal(compiler.run(true),'compiled');
}else{
 assert.equal(compiler.run(true),'verified','Sans sources : contrôle par empreinte annoncé.');
 assert.throws(()=>compiler.run(false),/Sources privées absentes : impossible de recompiler/,'Pas de recompilation silencieuse sans sources.');
 assert.throws(()=>compiler.build(),/Sources privées absentes/);
}
const staff=require('../native/engine/staff.cjs'),base={meta:{mode:'common',catalogue:[]},club:{id:0}},before=JSON.stringify(base);
const projected=staff.project(base);assert.equal(projected.staff.teams.length,30);assert.equal(JSON.stringify(base),before,'Projection indépendante sans mutation de l’entrée.');
assert.deepEqual(staff.project(base),projected);assert.ok(staff.ids.has(people[0].id));
const legacy=staff.project({meta:{mode:'fictional14'},club:{id:0}});assert.deepEqual(legacy.staff.teams,[],'Pas de vrais staffs affectés à une ancienne base générée.');
console.log('Staff : registre 30 clubs, identités anonymes, contrôle par '+mode+' et projection pure PASS ('+people.length+' personnes).');

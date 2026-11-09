'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const ROOT=path.resolve(__dirname,'..');
const world=require('../native/engine/world-registry.json');
const french=require('../native/engine/staff-registry.json');
const publicFile=path.join(ROOT,'native/engine/world-staff-registry.json');
assert.ok(fs.existsSync(publicFile),'Registre public des staffs du monde attendu');
const staff=JSON.parse(fs.readFileSync(publicFile,'utf8'));
assert.equal(staff.schema,french.schema);assert.equal(staff.version,french.version);
assert.deepEqual(staff.clubs.slice(0,30),french.clubs,'Les 428 membres français et leurs identifiants sont préservés');
assert.deepEqual(staff.clubs.map(x=>x.id),world.clubs.map(x=>x.id));
const all=staff.clubs.flatMap(c=>c.members),foreign=staff.clubs.slice(30).flatMap(c=>c.members);
assert.equal(new Set(all.map(x=>x.id)).size,all.length);
assert.ok(staff.clubs.slice(30).every(c=>c.members.length>0),'Un encadrement documenté dans chaque club étranger');
for(const s of foreign){
 assert.match(s.id,new RegExp('^staff:'+s.clubId+':[a-f0-9]{16}$'));
 assert.equal(s.portraitStatus,'anonymous');
 assert.ok(s.name.trim().length>0&&s.role.trim().length>0);
 assert.deepEqual(Object.keys(s),['id','clubId','name','role','sourceSeason','sourceDate','historical','observedAt','portraitStatus']);
}
assert.ok(!/https?:\/\/|\.(?:png|jpg|webp)|[A-Z]:\\/.test(JSON.stringify(staff)),'Aucun lien de profil ni média privé publié');
const archive=process.argv[2];
if(archive){
 assert.ok(path.isAbsolute(archive),'Le ZIP privé de test doit être un chemin absolu');
 const {meta,clubs,players,staff:people,files}=require('../native/engine/media-packs.cjs').analyse(archive,world);
 assert.equal(meta.databaseId,world.id);assert.equal(meta.counts.clubs,58);assert.equal(meta.counts.logos,58);
 assert.equal(meta.counts.players,world.playerCount);assert.equal(meta.counts.staff,all.length);
 assert.equal(Object.keys(clubs).length,58);assert.equal(Object.keys(players).length,world.playerCount);
 for(const p of all)assert.ok(people[p.id]?.name);
 for(const p of foreign)assert.notEqual(p.name.normalize('NFKC').toLowerCase(),people[p.id].name.normalize('NFKC').toLowerCase(),'Le registre public porte un pseudonyme distinct');
 assert.ok(files.size>3500);
 if(process.argv.includes('--complete')){
  assert.ok(Object.values(players).every(p=>p.portrait),'Chaque joueur a une image de présentation');
  assert.ok(Object.values(people).every(p=>p.portrait),'Chaque membre du staff a une image de présentation');
  assert.equal(Object.entries(players).filter(([id,p])=>id.startsWith('world:')&&p.portraitStatus==='synthetic').length,62);
  assert.equal(foreign.filter(p=>people[p.id].portraitStatus==='synthetic').length,26);
  assert.equal(meta.counts.staffSynthetic,130,'104 illustrations françaises conservées et 26 ajoutées');
  assert.equal(files.size,4074,'3 986 médias d’origine plus 88 illustrations distinctes');
 }
}
console.log(JSON.stringify({clubs:staff.clubs.length,frenchStaff:french.clubs.flatMap(c=>c.members).length,foreignStaff:foreign.length,privateArchiveChecked:Boolean(archive)}));

'use strict';
// Without a pack, no real name reaches the game: the 116 clubs of the player and staff
// registries carry base names only, and no file shipped with the game quotes a real person
// of the French base. The real names are read from the research sources of the private data
// repository rugby-reel-donnees (scripts/sources-privees.cjs: copy laid over the repository, or
// its clone designated by CD_SOURCES_PRIVEES); they are never written anywhere. Without them,
// the comparison with real names is announced as not done and the public checks still run.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const root=path.resolve(__dirname,'..'),baseNames=require('../scripts/base-names.cjs'),privees=require('../scripts/sources-privees.cjs');
const json=file=>JSON.parse(fs.readFileSync(path.join(root,file),'utf8'));
const fold=name=>String(name).normalize('NFKD').replace(/[\u0300-\u036f]/g,'').toLowerCase().replace(/[^a-z0-9]+/g,' ').trim();

// Real identities: 1 592 players of the French base, 471 staff members, the press of the pack.
const SOURCES={players:'dist/lnr-rosters-data.js',staff:'data/staff/verified.json',press:'pack/journalistes.json'};
const located=Object.fromEntries(Object.entries(SOURCES).map(([k,r])=>[k,privees.locate(r)]));
function catalogue(file){const ctx=vm.createContext({});vm.runInContext(fs.readFileSync(file,'utf8').replace(/^const LNR_CATALOGUE=/m,'var LNR_CATALOGUE='),ctx);return ctx.LNR_CATALOGUE;}
const realPlayers=located.players?catalogue(located.players).clubs.flatMap(c=>c[3].map(([id,name])=>[id,name])):[];
const realStaff=located.staff?JSON.parse(fs.readFileSync(located.staff,'utf8')).people.map(p=>[p.id,p.name]):[];
const realPress=located.press?JSON.parse(fs.readFileSync(located.press,'utf8')).press.journalists.map(j=>[j.id,j.name]):[];
if(located.players)assert.equal(realPlayers.length,1592);if(located.staff)assert.equal(realStaff.length,471);if(located.press)assert.equal(realPress.length,10);
const missing=Object.keys(SOURCES).filter(k=>!located[k]);
if(missing.length)console.warn('Sources privées absentes ('+missing.map(k=>SOURCES[k]).join(', ')+') : comparaison avec ces vrais noms non faite.');
const real=new Map([...realPlayers,...realStaff,...realPress].map(([id,name])=>[id,fold(name)]));
const realNames=new Set(real.values());
// A surname is what follows the given name; a real surname is never reused by the base.
const surname=name=>fold(name).split(' ').slice(1).join(' ');
const realSurnames=new Set([...realPlayers,...realStaff].map(([,name])=>surname(name)));
// Players and staff of the base: the seeded name pools are compared with them (a pool pair that matches the
// common name of a journalist is a coincidence of first names and surnames, not a quoted person).
const sportNames=new Set([...realPlayers,...realStaff].map(([,name])=>fold(name)));

// The 116 clubs as the engine composes them, and the 2 160 staff members of the largest edition.
const {extendWorldRegistry,extendJapanRegistry,extendNationaleRegistry,extendChampRegistry}=require('../native/engine/world-pacific-registry.cjs');
const engine=file=>json('native/engine/'+file);
const full=extendChampRegistry(extendNationaleRegistry(extendJapanRegistry(extendWorldRegistry(engine('world-registry.json'),engine('world-pacific-extension.json')),engine('world-japan-extension.json')),engine('world-nationale-extension.json')),engine('world-champ-extension.json'));
const players=[...full.clubs.flatMap(club=>club.players),...Object.values(full.compatibilityAliases).map(row=>row.player)];
const staff=require('../native/engine/staff.cjs').forDatabase('rugby-world-2026-11-09-champ-v5').referenceRegistry.clubs.flatMap(club=>club.members);
const common=require('../dist/rugby-common-rosters.js').clubs.flatMap(club=>club.players);
const french=engine('staff-registry.json').clubs.flatMap(club=>club.members);
assert.equal(full.clubs.length,116);assert.equal(players.length,5884);assert.equal(staff.length,2160);assert.equal(common.length,1592);assert.equal(french.length,428);

const people=[...players,...staff,...common,...french];
for(const person of people){
 assert.ok(!realNames.has(fold(person.name)),person.id+' : nom d’une personne réelle de la base');
 assert.ok(!realSurnames.has(surname(person.name)),person.id+' : patronyme d’une personne réelle de la base');
 if(real.has(person.id))assert.notEqual(fold(person.name),real.get(person.id),person.id+' : vrai nom');
}
// Names drawn by seed: the generic pool (academy youths, generated players) and the pool of the training
// clubs of the Espoirs strategy. No pair of the pools, drawn or not yet drawn, is the name of a real person.
const pool=(file,name)=>{const m=fs.readFileSync(path.join(root,'dist',file),'utf8').match(new RegExp('const '+name+'=(\\[[^\\]]*\\])'));assert.ok(m,file+' : vivier '+name);return JSON.parse(m[1].replace(/'/g,'"'));};
for(const [file,firsts,lasts,size] of [['world-data.js','FIRST','LAST',832],['espoirs-strategy-v95-v100.js','firstnames','surnames',144]]){
 const given=pool(file,firsts),family=pool(file,lasts),pairs=given.flatMap(g=>family.map(f=>fold(g+' '+f)));
 assert.equal(pairs.length,size,file+' : taille du vivier');
 assert.deepEqual(pairs.filter(pair=>sportNames.has(pair)).length,0,file+' : combinaison tirée au sort égale au nom d’une personne réelle');
}
// Every displayed name of the registries comes from the tables of base names.
const tables=new Set([...baseNames.players().values(),...baseNames.staff().values()]);
for(const person of people)assert.ok(tables.has(person.name),person.id+' : nom hors des tables de base');

// No file shipped with the game quotes a real name: the engine folder and the loaded core modules,
// plus the Godot interface. Names are matched word by word, without case, accents or punctuation.
const byFirst=new Map();
for(const name of realNames){const words=name.split(' ');if(words.length<2)continue;if(!byFirst.has(words[0]))byFirst.set(words[0],[]);byFirst.get(words[0]).push(words);}
function quoted(text){
 const words=fold(text).split(' '),found=new Set();
 for(let i=0;i<words.length;i++)for(const name of byFirst.get(words[i])||[])if(name.every((word,j)=>words[i+j]===word))found.add(name.join(' '));
 return found;
}
const shipped=[];
(function walk(dir){for(const entry of fs.readdirSync(dir,{withFileTypes:true})){const file=path.join(dir,entry.name);if(entry.isDirectory()){if(!['.godot','node_modules'].includes(entry.name))walk(file);}else if(/\.(?:json|cjs|js|gd|tscn|tres|cfg|txt|md|csv)$/.test(entry.name))shipped.push(file);}})(path.join(root,'native'));
for(const file of require('../native/engine/worker.cjs').CORE_FILES)shipped.push(path.join(root,'dist',file));
const leaks=[];
for(const file of shipped){
 const relative=path.relative(root,file).split(path.sep).join('/');
 for(const name of quoted(fs.readFileSync(file,'utf8')))leaks.push(relative+' : '+name);
}
assert.deepEqual(leaks,[],'vrais noms dans les fichiers livrés');

console.log(JSON.stringify({passed:true,realSources:Object.keys(SOURCES).filter(k=>located[k]),clubs:full.clubs.length,players:players.length,staff:staff.length,realNamesChecked:realNames.size,shippedFiles:shipped.length}));

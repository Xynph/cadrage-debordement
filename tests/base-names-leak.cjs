'use strict';
process.env.CD_MODES_HERITES='1'; // Anciens modes de carrière (non-Monde) : test à migrer vers le mode Monde.
// Without a pack, no real name reaches the game: the 116 clubs of the player and staff
// registries carry base names only, and no file shipped with the game quotes a real person
// of the French base. The real names are read from the research sources still in the repository
// (dist/lnr-rosters-data.js, data/staff/verified.json); they are never written anywhere.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'..'),{context}=require('./france-harness.cjs'),baseNames=require('../scripts/base-names.cjs');
const json=file=>JSON.parse(fs.readFileSync(path.join(root,file),'utf8'));
const fold=name=>String(name).normalize('NFKD').replace(/[̀-ͯ]/g,'').toLowerCase().replace(/[^a-z0-9]+/g,' ').trim();

// Real identities of the French base: 1 592 players and 471 staff members.
const ref=context();
for(const file of ['france-clubs.js','lnr-rosters-data.js','lnr-ratings-v12.js','lnr-birthyears-data.js','lnr-career.js'])ref.run(fs.readFileSync(path.join(root,'dist',file),'utf8'));
ref.run('LNR_TOP14.splice(0,LNR_TOP14.length,...LNR_CATALOGUE.clubs)');
const realPlayers=JSON.parse(ref.run('JSON.stringify(CDFranceClubs.clubs.flatMap(c=>lnrGamePlayers(LNR_TOP14.findIndex(x=>x[0]===c.slug),c.base).map(p=>[p.id,p.name])))'));
const realStaff=json('data/staff/verified.json').people.map(p=>[p.id,p.name]);
assert.equal(realPlayers.length,1592);assert.equal(realStaff.length,471);
const real=new Map([...realPlayers,...realStaff].map(([id,name])=>[id,fold(name)]));
const realNames=new Set(real.values());
// A surname is what follows the given name; a real surname is never reused by the base.
const surname=name=>fold(name).split(' ').slice(1).join(' ');
const realSurnames=new Set([...realPlayers,...realStaff].map(([,name])=>surname(name)));

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
 assert.deepEqual(pairs.filter(pair=>realNames.has(pair)).length,0,file+' : combinaison tirée au sort égale au nom d’une personne réelle');
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
// Known homonym outside the player and staff registries: the press character « fiction-1 » of the question
// bank bears the name of a player of the French base. The press bank is reworked by PR #553.
// Read by identifier so that the test itself quotes no name.
const reporter=require('../dist/press-question-bank.js').journalists.find(j=>j.id==='fiction-1');
const KNOWN={'dist/press-question-bank.js':new Set(reporter?[fold(reporter.name)]:[])};
const leaks=[];
for(const file of shipped){
 const relative=path.relative(root,file).split(path.sep).join('/');
 for(const name of quoted(fs.readFileSync(file,'utf8')))if(!KNOWN[relative]?.has(name))leaks.push(relative+' : '+name);
}
assert.deepEqual(leaks,[],'vrais noms dans les fichiers livrés');

console.log(JSON.stringify({passed:true,clubs:full.clubs.length,players:players.length,staff:staff.length,realNamesChecked:realNames.size,shippedFiles:shipped.length}));

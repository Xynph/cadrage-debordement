'use strict';
// Display names of the base game: one per identifier, read from data/names.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'..'),baseNames=require('../scripts/base-names.cjs');
const read=file=>fs.readFileSync(path.join(root,file),'utf8'),json=file=>JSON.parse(read(file));
const sha=file=>crypto.createHash('sha256').update(fs.readFileSync(path.join(root,file))).digest('hex');
const fold=name=>name.normalize('NFD').replace(/[̀-ͯ]/g,'').toLowerCase();

// Provenance: the four tables are the files checked in the private data repository (docs/noms-inventes-branchement-20261111.md).
const DIGESTS={
 'noms-joueurs-v1.json':'b8ace38119541b1fe488d261178d843eaecfe1d7d7430dc3f5b141f80aebd1e4',
 'noms-staffs-v1.json':'ec2e7fece122c6b975a0f91b42978b725ad27c662243b4bac6efc632049f631f',
 'noms-monde-v1.json':'1a9b72d91b4be713c757594495ce5af6bc6b54b98007daf3a6c0b482c5c57f67',
 'noms-monde-staffs-v1.json':'2c3c7a17f9803479119d1ba711edb8dc0be2b3f1a43032b5c90c4b47537e1d51',
};
for(const [file,digest] of Object.entries(DIGESTS))assert.equal(sha('data/names/'+file),digest,file+' : table de noms modifiée sans nouveau contrôle');

const frenchPlayers=baseNames.frenchPlayers(),worldPlayers=baseNames.worldPlayers(),frenchStaff=baseNames.frenchStaff(),worldStaff=baseNames.worldStaff();
assert.deepEqual([frenchPlayers.size,worldPlayers.size,frenchStaff.size,worldStaff.size],[1592,4292,471,1732]);
const players=baseNames.players(),staff=baseNames.staff();

// The whole base: 116 clubs once the four extensions are composed, as the engine does.
const {extendWorldRegistry,extendJapanRegistry,extendNationaleRegistry,extendChampRegistry}=require('../native/engine/world-pacific-registry.cjs');
const engine=file=>json('native/engine/'+file);
const world=engine('world-registry.json');
const full=extendChampRegistry(extendNationaleRegistry(extendJapanRegistry(extendWorldRegistry(world,engine('world-pacific-extension.json')),engine('world-japan-extension.json')),engine('world-nationale-extension.json')),engine('world-champ-extension.json'));
const registryPlayers=full.clubs.flatMap(club=>club.players),legacy=Object.values(full.compatibilityAliases).map(row=>row.player);
assert.equal(full.clubs.length,116);assert.equal(registryPlayers.length,5878);assert.equal(legacy.length,6);
assert.equal(new Set(registryPlayers.map(p=>p.id)).size,5878);

// 100 % of the identifiers carry the name of the table, and the tables name nothing else.
for(const p of [...registryPlayers,...legacy])assert.equal(p.name,players.get(p.id),'joueur '+p.id);
assert.deepEqual([...players.keys()].sort(),[...registryPlayers,...legacy].map(p=>p.id).sort(),'un nom par identifiant de joueur, sans identifiant en trop');
const common=require('../dist/rugby-common-rosters.js'),commonPlayers=common.clubs.flatMap(club=>club.players);
assert.equal(commonPlayers.length,1592);
for(const p of commonPlayers)assert.equal(p.name,frenchPlayers.get(p.id),'base commune '+p.id);
for(const input of json('data/world/foreign-inputs.json').players)assert.equal(input.alias,worldPlayers.get(input.id),'entrée '+input.id);

const staffRegistry=require('../native/engine/staff.cjs'),champStaff=staffRegistry.forDatabase('rugby-world-2026-11-09-champ-v5').referenceRegistry.clubs.flatMap(club=>club.members);
assert.equal(champStaff.length,2160);assert.equal(new Set(champStaff.map(p=>p.id)).size,2160);
for(const p of champStaff)assert.equal(p.name,staff.get(p.id),'staff '+p.id);
const frenchRegistry=engine('staff-registry.json').clubs.flatMap(club=>club.members);
assert.equal(frenchRegistry.length,428);
for(const p of frenchRegistry)assert.equal(p.name,frenchStaff.get(p.id),'staff français '+p.id);
const named=new Set(champStaff.map(p=>p.id));
assert.equal([...staff.keys()].filter(id=>!named.has(id)).length,43,'seuls les 43 staffs français non importés sont nommés sans figurer au registre');
assert.ok([...staff.keys()].filter(id=>!named.has(id)).every(id=>frenchStaff.has(id)));

// One form for the whole base: « Prénom NOM » for players, « Prénom Nom » for staff.
const player=/^\p{Lu}[\p{L}'-]*(?: [\p{Lu}'-]+)+$/u,person=/^\p{Lu}[\p{L}'-]*(?: \p{L}[\p{L}'-]*)+$/u;
for(const [id,name] of players){
 assert.match(name,player,'forme du nom de joueur '+id);
 const words=name.split(' ');
 assert.notEqual(words[0],words[0].toUpperCase(),'prénom en capitales '+id);
 assert.ok(words.slice(1).every(word=>word===word.toUpperCase()),'patronyme en capitales '+id);
}
for(const [id,name] of staff){assert.match(name,person,'forme du nom de staff '+id);assert.notEqual(name,name.toUpperCase(),'staff en capitales '+id);}
for(const name of [...players.values(),...staff.values()])assert.ok(baseNames.valid(name)&&name.length<=40);

// No homonym in the base: a name designates one person.
const seen=new Set();
for(const name of [...registryPlayers.map(p=>p.name),...staff.values()]){assert.ok(!seen.has(fold(name)),'homonyme : '+name);seen.add(fold(name));}
// A former identifier of the same person carries the name of its current identifier.
for(const [id,row] of Object.entries(full.compatibilityAliases))assert.equal(players.get(id),players.get(row.canonicalId),'ancien identifiant '+id);

// Compiled registries are current and no compiler derives a name from a source identity any more.
baseNames.apply(true);
for(const file of ['scripts/build-rugby-common.cjs','scripts/build-staff-registry.cjs','scripts/build-world-registry.cjs','scripts/build-world-identity-pack.py']){
 assert.doesNotMatch(read(file),/endings|pseudonym|fictitious\(/i,file+' : dérivation de nom à partir d’une identité source');
}
assert.match(read('scripts/build-rugby-common.cjs'),/base-names\.cjs/);assert.match(read('scripts/build-staff-registry.cjs'),/base-names\.cjs/);
assert.match(read('scripts/build-world-identity-pack.py'),/data\/names\/noms-monde-staffs-v1\.json/);
assert.throws(()=>baseNames.nameOf(players,'lnr:inconnu'),/Nom de base absent/);

console.log(JSON.stringify({passed:true,clubs:full.clubs.length,players:registryPlayers.length,legacyIds:legacy.length,staff:champStaff.length,tables:Object.keys(DIGESTS).length}));

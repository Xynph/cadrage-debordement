'use strict';
// Postes et années de naissance vérifiés : appliqués à la création d'une carrière Monde,
// conservés au rechargement, sans aucune identité dans le fichier.
const {test}=require('node:test'),a=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path'),os=require('node:os');
const engine='../native/engine/';
const {createBridge}=require(engine+'worker.cjs');
const compose=require(engine+'world-pacific-registry.cjs');
const base=require(engine+'world-registry.json');
const pacific=compose.extendWorldRegistry(base,require(engine+'world-pacific-extension.json'));
const japan=compose.extendJapanRegistry(pacific,require(engine+'world-japan-extension.json'));
const nat=compose.extendNationaleRegistry(japan,require(engine+'world-nationale-extension.json'));
const world=compose.extendChampRegistry(nat,require(engine+'world-champ-extension.json'));
const fixes=require(engine+'world-player-corrections.json');
const POSITIONS=['Pilier gauche','Pilier droit','Talonneur','Deuxième ligne','Troisième ligne','Numéro 8','Demi de mêlée','Demi d’ouverture','Centre','Ailier','Arrière'];

test('le fichier de corrections ne porte que des identifiants, postes et années valides',()=>{
 a.equal(fixes.schema,'world-player-corrections-v1');
 a.equal(fixes.databaseId,world.id);
 const known=new Set(world.clubs.flatMap(c=>c.players.map(p=>p.id)));
 for(const [id,f] of Object.entries(fixes.players)){
  a.ok(known.has(id)&&id.startsWith('world:'),id);
  a.ok(Object.keys(f).length>0&&Object.keys(f).every(k=>k==='pos'||k==='birthYear'),id);
  if(f.pos!==undefined)a.ok(POSITIONS.includes(f.pos),id);
  if(f.birthYear!==undefined)a.ok(Number.isInteger(f.birthYear)&&f.birthYear>=1980&&f.birthYear<=2010,id);
 }
});

test('une nouvelle carrière Monde applique les corrections et se recharge à l’identique',t=>{
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'cd-world-fixes-'));
 const config={dataDir:dir,seed:4823,now:1788134400000};
 let b=createBridge(config),n=0;
 t.after(()=>{b.close();fs.rmSync(dir,{recursive:true,force:true});});
 const act=(command,payload={})=>{const res=b.handle({id:++n,command,payload});a.equal(res.ok,true,res.error);return res.model;};
 act('new_career',{mode:'world-champ',club:0});
 const first=JSON.parse(act('export').meta.exportText).state;
 const players=new Map(first.clubs.flatMap(c=>c.players.map(p=>[p.id,p])));
 let checked=0;
 for(const [id,f] of Object.entries(fixes.players)){
  const p=players.get(id);a.ok(p,id);
  if(f.pos!==undefined){a.equal(p.pos,f.pos,id);a.equal(p.gameplayPosition,f.pos,id);}
  if(f.birthYear!==undefined){a.equal(p.birthYear,f.birthYear,id);a.equal(p.ageEstimated,false,id);}
  checked++;
 }
 a.equal(checked,Object.keys(fixes.players).length);
 b.close();b=createBridge(config);
 a.deepEqual(JSON.parse(act('export').meta.exportText).state,first);
});

// Postes francais verifies : ils vivent dans la fondation d'effectif (les `lnr:` sont exclus du fichier de corrections).
const FRENCH={'lnr:1058':'Troisième ligne','lnr:11767':'Pilier droit','lnr:11953':'Pilier gauche','lnr:1753':'Pilier droit','lnr:2298':'Pilier droit'};
test('les cinq postes français vérifiés viennent de la fondation et se rechargent à l’identique',t=>{
 a.ok(Object.keys(fixes.players).every(id=>!id.startsWith('lnr:')));
 const foundation=require('../dist/rugby-roster-foundation.js');
 for(const [id,pos] of Object.entries(FRENCH)){const p=foundation.players[id].position;a.equal(p.primary,pos,id);a.equal(p.basis,'official',id);a.deepEqual(p.qualifications,[pos],id);}
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'cd-world-french-'));
 const config={dataDir:dir,seed:4823,now:1788134400000};
 let b=createBridge(config),n=0;
 t.after(()=>{b.close();fs.rmSync(dir,{recursive:true,force:true});});
 const act=(command,payload={})=>{const res=b.handle({id:++n,command,payload});a.equal(res.ok,true,res.error);return res.model;};
 act('new_career',{mode:'world-champ',club:0});
 const first=JSON.parse(act('export').meta.exportText).state;
 const players=new Map(first.clubs.flatMap(c=>c.players.map(p=>[p.id,p])));
 for(const [id,pos] of Object.entries(FRENCH)){const p=players.get(id);a.ok(p,id);a.equal(p.pos,pos,id);a.equal(p.gameplayPosition,pos,id);a.equal(p.rosterProfile.position.primary,pos,id);}
 b.close();b=createBridge(config);
 a.deepEqual(JSON.parse(act('export').meta.exportText).state,first);
});
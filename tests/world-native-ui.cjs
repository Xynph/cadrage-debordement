'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {spawnSync} = require('node:child_process');
const {test} = require('node:test');
const {crc32} = require('../native/engine/media-packs.cjs');

const godot = process.env.CD_GODOT_EXECUTABLE;
const project = process.env.CD_WORLD_UI_PROJECT;
const proofRoot = process.env.CD_WORLD_UI_PROOF;

function writePack(file, databaseId, id, name, club, clubName, abbr) {
 const manifest = Buffer.from(JSON.stringify({schema:'cd-identity-pack-v1', id, name, version:'1', databaseId,
  rightsStatus:'test-local', clubs:[{id:club, name:clubName, abbr}], players:[], assets:[]}));
 const filename = Buffer.from('pack.json');
 const local = Buffer.alloc(30), central = Buffer.alloc(46), end = Buffer.alloc(22), crc = crc32(manifest);
 local.writeUInt32LE(0x04034b50); local.writeUInt16LE(20,4); local.writeUInt32LE(crc,14);
 local.writeUInt32LE(manifest.length,18); local.writeUInt32LE(manifest.length,22); local.writeUInt16LE(filename.length,26);
 central.writeUInt32LE(0x02014b50); central.writeUInt16LE(20,4); central.writeUInt16LE(20,6); central.writeUInt32LE(crc,16);
 central.writeUInt32LE(manifest.length,20); central.writeUInt32LE(manifest.length,24); central.writeUInt16LE(filename.length,28);
 end.writeUInt32LE(0x06054b50); end.writeUInt16LE(1,8); end.writeUInt16LE(1,10);
 end.writeUInt32LE(central.length+filename.length,12); end.writeUInt32LE(local.length+filename.length+manifest.length,16);
 fs.writeFileSync(file,Buffer.concat([local,filename,manifest,central,filename,end]));
}

test('Godot natif : création mondiale, packs par édition, calendrier, poules et retour France 30', {
 skip:!(godot&&project&&proofRoot)&&'SDK, projet et dossier de preuve isolés requis',
},()=>{
 fs.mkdirSync(proofRoot,{recursive:true});
 const proof = fs.mkdtempSync(path.join(proofRoot,'world-ui-'));
 const world = path.join(proof,'world.zip'), france = path.join(proof,'france.zip'), champ = path.join(proof,'champ.zip');
 writePack(world,require('../native/engine/world-registry.json').id,'world-ui','Identités Monde test',30,'Bath témoin','BAT');
 writePack(france,require('../dist/rugby-common-rosters.js').id,'france-ui','Identités France test',0,'Toulouse témoin','TLS');
 writePack(champ,require('../native/engine/world-champ-extension.json').id,'champ-ui','Identités Monde complet test',0,'Club Monde complet témoin','TEM');
 const run = spawnSync(godot,['--headless','--audio-driver','Dummy','--max-fps','120','--path',project,'--script',path.resolve(__dirname,'world-native-ui.gd')],{
  encoding:'utf8',windowsHide:true,timeout:150000,
  env:{...process.env,CD_NODE_EXECUTABLE:process.execPath,CD_GODOT_SELF_TEST:'0',CD_GODOT_DATA_DIR:path.join(proof,'profile'),CD_WORLD_UI_WORLD_PACK:world,CD_WORLD_UI_FRANCE_PACK:france,CD_WORLD_UI_CHAMP_PACK:champ},
 });
 const output = (run.stdout||'')+(run.stderr||'');
 fs.writeFileSync(path.join(proof,'godot-world-ui.log'),output);
 console.log(output.trim(),`\nPreuves SDK : ${proof}`);
 if(run.error) throw run.error;
 assert.equal(run.status,0,output);
 assert.doesNotMatch(output,/SCRIPT ERROR|Parse Error|ERROR:/);
 assert.ok(output.includes('WORLD_NATIVE_UI_CHECKS '),'Le parcours doit atteindre sa dernière assertion.');
});

'use strict';
process.env.CD_MODES_HERITES='1'; // Anciens modes de carrière (non-Monde) : test à migrer vers le mode Monde.
const {settleClubMeetings}=require('./helpers/club-meetings.cjs');
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),os=require('node:os'),crypto=require('node:crypto');
const {createBridge}=require('../native/engine/worker.cjs'),media=require('../native/engine/media-packs.cjs'),world=require('../native/engine/world-registry.json'),legacy=require('../dist/rugby-common-rosters.js');
const root=fs.mkdtempSync(path.join(process.env.CD_WORLD_TEST_ROOT||os.tmpdir(),'cd-world-media-'));let seq=0,b;
function zip(filename,items){let offset=0;const local=[],central=[];for(const [name,data]of items){const n=Buffer.from(name),a=Buffer.from(data),head=Buffer.alloc(30),entry=Buffer.alloc(46);head.writeUInt32LE(0x04034b50);head.writeUInt16LE(20,4);head.writeUInt32LE(media.crc32(a),14);head.writeUInt32LE(a.length,18);head.writeUInt32LE(a.length,22);head.writeUInt16LE(n.length,26);entry.writeUInt32LE(0x02014b50);entry.writeUInt16LE(20,6);entry.writeUInt32LE(media.crc32(a),16);entry.writeUInt32LE(a.length,20);entry.writeUInt32LE(a.length,24);entry.writeUInt16LE(n.length,28);entry.writeUInt32LE(offset,42);local.push(head,n,a);central.push(entry,n);offset+=head.length+n.length+a.length;}const cd=Buffer.concat(central),end=Buffer.alloc(22);end.writeUInt32LE(0x06054b50);end.writeUInt16LE(items.length,8);end.writeUInt16LE(items.length,10);end.writeUInt32LE(cd.length,12);end.writeUInt32LE(offset,16);const file=path.join(root,filename);fs.writeFileSync(file,Buffer.concat([...local,cd,end]));return file;}
function call(command,payload={}){return b.handle({id:++seq,command,payload});}
function go(command,payload={}){const r=call(command,payload);assert.equal(r.ok,true,command+': '+r.error);return r.model;}
function state(){return JSON.parse(go('export').meta.exportText).state;}
try{
 const profile=path.join(root,'profile');b=createBridge({dataDir:profile,seed:741,now:1794178800000});
 const pixel=Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/l9sAAAAASUVORK5CYII=','base64');
 const sha256=crypto.createHash('sha256').update(pixel).digest('hex'),p=world.clubs[30].players[0];
 const manifest={schema:'cd-identity-pack-v2',id:'world-test',name:'Pack de réception',version:'1',databaseId:world.id,rightsStatus:'test-local',clubs:[{id:30,name:'Nom privé du club',abbr:'NPC',logo:'pixel'}],players:[{id:p.id,name:'Nom privé du joueur',portrait:'pixel',synthetic:true}],staff:[],assets:[{id:'pixel',path:'image.png',sha256,bytes:pixel.length}]};
 const file=zip('world.zip',[['pack.json',JSON.stringify(manifest)],['image.png',pixel]]);
 assert.equal(call('pack_inspect',{path:file}).ok,false,'a new world pack is not silently treated as a French30 pack');
 const preview=go('pack_inspect',{path:file,mode:'world'}).packs.preview;assert.equal(preview.databaseId,world.id);
 go('pack_install',{path:file,digest:preview.digest});assert.equal(call('pack_select',{scope:'creation',id:preview.id}).ok,false);
 const m=settleClubMeetings(go('pack_select',{scope:'creation',mode:'world',id:preview.id}),(command,payload)=>go(command,payload));assert.equal(m.meta.worldCatalogue[30].name,'Nom privé du club');assert.equal(m.meta.legacyCatalogue.length,30);assert.equal(m.meta.legacyPackCreation,'base');
 const career=settleClubMeetings(go('new_career',{mode:'world',club:30}),(command,payload)=>go(command,payload));assert.equal(career.club.name,'Nom privé du club');assert.equal(career.squad.find(x=>x.id===p.id).name,'Nom privé du joueur');assert.ok(fs.existsSync(career.squad.find(x=>x.id===p.id).portraitPath));
 const before=state();assert.equal(before.clubs[30].name,world.clubs[30].name);assert.equal(before.clubs[30].players.find(x=>x.id===p.id).name,p.name);
 const old=zip('legacy.zip',[['pack.json',JSON.stringify({schema:'cd-identity-pack-v1',id:'legacy-test',name:'France test',version:'1',databaseId:legacy.id,rightsStatus:'test-local',clubs:[{id:0,name:'Club France test'}],players:[],assets:[]})]]);
 const oldPreview=go('pack_inspect',{path:old,mode:'common'}).packs.preview;go('pack_install',{path:old,digest:oldPreview.digest});assert.equal(call('pack_select',{scope:'career',id:oldPreview.id}).ok,false);assert.deepEqual(state(),before);
 settleClubMeetings(go('pack_select',{scope:'career',id:'base'}),(command,payload)=>go(command,payload));const after=state(),unbound={...before};delete unbound.identityPack;assert.deepEqual(after,unbound);
 settleClubMeetings(go('pack_select',{scope:'career',id:preview.id}),(command,payload)=>go(command,payload));go('shutdown');b=createBridge({dataDir:profile,seed:99});assert.deepEqual(state(),before);assert.equal(go('snapshot').packs.career,preview.id);
 console.log(JSON.stringify({passed:true,checks:['world-only inspection','separate creation preferences','foreign logo and player image','display-only identities','cross-edition refusal without mutation','switch and restart']}));
}finally{if(b)b.close();fs.rmSync(root,{recursive:true,force:true});}

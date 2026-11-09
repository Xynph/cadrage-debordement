'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),os=require('node:os');
const media=require('../native/engine/media-packs.cjs'),{createBridge}=require('../native/engine/worker.cjs');
const root=fs.mkdtempSync(path.join(os.tmpdir(),'cd-nationale-pack-'));let seq=0;
function archive(manifest){
 const png=Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/l9sAAAAASUVORK5CYII=','base64');
 const items=[['pack.json',Buffer.from(JSON.stringify(manifest))],...(manifest.assets.length?[['portrait.png',png]]:[])];let offset=0;const blocks=[],central=[];
 for(const [name,data]of items){const n=Buffer.from(name),l=Buffer.alloc(30),c=Buffer.alloc(46),crc=media.crc32(data);l.writeUInt32LE(0x04034b50);l.writeUInt16LE(20,4);l.writeUInt16LE(0x800,6);l.writeUInt32LE(crc,14);l.writeUInt32LE(data.length,18);l.writeUInt32LE(data.length,22);l.writeUInt16LE(n.length,26);c.writeUInt32LE(0x02014b50);c.writeUInt16LE(20,4);c.writeUInt16LE(20,6);c.writeUInt16LE(0x800,8);c.writeUInt32LE(crc,16);c.writeUInt32LE(data.length,20);c.writeUInt32LE(data.length,24);c.writeUInt16LE(n.length,28);c.writeUInt32LE(offset,42);blocks.push(l,n,data);central.push(c,n);offset+=30+n.length+data.length;}
 const cd=Buffer.concat(central),end=Buffer.alloc(22);end.writeUInt32LE(0x06054b50);end.writeUInt16LE(items.length,8);end.writeUInt16LE(items.length,10);end.writeUInt32LE(cd.length,12);end.writeUInt32LE(offset,16);
 const file=path.join(root,'pack-'+(++seq)+'.zip');fs.writeFileSync(file,Buffer.concat([...blocks,cd,end]));return file;
}

test('Nationale presentation fields apply in creation and career without changing simulation',()=>{
 const profile=path.join(root,'career'),b=createBridge({dataDir:profile,seed:4823,now:1788134400000});
 const raw=(command,payload={})=>b.handle({id:++seq,command,payload});
 const good=(command,payload={})=>{const r=raw(command,payload);assert.equal(r.ok,true,command+' : '+r.error);return r.model;};
 const state=()=>JSON.parse(good('export').meta.exportText).state;
 const mode='world-nationale';
 try{
  let m=good('new_career',{mode,club:88});
  const before=state(),coach=m.staff.teams.find(t=>t.id===88).members[0];
  assert.equal(typeof coach.sourceStaffId,'string');
  assert.notEqual(coach.id,coach.sourceStaffId);
  const manifest={schema:'cd-identity-pack-v2',id:'temoin-nationale',name:'Témoin Nationale',version:'1',databaseId:m.meta.nationaleDatabase.id,rightsStatus:'test-local',clubs:[{id:88,city:'Ville témoin',stadium:'Parc témoin'}],players:[],staff:[{id:coach.sourceStaffId,role:'Mêlée et conquête'}],assets:[]};
  assert.equal(raw('pack_inspect',{path:archive({...manifest,staff:[{id:coach.id,role:'Mêlée et conquête'}]}),mode}).ok,false,'Un ID de commande de carrière ne remplace pas une référence du pack');
  const zip=archive(manifest),preview=good('pack_inspect',{path:zip,mode}).packs.preview;
  good('pack_install',{path:zip,digest:preview.digest,mode});
  m=good('pack_select',{scope:'creation',id:preview.id,mode});
  assert.equal(m.meta.nationaleCatalogue.find(c=>c.id===88).city,'Ville témoin');
  assert.equal(m.meta.nationaleCatalogue.find(c=>c.id===88).stadium,'Parc témoin');
  assert.notEqual(m.club.stadium,'Parc témoin');
  m=good('pack_select',{scope:'career',id:preview.id,mode});
  assert.equal(m.club.stadium,'Parc témoin');
  assert.equal(m.club.presentation.city,'Ville témoin');
  assert.equal(m.staff.teams.find(t=>t.id===88).members[0].identity.role,'Mêlée et conquête');
  assert.equal(m.staff.teams.find(t=>t.id===88).members[0].roleLabel,'Mêlée et conquête');
  assert.equal(m.staff.teams.find(t=>t.id===88).members[0].role,coach.role);
  assert.equal(m.calendar.find(f=>f.home.id===88).venue,'Parc témoin');
  const after=state();delete after.identityPack;assert.deepEqual(after,before);
  const wrong={...manifest,databaseId:m.meta.japanDatabase.id,clubs:[{id:68,city:'Interdit sur v3'}],staff:[]};
  assert.equal(raw('pack_inspect',{path:archive(wrong),mode:'world-japan'}).ok,false);
  const old={...manifest,schema:'cd-identity-pack-v1'};delete old.staff;
  assert.equal(raw('pack_inspect',{path:archive(old),mode}).ok,false);
  for(const value of ['<b>Unsafe</b>','X'.repeat(121),'   ']){
   const bad={...manifest,clubs:[{id:88,stadium:value}]};
   assert.equal(raw('pack_inspect',{path:archive(bad),mode}).ok,false);
   const badRole={...manifest,staff:[{id:coach.sourceStaffId,role:value}]};
   assert.equal(raw('pack_inspect',{path:archive(badRole),mode}).ok,false,'Rôle cosmétique invalide refusé');
  }
  assert.equal(state().identityPack.id,preview.id);
  m=good('pack_select',{scope:'career',id:'base',mode});
  assert.equal(m.staff.teams.find(t=>t.id===88).members[0].role,coach.role);
  assert.equal(m.staff.teams.find(t=>t.id===88).members[0].roleLabel,coach.roleLabel);
  assert.deepEqual(state(),before);
 }finally{b.close();}
});

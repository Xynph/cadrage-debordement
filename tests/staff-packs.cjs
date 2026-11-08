'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),os=require('node:os'),crypto=require('node:crypto');
const media=require('../native/engine/media-packs.cjs'),db=require('../dist/rugby-common-rosters.js'),staff=require('../native/engine/staff.cjs'),{createBridge}=require('../native/engine/worker.cjs');
const root=fs.mkdtempSync(path.join(os.tmpdir(),'cd-staff-packs-')),profile=path.join(root,'career');let seq=0;
function archive(manifest){
 const png=Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/l9sAAAAASUVORK5CYII=','base64');
 const items=[['pack.json',Buffer.from(JSON.stringify(manifest))],...(manifest.assets.length?[['portrait.png',png]]:[])];let offset=0;const blocks=[],central=[];
 for(const [name,data]of items){const n=Buffer.from(name),l=Buffer.alloc(30),c=Buffer.alloc(46),crc=media.crc32(data);l.writeUInt32LE(0x04034b50);l.writeUInt16LE(20,4);l.writeUInt16LE(0x800,6);l.writeUInt32LE(crc,14);l.writeUInt32LE(data.length,18);l.writeUInt32LE(data.length,22);l.writeUInt16LE(n.length,26);c.writeUInt32LE(0x02014b50);c.writeUInt16LE(20,4);c.writeUInt16LE(20,6);c.writeUInt16LE(0x800,8);c.writeUInt32LE(crc,16);c.writeUInt32LE(data.length,20);c.writeUInt32LE(data.length,24);c.writeUInt16LE(n.length,28);c.writeUInt32LE(offset,42);blocks.push(l,n,data);central.push(c,n);offset+=30+n.length+data.length;}
 const cd=Buffer.concat(central),end=Buffer.alloc(22);end.writeUInt32LE(0x06054b50);end.writeUInt16LE(items.length,8);end.writeUInt16LE(items.length,10);end.writeUInt32LE(cd.length,12);end.writeUInt32LE(offset,16);
 const file=path.join(root,'pack-'+(++seq)+'.zip');fs.writeFileSync(file,Buffer.concat([...blocks,cd,end]));return file;
}
const sid=staff.registry.clubs[1].members[0].id,pid=db.clubs[1].players[0].id,png=Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/l9sAAAAASUVORK5CYII=','base64');
const manifest={schema:'cd-identity-pack-v2',id:'staff-test',name:'Encadrement personnalisé',version:'1',databaseId:db.id,rightsStatus:'test-local',clubs:[],players:[{id:pid,name:'Joueur test'}],staff:[{id:sid,name:'Coach test',portrait:'photo',synthetic:false}],assets:[{id:'photo',path:'portrait.png',sha256:crypto.createHash('sha256').update(png).digest('hex'),bytes:png.length}]};
let b=createBridge({dataDir:profile,seed:321,now:1700000000000});
const good=(command,payload={})=>{const r=b.handle({id:++seq,command,payload});assert.equal(r.ok,true,command+': '+r.error);return r.model;};
const state=()=>JSON.parse(good('export').meta.exportText).state,withoutPack=s=>{const v=structuredClone(s);delete v.identityPack;return v;};
try{
 let m=good('new_career',{mode:'common',club:1});assert.ok(m.staff?.teams?.length===30,'Staff projeté dans le jeu natif.');
 const before=state(),file=path.join(m.meta.dataDir,'donnees.json'),raw=fs.readFileSync(file),seed=JSON.parse(raw).seed;
 for(let i=0;i<3;i++)good('snapshot');assert.deepEqual(fs.readFileSync(file),raw);
 const zip=archive(manifest),preview=good('pack_inspect',{path:zip}).packs.preview;assert.equal(preview.counts.staff,1);assert.equal(preview.counts.staffOfficial,1);
 good('pack_install',{path:zip,digest:preview.digest});m=good('pack_select',{id:preview.id,scope:'career'});
 const coach=m.staff.teams[1].members.find(p=>p.id===sid);assert.equal(coach.name,'Coach test');assert.equal(coach.portraitStatus,'official');assert.ok(fs.existsSync(coach.portraitPath));assert.equal(m.squad.find(p=>p.id===pid).name,'Joueur test');
 assert.deepEqual(withoutPack(state()),withoutPack(before));assert.equal(JSON.parse(fs.readFileSync(file)).seed,seed);
 good('shutdown');b=createBridge({dataDir:profile});m=good('snapshot');assert.equal(m.staff.teams[1].members.find(p=>p.id===sid).name,'Coach test');
 const portrait=m.staff.teams[1].members.find(p=>p.id===sid).portraitPath,original=fs.readFileSync(portrait),stats=fs.statSync(portrait),corrupt=Buffer.from(original);corrupt[corrupt.length-1]^=1;
 fs.writeFileSync(portrait,corrupt);fs.utimesSync(portrait,stats.atime,stats.mtime);
 m=good('snapshot');assert.ok(m.packs.missing.some(x=>x.startsWith('Pack de carrière absent')),'Une corruption en place invalide aussi le cache chaud, même si taille/mtime sont conservées.');assert.ok(!m.staff.teams[1].members.find(p=>p.id===sid).portraitPath,'Aucun faux portrait officiel après corruption.');
 fs.writeFileSync(portrait,original);m=good('snapshot');assert.equal(m.staff.teams[1].members.find(p=>p.id===sid).portraitStatus,'official');
 good('pack_select',{id:'base',scope:'career'});assert.notEqual(good('snapshot').staff.teams[1].members.find(p=>p.id===sid).name,'Coach test');assert.deepEqual(withoutPack(state()),withoutPack(before));
 const v1={...manifest,schema:'cd-identity-pack-v1',assets:[]};delete v1.staff;const legacy=archive(v1),lp=good('pack_inspect',{path:legacy}).packs.preview;good('pack_install',{path:legacy,digest:lp.digest});good('pack_select',{id:lp.id,scope:'career'});assert.equal(good('snapshot').staff.teams[1].members.find(p=>p.id===sid).portraitStatus,'anonymous');
 for(const mutate of [x=>x.staff.push({...x.staff[0]}),x=>x.staff[0].id=pid,x=>x.staff[0].id='staff:99:0000000000000000',x=>x.staff[0].rating=100,x=>x.staff[0].portrait='../escape',x=>delete x.staff[0].synthetic,x=>x.schema='cd-identity-pack-v1']){
  const bad=structuredClone(manifest);mutate(bad);const result=b.handle({id:++seq,command:'pack_inspect',payload:{path:archive(bad)}});assert.equal(result.ok,false,'Pack hostile ou staff invalide refusé.');assert.deepEqual(withoutPack(state()),withoutPack(before));
 }
 console.log('Staff packs : v1/v2, portraits, changement/reprise, état/RNG et refus stricts PASS.');
}finally{b.close();}

'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {readZip,checkPackage,store}=require('../modding/r4/package-store.cjs');
function zip(files){
 const local=[],central=[];let offset=0;
 for(const [name,content] of Object.entries(files)){
  const n=Buffer.from(name),b=Buffer.from(content),a=Buffer.alloc(30),c=Buffer.alloc(46);
  a.writeUInt32LE(0x04034b50);a.writeUInt16LE(20,4);a.writeUInt32LE(b.length,18);a.writeUInt32LE(b.length,22);a.writeUInt16LE(n.length,26);
  c.writeUInt32LE(0x02014b50);c.writeUInt16LE(20,4);c.writeUInt16LE(20,6);c.writeUInt32LE(b.length,20);c.writeUInt32LE(b.length,24);c.writeUInt16LE(n.length,28);c.writeUInt32LE(offset,42);
  local.push(a,n,b);central.push(c,n);offset+=a.length+n.length+b.length;
 }
 const list=Buffer.concat(central),end=Buffer.alloc(22);
 end.writeUInt32LE(0x06054b50);end.writeUInt16LE(Object.keys(files).length,8);end.writeUInt16LE(Object.keys(files).length,10);end.writeUInt32LE(list.length,12);end.writeUInt32LE(offset,16);
 return Buffer.concat([...local,list,end]);
}
const manifest={schema:1,id:'fictional-pack',version:'1.0.0',data:[{type:'clubs',path:'clubs.json'}],assets:[]};
const archive=zip({'manifest.json':JSON.stringify(manifest),'clubs.json':'[]'});
const decoded=readZip(archive);assert.equal(checkPackage(decoded).id,'fictional-pack');
const temp=fs.mkdtempSync(path.join(os.tmpdir(),'cd-r4-'));
try{
 const registry=store(temp),result=registry.install(archive);
 assert.ok(fs.existsSync(path.join(result.path,'clubs.json')));
 assert.deepEqual(registry.checkBinding({schema:1,mods:[{id:'fictional-pack',version:'1.0.0'}]}).missing,[]);
 assert.equal(registry.checkBinding({schema:1,mods:[{id:'fictional-pack',version:'2.0.0'}]}).ok,false);
 assert.throws(()=>registry.install(archive),/déjà installée/);
 assert.throws(()=>readZip(zip({'../evil.json':'{}'})),/invalide/);
 assert.throws(()=>checkPackage(readZip(zip({'manifest.json':JSON.stringify(manifest),'clubs.json':'[]','secret.json':'[]'}))),/non déclaré/);
}finally{fs.rmSync(temp,{recursive:true,force:true})}
console.log(JSON.stringify({passed:true,checks:['zip stored','manifest','atomic install','version binding','duplicate guard','traversal','undeclared file']}));

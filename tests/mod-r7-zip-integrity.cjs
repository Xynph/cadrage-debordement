'use strict';
const assert=require('node:assert/strict');
const fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {readZip,store}=require('../modding/r4/package-store.cjs');
function crc32(buf){let c=0xffffffff;for(const b of buf){c^=b;for(let i=0;i<8;i++)c=(c>>>1)^((c&1)?0xedb88320:0)}return(c^0xffffffff)>>>0}
function zip(name,contents){
 const b=Buffer.from(contents),n=Buffer.from(name),a=Buffer.alloc(30),c=Buffer.alloc(46),end=Buffer.alloc(22),crc=crc32(b);
 a.writeUInt32LE(0x04034b50);a.writeUInt16LE(20,4);a.writeUInt32LE(crc,14);a.writeUInt32LE(b.length,18);a.writeUInt32LE(b.length,22);a.writeUInt16LE(n.length,26);
 c.writeUInt32LE(0x02014b50);c.writeUInt16LE(20,4);c.writeUInt16LE(20,6);c.writeUInt32LE(crc,16);c.writeUInt32LE(b.length,20);c.writeUInt32LE(b.length,24);c.writeUInt16LE(n.length,28);
 const offset=a.length+n.length+b.length;end.writeUInt32LE(0x06054b50);end.writeUInt16LE(1,8);end.writeUInt16LE(1,10);end.writeUInt32LE(c.length+n.length,12);end.writeUInt32LE(offset,16);
 return Buffer.concat([a,n,b,c,n,end]);
}
const good=zip('test.json','[]');
assert.equal(readZip(good)['test.json'].toString(),'[]');
const corrupted=Buffer.from(good);corrupted[30+Buffer.byteLength('test.json')]^=1;
assert.throws(()=>readZip(corrupted),/CRC32/);
const root=fs.mkdtempSync(path.join(os.tmpdir(),'r7-mods-'));
try{
 const mod=store(root);
 assert.equal(mod.checkBinding({schema:1,mods:[{id:'../escape',version:'1.0.0'}]}).ok,false);
 assert.equal(mod.checkBinding({schema:1,mods:[{id:'valid-name',version:'../../'}]}).ok,false);
 fs.mkdirSync(path.join(root,'valid-name--1.0.0'));
 assert.deepEqual(mod.installed(),['valid-name--1.0.0']);
 assert.equal(mod.checkBinding({schema:1,mods:[{id:'valid-name',version:'1.0.0'}]}).ok,false);
}finally{fs.rmSync(root,{recursive:true,force:true})}
console.log(JSON.stringify({passed:true,checks:['crc accepted','crc tamper rejected','version path traversal rejected','installed version listed','missing manifest refused']}));

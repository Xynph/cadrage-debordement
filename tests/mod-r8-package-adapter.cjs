'use strict';
const assert=require('node:assert/strict'),crypto=require('node:crypto');
const {toWorldPack,installIntoUniverse}=require('../modding/r4/installed-adapter.cjs');
const {readZip}=require('../modding/r4/package-store.cjs');
function crc32(buf){let c=0xffffffff;for(const b of buf){c^=b;for(let i=0;i<8;i++)c=(c>>>1)^((c&1)?0xedb88320:0)}return(c^0xffffffff)>>>0}
function zip(files){
 const a=[],b=[];let offset=0;
 for(const [name,value] of Object.entries(files)){
  const n=Buffer.from(name),v=Buffer.from(value),local=Buffer.alloc(30),central=Buffer.alloc(46),crc=crc32(v);
  local.writeUInt32LE(0x04034b50);local.writeUInt16LE(20,4);local.writeUInt32LE(crc,14);local.writeUInt32LE(v.length,18);local.writeUInt32LE(v.length,22);local.writeUInt16LE(n.length,26);
  central.writeUInt32LE(0x02014b50);central.writeUInt16LE(20,4);central.writeUInt16LE(20,6);central.writeUInt32LE(crc,16);central.writeUInt32LE(v.length,20);central.writeUInt32LE(v.length,24);central.writeUInt16LE(n.length,28);central.writeUInt32LE(offset,42);
  a.push(local,n,v);b.push(central,n);offset+=local.length+n.length+v.length;
 }
 const directory=Buffer.concat(b),tail=Buffer.alloc(22);tail.writeUInt32LE(0x06054b50);tail.writeUInt16LE(Object.keys(files).length,8);tail.writeUInt16LE(Object.keys(files).length,10);tail.writeUInt32LE(directory.length,12);tail.writeUInt32LE(offset,16);
 return Buffer.concat([...a,directory,tail]);
}
const manifest={schema:1,id:'fictional-world',version:'1.0.0',title:'Univers de test',kind:'dataset',data:[{type:'clubs',path:'clubs.json'}],assets:[]};
const archive=zip({'manifest.json':JSON.stringify(manifest),'clubs.json':JSON.stringify([{id:'club:test',name:'Club fictif'}])});
assert.ok(readZip(archive)['manifest.json']);
const normalized=toWorldPack(archive);
assert.equal(normalized.manifest.id,'fictional-world');
assert.deepEqual(normalized.records.clubs,[{id:'club:test',name:'Club fictif'}]);
let installations=0;const receiver={install(p){assert.deepEqual(p,normalized);installations++;return p.manifest.id}};
assert.equal(installIntoUniverse(archive,receiver),'fictional-world');assert.equal(installations,1);
assert.throws(()=>toWorldPack(zip({'manifest.json':JSON.stringify({...manifest,data:[{type:'evil',path:'clubs.json'}]}),'clubs.json':'[]'})),/interdite/);
assert.throws(()=>toWorldPack(zip({'manifest.json':JSON.stringify({...manifest,title:''}),'clubs.json':'[]'})),/Titre/);
const bad=Buffer.from(archive);bad[45]^=1;assert.throws(()=>toWorldPack(bad),/CRC32/);
console.log(JSON.stringify({passed:true,checks:['real zip parse','normalize','inject sole registry','invalid collection','invalid manifest','tampering']}));
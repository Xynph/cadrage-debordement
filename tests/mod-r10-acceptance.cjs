'use strict';
/* End-to-end isolated acceptance of R7/R8/R9. Native browser/runtime integration is a separate gate. */
const assert=require('node:assert/strict');
const crypto=require('node:crypto');
const {toWorldPack,installIntoUniverse}=require('../modding/r4/installed-adapter.cjs');
const {createCareer,planResume}=require('../modding/r4/career-bridge.cjs');
function crc32(b){let c=0xffffffff;for(const x of b){c^=x;for(let i=0;i<8;i++)c=(c>>>1)^((c&1)?0xedb88320:0)}return(c^0xffffffff)>>>0}
function zip(entries){
 const local=[],central=[];let position=0;
 for(const [name,raw] of Object.entries(entries)){
  const n=Buffer.from(name),b=Buffer.from(raw),l=Buffer.alloc(30),c=Buffer.alloc(46),sum=crc32(b);
  l.writeUInt32LE(0x04034b50);l.writeUInt16LE(20,4);l.writeUInt32LE(sum,14);l.writeUInt32LE(b.length,18);l.writeUInt32LE(b.length,22);l.writeUInt16LE(n.length,26);
  c.writeUInt32LE(0x02014b50);c.writeUInt16LE(20,4);c.writeUInt16LE(20,6);c.writeUInt32LE(sum,16);c.writeUInt32LE(b.length,20);c.writeUInt32LE(b.length,24);c.writeUInt16LE(n.length,28);c.writeUInt32LE(position,42);
  local.push(l,n,b);central.push(c,n);position+=l.length+n.length+b.length;
 }
 const dir=Buffer.concat(central),tail=Buffer.alloc(22);
 tail.writeUInt32LE(0x06054b50);tail.writeUInt16LE(Object.keys(entries).length,8);tail.writeUInt16LE(Object.keys(entries).length,10);tail.writeUInt32LE(dir.length,12);tail.writeUInt32LE(position,16);
 return Buffer.concat([...local,dir,tail]);
}
const picture=Buffer.from('89504e470d0a1a0a0000000049454e44ae426082','hex');
const manifest={schema:1,id:'rugby-test-mod',version:'1.0.0',title:'Univers fictif test',kind:'combined',data:[{type:'clubs',path:'clubs.json'}],assets:[{type:'club-logo',ownerId:'club:test',path:'image.png',bytes:picture.length,sha256:crypto.createHash('sha256').update(picture).digest('hex')}]};
function packageWith(m=manifest,club='[{"id":"club:test","name":"Club fictif ajouté"}]',image=picture){
 return zip({'manifest.json':JSON.stringify(m),'clubs.json':club,'image.png':image});
}
// Mock only the R5 API injected into the bridges: R5 integration test is required separately.
function world(){
 const installed=new Map();let selected=[];
 const snapshot=()=>({clubs:[{id:'club:base',name:'Club fictif initial'},...selected.flatMap(id=>installed.get(id).records.clubs)]});
 return {
  install(p){if(installed.has(p.manifest.id))throw Error('Déjà installé');installed.set(p.manifest.id,p);return p.manifest.id},
  select(ids){for(const id of ids)if(!installed.has(id))throw Error('Mod manquant');selected=ids.slice();return snapshot()},
  reset(){selected=[];return snapshot()},
  active(){return selected.slice()},
  binding(){return {schema:1,mods:selected.map(id=>({id,version:installed.get(id).manifest.version}))}},
  prepareNewCareer(t){return {...t,modBinding:this.binding()}},
  checkCareer(save){const actual=JSON.stringify(this.binding());return {ok:actual===JSON.stringify(save.modBinding),reason:'Version incompatible'}}
 };
}
const session=world();
assert.equal(installIntoUniverse(packageWith(),session),'rugby-test-mod');
assert.deepEqual(session.active(),[],'Install never activates mod');
const career=createCareer(session,['rugby-test-mod'],{season:1},(settings,universe)=>({...settings,clubCount:universe.clubs.length}));
assert.equal(career.clubCount,2);
assert.equal(planResume(session,JSON.parse(JSON.stringify(career))).ok,true,'Resume same version');
assert.deepEqual(session.binding().mods,[{id:'rugby-test-mod',version:'1.0.0'}]);
const legacy={season:1,clubs:['club:base']},legacyBytes=JSON.stringify(legacy);
const oldResult=planResume(session,legacy);
assert.equal(oldResult.ok,true);
assert.equal(oldResult.legacy,true);
assert.deepEqual(session.active(),[]);
assert.equal(JSON.stringify(legacy),legacyBytes,'Legacy never changed');
assert.equal(planResume(session,{...career,modBinding:{schema:1,mods:[{id:'rugby-test-mod',version:'2.0.0'}]}}).ok,false,'Version mismatch');
assert.deepEqual(session.active(),[],'Failed resume restores selection');
assert.equal(planResume(session,{...career,modBinding:{schema:1,mods:[{id:'other-pack',version:'1.0.0'}]}}).ok,false,'Missing pack');
assert.throws(()=>toWorldPack(packageWith(manifest,'not json')),SyntaxError);
const wrongDigest=Buffer.from(picture);wrongDigest[10]^=1;
assert.throws(()=>toWorldPack(packageWith(manifest,undefined,wrongDigest)),/SHA/);
const invalidArchive=Buffer.from(packageWith());invalidArchive[43]^=1;
assert.throws(()=>toWorldPack(invalidArchive),/CRC/);
assert.deepEqual(session.active(),[]);
console.log(JSON.stringify({passed:true,checks:['zip import','asset hash','no automatic activation','new career','resume','legacy unchanged','version rejection','missing pack','bad json','bad image','crc corruption','failed resume rollback']}));

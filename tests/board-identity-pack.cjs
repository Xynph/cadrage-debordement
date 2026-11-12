'use strict';
// Rubrique facultative `boards` des packs d'identités : présidents et directeurs
// sportifs par identifiant stable (pres-<club>, ds-<club>). Noms de test inventés.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),os=require('node:os');
const media=require('../native/engine/media-packs.cjs'),boards=require('../native/engine/board-identities.cjs');
const root=fs.mkdtempSync(path.join(os.tmpdir(),'cd-board-pack-'));let seq=0;
function archive(manifest){
 const items=[['pack.json',Buffer.from(JSON.stringify(manifest))]];let offset=0;const blocks=[],central=[];
 for(const [name,data]of items){const n=Buffer.from(name),l=Buffer.alloc(30),c=Buffer.alloc(46),crc=media.crc32(data);
  l.writeUInt32LE(0x04034b50);l.writeUInt16LE(20,4);l.writeUInt16LE(0x800,6);l.writeUInt32LE(crc,14);l.writeUInt32LE(data.length,18);l.writeUInt32LE(data.length,22);l.writeUInt16LE(n.length,26);
  c.writeUInt32LE(0x02014b50);c.writeUInt16LE(20,4);c.writeUInt16LE(20,6);c.writeUInt16LE(0x800,8);c.writeUInt32LE(crc,16);c.writeUInt32LE(data.length,20);c.writeUInt32LE(data.length,24);c.writeUInt16LE(n.length,28);c.writeUInt32LE(0x81a40000,38);c.writeUInt32LE(offset,42);
  blocks.push(l,n,data);central.push(c,n);offset+=30+n.length+data.length;}
 const cd=Buffer.concat(central),end=Buffer.alloc(22);end.writeUInt32LE(0x06054b50);end.writeUInt16LE(items.length,8);end.writeUInt16LE(items.length,10);end.writeUInt32LE(cd.length,12);end.writeUInt32LE(offset,16);
 const file=path.join(root,'pack-'+(++seq)+'.zip');fs.writeFileSync(file,Buffer.concat([...blocks,cd,end]));return file;
}
const world=require('../native/engine/world-registry.json');
const rubric=[{id:'pres-0',name:'Président Test Zéro'},{id:'ds-0',name:'Directeur Test Zéro'},{id:'pres-12',name:'Président Test Douze'}];
const base={schema:'cd-identity-pack-v2',id:'directions-test',name:'Directions de réception',version:'1',databaseId:world.id,rightsStatus:'test-local',clubs:[],players:[],staff:[],assets:[]};
// Rubrique acceptée, absente.
{const meta=media.analyse(archive({...base,boards:rubric}),world).meta;
 assert.equal(meta.boardIdentityVersion,1);assert.equal(meta.counts.boards,3);
 const plain=media.analyse(archive(base),world).meta;
 assert.ok(!('boardIdentityVersion' in plain)&&!('boards' in plain.counts),'pack sans rubrique : métadonnées inchangées');}
// Refus.
for(const [label,raw] of [
 ['identifiant inconnu',[{id:'pres-999',name:'Président Test'}]],
 ['forme d’identifiant',[{id:'president-1',name:'Président Test'}]],
 ['champ en plus',[{id:'pres-1',name:'Président Test',traits:{ambition:80}}]],
 ['nom absent',[{id:'pres-1'}]],
 ['doublon',[{id:'pres-1',name:'A Test'},{id:'pres-1',name:'B Test'}]],
 ['lien',[{id:'pres-1',name:'https://exemple.test'}]],
 ['balise',[{id:'pres-1',name:'<b>Président</b>'}]],
 ['liste vide',[]],
 ['objet au lieu d’une liste',{'pres-1':'Président Test'}],
])assert.throws(()=>media.analyse(archive({...base,boards:raw}),world),/Pack refusé/,label);
// Nom de base inventé, stable, le même que celui du moteur ; remplacement d'affichage.
{const n=boards.baseName('pres-0',world);assert.ok(typeof n==='string'&&n.length>3);assert.equal(boards.baseName('pres-0',world),n);
 assert.notEqual(boards.baseName('ds-0',world),n);
 const pairs=boards.replacements(boards.ingest(rubric,world).boards,world);
 assert.deepEqual(pairs.map(p=>p[1]),rubric.map(r=>r.name));assert.equal(pairs[0][0],n);
 assert.ok(boards.validateInstalled(boards.ingest(rubric,world).boards,world));
 assert.throws(()=>boards.validateInstalled({'pres-0':{name:'X Test',extra:1}},world),/Pack refusé/);}
fs.rmSync(root,{recursive:true,force:true});
console.log('PASS rubrique boards : présidents et directeurs sportifs par identifiant, refus, nom de base, remplacement');

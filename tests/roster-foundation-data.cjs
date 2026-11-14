'use strict';
// Registre des postes, statuts et contrats vérifiés : compilé à partir de data/roster-foundation/, source du
// dépôt privé rugby-reel-donnees (scripts/sources-privees.cjs). Sans elle, le fichier publié est contrôlé par
// son empreinte et ses invariants ; avec elle (copie posée ou CD_SOURCES_PRIVEES), aussi par la source.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const builder=require('../scripts/build-roster-foundation.cjs'),privees=require('../scripts/sources-privees.cjs'),files=privees.locateAll(builder.SOURCES);
const registry=files?JSON.parse(fs.readFileSync(files['data/roster-foundation/verified.json'],'utf8')):null;
const data=require('../dist/rugby-roster-foundation.js'),base=require('../dist/rugby-common-rosters.js'),v1=data.resolve({...data.marker,version:1});
const ids=base.clubs.flatMap(c=>c.players.map(p=>p.id)).sort();assert.equal(ids.length,1592);assert.deepEqual(Object.keys(data.players).sort(),ids);assert.deepEqual(Object.keys(v1.players).sort(),ids);
const count=k=>Object.values(data.players).filter(p=>p[k].basis==='official').length;assert.equal(count('position'),241);assert.equal(count('contract'),86);assert.equal(count('status'),9);
for(const [section,field] of [['positions','position'],['contracts','contract'],['statuses','status']])for(const [id,p] of Object.entries(v1.players))if(p[field].basis==='official')assert.deepEqual(data.players[id][field],p[field],'v1 known '+section+' retained');
const knownStatuses={'lnr:1734':'professionnel','lnr:11794':'professionnel','lnr:13550':'espoir','lnr:13725':'espoir','lnr:13499':'espoir','lnr:13174':'espoir','lnr:13505':'espoir','lnr:13417':'espoir'};for(const [id,value] of Object.entries(knownStatuses)){assert.equal(data.players[id].status.value,value);assert.equal(data.players[id].status.basis,'official');}
for(const id of ['lnr:13516','lnr:13531','lnr:13650','lnr:13711'])assert.equal(data.players[id].position.basis,'estimated','quarantine retained '+id);
for(const id of ['lnr:213','lnr:1499','lnr:1555','lnr:11655']){assert.equal(data.players[id].contract.basis,'estimated');assert.equal(data.players[id].status.basis,'estimated');if(registry)assert.ok(!Object.hasOwn(registry.contracts,id));}
let newMonths=0,positionChanges=0;for(const [id,p] of Object.entries(data.players)){assert.deepEqual(p.position.qualifications,[p.position.primary]);if(v1.players[id].position.primary!==p.position.primary)positionChanges++;if(p.contract.endMonth!==null&&v1.players[id].contract.basis!=='official')newMonths++;for(const [field,section] of [['position','positions'],['contract','contracts'],['status','statuses']]){if(registry)assert.equal(Object.hasOwn(registry[section],id),p[field].basis==='official',id+' : '+field+' officiel si et seulement si vérifié');if(p[field].basis!=='official')assert.deepEqual(p[field],v1.players[id][field]);}for(const field of ['position','status','contract'])for(const source of p[field].sources)assert.ok(data.sources[source]);assert.equal(p.contract.endSeason,p.contract.endYear-2026);assert.equal(p.wage.basis,'estimated');}
assert.equal(newMonths,2);for(const [id,s] of Object.entries(data.sources)){assert.equal(s.publisher,'Source officielle '+id);assert.equal(s.observed,'2026-11-07');assert.ok(!s.published||s.published<=data.snapshot);assert.ok(!JSON.stringify(s).includes('http'));}
// Le fichier publié est celui dont l'empreinte est publiée ; toute retouche sans les sources est refusée.
privees.verifyCompiled(builder.TARGET);
const tmp=fs.mkdtempSync(path.join(require('node:os').tmpdir(),'cd-roster-empreinte-'));
try{const copy=path.join(tmp,'foundation.js');fs.writeFileSync(copy,fs.readFileSync(path.join(__dirname,'../dist/rugby-roster-foundation.js'),'utf8').replace('"endYear":2027','"endYear":2028'));assert.throws(()=>privees.verifyCompiled(builder.TARGET,copy),/modifié sans ses sources privées/);}
finally{fs.rmSync(tmp,{recursive:true,force:true});}
if(registry){
 assert.equal(registry.positionEvidence.observed,'2026-11-07');
 for(const evidence of Object.values(registry.positionEvidence.players))for(const source of evidence.sources)assert.ok(registry.sources[source],'linked development evidence '+source);
 const archive=path.dirname(files['data/roster-foundation/archive/v1/runtime.js']);assert.equal(crypto.createHash('sha256').update(fs.readFileSync(path.join(archive,'runtime.js'))).digest('hex'),'baf77c4a83517adb02358d11f177cd938cf86d356a13be119e8c0cae505fd398');assert.deepEqual(builder.archivedV1(),v1);
 assert.deepEqual(builder.build(),builder.build());assert.equal(builder.write(true),'compiled');
}else{
 assert.equal(builder.write(true),'verified','Sans sources : contrôle par empreinte annoncé.');
 assert.throws(()=>builder.write(false),/Sources privées absentes : impossible de recompiler/,'Pas de recompilation silencieuse sans sources.');
}
assert.equal(data.resolve({...data.marker,version:'1'}),null);for(const marker of [null,[],{}, {id:data.marker.id,version:0}])assert.equal(data.resolve(marker),null);
const runtime=fs.readFileSync(path.join(__dirname,'../dist/rugby-roster-foundation.js'),'utf8');assert.ok(!/https?:\/\//.test(runtime));if(registry)for(const [id,source] of Object.entries(registry.sources))assert.ok(!runtime.includes(source.evidence)&&!runtime.includes(source.url),'preuve source absente du fichier publié : '+id);
console.log(JSON.stringify({passed:true,ids:ids.length,officialPositions:count('position'),officialContracts:count('contract'),officialStatuses:count('status'),newMonths,positionChanges,controle:registry?'sources':'empreinte'}));

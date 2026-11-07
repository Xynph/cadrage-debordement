'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'..');
const catalogue=require('../dist/france-clubs.js');
const manifest=JSON.parse(fs.readFileSync(path.join(root,'dist/assets/club-atlas/manifest.json'),'utf8'));
test('atlas natif : trente territoires, soixante sources et WebP verifies',()=>{
 assert.equal(manifest.photos.length,60);
 const ids=new Set();
 for(const club of catalogue.clubs){
  for(const kind of ['city','stadium']){
   const id=club.slug+':'+kind,photo=manifest.photos.find(p=>p.id===id);
   assert.ok(photo,id);assert.ok(!ids.has(id));ids.add(id);
   const relative='assets/club-atlas/'+club.slug+'-'+kind+'.webp';
   assert.equal(photo.file,relative);
   const bytes=fs.readFileSync(path.join(root,'dist',relative));
   assert.equal(bytes.subarray(0,4).toString(),'RIFF');assert.equal(bytes.subarray(8,12).toString(),'WEBP');
   assert.equal(photo.sha256,crypto.createHash('sha256').update(bytes).digest('hex'));
   assert.equal(photo.file_bytes,bytes.length);assert.equal(photo.mime_type,'image/webp');
   assert.match(photo.source_sha256,/^[a-f0-9]{64}$/);
   for(const key of ['photographer','license','license_url','source_page_url','changes'])assert.ok(photo[key],id+' '+key);
   // Panoramas remain panoramas; portrait sources are limited to 1200px tall.
   assert.ok(photo.width>=640&&photo.height>=300&&Math.max(photo.width,photo.height)>=1000,id+' dimensions');
   assert.ok(photo.source_width>=1280&&photo.source_height>=500,id+' source dimensions');
   assert.ok(photo.visual_reviewed,id+' revue visuelle');
  }
 }
});
test('fontes et modele natifs sont accompagnes de leurs licences',()=>{
 for(const font of ['DMSans','BarlowCondensed-SemiBold']){
  const bytes=fs.readFileSync(path.join(root,'native/godot/fonts',font+'.ttf'));
  assert.ok(bytes.length>50000);assert.equal(bytes.readUInt32BE(0),0x00010000);
 }
 for(const license of ['DMSans-OFL.txt','BarlowCondensed-OFL.txt']){
  assert.match(fs.readFileSync(path.join(root,'native/godot/fonts',license),'utf8'),/SIL OPEN FONT LICENSE/);
 }
 assert.match(fs.readFileSync(path.join(root,'dist/match3d/assets/QUATERNIUS-CC0-v22.md'),'utf8'),/CC0/);
});

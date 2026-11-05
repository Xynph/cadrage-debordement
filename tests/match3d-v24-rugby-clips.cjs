'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const THREE=require('../dist/match3d/vendor/three-r149.min.js');
const ctx={};vm.runInNewContext(fs.readFileSync('dist/match3d/assets/rugby-v24/rugby-clips.js','utf8'),ctx);
const create=ctx.CDMatch3DV24RugbyClips.create;
const names=['pelvis','spine_02','spine_03','clavicle_l','clavicle_r','upperarm_l','upperarm_r','lowerarm_l','lowerarm_r','thigh_l','thigh_r','calf_l','calf_r'];
const bones=names.map(name=>{const b=new THREE.Bone();b.name=name;return b;});
const initial=bones.map(b=>b.quaternion.toArray());
const clips=create(THREE,bones);
assert.deepEqual(Array.from(clips,c=>c.name),['rugby_carry','rugby_pass','rugby_tackle','rugby_recover']);
for(const clip of clips){
 assert.ok(clip.duration>0&&clip.tracks.length>0);
 for(const track of clip.tracks){
  assert.ok(track.name.endsWith('.quaternion'));
  assert.ok(track.times.length>=3);
  for(let i=0;i<track.values.length;i+=4){
   const q=track.values.slice(i,i+4),len=Math.hypot(...q);
   assert.ok(Math.abs(len-1)<1e-5,'Quaternion normalized');
  }
 }
}
// Limiter la rotation des bras dans les poses clés pour éviter les manches disjointes.
for(const clip of clips.filter(c=>['rugby_pass','rugby_tackle'].includes(c.name))){
 for(const track of clip.tracks.filter(t=>/^upperarm_[lr]\.quaternion$/.test(t.name))){
  for(let i=0;i<track.values.length;i+=4){
   const angle=2*Math.acos(Math.min(1,Math.abs(track.values[i+3])));
   assert.ok(angle<=0.85,'Epaule trop ouverte '+clip.name+' '+angle);
  }
 }
}
for(const clip of clips.filter(c=>['rugby_pass','rugby_tackle'].includes(c.name))){
 assert.ok(clip.tracks.some(t=>t.name==='clavicle_l.quaternion'),'left clavicle in '+clip.name);
 assert.ok(clip.tracks.some(t=>t.name==='clavicle_r.quaternion'),'right clavicle in '+clip.name);
}
// Regressions cinematiques : eviter le retour aux bras synchrones et aux torses figes.
for(const name of ['rugby_pass','rugby_tackle']){
 const clip=clips.find(c=>c.name===name);
 const tracks=new Map(clip.tracks.map(t=>[t.name,t]));
 for(const bone of ['pelvis','spine_02','spine_03','upperarm_l','upperarm_r','lowerarm_l','lowerarm_r']){
  assert.ok(tracks.has(bone+'.quaternion'),name+' track '+bone);
 }
 const left=tracks.get('upperarm_l.quaternion').values;
 const right=tracks.get('upperarm_r.quaternion').values;
 assert.ok(left.some((value,i)=>Math.abs(value-right[i])>.01),name+' arms need distinct trajectories');
 const pelvis=tracks.get('pelvis.quaternion').values;
 assert.ok(pelvis.some((value,i)=>i%4!==3&&Math.abs(value)>.02),name+' pelvis must move');
}
assert.deepEqual(bones.map(b=>b.quaternion.toArray()),initial,'Never mutate original bones');
assert.throws(()=>create(THREE,bones.slice(1)),/manquant/);
console.log('PASS original rugby clips: 4 actions, normalized keyframes, nonmutation, missing-joint gate');

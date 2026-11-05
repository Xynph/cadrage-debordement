'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const THREE=require('../dist/match3d/vendor/three-r149.min.js');
const ctx={};vm.runInNewContext(fs.readFileSync('dist/match3d/assets/rugby-v24/rugby-clips.js','utf8'),ctx);
const create=ctx.CDMatch3DV24RugbyClips.create;
const names=['pelvis','spine_02','spine_03','upperarm_l','upperarm_r','lowerarm_l','lowerarm_r','thigh_l','thigh_r','calf_l','calf_r'];
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
assert.deepEqual(bones.map(b=>b.quaternion.toArray()),initial,'Never mutate original bones');
assert.throws(()=>create(THREE,bones.slice(1)),/manquant/);
console.log('PASS original rugby clips: 4 actions, normalized keyframes, nonmutation, missing-joint gate');

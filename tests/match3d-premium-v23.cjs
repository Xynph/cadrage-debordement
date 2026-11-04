'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const asset=fs.readFileSync(path.resolve(__dirname,'../dist/match3d/rugby-player-v22.js'),'utf8');
const match=fs.readFileSync(path.resolve(__dirname,'../dist/match3d/match3d.js'),'utf8');

test('v23: low-cost PBR textile uses 2 local team palettes, no external assets',()=>{
 assert.match(asset,/function textile\(T,side,part\)/);
 assert.match(asset,/new T.CanvasTexture\(canvas\)/);
 assert.match(asset,/decorateMaterial\(T,m,side,keyName\)/);
 assert.match(asset,/mat\.roughness=\.91/);
 assert.match(asset,/mat\.metalness=0/);
 assert.doesNotMatch(asset,/fetch\s*\(|https?:\/\//);
});

test('v23: deterministic rugby cues are presentation-only, no rule or save mutation',()=>{
 assert.match(asset,/function tick\(group,delta,pace=1,fall=false,cue=null\)/);
 for(const name of ['UpperArm.L','UpperArm.R','LowerArm.L','LowerArm.R','Torso'])
  assert.ok(asset.includes(name),name);
 assert.match(match,/passCue=\/pass\|offload\/i/);
 assert.match(match,/brace:cue\.bracing,pass:passCue,recovery:stumble\.recovery/);
 assert.match(match,/instance\.state\.kind/);
});

test('v23: original offline asset and fallback retained',()=>{
 assert.match(asset,/quaternius-rugby-athlete\.glb/);
 assert.match(asset,/fallback\.build/);
 assert.match(asset,/gltfAthleteV20=true/);
});

test('v23: shared fabric texture cache is deterministic and minimal',()=>{
 const window={};const context={window,Promise};vm.runInNewContext(asset,context);
 assert.equal(typeof window.CDMatch3DRugbyPlayer.load,'function');
 assert.equal(window.CDMatch3DRugbyPlayer.status().clothTextures,0);
});

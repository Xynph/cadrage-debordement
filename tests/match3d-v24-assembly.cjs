const assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const sandbox={};vm.runInNewContext(fs.readFileSync('dist/match3d/assets/rugby-v24/assembly.js','utf8'),sandbox);
assert.equal(typeof sandbox.CDV24Assembly.load,'function');
const api=sandbox.CDV24Assembly;
assert.throws(()=>api.matchBones([{name:'missing'}],[]),/missing/);
const bones=[{name:'hip'},{name:'arm'}];assert.equal(api.matchBones([{name:'arm'}],bones)[0],bones[1]);
console.log('PASS assembly API, matching by bone name, missing bone rejected');

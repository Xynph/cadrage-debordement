'use strict';
// Legacy function bodies captured verbatim from dist/saves.js at 54d67fa9.
// This tests result/rejection compatibility against that real former code.
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const LEGACY_TREE="function safeTree(root){const maxNodes=commonDatabaseActive(root)?650000:typeof CDFranceCompetition!=='undefined'&&CDFranceCompetition.active(root)?400000:200000;let count=0;function visit(v,depth){saveCheck(++count<maxNodes&&depth<35,'Le fichier est trop complexe.');if(typeof v==='string')saveCheck(v.length<=6000&&!/[<>\"`&\\u0000-\\u0008\\u000b\\u000c\\u000e-\\u001f]/.test(v),'Le fichier contient du texte non autorisé.');else if(typeof v==='number')saveCheck(saveNumber(v));else if(Array.isArray(v)){saveCheck(v.length<=2000);v.forEach(x=>visit(x,depth+1))}else if(saveObject(v)){saveCheck(Object.keys(v).length<=2000);for(const [k,x] of Object.entries(v)){saveCheck(!['__proto__','constructor','prototype'].includes(k),'Le fichier contient une structure non autorisée.');saveCheck(k.length<200&&!/[<>\"`&]/.test(k));visit(x,depth+1)}}else saveCheck(v===null||typeof v==='boolean')}visit(root,0)}";
const LEGACY_CHECKSUM="function saveChecksum(state){const text=JSON.stringify(state);let h=2166136261;for(let i=0;i<text.length;i++){h^=text.charCodeAt(i);h=Math.imul(h,16777619)}return (h>>>0).toString(16).padStart(8,'0')}";
const lines=fs.readFileSync(path.join(__dirname,'../dist/saves.js'),'utf8').split(/\r?\n/);
const currentTree=lines.find(line=>line.startsWith('function safeTree(')),currentChecksum=lines.find(line=>line.startsWith('function saveChecksum('));
// Standalone helper compilation includes the same stable intrinsic bindings as production.
const numericIntrinsics=lines.find(line=>line.startsWith('const nativeSaveFinite='));assert.equal(typeof numericIntrinsics,'string');
const helpers=[numericIntrinsics,...['saveError','saveCheck','saveObject','saveNumber'].map(name=>lines.find(line=>line.startsWith('function '+name+'(')))].join('\n');
function pair(){return [[LEGACY_TREE,LEGACY_CHECKSUM],[currentTree,currentChecksum]].map(source=>{const ctx=vm.createContext({JSON,Math:Object.create(Math)});vm.runInContext(helpers+"\nfunction commonDatabaseActive(root){return root?.common===true}\nconst CDFranceCompetition={active:root=>root?.france===true};\n"+source.join('\n'),ctx);return ctx;});}
function result(ctx,expression,value){ctx.candidate=value;try{return {value:vm.runInContext(expression,ctx)};}catch(error){return {error:error.name+':'+error.message};}}
test('Sauvegardes : 205 checksums strictement identiques à la fonction historique, sans mutation',()=>{
 const real=require('./harness.cjs').context();real.run('start(0)');const state=JSON.parse(real.run('JSON.stringify(S)'));
 let seed=31;const random=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed;};
 const values=[state,null,{},[],{accent:'Émile été',emoji:'🏉',lone:'\ud800',zero:-0},...Array.from({length:200},()=>({n:random()|0,s:Array.from({length:100},()=>String.fromCharCode(random()%65536)).join(''),a:[random(),true,null]}))];
 const contexts=pair();for(const value of values){const before=JSON.stringify(value);assert.deepEqual(result(contexts[1],'saveChecksum(candidate)',value),result(contexts[0],'saveChecksum(candidate)',value));assert.equal(JSON.stringify(value),before);}
 assert.equal(values.length,205);
});
test('Sauvegardes : mêmes contrôles, messages, limites et ordre de visite pour les arbres hostiles',()=>{
 const contexts=pair();const deep={};let tail=deep;for(let n=0;n<36;n++)tail=tail.child={};
 const cases=[{accepted:true,value:{text:'Émile',data:[false,null,25]}},...[
  NaN,Infinity,-Infinity,1e12+1,-1e12-1,undefined,()=>0,'<script>',String.fromCharCode(0),'x'.repeat(6001),
  JSON.parse('{"__proto__":0}'),{constructor:0},{prototype:0},{['k'.repeat(200)]:0},Array(2001).fill(0),
  Object.fromEntries(Array.from({length:2001},(_,i)=>['x'+i,0])),deep
 ].map(value=>({accepted:false,value}))];
 for(const limit of [200000,400000,650000]){
  const shape=n=>({common:limit===650000,france:limit===400000,items:Array.from({length:n},()=>Array(1000).fill(false))});
  cases.push({accepted:true,value:shape(Math.floor(limit/1001)-1)},{accepted:false,value:shape(Math.ceil(limit/1001)+1)});
 }
 for(const item of cases){const before=JSON.stringify(item.value),old=result(contexts[0],'safeTree(candidate)',item.value),actual=result(contexts[1],'safeTree(candidate)',item.value);assert.deepEqual(actual,old);assert.equal(!Object.hasOwn(actual,'error'),item.accepted);assert.equal(JSON.stringify(item.value),before);}
 // Object.entries must read all values before the first key rejection, exactly
 // as before. Do not replace the visitor with a traversal of a different order.
 for(const context of contexts){const trace=[];const value={};Object.defineProperty(value,'constructor',{enumerable:true,get(){trace.push('first');return 0;}});Object.defineProperty(value,'later',{enumerable:true,get(){trace.push('second');return 'x';}});assert.ok(result(context,'safeTree(candidate)',value).error);assert.deepEqual(trace,['first','second']);}
});


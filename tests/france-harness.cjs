'use strict';
process.env.CD_MODES_HERITES='1'; // Anciens modes de carrière (non-Monde) : test à migrer vers le mode Monde.
const vm=require('node:vm'),fs=require('node:fs'),path=require('node:path');
const {CORE_FILES}=require('../native/engine/worker.cjs');
const playerAttributes=require('../native/engine/player-attributes.cjs');
function context(seed=827381,options={}){const store={};const math=Object.create(Math);math.random=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296;};class FixedDate extends Date{constructor(...args){super(...(args.length?args:[1700000000000]));}static now(){return 1700000000000;}}
const el={innerHTML:'',textContent:'',style:{}},storage={getItem:k=>store[k]??null,setItem:(k,v)=>store[k]=v,removeItem:k=>delete store[k]};
const ctx=vm.createContext({CDNativeHeadless:true,console,Intl,Math:math,Date:FixedDate,Set,JSON,document:{querySelector:()=>el},window:{CDNativeHeadless:true,CDOfflineError:true},localStorage:storage,setTimeout:()=>0,clearTimeout(){},setInterval:()=>0,clearInterval(){},nativeDataDirectory:'test'});const run=src=>vm.runInContext(src,ctx,{timeout:180000});for(const f of (options.files||CORE_FILES))run(options.source?options.source(f):fs.readFileSync(path.join(__dirname,'../dist',f),'utf8'));run("render=()=>{};toast=()=>{};startTimer=()=>{};validatingStartup=false;");if(process.env.CD_MATCH_COURSES==='0')ctx.MATCH_COURSES_DECOUPEES=false;let nativeProjectionReady=false;
function prepareNativeProjection(){
 if(!nativeProjectionReady){
  run(`const nativeAttributeStore=(${playerAttributes.toString()})();const nativePlayerAttributes=nativeAttributeStore.project;`);
  nativeProjectionReady=true;
 }
 run('nativeAttributeStore.complete(S)');
}
return {ctx,run,store,prepareNativeProjection,seed:()=>seed,state:()=>JSON.parse(run('JSON.stringify(S)'))};}
module.exports={context};

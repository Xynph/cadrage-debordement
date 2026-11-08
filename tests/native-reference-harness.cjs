'use strict';
// Référence directe du moteur natif : même manifeste et hooks, sans protocole,
// createBridge, profil disque ni projection de sauvegarde.
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const {CORE_FILES}=require('../native/engine/worker.cjs');
const systems=require('../native/engine/native-systems.cjs');
const common=require('../native/engine/common-rosters.cjs');
function context({seed:initialSeed=827381,now=1700000000000,dataDir=''}={}){
 let seed=initialSeed>>>0,calls=0;
 const math=Object.create(Math);math.random=()=>{calls++;seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296;};
 class EngineDate extends Date{constructor(...args){super(...(args.length?args:[now]));}static now(){return now;}}
 const store={},storage={offline:true,directory:dataDir,getItem:key=>store[key]??null,setItem:(key,value)=>{store[key]=String(value);},removeItem:key=>{delete store[key];}};
 const element={innerHTML:'',textContent:'',style:{}};
 const ctx=vm.createContext({console:{log(){},warn(){},error(){}},Intl,Math:math,Date:EngineDate,Set,JSON,CDNativeHeadless:true,document:{querySelector:()=>element},window:{CDNativeHeadless:true,CDOfflineStorage:storage,CDOfflineError:true},localStorage:storage,setTimeout:()=>0,clearTimeout(){},setInterval:()=>0,clearInterval(){},nativeDataDirectory:dataDir});
 const run=source=>vm.runInContext(source,ctx,{timeout:15000});
 for(const name of CORE_FILES)run(fs.readFileSync(path.resolve(__dirname,'../dist',name),'utf8'));
 run(`render=()=>{};toast=()=>{};startTimer=()=>{};save=()=>{if(S&&!validatingStartup){gameStorage.setItem('bdt-v1',JSON.stringify(S));lastSaveError=false;}};validatingStartup=false;const CDCommonCareer=(${common.toString()})();`);
 run(systems.bootstrap());
 return {ctx,store,run,randomState:()=>({seed,calls})};
}
module.exports={context};

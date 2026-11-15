'use strict';
// Codec-only fixtures: no career is created, booted or simulated in this VM.
// Whole-career validation is exercised separately by saves/offline and World recipes.
const fs=require('node:fs'),vm=require('node:vm');
function context(){
 const store={};const ctx=vm.createContext({console,Date,gameStorage:{getItem:k=>store[k]??null,setItem:(k,v)=>{store[k]=String(v)},removeItem:k=>{delete store[k]}},toast:message=>{throw Error(message)}});
 vm.runInContext(fs.readFileSync(__dirname+'/../../dist/ai-roster-cycle.js','utf8'),ctx,{filename:'ai-roster-cycle.js'});
 vm.runInContext(fs.readFileSync(__dirname+'/../../dist/saves.js','utf8'),ctx,{filename:'saves.js'});
 return {ctx,store,run:source=>vm.runInContext(source,ctx)};
}
module.exports={context};
// Real browser persistence contract, isolated from the worker's native writer.
function webSaveContext(state,storage,slots){
 const ctx=vm.createContext({S:JSON.parse(JSON.stringify(state)),gameStorage:storage,CDMenuSlots:slots,validatingStartup:false,lastSaveError:false,toast(){}});
 const source=fs.readFileSync(__dirname+'/../../dist/game.js','utf8').split('\n').find(line=>line.startsWith('function save('));
 if(!source)throw Error('Fonction save Web absente.');
 vm.runInContext(source,ctx,{filename:'game.js:save'});
 return {ctx,run:code=>vm.runInContext(code,ctx)};
}
module.exports.webSaveContext=webSaveContext;

'use strict';
// Compatibilité des recettes HTML : même VM et vraie création world-champ que le jeu natif.
// Aucun démarrage de carrière hérité ; les scénarios règlent ensuite leur fixture Monde.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {context:worldContext}=require('./monde-harness.cjs');
const root=path.resolve(__dirname,'../dist');
const source=fs.readFileSync(path.join(root,'game.js'),'utf8').split('\n');
function context(saved,providedStorage){
 if(saved)assert.equal(saved.worldMode?.version,5,'Le harnais ne recharge que la carrière Monde complète.');
 const h=worldContext(827381,{club:null});
 const rawRun=h.run,nativeStart=h.start,ctx=h.ctx,app=ctx.document.querySelector('#app');
 let creating=false;
 try{
  for(const file of ['main-menu-slots.js','main-menu-v3.js','art-direction-v4.js'])rawRun(fs.readFileSync(path.join(root,file),'utf8'));
  // Le worker masque le rendu ; réutiliser les vraies fonctions du jeu pour conserver les contrôles HTML.
  for(const name of ['render','toast','startTimer']){
   const definition=source.find(line=>line.startsWith('function '+name+'('));
   assert.ok(definition,'Fonction de présentation absente : '+name);
   rawRun(definition);
  }
  function start(club=0,mode){
   // Le dispatch natif appelle encore start avec le mode Monde après avoir créé sa carrière : aucun effet.
   if(creating&&mode==='world-champ')return;
   if(mode!==undefined&&mode!=='world-champ')throw Error('Le harnais autorise uniquement la carrière Monde.');
   creating=true;try{nativeStart(club);}finally{creating=false;}
   rawRun('entryScreen="game";view="dashboard"');return h;
  }
  ctx.start=start;ctx.startWorld=start;h.start=start;
  ctx.toMatch=h.toMatch;
  h.app=app;
  if(providedStorage){
   const storage=ctx.window.CDOfflineStorage;
   for(const name of ['getItem','setItem','removeItem'])if(typeof providedStorage[name]==='function')storage[name]=providedStorage[name].bind(providedStorage);
  }
  if(saved){
   ctx.harnessSavedText=JSON.stringify(saved);
   rawRun('gameStorage.setItem("bdt-v1",harnessSavedText);loadedSaveText=harnessSavedText;S=JSON.parse(harnessSavedText);validatingStartup=true;bootSavedCareer();delete globalThis.harnessSavedText');
  }
  h.run=(code,timeout)=>{
   if(/\bCD(?:France|Common|World)Career\.start\s*\(/.test(code))throw Error('Utiliser le démarrage Monde du harnais, pas une ancienne fabrique.');
   return rawRun(code,timeout);
  };
  return h;
 }catch(e){h.close();throw e;}
}
module.exports={context};

#!/usr/bin/env node
'use strict';
// Rejoue un cas extrait d'une carrière Monde sans reconstruire cette carrière.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const C=require('../../native/engine/match-choregraphe.cjs');
function replay(file,output){
 const data=JSON.parse(fs.readFileSync(file,'utf8')),cases=Array.isArray(data)?data:[data];
 const result=cases.map((sample,index)=>{
  const entree=sample.entree??sample,t0=performance.now(),c=C.composer(entree),ms=performance.now()-t0;
  assert.ok(c.duree>=C.DUREE_MIN&&c.duree<=c.dureeMax&&c.dureeMax<=C.DUREE_PLAFOND,'Durée invalide');
  if(entree.jalonsAttendus)assert.deepEqual([...new Set(c.jalons.map(([,k])=>k))].sort((a,b)=>a-b),[...entree.jalonsAttendus].sort((a,b)=>a-b),'Un fait du moteur a disparu');
  if(entree.marqueur!=null)assert.equal(c.marqueur,String(entree.marqueur),'Le marqueur du moteur a changé');
  return {source:sample.source??'cas '+index,ms:Math.round(ms*10)/10,choregraphie:c};
 });
 if(output){const target=path.resolve(output);fs.mkdirSync(path.dirname(target),{recursive:true});fs.writeFileSync(target,JSON.stringify(result)+'\n');}
 console.log(JSON.stringify(result.map(({source,ms,choregraphie:c})=>({source,ms,type:c.type,duree:c.duree,jalons:c.jalons,marqueur:c.marqueur})),null,2));
 return result;
}
if(require.main===module){try{const args=process.argv.slice(2),at=args.indexOf('--output');if(!args[0])throw Error('Usage : node tools/qa/replay-choregraphe.cjs <entrée.json> [--output pistes.json]');replay(args[0],at>=0?args[at+1]:null);}catch(e){console.error(e.message);process.exitCode=1;}}
module.exports={replay};

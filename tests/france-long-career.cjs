'use strict';
const assert=require('node:assert/strict'),{context}=require('./france-harness.cjs');
const h=context();h.run("start(29,'france')");const measures=[];
function count(v){return 1+(Array.isArray(v)?v.reduce((n,x)=>n+count(x),0):v&&typeof v==='object'?Object.values(v).reduce((n,x)=>n+count(x),0):0);}
for(let season=1;season<=10;season++){
 for(let w=0;w<34;w++)h.run('finishRound()');
 const s=h.state();assert.equal(s.history.length,433);assert.equal(s.season,season);const text=JSON.stringify(s);measures.push({season,phase:s.phase,bytes:Buffer.byteLength(text),nodes:count(s),players:s.clubs.reduce((n,c)=>n+c.players.length,0),academy:s.aiRoster.academies.reduce((n,a)=>n+a.players.length,0)});
 let validation='OK';try{h.run('validateCareer(S);pendingSave=parseSaveDocument(JSON.stringify(createSaveDocument()));if(!confirmSaveImport())throw Error("import");');}catch(e){validation=e.message;if(!process.argv.includes('--measure'))throw e;}
 console.log(JSON.stringify({...measures.at(-1),validation}));h.run('advanceSeason()');
 try{h.run('validateCareer(S);pendingSave=parseSaveDocument(JSON.stringify(createSaveDocument()));if(!confirmSaveImport())throw Error("import");');}catch(e){if(!process.argv.includes('--measure'))throw e;}
}
console.log('MAX',JSON.stringify({bytes:Math.max(...measures.map(m=>m.bytes)),nodes:Math.max(...measures.map(m=>m.nodes))}));

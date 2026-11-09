'use strict';
const assert=require('node:assert/strict');
const fs=require('node:fs');
assert.ok(fs.existsSync(require('node:path').join(__dirname,'../native/engine/competition-editor.cjs')),'Le module atelier de calendrier est disponible');
const editor=require('../native/engine/competition-editor.cjs');
let checks=0;
function ok(condition,message){assert.ok(condition,message);checks++;}
for(let n=2;n<=32;n++)for(const doubleRound of [false,true]){
 const names=Array.from({length:n},(_,i)=>'Club '+(i+1));
 const doc=editor.generate({name:'Ma ligue',clubs:names,doubleRound});
 const text=JSON.stringify(doc);
 const out=editor.validate(doc);
 ok(out.fixtures.length===n*(n-1)/2*(doubleRound?2:1),'nombre total rencontres '+n);
 ok(doc.rounds===(n%2?n:n-1)*(doubleRound?2:1),'nombre journées '+n);
 const pair=new Map();
 for(const f of doc.fixtures){const key=[f.homeId,f.awayId].sort().join('/');pair.set(key,(pair.get(key)||0)+1);}
 ok([...pair.values()].every(v=>v===(doubleRound?2:1)),'toutes les paires présentes');
 ok(JSON.stringify(doc)===text,'validation sans mutation');
 ok(JSON.stringify(editor.project({action:'validate',document:doc}).document)===text,'projection conserve le document');
 if(doubleRound)ok(doc.fixtures.every(f=>doc.fixtures.some(g=>g.homeId===f.awayId&&g.awayId===f.homeId)),'retours inversés');
}
const source=editor.generate({name:'Ligue',clubs:['A','B','C','D'],doubleRound:true});
const reject=(fn)=>{assert.throws(fn,/calendrier/i);checks++;};
reject(()=>editor.generate({name:'Ligue',clubs:['A'],doubleRound:false}));
reject(()=>editor.generate({name:'Ligue',clubs:['A','a'],doubleRound:false}));
reject(()=>editor.generate({name:'Ligue',clubs:['A','B'],doubleRound:'yes'}));
reject(()=>editor.generate({name:'Ligue',clubs:['A','B'],doubleRound:false,extra:true}));
for(const modify of [d=>d.fixtures.pop(),d=>d.fixtures[0].awayId=d.fixtures[0].homeId,d=>d.fixtures[0].homeId='absent',d=>d.fixtures.push({...d.fixtures[0]}),d=>d.fixtures[0].round=0,d=>d.fixtures[0].round=1.2,d=>d.clubs[1].id=d.clubs[0].id,d=>d.clubs[1].name='a',d=>d.official=true,d=>d.fixtures[0].score=2]){
 const doc=structuredClone(source);modify(doc);reject(()=>editor.validate(doc));
}
const moved=structuredClone(source);moved.fixtures[1].round=moved.fixtures[0].round;moved.fixtures[1].homeId=moved.fixtures[0].homeId;reject(()=>editor.validate(moved));
reject(()=>editor.project({action:'validate',document:JSON.stringify(source)}));
reject(()=>editor.project({action:'unknown'}));
ok(editor.project({action:'generate',name:'Ligue',clubs:['A','B'],doubleRound:false}).summary.matches===1,'résumé utilisable');
console.log(checks+' contrôles calendrier réussis');

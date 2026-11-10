'use strict';
const assert=require('node:assert/strict');
const {context}=require('./harness.cjs');

const {ctx,run,store}=context();
const freeAgents=[
 {id:'agent:a',bio:'é'.repeat(180),condition:89},
 {id:'agent:b',bio:'à'.repeat(180),condition:72},
 {id:'agent:c',condition:66},
];
const source={
 version:2,season:4,club:0,
 worldMode:{version:5},
 economy:{freeAgents},
 market:[{...freeAgents[1]},{...freeAgents[2],condition:64},{...freeAgents[0]}],
};
ctx.codecFixture=JSON.stringify(source);
ctx.codecCap=1250;
run(`
 const CDWorldCareer={
  active:s=>[4,5].includes(s?.worldMode?.version),
  edition:s=>({version:s.worldMode.version,limits:{saveBytes:codecCap}}),
 };
 const codecState=JSON.parse(codecFixture);
 // This test isolates the portable codec. The real worker test keeps every
 // career and player validation when importing an actual saved season.
 validateCareer=s=>saveCheck(s.market.every(p=>saveObject(p)&&saveId(p.id)));
`);

const encoded=run('JSON.stringify(createSaveDocument(codecState))');
const portable=JSON.parse(encoded);
assert.equal(portable.exportVersion,2);
assert.ok(Buffer.byteLength(encoded)<=ctx.codecCap);
assert.deepEqual(portable.state.market,['agent:b',{id:'agent:c',condition:64},'agent:a']);
ctx.codecText=encoded;
assert.equal(run('JSON.stringify(parseSaveDocument(codecText).state)'),JSON.stringify(source));
assert.equal(run('{const restored=parseSaveDocument(codecText).state;restored.market[0]!==restored.economy.freeAgents[1]}'),true);

store['bdt-before-import']=encoded;
run('var capturedBackup;downloadSaveDocument=doc=>{capturedBackup=doc};exportBackup()');
assert.deepEqual(JSON.parse(run('JSON.stringify(capturedBackup)')),portable);

function refuses(change,message){
 const bad=JSON.parse(encoded);
 change(bad);
 ctx.codecBad=JSON.stringify(bad);
 assert.throws(()=>run('parseSaveDocument(codecBad)'),message);
}
refuses(doc=>{doc.state.market[0]='agent:missing';},/référence/i);
refuses(doc=>{doc.state.market[1]='agent:b';},/référence/i);
refuses(doc=>{doc.state.economy.freeAgents.push(doc.state.economy.freeAgents[2]);},/référence/i);
refuses(doc=>{doc.state.economy.freeAgents[0].condition=10;},/modifié ou endommagé/i);
refuses(doc=>{doc.state.worldMode.version=4;},/version d.export/i);
refuses(doc=>{doc.exportVersion=1;},/incohérentes/i);

const ordinary=JSON.parse(run('JSON.stringify(createSaveDocument({...codecState,economy:{freeAgents:[]},market:[]}))'));
assert.equal(ordinary.exportVersion,1);
ctx.codecOrdinary=JSON.stringify(ordinary);
assert.equal(run('JSON.stringify(parseSaveDocument(codecOrdinary))'),ctx.codecOrdinary);
assert.throws(()=>run('createSaveDocument({...codecState,worldMode:{version:4}})'),/trop volumineux/i);
assert.throws(()=>run('createSaveDocument({...codecState,market:codecState.market.map(p=>({...p,condition:0}))})'),/trop volumineux/i);
console.log('PASS export Champ : v1, v2, références sûres, ordre, état et secours identiques, édition et plafond');

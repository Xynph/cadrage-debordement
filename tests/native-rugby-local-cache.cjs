'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const {isDeepStrictEqual}=require('node:util');
const {performance}=require('node:perf_hooks'),{context}=require('./native-reference-harness.cjs');
function exact(actual,expected,label){
 if(isDeepStrictEqual(actual,expected))return;
 const folder=path.resolve(__dirname,'../work/local-cache-diagnostics');fs.mkdirSync(folder,{recursive:true});
 const name=label.replace(/[^a-zA-Z0-9_-]/g,'_'),files=['actual','expected'].map(side=>path.join(folder,name+'-'+side+'.json'));
 for(const [i,value]of [actual,expected].entries())fs.writeFileSync(files[i],typeof value==='string'?value:JSON.stringify(value));
 assert.fail(label+' differs; exact diagnostics: '+files.join(', '));
}
// Exact production functions from763903ec8a4aae5f61862d5e404bd438c246da4e.
// Execute them as an independent behavioral reference, not as an expected-data builder.
const originalBuild=String.raw`function buildSheet(c,preferred=[],preferredBench=[]){const used=new Set();const lineup=FAMILIES.map((f,i)=>{let p=c.players.find(p=>p.id===preferred[i]&&!p.injury&&!used.has(p.id)&&slotEligible(p,i));if(!p)p=c.players.filter(p=>!p.injury&&!used.has(p.id)&&slotEligible(p,i)).sort((a,b)=>fitScore(b,f)-fitScore(a,f))[0];if(p)used.add(p.id);return p?.id||null});const bench=BENCH_LABELS.map((_,i)=>{let p=c.players.find(p=>p.id===preferredBench[i]&&!p.injury&&!used.has(p.id)&&benchEligible(p,i));if(!p)p=c.players.filter(p=>!p.injury&&!used.has(p.id)&&benchEligible(p,i)).sort((a,b)=>fitScore(b)-fitScore(a))[0];if(p)used.add(p.id);return p?.id||null});return{lineup,bench}}`;
const originalActive=String.raw`function activePlayers(l,side){const s=l.sheets[side];return s.on.map(id=>matchPlayer(l,side,id)).filter(p=>p&&!s.cards.some(c=>c.id===p.id&&c.until>l.minute))}`;
const generated=context({seed:13});generated.run('CDCommonCareer.start(29);nativeSystems.execute("academy_activate",{season:1,week:0,club:29,confirmed:true})');
const initial=JSON.parse(generated.run('JSON.stringify(S)')),historical=context({seed:13});historical.run('start(0)');
const inputs=[...initial.clubs,...JSON.parse(historical.run('JSON.stringify(S.clubs)')),...initial.nativeAcademy.centers.map(c=>({id:c.id,players:c.clubId===null?c.players:c.clubId===initial.club?initial.development.academy:initial.aiRoster.academies.find(a=>a.clubId===c.clubId).players}))];
assert.equal(inputs.length,88,'30clubs communs,14historiques,44centres');
const optional=process.env.CD_RUGBY_CACHE_PROFILE;
const start=optional?JSON.parse(JSON.parse(fs.readFileSync(optional,'utf8')).store['bdt-v1']):initial;
const initialSeed=optional?JSON.parse(fs.readFileSync(optional,'utf8')).seed:generated.randomState().seed;
const variants={};
for(const name of ['baseline','production']){
 // Historical inner functions receive the same qualification and bench wrappers.
 const t=context({seed:initialSeed,beforePositionHooks:name==='baseline'?'buildSheet='+originalBuild+';activePlayers='+originalActive:undefined});
 t.ctx.start=JSON.stringify(start);t.run('S=JSON.parse(start)');t.ctx.inputs=JSON.stringify(inputs);
 const before=t.run('JSON.stringify(S)'),rng=t.randomState();
 const cases=JSON.parse(t.run(`(()=>{const rows=[],active=[],saved=S,realFit=fitScore,realPlayer=matchPlayer;let fitCalls=0,lookups=0;fitScore=(...a)=>{fitCalls++;return realFit(...a)};matchPlayer=(...a)=>{lookups++;return realPlayer(...a)};try{
 for(const source of JSON.parse(inputs)){
  for(const mode of ['empty','preferred','lazy']){const c=JSON.parse(JSON.stringify(source));if(mode==='lazy')for(const p of c.players){delete p.skills;delete p.skillBase;}const preferred=mode==='preferred'?buildSheet(JSON.parse(JSON.stringify(source))):{lineup:[],bench:[]};const sheet=buildSheet(c,preferred.lineup,preferred.bench);rows.push({club:c.id,mode,sheet,players:c.players});}
  for(const duplicate of [false,true]){const c=JSON.parse(JSON.stringify(source));if(duplicate)c.players.push({...c.players[0],rating:-999});S={...saved,clubs:[c]};const l={pair:[0,0],minute:20,sheets:[{on:[...c.players.slice(0,15).map(p=>p.id),c.players[0].id,'unknown',null],cards:[{id:c.players[5]?.id,until:21},{id:c.players[6]?.id,until:20}]}]};active.push({club:c.id,duplicate,indices:activePlayers(l,0).map(p=>c.players.indexOf(p))});c.players.reverse();active.push({club:c.id,duplicate,changed:true,indices:activePlayers(l,0).map(p=>c.players.indexOf(p))});}
  const changed=JSON.parse(JSON.stringify(source));buildSheet(changed);changed.players[0].rating=99;changed.players[0].condition=12;rows.push({club:changed.id,mode:'changed',sheet:buildSheet(changed),players:changed.players});
 }
 }finally{S=saved;fitScore=realFit;matchPlayer=realPlayer;}return JSON.stringify({rows,active,fitCalls,lookups})})()`));
 exact(t.run('JSON.stringify(S)'),before,name+'-comparisons-do-not-mutate-S');assert.deepEqual(t.randomState(),rng,'Comparaisons sans RNG');
 const weeks=[];for(let i=0;i<2;i++){const began=performance.now();t.run('finishRound();save();validateCareer(S)');weeks.push({ms:performance.now()-began,week:t.run('S.franceMode.week'),juniorRound:t.run('S.v73Espoirs.round'),accessionRound:t.run('S.v74Accession.round'),state:t.run('JSON.stringify(S)'),store:JSON.stringify(t.store),rng:t.randomState()});}
 variants[name]={cases,weeks};
}
const a=variants.baseline,b=variants.production;
assert.equal(b.cases.rows.length,a.cases.rows.length);
for(let i=0;i<a.cases.rows.length;i++)exact(b.cases.rows[i],a.cases.rows[i],'row-'+i+'-'+a.cases.rows[i].club+'-'+a.cases.rows[i].mode);
assert.deepEqual(b.cases.active,a.cases.active,'Mêmes objets/ordre/cartes/doublons find-first et roster remplacé entre appels');
assert.ok(b.cases.fitCalls<a.cases.fitCalls,'Les mêmes notes ne doivent pas être recalculées à chaque comparaison dans buildSheet');
assert.ok(a.cases.lookups>0);assert.equal(b.cases.lookups,0,'activePlayers résout les IDs une fois localement sans find répété');
for(let i=0;i<2;i++){exact(b.weeks[i].state,a.weeks[i].state,'week-'+i+'-state');exact(b.weeks[i].store,a.weeks[i].store,'week-'+i+'-store');assert.deepEqual(b.weeks[i].rng,a.weeks[i].rng);assert.equal(b.weeks[i].week,a.weeks[i].week);}
assert.equal(b.weeks[1].juniorRound,1);assert.equal(b.weeks[1].accessionRound,1);
console.log(JSON.stringify({passed:true,buildComparisons:b.cases.rows.length,activeComparisons:b.cases.active.length,fitCalls:{baseline:a.cases.fitCalls,production:b.cases.fitCalls},realWeeks:a.weeks.map((w,i)=>({week:w.week,baselineMs:w.ms,productionMs:b.weeks[i].ms})),stateStoreAndRngExact:true,optionalProfile:optional||null}));

'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const {JOBS,marker,assess,candidates,handle}=require('../ci/producer-handoff.cjs');
const SHA='a'.repeat(40),REPO='Xynph/cadrage-debordement';
const pr=()=>({number:215,state:'open',draft:false,merged:false,mergeable_state:'clean',
 base:{ref:'main'},head:{sha:SHA,repo:{full_name:REPO}}});
const js=()=>({id:9,name:'Tests JavaScript',event:'pull_request',head_sha:SHA,status:'completed',conclusion:'success'});
const other=()=>({id:10,name:'UI Chromium mutualise - CI V3',event:'pull_request',head_sha:SHA,status:'completed',conclusion:'success'});
const jobs=()=>JOBS.map(name=>({name,status:'completed',conclusion:'success'}));
test('sept jobs exacts et autres workflows effectivement réussis',()=>{
 assert.equal(assess(pr(),[js(),other()],jobs()).ready,true);
});
test('jamais de passation sur draft, branche behind ou dépôt externe',()=>{
 assert.equal(assess({...pr(),draft:true},[js()],jobs()).ready,false);
 assert.equal(assess({...pr(),mergeable_state:'behind'},[js()],jobs()).ready,false);
 assert.equal(assess({...pr(),head:{sha:SHA,repo:{full_name:'fork/repo'}}},[js()],jobs()).ready,false);
});
test('jamais de passation pour CI échouée, sautée ou job supplémentaire',()=>{
 const bad=jobs();bad[1].conclusion='failure';
 assert.equal(assess(pr(),[js()],bad).ready,false);
 const skipped=jobs();skipped[2].conclusion='skipped';
 assert.equal(assess(pr(),[js()],skipped).ready,false);
 assert.equal(assess(pr(),[js()],[...jobs(),{name:'extra',status:'completed',conclusion:'success'}]).ready,false);
 const no=js();no.conclusion='failure';
 assert.equal(assess(pr(),[no],jobs()).ready,false);
});
test('un autre workflow en attente ou en échec bloque la passation',()=>{
 const wait=other();wait.status='in_progress';wait.conclusion=null;
 assert.equal(assess(pr(),[js(),wait],jobs()).ready,false);
 const failed=other();failed.conclusion='failure';
 assert.equal(assess(pr(),[js(),failed],jobs()).ready,false);
});
test('une CI d’un autre SHA ne sert jamais de preuve',()=>{
 const a=js();a.head_sha='b'.repeat(40);
 assert.equal(assess(pr(),[a],jobs()).ready,false);
});
test('la dernière tentative de chaque workflow prévaut',()=>{
 const bad=js();bad.id=11;bad.conclusion='failure';
 assert.equal(assess(pr(),[js(),bad],jobs()).ready,false);
});
test('candidats de la PR ou du workflow reçu',()=>{
 assert.deepEqual(candidates({pull_request:{number:215}}),[215]);
 assert.deepEqual(candidates({workflow_run:{pull_requests:[{number:215},{number:215}]}}),[215]);
});
function mock(existing=false){
 const calls=[],key=marker(215,SHA);
 const api=async(path,method='GET',data)=>{
  calls.push({path,method,data});
  if(path==='pulls/215')return pr();
  if(path.startsWith('actions/runs?'))return {workflow_runs:[js(),other()]};
  if(path==='actions/runs/9/jobs?per_page=100')return {jobs:jobs()};
  if(path.startsWith('issues/73/comments?'))return existing?[{body:key}]:[];
  if(path==='issues/73/comments'&&method==='POST')return {id:1};
  throw Error('Unmocked '+path);
 };
 return {api,calls};
}
test('publication unique avec SHA et avertissement aucune fusion',async()=>{
 const m=mock();
 const output=await handle({pull_request:{number:215,head:{sha:SHA}}},m.api);
 assert.equal(output.length,1);
 const write=m.calls.filter(c=>c.method==='POST');
 assert.equal(write.length,1);
 assert.match(write[0].data.body,/Aucune fusion autorisée/);
 assert.match(write[0].data.body,/7\/7|sept jobs/i);
 assert.match(write[0].data.body,new RegExp(SHA));
});
test('idempotence exacte sur PR + SHA',async()=>{
 const m=mock(true);
 assert.deepEqual(await handle({pull_request:{number:215,head:{sha:SHA}}},m.api),[]);
 assert.equal(m.calls.filter(c=>c.method==='POST').length,0);
});
test('aucune opération d’écriture avec un HEAD de départ obsolète',async()=>{
 const m=mock();
 assert.deepEqual(await handle({pull_request:{number:215,head:{sha:'b'.repeat(40)}}},m.api),[]);
 assert.equal(m.calls.filter(c=>c.method==='POST').length,0);
});
test('pas de transfert de workflow push sur main',async()=>{
 const m=mock();
 assert.deepEqual(await handle({workflow_run:{event:'push',head_sha:SHA,pull_requests:[{number:215}]}},m.api),[]);
 assert.equal(m.calls.length,0);
});

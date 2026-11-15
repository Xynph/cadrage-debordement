'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),press=require('../native/engine/press.cjs');
const ctx=vm.createContext({CDNativeHeadless:true,console,save(){},render(){}}),run=s=>vm.runInContext(s,ctx);
run(fs.readFileSync(path.join(__dirname,'../dist/france-competition.js'),'utf8'));
for(const file of press.files)run(fs.readFileSync(path.join(__dirname,'../dist',file),'utf8'));
run(`S={season:1,round:2,club:1,morale:75,trust:70,live:null,clubs:[{id:0,name:'A',points:4,played:2,pf:30,pa:40,players:[]},{id:1,name:'B',points:4,played:2,pf:50,pa:30,players:[]}],history:[{leagueId:'elite',phase:'league',pair:[0,1],score:[20,10],tries:[2,1]}],franceMode:{version:1,catalogue:'france-territories-2026-10-31-v1',week:2,leagues:{elite:{members:[0,1]},accession:{members:[]}}}};const nativePress=(${press.factory.toString()})();`);
const before=run('JSON.stringify(S)');assert.equal(run("JSON.stringify(nativePress.project().journal.divisions[0].standings.map(x=>x.clubId))"),run("JSON.stringify(CDFranceCompetition.ranked(S,'elite').map(c=>c.id))"),'Classement presse et départage canonique identiques.');assert.equal(run('JSON.stringify(S)'),before);
run("S.franceMode=null;S.clubs[0].pf=30;S.clubs[0].pa=20;S.clubs[1].pf=50;S.clubs[1].pa=40;function ranked(){return [...S.clubs].sort((a,b)=>b.points-a.points||(b.pf-b.pa)-(a.pf-a.pa)||b.pf-a.pf||a.id-b.id)}");assert.equal(run("JSON.stringify(nativePress.project().journal.divisions[0].standings.map(x=>x.clubId))"),run('JSON.stringify(ranked().map(c=>c.id))'),'Départage historique par points marqués conservé.');
for(const variant of [1,2]){
 let found=false;
 for(let week=0;week<=34&&!found;week++)for(let club=0;club<30&&!found;club++){
  run(`S={season:1,round:${week},club:${club},morale:75,trust:70,live:null,clubs:Array.from({length:30},(_,id)=>({id,name:'Club '+id,points:0,played:0,pf:0,pa:0,players:[]})),history:[],franceMode:{version:1,catalogue:'france-territories-2026-10-31-v1',week:${week},leagues:{elite:{members:Array.from({length:14},(_,i)=>i)},accession:{members:Array.from({length:16},(_,i)=>i+14)}}}}`);
  const p=JSON.parse(run('JSON.stringify(nativePress.project())'));if(!p.conference.questions.some(q=>q.variant===variant))continue;found=true;
  ctx.payload={context:p.context,answers:p.conference.questions.map(q=>({questionId:q.id,answerId:'r1'}))};run("nativePress.execute('press_conference',payload);nativePress.validate(S)");const h=JSON.parse(run('JSON.stringify(nativePress.project().history)'));
  for(const q of p.conference.questions){const row=h.find(x=>x.id===q.id);assert.equal(row.question,q.question,'Question exacte conservée (variante'+q.variant+')');assert.equal(row.answer,q.answers[1].text);}
  const state=run('JSON.stringify(S)');run('S=JSON.parse('+JSON.stringify(state)+');nativePress.validate(S)');assert.equal(run('JSON.stringify(nativePress.project().history)'),JSON.stringify(h));
  run('delete S.pressConference.history[0].questionText;delete S.pressConference.history[0].answerText;nativePress.validate(S)');assert.equal(run('nativePress.project().history[0].question'),null,'Ancien libellé absent explicitement.');assert.equal(run('nativePress.project().history[0].answer'),null);
  for(const mutate of ["S.pressConference.history[0].questionText='x'.repeat(601);S.pressConference.history[0].answerText='ok'","S.pressConference.history[0].questionText='ok';delete S.pressConference.history[0].answerText","S.pressConference.history[0].questionText=3;S.pressConference.history[0].answerText='ok'"]){run('S=JSON.parse('+JSON.stringify(state)+')');run(mutate);assert.throws(()=>run('nativePress.validate(S)'),/presse|conférence/i);}
 }
 assert.ok(found,'Variante '+variant+' réellement préparée.');
}
const {createBridge}=require('../native/engine/worker.cjs');
for(const [club,variant] of [[1,1],[6,2]]){
 const root=fs.mkdtempSync(path.join(process.env.CD_PRESS_TEST_ROOT||require('node:os').tmpdir(),'cd-press-review-'));let b=createBridge({dataDir:root,seed:398,now:1700000000000}),n=0;
 const good=(command,payload={})=>{const r=b.handle({id:++n,command,payload});assert.equal(r.ok,true,command+': '+r.error);return r.model;};
 try{
  let m=good('new_career',{mode:'world-champ',club}),p=m.clubLife.press;assert.ok(p.conference.questions.some(q=>q.variant===variant));
  const asked=p.conference.questions;m=good('press_conference',{context:p.context,answers:asked.map(q=>({questionId:q.id,answerId:'r1'}))});
  const expected=asked.map(q=>({id:q.id,question:q.question,answer:q.answers[1].text})),quotes=model=>model.clubLife.press.history.map(({id,question,answer})=>({id,question,answer}));assert.deepEqual(quotes(m),expected);
  const text=good('export').meta.exportText;assert.deepEqual(quotes(good('import',{text})),expected);
  good('shutdown');b=createBridge({dataDir:root,now:1700000000000});assert.deepEqual(quotes(good('snapshot')),expected,'Vrais libellés repris variante'+variant);
  const old=JSON.parse(text);old.state.pressConference.history.forEach(h=>{delete h.questionText;delete h.answerText;});const raw=JSON.stringify(old.state);let hash=2166136261;for(let i=0;i<raw.length;i++)hash=Math.imul(hash^raw.charCodeAt(i),16777619);old.checksum=(hash>>>0).toString(16).padStart(8,'0');
  m=good('import',{text:JSON.stringify(old)});assert.ok(m.clubLife.press.history.every(h=>h.question===null&&h.answer===null),'Ancien export compatible sans fausse citation.');
 }finally{b.close();}
}
console.log('Revue presse : départages canoniques France/historique, variantes1/2 exactes, export/import/reprise du vrai worker et anciens libellés absents PASS.');

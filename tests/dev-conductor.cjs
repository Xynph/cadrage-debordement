'use strict';
const assert=require('node:assert/strict');
const {lane,overlap,select,report,statusCI,attachCI,gateNumber}=require('../ci/dev-conductor.cjs');
const base=(number,files,opts={})=>({number,title:'PR '+number,files,head:{sha:'a'.repeat(40)},base:{ref:'main'},state:'open',draft:false,mergeable:true,mergeable_state:'clean',...opts});
assert.deepEqual(lane(['modding/data06/rugby-master-2026-2027.json']),['DATA']);
assert.deepEqual(lane(['dist/press-question-bank.js','dist/saves.js']),['V60']);
assert.deepEqual(lane(['ci/dev-conductor.cjs','tests/dev-conductor.cjs']),['CI']);
assert.deepEqual(overlap(['a','b'],['b','c']),['b']);
const p=select([base(4,['modding/data06/master.json']),base(2,['modding/data06/master.json']),base(3,['dist/index.html'])]);
assert.deepEqual(p.map(x=>x.number),[2,3,4]);
assert.deepEqual(p[0].conflicts,[{pr:4,files:['modding/data06/master.json']}]);
assert.deepEqual(p[1].conflicts,[]);
assert.equal(p[0].sensitive,true);
assert.match(p[0].next,/Coordonner/);
assert.match(p[2].next,/Coordonner/);
assert.match(p[1].next,/Contrôler CI/);
assert.match(report(p),/Aucune fusion/);
const draft=select([base(5,['docs/x.md'],{draft:true})])[0];
assert.equal(draft.ready,false);
assert.match(draft.next,/draft/);
const stacked=select([base(6,['dist/file.js'],{base:{ref:'feature/another'}})])[0];
assert.match(stacked.next,/dépendance/);
assert.throws(()=>select([{number:0,files:[]}]),/invalides/);
assert.throws(()=>lane([null]),/Chemin invalide/);

// Le tableau donne une preuve informative uniquement sur le HEAD exact.
const sha='a'.repeat(40), old='b'.repeat(40);
const run=(head_sha,id=101)=>({id,head_sha,event:'pull_request',name:'Tests JavaScript',
  path:'.github/workflows/tests.yml',status:'completed',conclusion:'success',created_at:'2026-11-03T12:00:00Z'});
const green=require('../ci/ci-jobs.cjs').OFFICIAL_JOBS
  .map(name=>({name,status:'completed',conclusion:'success'}));
assert.equal(statusCI(sha,[run(old)],{101:green}),'CI absente sur HEAD');
assert.equal(statusCI(sha,[run(sha)],{101:green}),'12/12 SUCCESS (gate non exécuté)');
assert.equal(statusCI(sha,[run(sha)],{}),'Jobs CI non vérifiés');
assert.equal(statusCI(sha,[{...run(sha),status:'in_progress'}],{}),'CI en cours');
assert.equal(statusCI(sha,[{...run(sha),conclusion:'failure'}],{}),'CI échouée ou annulée');
assert.equal(statusCI(sha,[run(sha)],{101:green.slice(0,11)}),'CI incomplète ou non conforme');
assert.equal(statusCI(sha,[run(sha)],{101:[...green,green[0]]}),'CI incomplète ou non conforme');
assert.equal(statusCI('bad',[],{}),'SHA invalide');
const rich=attachCI(select([base(7,['docs/readme.md'])]),[run(sha)],()=>green);
assert.match(rich[0].ci,/12\/12 SUCCESS/);
assert.match(report(rich),/12\/12 SUCCESS/);

assert.equal(gateNumber('259'),259);
assert.throws(()=>gateNumber('0'),/invalide/);
assert.throws(()=>gateNumber('259 --merge'),/invalide/);
assert.throws(()=>gateNumber('1;echo hacked'),/invalide/);
assert.throws(()=>gateNumber(''),/invalide/);
assert.throws(()=>gateNumber('99999999999999'),/invalide/);
console.log('dev-conductor : sélection, CI SHA exact et précontrôle officiel sûrs');

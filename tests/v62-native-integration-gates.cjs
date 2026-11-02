'use strict';
// V62 — barrières de raccordement : vrais modules main + modules candidats exclusivement lus.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const root=path.resolve(__dirname,'../dist'),read=n=>fs.readFileSync(path.join(root,n+'.js'),'utf8');
const ai=require('../dist/club-ai.js'),coach=require('../dist/coach-market.js');
const tests=[];function test(name,fn){fn();tests.push(name);}
test('module IA de main execute',()=>{const result=ai.decideClub({cash:1000000,wageRoom:50000,needs:['9'],candidates:[{id:'a',pos:'9',rating:85,fee:100000,wage:10000}]});assert.equal(result.action,'scout');assert.equal(result.candidate.id,'a');});
test('IA refuse une signature hors budget',()=>{const result=ai.decideClub({cash:100000,wageRoom:500,needs:['9'],candidates:[{id:'a',pos:'9',rating:85,fee:100000,wage:10000}]});assert.equal(result.candidate,null);});
test('marche V48 natif : seuil de confiance',()=>{const r=coach.dismissalRisk({confidence:10,consecutiveLosses:5});assert.equal(r.critical,true);});
test('marche V48 natif : poste disponible',()=>{const r=coach.jobOffers([{id:'A',vacant:true,budget:100,reputation:50}],{salary:60,reputation:50});assert.equal(r[0].clubId,'A');});
test('V42 contient deja les mecanismes de confiance',()=>{const s=read('career-integration');assert.match(s,/boardHistory/);assert.match(s,/lastBoardRound/);});
test('V46-V51 effectifs et finances deja integres',()=>{const s=read('world-career');assert.match(s,/function worldFacilityQuote/);assert.match(s,/function worldUpgradeFacility/);assert.match(s,/ledgerEntry/);});
test('sauvegarde native refuse les identifiants malformes',()=>{const code=read('saves'),context=vm.createContext({});vm.runInContext(code,context,{timeout:3000});assert.equal(vm.runInContext('saveId("club-42")',context),true);assert.equal(vm.runInContext('saveId("club <42>")',context),false);});
test('sauvegarde native rejette la corruption JSON',()=>{const context=vm.createContext({});vm.runInContext(read('saves'),context,{timeout:3000});assert.throws(()=>vm.runInContext('safeTree({x:"<script>"})',context));assert.equal(vm.runInContext('safeTree({x:"club-42",season:2})',context),undefined);});
test('sauvegarde native rejette valeurs non finies',()=>{const context=vm.createContext({});vm.runInContext(read('saves'),context,{timeout:3000});assert.equal(vm.runInContext('saveNumber(Infinity)',context),false);assert.equal(vm.runInContext('saveInt(-2)',context),false);});
const report={kind:'native modules with isolated vm, not real saved career',passed:tests.length,tests,riskFlags:['V61 vs V42 double board trust','V58 vs V48 dual coach ownership','V60 vs V42 double board pressure','V58 salary vs native ledger double charge','new fields vs save validator'],noChangesTo:'dist/saves.js or shared game scripts'};
if(process.env.CD_V62_REPORT)fs.writeFileSync(process.env.CD_V62_REPORT,JSON.stringify(report,null,2)+'\n');
console.log('V62 NATIVE INTEGRATION GATES PASS '+JSON.stringify(report));

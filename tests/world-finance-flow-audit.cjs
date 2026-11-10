'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const {reconcile,upkeep}=require('../native/engine/world-finance-flow-audit.cjs');
const COVERAGE_CLUB=14;
function withCoverageFixture(bridge){
 const handle=bridge.handle.bind(bridge);
 bridge.handle=request=>{
  const response=handle(request);
  if(request.command!=='new_career'||!response.ok)return response;
  const exported=handle({id:'finance-coverage-export',command:'export',payload:{}});
  assert.equal(exported.ok,true,exported.error);
  const document=JSON.parse(exported.model.meta.exportText);
  const club=document.state.clubs.find(c=>c.id===COVERAGE_CLUB);
  assert.ok(club&&club.id!==document.state.club&&club.players.length>0);
  // Explicit imported unavailability forces real AI coverage, independently
  // of the starting roster depth and current position qualifications.
  for(const player of club.players)player.injury=2;
  const state=JSON.stringify(document.state);
  let checksum=2166136261;
  for(let i=0;i<state.length;i++)checksum=Math.imul(checksum^state.charCodeAt(i),16777619);
  document.checksum=(checksum>>>0).toString(16).padStart(8,'0');
  const imported=handle({id:'finance-coverage-import',command:'import',payload:{text:JSON.stringify(document)}});
  assert.equal(imported.ok,true,'Availability fixture: '+imported.error);
  return {...imported,id:request.id};
 };
 return bridge;
}
// The source-order receipt is deliberately scoped to the legacy v1 initializer.
// Execute the genuine worker/core in an isolated dist fixture; production stays v2.
function coverageWorkerAudit(t,legacy=true){
 const fs=require('node:fs'),path=require('node:path'),os=require('node:os'),Module=require('node:module');
 const worker=require('../native/engine/worker.cjs'),dist=fs.mkdtempSync(path.join(os.tmpdir(),'cd-finance-v1-fixture-'));
 t.after(()=>fs.rmSync(dist,{recursive:true,force:true}));
 for(const file of worker.CORE_FILES){const target=path.join(dist,file);fs.mkdirSync(path.dirname(target),{recursive:true});let text=fs.readFileSync(path.join(__dirname,'../dist',file),'utf8');
  if(legacy&&file==='ai-roster-cycle.js')text+='\nconst fixtureBaseAiSetup=aiRosterSetup;aiRosterSetup=function(){const result=fixtureBaseAiSetup();if(S?.aiRoster){S.aiRosterVersion=1;S.aiRoster.version=1;delete S.aiRoster.population;}return result;};\n';
  fs.writeFileSync(target,text);
 }
 const workerFile=require.resolve('../native/engine/worker.cjs'),historical=new Module(workerFile,module);
 historical.filename=workerFile;historical.paths=Module._nodeModulePaths(path.dirname(workerFile));
 // Freeze the pre-expansion conditions that produced the historical coverage events.
 const workerSource=fs.readFileSync(workerFile,'utf8');
 historical._compile(legacy?workerSource
  .replace('CDNativeAcademyGroups.start(S)','void 0')
  .replaceAll('nativeProfessionalDepth.fill(S);',''):workerSource,workerFile);
 const filename=path.join(__dirname,'../ci/world-finance-flow-audit.cjs'),m=new Module(filename,module);
 m.filename=filename;m.paths=Module._nodeModulePaths(path.dirname(filename));const normal=m.require.bind(m);
 m.require=id=>id==='../native/engine/worker.cjs'?{...historical.exports,createBridge:options=>withCoverageFixture(historical.exports.createBridge({...options,distDir:dist}))}:normal(id);
 m._compile(fs.readFileSync(filename,'utf8'),filename);return m.exports;
}

test('A real worker week reconciles stable and source-order payrolls; isolated wage counterfactual preserves RNG and results',t=>{
  const r=coverageWorkerAudit(t).run({seed:827381,weeks:1,club:0});
  assert.equal(r.passed,true);assert.equal(r.weeks[0].ai.clubs,57);
  const explained=r.weeks[0].rows.filter(x=>x.kind==='ai'&&x.status==='reconciled-source-order');
  assert.deepEqual(explained.map(x=>x.clubId),[COVERAGE_CLUB]);
  const addedWages=explained.flatMap(row=>row.addedPlayers).reduce((total,player)=>total+player.weeklyWage,0);
  assert.ok(addedWages>0,'Actual coverage signings must change the billed payroll');
  assert.equal(r.weeks[0].ai.reconciled,56);assert.equal(r.weeks[0].ai.openingPayrollResidual,-addedWages);assert.equal(r.weeks[0].ai.residual,0);
  assert.equal(r.weeks[0].ai.unknown,0);
  assert.equal(r.weeks[0].billingReplay.matched,57);
  for(const row of explained){assert.equal(row.payrollStable,false);assert.equal(row.residualAtClosingPayroll,0);assert.equal(row.residual,-row.payrollDelta);}
  assert.equal(r.weeks[0].rows.find(x=>x.kind==='human-ledger').status,'reconciled-ledger');
  assert.equal(r.counterfactual.cashDeltaDifference,-1000);assert(r.counterfactual.duplicateWeekRefused);
});
test('Coverage explanation cannot escape its source-order window, evidence or exact residual',()=>{
  const a={season:1,round:0,phase:'league',club:0,history:[],ledger:[],worldMode:{version:1},aiRosterVersion:1,aiRoster:{version:1,events:[]},
    worldManagement:{clubInfo:[{id:0,facilities:2},{id:1,facilities:2}]},clubs:[{id:0,cash:100,players:[]},{id:1,cash:100,players:[{id:'old',salary:1000}]}]};
  const b=structuredClone(a);b.round=1;b.clubs[1].players.push({id:'new',salary:2000});b.clubs[1].cash+=160000-3000;
  b.aiRoster.events.push({season:1,clubId:1,kind:'emergency',playerId:'new',salary:2000,fee:0});
  assert.equal(reconcile(a,b).rows[1].status,'reconciled-source-order');
  b.clubs[1].cash++;assert.equal(reconcile(a,b).rows[1].status,'unknown');b.clubs[1].cash--;
  b.aiRoster.events[0].fee=1;assert.equal(reconcile(a,b).rows[1].status,'unknown');b.aiRoster.events[0].fee=0;
  a.round=12;b.round=13;assert.equal(reconcile(a,b).rows[1].status,'unknown','trading week remains unknown');
});
test('Unexplained cash or payroll changes remain unknown, never attributed to a made-up flow',()=>{
  const a={season:1,round:0,club:0,history:[],ledger:[],worldMode:{version:1},worldManagement:{clubInfo:[{id:0,facilities:2},{id:1,facilities:3}]},clubs:[{id:0,cash:100,players:[{id:'a',salary:1}]},{id:1,cash:100,players:[{id:'b',salary:2000}]}]};
  const b=structuredClone(a);b.round=1;b.clubs[1].cash+=160000-2000-upkeep(3)+999;
  const row=reconcile(a,b).rows[1];assert.equal(row.residual,999);assert.equal(row.status,'unknown');
  b.clubs[1].cash-=999;b.clubs[1].players[0].salary++;
  assert.equal(reconcile(a,b).rows[1].status,'unknown');
  b.season++;assert.throws(()=>reconcile(a,b),/no interseason/);
});

test('V2 coverage changes remain unknown to the deliberately v1-only source-order receipt',t=>{
 const r=coverageWorkerAudit(t,false).run({seed:827381,weeks:1,club:0});assert.equal(r.passed,true);
 const changed=r.weeks[0].rows.filter(row=>row.kind==='ai'&&!row.payrollStable);
 assert.ok(changed.length>0,'real v2 fixture exercises coverage additions');
 assert.deepEqual(changed.map(row=>row.clubId),[COVERAGE_CLUB]);
 assert.ok(changed[0].addedPlayers.length>0&&changed[0].payrollDelta>0);
 assert.ok(changed.every(row=>row.sourceOrderVerified===false&&row.status==='unknown'));
 assert.equal(r.weeks[0].ai.explainedSourceOrder,0,'no v2 source-order claim without a separate receipt');
});

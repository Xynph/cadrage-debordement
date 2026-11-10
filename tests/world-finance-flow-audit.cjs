'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const {reconcile,upkeep}=require('../native/engine/world-finance-flow-audit.cjs');
// Historical coverage fixtures predate specialist depth, academy groups and
// emergency out-of-position eligibility. Both execute the genuine worker/core;
// only v1 may claim the source-order receipt. Production stays unchanged.
function coverageWorkerAudit(t,version){
 assert.ok([1,2].includes(version));
 const fs=require('node:fs'),path=require('node:path'),os=require('node:os'),Module=require('node:module');
 let fillCalls=0,lastRoster=null,beforeClose=null;
 const worker=require('../native/engine/worker.cjs'),dist=fs.mkdtempSync(path.join(os.tmpdir(),'cd-finance-coverage-fixture-'));
 t.after(()=>fs.rmSync(dist,{recursive:true,force:true}));
 for(const file of worker.CORE_FILES){const target=path.join(dist,file);fs.mkdirSync(path.dirname(target),{recursive:true});let text=fs.readFileSync(path.join(__dirname,'../dist',file),'utf8');
  if(version===1&&file==='ai-roster-cycle.js')text+='\nconst fixtureBaseAiSetup=aiRosterSetup;aiRosterSetup=function(){const result=fixtureBaseAiSetup();if(S?.aiRoster){S.aiRosterVersion=1;S.aiRoster.version=1;delete S.aiRoster.population;}return result;};\n';
  fs.writeFileSync(target,text);
 }
 const workerFile=require.resolve('../native/engine/worker.cjs'),historical=new Module(workerFile,module);
 historical.filename=workerFile;historical.paths=Module._nodeModulePaths(path.dirname(workerFile));
 // Stub the service where it enters the isolated VM, including calls generated
 // inside worldVm.bootstrap(). Removing worker call sites alone misses start().
 const source=fs.readFileSync(workerFile,'utf8'),depth='const nativeProfessionalDepth=(${professionalDepth.toString()})();';
 const positions='nativePositionAptitudes.installHooks();',vmEntry='const run=source=>';
 assert.equal(source.split(depth).length,2,'The isolated coverage fixture must replace exactly one depth service');
 assert.equal(source.split(positions).length,2,'The historical fixture must omit exactly one new position hook installation');
 assert.equal(source.split(vmEntry).length,2,'The fixture probe must enter exactly one worker VM');
 historical._compile(source
  .replace('CDNativeAcademyGroups.start(S)','void 0')
  .replace(positions,'')
  .replace(vmEntry,'ctx.nativeCoverageProbe=options.coverageProbe;'+vmEntry)
  .replace(depth,'const nativeProfessionalDepth={...(${professionalDepth.toString()})(),fill(state){nativeCoverageProbe(state?.clubs.map(c=>({id:c.id,players:c.players.length,depth:c.players.filter(p=>p.id.startsWith("depth-")).length})));},additions(){return []}};'),workerFile);
 const filename=path.join(__dirname,'../ci/world-finance-flow-audit.cjs'),m=new Module(filename,module);
 m.filename=filename;m.paths=Module._nodeModulePaths(path.dirname(filename));const normal=m.require.bind(m);
 m.require=id=>id==='../native/engine/worker.cjs'?{...historical.exports,createBridge:options=>{
  const bridge=historical.exports.createBridge({...options,distDir:dist,coverageProbe:roster=>{
   fillCalls++;lastRoster=roster?JSON.parse(JSON.stringify(roster)):null;
  }}),handle=bridge.handle;
  bridge.handle=request=>{
   if(request.command==='finish_round'&&beforeClose===null)beforeClose={fillCalls,rosters:lastRoster};
   return handle(request);
  };
  return bridge;
 }}:normal(id);
 m._compile(fs.readFileSync(filename,'utf8'),filename);
 return {run(options){return {...m.exports.run(options),coverageFixture:beforeClose};}};
}
function verifyCoverageFixture(report,version){
 const {fillCalls,rosters}=report.coverageFixture;
 assert.ok(fillCalls>0,'The no-op service received the real startup/command fill calls');
 assert.equal(rosters.length,58);
 assert.ok(rosters.some(c=>c.players<40),'The historical checkpoint predates the professional depth floor');
 assert.ok(rosters.every(c=>c.depth===0),'No specialist depth player entered the coverage fixture');
 console.log(JSON.stringify({fixture:'historical-coverage-v'+version,fillCalls,
  minimumRoster:Math.min(...rosters.map(c=>c.players)),maximumRoster:Math.max(...rosters.map(c=>c.players)),
  targets:rosters.filter(c=>[14,25,27].includes(c.id))}));
}

test('A real worker week reconciles stable and source-order payrolls; isolated wage counterfactual preserves RNG and results',t=>{
  const r=coverageWorkerAudit(t,1).run({seed:827381,weeks:1,club:0});
  verifyCoverageFixture(r,1);
  assert.equal(r.passed,true);assert.equal(r.weeks[0].ai.clubs,57);
  assert.equal(r.weeks[0].ai.reconciled,54);assert.equal(r.weeks[0].ai.openingPayrollResidual,-8000);assert.equal(r.weeks[0].ai.residual,0);
  const explained=r.weeks[0].rows.filter(x=>x.kind==='ai'&&x.status==='reconciled-source-order');
  assert.deepEqual(explained.map(x=>x.clubId),[14,25,27]);assert.equal(r.weeks[0].ai.unknown,0);
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
 const r=coverageWorkerAudit(t,2).run({seed:827381,weeks:1,club:0});assert.equal(r.passed,true);
 verifyCoverageFixture(r,2);
 const changed=r.weeks[0].rows.filter(row=>row.kind==='ai'&&!row.payrollStable);
 assert.ok(changed.length>0,'real v2 fixture exercises coverage additions');
 assert.ok(changed.every(row=>row.sourceOrderVerified===false&&row.status==='unknown'));
 assert.equal(r.weeks[0].ai.explainedSourceOrder,0,'no v2 source-order claim without a separate receipt');
});

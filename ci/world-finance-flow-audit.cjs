'use strict';
process.env.CD_MODES_HERITES='1'; // Anciens modes de carrière (non-Monde) : test à migrer vers le mode Monde.
const {settleClubMeetings}=require('../tests/helpers/club-meetings.cjs');
// Manual audit: short real weeks, no coefficients or production state changed.
const fs=require('node:fs'),path=require('node:path'),os=require('node:os'),crypto=require('node:crypto');
const assert=require('node:assert/strict'),{execFileSync}=require('node:child_process');
const {createBridge}=require('../native/engine/worker.cjs');
const {reconcile}=require('../native/engine/world-finance-flow-audit.cjs');
const sha=x=>crypto.createHash('sha256').update(typeof x==='string'||Buffer.isBuffer(x)?x:JSON.stringify(x)).digest('hex');
function counterfactual(state,results,closing=null) {
  const {context}=require('../tests/france-harness.cjs');
  const {bootstrap}=require('../native/engine/world-vm.cjs');
  const id=state.clubs.find(c=>c.id!==state.club).id;
  function variant(extra,closingRosters=false) {
    const h=context(901);
    h.ctx.nativeWorldRegistryText=JSON.stringify(require('../native/engine/world-registry.json'));
    h.run(bootstrap());h.ctx.auditState=structuredClone(state);h.ctx.auditResults=structuredClone(results);
    h.run('S=auditState');
    if(closingRosters){h.ctx.auditClosing=structuredClone(closing.clubs);h.run('for(const c of S.clubs)c.players=auditClosing.find(n=>n.id===c.id).players');}
    if(extra)h.run(`S.clubs.find(c=>c.id===${id}).players[0].salary+=1000`);
    const seed=h.seed(),sports=h.run('JSON.stringify({history:S.history,live:S.live,fixtures:S.worldMode.fixtures})');
    const cash=h.run(`S.clubs.find(c=>c.id===${id}).cash`);
    assert.equal(h.run('worldWeeklyEconomy(auditResults)'),true);
    assert.equal(h.seed(),seed,'financial application does not consume RNG');
    assert.equal(h.run('JSON.stringify({history:S.history,live:S.live,fixtures:S.worldMode.fixtures})'),sports,'sports and fixtures unchanged');
    const after=h.state(),snapshot=JSON.stringify(after);
    assert.equal(h.run('worldWeeklyEconomy(auditResults)'),false,'duplicate week refused');
    assert.equal(JSON.stringify(h.state()),snapshot,'no second payment, ledger or state mutation');
    assert.equal(h.seed(),seed);
    return {delta:after.clubs.find(c=>c.id===id).cash-cash,after,seed};
  }
  const base=variant(false),raised=variant(true);
  assert.equal(raised.delta-base.delta,-1000,'one extra 1000 wage reduces weekly cash by exactly 1000');
  // All other clubs and all non-financial state remain equal between variants.
  const normalized=structuredClone(raised.after),target=normalized.clubs.find(c=>c.id===id);
  target.cash+=1000;target.players[0].salary-=1000;
  assert.deepEqual(normalized,base.after);
  let billingReplay=null;
  if(closing){
    const replay=variant(false,true);
    const rows=state.clubs.filter(c=>c.id!==state.club).map(c=>({clubId:c.id,
      replayDelta:replay.after.clubs.find(n=>n.id===c.id).cash-c.cash,observedDelta:closing.clubs.find(n=>n.id===c.id).cash-c.cash}));
    billingReplay={matched:rows.filter(r=>r.replayDelta===r.observedDelta).length,clubs:rows.length,rows,
      note:'Actual worldWeeklyEconomy on isolated pre-week cash plus closing rosters. Timing interpretation additionally requires source-order receipt; match alone never proves timing.'};
  }
  return {clubId:id,extraWeeklyWages:1000,cashDeltaDifference:raised.delta-base.delta,
    rngUnchanged:true,sportsUnchanged:true,otherStateIdentical:true,duplicateWeekRefused:true,billingReplay,
    scope:'Isolated VM copy of a real worker checkpoint; executes actual worldWeeklyEconomy, not a second gameplay trajectory.'};
}
function run({seed=827381,weeks=3,club=0,out}={}) {
  assert(Number.isInteger(seed)&&seed>=0&&seed<=0xffffffff);assert(Number.isInteger(weeks)&&weeks>=1&&weeks<=3);
  assert(Number.isInteger(club)&&club>=0&&club<56);
  const root=fs.mkdtempSync(path.join(os.tmpdir(),'cd-finance-flows-')),profile=path.join(root,'PrototypeGodot');
  const report={schema:'world-finance-flows-v1',mode:'world',seed,club,node:process.version,
    source:execFileSync('git',['rev-parse','HEAD'],{cwd:path.join(__dirname,'..'),encoding:'utf8'}).trim(),
    sources:Object.fromEntries(['dist/world-career.js','dist/game.js','dist/facilities.js','dist/france-career.js','dist/ai-roster-cycle.js','dist/manager.js','native/engine/world-career.cjs','native/engine/worker.cjs',
      'native/engine/world-finance-flow-audit.cjs','ci/world-finance-flow-audit.cjs','tests/helpers/club-meetings.cjs','native/engine/club-meetings.cjs'].map(f=>[f,sha(fs.readFileSync(path.join(__dirname,'..',f)))])),
    now:1794178800000,policy:'Public worker commands; no training/recruitment/contract editing; mandatory press/medical/board decisions and necessary lineup/coverage public commands traced.',weeks:[],commands:[]};
  let b,serial=0,model;
  const go=(command,payload={})=>{const r=b.handle({id:++serial,command,payload});report.commands.push({command,payload,ok:r.ok});assert.equal(r.ok,true,command+': '+r.error);model=r.model;return model;};
  const exported=()=>{const text=go('export').meta.exportText;return {state:JSON.parse(text).state,sha256:sha(text)};};
  try {
    b=createBridge({dataDir:profile,seed,now:report.now});settleClubMeetings(go('new_career',{mode:'world',club}),go);
    for(let n=0;n<weeks;n++) {
      if(model.next) {
        if(!model.selection.valid)go('auto_lineup');
        if(!model.selection.valid)go('promote_cover',{confirmed:true});
        go('begin_match');go('delegate');
      }
      const before=exported(),privateBefore=sha(fs.readFileSync(path.join(profile,'donnees.json')));
      settleClubMeetings(go('finish_round'),go);const after=exported();
      const reconciliation=reconcile(before.state,after.state);
      const experiment=counterfactual(before.state,after.state.history.filter(r=>!before.state.history.some(p=>p.fixtureId===r.fixtureId)),after.state);
      for(const row of reconciliation.rows.filter(r=>r.status==='reconciled-source-order'))
        assert.equal(experiment.billingReplay.rows.find(r=>r.clubId===row.clubId).replayDelta,row.delta,'source-order explanation confirmed by actual financial function');
      report.weeks.push({beforeExportSha256:before.sha256,afterExportSha256:after.sha256,privateBeforeSha256:privateBefore,
        billingReplay:experiment.billingReplay,
        privateAfterSha256:sha(fs.readFileSync(path.join(profile,'donnees.json'))),...reconciliation});
      if(n===0){delete experiment.billingReplay;report.counterfactual=experiment;}
    }
    report.passed=true;
  } catch(error) {report.passed=false;report.failure=error.stack;throw error;}
  finally {
    b?.close();fs.rmSync(root,{recursive:true,force:true});
    if(out){fs.mkdirSync(path.dirname(path.resolve(out)),{recursive:true});fs.writeFileSync(out,JSON.stringify(report,null,2));}
  }
  return report;
}
if(require.main===module) {
  const args=process.argv.slice(2),o={};
  for(let i=0;i<args.length;i+=2){assert(args[i+1]!==undefined);const k={'--seed':'seed','--weeks':'weeks','--club':'club','--out':'out'}[args[i]];assert(k,'unknown argument');o[k]=k==='out'?args[i+1]:Number(args[i+1]);}
  assert(o.out,'explicit --out required');
  try{const r=run(o);console.log(JSON.stringify({passed:r.passed,source:r.source,weeks:r.weeks.map(w=>({week:w.week,...w.ai})),counterfactual:r.counterfactual}));}
  catch(error){console.error(error.stack);process.exitCode=1;}
}
module.exports={run,counterfactual};

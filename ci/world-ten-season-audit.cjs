'use strict';
const {settleClubMeetings}=require('../tests/helpers/club-meetings.cjs');
// Manual, deliberately outside tests/: genuine worker commands, no result injection.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const crypto = require('node:crypto');
const {execFileSync} = require('node:child_process');
const {createBridge} = require('../native/engine/worker.cjs');

function argumentsFor(argv) {
  const options = {seasons:10, budgetMs:1200000, club:0};
  for (let i=0;i<argv.length;i+=2) {
    assert(argv[i+1] !== undefined, 'value required for '+argv[i]);
    const key = {'--seed':'seed','--seasons':'seasons','--budget-ms':'budgetMs','--club':'club','--out':'out','--resume-profile':'resumeProfile','--prior-report':'priorReport'}[argv[i]];
    assert(key, 'unknown argument '+argv[i]);
    options[key] = ['out','resumeProfile','priorReport'].includes(key) ? path.resolve(argv[i+1]) : Number(argv[i+1]);
  }
  assert(Number.isInteger(options.seed) && options.seed>=0 && options.seed<=0xffffffff, 'explicit --seed uint32 required');
  assert(Number.isInteger(options.seasons)&&options.seasons>=1&&options.seasons<=10, '1–10 seasons');
  assert(Number.isInteger(options.club)&&options.club>=0&&options.club<56, 'playable world club required');
  assert(Number.isInteger(options.budgetMs)&&options.budgetMs>=1000, 'positive budget');
  assert(options.out, 'explicit --out required');
  assert(Boolean(options.resumeProfile)===Boolean(options.priorReport), 'resume profile and prior report required together');
  return options;
}
function checksum(state) {
  const text=JSON.stringify(state);let value=2166136261;
  for(let i=0;i<text.length;i++)value=Math.imul(value^text.charCodeAt(i),16777619);
  return (value>>>0).toString(16).padStart(8,'0');
}
function run(options) {
  const started=Date.now(),root=fs.mkdtempSync(path.join(os.tmpdir(),'cd-world-ten-season-'));
  const profile=path.join(root,'PrototypeGodot'),file=path.join(profile,'donnees.json');
  const currentHarnessSha=crypto.createHash('sha256').update(fs.readFileSync(__filename)).digest('hex');
  const report={schema:'world-ten-season-audit-v1',seed:options.seed,club:options.club,requestedSeasons:options.seasons,
    mode:'world',node:process.version,harnessSha256:currentHarnessSha,source:execFileSync('git',['rev-parse','HEAD'],{cwd:path.join(__dirname,'..'),encoding:'utf8'}).trim(),
    budgetMs:options.budgetMs,startedAt:new Date(started).toISOString(),status:'running',commands:0,annual:[],restarts:[],promotions:[],
    policy:'No training, recruitment, investment or contract changes; actual mandatory club meetings and auto_lineup/promote_cover needed to play; deterministic now; fictional money.'};
  let previousElapsed=0;
  try {
  if(options.priorReport) {
    const prior=JSON.parse(fs.readFileSync(options.priorReport,'utf8'));
    assert.equal(prior.seed,options.seed,'resume seed differs from original experiment');
    assert.equal(prior.club,options.club,'resume club differs');
    assert.equal(prior.mode,'world');
    assert.equal(prior.requestedSeasons,options.seasons,'requested season count changed during audit');
    assert.equal(prior.source,report.source,'source revision changed during audit');
    const rawProfile=fs.readFileSync(options.resumeProfile);
    assert(prior.checkpoint,'paired checkpoint receipt required');
    assert.equal(crypto.createHash('sha256').update(rawProfile).digest('hex'),prior.checkpoint.profileSha256,'checkpoint profile/report mismatch');
    const stored=JSON.parse(JSON.parse(rawProfile).store['bdt-v1']);
    assert.equal(stored.club,options.club,'checkpoint club changed');
    assert.equal(stored.worldMode?.version,1,'checkpoint edition changed');
    const position={season:stored.season,week:stored.round,phase:stored.phase};
    assert.deepEqual(position,prior.checkpoint.position,'checkpoint position mismatch');
    assert.equal(prior.position.season,stored.season);assert.equal(prior.position.week,stored.round);assert.equal(prior.position.phase,stored.phase);
    assert(!stored.live,'resume only at a completed weekly boundary');
    assert(prior.annual.every((row,index)=>row.season===index+1&&row.season<=stored.season&&(row.season<stored.season||stored.phase==='ended')),'annual evidence ahead of checkpoint');
    assert(stored.phase==='ended'?[stored.season-1,stored.season].includes(prior.annual.length):prior.annual.length===stored.season-1,'missing annual evidence before checkpoint');
    Object.assign(report,prior);
    report.harnessSha256=currentHarnessSha;report.budgetMs=options.budgetMs;
    previousElapsed=prior.elapsedMs;
    report.status='running';report.passed=false;
    if(prior.failure)report.failureHistory=(prior.failureHistory||[]).concat({status:prior.status,...prior.failure});
    delete report.failure;
    report.segments=(prior.segments||[{startedAt:prior.startedAt,budgetMs:prior.budgetMs,harnessSha256:prior.harnessSha256??null}]).concat({startedAt:new Date(started).toISOString(),budgetMs:options.budgetMs,harnessSha256:currentHarnessSha,from:prior.position});
    fs.mkdirSync(profile,{recursive:true});fs.copyFileSync(options.resumeProfile,file);
  }
  } catch(error) {fs.rmSync(root,{recursive:true,force:true});throw error;}
  let bridge,serial=0,model,lastCommand,lastPayload;
  const elapsed=()=>previousElapsed+Date.now()-started;
  function persist(checkpoint=false) {
    report.elapsedMs=elapsed();
    if(model)report.position={season:model.meta.season,week:model.meta.week,phase:model.meta.phase,league:model.meta.leagueId};
    fs.mkdirSync(path.dirname(options.out),{recursive:true});
    if(checkpoint&&fs.existsSync(file)) {
      const bytes=fs.readFileSync(file),state=JSON.parse(JSON.parse(bytes).store['bdt-v1']);
      assert(!state.live,'checkpoint requires completed weekly boundary');
      assert.equal(state.season,report.position.season);assert.equal(state.round,report.position.week);
      const profilePath=options.out+'.profile.json',reportPath=options.out+'.resume.json';
      report.checkpoint={profilePath,reportPath,profileSha256:crypto.createHash('sha256').update(bytes).digest('hex'),position:{season:state.season,week:state.round,phase:state.phase}};
      fs.writeFileSync(profilePath+'.tmp',bytes);fs.renameSync(profilePath+'.tmp',profilePath);
      fs.writeFileSync(reportPath+'.tmp',JSON.stringify(report,null,2));fs.renameSync(reportPath+'.tmp',reportPath);
    }
    fs.writeFileSync(options.out+'.tmp',JSON.stringify(report,null,2));fs.renameSync(options.out+'.tmp',options.out);
  }
  function go(command,payload={}) {
    lastCommand=command;lastPayload=payload;
    assert(Date.now()-started<options.budgetMs,'audit wall-clock budget exceeded before '+command);
    const response=bridge.handle({id:++serial,command,payload});report.commands++;
    assert.equal(response.ok,true,command+' @ '+JSON.stringify(report.position)+': '+response.error);
    model=response.model;return model;
  }
  function open(seed) {return createBridge({dataDir:profile,seed,now:1794178800000});}
  function exported() {
    const text=go('export').meta.exportText,doc=JSON.parse(text);
    assert.equal(doc.checksum,checksum(doc.state),'independent UTF-16 state integrity');
    assert.equal(doc.exportVersion,1);
    assert(Buffer.byteLength(text)<=16*1024*1024,'world v1 export limit');
    return {text,state:doc.state,bytes:Buffer.byteLength(text),sha256:crypto.createHash('sha256').update(text).digest('hex')};
  }
  function summary(checkpoint,label) {
    const s=checkpoint.state,leagues={};
    for(const [id,league] of Object.entries(s.worldMode.leagues)) {
      const clubs=league.members.map(cid=>s.clubs[cid]),players=clubs.flatMap(c=>c.players);
      const ages=players.map(p=>p.age).filter(Number.isFinite),cash=clubs.map(c=>c.cash),counts=clubs.map(c=>c.players.length);
      leagues[id]={clubs:clubs.length,players:players.length,rosterMin:Math.min(...counts),rosterMax:Math.max(...counts),
        cashTotal:cash.reduce((a,b)=>a+b,0),cashMin:Math.min(...cash),cashMax:Math.max(...cash),negativeCashClubs:cash.filter(x=>x<0).length,
        weeklyWages:players.reduce((a,p)=>a+(p.salary||0),0),observedAge:ages.length,ageMin:ages.length?Math.min(...ages):null,ageMax:ages.length?Math.max(...ages):null,ageMean:ages.length?ages.reduce((a,b)=>a+b,0)/ages.length:null,
        unknownAge:players.length-ages.length,injured:players.filter(p=>p.injury>0).length,uninjured:players.filter(p=>!(p.injury>0)).length,
        contractsExpiring:players.filter(p=>Number.isFinite(p.contractEnd)&&p.contractEnd<=s.season).length,champion:league.champion};
      assert(cash.every(Number.isFinite),'cash must remain finite');
      // Age is an observation, not an invented eligibility limit.
      leagues[id].ageBelow16=ages.filter(a=>a<16).length;
      leagues[id].ageAbove40=ages.filter(a=>a>40).length;
    }
    const european={};
    for(const [id,cup] of Object.entries(s.worldMode.europe)) {
      const entries=cup.pools.flat();assert.equal(new Set(entries).size,entries.length,id+' duplicate entrant');
      european[id]={entries:entries.length,champion:cup.champion,unique:true};
    }
    const all=s.clubs.flatMap(c=>c.players.map(p=>p.id));assert.equal(new Set(all).size,all.length,'active player duplicate');
    return {label,season:s.season,week:s.round,phase:s.phase,elapsedMs:elapsed(),leagues,european,
      totalCash:s.clubs.reduce((a,c)=>a+c.cash,0),activePlayers:all.length,freeMarketPlayers:s.market.length,
      freeMarketUnique:new Set(s.market.map(p=>p.id)).size,fixtures:s.worldMode.fixtures.length,results:s.history.length,
      ownSheet:{valid:model.selection.valid,errors:model.selection.errors},exportBytes:checkpoint.bytes,exportSha256:checkpoint.sha256};
  }
  function restart(checkpoint) {
    const before=JSON.parse(fs.readFileSync(file));go('shutdown');bridge=open((options.seed+12345)>>>0);
    const after=exported();assert.equal(after.text,checkpoint.text,'restart exact public export');
    const disk=JSON.parse(fs.readFileSync(file));assert.deepEqual(disk,before,'restart private state, RNG and clock exact');
    report.restarts.push({season:checkpoint.state.season,exportIdentical:true,privateProfileIdentical:true,seed:disk.seed,clock:disk.clock});
  }
  try {
    bridge=open(options.seed);
    if(options.resumeProfile) {
      go('snapshot');
      const source=JSON.parse(fs.readFileSync(options.resumeProfile,'utf8'));
      const sourceState=JSON.parse(source.store['bdt-v1']);
      const resumed=exported();
      assert.deepEqual(resumed.state,sourceState,'resume exact career state');
      assert.deepEqual(JSON.parse(fs.readFileSync(file)),source,'resume exact private RNG/clock/profile');
      report.resumptions=(report.resumptions||[]).concat({season:sourceState.season,week:sourceState.round,stateIdentical:true,privateProfileIdentical:true,exportSha256:resumed.sha256});
    } else {
      settleClubMeetings(go('new_career',{mode:'world',club:options.club}),go);
      report.initial=summary(exported(),'initial');
    }
    // Exact resume assertions above precede the real mandatory decisions.
    settleClubMeetings(model,go);persist(true);
    for(let season=model.meta.season;season<=options.seasons;season++) {
      assert.equal(model.meta.season,season);
      const seasonStarted=report.annual.at(-1)?.elapsedMs??report.initial.elapsedMs;
      for(let week=model.meta.week;week<46;week++) {
        assert.equal(model.meta.week,week);
        if(model.live) {
          if(!model.live.finished)go('delegate');
        } else if(model.next) {
          if(!model.selection.valid)go('auto_lineup');
          if(!model.selection.valid) {
            const reason=model.selection.errors.slice();go('promote_cover',{confirmed:true});
            report.promotions.push({season,week,reason,coverage:model.meta.coverage??null});
          }
          assert.equal(model.selection.valid,true,'qualified user sheet required');
          go('begin_match');go('delegate');
        }
        settleClubMeetings(go('finish_round'),go);assert.equal(model.meta.week,week+1);persist(true);
      }
      const end=exported();assert.equal(end.state.phase,'ended');
      assert.equal(end.state.history.length,end.state.worldMode.fixtures.length,'all actual seasonal fixtures completed');
      const row=summary(end,'end');row.seasonElapsedMs=elapsed()-seasonStarted;if(!report.annual.some(r=>r.season===season))report.annual.push(row);
      if(season===1)report.projectedTenSeasonsMs=row.seasonElapsedMs*10;
      if(season===5||season===10)restart(end);
      console.log(JSON.stringify({season,elapsedMs:elapsed(),seasonElapsedMs:row.seasonElapsedMs,totalCash:row.totalCash,players:row.activePlayers,bytes:row.exportBytes}));persist(true);
      if(season<options.seasons) {
        settleClubMeetings(go('next_season',{confirmed:true}),go);assert.equal(model.meta.season,season+1);
        const next=exported();assert.equal(next.state.history.length,0);
        assert.equal(next.state.worldMode.qualification.champions.length,24);
        assert.equal(next.state.worldMode.qualification.challenge.length,18);
        assert.equal(next.state.worldMode.yearbook.length,season);
      }
    }
    assert.equal(report.annual.length,options.seasons,'all requested annual records required');
    report.status='completed';report.completedSeasons=report.annual.length;report.passed=true;
  } catch(error) {
    report.status='failed';report.passed=false;report.completedSeasons=report.annual.length;
    report.failure={command:lastCommand,payload:lastPayload,position:report.position,error:error.stack||String(error)};
    report.failureHistory=(report.failureHistory||[]).concat({status:'failed',...report.failure});
    console.error(JSON.stringify(report.failure));process.exitCode=1;
  } finally {
    bridge?.close();
    if(report.status==='failed'&&report.checkpoint?.reportPath&&fs.existsSync(report.checkpoint.reportPath)) {
      const receipt=JSON.parse(fs.readFileSync(report.checkpoint.reportPath,'utf8'));
      receipt.failureHistory=report.failureHistory;receipt.status='recoverable-checkpoint';
      fs.writeFileSync(report.checkpoint.reportPath+'.tmp',JSON.stringify(receipt,null,2));
      fs.renameSync(report.checkpoint.reportPath+'.tmp',report.checkpoint.reportPath);
    }
    report.finishedAt=new Date().toISOString();persist();fs.rmSync(root,{recursive:true,force:true});
  }
  return report;
}
if(require.main===module){try{run(argumentsFor(process.argv.slice(2)));}catch(error){console.error(error.stack);process.exitCode=1;}}
module.exports={run,argumentsFor};

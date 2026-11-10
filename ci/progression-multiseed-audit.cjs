'use strict';
const {settleClubMeetings}=require('../tests/helpers/club-meetings.cjs');
// Manual experiment, outside the long CI path. Policies see only public models.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),os=require('node:os'),crypto=require('node:crypto'),{execFileSync}=require('node:child_process');
const {createBridge,CORE_FILES}=require('../native/engine/worker.cjs');
const SEEDS=Object.freeze([827381,318,52602]),NOW=1794178800000;
const copy=x=>JSON.parse(JSON.stringify(x)),hash=x=>crypto.createHash('sha256').update(x).digest('hex');
function freeze(x){if(x&&typeof x==='object'&&!Object.isFrozen(x)){Object.values(x).forEach(freeze);Object.freeze(x);}return x;}
function publicModel(model){const m=copy(model);if(m.meta)delete m.meta.exportText;return freeze(m);}
function quantiles(values){const a=values.filter(Number.isFinite).slice().sort((x,y)=>x-y),at=q=>a.length?a[Math.max(0,Math.ceil(a.length*q)-1)]:null;return {n:a.length,q25:at(.25),median:at(.5),q75:at(.75)};}
function initialBand(age){return !Number.isFinite(age)?'unknown':age<=23?'<=23':age<=29?'24-29':'>=30';}
function category(title){if(/Financement de début de saison/i.test(title))return'financing';if(/salaire/i.test(title))return'wages';if(/partenaire|sponsor/i.test(title))return'sponsorship';if(/billetterie/i.test(title))return'gate';if(/entretien|amortissement/i.test(title))return'maintenance';if(/prime de victoire/i.test(title))return'victoryBonus';if(/prolongation|signature/i.test(title))return'contractFees';if(/transfert|vente/i.test(title))return'transfers';if(/investissement|aménagement|travaux|construction/i.test(title))return'investments';return'other';}
function ledgerDelta(before,after){
 const a=before||[],b=after||[];let overlap=0;
 for(let n=Math.min(a.length,b.length);n>=0;n--)if(JSON.stringify(b.slice(b.length-n))===JSON.stringify(a.slice(0,n))){overlap=n;break;}
 return b.slice(0,b.length-overlap);
}
function validateAction(action,allowed){assert(action&&typeof action==='object'&&!Array.isArray(action),'policy action object required');assert(allowed.includes(action.command),'unsafe policy command');assert(action.payload&&typeof action.payload==='object'&&!Array.isArray(action.payload),'policy payload required');assert(typeof action.reason==='string'&&action.reason.length<=2000,'bounded policy reason required');return action;}
function sourceManifest(){
 const root=path.join(__dirname,'..'),files=['tests/helpers/club-meetings.cjs',...CORE_FILES.map(f=>path.join('dist',f)),...fs.readdirSync(path.join(root,'native/engine')).filter(f=>/\.(cjs|json)$/.test(f)).map(f=>'native/engine/'+f)].sort();
 return {commit:execFileSync('git',['rev-parse','HEAD'],{cwd:root,encoding:'utf8'}).trim(),digest:hash(files.map(f=>f+'\0'+hash(fs.readFileSync(path.join(root,f)))).join('\n')),runnerHash:hash(fs.readFileSync(__filename)),policiesHash:hash(fs.readFileSync(path.join(__dirname,'progression-policies.cjs')))};
}
function argumentsFor(argv){const o={policy:null,seed:null,mode:'world',club:0,seasons:2,budgetMs:1200000};for(let i=0;i<argv.length;i+=2){const key={'--seed':'seed','--policy':'policy','--mode':'mode','--club':'club','--seasons':'seasons','--budget-ms':'budgetMs','--out':'out'}[argv[i]];assert(key&&argv[i+1]!==undefined,'argument/value required: '+argv[i]);o[key]=['policy','mode','out'].includes(key)?argv[i+1]:Number(argv[i+1]);}assert(SEEDS.includes(o.seed),'one preregistered seed required');assert(['minimal','attentive'].includes(o.policy),'minimal or attentive policy required');assert.equal(o.mode,'world','paired design fixed to world');assert.equal(o.club,0,'paired design fixed to club 0');assert.equal(o.seasons,2,'two seasons required');assert(Number.isInteger(o.budgetMs)&&o.budgetMs>=1000,'positive budget');assert(o.out,'explicit --out required');o.out=path.resolve(o.out);assert(!fs.existsSync(o.out),'output already exists');return o;}
function cohortRecords(state,baseline){
 const found=new Map(),add=(p,status,clubId=null)=>{if(!found.has(p.id))found.set(p.id,{id:p.id,status,clubId,age:p.age??null,rating:p.rating??null,minutes:p.dev?.minutes??null,careerMinutes:p.dev?.careerMinutes??null});};
 for(const c of state.clubs)for(const p of c.players)add(p,c.id===state.club?'own':'other-professional',c.id);
 for(const p of state.development?.academy||[])add(p,'academy',state.club);for(const a of state.aiRoster?.academies||[])for(const p of a.players)add(p,'academy',a.clubId);
 for(const p of state.economy?.freeAgents||[])add(p,'free-agent');for(const p of state.market||[])add(p,'market');
 for(const p of state.development?.retired||[])if(!found.has(p.id))found.set(p.id,{id:p.id,status:'retired',age:p.age??null,rating:null});
 return baseline.map(p=>({...found.get(p.id)||{id:p.id,status:'untracked',rating:null,age:null},initialAge:p.age,initialAgeBand:initialBand(p.age),initialRating:p.rating}));
}
function observation(state,model,label,baseline){
 const own=state.clubs[state.club],byId=new Map(model.squad.map(p=>[p.id,p])),league=model.league||[],rank=league.findIndex(c=>c.id===state.club)+1,row=league.find(c=>c.id===state.club),xv=model.lineup.map(id=>byId.get(id)?.note).filter(Number.isFinite);
 const players=own.players.map(p=>({id:p.id,age:p.age,rating:p.rating,note:byId.get(p.id)?.note??null,potential:byId.get(p.id)?.potential??null,salary:p.salary,contractEnd:p.contractEnd??null,minutes:p.dev?.minutes??null,careerMinutes:p.dev?.careerMinutes??null,initialAgeBand:initialBand(baseline.find(b=>b.id===p.id)?.age)}));
 return {label,season:state.season,week:state.round,phase:label==='initial'?'initial':label.startsWith('end-')?'end':'opening',results:state.history.length,club:{id:state.club,division:model.meta.leagueId,rank:rank||null,unresolvedTie:!!row?.unresolvedTie,leagueSize:league.length,rankPercentile:rank&&league.length>1?(league.length-rank)/(league.length-1):null,points:row?.points??null,played:row?.played??null,pointsPerMatch:row?.played?row.points/row.played:null,scoreDifferencePerMatch:row?.played?(row.pf-row.pa)/row.played:null,cash:own.cash,debt:Number.isFinite(state.worldManagement?.clubInfo?.find(c=>c.id===state.club)?.debt)?state.worldManagement.clubInfo.find(c=>c.id===state.club).debt:Number.isFinite(model.club?.debt)?model.club.debt:null,weeklyWages:own.players.reduce((n,p)=>n+p.salary,0),professionals:own.players.length},quality:{rating:quantiles(players.map(p=>p.rating)),age:quantiles(players.map(p=>p.age)),xvMeanNote:xv.length===15?xv.reduce((a,b)=>a+b,0)/15:null,xvObserved:xv.length,sheetValid:!!model.selection.valid},players,cohortRecords:cohortRecords(state,baseline)};
}
function validateReport(r){
 assert.equal(r.schema,'progression-multiseed-audit-v1');assert.equal(r.status,'completed');assert.equal(r.passed,true);assert(SEEDS.includes(r.seed));assert(['minimal','attentive'].includes(r.policy.id));assert.equal(r.requestedSeasons,2);assert.equal(r.completedSeasons,2);
 const digest=x=>typeof x==='string'&&/^[a-f0-9]{64}$/.test(x);assert(digest(r.initialHash)&&digest(r.initialProfileHash));assert(/^[a-f0-9]{40}$/.test(r.sources.commit));for(const key of ['digest','runnerHash','policiesHash'])assert(digest(r.sources[key]));assert.equal(r.policy.hash,r.sources.policiesHash);
 assert.deepEqual(r.observations.map(o=>o.label),['initial','end-S1','opening-S2','end-S2','opening-S3']);assert.deepEqual(r.observations.map(o=>o.season),[1,1,2,2,3]);assert.equal(r.annual.length,2);assert.equal(r.financialPeriods.length,2);
 for(let i=0;i<2;i++){const a=r.annual[i],f=r.financialPeriods[i];assert.equal(a.season,i+1);assert(Number.isInteger(a.fixtures)&&a.fixtures>0);assert.equal(a.results,a.fixtures);assert.equal(a.closingLabel,'end-S'+(i+1));assert.equal(a.transitionLabel,'opening-S'+(i+2));assert.equal(f.season,i+1);for(const k of ['cashOpening','cashClosing','cashAfterManagement','cashAfterTransition','minCash','unexplainedCash'])assert(Number.isFinite(f[k]));assert(Object.values(f.categories).every(Number.isFinite));assert(Math.abs(Object.values(f.categories).reduce((n,v)=>n+v,0)+f.unexplainedCash-(f.cashAfterTransition-f.cashOpening))<1e-6,'cash-flow conservation');assert(Number.isInteger(f.negativeWeeks)&&f.negativeWeeks>=0&&f.negativeWeeks<=46);assert(Number.isInteger(f.longestNegativeStreak)&&f.longestNegativeStreak>=0&&f.longestNegativeStreak<=f.negativeWeeks);}
 assert.equal(r.reopened,true);assert.deepEqual(r.restarts.map(x=>x.label),['end-S1','end-S2','opening-S3']);assert(r.restarts.every(x=>x.publicExact&&x.privateExact&&digest(x.stateHash)&&digest(x.profileHash)));return true;
}
function run(o){
 const P=require('./progression-policies.cjs'),controller=P.createPolicy(o.policy),sources=sourceManifest(),started=Date.now(),root=fs.mkdtempSync(path.join(os.tmpdir(),'cd-progression-multiseed-')),file=path.join(root,'PrototypeGodot/donnees.json');
 const report={schema:'progression-multiseed-audit-v1',status:'running',passed:false,seed:o.seed,policy:{id:o.policy,hash:sources.policiesHash,profile:copy(controller.profile)},sources,now:NOW,preregisteredSeeds:[...SEEDS],requestedSeasons:2,completedSeasons:0,node:process.version,commands:0,actions:[],observations:[],annual:[],financialPeriods:[],restarts:[],options:o};
 assert.equal(controller.sourceHash,sources.policiesHash,'cached policy source differs from disk');
 let bridge,model,serial=0,baseline,financial=null,weeklyMin=new Map();
 const persist=()=>{fs.mkdirSync(path.dirname(o.out),{recursive:true});report.elapsedMs=Date.now()-started;fs.writeFileSync(o.out,JSON.stringify(report,null,2));};
 function send(command,payload={},detail={kind:'harness'}){
  assert(Date.now()-started<o.budgetMs,'audit wall-clock budget exceeded');const before=model,reply=bridge.handle({id:++serial,command,payload});report.commands++;
  if(command!=='export'&&reply.model){model=reply.model;delete model.meta.exportText;}
  if(command!=='export'&&command!=='snapshot')report.actions.push({...copy(detail),command,payload:copy(payload),ok:reply.ok,error:reply.error??null,season:before?.meta.season??null,week:before?.meta.week??null,negotiation:copy(reply.model?.meta?.negotiation??null)});
  if(financial&&before?.club&&reply.model?.club&&command!=='export'){
   const entries=ledgerDelta(before.ledger,reply.model.ledger);for(const e of entries){assert(Number.isFinite(e.amount),'finite ledger amount');financial.categories[category(e.title)]+=e.amount;financial.ledgerEntries++;}
   const delta=reply.model.club.cash-before.club.cash;financial.unexplainedCash+=delta-entries.reduce((n,e)=>n+e.amount,0);financial.minCash=Math.min(financial.minCash,reply.model.club.cash);if(before.meta.season===financial.season&&before.meta.week<46){const w=before.meta.week;weeklyMin.set(w,Math.min(weeklyMin.get(w)??Infinity,reply.model.club.cash));}
  }
  return reply;
 }
 const go=(command,payload)=>{const r=send(command,payload);assert(r.ok,command+': '+r.error);return r.model;};
 const exported=()=>{const r=send('export');assert(r.ok,'export failed');return {text:r.model.meta.exportText,state:JSON.parse(r.model.meta.exportText).state};};
 const restart=(label)=>{const before=exported(),bytes=fs.readFileSync(file);go('shutdown');bridge=createBridge({dataDir:root,seed:1,now:1});const after=exported();assert.equal(after.text,before.text,'public reopen exact');assert(fs.readFileSync(file).equals(bytes),'private reopen exact');go('snapshot');report.restarts.push({label,publicExact:true,privateExact:true,stateHash:hash(JSON.stringify(after.state)),profileHash:hash(bytes)});};
 function phase(id){for(let i=0;i<controller.profile.maxActionsPerPhase;i++){const action=controller.nextAction(publicModel(model),id);if(!action)return;validateAction(action,P.commands);const r=send(action.command,action.payload,{kind:'policy',phase:id,reason:action.reason,evidence:action.evidence??{}});const receipt=controller.observe(action,publicReply(r));assert(!receipt?.critical,'critical policy refusal: '+(r.error||receipt?.outcome));}assert.equal(controller.nextAction(publicModel(model),id),null,'policy exceeded phase action cap');}
 function publicReply(reply){return freeze({...copy(reply),...(reply.model?{model:publicModel(reply.model)}:{})});}
 const checkpoint=(label)=>{const e=exported();report.observations.push(observation(e.state,model,label,baseline));persist();return e.state;};
 try{bridge=createBridge({dataDir:root,seed:o.seed,now:NOW});settleClubMeetings(go('new_career',{mode:o.mode,club:o.club}),go);const initial=exported();baseline=initial.state.clubs[initial.state.club].players.map(p=>({id:p.id,age:p.age,rating:p.rating}));report.initialHash=hash(JSON.stringify(initial.state));report.initialProfileHash=hash(fs.readFileSync(file));checkpoint('initial');
  for(let season=1;season<=2;season++){
   financial={season,cashOpening:model.club.cash,cashClosing:null,cashAfterManagement:null,cashAfterTransition:null,minCash:model.club.cash,negativeWeeks:0,longestNegativeStreak:0,categories:Object.fromEntries(['wages','sponsorship','gate','maintenance','victoryBonus','financing','contractFees','transfers','investments','other'].map(k=>[k,0])),ledgerEntries:0,unexplainedCash:0};weeklyMin=new Map();
   for(let week=0;week<46;week++){weeklyMin.set(week,model.club.cash);phase('before-week');if(model.next){phase('before-match');assert(model.selection.valid,'policy must provide a playable sheet');go('begin_match');go('delegate');}settleClubMeetings(go('finish_round'),go);assert.equal(model.meta.week,week+1);if(week%10===9){console.log(JSON.stringify({seed:o.seed,policy:o.policy,season,week:week+1,elapsedMs:Date.now()-started}));persist();}}
   const end=checkpoint('end-S'+season);assert.equal(end.phase,'ended');assert.equal(end.history.length,end.worldMode.fixtures.length);financial.cashClosing=model.club.cash;restart('end-S'+season);phase('after-season');financial.cashAfterManagement=model.club.cash;settleClubMeetings(go('next_season',{confirmed:true}),go);phase('transition');const next=checkpoint('opening-S'+(season+1));assert.equal(next.season,season+1);assert.equal(next.worldMode.yearbook.length,season);financial.cashAfterTransition=model.club.cash;
   let streak=0;for(let w=0;w<46;w++){if((weeklyMin.get(w)??financial.cashOpening)<0){financial.negativeWeeks++;streak++;financial.longestNegativeStreak=Math.max(financial.longestNegativeStreak,streak);}else streak=0;}
   report.financialPeriods.push(financial);financial=null;report.annual.push({season,openingLabel:season===1?'initial':'opening-S2',closingLabel:'end-S'+season,transitionLabel:'opening-S'+(season+1),results:end.history.length,fixtures:end.worldMode.fixtures.length});report.completedSeasons++;persist();
  }
  restart('opening-S3');report.reopened=true;report.policySummary=controller.summary();assert.deepEqual(sourceManifest(),sources,'sources changed during experiment');report.status='completed';report.passed=true;validateReport(report);
 }catch(e){report.status='failed';report.passed=false;report.failure={season:model?.meta.season,week:model?.meta.week,error:e.stack||String(e)};if(fs.existsSync(file)){report.failureProfile=o.out+'.failure-profile.json';fs.copyFileSync(file,report.failureProfile);}report.policySummary=controller.summary();throw e;}
 finally{bridge?.close();persist();fs.rmSync(root,{recursive:true,force:true});}
 return report;
}
if(require.main===module){try{run(argumentsFor(process.argv.slice(2)));}catch(e){console.error(e.stack);process.exitCode=1;}}
module.exports={SEEDS,NOW,argumentsFor,quantiles,initialBand,ledgerDelta,category,validateAction,publicModel,cohortRecords,observation,validateReport,run};

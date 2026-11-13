'use strict';
process.env.CD_MODES_HERITES='1'; // Anciens modes de carrière (non-Monde) : test à migrer vers le mode Monde.
// Bounded public-worker observations. Never edits engine, rosters, money, RNG,
// schedules or saved careers. Temporary profiles are copied then deleted; the
// live worker's process lock is excluded, never its saved data or RNG/clock.
const assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path'),crypto=require('node:crypto'),{execFileSync}=require('node:child_process');
const {createBridge}=require('../../native/engine/worker.cjs');
const {settleClubMeetings}=require('../../tests/helpers/club-meetings.cjs');
const ROOT=path.resolve(__dirname,'../..'),hash=value=>crypto.createHash('sha256').update(value).digest('hex');
const ALLOWED_CHECKPOINTS=[{seed:427,club:13},{seed:731,club:6},{seed:1299,club:0}],PREFERRED_FAMILIES=[2,6,4,1,3,5,7,8,0];
const selectedSeed=Number(process.argv.find(value=>value.startsWith('--checkpoint-seed='))?.slice(18));
assert.ok(ALLOWED_CHECKPOINTS.some(item=>item.seed===selectedSeed),'Choose exactly one bounded public checkpoint: --checkpoint-seed=427, 731 or 1299');
const CHECKPOINTS=ALLOWED_CHECKPOINTS.filter(item=>item.seed===selectedSeed);
const output=path.resolve(process.argv.find(value=>value.startsWith('--output='))?.slice(9)||'work/management-rival-comparison.json');
const report={schema:1,sourceSha:execFileSync('git',['rev-parse','HEAD'],{cwd:ROOT,encoding:'utf8'}).trim(),nodeVersion:process.version,scriptSha256:hash(fs.readFileSync(__filename)),checkpoints:[],checks:0,complete:false,
 method:'One explicit batch from three approved independent public Fiction careers; up to three publicly available positional families each; repeated negotiation, public-cash negative control, exact complete-profile forks and actual confirmed auctions.',
 limits:['Different checkpoints are not the same world or a causal experiment.','Only quoted positive need is observed; non-offers have no per-club reason.','Public coach reaction personality is not a tactical identity or evidence of recruitment motive.','No hidden player rating, potential, skill, condition or private decision score selects a target.','Full profiles and exported career states are never published.','This negotiated-release channel does not execute or qualify an autonomous transfer window.'],
 sourceFiles:Object.fromEntries(['native/engine/interclub-market.cjs','native/engine/model.cjs','native/engine/club-world.cjs','dist/ai-roster-cycle.js','tools/qa/management-rival-observation.cjs'].map(file=>[file,hash(fs.readFileSync(path.join(ROOT,file)))]))};
const check=(condition,message)=>{report.checks++;assert.ok(condition,message);};
const equal=(actual,expected,message)=>{report.checks++;assert.deepEqual(actual,expected,message);};
const started=Date.now(),directory=fs.mkdtempSync(path.join(os.tmpdir(),'rg27-rival-comparison-'));
function bridge(folder,seed){
 const backend=createBridge({dataDir:folder,seed,now:1794434400000});let serial=0,model;
 const commands=[];
 const send=(command,payload={})=>{check(Date.now()-started<120000,'The bounded collection remains within two minutes');const response=backend.handle({id:++serial,command,payload});check(response.ok,command+': '+response.error);commands.push({command,payload});return model=response.model;};
 return {send,commands,get model(){return model;},profile:()=>fs.readFileSync(path.join(folder,'PrototypeGodot','donnees.json')),stateHash:()=>hash(JSON.stringify(JSON.parse(send('export').meta.exportText).state)),close:()=>backend.close()};
}
function cashRows(model){
 const rows=[...(model.league||[]),...(model.leagues||[]).flatMap(league=>league.rows||[]),...(model.club?[model.club]:[])];
 return new Map(rows.filter(row=>Number.isFinite(row.cash)).map(row=>[row.id,{id:row.id,name:row.name,cash:row.cash}]));
}
function owners(model,id){
 return [...(model.squad||[]).filter(player=>player.id===id).map(player=>({clubId:model.club.id,salary:player.salary,contractEnd:player.contractEnd})),
  ...(model.clubLife?.interclubMarket?.candidates||[]).filter(player=>player.id===id).map(player=>({clubId:player.clubId,salary:player.sourceSalary,contractEnd:player.contractEnd}))];
}
function publicClubs(model,target,quote){
 const cash=cashRows(model),candidates=model.clubLife.interclubMarket.candidates;
 const coach=new Map((model.clubLife?.clubWorld?.coaches||[]).map(row=>[row.clubId,row]));
 const offers=new Map(quote.offers.map(offer=>[offer.clubId,offer]));
 return [...cash.values()].map(club=>{
  const players=club.id===model.club.id?model.squad:candidates.filter(player=>player.clubId===club.id);
  const salaries=players.map(player=>club.id===model.club.id?player.salary:player.sourceSalary);
  const sameFamily=players.filter(player=>club.id===model.club.id?player.fam===target.family:player.family===target.family);
  const offer=offers.get(club.id),reaction=coach.get(club.id);
  return {...club,role:club.id===model.club.id?'human':club.id===target.clubId?'seller':'potential-rival',
   publicContractedPlayers:players.length,publicPayroll:salaries.every(Number.isFinite)?salaries.reduce((a,b)=>a+b,0):null,
   publicFamilyPlayers:sameFamily.length,publicFamilyContractsBeyondSeason:sameFamily.filter(player=>player.contractEnd>model.meta.season).length,
   reactionPersonality:reaction?.style??null,offered:!!offer,quotedNeed:offer?.need??null,
   feeIfOffered:offer?.fee??null,salaryIfOffered:offer?.salary??null,
   cashAfterFeeIfOffered:offer?club.cash-offer.fee:null,
   reserveAndEightWagesIfOffered:offer?club.cash-offer.fee-400000-8*offer.salary:null,
   nonOfferReason:!offer&&club.id!==target.clubId&&club.id!==model.club.id?'not-published':null};
 });
}
function main(){
 try{
  for(const spec of CHECKPOINTS){
   const checkpoint=path.join(directory,'checkpoint-'+spec.seed);let base=bridge(checkpoint,spec.seed);
   const checkpointReport={...spec,targets:[]};report.checkpoints.push(checkpointReport);
   try{
    base.send('new_career',{mode:'fiction',club:spec.club});settleClubMeetings(base.model,base.send);
    const market=base.model.clubLife.interclubMarket;
    const candidates=market.candidates.filter(player=>player.available);
    const targets=[];
    for(const family of PREFERRED_FAMILIES){
     const rows=candidates.filter(player=>player.family===family).sort((a,b)=>a.fee-b.fee||a.salary-b.salary||a.id.localeCompare(b.id));
     if(rows.length)targets.push(rows[0]);if(targets.length===3)break;
    }
    check(targets.length>0,'At least one public available target');
    const profile=base.profile(),profileHash=hash(profile),profileMeta=JSON.parse(profile);
    checkpointReport.profileSha256=profileHash;checkpointReport.openingRng=profileMeta.seed;checkpointReport.openingClock=profileMeta.clock;
    checkpointReport.publicContext=market.context;checkpointReport.publicHumanCash=base.model.finance.cash;
    checkpointReport.publicAvailableCandidates=candidates.length;checkpointReport.selectedFamilies=targets.map(target=>target.family);
    checkpointReport.initialStateSha256=base.stateHash();equal(base.profile(),profile,'Export does not write the checkpoint');
    for(const target of targets){
     const offer={playerId:target.id,sellerId:target.clubId,fee:target.fee,salary:target.salary,sourceSalary:target.sourceSalary,contractEnd:target.contractEnd,context:market.context};
     base.send('interclub_negotiate',offer);const quote=structuredClone(base.model.meta.interclubNegotiation);
     equal(base.profile(),profile,'Negotiation preserves career bytes, RNG and clock');
     base.send('interclub_negotiate',offer);equal(base.model.meta.interclubNegotiation,quote,'Repeated public quote is deterministic');equal(base.profile(),profile,'Repeated quote remains read only');
     const sorted=quote.offers.slice().sort((a,b)=>b.salary-a.salary||b.fee-a.fee||b.need-a.need||a.clubId-b.clubId);
     equal(quote.offers,sorted,'Public offer order agrees with published salary/fee/need/ID arbitration');equal(quote.winner,quote.offers[0],'Winner is the first public offer');
     const cash=cashRows(base.model);
     for(const rival of quote.offers.filter(row=>!row.human)){
      check(rival.need>0,'Every observed rival offer has a positive published need');
      const publicCash=cash.get(rival.clubId)?.cash;check(Number.isFinite(publicCash),'Bidder cash is actually published');
      check(publicCash-rival.fee-400000-8*rival.salary>=0,'Observed bidder retains public reserve and eight salary periods');
     }
     const tooExpensive={...offer,fee:Math.floor(base.model.finance.cash)+1000};
     base.send('interclub_negotiate',tooExpensive);const refused=structuredClone(base.model.meta.interclubNegotiation);
     check(!refused.humanReady,'Offer above the human public cash is not ready');
     equal(refused.offers.filter(row=>!row.human),quote.offers.filter(row=>!row.human),'Human over-budget proposal does not fabricate different rival offers');equal(base.profile(),profile,'Over-budget consultation leaves the checkpoint intact');
     const row={target:{id:target.id,name:target.name,pos:target.pos,family:target.family,sellerId:target.clubId,fee:target.fee,salary:target.salary,sourceSalary:target.sourceSalary,contractEnd:target.contractEnd},
      publicQuote:quote,publicClubs:publicClubs(base.model,target,quote),overBudgetControl:{proposal:tooExpensive,humanReady:refused.humanReady,humanReason:refused.humanReason,rivalOffersUnchanged:true},forks:[]};
     checkpointReport.targets.push(row);
     for(const policy of ['asking-price','public-overbid']){
      const fork=path.join(directory,'fork-'+spec.seed+'-'+targets.indexOf(target)+'-'+policy);fs.cpSync(checkpoint,fork,{recursive:true,filter:source=>path.basename(source)!=='profil.lock'});let current=bridge(fork,spec.seed);
      try{
       equal(hash(current.profile()),profileHash,'Each alternative starts from identical complete profile bytes');equal(JSON.parse(current.profile()).seed,profileMeta.seed,'Each alternative starts from identical RNG');
       current.send('snapshot');const beforeCash=cashRows(current.model);
       const proposal=policy==='public-overbid'?{...offer,fee:quote.winner.fee+1000,salary:Math.min(100000,quote.winner.salary+100)}:{...offer};
       current.send('interclub_negotiate',proposal);const actual=structuredClone(current.model.meta.interclubNegotiation),winner=actual.winner;
       check(!!winner,'A real winner must be projected before confirmation');equal(hash(current.profile()),profileHash,'Fork quote does not write the career');
       const confirmed={...proposal,expectedWinner:winner.clubId,expectedFee:winner.fee,expectedSalary:winner.salary,confirmed:true};
       current.send('interclub_auction',confirmed);const receipt=structuredClone(current.model.meta.interclubTransfer),afterCash=cashRows(current.model),owner=owners(current.model,target.id);
       check(receipt.playerId===target.id&&receipt.buyerId===winner.clubId&&receipt.sellerId===target.clubId,'Confirmation receipt refers to the exact quoted player and clubs');
       equal(owner,[{clubId:winner.clubId,salary:winner.salary,contractEnd:target.contractEnd}],'Exactly one publicly projected owner and the confirmed contract');
       equal(afterCash.get(winner.clubId).cash-beforeCash.get(winner.clubId).cash,-winner.fee,'Buyer debit reconciles with public cash');
       equal(afterCash.get(target.clubId).cash-beforeCash.get(target.clubId).cash,winner.fee,'Seller credit reconciles with public cash');
       const afterHash=current.stateHash(),saved=current.profile(),executedCommands=current.commands.slice();current.close();current=bridge(fork,spec.seed);
       equal(current.profile(),saved,'Restart preserves saved profile bytes');equal(current.stateHash(),afterHash,'Restart preserves the exact sporting state');
       row.forks.push({policy,openingProfileSha256:profileHash,openingRng:profileMeta.seed,proposal,quote:actual,confirmedPayload:confirmed,receipt,
        owner:owner[0],buyerCashChange:-winner.fee,sellerCashChange:winner.fee,closingProfileSha256:hash(saved),closingStateSha256:afterHash,persisted:true,humanOverbidReady:actual.humanReady,commands:[...executedCommands,...current.commands],
        invariants:['Opening profile and RNG identical','Quote leaves bytes unchanged','Winner revalidated on actual confirmation','Exactly one public owner','Public cash debit and credit reconciled','Public contract and full state persist after restart']});
      }finally{current.close();}
     }
     equal(base.profile(),profile,'Alternative forks never mutate their checkpoint');
    }
    checkpointReport.commands=base.commands;
   }finally{base.close();}
  }
  report.complete=true;
 }catch(error){report.error={message:error.message,stack:error.stack};throw error;}
 finally{
  report.elapsedMs=Date.now()-started;report.totals={checkpoints:report.checkpoints.length,targets:report.checkpoints.reduce((n,c)=>n+c.targets.length,0),confirmedTransfers:report.checkpoints.reduce((n,c)=>n+c.targets.reduce((v,t)=>v+t.forks.length,0),0)};
  fs.mkdirSync(path.dirname(output),{recursive:true});fs.writeFileSync(output,JSON.stringify(report,null,2)+'\n');
  fs.rmSync(directory,{recursive:true,force:true});
  console.log(JSON.stringify({output,complete:report.complete,checks:report.checks,elapsedMs:report.elapsedMs,...report.totals}));
 }
}
if(require.main===module)main();

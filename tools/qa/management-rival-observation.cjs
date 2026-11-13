'use strict';
process.env.CD_MODES_HERITES='1'; // Anciens modes de carrière (non-Monde) : test à migrer vers le mode Monde.
// Targeted real-worker observation of competition for one player. No production
// coefficients, budgets, rosters, hidden ratings or RNG are edited by the runner.
const assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path'),crypto=require('node:crypto'),{execFileSync}=require('node:child_process');
const {createBridge}=require('../../native/engine/worker.cjs');
const {settleClubMeetings}=require('../../tests/helpers/club-meetings.cjs');
const hash=x=>crypto.createHash('sha256').update(x).digest('hex');
const ROOT=path.resolve(__dirname,'../..');
function worker(directory){
 const b=createBridge({dataDir:directory,seed:427,now:1794434400000});let serial=0,model;
 const go=(command,payload={})=>{const r=b.handle({id:++serial,command,payload});assert.equal(r.ok,true,command+': '+r.error);return model=r.model;};
 return {go,get model(){return model;},state:()=>JSON.parse(go('export').meta.exportText).state,
  profile:()=>fs.readFileSync(path.join(directory,'PrototypeGodot','donnees.json')),close:()=>b.close()};
}
function main(){
 const directory=fs.mkdtempSync(path.join(os.tmpdir(),'rg27-rival-observation-'));
 const checkpoint=path.join(directory,'checkpoint');let base=worker(checkpoint);
 const report={schema:1,sourceSha:execFileSync('git',['rev-parse','HEAD'],{cwd:ROOT,encoding:'utf8'}).trim(),nodeVersion:process.version,scriptSha256:hash(fs.readFileSync(__filename)),
  method:'Real public worker, complete saved profile fork including RNG, actual negotiation and confirmed auction in isolated temporary profiles',
  limits:['One player and one checkpoint do not qualify every club or recruitment window.','This channel uses public positional need and affordability; no claim that tactical style explains its bids.','No hidden rating or potential used to select the target.','A quote is distinguished from the confirmed transfer and its saved receipt.'],results:[]};
 try{
  base.go('new_career',{mode:'fiction',club:13});settleClubMeetings(base.model,base.go);
  const market=base.model.clubLife.interclubMarket,p=market.candidates.find(p=>p.available&&p.family===1);assert.ok(p);
  const offer={playerId:p.id,sellerId:p.clubId,fee:p.fee,salary:p.salary,sourceSalary:p.sourceSalary,contractEnd:p.contractEnd,context:market.context};
  const profile=base.profile();base.go('interclub_negotiate',offer);assert.deepEqual(base.profile(),profile,'A quote cannot write the saved career or consume its RNG');
  const negotiation=base.model.meta.interclubNegotiation;assert.ok(negotiation.offers.some(o=>!o.human),'The real baseline must include competition');
  report.target={id:p.id,pos:p.pos,sellerId:p.clubId,fee:p.fee,salary:p.salary,knowledge:p.knowledge.stage};
  report.checkpointProfileSha256=hash(profile);report.checkpointRng=JSON.parse(profile).seed;report.publicQuote=negotiation;
  base.close();base=null;
  for(const policy of ['prix_demande','surenchere']){
   const dir=path.join(directory,policy);fs.cpSync(checkpoint,dir,{recursive:true});let w=worker(dir);
   try{
    assert.equal(hash(w.profile()),report.checkpointProfileSha256);assert.equal(JSON.parse(w.profile()).seed,report.checkpointRng);
    const before=w.state(),proposal={...offer};
    if(policy==='surenchere'){proposal.fee=negotiation.winner.fee+1000;proposal.salary=negotiation.winner.salary+100;}
    const quoteBytes=w.profile();w.go('interclub_negotiate',proposal);assert.deepEqual(w.profile(),quoteBytes);
    const quote=w.model.meta.interclubNegotiation,winner=quote.winner;assert.ok(winner);
    if(policy==='prix_demande')assert.equal(winner.human,false);else assert.equal(winner.human,true);
    const payload={...proposal,expectedWinner:winner.clubId,expectedFee:winner.fee,expectedSalary:winner.salary,confirmed:true};
    w.go('interclub_auction',payload);const receipt=w.model.meta.interclubTransfer;
    assert.ok(receipt&&receipt.playerId===p.id&&receipt.buyerId===winner.clubId);const after=w.state();
    assert.equal(after.clubs[p.clubId].cash-before.clubs[p.clubId].cash,winner.fee);
    assert.equal(after.clubs[winner.clubId].cash-before.clubs[winner.clubId].cash,-winner.fee);
    assert.equal(after.clubs.flatMap(c=>c.players).filter(player=>player.id===p.id).length,1);
    assert.ok(!after.clubs[p.clubId].players.some(player=>player.id===p.id));
    const transferred=after.clubs[winner.clubId].players.find(player=>player.id===p.id);assert.equal(transferred.salary,winner.salary);
    const closed=w.profile();w.close();w=worker(dir);assert.deepEqual(w.profile(),closed);assert.deepEqual(w.state(),after,'Restart retains the real transfer');
    report.results.push({policy,proposal,quote,confirmedPayload:payload,receipt,
     openingProfileSha256:report.checkpointProfileSha256,closingProfileSha256:hash(closed),
     buyerCashChange:-winner.fee,sellerCashChange:winner.fee,newSalary:transferred.salary,persisted:true,
     invariants:['Quote leaves career, RNG and disk unchanged','Expected quote winner revalidated before confirmation','Exactly one owner after transfer','Buyer and seller cash reconciled','Contract persists after real worker restart']});
   }finally{w.close();}
  }
  report.complete=true;
  const output=path.resolve(process.argv.find(a=>a.startsWith('--output='))?.slice(9)||'work/management-rival-results.json');fs.mkdirSync(path.dirname(output),{recursive:true});fs.writeFileSync(output,JSON.stringify(report,null,2)+'\n');console.log(output);
 }finally{base?.close();fs.rmSync(directory,{recursive:true,force:true});}
}
if(require.main===module)main();

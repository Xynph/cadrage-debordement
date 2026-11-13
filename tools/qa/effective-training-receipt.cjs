'use strict';
process.env.CD_MODES_HERITES='1'; // Anciens modes de carrière (non-Monde) : test à migrer vers le mode Monde.
// Real public commands only. No edited condition/lineup state, altered threshold,
// or extraction of an applied mode from a sentence or a fitness calculation.
const assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path'),crypto=require('node:crypto'),{execFileSync}=require('node:child_process');
const {createBridge}=require('../../native/engine/worker.cjs');
const {settleClubMeetings}=require('../../tests/helpers/club-meetings.cjs');
const ROOT=path.resolve(__dirname,'../..');
const hash=x=>crypto.createHash('sha256').update(x).digest('hex');
function worker(directory){
 const b=createBridge({dataDir:directory,seed:427,now:1794434400000});let serial=0,model;const commands=[];
 const go=(command,payload={})=>{const r=b.handle({id:++serial,command,payload});assert.equal(r.ok,true,command+': '+r.error);model=r.model;if(!['snapshot','export'].includes(command))commands.push({command,payload});return model;};
 return {go,commands,profile:()=>fs.readFileSync(path.join(directory,'PrototypeGodot','donnees.json')),get model(){return model;},close:()=>b.close()};
}
function visible(model){
 const support=model.clubLife.clubSupport;
 // The mode receipt contract uses these public fields, not individual ratings,
 // potential, raw inbox searches, forecast plans, or an inferred numeric rule.
 return {club:{id:model.club.id},meta:{mode:model.meta.mode,season:model.meta.season,week:model.meta.week,trained:model.meta.trained,training:model.meta.training,morale:model.meta.morale,saveError:model.meta.saveError},
  finance:{cash:model.finance.cash,wage:model.finance.wage},squad:[],clubLife:{clubSupport:{context:structuredClone(support.context),training:{session:structuredClone(support.training.session)}}}};
}
function meanLineup(model){
 const rows=model.lineup.map(id=>model.squad.find(p=>p.id===id&&p.knowledge?.owned===true)).filter(Boolean);
 assert.equal(rows.length,15,'A public full starting XV is needed for the observed fixture');
 return rows.reduce((sum,p)=>sum+p.condition,0)/rows.length;
}
function round(w,index){
 if(!w.model.meta.trained)w.go('train',{mode:index===0?'normal':'intense'});settleClubMeetings(w.model,w.go);w.go('auto_lineup');
 if(!w.model.selection.valid){const q=w.model.selection.coverage;assert.ok(q?.slots?.length&&q.slots.length<=q.places);w.go('promote_cover',{confirmed:true,expectedSlots:q.slots});}
 w.go('begin_match');w.go('delegate');w.go('finish_round');settleClubMeetings(w.model,w.go);
}
function collect(output){
 const temp=fs.mkdtempSync(path.join(os.tmpdir(),'rg27-effective-training-'));
 const report={schema:1,sourceSha:execFileSync('git',['rev-parse','HEAD'],{cwd:ROOT,encoding:'utf8'}).trim(),runnerSha256:hash(fs.readFileSync(__filename)),nodeVersion:process.version,
  method:'Public pending/applied session plus current meta.training in matching club/season/week; exact public reason retained verbatim',
  limits:['The session has no own mode field or timestamp: clubSupport.context and meta must match.','The collective mode does not replace individual exceptions.','No before/after condition is used to infer the receipt mode or invent its reason.','The two fixtures are different career moments, not an equal-checkpoint strategy comparison.'],cases:[]};
 try{
  for(const tired of [false,true]){
   const w=worker(path.join(temp,tired?'tired':'fresh'));
   try{
    w.go('new_career',{mode:'fiction',club:13});settleClubMeetings(w.model,w.go);
    let rounds=0;
    if(tired){
     w.go('set_delegation',{key:'training',enabled:false});
     do{round(w,rounds);rounds++;}while(meanLineup(w.model)>=75&&rounds<3);
    }
    w.go('set_delegation',{key:'training',enabled:true});
    const before=visible(w.model),condition=meanLineup(w.model),profile=w.profile();
    assert.equal(before.clubLife.clubSupport.training.session.status,'pending');assert.equal(before.meta.trained,false);
    w.go('train',{mode:'intense'});const after=visible(w.model),afterProfile=w.profile();
    const applied=after.meta.training;assert.ok(['repos','normal'].includes(applied));
    assert.equal(after.meta.trained,true);assert.equal(after.clubLife.clubSupport.training.session.status,'applied');
    assert.equal(typeof after.clubLife.clubSupport.training.session.reason,'string');
    const beforeContext=before.clubLife.clubSupport.context,afterContext=after.clubLife.clubSupport.context;
    assert.deepEqual(afterContext,beforeContext);assert.deepEqual(afterContext,{season:after.meta.season,week:after.meta.week,club:after.club.id});
    w.go('snapshot');w.go('export');assert.deepEqual(w.profile(),afterProfile,'Reading the public session cannot rewrite the outcome profile or RNG');
    report.cases.push({id:tired?'delegated_after_public_matches':'delegated_fresh_career',requested:'intense',applied,before,after,
     publicLineupMeanConditionBefore:condition,publicWarmupMatches:rounds,recoveryOverrideReached:applied==='repos',commands:w.commands,
     profileBeforeSha256:hash(profile),profileAfterSha256:hash(afterProfile),seedBefore:JSON.parse(profile).seed,seedAfter:JSON.parse(afterProfile).seed,
     clockBefore:JSON.parse(profile).clock,clockAfter:JSON.parse(afterProfile).clock,readOnlyCollectionPreservedProfile:true});
   }finally{w.close();}
  }
  report.realNormalOverride=report.cases.some(c=>c.applied==='normal');report.realRecoveryOverride=report.cases.some(c=>c.applied==='repos');
  report.complete=true;fs.mkdirSync(path.dirname(output),{recursive:true});fs.writeFileSync(output,JSON.stringify(report,null,2)+'\n');return report;
 }finally{fs.rmSync(temp,{recursive:true,force:true});}
}
if(require.main===module){const output=path.resolve(process.argv.find(a=>a.startsWith('--output='))?.slice(9)||'work/effective-training-cases.json');const r=collect(output);console.log(JSON.stringify({output,normal:r.realNormalOverride,recovery:r.realRecoveryOverride,cases:r.cases.map(c=>({id:c.id,condition:c.publicLineupMeanConditionBefore,requested:c.requested,applied:c.applied,reason:c.after.clubLife.clubSupport.training.session.reason}))}));}
module.exports={collect};

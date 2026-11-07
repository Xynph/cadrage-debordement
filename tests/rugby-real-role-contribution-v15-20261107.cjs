'use strict';
/** Diagnostic read-only of 1592 active profiles and shadow-only individual changes. */
const {test}=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const N=require('../tools/rugby-real-v12/native.cjs');
const C=require('../tools/rugby-real-v12/review.cjs');
const A=require('../tools/rugby-real-v12/campaign.cjs');
const ROOT=path.resolve(__dirname,'..');
const raw=fs.readFileSync(path.join(ROOT,'dist/lnr-ratings-v12.js'),'utf8');
const data=vm.runInNewContext(raw+'\n;LNR_V12_PLAYER_DATA;');
const master=JSON.parse(fs.readFileSync(path.join(ROOT,'modding/data06/rugby-master-2026-2027.json'),'utf8'));
const clone=x=>JSON.parse(JSON.stringify(x)),round=n=>+n.toFixed(3);
const mean=a=>a.reduce((s,v)=>s+v,0)/a.length;
const sd=a=>{const m=mean(a);return Math.sqrt(mean(a.map(v=>(v-m)**2)))};
const SKILLS=data.skillKeys,ATTRS=data.attributeKeys;
const active=clone(master);
for(const p of active.players){
 const tuple=data.players[p.id];assert.ok(tuple);
 p.rating=p.ratingV12=tuple[0];p.potential=tuple[2];
 p.attributesV2=Object.fromEntries(ATTRS.map((k,i)=>[k,tuple[3][i]]));
 p.skills=Object.fromEntries(SKILLS.map((k,i)=>[k,tuple[4][i]]));
 p.hiddenTraitsV2=clone(tuple[6]);
}
const roleKeys={
 'Pilier gauche':['scrumTechnique','strength','ruckClearout','maul','tackling'],
 'Pilier droit':['scrumTechnique','strength','ruckClearout','maul','tackling'],
 'Talonneur':['hooking','lineoutThrow','tackling','maul','ruckClearout'],
 'Deuxième ligne':['lineoutJump','lineoutLift','maul','ruckClearout','strength'],
 'Troisième ligne':['jackal','tackling','ruckClearout','workRate','ballCarry'],
 'Numéro 8':['ballCarry','strength','tackling','jackal','workRate'],
 'Demi de mêlée':['passing','decisions','vision','kickAccuracy','workRate'],
 'Demi d’ouverture':['kickAccuracy','passing','decisions','vision','kickDistance'],
 'Centre':['tackling','ballCarry','passing','offload','decisions'],
 'Ailier':['topSpeed','acceleration','evasion','receiving','kickChase'],
 'Arrière':['aerialAbility','receiving','positioning','kickDistance','decisions']
};
function complete(lab,c){const s=lab.sheet(c);return s.lineup.filter(Boolean).length===15&&s.bench.filter(Boolean).length===8;}
function details(lab,c){
 const s=lab.sheet(c),idx=new Map(c.players.map(p=>[p.id,p]));
 return s.lineup.filter(Boolean).map((id,slot)=>{const p=idx.get(id);return {id:p.id,slot,role:p.pos,
  note:lab.note(p),skills:clone(p.skills),attrs:clone(p.attributesV2)};});
}
function shadow(c,changes){const x=clone(c),idx=new Map(x.players.map(p=>[p.id,p]));
 for(const entry of changes){
  const p=idx.get(entry.id);assert.ok(p,'missing candidate '+entry.id);
  const original=clone(p);for(const [key,delta] of Object.entries(entry.attributes))p.attributesV2[key]=Math.min(97,Math.max(20,p.attributesV2[key]+delta));
  if(entry.sync){
   const before=C.project(original),after=C.project(p);
   for(const k of SKILLS)p.skills[k]=Math.min(97,Math.max(20,+(p.skills[k]+after[k]-before[k]).toFixed(2)));
  }
 }
 return x;
}
function paired(lab,a,b,seeds){
 assert.ok(complete(lab,a)&&complete(lab,b),'complete roster required');
 const rows=[];
 for(let i=0;i<seeds;i++)for(const home of [0,1]){
  const r=lab.match(a,b,A.seed(i),{home});
  rows.push({seed:i,home,score:r.score});
 }
 return Array.from({length:seeds},(_,i)=>mean(rows.slice(i*2,i*2+2).map(r=>r.score[0]-r.score[1])));
}
function effect(a,b){
 const diff=a.map((x,i)=>x-b[i]),m=mean(diff),se=sd(diff)/Math.sqrt(diff.length-1);
 return {marginDelta:round(m),ci95:[round(m-1.96*se),round(m+1.96*se)],
  seedPairs:diff.length};
}
test('All 1592 players: attributes, 11 skills, role signatures and within-team compression',()=>{
 assert.equal(active.players.length,1592);
 const lab=N.laboratory(active,'legacy');
 const players=active.players;
 const leagues=Object.fromEntries(['top14','prod2'].map(league=>{
  const ps=players.filter(p=>p.league===league);
  return [league,{count:ps.length,rating:{mean:round(mean(ps.map(p=>p.rating))),sd:round(sd(ps.map(p=>p.rating)))},
   skills:Object.fromEntries(SKILLS.map(k=>[k,{mean:round(mean(ps.map(p=>p.skills[k]))),sd:round(sd(ps.map(p=>p.skills[k])))}])),
   attrs:Object.fromEntries(ATTRS.map(k=>[k,{mean:round(mean(ps.map(p=>p.attributesV2[k]))),sd:round(sd(ps.map(p=>p.attributesV2[k])))}]))}];
 }));
 const byRole=Object.fromEntries(Object.keys(roleKeys).map(role=>{
  const ps=players.filter(p=>p.gameplayPosition===role),keys=roleKeys[role];
  const weighted=ps.map(p=>mean(keys.map(k=>p.attributesV2[k])));
  return [role,{n:ps.length,meanFivePrimary:round(mean(weighted)),sdFivePrimary:round(sd(weighted)),
   ratingMean:round(mean(ps.map(p=>p.rating))),ratingSD:round(sd(ps.map(p=>p.rating))),
   attributeSpread:round(mean(keys.map(k=>sd(ps.map(p=>p.attributesV2[k])))))}];
 }));
 const teams={};for(const league of ['top14','prod2']){
  const clubs=lab.clubs.filter(c=>c.league===league&&complete(lab,c));
  const rows=clubs.map(c=>{const starters=details(lab,c),scores=starters.map(x=>x.note);
   return {club:c.slug,overall:round(mean(scores)),max:Math.max(...scores),min:Math.min(...scores),
    withinXVSD:round(sd(scores)),
    slots:starters.map(x=>({slot:x.slot,role:x.role,note:x.note,id:x.id}))};
  });
  const teamMeans=rows.map(r=>r.overall);
  teams[league]={n:rows.length,clubSD:round(sd(teamMeans)),clubRange:round(Math.max(...teamMeans)-Math.min(...teamMeans)),
   averageWithinXVSD:round(mean(rows.map(x=>x.withinXVSD))),rows};
 }
 console.log('RUGBY_REAL_ROLE_CONTRIBUTION_CENSUS '+JSON.stringify({
  population:1592,leagues,byRole,teams,
  interpretation:'The 36 attributes coexist with precomputed 11 skills; roleNote weights the latter, not directly all 36.'
 }));
});
test('Shadow-only positional correction: inspect attributes-only versus synchronized skills, then paired native matches',{timeout:300000},()=>{
 const lab=N.laboratory(active,'legacy');
 const rank=league=>lab.clubs.filter(c=>c.league===league&&complete(lab,c))
  .sort((a,b)=>lab.quality(a)-lab.quality(b)||a.slug.localeCompare(b.slug));
 const pro=rank('prod2').at(-1),top=rank('top14');
 const rival=top[Math.floor(top.length/2)];
 const baseline=details(lab,pro);
 // Choose top five candidates among weakest starting positions; cover five distinct roles.
 const ordered=baseline.slice().sort((a,b)=>a.note-b.note||a.id.localeCompare(b.id));
 const chosen=[],seen=new Set();for(const p of ordered){if(seen.has(p.role))continue;chosen.push(p);seen.add(p.role);if(chosen.length===5)break;}
 assert.equal(chosen.length,5);
 const edits=chosen.map(p=>({id:p.id,role:p.role,attributes:Object.fromEntries(roleKeys[p.role].map(k=>[k,5]))}));
 const just36=shadow(pro,edits.map(x=>({...x,sync:false})));
 const reconciled=shadow(pro,edits.map(x=>({...x,sync:true})));
 const byId=c=>new Map(c.players.map(p=>[p.id,p]));
 const effects=chosen.map(p=>{const baseP=byId(pro).get(p.id),only=byId(just36).get(p.id),sync=byId(reconciled).get(p.id);
  return {id:p.id,role:p.role,originalNote:lab.note(baseP),only36Note:lab.note(only),
   syncedNote:lab.note(sync),attributeChanges:Object.fromEntries(roleKeys[p.role].map(k=>[k,round(sync.attributesV2[k]-baseP.attributesV2[k])])),
   skillDeltas:Object.fromEntries(SKILLS.filter(k=>sync.skills[k]!==baseP.skills[k]).map(k=>[k,round(sync.skills[k]-baseP.skills[k])]))};
 });
 const baseScore=paired(lab,pro,rival,16);
 const attrScore=paired(lab,just36,rival,16);
 const skillScore=paired(lab,reconciled,rival,16);
 const unchangedSource=chosen.every(p=>{const original=data.players[p.id],now=active.players.find(x=>x.id===p.id);return now.rating===original[0]&&now.attributesV2.topSpeed===original[3][ATTRS.indexOf('topSpeed')]});
 assert.equal(unchangedSource,true);
 const out={club:pro.slug,opponent:rival.slug,edits,affected:effects,
  baseXV:round(mean(details(lab,pro).map(p=>p.note))),only36XV:round(mean(details(lab,just36).map(p=>p.note))),
  syncXV:round(mean(details(lab,reconciled).map(p=>p.note))),
  attributeOnly:effect(attrScore,baseScore),synchronized:effect(skillScore,baseScore),
  baselineMargin:round(mean(baseScore)),sourceUnchanged:unchangedSource,
  caution:'Illustrative estimated changes +5 on five primary attrs for five distinct role incumbents. Not evidence of player under/overrating.'};
 console.log('RUGBY_REAL_ROLE_SHADOW_CALIBRATION '+JSON.stringify(out));
 assert.equal(effects.length,5);
});

test('Dose response on three TOP14 opponents, 5 real individual candidates, +5/+10 shadow calibration', {timeout:420000},()=>{
 const lab=N.laboratory(active,'legacy');
 const rank=league=>lab.clubs.filter(c=>c.league===league&&complete(lab,c))
  .sort((a,b)=>lab.quality(a)-lab.quality(b)||a.slug.localeCompare(b.slug));
 const promoted=rank('prod2').at(-1),top=rank('top14');
 const rivals=[top[0],top[Math.floor(top.length/2)],top.at(-1)];
 const starters=details(lab,promoted).sort((a,b)=>a.note-b.note||a.id.localeCompare(b.id));
 const targets=[],seen=new Set();
 for(const p of starters){if(seen.has(p.role))continue;seen.add(p.role);targets.push(p);if(targets.length===5)break;}
 assert.equal(targets.length,5);
 const doses=[5,10],copies=doses.map(d=>shadow(promoted,targets.map(p=>({id:p.id,sync:true,
  attributes:Object.fromEntries(roleKeys[p.role].map(k=>[k,d]))}))));
 const q=team=>round(mean(details(lab,team).map(x=>x.note)));
 const cases=[];
 for(const rival of rivals){
  const baseline=paired(lab,promoted,rival,32);
  const results=copies.map((c,i)=>({dose:doses[i],xvDelta:round(q(c)-q(promoted)),
   effect:effect(paired(lab,c,rival,32),baseline)}));
  cases.push({opponent:rival.slug,opponentXV:q(rival),initialXV:q(promoted),
   baselineMargin:round(mean(baseline)),results});
 }
 console.log('RUGBY_REAL_ROLE_DOSE_RESPONSE '+JSON.stringify({matches:3*3*32*2,
  seedPairsPerScenario:32,candidates:targets.map(p=>({id:p.id,role:p.role,note:p.note})),
  cases,notice:'+5/+10 primary attributes are synthetic stress tests only; nothing applied to the BDD'}));
});

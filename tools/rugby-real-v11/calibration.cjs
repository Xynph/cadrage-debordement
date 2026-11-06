'use strict';
const crypto=require('node:crypto');
const clone=x=>JSON.parse(JSON.stringify(x));
const hash=x=>crypto.createHash('sha256').update(typeof x==='string'||Buffer.isBuffer(x)?x:JSON.stringify(x)).digest('hex');
const mean=a=>a.reduce((n,v)=>n+v,0)/a.length;
const round=n=>Math.round(n*100)/100;
const ROLES={
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
// Proposal only: no live/save code imports this projection. All 36 facets contribute.
const PROJECTION={
 scrum:{scrumTechnique:.65,hooking:.15,strength:.2},
 lineout:{lineoutThrow:.2,lineoutJump:.25,lineoutLift:.2,jumping:.2,aerialAbility:.15},
 tackle:{tackling:.7,jackal:.15,positioning:.15},
 speed:{topSpeed:.4,acceleration:.25,agility:.15,evasion:.1,kickChase:.1},
 pass:{passing:.6,receiving:.15,offload:.1,ballHandling:.15},
 kick:{kickDistance:.45,kickAccuracy:.45,vision:.1},
 goal:{goalAccuracy:.9,composure:.1},
 mental:{decisions:.35,anticipation:.15,vision:.15,composure:.15,teamwork:.15,leadership:.05},
 discipline:{discipline:1},stamina:{endurance:.8,workRate:.2},
 power:{strength:.4,explosiveness:.2,ballCarry:.2,ruckClearout:.1,maul:.1}
};
const weighted=(a,w)=>Object.entries(w).reduce((n,[k,v])=>n+a[k]*v,0);
function project(p){
 const a=p.attributesV2,role=p.gameplayPosition;
 if(!ROLES[role]||!a||Object.keys(a).length!==36)throw Error('Invalid role/36 attributes');
 const weights={...PROJECTION};
 if(role==='Talonneur')weights.lineout={lineoutThrow:.65,ballHandling:.1,decisions:.05,lineoutJump:.05,lineoutLift:.05,jumping:.05,aerialAbility:.05};
 if(role==='Deuxième ligne')weights.lineout={lineoutJump:.4,lineoutLift:.2,jumping:.2,aerialAbility:.15,lineoutThrow:.05};
 return Object.fromEntries(Object.entries(weights).map(([k,w])=>[k,round(weighted(a,w))]));
}
function validate(master){
 if(!Array.isArray(master.players)||master.players.length!==1592)throw Error('Expected 1592 master players');
 const ids=new Set(),keys=Object.keys(master.players[0].attributesV2).sort().join();
 for(const p of master.players){
  if(ids.has(p.id)||!p.id)throw Error('Duplicate/missing ID');ids.add(p.id);
  if(!ROLES[p.gameplayPosition]||!['top14','prod2'].includes(p.league))throw Error('Invalid league/role');
  if(Object.keys(p.attributesV2).sort().join()!==keys||Object.values(p.attributesV2).some(v=>!Number.isFinite(v)||v<20||v>97))throw Error('Invalid attributes');
  if(Object.keys(p.hiddenTraitsV2).length!==6)throw Error('Expected 6 hidden traits');
 }
}
function consolidate(master,{targetGap=7}={}){
 validate(master);if(!Number.isFinite(targetGap)||targetGap<4||targetGap>9)throw Error('Invalid target');
 const changes=new Map(),roleAudit={};
 for(const [role,fields] of Object.entries(ROLES)){
  const group=master.players.filter(p=>p.gameplayPosition===role),top=group.filter(p=>p.league==='top14'),pro=group.filter(p=>p.league==='prod2');
  const quality=p=>mean(fields.map(k=>p.attributesV2[k]));
  const gap=mean(top.map(quality))-mean(pro.map(quality));
  const median=[...group.map(quality)].sort((a,b)=>a-b)[Math.floor(group.length/2)];
  // Freeze initial cohort by ID, never use the club's CURRENT division.
  // Modulate by individual specialist profile; fringe players get smaller corrections.
  const raw=top.map(p=>({p,weight:Math.max(.4,Math.min(1.2,1+(quality(p)-median)/25))}));
  const weightMean=mean(raw.map(x=>x.weight)),needed=Math.max(0,targetGap-gap);
  for(const {p,weight} of raw){
   const delta=Math.min(5,needed*weight/weightMean);
   changes.set(p.id,fields.map(k=>({attribute:k,from:p.attributesV2[k],to:round(Math.min(97,p.attributesV2[k]+delta)),kind:'gameplay-estimate',basis:'frozen-start-cohort-individual-role-profile'})).filter(c=>c.from!==c.to));
  }
  const after=top.map(p=>{const a={...p.attributesV2};for(const c of changes.get(p.id))a[c.attribute]=c.to;return mean(fields.map(k=>a[k]));});
  roleAudit[role]={top14:top.length,prod2:pro.length,gapBefore:round(gap),gapAfter:round(mean(after)-mean(pro.map(quality))),targetGap,primary:fields};
 }
 const candidates=master.players.map(p=>({playerId:p.id,leagueAtStart:p.league,role:p.gameplayPosition,changes:changes.get(p.id)||[]}));
 return {schema:'rugby-real-v11-consolidated-candidate',baselineHash:hash(master),asOf:'2026-07-01',targetGap,appliedToMaster:false,
  method:'One recomputation from immutable V3/V4/V5 master; V6/V8/V9/V10 deltas NOT stacked. Observations stay separate from skill estimates.',
  roleAudit,candidates,summary:{players:1592,affected:candidates.filter(p=>p.changes.length).length,adjustments:candidates.reduce((n,p)=>n+p.changes.length,0)}};
}
function apply(master,report){
 if(report.schema!=='rugby-real-v11-consolidated-candidate'||report.baselineHash!==hash(master))throw Error('Candidate baseline mismatch / already applied');
 const copy=clone(master),byId=new Map(copy.players.map(p=>[p.id,p])),seen=new Set();
 for(const row of report.candidates){
  const p=byId.get(row.playerId);if(!p||seen.has(p.id))throw Error('Invalid/duplicate candidate ID');seen.add(p.id);
  const attrs=new Set();
  for(const c of row.changes){
   if(attrs.has(c.attribute)||!Object.hasOwn(p.attributesV2,c.attribute)||p.attributesV2[c.attribute]!==c.from||!Number.isFinite(c.to)||c.to<20||c.to>97)throw Error('Invalid change precondition');
   attrs.add(c.attribute);p.attributesV2[c.attribute]=c.to;
  }
 }
 if(seen.size!==1592)throw Error('Incomplete candidate');
 return copy;
}
module.exports={ROLES,PROJECTION,project,consolidate,apply,validate,hash,clone,mean,round};

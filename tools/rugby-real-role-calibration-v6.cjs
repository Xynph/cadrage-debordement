'use strict';
const fs=require('node:fs'), path=require('node:path');
const ROOT=path.resolve(__dirname,'../modding/data06/rugby-master-2026-2027.json');
const PRIORITIES={
 'Pilier gauche':['scrumTechnique','strength','ruckClearout','tackling','maul'],
 'Pilier droit':['scrumTechnique','strength','ruckClearout','tackling','maul'],
 'Talonneur':['hooking','lineoutThrow','ruckClearout','tackling','ballHandling'],
 'Deuxième ligne':['lineoutJump','lineoutLift','maul','ruckClearout','strength'],
 'Troisième ligne':['jackal','tackling','ruckClearout','ballCarry','workRate'],
 'Numéro 8':['ballCarry','tackling','strength','workRate','jackal'],
 'Demi de mêlée':['passing','decisions','vision','kickAccuracy','workRate'],
 'Demi d’ouverture':['kickAccuracy','passing','decisions','vision','kickDistance'],
 'Centre':['tackling','ballCarry','passing','offload','decisions'],
 'Ailier':['topSpeed','acceleration','evasion','receiving','kickChase'],
 'Arrière':['aerialAbility','receiving','positioning','kickDistance','decisions']
};
const numeric=x=>typeof x==='number'&&Number.isFinite(x);
const midpoint=x=>{const a=[...x].sort((a,b)=>a-b);return a.length?(a[Math.floor((a.length-1)/2)]+a[Math.floor(a.length/2)])/2:null;};
function calibrate(root){
  const players=root.players;
  if(!Array.isArray(players)||players.length!==1592)throw Error('Expected 1592 master players');
  const ids=new Set(), groups=new Map(), fields=new Set();
  for(const p of players){
    if(!p||!p.id||ids.has(p.id))throw Error('Missing or duplicate stable player ID');
    ids.add(p.id);
    if(!p.attributesV2||Object.keys(p.attributesV2).length!==36||Object.values(p.attributesV2).some(v=>!numeric(v)||v<20||v>97))throw Error('Invalid 36-attribute record');
    for(const k of Object.keys(p.attributesV2))fields.add(k);
    const role=p.gameplayPosition||p.position, league=p.league;
    if(!PRIORITIES[role]||!['top14','prod2'].includes(league))throw Error('Unknown league/role '+league+' '+role);
    const key=league+'|'+role;
    if(!groups.has(key))groups.set(key,[]);
    groups.get(key).push(p);
  }
  if(fields.size!==36)throw Error('Not 36 consistent fields');
  const thresholds=new Map();
  for(const [g,roster] of groups){
    const role=g.split('|')[1];
    thresholds.set(g,Object.fromEntries(PRIORITIES[role].map(attr=>{
      const vals=roster.map(p=>p.attributesV2[attr]).sort((a,b)=>a-b);
      if(vals.length<8)throw Error('Underpopulated role '+g);
      return [attr,{q25:vals[Math.floor((vals.length-1)*.25)],q75:vals[Math.floor((vals.length-1)*.75)],median:midpoint(vals)}];
    })));
  }
  const candidates=[];
  const summary={players:players.length,recordsWithCandidateChanges:0,changedAttributes:0,byLeague:{top14:0,prod2:0},byRole:{},priorEvidence:{performance2025_2026:0,v4EvidenceAdjustment:0},method:'relative-role-profile-v6',appliedToMaster:false};
  for(const p of players){
    const role=p.gameplayPosition||p.position,group=p.league+'|'+role;
    const changes=[];
    // Build a bounded optional candidate for four specialist attributes only.
    // Comparisons depend only on the 2026-27 master baseline; no future match results.
    for(const attr of PRIORITIES[role].slice(0,4)){
      const old=p.attributesV2[attr],t=thresholds.get(group)[attr];
      const delta=old>t.q75?2:old<t.q25?-1:0;
      const proposed=Math.max(20,Math.min(97,old+delta));
      if(proposed!==old)changes.push({attribute:attr,from:old,to:proposed,delta:proposed-old,evidence:'model-estimate',basis:'within-league-position-quartile'});
    }
    if(p.performance2025_2026!=null)summary.priorEvidence.performance2025_2026++;
    if(p.v4EvidenceAdjustment!=null)summary.priorEvidence.v4EvidenceAdjustment++;
    if(changes.length){summary.recordsWithCandidateChanges++;summary.changedAttributes+=changes.length;summary.byLeague[p.league]++;}
    const bucket=summary.byRole[group]||(summary.byRole[group]={players:0,candidates:0,changedAttributes:0});
    bucket.players++;if(changes.length)bucket.candidates++;bucket.changedAttributes+=changes.length;
    candidates.push({playerId:p.id,league:p.league,gameplayPosition:role,gameplayPositionEstimated:!!p.gameplayPositionEstimated,quality:'model-estimate',priorPerformanceAvailable:p.performance2025_2026!=null,priorV4Adjustment:p.v4EvidenceAdjustment!=null,changes});
  }
  return {schema:'rugby-real-role-calibration-v6-candidate',asOf:'2026-07-01',summary,candidates};
}
function main(){
  const input=process.argv[2]||ROOT;
  const dest=process.argv[3];
  const root=JSON.parse(fs.readFileSync(input,'utf8'));
  const unchanged=JSON.stringify(root);
  const report=calibrate(root);
  if(JSON.stringify(root)!==unchanged)throw Error('Input mutated');
  if(dest)fs.writeFileSync(dest,JSON.stringify(report,null,2)+'\n');
  console.log(JSON.stringify({schema:report.schema,summary:report.summary}));
}
if(require.main===module)main();
module.exports={calibrate,PRIORITIES};
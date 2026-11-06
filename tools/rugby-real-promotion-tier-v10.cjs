'use strict';
const fs=require('node:fs'),path=require('node:path');
const DATA=path.resolve(__dirname,'../modding/data06/rugby-master-2026-2027.json');
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
const mean=a=>a.reduce((s,v)=>s+v,0)/a.length;
const round=x=>Math.round(x*100)/100;
function evaluate(root,{targetGap=7,maxBonus=5,fixture=false}={}){
 if(!(targetGap>=3&&targetGap<=10&&Number.isFinite(targetGap)))throw Error('Invalid gap target');
 if(!(maxBonus>=0&&maxBonus<=6&&Number.isInteger(maxBonus)))throw Error('Invalid max bonus');
 const players=root.players;
 if(!Array.isArray(players)||(!fixture&&players.length!==1592))throw Error('Master must contain 1592 players');
 const roster=new Map(),ids=new Set();
 for(const p of players){
  const role=p.gameplayPosition||p.position;
  if(!p.id||ids.has(p.id))throw Error('Duplicate/missing player ID');
  ids.add(p.id);
  if(!ROLES[role]||!['top14','prod2'].includes(p.league))throw Error('Unrecognized position or league');
  if(!p.attributesV2||Object.keys(p.attributesV2).length!==36||Object.values(p.attributesV2).some(v=>!Number.isFinite(v)||v<20||v>97))throw Error('Invalid 36 skills');
  const key=p.league+'|'+role;
  if(!roster.has(key))roster.set(key,[]);
  roster.get(key).push(p);
 }
 const byId=new Map(),roleAudit={};
 for(const [role,fields] of Object.entries(ROLES)){
  const top=roster.get('top14|'+role)||[],pro=roster.get('prod2|'+role)||[];
  if(!top.length||!pro.length)throw Error('Missing reference group '+role);
  const score=p=>mean(fields.map(k=>p.attributesV2[k]));
  const baseTop=mean(top.map(score)),basePro=mean(pro.map(score));
  const gap=baseTop-basePro;
  // Existing TOP14 cohort only, not a division-based buff at promotion time.
  const bonus=Math.max(0,Math.min(maxBonus,Math.ceil((targetGap-gap)*100)/100));
  let totalApplied=0,changed=0;
  for(const p of top){
   const changes=fields.map(k=>{
    const old=p.attributesV2[k],next=round(Math.min(97,old+bonus));
    return next>old?{attribute:k,from:old,to:next,delta:round(next-old),kind:'gameplay-balance-candidate',reason:'top14-starting-roster-tier-strength'}:null;
   }).filter(Boolean);
   if(changes.length){changed++;totalApplied+=mean(fields.map(k=>changes.find(c=>c.attribute===k)?.delta||0));}
   byId.set(p.id,changes);
  }
  for(const p of pro)byId.set(p.id,[]);
  const afterTop=baseTop+totalApplied/top.length,afterGap=afterTop-basePro;
  roleAudit[role]={playersTop14:top.length,playersProD2:pro.length,top14Before:round(baseTop),proD2Before:round(basePro),gapBefore:round(gap),proposedTop14Bonus:round(bonus),gapAfter:round(afterGap),targetReached:afterGap>=targetGap-.02,playersChanged:changed};
 }
 const candidates=players.map(p=>({playerId:p.id,leagueAtStart:p.league,gameplayPosition:p.gameplayPosition||p.position,changes:byId.get(p.id)}));
 const changed=candidates.filter(p=>p.changes.length);
 const summary={total:players.length,top14:players.filter(p=>p.league==='top14').length,prod2:players.filter(p=>p.league==='prod2').length,affectedPlayers:changed.length,changedAttributes:changed.reduce((s,p)=>s+p.changes.length,0),rolesTargetMet:Object.values(roleAudit).filter(r=>r.targetReached).length,rolesAudited:Object.keys(roleAudit).length};
 // Scenario compares unchanged player quality to existing opponent tier; not a match-engine result.
 const transitions={promotion:{roster:'unchanged PRO D2 cohort',opponent:'current TOP14 cohort with proposed specialist adjustments',automaticLeagueBonusToPromoted:0},relegation:{roster:'unchanged TOP14 cohort, including acquired player development',opponent:'current PRO D2 cohort',automaticLeagueNerfToRelegated:0}};
 return {schema:'rugby-real-v10-promotion-tier-candidates',asOf:'2026-07-01',targetGap,maxBonus,summary,roleAudit,transitions,candidates,limitations:['Heuristic quality proxy only; no win-rate evidence or match engine used','Existing cohorts are different squads, not promotion history','Must assess V6/V8/V9 overlap before integrating candidates']};
}
if(require.main===module){
 const input=process.argv[2]||DATA,out=process.argv[3];
 const buffer=fs.readFileSync(input),master=JSON.parse(buffer.toString());
 const result=evaluate(master);
 if(!fs.readFileSync(input).equals(buffer))throw Error('Master mutated');
 if(out)fs.writeFileSync(out,JSON.stringify(result,null,2)+'\n');
 console.log(JSON.stringify({summary:result.summary,roleAudit:result.roleAudit,transitions:result.transitions}));
}
module.exports={evaluate,ROLES};

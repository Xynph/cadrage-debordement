'use strict';
const fs=require('node:fs'),path=require('node:path');
const SOURCE=path.resolve(__dirname,'../modding/data06/rugby-master-2026-2027.json');
const ROLE={
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
const mean=a=>a.reduce((s,x)=>s+x,0)/a.length;
const rounded=x=>Math.round(x*100)/100;
function run(root,options={}){
 const players=root.players, target=options.targetGap??3;
 if(!Array.isArray(players)||players.length!==1592)throw Error('Expected 1592 master players');
 if(!(target>=0&&target<=6))throw Error('Unreasonable targetGap');
 const groups=new Map(),ids=new Set();
 for(const p of players){
   if(!p.id||ids.has(p.id))throw Error('Duplicate/missing player ID');
   ids.add(p.id);
   const role=p.gameplayPosition||p.position,league=p.league;
   if(!ROLE[role]||!['top14','prod2'].includes(league))throw Error('Unsupported position or league');
   if(!p.attributesV2||Object.keys(p.attributesV2).length!==36||Object.values(p.attributesV2).some(x=>typeof x!=='number'||!Number.isFinite(x)||x<20||x>97))throw Error('Invalid attributesV2');
   const key=role+'|'+league;
   if(!groups.has(key))groups.set(key,[]);
   groups.get(key).push(p);
 }
 const roleReports={}, adjustments=[], candidates=[];
 let affectedPlayers=0;
 for(const [role,keys] of Object.entries(ROLE)){
   const top=groups.get(role+'|top14')||[],pro=groups.get(role+'|prod2')||[];
   if(top.length<10||pro.length<10)throw Error('Insufficient players for '+role);
   const avg=p=>mean(keys.map(k=>p.attributesV2[k]));
   const beforeTop=mean(top.map(avg)),beforePro=mean(pro.map(avg));
   const required=Math.max(0,target-(beforeTop-beforePro));
   // Conservative, symmetric and clearly estimated: only boost TOP14 core attributes;
   // never lower PRO D2, never force individual dominance or change relative ranks.
   const boost=Math.min(3,Math.ceil(required));
   let modified=0,sumApplied=0;
   for(const p of top){
     const changes=keys.map(k=>({attribute:k,from:p.attributesV2[k],to:Math.min(97,p.attributesV2[k]+boost)}))
       .filter(x=>x.to!==x.from).map(x=>({...x,delta:x.to-x.from,kind:'model-estimate',reason:'league-level-prior'}));
     if(changes.length){modified++;affectedPlayers++;sumApplied+=changes.reduce((s,x)=>s+x.delta,0)/keys.length;}
     candidates.push({playerId:p.id,league:'top14',position:role,changes});
   }
   for(const p of pro)candidates.push({playerId:p.id,league:'prod2',position:role,changes:[]});
   const afterTop=beforeTop+sumApplied/top.length;
   roleReports[role]={top14Players:top.length,prod2Players:pro.length,top14MeanBefore:rounded(beforeTop),prod2MeanBefore:rounded(beforePro),gapBefore:rounded(beforeTop-beforePro),suggestedTop14Bonus:boost,top14MeanAfter:rounded(afterTop),gapAfter:rounded(afterTop-beforePro),targetReached:afterTop-beforePro>=target-0.005,top14PlayersChanged:modified};
 }
 if(candidates.length!==1592||new Set(candidates.map(x=>x.playerId)).size!==1592)throw Error('Candidate coverage failure');
 const byLeague={top14:players.filter(p=>p.league==='top14').length,prod2:players.filter(p=>p.league==='prod2').length};
 const evidence={observed2025_2026:players.filter(p=>p.performance2025_2026!=null).length,unobserved2025_2026:players.filter(p=>p.performance2025_2026==null).length};
 return {schema:'rugby-real-v7-league-prior-candidate',asOf:'2026-07-01',status:'candidates-only',targetGap:target,byLeague,evidence,affectedPlayers,roleReports,candidates};
}
if(require.main===module){
 const file=process.argv[2]||SOURCE,dest=process.argv[3];
 const original=fs.readFileSync(file,'utf8'),root=JSON.parse(original);
 const report=run(root);
 if(JSON.stringify(root)!==JSON.stringify(JSON.parse(original)))throw Error('Master mutated');
 if(dest)fs.writeFileSync(dest,JSON.stringify(report,null,2)+'\n');
 console.log(JSON.stringify({schema:report.schema,byLeague:report.byLeague,evidence:report.evidence,affectedPlayers:report.affectedPlayers,roleReports:report.roleReports}));
}
module.exports={run,ROLE};

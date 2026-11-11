'use strict';
// Detailed source profiles use the existing XP/focus budget during the season.
// Their annual transition then applies age effects only, not a second learning grant.
module.exports=function inSeasonDevelopment(){
 const clamp=(n,a,b)=>Math.max(a,Math.min(b,n)),round=n=>Math.round(n*100)/100;
 function detailed(p){return !!p?.attributesV2&&(p.lnrRatingsVersion===1||p.worldRatingsVersion===1&&typeof CDWorldCareer!=='undefined'&&CDWorldCareer.active(S)&&CDWorldCareer.sourcePlayerKnown(p.id));}
 function projected(p){return lnrProjectV12({...p,gameplayPosition:p.gameplayPosition||p.pos});}
 function evolve(p,before,skills,levelDelta,focusDeltas={}){
  if(!levelDelta&&!Object.values(focusDeltas).some(value=>value!==0))return;
  const old=projected({...p,attributesV2:before});
  const weights=lnrProjectionWeightsV12({...p,gameplayPosition:p.gameplayPosition||p.pos});
  p.attributesV2=Object.fromEntries(Object.entries(before).map(([key,value])=>{
   const targeted=Object.entries(focusDeltas).reduce((sum,[focus,delta])=>sum+(Object.hasOwn(weights[focus]||{},key)?delta:0),0);
   return [key,round(clamp(value+levelDelta+targeted,20,97))];
  }));
  const next=projected(p);
  // The specialization bonus is still added by skill(); compensate it here
  // because the same earned point is now present in the real 36 attributes.
  const base=p.skillBase,nextBase=clamp(base+levelDelta,15,99),residual=levelDelta-(nextBase-base);
  p.skills=Object.fromEntries(Object.entries(skills).map(([key,value])=>[key,round(clamp(value+next[key]-old[key]-(focusDeltas[key]||0)-residual,15,99))]));
  p.skillBase=nextBase;
 }
 let installed=false;
 function installHooks(){
  if(installed)return;installed=true;
  const legacyGrow=growPlayer;
  growPlayer=function(p,xp,allowFocus=true){
   if(!Number.isFinite(xp)||xp<=0)return legacyGrow.apply(this,arguments);
   const professionalism=typeof nativePotentialEvolution!=='undefined'?nativePotentialEvolution.traits(p).professionalism:p.hiddenTraitsV2?.professionalism??50;
   const learningXP=xp*(.85+clamp(professionalism,0,100)*.003);
   if(!detailed(p))return legacyGrow.call(this,p,learningXP,allowFocus);
   const attrs={...p.attributesV2},skills={...p.skills},level=p.rating,bonuses={...(p.dev?.specialization?.bonuses||{})};
   const flags={};for(const key of ['lnrRatingsVersion','worldRatingsVersion'])if(Object.hasOwn(p,key)){flags[key]=p[key];delete p[key];}
   let result;try{result=legacyGrow.call(this,p,learningXP,allowFocus);}finally{Object.assign(p,flags);}
   const focus=Object.fromEntries(Object.entries(p.dev?.specialization?.bonuses||{}).map(([key,value])=>[key,value-(bonuses[key]||0)]));
   evolve(p,attrs,skills,p.rating-level,focus);p.dev.inSeasonGrowthSeason=S.season;
   return result;
  };
  const legacyAge=ageDevelopmentPlayer;
  ageDevelopmentPlayer=function(p,completedSeason=S.season){
   if(!detailed(p)||p.dev?.inSeasonGrowthSeason!==completedSeason)return legacyAge.apply(this,arguments);
   const d=p.dev;if(d.lastYear===completedSeason)return;
   const old=p.rating,oldSkills={...p.skills},before=projected(p);
   d.lastYear=completedSeason;
   d.history.push({season:completedSeason,age:p.age,start:d.seasonStart,end:p.rating,minutes:d.minutes,appearances:d.appearances});d.history=d.history.slice(-12);
   const aged=LNR_V11_AGE.step({...p,gameplayPosition:p.gameplayPosition||p.pos,potential:clamp(Math.max(p.rating,d.potential),20,97)},
    {playerId:p.id,age:p.age,season:completedSeason,lastSeason:null},{minutes:0,training:0,injuryWeeks:Math.min(52,p.injury||0),load:0});
   p.attributesV2=aged.player.attributesV2;const after=projected(p);
   const delta=Object.keys(oldSkills).reduce((sum,key)=>sum+after[key]-before[key],0)/Object.keys(oldSkills).length;
   p.rating=clamp(Math.round(old+delta),20,99);const base=p.skillBase,nextBase=clamp(base+p.rating-old,15,99),residual=p.rating-old-(nextBase-base);p.skillBase=nextBase;
   p.skills=Object.fromEntries(Object.entries(oldSkills).map(([key,value])=>[key,round(clamp(value+after[key]-before[key]-residual,15,99))]));
   p.age=aged.state.age;d.potential=Math.max(p.rating,d.potential);d.decline=Math.max(0,Math.min(5,old-p.rating));d.seasonStart=p.rating;
   d.minutes=0;d.appearances=0;d.xp=0;if(d.specialization)d.specialization.xp=0;p.condition=100;p.injury=0;
  };
 }
 return Object.freeze({installHooks});
};

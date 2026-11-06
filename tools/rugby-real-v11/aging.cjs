'use strict';
// Candidate annual evolution of attributes on COPIES. Not connected to legacy rating growth.
// Ages/rates below are game-design parameters, not measured physiological cutoffs.
const C=require('./calibration.cjs');
const CURVES={
 'Pilier gauche':{quick:25,strength:29,technical:30,mental:32},
 'Pilier droit':{quick:25,strength:29,technical:30,mental:32},
 'Talonneur':{quick:24,strength:28,technical:29,mental:31},
 'Deuxième ligne':{quick:25,strength:28,technical:29,mental:31},
 'Troisième ligne':{quick:24,strength:27,technical:28,mental:30},
 'Numéro 8':{quick:24,strength:28,technical:28,mental:31},
 'Demi de mêlée':{quick:24,strength:26,technical:29,mental:32},
 'Demi d’ouverture':{quick:24,strength:26,technical:30,mental:33},
 'Centre':{quick:24,strength:27,technical:28,mental:31},
 'Ailier':{quick:23,strength:26,technical:27,mental:30},
 'Arrière':{quick:24,strength:26,technical:29,mental:32}
};
const PHYSICAL=['acceleration','topSpeed','agility','explosiveness','strength','endurance','jumping'];
const QUICK=new Set(['acceleration','topSpeed','agility','explosiveness','jumping','evasion','kickChase']);
const MENTAL=new Set(['decisions','anticipation','vision','positioning','composure','discipline','teamwork','leadership']);
const clamp=(n,a,b)=>Math.max(a,Math.min(b,n));
function step(p,state,{minutes=0,training=0,injuryWeeks=0,load=0}={}){
 if(!CURVES[p.gameplayPosition]||Object.keys(p.attributesV2||{}).length!==36)throw Error('Invalid ageing profile');
 if(Object.values(p.attributesV2).some(v=>!Number.isFinite(v)||v<20||v>97)||!Number.isFinite(p.potential)||p.potential<20||p.potential>97||!Number.isFinite(p.hiddenTraitsV2?.professionalism))throw Error('Invalid ageing attributes/potential/traits');
 if(state.playerId&&state.playerId!==p.id)throw Error('Ageing identity mismatch');
 const {age,season,lastSeason=null}=state;
 if(lastSeason!==null&&(!Number.isInteger(lastSeason)||lastSeason<1))throw Error('Invalid lastSeason');
 if(!Number.isInteger(age)||age<15||age>60||!Number.isInteger(season)||season<1)throw Error('Invalid age/season');
 if(!Number.isFinite(minutes)||minutes<0||minutes>3500||!Number.isFinite(training)||training<0||training>1||!Number.isFinite(injuryWeeks)||injuryWeeks<0||injuryWeeks>52||!Number.isFinite(load)||load<0||load>100)throw Error('Invalid exposure');
 if(lastSeason!==null&&season<lastSeason)throw Error('Backward season');
 if(lastSeason===season)return {player:C.clone(p),state:{...state},changes:[]};
 const copy=C.clone(p),curve=CURVES[p.gameplayPosition],professionalism=p.hiddenTraitsV2.professionalism;
 const exposure=(training*.6+Math.min(1,minutes/1600)*.4)*(1-injuryWeeks/52)*(1-Math.max(0,load-50)/150);
 const headroom=clamp((p.potential-C.mean(Object.values(p.attributesV2)))/15,0,1);
 const growthIndividual=.85+professionalism*.003,declineIndividual=1.1-professionalism*.002;
 const changes=[];
 for(const [key,from] of Object.entries(p.attributesV2)){
  let group=QUICK.has(key)?'quick':key==='strength'?'strength':key==='endurance'||key==='workRate'?'endurance':MENTAL.has(key)?'mental':'technical';
  const peak=group==='endurance'?27:curve[group];
  const growthRate=group==='quick'?.75:group==='strength'?1.1:group==='endurance'?.9:group==='mental'?.65:.85;
  const maturity=age<peak?clamp((peak-age)/6,.15,1):group==='mental'&&age<peak+6?.12:0;
  const growth=growthRate*maturity*exposure*headroom*growthIndividual;
  const start=group==='quick'?peak+4:group==='strength'?peak+4:group==='endurance'?31:group==='mental'?peak+7:peak+5;
  const rate=group==='quick'?1.05:group==='strength'?.5:group==='endurance'?.7:group==='mental'?.08:.15;
  const decline=age>=start?rate*Math.min(2.5,1+(age-start)/8)*declineIndividual:0;
  const to=C.round(clamp(from+growth-decline,20,97));
  copy.attributesV2[key]=to;
  if(to!==from)changes.push({attribute:key,from,to,kind:'age-and-exposure-gameplay-estimate',group});
 }
 // Potential is an overall development ceiling, not a ceiling for every specialist attribute.
 const avg=C.mean(Object.values(copy.attributesV2)),base=C.mean(Object.values(p.attributesV2));
 if(avg>Math.max(base,p.potential)){
  const allowed=Math.max(base,p.potential)-base,positive=changes.filter(c=>c.to>c.from).reduce((n,c)=>n+c.to-c.from,0),negative=changes.filter(c=>c.to<c.from).reduce((n,c)=>n+c.to-c.from,0);
  const scale=clamp((allowed*36-negative)/Math.max(positive,.001),0,1);
  for(const c of changes)if(c.to>c.from){c.to=C.round(c.from+(c.to-c.from)*scale);copy.attributesV2[c.attribute]=c.to;}
 }
 return {player:copy,state:{playerId:p.id,age:age+1,season,lastSeason:season},changes:changes.filter(c=>c.to!==c.from)};
}
function trajectories(master){
 return Object.keys(CURVES).map(role=>{
  // Controlled equal-start profiles isolate the curve, not reconstructed real player histories.
  let p=C.clone(master.players.find(p=>p.gameplayPosition===role));
  for(const k in p.attributesV2)p.attributesV2[k]=65;p.potential=85;
  p.hiddenTraitsV2.professionalism=65;
  const years=[];for(let age=18;age<=40;age++){
   const a=p.attributesV2;years.push({age,physical:C.round(C.mean(PHYSICAL.map(k=>a[k]))),quickness:C.round(C.mean([...QUICK].map(k=>a[k]))),strength:a.strength,technique:a.passing,decisions:a.decisions,overall:C.round(C.mean(Object.values(a)))});
   p=step(p,{age,season:age-17},{minutes:1600,training:1}).player;
  }
  const peak=[...years].sort((a,b)=>b.overall-a.overall)[0];return {role,kind:'Controlled gameplay trajectory; NOT observed career',peakAge:peak.age,years};
 });
}
module.exports={CURVES,PHYSICAL,step,trajectories};

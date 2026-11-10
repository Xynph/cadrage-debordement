'use strict';
// Career evidence changes the real development ceiling, never the reference
// database or a displayed estimate. No random draws and no writes on reads.
module.exports=function potentialEvolution(){
 const C={ID:0,SEASON:1,START:2,INITIAL:3,WEEKS:4,QUALITY:5,WEEK:6,MATCHES:7,MINUTES:8,FORM:9,WEIGHT:10,BAD:11,REVIEW:12,NET:13,DELTA:14,REASON:15,INJURED:16};
 const indexes=new WeakMap(),seenMatches=new WeakSet();
 const IMPACT={carry:.35,turnover:1.2,'setpiece-win':.8,try:1.2,goal:.5,'hand-fault':-.6,penalty:-.8,card:-1.5};
 const clamp=(n,a,b)=>Math.max(a,Math.min(b,n)),round=n=>Math.round(n*10000)/10000;
 const number=(n,a,b)=>typeof n==='number'&&Number.isFinite(n)&&n>=a&&n<=b;
 const integer=(n,a,b)=>Number.isSafeInteger(n)&&n>=a&&n<=b;
 const object=x=>!!x&&typeof x==='object'&&!Array.isArray(x);
 const validId=id=>typeof id==='string'&&/^[A-Za-z0-9:_-]{1,180}$/.test(id);
 const check=(ok,message)=>{if(!ok)throw Error('Potentiel évolutif : '+message+'.');};
 const hash=text=>{let h=2166136261;for(const c of String(text))h=Math.imul(h^c.charCodeAt(0),16777619);h^=h>>>16;return h>>>0;};
 const week=s=>s.worldMode?.week??s.franceMode?.week??s.round??0;
 const eligible=p=>p&&validId(p.id)&&number(p.age,15,28)&&number(p.rating,15,99)&&number(p.dev?.potential,p.rating,99);
 function pools(s){return [...(s.clubs||[]).map(c=>c.players||[]),s.development?.academy||[],s.economy?.freeAgents||[],s.market||[],...(s.aiRoster?.academies||[]).map(a=>a.players||[]),...(s.nativeAcademy?.centers||[]).map(a=>a.players||[])];}
 function index(st){let value=indexes.get(st);if(!value){value=new Map(st.records.flat().map(r=>[r[C.ID],r]));indexes.set(st,value);}return value;}
 function record(s,p,create=false){
  let st=s?.potentialEvolution;if(!st&&!create)return null;
  if(!st)st=s.potentialEvolution={version:1,records:[]};
  const map=index(st);let r=map.get(p.id);
  if(!r&&create){
   if(map.size>=32000){const active=new Set(pools(s).flat().map(p=>p.id));for(const id of map.keys())if(!active.has(id))map.delete(id);st.records=[];for(const row of map.values()){if(!st.records.length||st.records.at(-1).length===2000)st.records.push([]);st.records.at(-1).push(row);}}
   check(map.size<32000,'capacité de suivi dépassée');
   r=[p.id,s.season,p.rating,p.dev.potential,0,0,-1,0,0,0,0,0,0,0,0,'stable',0];
   if(!st.records.length||st.records.at(-1).length===2000)st.records.push([]);st.records.at(-1).push(r);map.set(p.id,r);
  }
  if(r&&create&&r[C.SEASON]!==s.season){
   check(r[C.SEASON]<s.season,'suivi dans une saison future');
   for(const k of [C.WEEKS,C.QUALITY,C.MATCHES,C.MINUTES,C.FORM,C.WEIGHT,C.INJURED])r[k]=0;
   r[C.SEASON]=s.season;r[C.START]=p.rating;r[C.WEEK]=-1;
  }
  return r;
 }
 function traits(p){
  const result={};for(const key of ['professionalism','ambition','adaptability']){
   const source=p.hiddenTraitsV2?.[key];result[key]=number(source,0,100)?source:35+hash(p.id+':'+key)%51;
  }
  // Generated players use the same identity-backed personality categories as
  // the existing locker-room system; their source object stays unchanged.
  if(!p.hiddenTraitsV2){let h=2166136261;for(const c of p.id)h=Math.imul(h^c.charCodeAt(0),16777619);const kind=(h>>>0)%8;if(kind===0)result.ambition=clamp(result.ambition+15,0,100);if(kind===2)result.professionalism=clamp(result.professionalism+12,0,100);if(kind===5)result.ambition=clamp(result.ambition+10,0,100);if(kind===7)result.adaptability=clamp(result.adaptability+10,0,100);}
  return result;
 }
 function training(s,p,mode){
  if(!eligible(p))return false;
  const r=record(s,p,true),current=week(s);if(r[C.WEEK]===current)return false;
  r[C.WEEK]=current;
  if(p.injury){r[C.INJURED]=Math.min(52,r[C.INJURED]+1);return true;}
  if(mode==='repos')return true;
  if(!['normal','intense'].includes(mode))return false;
  if(r[C.WEEKS]>=52)return false;
  const fatigue=p.physicalLoad?.version===1?p.physicalLoad.fatigue:0;
  const quality=(mode==='intense'?1:.82)*clamp((p.condition??100)/80,.4,1)*clamp(1-fatigue/250,.65,1);
  r[C.WEEKS]++;r[C.QUALITY]=round(r[C.QUALITY]+quality);return true;
 }
 function match(s,l){
  if(!l?.finished||seenMatches.has(l)||!Array.isArray(l.pair)||l.pair.length!==2||!Array.isArray(l.sheets))return false;
  seenMatches.add(l);
  const teams=l.pair.map(id=>s.clubs[id]),strength=teams.map((c,side)=>{const minutes=l.sheets[side]?.minutes||{},list=(c?.players||[]).filter(p=>number(minutes[p.id],1,240));const weight=list.reduce((n,p)=>n+minutes[p.id],0);return weight?list.reduce((n,p)=>n+p.rating*minutes[p.id],0)/weight:65;});
  for(let side=0;side<2;side++){
   const sh=l.sheets[side],people=new Map((teams[side]?.players||[]).map(p=>[p.id,p]));if(!sh)continue;
   const expected=clamp((strength[side]-strength[1-side])*.9+(side===0?3:-3),-25,25);
   const collective=clamp(((l.score?.[side]??0)-(l.score?.[1-side]??0)-expected)/25,-1,1);
   const facts=new Map();
   if(l.potentialEvidence)for(const [id,team,impact]of l.potentialEvidence.rows){if(team===side)facts.set(id,impact);}
   else for(const event of l.events||[]){const a=event.scene;if(!a||a.team!==side||!validId(a.actor))continue;facts.set(a.actor,(facts.get(a.actor)||0)+(IMPACT[a.kind]??0));}
   for(const id of new Set(sh.used||[])){
    const p=people.get(id),minutes=clamp(sh.minutes?.[id]??0,0,240);if(!minutes||!eligible(p))continue;
    const r=record(s,p,true);if(r[C.MATCHES]>=200)continue;
    const contribution=clamp((facts.get(id)||0)/Math.max(1,minutes/20),-1,1);
    const form=clamp(collective*.65+contribution*.35,-1,1);
    r[C.MATCHES]++;r[C.MINUTES]+=minutes;r[C.FORM]=round(r[C.FORM]+form*minutes);r[C.WEIGHT]+=minutes;
   }
  }
  delete l.potentialEvidence;
  return true;
 }
 function action(l,type,meta={}){
  const kind=meta.kind??type,weight=IMPACT[kind]??0,side=meta.team??l.possession,id=meta.actor;
  const sheet=l.sheets?.[side],present=sheet?.on?.includes(id)||kind==='card'&&(sheet?.used?.includes(id)||sheet?.nominated?.includes(id));
  if(!weight||![0,1].includes(side)||!validId(id)||!present||l.developmentRecorded)return false;
  if(!l.potentialEvidence){
   l.potentialEvidence={version:1,rows:[]};
   // Preserve facts already present in a live save made before this feature.
   for(const event of l.events||[]){const a=event.scene;if(!a||![0,1].includes(a.team)||!validId(a.actor)||!IMPACT[a.kind])continue;let row=l.potentialEvidence.rows.find(r=>r[0]===a.actor&&r[1]===a.team);if(!row){row=[a.actor,a.team,0];l.potentialEvidence.rows.push(row);}row[2]=round(clamp(row[2]+IMPACT[a.kind],-500,500));}
  }
  let row=l.potentialEvidence.rows.find(r=>r[0]===id&&r[1]===side);
  if(!row){check(l.potentialEvidence.rows.length<46,'trop de contributeurs dans le match');row=[id,side,0];l.potentialEvidence.rows.push(row);}
  row[2]=round(clamp(row[2]+weight,-500,500));return true;
 }
 function review(s,p,completedSeason,age=p.age){
  const r=record(s,p);if(!r||r[C.SEASON]!==completedSeason||r[C.REVIEW]>=completedSeason)return {delta:0,reason:'stable'};
  const quality=r[C.WEEKS]?r[C.QUALITY]/r[C.WEEKS]:0,form=r[C.WEIGHT]?r[C.FORM]/r[C.WEIGHT]:0;
  const t=traits(p),personality=t.professionalism*.5+t.ambition*.3+t.adaptability*.2;
  const growth=p.rating-r[C.START],gap=p.dev.potential-p.rating,draw=hash((s.careerVariation?.seed??'legacy')+':'+p.id+':'+completedSeason+':potential')%1000/10;
  const young=age<=(p.fam<=3?27:25),sustained=r[C.WEEKS]>=12&&r[C.MATCHES]>=8&&r[C.MINUTES]>=640;
  const strong=sustained&&quality>=.72&&form>=.12&&(growth>=1||gap<=3&&form>=.18)&&r[C.INJURED]<16;
  let delta=0,reason='stable';
  if(young&&strong&&r[C.NET]<8&&draw<20+personality*.55+Math.max(0,form)*12){
   const exceptional=age<=21&&quality>=.88&&form>=.3&&growth>=2&&draw<12+personality*.12;
   delta=Math.min(exceptional?2:1,8-r[C.NET],99-p.dev.potential);reason=delta?'breakthrough':'stable';r[C.BAD]=0;
  }else{
   const poor=age<=28&&r[C.WEEKS]>=16&&quality<.55&&r[C.MINUTES]<320&&growth<=0&&r[C.INJURED]<6;
   r[C.BAD]=poor?Math.min(10,r[C.BAD]+1):0;
   if(r[C.BAD]>=2&&personality<55&&r[C.NET]>-4&&gap>=3&&draw<25+(55-personality)*.5){delta=-Math.min(1,r[C.NET]+4,gap);reason=delta?'stagnation':'stable';}
  }
  if(delta)p.dev.potential=clamp(p.dev.potential+delta,p.rating,99);
  r[C.REVIEW]=completedSeason;r[C.NET]+=delta;r[C.DELTA]=delta;r[C.REASON]=reason;
  return {delta,reason};
 }
 function project(s,id){
  const r=record(s,{id});if(!r||!r[C.REVIEW])return null;
  return {season:r[C.REVIEW],trend:r[C.DELTA]>0?'up':r[C.DELTA]<0?'down':'stable',label:r[C.DELTA]>0?'Potentiel en hausse':r[C.DELTA]<0?'Potentiel revu à la baisse':'Potentiel stable',notice:'Bilan de saison : travail, performances, progression et personnalité. Ce plafond peut évoluer sans être atteint.'};
 }
 function validate(s){
  const evidence=s?.live?.potentialEvidence;
  if(evidence!==undefined){
   check(object(evidence)&&Object.keys(evidence).length===2&&evidence.version===1&&Array.isArray(evidence.rows)&&evidence.rows.length<=46,'faits de match invalides');
   const ids=new Set();for(const row of evidence.rows){check(Array.isArray(row)&&row.length===3&&validId(row[0])&&integer(row[1],0,1)&&number(row[2],-500,500)&&!ids.has(row[0]),'contribution invalide ou répétée');const team=s.clubs?.[s.live?.pair?.[row[1]]],sheet=s.live?.sheets?.[row[1]];check(team?.players?.some(p=>p.id===row[0])&&(sheet?.nominated??sheet?.used??[]).includes(row[0]),'contributeur absent de la feuille de son équipe');ids.add(row[0]);}
  }
  const st=s?.potentialEvolution;if(st===undefined)return true;
  check(object(st)&&Object.keys(st).length===2&&st.version===1&&Array.isArray(st.records)&&st.records.length<=16,'manifeste invalide');
  const seen=new Set();
  for(const block of st.records){check(Array.isArray(block)&&block.length<=2000,'bloc invalide');for(const r of block){
   check(Array.isArray(r)&&r.length===17&&validId(r[C.ID])&&!seen.has(r[C.ID]),'joueur invalide ou répété');seen.add(r[C.ID]);
   check(integer(r[C.SEASON],1,s.season)&&number(r[C.START],15,99)&&number(r[C.INITIAL],15,99)&&integer(r[C.WEEKS],0,52)&&number(r[C.QUALITY],0,r[C.WEEKS]+.001)&&integer(r[C.WEEK],-1,10000)&&(r[C.SEASON]<s.season||r[C.WEEK]<=week(s)),'suivi de travail invalide');
   check(integer(r[C.MATCHES],0,200)&&number(r[C.MINUTES],0,r[C.MATCHES]*240)&&number(r[C.WEIGHT],0,r[C.MATCHES]*240)&&r[C.WEIGHT]===r[C.MINUTES]&&number(r[C.FORM],-r[C.WEIGHT]-.001,r[C.WEIGHT]+.001),'suivi de match invalide');
   check(integer(r[C.BAD],0,10)&&integer(r[C.REVIEW],0,r[C.SEASON])&&integer(r[C.NET],-4,8)&&integer(r[C.DELTA],-1,2)&&['stable','breakthrough','stagnation'].includes(r[C.REASON])&&integer(r[C.INJURED],0,52)&&(r[C.DELTA]>0?r[C.REASON]==='breakthrough':r[C.DELTA]<0?r[C.REASON]==='stagnation':r[C.REASON]==='stable'),'bilan annuel invalide');
  }}
  return true;
 }
 let installed=false;
 function installHooks(){
  if(installed)return;installed=true;
  const oldTraining=developmentTraining;developmentTraining=function(p,mode,...args){training(S,p,mode);return oldTraining.call(this,p,mode,...args);};
  const oldEvent=addEvent;addEvent=function(l,text,type='play',meta={}){action(l,type,meta);return oldEvent.apply(this,arguments);};
  const oldWeek=trainWeek;trainWeek=function(){if(S&&!S.trained)for(const pool of pools(S))for(const p of pool)if(p.injury&&eligible(p))training(S,p,'repos');return oldWeek.apply(this,arguments);};
  const oldMatch=recordDevelopmentMatch;recordDevelopmentMatch=function(l){if(!l.developmentRecorded)match(S,l);return oldMatch.apply(this,arguments);};
  const oldAge=ageDevelopmentPlayer;ageDevelopmentPlayer=function(p,season=S.season){const age=p.age,recorded=p.dev?.lastYear===season,result=oldAge.apply(this,arguments);if(!recorded&&p.dev?.lastYear===season){const outcome=review(S,p,season,age);if(outcome.delta&&S.clubs[S.club]?.players.some(q=>q.id===p.id)&&typeof managerMessage==='function')managerMessage('Évolution du potentiel',p.name+' : '+(outcome.delta>0?'le staff relève ses perspectives après cette saison.':'le staff revoit ses perspectives après une stagnation prolongée.'),'staff','team');}return result;};
 }
 return Object.freeze({training,match,action,review,project,traits,validate,installHooks});
};

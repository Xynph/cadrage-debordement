'use strict';
(function(root){
 const cp=x=>JSON.parse(JSON.stringify(x));
 const esc=x=>String(x??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;','\'':'&#39;'}[c]));
 const clamp=(v,min,max)=>Math.max(min,Math.min(max,v));
 const PLANS=['performance','stabilite','finances','effectif'];
 const DEPTS=['sportif','physique','recrutement','administratif'];
 const MISSIONS=['analyse','recuperation','prospection','organisation'];
 const FACILITIES={video:{cost:12000,bonus:7},medical:{cost:18000,bonus:9},logistique:{cost:10000,bonus:6}};
 const RISKS=['fatigue','finances','profondeur','organisation'];
 const ACTIONS=['surveiller','prevenir','prioriser'];
 const version=1;
 function valid(st){
  return !!st&&st.version===version&&Number.isInteger(st.season)&&st.season>0&&
   Number.isInteger(st.confidence)&&st.confidence>=0&&st.confidence<=100&&
   PLANS.includes(st.priority)&&
   Array.isArray(st.missions)&&st.missions.length<=4&&st.missions.every(m=>m&&DEPTS.includes(m.department)&&MISSIONS.includes(m.mission)&&Number.isInteger(m.season))&&
   Array.isArray(st.projects)&&st.projects.length<=3&&st.projects.every(p=>p&&Object.hasOwn(FACILITIES,p.kind)&&Number.isInteger(p.started)&&typeof p.complete==='boolean')&&
   Array.isArray(st.risks)&&st.risks.length<=4&&st.risks.every(r=>r&&RISKS.includes(r.kind)&&ACTIONS.includes(r.action)&&Number.isInteger(r.season))&&
   Array.isArray(st.history)&&st.history.length<=12&&st.history.every(h=>h&&Number.isInteger(h.season)&&Number.isInteger(h.score))&&
   Number.isInteger(st.spent)&&st.spent>=0&&st.spent<=200000;
 }
 function ensure(s){
  if(!s||!Number.isInteger(s.season)||s.season<1||!Array.isArray(s.clubs)||!s.clubs[s.club])return null;
  if(s.v105to110!==undefined){
   if(!valid(s.v105to110)||s.v105to110.season>s.season)return null;
   return s.v105to110;
  }
  s.v105to110={version,season:s.season,confidence:55,priority:'stabilite',missions:[],projects:[],risks:[],history:[],spent:0};
  return s.v105to110;
 }
 const unlocked=s=>!!s&&!s.live&&s.phase!=='ended';
 function transact(s,action,save){
  const before=cp(s);
  try{
   if(action()!==true)return false;
   if(typeof save==='function'&&save()===false)throw Error('storage');
   return true;
  }catch{
   for(const key of Object.keys(s))delete s[key];
   Object.assign(s,before);
   return false;
  }
 }
 // V105: choose a priority that will be measured at season end.
 function priority(s,kind,save){
  const st=ensure(s);
  if(!st||!unlocked(s)||!PLANS.includes(kind)||st.history.some(h=>h.season===s.season))return false;
  return transact(s,()=>{st.priority=kind;return true},save);
 }
 // V106: staff work orders with one active mission per department and per season.
 function delegate(s,department,mission,save){
  const st=ensure(s);
  if(!st||!unlocked(s)||!DEPTS.includes(department)||!MISSIONS.includes(mission))return false;
  if(st.missions.some(m=>m.department===department&&m.season===s.season))return false;
  if(st.missions.filter(m=>m.season===s.season).length>=4)return false;
  return transact(s,()=>{st.missions.push({department,mission,season:s.season});return true},save);
 }
 // V107: fictitious club investments, charged once, providing board score only (not match boosts).
 function invest(s,kind,save){
  const st=ensure(s),config=FACILITIES[kind],club=s?.clubs?.[s.club];
  if(!st||!unlocked(s)||!config||!Number.isFinite(club?.cash)||club.cash<config.cost||
   st.projects.some(p=>p.kind===kind)||st.projects.length>=3)return false;
  return transact(s,()=>{
   club.cash-=config.cost;st.spent+=config.cost;
   st.projects.push({kind,started:s.season,complete:false});
   return true;
  },save);
 }
 // V108: bounded preventive measures. No automatic player fitness or injuries.
 function mitigate(s,kind,action,save){
  const st=ensure(s),cost=action==='prevenir'?1000:0,club=s?.clubs?.[s.club];
  if(!st||!unlocked(s)||!RISKS.includes(kind)||!ACTIONS.includes(action)||
   st.risks.some(r=>r.kind===kind&&r.season===s.season)||st.risks.filter(r=>r.season===s.season).length>=4||
   !Number.isFinite(club?.cash)||club.cash<cost)return false;
  return transact(s,()=>{
   club.cash-=cost;st.spent+=cost;
   st.risks.push({kind,action,season:s.season});return true;
  },save);
 }
 // V109: read-only signal board, and transparent estimates, not match predictions.
 function readiness(s){
  const st=ensure(s);if(!st)return null;
  const squad=s?.clubs?.[s.club]?.players||[];
  const available=squad.filter(p=>!(Number(p.injury)>0));
  const fit=available.filter(p=>(Number(p.condition)||0)>=70);
  const coverage=available.length?Math.round(100*fit.length/available.length):0;
  const cash=s.clubs[s.club].cash;
  const cashSignal=!Number.isFinite(cash)?'inconnu':cash<0?'critique':cash<25000?'vigilance':'normal';
  const pending=st.projects.filter(p=>!p.complete).length;
  return {available:available.length,fit:fit.length,coverage,cashSignal,pending,
   actions:st.missions.filter(x=>x.season===s.season).length,
   warnings:[...(available.length<23?['Moins de 23 joueurs disponibles']:[]),
    ...(coverage<60?['Condition de l effectif fragile']:[]),
    ...(cashSignal==='critique'?['Tresorerie negative']:[])],
   disclaimer:'Indicateurs de gestion uniquement, sans influence automatique sur les matchs'};
 }
 // V110: deterministic annual score, historical reports and clean transition.
 function closeSeason(s,save){
  const st=ensure(s);
  if(!st||s.phase!=='ended'||st.history.some(h=>h.season===s.season))return false;
  return transact(s,()=>{
   const jobs=st.missions.filter(m=>m.season===s.season).length;
   const proactive=st.risks.filter(r=>r.season===s.season&&r.action==='prevenir').length;
   const completed=st.projects.filter(p=>!p.complete&&p.started<=s.season);
   const completedBonus=completed.reduce((v,p)=>v+FACILITIES[p.kind].bonus,0);
   const financial=s.clubs[s.club].cash;
   const financialScore=Number.isFinite(financial)?(financial>=75000?7:financial>=0?2:-12):0;
   const availability=readiness(s).coverage;
   const priorityBonus=st.priority==='finances'?(financialScore>0?6:-5):
    st.priority==='effectif'?(availability>=70?6:-4):
    st.priority==='performance'?(jobs>=2?6:-3):
    (proactive>=1?5:0);
   const score=clamp(42+jobs*5+proactive*4+completedBonus+financialScore+priorityBonus,0,100);
   completed.forEach(p=>{p.complete=true});
   st.confidence=clamp(Math.round((st.confidence+score)/2),0,100);
   st.history=[{season:s.season,score,confidence:st.confidence,priority:st.priority,
    jobs,proactive,completed:completed.map(p=>p.kind),spent:st.spent,
    cash:Number.isFinite(financial)?financial:null},...st.history].slice(0,12);
   st.spent=0;
   return true;
  },save);
 }
 function rotate(s){
  const st=ensure(s);if(!st||st.season===s.season)return false;
  if(st.season>s.season)return false;
  st.season=s.season;
  st.missions=[];st.risks=[];st.spent=0;
  return true;
 }
 function panel(s){
  const st=ensure(s);if(!st)return '';
  const r=readiness(s),locked=!unlocked(s);
  const button=(action,label,disabled=false)=>'<button type="button" onclick="'+action+'"'+(disabled?' disabled':'')+'>'+esc(label)+'</button>';
  const makeButtons=(list,fn,selected)=>list.map(x=>button(fn+'(\''+x+'\')',x,locked||selected(x))).join(' ');
  return '<section class="cd04-panel" style="padding:18px;margin-top:18px">'+
   '<h2>V105–V110 · Direction sportive</h2><h3>V105 · Feuille de route</h3>'+
   '<p>Priorite : '+esc(st.priority)+' · confiance direction '+st.confidence+'/100</p>'+
   makeButtons(PLANS,'v105Priority',()=>false)+
   '<h3>V106 · Missions du staff</h3>'+
   DEPTS.map(d=>'<p>'+esc(d)+' : '+MISSIONS.map(m=>button('v106Delegate(\''+d+'\',\''+m+'\')',m,locked||st.missions.some(x=>x.department===d&&x.season===s.season))).join(' ')+'</p>').join('')+
   '<h3>V107 · Infrastructures (budgets fictifs)</h3>'+
   Object.keys(FACILITIES).map(k=>'<p>'+esc(k)+' · '+FACILITIES[k].cost+
   ' € '+button('v107Invest(\''+k+'\')','Investir',locked||st.projects.some(p=>p.kind===k))+'</p>').join('')+
   '<h3>V108 · Gestion des risques</h3>'+
   RISKS.map(k=>'<p>'+esc(k)+' : '+ACTIONS.map(a=>button('v108Mitigate(\''+k+'\',\''+a+'\')',a,
    locked||st.risks.some(r=>r.kind===k&&r.season===s.season))).join(' ')+'</p>').join('')+
   '<h3>V109 · Indicateurs de semaine</h3><p>'+r.available+' joueurs disponibles · '+r.coverage+
   '% condition ≥70 · trésorerie '+esc(r.cashSignal)+' · '+r.pending+' projets en cours</p>'+
   '<ul>'+r.warnings.map(w=>'<li>'+esc(w)+'</li>').join('')+'</ul>'+
   '<h3>V110 · Revues annuelles</h3><ul>'+st.history.map(h=>'<li>S'+h.season+
   ' · score '+h.score+'/100 · confiance '+h.confidence+'/100 · '+h.jobs+
   ' missions · '+h.completed.length+' equipements acheves</li>').join('')+'</ul>'+
   '<p class="help">Effets bornés au bureau : budget fictif et indices internes. Pas de bonus caché en match, pas de modification du calendrier.</p></section>';
 }
 function install(g){
  if(!g||typeof g.start!=='function'||typeof g.advanceSeason!=='function'||typeof g.render!=='function')return false;
  if(typeof g.v105Priority==='function')return true;
  const state=()=>typeof S!=='undefined'?S:g.S;
  const save=()=>typeof g.save==='function'&&g.save()!==false;
  const start=g.start;g.start=function(){
   const result=start.apply(this,arguments);
   if(state())ensure(state());return result;
  };
  const advance=g.advanceSeason;g.advanceSeason=function(){
   const s=state();
   if(s?.phase==='ended'&&!s?.v105to110?.history?.some(h=>h.season===s.season)){
    if(!closeSeason(s,save))return false;
   }
   const before=s?.season,result=advance.apply(this,arguments);
   if(result!==false&&state()&&state().season!==before){
    const snapshot=cp(state());
    if(rotate(state())&&!save()){
     for(const k of Object.keys(state()))delete state()[k];
     Object.assign(state(),snapshot);
     return false;
    }
   }
   return result;
  };
  const render=g.render;g.render=function(){
   const result=render.apply(this,arguments),s=state();
   if(s&&typeof document!=='undefined'&&typeof view!=='undefined'&&view==='bureau'){
    const target=document.querySelector('.cd04-content')||document.querySelector('#content');
    if(target?.insertAdjacentHTML)target.insertAdjacentHTML('beforeend',panel(s));
   }
   return result;
  };
  for(const [name,fn] of [['v105Priority',priority],['v106Delegate',delegate],
   ['v107Invest',invest],['v108Mitigate',mitigate]]){
   g[name]=function(){const ok=fn(state(),...arguments,save);if(ok)g.render();return ok;};
  }
  return true;
 }
 const api={valid,ensure,priority,delegate,invest,mitigate,readiness,closeSeason,rotate,panel,install};
 root.CDSportingDirectorV105V110=api;
 if(typeof module==='object'&&module.exports)module.exports=api;
 if(typeof document!=='undefined'&&!root.CDNativeHeadless)install(root);
})(typeof globalThis==='object'?globalThis:this);

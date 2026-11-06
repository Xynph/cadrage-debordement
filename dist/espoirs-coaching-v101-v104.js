'use strict';
(function(root){
 const copy=x=>JSON.parse(JSON.stringify(x));
 const esc=x=>String(x??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
 const cap=(x,a,b)=>Math.max(a,Math.min(b,x));
 const STRATEGIES=['equilibre','minutes','progression','professionnel'];
 const academy=s=>Array.isArray(s?.development?.academy)?s.development.academy:[];
 const pro=s=>s?.clubs?.[s.club]?.players||[];
 const rating=p=>Number.isFinite(p?.rating)?p.rating:0;
 const potential=p=>Number.isFinite(p?.dev?.potential)?p.dev.potential:rating(p);
 const minutes=(s,id)=>Math.max(0,Number(s?.v73Espoirs?.minutes?.[id])||0);
 const valid=st=>!!st&&st.version===1&&Number.isInteger(st.season)&&st.season>0&&
  Array.isArray(st.paths)&&st.paths.length<=35&&st.paths.every(p=>p&&typeof p.id==='string'&&
  STRATEGIES.includes(p.strategy)&&Number.isInteger(p.startRating)&&Number.isInteger(p.createdSeason))&&
  Array.isArray(st.archive)&&st.archive.length<=15&&st.archive.every(h=>h&&Number.isInteger(h.season)&&
  Array.isArray(h.players)&&h.players.length<=35)&&Array.isArray(st.audit)&&st.audit.length<=12;
 function ensure(s){
  if(!s?.development||!Number.isInteger(s.season)||s.season<1)return null;
  if(s.v101to104!==undefined){
   if(!valid(s.v101to104)||s.v101to104.season>s.season)return null;
   return s.v101to104;
  }
  s.v101to104={version:1,season:s.season,paths:[],archive:[],audit:[]};
  return s.v101to104;
 }
 // V101: a read-only cross-module audit. No invented button interactions or match outcomes.
 function audit(s){
  const issues=[],st=ensure(s);
  if(!st)return {ok:false,issues:['Sauvegarde de formation indisponible']};
  const ids=new Set(academy(s).map(p=>p.id));
  const other=s.v82to85;
  if(other?.plans)for(const p of other.plans)if(!ids.has(p.id))issues.push('Objectif individuel sans Espoir actif : '+p.id);
  if(other?.mentors)for(const pair of other.mentors){
   if(!ids.has(pair.youthId))issues.push('Mentorat sans Espoir : '+pair.youthId);
   if(!pro(s).some(p=>p.id===pair.seniorId))issues.push('Mentorat sans professionnel : '+pair.seniorId);
  }
  for(const p of academy(s))if(rating(p)>potential(p))issues.push('Note superieure au potentiel : '+p.id);
  if(s.v95to100?.loads)for(const l of s.v95to100.loads)if(!ids.has(l.id))issues.push('Charge sans Espoir : '+l.id);
  const failures=issues.slice(0,12);
  return {ok:issues.length===0,issues:failures,checked:academy(s).length,
   checks:['objectifs','mentors','potentiels','charges'],excess:Math.max(0,issues.length-failures.length)};
 }
 // V102: manager-chosen personal trajectories; no automatic promotion or transfer.
 function path(s,id,strategy,save){
  const st=ensure(s),p=academy(s).find(x=>x.id===id);
  if(!st||!p||p.age>21||s.live||s.phase==='ended'||!STRATEGIES.includes(strategy))return false;
  if(st.paths.length>=35&&!st.paths.some(x=>x.id===id))return false;
  const old=copy(s);
  try{
   const entry=st.paths.find(x=>x.id===id);
   if(entry){entry.strategy=strategy;entry.updatedSeason=s.season;}
   else st.paths.push({id,createdSeason:s.season,updatedSeason:s.season,strategy,startRating:rating(p)});
   if(typeof save==='function'&&save()===false)throw Error('storage');
   return true;
  }catch{for(const k of Object.keys(s))delete s[k];Object.assign(s,old);return false;}
 }
 // V103: transparent advice derived from observed minutes, potential, existing commitments.
 function advice(s,id){
  const p=academy(s).find(x=>x.id===id);if(!p)return null;
  const played=minutes(s,id),growth=potential(p)-rating(p);
  const hasMentor=(s.v82to85?.mentors||[]).some(m=>m.youthId===id);
  const load=(s.v95to100?.loads||[]).find(x=>x.id===id)?.load;
  const eligible=p.age<=21,condition=Number.isFinite(p.condition)?p.condition:75;
  let strategy='equilibre',reason='Conserver un suivi regulier';
  if(condition<65||load==='intensive'&&condition<75){
   strategy='equilibre';reason='Recuperation prioritaire pour limiter la fatigue';
  }else if(played<240){
   strategy='minutes';reason='Temps de jeu insuffisant sur la saison';
  }else if(growth>=8&&!hasMentor){
   strategy='progression';reason='Potentiel de progression et mentorat a explorer';
  }else if(p.age>=20&&played>=480&&rating(p)>=65){
   strategy='professionnel';reason='Preparer une evaluation pour le groupe professionnel';
  }
  return {id,strategy,reason,minutes:played,growth,condition,eligible,hasMentor,
   current:ensure(s)?.paths.find(x=>x.id===id)?.strategy||null};
 }
 // V104: bounded snapshot of each generation; idempotent per season.
 function closeSeason(s,save){
  const st=ensure(s);
  if(!st||s.phase!=='ended'||st.archive.some(h=>h.season===s.season))return false;
  const old=copy(s);
  try{
   const entries=academy(s).slice(0,35).map(p=>({
    id:String(p.id),name:String(p.name||''),pos:String(p.pos||''),
    age:cap(Number(p.age)||0,0,99),rating:cap(rating(p),0,100),
    potential:cap(potential(p),0,100),minutes:minutes(s,p.id),
    strategy:st.paths.find(q=>q.id===p.id)?.strategy||'equilibre'
   }));
   const graduates=(s.v77Promotions?.promotions||[]).length;
   st.archive=[{season:s.season,players:entries,graduates,
    reputation:Number(s.v95to100?.reputation)||0},...st.archive].slice(0,15);
   st.season=s.season;
   if(typeof save==='function'&&save()===false)throw Error('storage');
   return true;
  }catch{for(const k of Object.keys(s))delete s[k];Object.assign(s,old);return false;}
 }
 function generations(s){const st=ensure(s);return st?st.archive.map(h=>({
  season:h.season,count:h.players.length,graduates:h.graduates,
  averageRating:h.players.length?Math.round(h.players.reduce((a,p)=>a+p.rating,0)/h.players.length):0,
  reputation:h.reputation
 })):[];}
 function panel(s){
  const st=ensure(s);if(!st)return '';
  const checked=audit(s),locked=!!s.live||s.phase==='ended';
  const rows=academy(s).filter(p=>p.age<=21).slice(0,15).map(p=>{
   const a=advice(s,p.id),arg=JSON.stringify(String(p.id)).replace(/"/g,'&quot;');
   const existing=st.paths.find(x=>x.id===p.id);
   return '<tr><td>'+esc(p.name)+'</td><td>'+esc(p.pos)+'</td><td>'+a.minutes+
    '</td><td>'+esc(a.reason)+'</td><td>'+esc(existing?.strategy||'non defini')+
    '</td><td>'+STRATEGIES.map(x=>'<button type="button" onclick="v102Path('+arg+',\''+x+'\')"'+
    (locked?' disabled':'')+'>'+esc(x)+'</button>').join(' ')+'</td></tr>';
  }).join('');
  const hist=generations(s).map(h=>'<li>S'+h.season+' · '+h.count+
   ' Espoirs · '+h.graduates+' promotions · note moyenne '+h.averageRating+
   ' · reputation '+h.reputation+'</li>').join('');
  return '<section class="cd04-panel" style="padding:18px;margin-top:18px"><h2>V101–V104 · Pilotage des generations</h2>'+
   '<h3>V101 · Diagnostic de coherence</h3><p>'+ (checked.ok?'Aucune incoherence detectee':'Alertes detectees : '+checked.issues.length)+
   ' · '+checked.checked+' Espoirs controles. Diagnostic de donnees, pas un test automatise des clics.</p>'+
   '<ul>'+checked.issues.map(x=>'<li>'+esc(x)+'</li>').join('')+'</ul>'+
   '<h3>V102–V103 · Parcours et conseils individualises</h3>'+
   '<div class="tablewrap"><table><thead><tr><th>Espoir</th><th>Poste</th><th>Minutes</th><th>Conseil explique</th><th>Parcours</th><th>Decision</th></tr></thead><tbody>'+
   rows+'</tbody></table></div><p>Le conseil est indicatif : aucune promotion ni mutation automatique.</p>'+
   '<h3>V104 · Memoire des generations</h3><ul>'+(hist||'<li>Aucune saison archivee</li>')+'</ul></section>';
 }
 function install(g){
  if(!g||typeof g.start!=='function'||typeof g.advanceSeason!=='function'||typeof g.render!=='function')return false;
  if(typeof g.v102Path==='function')return true;
  const state=()=>typeof S!=='undefined'?S:g.S;
  const save=()=>typeof g.save==='function'&&g.save()!==false;
  const start=g.start;g.start=function(){const r=start.apply(this,arguments);if(state())ensure(state());return r};
  const year=g.advanceSeason;g.advanceSeason=function(){
   const s=state();
   if(s?.phase==='ended'&&!s?.v101to104?.archive?.some(h=>h.season===s.season)){
    if(!closeSeason(s,save))return false;
   }
   const r=year.apply(this,arguments);
   if(state())ensure(state());
   return r;
  };
  const render=g.render;g.render=function(){
   const r=render.apply(this,arguments),s=state();
   if(s&&typeof document!=='undefined'&&typeof view!=='undefined'&&view==='formation'){
    const target=document.querySelector('.cd04-content [data-da42-page="dossiers"]')||
     document.querySelector('.cd04-content');
    if(target?.insertAdjacentHTML)target.insertAdjacentHTML('beforeend',panel(s));
   }
   return r;
  };
  g.v102Path=(id,strategy)=>{const ok=path(state(),id,strategy,save);if(ok)g.render();return ok};
  return true;
 }
 const api={valid,ensure,audit,path,advice,closeSeason,generations,panel,install};
 root.CDEspoirsCoachingV101V104=api;
 if(typeof module==='object'&&module.exports)module.exports=api;
 if(typeof document!=='undefined')install(root);
})(typeof globalThis==='object'?globalThis:this);

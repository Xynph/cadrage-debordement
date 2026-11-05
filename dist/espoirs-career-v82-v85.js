'use strict';
(function(root){
 const copy=value=>JSON.parse(JSON.stringify(value));
 const safe=value=>String(value).replace(/[&<>"']/g,ch=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[ch]));
 const TARGETS=['minutes','progression','regularite'];
 const GOALS=['promotions','formation','prets'];
 const academy=s=>s?.development?.academy||[];
 const seniors=s=>s?.clubs?.[s.club]?.players||[];
 function valid(st){
  return !!st&&st.version===1&&Number.isInteger(st.season)&&st.season>=1&&
   TARGETS.includes(st.focus)&&GOALS.includes(st.goal)&&
   Array.isArray(st.plans)&&st.plans.length<=3&&
   Array.isArray(st.mentors)&&st.mentors.length<=3&&
   Array.isArray(st.reports)&&st.reports.length<=20&&
   Array.isArray(st.history)&&st.history.length<=4&&
   st.plans.every(p=>p&&typeof p.id==='string'&&TARGETS.includes(p.target)&&Number.isInteger(p.startRating))&&
   st.mentors.every(p=>p&&typeof p.youthId==='string'&&typeof p.seniorId==='string')&&
   st.reports.every(x=>x&&typeof x.id==='string'&&Number.isInteger(x.minutes)&&x.minutes>=0)&&
   st.history.every(h=>h&&Number.isInteger(h.season)&&typeof h.goal==='string'&&typeof h.completed==='boolean');
 }
 function ensure(s){
  if(!s?.development||!root.CDEspoirsPathwaysV78V81?.ensure(s))return null;
  const st=s.v82to85;
  if(st!==undefined){if(!valid(st)||st.season>s.season)return null;if(st.season===s.season)return st;
   s.v82to85={...st,season:s.season,plans:[],mentors:[],reports:[],history:st.history.slice(0,4)};
   return s.v82to85;
  }
  s.v82to85={version:1,season:s.season,focus:'progression',goal:'formation',plans:[],mentors:[],reports:[],history:[]};
  return s.v82to85;
 }
 function transact(s,action,save){
  const old=copy(s);
  try{if(action()!==true)return false;if(save&&save()===false)throw Error('storage');return true}
  catch(e){Object.keys(s).forEach(k=>delete s[k]);Object.assign(s,old);return false}
 }
 function plan(s,id,target,save){
  const st=ensure(s),p=academy(s).find(x=>x.id===id);
  if(!st||s.live||s.phase==='ended'||!p||!TARGETS.includes(target)||st.plans.length>=3||
   st.plans.some(x=>x.id===id)||p.age>21)return false;
  return transact(s,()=>{st.plans.push({id,name:p.name,target,startRating:p.rating,season:s.season});
   s.news.unshift('Formation : objectif '+target+' attribué à '+p.name+'.');s.news=s.news.slice(0,100);return true},save);
 }
 function mentor(s,youthId,seniorId,save){
  const st=ensure(s),p=academy(s).find(x=>x.id===youthId),pro=seniors(s).find(x=>x.id===seniorId);
  if(!st||s.live||s.phase==='ended'||!p||!pro||p.pos!==pro.pos||st.mentors.length>=3||
   st.mentors.some(x=>x.youthId===youthId||x.seniorId===seniorId)||pro.age<23)return false;
  return transact(s,()=>{st.mentors.push({youthId,seniorId,name:p.name,mentor:pro.name,season:s.season});
   s.news.unshift('Formation : '+pro.name+' accompagne '+p.name+'.');s.news=s.news.slice(0,100);return true},save);
 }
 function goal(s,value,save){
  const st=ensure(s);
  if(!st||s.live||s.phase==='ended'||!GOALS.includes(value)||st.history.some(h=>h.season===s.season))return false;
  return transact(s,()=>{st.goal=value;return true},save);
 }
 function report(s){
  const st=ensure(s);if(!st)return [];
  const loans=s.v78to81?.loans||[];
  return loans.map(l=>{
   const p=s.clubs?.[l.to]?.players?.find(x=>x.id===l.id);
   const minutes=Math.max(0,Math.min(100000,Math.round(p?.dev?.minutes||0)));
   return {id:l.id,name:l.name,club:s.clubs[l.to]?.name||'Club',minutes,season:s.season,successful:minutes>=200};
  });
 }
 function seasonEnd(s){
  const st=ensure(s);if(!st||s.phase!=='ended'||st.history.some(h=>h.season===s.season))return false;
  const loans=report(s);
  let achieved=0;
  for(const entry of st.plans){
   const p=academy(s).find(x=>x.id===entry.id),minutes=s.v73Espoirs?.minutes?.[entry.id]||0;
   const ok=!!p&&(entry.target==='minutes'?minutes>=480:
      entry.target==='progression'?p.rating>entry.startRating:
      minutes>=240&&p.condition>=65);
   if(ok)achieved++;
  }
  let bonuses=0;
  for(const pair of st.mentors){
   const youth=academy(s).find(x=>x.id===pair.youthId);
   const pro=seniors(s).find(x=>x.id===pair.seniorId);
   if(!youth||!pro||youth.age>21||youth.rating>=youth.dev?.potential)continue;
   youth.rating=Math.min(youth.dev.potential,youth.rating+1);bonuses++;
  }
  const promotions=s.v77Promotions?.promotions?.length||0;
  const target=st.goal==='promotions'?promotions>=2:st.goal==='prets'?loans.filter(x=>x.successful).length>=1:achieved>=2;
  const reward=target?24000:0;
  if(reward){s.clubs[s.club].cash+=reward;s.ledger.unshift({title:'Objectif centre de formation',amount:reward});s.ledger=s.ledger.slice(0,100)}
  st.reports=loans;
  st.history=[{season:s.season,goal:st.goal,completed:target,planned:st.plans.length,
   achieved,mentorshipBonuses:bonuses,loans:copy(loans),promotions,reward},...st.history].slice(0,4);
  s.news.unshift('Bilan formation S'+s.season+' : '+achieved+' objectif(s) individuels, '+
   bonuses+' mentorat(s), '+loans.length+' pret(s), objectif du centre '+(target?'atteint.':'non atteint.'));
  s.news=s.news.slice(0,100);
  return true;
 }
 function panel(s){
  const st=ensure(s);if(!st)return '';
  const locked=!!s.live||s.phase==='ended';
  const rows=academy(s).slice(0,10).map(p=>{
   const paired=seniors(s).find(q=>q.pos===p.pos&&q.age>=23&&!st.mentors.some(m=>m.seniorId===q.id));
   return '<tr><td>'+safe(p.name)+'</td><td>'+safe(p.pos)+'</td><td>'+p.rating+'</td><td>'+
    '<button type="button" onclick="v82Plan('+JSON.stringify(p.id)+',\'minutes\')"'+(locked||st.plans.some(x=>x.id===p.id)||st.plans.length>=3?' disabled':'')+'>Objectif minutes</button> '+
    '<button type="button" onclick="v82Plan('+JSON.stringify(p.id)+',\'progression\')"'+(locked||st.plans.some(x=>x.id===p.id)||st.plans.length>=3?' disabled':'')+'>Objectif niveau</button></td><td>'+
    (paired?'<button type="button" onclick="v83Mentor('+JSON.stringify(p.id)+','+JSON.stringify(paired.id)+')"'+
      (locked||st.mentors.some(x=>x.youthId===p.id)||st.mentors.length>=3?' disabled':'')+'>Accompagnement par '+safe(paired.name)+'</button>':'Aucun mentor disponible')+
    '</td></tr>';
  }).join('');
  return '<section class="card" style="padding:18px;margin-top:18px"><h2>V82–V85 · Direction du centre de formation</h2>'+
   '<p>V82 · '+st.plans.length+'/3 objectifs individuels · V83 · '+st.mentors.length+'/3 binômes professionnels.</p>'+
   '<div class="tablewrap"><table><thead><tr><th>Espoir</th><th>Poste</th><th>Note</th><th>Objectif</th><th>Mentor</th></tr></thead><tbody>'+rows+'</tbody></table></div>'+
   '<h3>V84 · Bilan des prêts</h3><p>Au changement de saison, recevez un rapport de minutes et de réussite de chaque prêt, sans modifier le moteur des matchs.</p>'+
   '<ul>'+((st.reports.length?st.reports:report(s)).map(x=>'<li>'+safe(x.name)+' — '+safe(x.club)+' — '+x.minutes+' minutes'+
    (x.successful?' · prêt réussi':' · temps de jeu limité')+'</li>').join('')||'<li>Aucun prêt suivi.</li>')+'</ul>'+
   '<h3>V85 · Objectif annuel du centre</h3><p>Une prime fictive de 24 000 € est accordée si l’objectif est atteint.</p>'+
   '<div class="row">'+GOALS.map(k=>'<button type="button" onclick="v85Goal(\''+k+'\')"'+(locked?' disabled':'')+'>'+
     (k==='promotions'?'Promouvoir deux Espoirs':k==='formation'?'Atteindre deux objectifs individuels':'Un prêt à 200 minutes')+
     (st.goal===k?' · actif':'')+'</button>').join('')+'</div>'+
   '<h3>Bilans annuels</h3><ul>'+st.history.map(h=>'<li>S'+h.season+' · '+(h.completed?'objectif atteint':'objectif manqué')+
    ' · '+h.achieved+' plans réussis · '+h.mentorshipBonuses+' bonus mentorat</li>').join('')+'</ul></section>';
 }
 function install(g){
  if(!g||typeof g.start!=='function'||typeof g.advanceSeason!=='function'||typeof g.render!=='function'||
   !root.CDEspoirsPathwaysV78V81)return false;
  if(typeof g.v82Plan==='function')return true;
  const get=()=>typeof S!=='undefined'?S:g.S;
  const save=()=>{if(typeof g.save!=='function')return false;const r=g.save();return r!==false&&(typeof lastSaveError==='undefined'||!lastSaveError)};
  const prevStart=g.start;g.start=function(){const r=prevStart.apply(this,arguments);if(get()){ensure(get());save()}return r};
  const prevYear=g.advanceSeason;g.advanceSeason=function(){
   const s=get(),before=s?.season;
   if(s?.phase==='ended')seasonEnd(s);
   const r=prevYear.apply(this,arguments);
   if(get()&&get().season!==before){ensure(get());save()}
   return r;
  };
  const prevRender=g.render;g.render=function(){
   const r=prevRender.apply(this,arguments),s=get();
   if(s&&typeof document!=='undefined'&&typeof view!=='undefined'&&view==='formation'){
    const target=document.querySelector('.cd04-content [data-da42-page="dossiers"]')||document.querySelector('.cd04-content');
    if(target?.insertAdjacentHTML)target.insertAdjacentHTML('beforeend',panel(s));
   }return r;
  };
  g.v82Plan=(id,target)=>{const ok=plan(get(),id,target,save);if(ok)g.render();return ok};
  g.v83Mentor=(id,proId)=>{const ok=mentor(get(),id,proId,save);if(ok)g.render();return ok};
  g.v85Goal=k=>{const ok=goal(get(),k,save);if(ok)g.render();return ok};
  return true;
 }
 const api={valid,ensure,plan,mentor,goal,report,seasonEnd,panel,install};
 root.CDEspoirsCareerV82V85=api;
 if(typeof module==='object'&&module.exports)module.exports=api;
 if(typeof document!=='undefined')install(root);
})(typeof globalThis==='object'?globalThis:this);

'use strict';
(function(root){
 const REGIONS=['Atlantique','Bretagne','Centre','Sud-Ouest','Mediterranee','Alpes'];
 const IDENTITIES=['mouvement','puissance','defense','polyvalence'];
 const DECISIONS=['accompagner','pret','professionnel','patienter'];
 const safe=x=>String(x??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
 const clean=x=>String(x??'').replace(/[&<>"'\x00-\x1f]/g,' ').slice(0,100);
 const copy=x=>JSON.parse(JSON.stringify(x));
 const hash=str=>{let h=2166136261;for(const c of String(str)){h^=c.charCodeAt(0);h=Math.imul(h,16777619)}return h>>>0};
 const clamp=(n,a,b)=>Math.max(a,Math.min(b,n));
 const youth=s=>s?.development?.academy||[];
 const pro=s=>s?.clubs?.[s.club]?.players||[];
 const potential=p=>Number.isFinite(p?.dev?.potential)?p.dev.potential:(p?.potential??p?.rating??0);
 function valid(st){
  return !!st&&st.version===1&&Number.isInteger(st.season)&&st.season>0&&
   REGIONS.includes(st.region)&&IDENTITIES.includes(st.identity)&&
   Number.isInteger(st.cohesion)&&st.cohesion>=0&&st.cohesion<=100&&
   Number.isInteger(st.reputation)&&st.reputation>=0&&st.reputation<=100&&
   Number.isInteger(st.scouts)&&st.scouts>=0&&st.scouts<=3&&
   Number.isInteger(st.meetings)&&st.meetings>=0&&st.meetings<=3&&
   Array.isArray(st.candidates)&&st.candidates.length<=9&&
   Array.isArray(st.recruits)&&st.recruits.length<=5&&
   Array.isArray(st.loads)&&st.loads.length<=35&&
   Array.isArray(st.ambitions)&&st.ambitions.length<=40&&
   Array.isArray(st.history)&&st.history.length<=15&&
   st.candidates.every(x=>x&&typeof x.id==='string'&&REGIONS.includes(x.region)&&Number.isInteger(x.rating)&&Number.isInteger(x.potential))&&
   st.loads.every(x=>x&&typeof x.id==='string'&&['allegee','equilibree','intensive'].includes(x.load))&&
   st.ambitions.every(x=>x&&typeof x.id==='string'&&DECISIONS.includes(x.decision)&&Number.isInteger(x.season))&&
   st.history.every(x=>x&&Number.isInteger(x.season)&&Number.isInteger(x.reputation));
 }
 function ensure(s){
  if(!s?.development||!Number.isInteger(s.season)||s.season<1)return null;
  const old=s.v95to100;
  if(old!==undefined){
   if(!valid(old)||old.season>s.season)return null;
   if(old.season===s.season)return old;
   s.v95to100={...old,season:s.season,scouts:0,meetings:0,candidates:[],recruits:[],loads:[],ambitions:[],
    history:old.history.slice(0,15)};
   return s.v95to100;
  }
  s.v95to100={version:1,season:s.season,region:'Atlantique',identity:'polyvalence',
   cohesion:55,reputation:45,scouts:0,meetings:0,candidates:[],recruits:[],loads:[],ambitions:[],history:[]};
  return s.v95to100;
 }
 function transact(s,action,save){
  const previous=copy(s);
  try{if(action()!==true)return false;if(save&&save()===false)throw Error('storage');return true}
  catch{for(const key of Object.keys(s))delete s[key];Object.assign(s,previous);return false}
 }
 function unlocked(s){return !!s&&!s.live&&s.phase!=='ended'}
 function cost(s,amount){return Number.isFinite(s?.clubs?.[s.club]?.cash)&&s.clubs[s.club].cash>=amount}
 function discover(s,region,save){
  const st=ensure(s);
  if(!st||!unlocked(s)||!REGIONS.includes(region)||st.scouts>=3||st.candidates.length>=9||!cost(s,3000))return false;
  return transact(s,()=>{
   s.clubs[s.club].cash-=3000;st.scouts++;st.region=region;
   const names=['Aurel','Mael','Nohan','Elian','Tilio','Sacha','Noe','Loan','Yanis','Axel','Ilan','Lino'];
   for(let i=0;i<3;i++){
    const h=hash(s.season+':'+s.club+':'+region+':'+st.scouts+':'+i);
    const id='v95-'+s.season+'-'+s.club+'-'+region.toLowerCase()+'-'+st.scouts+'-'+i;
    const rating=clamp(44+h%18,40,65),upside=12+Math.floor(h/19)%22;
    st.candidates.push({id,name:names[h%names.length]+' '+region+' '+(i+1),region,
     pos:(root.POS&&root.POS.length?root.POS[Math.floor(h/7)%root.POS.length]:(youth(s)[i%Math.max(1,youth(s).length)]?.pos||'10')),
     age:16+(Math.floor(h/31)%3),rating,potential:clamp(rating+upside,rating,95)});
   }
   return true;
  },save);
 }
 function recruit(s,id,save){
  const st=ensure(s),candidate=st?.candidates.find(p=>p.id===id),academy=youth(s);
  if(!st||!unlocked(s)||!candidate||st.recruits.length>=5||academy.length>=35||!cost(s,8000)||
   academy.some(x=>x.id===id)||!academy.length)return false;
  // Use a real academy player as the structural template for native simulation/save compatibility.
  const template=academy.find(x=>x.pos===candidate.pos)||academy[0];
  if(!template||!template.dev||!Number.isInteger(template.fam))return false;
  return transact(s,()=>{
   const p=copy(template);
   p.id=candidate.id;p.name=clean(candidate.name);p.pos=candidate.pos;p.age=candidate.age;p.rating=candidate.rating;
   p.injury=0;p.condition=95;p.academy=true;
   p.dev={...p.dev,potential:candidate.potential,xp:0,seasonStart:candidate.rating};
   s.clubs[s.club].cash-=8000;academy.push(p);st.recruits.push({id,name:p.name,season:s.season,region:candidate.region});
   st.candidates=st.candidates.filter(x=>x.id!==id);return true;
  },save);
 }
 function meeting(s,save){
  const st=ensure(s);
  if(!st||!unlocked(s)||st.meetings>=3||!cost(s,2000))return false;
  return transact(s,()=>{s.clubs[s.club].cash-=2000;st.meetings++;st.cohesion=clamp(st.cohesion+9,0,100);return true},save);
 }
 function load(s,id,value,save){
  const st=ensure(s),p=youth(s).find(x=>x.id===id);
  if(!st||!unlocked(s)||!p||!['allegee','equilibree','intensive'].includes(value)||p.age>21)return false;
  return transact(s,()=>{
   const existing=st.loads.find(x=>x.id===id);
   if(existing)existing.load=value;
   else{if(st.loads.length>=35)return false;st.loads.push({id,load:value})}
   return true;
  },save);
 }
 function ambition(s,id,decision,save){
  const st=ensure(s),p=youth(s).find(x=>x.id===id);
  if(!st||!unlocked(s)||!p||p.age>21||!DECISIONS.includes(decision)||
   st.ambitions.some(x=>x.id===id&&x.season===s.season))return false;
  return transact(s,()=>{
   st.ambitions.push({id,season:s.season,decision,fulfilled:decision==='accompagner'||decision==='patienter'});
   st.cohesion=clamp(st.cohesion+(decision==='patienter'?-2:2),0,100);
   return true;
  },save);
 }
 function identity(s,value,save){
  const st=ensure(s);
  if(!st||!unlocked(s)||!IDENTITIES.includes(value))return false;
  return transact(s,()=>{st.identity=value;return true},save);
 }
 function rankings(s){
  const st=ensure(s);if(!st)return null;
  const history=st.history.map(h=>({season:h.season,reputation:h.reputation,graduates:h.graduates,cohesion:h.cohesion}));
  return {reputation:st.reputation,tier:st.reputation>=80?'reference':st.reputation>=60?'reconnue':
   st.reputation>=40?'en-developpement':'fragile',history};
 }
 function settle(s){
  const st=ensure(s);
  if(!st||s.phase!=='ended'||st.history.some(h=>h.season===s.season))return false;
  return transact(s,()=>{
   let trained=0,overloaded=0,fulfilled=0,broken=0;
   for(const l of st.loads){
    const p=youth(s).find(x=>x.id===l.id);if(!p||!p.dev)continue;
    if(l.load==='allegee'){p.condition=clamp((p.condition||75)+8,35,100);continue}
    if(l.load==='equilibree'){p.condition=clamp((p.condition||75)+3,35,100);continue}
    if(potential(p)>p.rating&&p.injury===0){p.rating=Math.min(potential(p),99,p.rating+1);trained++}
    p.condition=clamp((p.condition||75)-10,35,100);overloaded++;
   }
   for(const a of st.ambitions){
    if(a.fulfilled){fulfilled++;continue}
    const promoted=pro(s).some(p=>p.id===a.id);
    const loan=(s.v78to81?.loans||[]).some(l=>l.id===a.id);
    a.fulfilled=a.decision==='professionnel'?promoted:a.decision==='pret'?loan:false;
    if(a.fulfilled)fulfilled++;else broken++;
   }
   const graduates=(s.v77Promotions?.promotions||[]).length;
   const completed=(s.v73Espoirs?.results||[]).filter(m=>Array.isArray(m.pair)&&m.pair.includes(s.club)).length;
   const performance=completed>0?Math.min(5,Math.round(completed/5)):0;
   st.cohesion=clamp(st.cohesion+(fulfilled-broken)*2-Math.ceil(overloaded/4),0,100);
   st.reputation=clamp(st.reputation+graduates*3+performance+Math.floor((st.cohesion-50)/12)-broken*2,0,100);
   st.history=[{season:s.season,reputation:st.reputation,cohesion:st.cohesion,
    graduates,trained,fulfilled,broken,identity:st.identity},...st.history].slice(0,15);
   return true;
  });
 }
 function panel(s){
  const st=ensure(s);if(!st)return '';
  const locked=!unlocked(s),js=x=>JSON.stringify(x).replace(/"/g,'&quot;');
  const prospects=st.candidates.slice(0,9).map(p=>'<li>'+safe(p.name)+' · '+safe(p.pos)+' · '+p.rating+'/'+
   p.potential+' · '+safe(p.region)+' <button onclick="v95Recruit('+js(p.id)+')"'+(locked?' disabled':'')+
   '>Recruter · 8 000 €</button></li>').join('');
  const youths=youth(s).filter(p=>p.age<=21).slice(0,12).map(p=>{
   const chosen=st.loads.find(x=>x.id===p.id)?.load||'equilibree';
   return '<li>'+safe(p.name)+' · '+safe(p.pos)+' · charge '+chosen+' · '+
    ['allegee','equilibree','intensive'].map(a=>'<button onclick="v97Load('+js(p.id)+',\''+a+'\')"'+(locked?' disabled':'')+'>'+a+'</button>').join(' ')+
    ' · '+DECISIONS.map(a=>'<button onclick="v98Ambition('+js(p.id)+',\''+a+'\')"'+
    (locked||st.ambitions.some(x=>x.id===p.id&&x.season===s.season)?' disabled':'')+'>'+a+'</button>').join(' ')+
   '</li>'}).join('');
  return '<section class="cd04-panel" style="padding:18px;margin-top:18px"><h2>V95–V100 · Stratégie de formation</h2>'+
   '<h3>V95 · Détection régionale</h3>'+REGIONS.map(x=>'<button onclick="v95Scout(\''+x+'\')"'+
   (locked||st.scouts>=3?' disabled':'')+'>'+x+' · 3 000 €</button>').join(' ')+
   '<p>Sessions : '+st.scouts+'/3 · Recrues : '+st.recruits.length+'/5</p><ul>'+prospects+'</ul>'+
   '<h3>V96 · Vie du groupe</h3><p>Cohésion : '+st.cohesion+'/100 · Réunions : '+st.meetings+
   '/3 <button onclick="v96Meeting()"'+(locked||st.meetings>=3?' disabled':'')+'>Réunion collective · 2 000 €</button></p>'+
   '<h3>V97 · Préparation physique et V98 · Ambitions</h3><ul>'+youths+'</ul>'+
   '<h3>V99 · Identité de jeu</h3><p>'+IDENTITIES.map(x=>'<button onclick="v99Identity(\''+x+'\')"'+
   (locked?' disabled':'')+'>'+x+(st.identity===x?' (actif)':'')+'</button>').join(' ')+'</p>'+
   '<h3>V100 · Réputation du centre</h3><p>'+st.reputation+'/100 · '+safe(rankings(s).tier)+
   '</p><ul>'+st.history.slice(0,10).map(h=>'<li>S'+h.season+' · '+h.graduates+' promus · réputation '+
   h.reputation+' · cohésion '+h.cohesion+'</li>').join('')+'</ul>'+
   '<p class="help">Candidats et réputation entièrement fictifs. Les promesses ne déclenchent pas de transfert ni de promotion automatique. Développement physique soldé à la fin de saison.</p></section>';
 }
 function install(g){
  if(!g||typeof g.start!=='function'||typeof g.advanceSeason!=='function'||typeof g.render!=='function')return false;
  if(typeof g.v95Scout==='function')return true;
  const state=()=>typeof S!=='undefined'?S:g.S;
  const save=()=>{if(typeof g.save!=='function')return false;return g.save()!==false&&(typeof lastSaveError==='undefined'||!lastSaveError)};
  const oldStart=g.start;g.start=function(){const r=oldStart.apply(this,arguments);if(state()){ensure(state());save()}return r};
  const oldYear=g.advanceSeason;g.advanceSeason=function(){
   const s=state(),old=s?.season;
   if(s?.phase==='ended'&&!s?.v95to100?.history?.some(x=>x.season===s.season)){
    const before=copy(s);if(!settle(s)||!save()){Object.keys(s).forEach(k=>delete s[k]);Object.assign(s,before);return false}
   }
   const result=oldYear.apply(this,arguments);
   if(state()&&state().season!==old){ensure(state());save()}return result;
  };
  const oldRender=g.render;g.render=function(){const r=oldRender.apply(this,arguments),s=state();
   if(s&&typeof document!=='undefined'&&typeof view!=='undefined'&&view==='formation'){
    const target=document.querySelector('.cd04-content [data-da42-page="dossiers"]')||document.querySelector('.cd04-content');
    if(target?.insertAdjacentHTML)target.insertAdjacentHTML('beforeend',panel(s));
   }return r};
  for(const [name,fn] of [['v95Scout',discover],['v95Recruit',recruit],['v96Meeting',meeting],
   ['v97Load',load],['v98Ambition',ambition],['v99Identity',identity]]){
    g[name]=function(){const ok=fn(state(),...arguments,save);if(ok)g.render();return ok};
  }
  return true;
 }
 const api={valid,ensure,discover,recruit,meeting,load,ambition,identity,rankings,settle,panel,install};
 root.CDEspoirsStrategyV95V100=api;
 if(typeof module==='object'&&module.exports)module.exports=api;
 if(typeof document!=='undefined')install(root);
})(typeof globalThis==='object'?globalThis:this);

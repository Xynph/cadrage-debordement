'use strict';
(function(root){
  const cp=x=>JSON.parse(JSON.stringify(x));
  const esc=x=>String(x??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;','\'':'&#39;'}[c]));
  const clamp=(n,a,b)=>Math.max(a,Math.min(b,n));
  const PRICES={accessible:12,equilibree:20,premium:30};
  const CAMPAIGNS={locale:{cost:3000,boost:9},familiale:{cost:5000,boost:14},numerique:{cost:4000,boost:11}};
  const EVENTS={ecoles:{cost:1500,gain:7},associations:{cost:2000,gain:9},portesOuvertes:{cost:3000,gain:12}};
  const SERVICES={simple:{cost:0,bonus:0},confort:{cost:2500,bonus:5},premium:{cost:6000,bonus:10}};
  const has=(obj,k)=>Object.prototype.hasOwnProperty.call(obj,k);
  const integer=(x,a,b)=>Number.isInteger(x)&&x>=a&&x<=b;
  const present=x=>x&&typeof x==='object'&&!Array.isArray(x);
  function valid(st){
    return present(st)&&st.version===1&&integer(st.season,1,10000)&&integer(st.sentiment,0,100)&&
      has(PRICES,st.price)&&integer(st.subscribers,0,100000)&&
      (st.campaign===null||(present(st.campaign)&&has(CAMPAIGNS,st.campaign.kind)&&integer(st.campaign.season,1,10000)))&&
      (st.service===null||(present(st.service)&&has(SERVICES,st.service.kind)&&integer(st.service.season,1,10000)))&&
      Array.isArray(st.community)&&st.community.length<=2&&st.community.every(x=>present(x)&&has(EVENTS,x.kind)&&integer(x.season,1,10000))&&
      Array.isArray(st.ledger)&&st.ledger.length<=26&&st.ledger.every(x=>present(x)&&integer(x.round,1,26)&&integer(x.attendance,0,100000)&&integer(x.revenue,0,10000000))&&
      Array.isArray(st.history)&&st.history.length<=12&&st.history.every(x=>present(x)&&integer(x.season,1,10000)&&integer(x.sentiment,0,100)&&integer(x.totalAttendance,0,2600000))&&
      integer(st.commercialCash,0,10000000);
  }
  function club(s){return s?.clubs?.[s.club]}
  function capacity(s){
    const n=Number(club(s)?.stadium?.capacity??club(s)?.stadiumCapacity);
    return Number.isInteger(n)&&n>=500&&n<=100000?n:12000;
  }
  function ensure(s){
    if(!s||!integer(s.season,1,10000)||!club(s))return null;
    if(s.v111to116!==undefined)return valid(s.v111to116)&&s.v111to116.season<=s.season?s.v111to116:null;
    s.v111to116={version:1,season:s.season,sentiment:50,price:'equilibree',subscribers:0,
      campaign:null,service:null,community:[],ledger:[],history:[],commercialCash:0};
    return s.v111to116;
  }
  const open=s=>!!s&&!s.live&&s.phase!=='ended';
  function transact(s,fn,save){
    const old=cp(s);
    try{
      if(fn()!==true){for(const k of Object.keys(s))delete s[k];Object.assign(s,old);return false}
      if(typeof save==='function'&&save()===false)throw Error('storage');
      return true;
    }catch(e){
      for(const k of Object.keys(s))delete s[k];Object.assign(s,old);return false;
    }
  }
  const ready=s=>{const st=ensure(s);return st&&st.season===s.season&&open(s)?st:null};
  function forecast(s){
    const st=ensure(s);if(!st)return null;
    const seats=capacity(s);
    const price=PRICES[st.price];
    const campaign=st.campaign?.season===s.season?CAMPAIGNS[st.campaign.kind].boost:0;
    const service=st.service?.season===s.season?SERVICES[st.service.kind].bonus:0;
    const discount=st.price==='accessible'?10:st.price==='premium'?-15:0;
    const demand=clamp(Math.round(35+st.sentiment*0.5+campaign+service+discount),15,98);
    const expectedAttendance=Math.min(seats,Math.round(seats*demand/100));
    const expectedTicketRevenue=expectedAttendance*price;
    return {capacity:seats,price,demand,expectedAttendance,expectedTicketRevenue,
      explanation:'Projection fictive de gestion, non issue de la billetterie ni du calendrier officiel'};
  }
  // V112: season price policy, constrained to three fixed symbolic tariff tiers.
  function setPrice(s,kind,save){
    const st=ready(s);if(!st||!has(PRICES,kind))return false;
    return transact(s,()=>{st.price=kind;return true},save);
  }
  // V113: one campaign per season, paid in fictional club cash.
  function campaign(s,kind,save){
    const st=ready(s),config=has(CAMPAIGNS,kind)?CAMPAIGNS[kind]:null,c=club(s);
    if(!st||!config||st.campaign?.season===s.season||!Number.isFinite(c.cash)||c.cash<config.cost)return false;
    return transact(s,()=>{
      c.cash-=config.cost;st.campaign={kind,season:s.season,cost:config.cost};
      st.subscribers=clamp(st.subscribers+Math.round(capacity(s)*config.boost/120),0,capacity(s));
      return true;
    },save);
  }
  // V114: two community activities per season, each type once.
  function community(s,kind,save){
    const st=ready(s),cfg=has(EVENTS,kind)?EVENTS[kind]:null,c=club(s);
    if(!st||!cfg||st.community.length>=2||st.community.some(e=>e.kind===kind)||
       !Number.isFinite(c.cash)||c.cash<cfg.cost)return false;
    return transact(s,()=>{
      c.cash-=cfg.cost;st.community.push({kind,season:s.season,cost:cfg.cost});
      st.sentiment=clamp(st.sentiment+cfg.gain,0,100);return true;
    },save);
  }
  // V115: one matchday-service configuration per season, no engine effects.
  function service(s,kind,save){
    const st=ready(s),cfg=has(SERVICES,kind)?SERVICES[kind]:null,c=club(s);
    if(!st||!cfg||st.service?.season===s.season||!Number.isFinite(c.cash)||c.cash<cfg.cost)return false;
    return transact(s,()=>{
      c.cash-=cfg.cost;st.service={kind,season:s.season,cost:cfg.cost};return true;
    },save);
  }
  // V111: commercially record a MANAGER-ENTERED fictional attendance, not an official result.
  // Strictly unique arbitrary slot 1..26; no match fixture or outcome is modified.
  function record(s,round,attendance,save){
    const st=ready(s),c=club(s),seats=capacity(s);
    if(!st||!integer(round,1,26)||!integer(attendance,0,seats)||
       st.ledger.some(x=>x.round===round)||st.ledger.length>=26||!Number.isFinite(c.cash))return false;
    const projected=forecast(s);
    return transact(s,()=>{
      const revenue=attendance*PRICES[st.price];
      c.cash+=revenue;st.commercialCash=clamp(st.commercialCash+revenue,0,10000000);
      st.ledger.push({round,attendance,revenue,price:st.price});
      st.sentiment=clamp(st.sentiment+(attendance>=projected.expectedAttendance?2:-1),0,100);
      return true;
    },save);
  }
  // V116: one idempotent yearly review with bounded archive and no match/calendar edits.
  function closeSeason(s,save){
    const st=ensure(s);
    if(!st||st.season!==s.season||s.phase!=='ended'||st.history.some(h=>h.season===s.season))return false;
    return transact(s,()=>{
      const attendance=st.ledger.reduce((n,e)=>n+e.attendance,0);
      const revenue=st.ledger.reduce((n,e)=>n+e.revenue,0);
      const satisfaction=st.sentiment;
      st.history=[{season:s.season,sentiment:satisfaction,subscribers:st.subscribers,
        rounds:st.ledger.length,totalAttendance:attendance,totalRevenue:revenue,
        price:st.price,community:st.community.length},...st.history].slice(0,12);
      return true;
    },save);
  }
  function rotate(s,save){
    const st=ensure(s);
    if(!st||st.season===s.season||st.season>s.season)return false;
    return transact(s,()=>{
      st.season=s.season;st.ledger=[];st.campaign=null;st.service=null;st.community=[];
      st.commercialCash=0;st.subscribers=Math.floor(st.subscribers*0.85);
      return true;
    },save);
  }
  function panel(s){
    const st=ensure(s);if(!st)return '';
    const f=forecast(s),locked=!open(s)||st.season!==s.season;
    const nextRound=Array.from({length:26},(_,i)=>i+1).find(i=>!st.ledger.some(e=>e.round===i));
    const btn=(call,label,disabled)=>'<button type="button" onclick="'+call+'"'+(disabled?' disabled':'')+'>'+esc(label)+'</button>';
    return '<section class="cd04-panel" style="padding:18px;margin-top:18px">'+
      '<h2>V111–V116 · Supporters et accueil</h2>'+
      '<h3>V111 · Affluence prévisionnelle</h3><p>Jauge '+f.capacity+
      ' · demande estimée '+f.demand+' % · '+f.expectedAttendance+' spectateurs prévus.'+
      ' Simulation interne, aucune donnée officielle.</p>'+ 
      (nextRound?btn('v111Record('+nextRound+','+f.expectedAttendance+')',
        'Simuler l accueil commercial '+nextRound+' ('+f.expectedAttendance+' visiteurs fictifs)',locked):'')+
      '<h3>V112 · Billetterie fictive</h3>'+
      Object.keys(PRICES).map(k=>btn('v112Price(\''+k+'\')',k+' · '+PRICES[k]+' €',
        locked)).join(' ')+
      '<h3>V113 · Campagne abonnés</h3><p>'+st.subscribers+' abonnés suivis</p>'+
      Object.keys(CAMPAIGNS).map(k=>btn('v113Campaign(\''+k+'\')',k+' · '+CAMPAIGNS[k].cost+' €',
        locked||st.campaign?.season===s.season)).join(' ')+
      '<h3>V114 · Vie locale</h3>'+
      Object.keys(EVENTS).map(k=>btn('v114Community(\''+k+'\')',k+' · '+EVENTS[k].cost+' €',
        locked||st.community.length>=2||st.community.some(e=>e.kind===k))).join(' ')+
      '<h3>V115 · Services aux spectateurs</h3>'+
      Object.keys(SERVICES).map(k=>btn('v115Service(\''+k+'\')',k+' · '+SERVICES[k].cost+' €',
        locked||st.service?.season===s.season)).join(' ')+
      '<p>La saisie des affluences fictives par créneau (1–26) reste accessible via API record ; '+
      'pas de simulation de match ni de prétention à des statistiques officielles.</p>'+
      '<h3>V116 · Fidélité et bilans</h3><p>Satisfaction : '+st.sentiment+'/100 · recettes de saison '+
      st.ledger.reduce((n,x)=>n+x.revenue,0)+' € fictifs</p><ul>'+
      st.history.map(h=>'<li>S'+h.season+' · '+h.totalAttendance+' spectateurs simulés · '+
        h.totalRevenue+' € · satisfaction '+h.sentiment+'/100</li>').join('')+
      '</ul></section>';
  }
  function install(g){
    if(!g||typeof g.start!=='function'||typeof g.advanceSeason!=='function'||typeof g.render!=='function')return false;
    if(typeof g.v112Price==='function')return true;
    const state=()=>typeof S!=='undefined'?S:g.S;
    const save=()=>typeof g.save==='function'&&g.save()!==false;
    const start=g.start;g.start=function(){
      const result=start.apply(this,arguments);
      if(result!==false&&state())ensure(state());return result;
    };
    const next=g.advanceSeason;g.advanceSeason=function(){
      const s=state();
      if(s?.phase==='ended'){
        const st=ensure(s);
        if(!st||!st.history.some(h=>h.season===s.season)){
          if(!closeSeason(s,save))return false;
        }
      }
      const result=next.apply(this,arguments);
      if(result!==false&&state()&&state().v111to116?.season<state().season){
        if(!rotate(state(),save))return false;
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
    for(const [name,fn] of [['v112Price',setPrice],['v113Campaign',campaign],
      ['v114Community',community],['v115Service',service],['v111Record',record]]){
      g[name]=function(){const ok=fn(state(),...arguments,save);if(ok)g.render();return ok};
    }
    return true;
  }
  const api={valid,ensure,capacity,forecast,setPrice,campaign,community,service,record,closeSeason,rotate,panel,install};
  root.CDFanExperienceV111V116=api;
  if(typeof module==='object'&&module.exports)module.exports=api;
  if(typeof document!=='undefined')install(root);
})(typeof globalThis==='object'?globalThis:this);

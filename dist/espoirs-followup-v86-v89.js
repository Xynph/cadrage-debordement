'use strict';
(function(root){
  const clone=x=>JSON.parse(JSON.stringify(x));
  const escape=x=>String(x).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const finite=x=>Number.isFinite(x)?x:0;
  const own=s=>s?.clubs?.[s.club]?.players||[];
  const academy=s=>s?.development?.academy||[];
  const persons=s=>[...academy(s),...own(s)];
  const currentMinutes=(s,id)=>Math.max(0,Math.min(50000,Math.floor(finite(s?.v73Espoirs?.minutes?.[id]))));
  const potential=p=>Math.max(finite(p?.rating),finite(p?.dev?.potential??p?.potential??p?.rating));
  const valid=st=>!!st&&st.version===1&&Number.isInteger(st.season)&&st.season>=1&&
    Array.isArray(st.targets)&&st.targets.length<=30&&Array.isArray(st.history)&&st.history.length<=5&&
    Array.isArray(st.events)&&st.events.length<=150&&
    st.targets.every(x=>x&&typeof x.id==='string'&&x.id.length<=100&&Number.isInteger(x.minutes)&&x.minutes>=80&&x.minutes<=2400)&&
    st.events.every(x=>x&&typeof x.id==='string'&&typeof x.type==='string'&&Number.isInteger(x.season));
  function ensure(s){
    if(!s?.development||!Number.isInteger(s.season)||s.season<1)return null;
    const old=s.v86to89;
    if(old!==undefined){
      if(!valid(old)||old.season>s.season)return null;
      if(old.season===s.season)return old;
      const snapshot={season:old.season,targets:old.targets.map(x=>({...x,achieved:currentMinutes(s,x.id)>=x.minutes}))};
      s.v86to89={...old,season:s.season,targets:[],
        history:[snapshot,...old.history].slice(0,5)};
      return s.v86to89;
    }
    s.v86to89={version:1,season:s.season,targets:[],history:[],events:[]};
    return s.v86to89;
  }
  function transact(s,fn,save){
    const previous=clone(s);
    try{if(fn()!==true)return false;if(save&&save()===false)throw Error('storage');return true}
    catch{for(const key of Object.keys(s))delete s[key];Object.assign(s,previous);return false}
  }
  function target(s,id,minutes,save){
    const st=ensure(s),p=persons(s).find(x=>x.id===id);
    if(!st||!p||!Number.isInteger(minutes)||minutes<80||minutes>2400||
      s.live||s.phase==='ended'||st.targets.length>=30)return false;
    return transact(s,()=>{
      st.targets=st.targets.filter(x=>x.id!==id);
      st.targets.push({id,name:p.name,pos:p.pos,minutes,start:currentMinutes(s,id),
        rating:finite(p.rating),season:s.season});
      return true;
    },save);
  }
  function minutesReport(s){
    const st=ensure(s);if(!st)return [];
    return st.targets.map(t=>{
      const p=persons(s).find(x=>x.id===t.id);
      const played=currentMinutes(s,t.id);
      const elapsed=Math.max(0,Math.min(26,Math.floor(finite(s.round))));
      const expected=t.minutes*elapsed/26;
      return {id:t.id,name:t.name,position:t.pos,target:t.minutes,played,
        remaining:Math.max(0,t.minutes-played),
        progress:Math.min(100,Math.round(played/t.minutes*100)),
        ratingChange:p?Math.round(finite(p.rating)-t.rating):null,
        alert:played+80*Math.max(0,26-elapsed)<t.minutes?'impossible':
          played+80<expected?'retard':played>=t.minutes?'atteint':'normal'};
    });
  }
  function succession(s){
    const roster=own(s),young=persons(s),positions=[...new Set([...roster,...academy(s)].map(x=>x.pos).filter(Boolean))];
    return positions.map(pos=>{
      const incumbents=roster.filter(p=>p.pos===pos).sort((a,b)=>finite(b.rating)-finite(a.rating));
      const prospects=young.filter(p=>p.pos===pos&&Number.isInteger(p.age)&&p.age<=24)
        .sort((a,b)=>potential(b)-potential(a)||finite(b.rating)-finite(a.rating)).slice(0,3);
      const veteran=incumbents.find(p=>p.age>=32)||null;
      return {pos,starter:incumbents[0]?.name||null,starterId:incumbents[0]?.id||null,
        risk:incumbents.length===0?'poste-vacant':veteran&&incumbents[0]===veteran?'retraite-a-anticiper':
          incumbents.length===1?'profondeur-limitee':'couvert',
        successors:prospects.map(p=>({id:p.id,name:p.name,age:p.age,rating:finite(p.rating),potential:potential(p)}))};
    });
  }
  function loanOptions(s,id){
    const st=ensure(s),p=own(s).find(x=>x.id===id);
    if(!st||!p||p.age>23||!root.CDEspoirsPathwaysV78V81?.eligiblePro(s).some(x=>x.id===id))return [];
    return (s.clubs||[]).map((club,to)=>{
      if(to===s.club||!club?.players||club.players.length>=42)return null;
      const competition=club.players.filter(x=>x.pos===p.pos).sort((a,b)=>finite(b.rating)-finite(a.rating));
      const stronger=competition.filter(x=>finite(x.rating)>=finite(p.rating)).length;
      const depth=competition.length;
      const projected=Math.max(0,Math.min(26,Math.round(23-stronger*7-depth*2)));
      const expectedMinutes=projected*65;
      const score=Math.round(expectedMinutes/20+Math.max(0,75-finite(p.rating))*0.1);
      return {to,club:club.name,expectedMinutes,expectedMatches:projected,competition:depth,
        score,warning:expectedMinutes<480?'temps-de-jeu-faible':null};
    }).filter(Boolean).sort((a,b)=>b.score-a.score||a.to-b.to);
  }
  function career(s,id){
    const st=ensure(s);if(!st)return null;
    const p=persons(s).find(x=>x.id===id)||
      (s?.v78to81?.loans||[]).map(l=>s.clubs?.[l.to]?.players?.find(x=>x.id===id)).find(Boolean);
    const events=st.events.filter(x=>x.id===id);
    for(const h of s.v77Promotions?.history||[])
      for(const q of h.promotions||[])if(q.playerId===id)
        events.push({id,type:'premier-contrat',season:h.season,text:'Passage professionnel'});
    for(const q of s.v77Promotions?.promotions||[])if(q.playerId===id)
      events.push({id,type:'premier-contrat',season:q.season,text:'Passage professionnel'});
    for(const h of s.v78to81?.history||[])
      for(const q of h.loans||[])if(q.id===id)
        events.push({id,type:'pret',season:h.season,text:'Prêt terminé'});
    for(const q of s.v78to81?.loans||[])if(q.id===id)
      events.push({id,type:'pret',season:q.season,text:'Prêt en cours'});
    return {id,name:p?.name||events.find(x=>x.name)?.name||id,
      currentClub:s?.clubs?.[s.club]?.players?.some(x=>x.id===id)?s.clubs[s.club].name:
        s?.v78to81?.loans?.find(x=>x.id===id)?s.clubs[s.v78to81.loans.find(x=>x.id===id).to]?.name:null,
      age:p?.age??null,rating:p?.rating??null,
      events:events.sort((a,b)=>a.season-b.season||a.type.localeCompare(b.type)).slice(-50)};
  }
  function record(s,id,type,detail,save){
    const st=ensure(s);if(!st||!persons(s).some(x=>x.id===id)||!['formation','promotion','bilan','recrutement'].includes(type)||s.live)return false;
    const text=String(detail||'').slice(0,120).replace(/[<>\x00-\x1f]/g,' ');
    return transact(s,()=>{
      st.events.push({id,type,season:s.season,text});
      st.events=st.events.slice(-150);return true;
    },save);
  }
  function panel(s){
    const st=ensure(s);if(!st)return '';
    const rows=minutesReport(s).map(x=>'<tr><td>'+escape(x.name)+'</td><td>'+x.played+' / '+x.target+
      '</td><td>'+x.progress+' %</td><td>'+escape(x.alert)+'</td></tr>').join('');
    const paths=succession(s).filter(x=>x.risk!=='couvert').slice(0,12)
      .map(x=>'<li>'+escape(x.pos)+' : '+escape(x.risk)+' · '+escape(x.successors[0]?.name||'aucune relève')+'</li>').join('');
    const seniors=own(s).filter(p=>p.age<=23).slice(0,8);
    const dest=seniors.map(p=>{const o=loanOptions(s,p.id)[0];return o?'<li>'+escape(p.name)+
      ' : '+escape(o.club)+' · '+o.expectedMinutes+' min estimées</li>':''}).join('');
    return '<section class="cd04-panel" style="padding:18px;margin-top:18px"><h2>V86–V89 · Suivi des talents</h2>'+
      '<h3>Objectifs de minutes et alertes</h3><table><thead><tr><th>Joueur</th><th>Minutes</th><th>Objectif</th><th>Alerte</th></tr></thead><tbody>'+rows+'</tbody></table>'+
      '<h3>Relève par poste</h3><ul>'+paths+'</ul><h3>Clubs de prêt conseillés</h3><ul>'+dest+'</ul>'+
      '<p class="help">Les minutes Espoirs proviennent des matchs simulés. Les projections de prêt sont indicatives et ne garantissent pas la sélection par le club d’accueil. Historique consultable via l’API carrière.</p></section>';
  }
  function install(g){
    if(!g||typeof g.render!=='function'||typeof g.start!=='function')return false;
    if(typeof g.v86Target==='function')return true;
    const state=()=>typeof S!=='undefined'?S:g.S;
    const save=()=>typeof g.save==='function'&&g.save()!==false;
    const start=g.start;g.start=function(){const r=start.apply(this,arguments);if(state())ensure(state());return r};
    if(typeof g.advanceSeason==='function'){
      const advance=g.advanceSeason;
      g.advanceSeason=function(){const r=advance.apply(this,arguments);if(state())ensure(state());return r};
    }
    const render=g.render;g.render=function(){const r=render.apply(this,arguments);
      if(typeof document!=='undefined'&&typeof view!=='undefined'&&view==='formation'&&state()){
        const el=document.querySelector('.cd04-content [data-da42-page="dossiers"]')||document.querySelector('.cd04-content');
        if(el?.insertAdjacentHTML)el.insertAdjacentHTML('beforeend',panel(state()));
      }return r};
    g.v86Target=(id,minutes)=>{const ok=target(state(),id,minutes,save);if(ok)g.render();return ok};
    return true;
  }
  const api={valid,ensure,target,minutesReport,succession,loanOptions,career,record,panel,install};
  root.CDEspoirsFollowupV86V89=api;
  if(typeof module==='object'&&module.exports)module.exports=api;
  if(typeof document!=='undefined')install(root);
})(typeof globalThis==='object'?globalThis:this);

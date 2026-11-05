'use strict';
(function(root){
  const pro=()=>root.CDEspoirsProV77;
  const copy=x=>JSON.parse(JSON.stringify(x));
  const safe=x=>String(x).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const levels=[0,1,2,3];
  function valid(st){
    return !!st&&st.version===1&&Number.isInteger(st.season)&&st.season>=1&&
      levels.includes(st.facilities)&&levels.includes(st.coaches)&&
      Array.isArray(st.loans)&&st.loans.length<=3&&
      Array.isArray(st.contracts)&&st.contracts.length<=75&&
      Array.isArray(st.u20)&&st.u20.length<=5&&
      Array.isArray(st.history)&&st.history.length<=4&&
      st.loans.every(x=>x&&typeof x.id==='string'&&Number.isInteger(x.to)&&x.to>=0&&x.to<14)&&
      st.contracts.every(x=>x&&typeof x.id==='string'&&Number.isInteger(x.expires))&&
      st.u20.every(x=>x&&typeof x.id==='string'&&Number.isFinite(x.gain));
  }
  function ensure(s){
    if(!s?.development||!pro()?.ensure(s))return null;
    if(s.v78to81!==undefined){
      const st=s.v78to81;
      if(!valid(st)||st.season>s.season)return null;
      if(st.season===s.season)return st;
      const h={season:st.season,loans:st.loans.map(x=>({id:x.id,to:x.to,name:x.name})),
        u20:copy(st.u20),facilities:st.facilities,coaches:st.coaches};
      s.v78to81={...st,season:s.season,loans:[],u20:[],
        contracts:st.contracts.filter(x=>x.expires>=s.season),
        history:[h,...st.history].slice(0,4)};
      return s.v78to81;
    }
    s.v78to81={version:1,season:s.season,loans:[],contracts:[],u20:[],
      facilities:0,coaches:0,history:[]};
    return s.v78to81;
  }
  const available=s=>s?.development?.academy?.filter(p=>p.age<=21)||[];
  const eligiblePro=s=>s?.clubs?.[s.club]?.players?.filter(p=>p.age<=23&&
    (p.id.startsWith('youth-')||p.joinedSeason!==undefined)&&
    p.contractEnd>=s.season)||[];
  const cash=s=>s?.clubs?.[s.club]?.cash;
  function transact(s,fn,save){
    const before=copy(s);
    try{if(!fn())return false;
      if(save&&save()===false)throw Error('save');
      return true;
    }catch{
      for(const key of Object.keys(s))delete s[key];
      Object.assign(s,before);
      return false;
    }
  }
  function contract(s,id,years,save){
    const st=ensure(s);
    if(!st||s.live||s.phase==='ended'||!Number.isInteger(years)||years<1||years>3)return false;
    const p=available(s).find(x=>x.id===id);
    if(!p||st.contracts.some(x=>x.id===id&&x.expires>=s.season+years-1))return false;
    const stipend=600+years*250+Math.max(0,Math.round(p.dev?.potential||p.rating)-60)*25;
    const price=stipend*10;
    if(!Number.isFinite(cash(s))||cash(s)<price)return false;
    return transact(s,()=>{
      s.clubs[s.club].cash-=price;
      st.contracts=st.contracts.filter(x=>x.id!==id);
      st.contracts.push({id,name:p.name,season:s.season,expires:s.season+years-1,
        stipend,fee:price});
      s.news.unshift('Centre : engagement Espoir '+p.name+' pour '+years+' saison(s).');
      s.news=s.news.slice(0,100);return true;
    },save);
  }
  function u20(s,id,save){
    const st=ensure(s);
    if(!st||s.live||s.phase==='ended'||st.u20.length>=5||st.u20.some(x=>x.id===id))return false;
    const p=available(s).find(x=>x.id===id);
    if(!p||p.age>20||p.injury>0||!p.dev||p.rating>=p.dev.potential)return false;
    return transact(s,()=>{
      const q=s.development.academy.find(x=>x.id===id);
      // Camp U20 fictif, sans modification des rencontres officielles.
      const gain=Math.min(2,Math.max(0,q.dev.potential-q.rating));
      q.rating=Math.min(q.dev.potential,99,q.rating+gain);
      if(q.dev){q.dev.seasonStart=Math.min(q.dev.seasonStart,q.rating);q.dev.xp=0}
      st.u20.push({id,name:q.name,age:q.age,season:s.season,gain});
      s.news.unshift('Stage international U20 fictif : '+q.name+' progresse de '+gain+' point(s).');
      s.news=s.news.slice(0,100);return true;
    },save);
  }
  function upgrade(s,kind,save){
    const st=ensure(s),key=kind==='facilities'?'facilities':kind==='coaches'?'coaches':null;
    if(!st||!key||s.live||s.phase==='ended'||st[key]>=3)return false;
    const fee=(st[key]+1)*(key==='facilities'?85000:55000);
    if(!Number.isFinite(cash(s))||cash(s)<fee)return false;
    return transact(s,()=>{
      s.clubs[s.club].cash-=fee;st[key]++;
      s.news.unshift('Centre de formation : '+(key==='facilities'?'installations':'éducateurs')+' niveau '+st[key]+'.');
      s.news=s.news.slice(0,100);return true;
    },save);
  }
  function loan(s,id,to,save){
    const st=ensure(s);
    if(!st||s.live||s.phase==='ended'||st.loans.length>=3||
       !Number.isInteger(to)||to<0||to>=14||to===s.club)return false;
    const c=s.clubs[s.club],borrower=s.clubs[to],p=eligiblePro(s).find(x=>x.id===id);
    if(!c||!borrower||!p||borrower.players.length>=42||
       borrower.players.some(x=>x.id===id)||st.loans.some(x=>x.id===id)||
       s.lineup.includes(id)||s.reserves.includes(id))return false;
    return transact(s,()=>{
      c.players=c.players.filter(x=>x.id!==id);
      borrower.players.push(p);
      st.loans.push({id,name:p.name,to,from:s.club,season:s.season});
      s.news.unshift(p.name+' prêté à '+borrower.name+' jusqu’à la fin de saison.');
      s.news=s.news.slice(0,100);return true;
    },save);
  }
  function returnLoans(s){
    const st=s.v78to81;if(!valid(st))return false;
    for(const loaned of st.loans){
      const origin=s.clubs[loaned.from],destination=s.clubs[loaned.to];
      if(!origin||!destination)return false;
      const p=destination.players.find(q=>q.id===loaned.id);
      if(!p||origin.players.some(q=>q.id===p.id))return false;
      destination.players=destination.players.filter(q=>q.id!==p.id);
      origin.players.push(p);
    }
    return true;
  }
  function year(s,prior){
    if(!s||s.season===prior)return;
    const st=ensure(s);
    if(!st)return;
    const count=st.facilities+st.coaches;
    if(count>0){
      for(const p of available(s)){
        if(p.dev&&p.rating<p.dev.potential){
          const gain=Math.min(p.dev.potential-p.rating,Math.floor(count/3));
          p.rating+=gain;
        }
      }
    }
  }
  function panel(s){
    const st=ensure(s);if(!st)return '';
    const locked=!!s.live||s.phase==='ended';
    const contractList=available(s).slice(0,8).map(p=>
      '<li>'+safe(p.name)+' · '+safe(p.pos)+' <button type="button" onclick="v79Contract('+JSON.stringify(p.id).replace(/"/g,'&quot;')+',2)"'+(locked?' disabled':'')+'>Engager 2 saisons</button></li>').join('');
    const selection=available(s).filter(p=>p.age<=20&&p.injury===0).slice(0,8).map(p=>
      '<li>'+safe(p.name)+' · '+p.rating+' / '+p.dev?.potential+' <button type="button" onclick="v80U20('+JSON.stringify(p.id).replace(/"/g,'&quot;')+')"'+(locked||st.u20.some(x=>x.id===p.id)||st.u20.length>=5?' disabled':'')+'>Stage U20</button></li>').join('');
    const loans=eligiblePro(s).filter(p=>!s.lineup.includes(p.id)&&!s.reserves.includes(p.id)).slice(0,8).map(p=>{
      const to=(s.club+1)%14;
      return '<li>'+safe(p.name)+' · '+safe(p.pos)+' <button type="button" onclick="v78Loan('+JSON.stringify(p.id).replace(/"/g,'&quot;')+','+to+')"'+(locked||st.loans.length>=3?' disabled':'')+'>Prêter à '+safe(s.clubs[to].name)+'</button></li>';
    }).join('');
    return '<section class="cd04-panel" style="padding:18px;margin-top:18px"><h2>V78–V81 · Parcours des talents</h2>'+
      '<p><strong>Prêts :</strong> '+st.loans.length+'/3 · <strong>Stages U20 :</strong> '+st.u20.length+'/5 · <strong>Installations :</strong> '+st.facilities+'/3 · <strong>Éducateurs :</strong> '+st.coaches+'/3</p>'+
      '<h3>V78 · Prêter un jeune professionnel</h3><ul>'+(loans||'<li>Aucun joueur disponible hors feuille de 23.</li>')+'</ul>'+
      '<h3>V79 · Sécuriser les Espoirs</h3><p>Engagement de formation distinct du contrat professionnel.</p><ul>'+(contractList||'<li>Aucun Espoir.</li>')+'</ul>'+
      '<h3>V80 · Stages internationaux U20 simulés</h3><ul>'+(selection||'<li>Aucun joueur éligible.</li>')+'</ul>'+
      '<h3>V81 · Investir dans la formation</h3>'+
      '<button type="button" onclick="v81Upgrade(\'facilities\')"'+(locked||st.facilities>=3?' disabled':'')+'>Installations +1 · '+((st.facilities+1)*85000).toLocaleString('fr-FR')+' €</button> '+
      '<button type="button" onclick="v81Upgrade(\'coaches\')"'+(locked||st.coaches>=3?' disabled':'')+'>Éducateurs +1 · '+((st.coaches+1)*55000).toLocaleString('fr-FR')+' €</button>'+
      '<p class="help">Les stages U20 sont des événements fictifs, sans calendrier ni résultats officiels. Les prêts concernent le championnat professionnel simulé et reviennent au club au changement de saison. Les investissements sont débités de la trésorerie fictive.</p></section>';
  }
  function install(g){
    if(!g||typeof g.start!=='function'||typeof g.advanceSeason!=='function'||typeof g.render!=='function'||!pro())return false;
    if(g.start.__v81)return true;
    const get=()=>typeof S!=='undefined'?S:g.S;
    const save=()=>{if(typeof g.save!=='function')return false;const result=g.save();return result!==false&&(typeof lastSaveError==='undefined'||!lastSaveError)};
    const oldStart=g.start;g.start=function(){const r=oldStart.apply(this,arguments);if(get()){ensure(get());save()}return r};g.start.__v81=true;
    const oldYear=g.advanceSeason;
    g.advanceSeason=function(){
      const s=get(),before=s?.season;
      if(s?.phase==='ended'&&s.v78to81?.loans.length){
        const old=copy(s);
        if(!returnLoans(s)){Object.assign(s,old);return false}
      }
      const r=oldYear.apply(this,arguments);
      if(get()&&get().season!==before){
        const updated=get(),st=updated.v78to81;
        // The native season can render before returning to this wrapper.
        // Reset even when a nested V77/V76 render has observed the new year.
        if(st&&valid(st)&&st.season<updated.season){
          updated.v78to81={...st,season:updated.season,loans:[],u20:[],
            contracts:st.contracts.filter(x=>x.expires>=updated.season),
            history:[{season:st.season,loans:st.loans.map(x=>({id:x.id,to:x.to,name:x.name})),
              u20:copy(st.u20),facilities:st.facilities,coaches:st.coaches},...st.history].slice(0,4)};
        }
        year(updated,before);save()
      }
      return r;
    };
    const oldRender=g.render;g.render=function(){const r=oldRender.apply(this,arguments),s=get();
      if(s&&typeof document!=='undefined'&&typeof view!=='undefined'&&view==='formation'){
        const target=document.querySelector('.cd04-content [data-da42-page="dossiers"]')||document.querySelector('.cd04-content');
        if(target?.insertAdjacentHTML)target.insertAdjacentHTML('beforeend',panel(s));
      }return r};
    g.v78Loan=(id,to)=>{const ok=loan(get(),id,to,save);if(ok)g.render();return ok};
    g.v79Contract=(id,years)=>{const ok=contract(get(),id,years,save);if(ok)g.render();return ok};
    g.v80U20=id=>{const ok=u20(get(),id,save);if(ok)g.render();return ok};
    g.v81Upgrade=kind=>{const ok=upgrade(get(),kind,save);if(ok)g.render();return ok};
    return true;
  }
  const api={valid,ensure,available,eligiblePro,contract,u20,upgrade,loan,returnLoans,year,panel,install};
  root.CDEspoirsPathwaysV78V81=api;
  if(typeof module==='object'&&module.exports)module.exports=api;
  if(typeof document!=='undefined')install(root);
})(typeof globalThis==='object'?globalThis:this);

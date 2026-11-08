'use strict';
(function(root){
  const scout=()=>root.CDEspoirsScoutingV76;
  const movement=()=>root.CDEspoirsMovementV75;
  const clone=x=>JSON.parse(JSON.stringify(x));
  const safe=x=>String(x).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  function valid(st){
    return !!st&&st.version===1&&Number.isInteger(st.season)&&st.season>=1&&
      Array.isArray(st.promotions)&&st.promotions.length<=3&&
      Array.isArray(st.history)&&st.history.length<=4&&
      st.promotions.every(e=>e&&typeof e.playerId==='string'&&Number.isInteger(e.years)&&e.years>=1&&e.years<=3)&&
      st.history.every(h=>h&&Number.isInteger(h.season)&&Array.isArray(h.promotions)&&h.promotions.length<=3);
  }
  function ensure(s){
    if(!s||!Number.isInteger(s.season)||!scout()?.own(s))return null;
    if(s.v77Promotions!==undefined){
      const st=s.v77Promotions;
      if(!valid(st)||st.season>s.season)return null;
      if(st.season===s.season)return st;
      s.v77Promotions={version:1,season:s.season,promotions:[],
        history:[{season:st.season,promotions:clone(st.promotions)},...st.history].slice(0,4)};
      return s.v77Promotions;
    }
    s.v77Promotions={version:1,season:s.season,promotions:[],history:[]};
    return s.v77Promotions;
  }
  function academy(s){
    const c=scout()?.own(s),native=s?.development?.academy;
    if(!c||!Array.isArray(native))return [];
    return native.filter(p=>p&&typeof p.id==='string'&&Number.isInteger(p.age)&&p.age<=21&&
      !s.clubs[s.club].players.some(q=>q.id===p.id));
  }
  function salary(p,years){
    return Math.min(100000,Math.max(2000,Math.round((p.rating*46+
      Math.max(0,(p.dev?.potential??p.potential??p.rating)-p.rating)*32+
      (years-1)*280)/100)*100));
  }
  function canPromote(s,id,years){
    const st=ensure(s),team=s?.clubs?.[s.club]?.players,p=academy(s).find(x=>x.id===id);
    if(!st||!Array.isArray(team)||!p||s.live||s.phase==='ended'||
       !Number.isInteger(years)||years<1||years>3||
       st.promotions.length>=3||(typeof professionalPlaces==='function'?professionalPlaces(s.clubs[s.club],s)<=0:team.length>=42)||
       st.promotions.some(x=>x.playerId===id)||!Number.isFinite(p.rating)||
       !Number.isFinite(p.dev?.potential)||!Number.isInteger(p.fam)||
       s.development.academy.filter(x=>x.id===id).length!==1)return false;
    const existing=team.some(x=>x.id===id);
    return !existing&&p.age<=21&&(!Number.isFinite(p.dev?.retireAge)||s.season+years-1<p.dev.retireAge);
  }
  function promote(s,id,years,save){
    if(!canPromote(s,id,years)||typeof academyPlayer!=='function'||
       typeof ensureSkills!=='function'||typeof ensureDevelopment!=='function'||
       typeof POS==='undefined')return false;
    const st=ensure(s),source=s.development.academy,team=s.clubs[s.club].players;
    const original=source.find(p=>p.id===id),slot=POS.indexOf(original.pos);
    if(slot<0)return false;
    const own=scout().own(s),m=movement()?.ensure(s);
    if(!m)return false;
    const oldAcademy=clone(source),oldTeam=clone(team),oldState=clone(st);
    const oldRoster=m.rosters[own.id]===undefined?undefined:clone(m.rosters[own.id]);
    const oldLineup=s.v73Espoirs?.lineup?.slice(),oldNews=s.news?.slice();
    const promoted=clone(original);
    promoted.academy=false;promoted.joinedSeason=s.season;promoted.joinedRound=s.round;
    promoted.contractEnd=s.season+years-1;promoted.salary=salary(promoted,years);
    ensureSkills(promoted);ensureDevelopment(promoted);
    promoted.dev.potential=Math.max(promoted.rating,promoted.dev.potential);
    const next=source.filter(p=>p.id!==id);
    // Keep a complete XV available to the Espoirs after promotion.
    const remaining=next.filter(p=>p.pos===promoted.pos);
    let replacement=null;
    if(!remaining.length||next.length<15){
      const serial=9000+st.promotions.length*15+slot;
      replacement=academyPlayer(s.club,slot,s.season,serial);
      if(next.some(p=>p.id===replacement.id)||team.some(p=>p.id===replacement.id))return false;
      next.push(replacement);
    }
    s.development.academy=next;
    s.clubs[s.club].players=[...team,promoted];
    if(oldRoster!==undefined)m.rosters[own.id]=clone(next);
    if(s.v73Espoirs?.lineup){
      s.v73Espoirs.lineup=s.v73Espoirs.lineup.map(x=>x===id?(replacement?.id||null):x);
    }
    st.promotions.push({playerId:id,name:promoted.name,pos:promoted.pos,season:s.season,
      round:s.round,age:promoted.age,rating:promoted.rating,potential:promoted.dev.potential,
      salary:promoted.salary,years,contractEnd:promoted.contractEnd});
    if(Array.isArray(s.news))s.news.unshift(promoted.name+' passe professionnel pour '+years+' saison(s). Choisissez sa place dans le groupe professionnel.');
    try{
      if(save&&save()===false)throw Error('save');
      return true;
    }catch{
      s.development.academy=oldAcademy;s.clubs[s.club].players=oldTeam;
      s.v77Promotions=oldState;
      if(oldRoster===undefined)delete m.rosters[own.id];else m.rosters[own.id]=oldRoster;
      if(oldLineup&&s.v73Espoirs)s.v73Espoirs.lineup=oldLineup;
      if(oldNews)s.news=oldNews;
      return false;
    }
  }
  function panel(s){
    const st=ensure(s);if(!st)return '';
    const locked=!!s.live||s.phase==='ended'||st.promotions.length>=3||(typeof professionalPlaces==='function'?professionalPlaces(s.clubs[s.club],s)<=0:s.clubs[s.club].players.length>=42);
    const youths=academy(s).sort((a,b)=>(b.dev?.potential||0)-(a.dev?.potential||0)||b.rating-a.rating).slice(0,12);
    const rows=youths.map(p=>{
      const allow=!locked&&canPromote(s,p.id,1);
      const actions=[1,2,3].map(y=>'<button type="button" onclick="v77Promote('+JSON.stringify(p.id).replace(/"/g,'&quot;')+','+y+')"'+(!allow?' disabled':'')+'>'+y+' an'+(y>1?'s':'')+' · '+salary(p,y).toLocaleString('fr-FR')+' €/sem.</button>').join(' ');
      return '<tr><td>'+safe(p.name)+'</td><td>'+safe(p.pos)+'</td><td>'+Math.round(p.rating)+
        '</td><td>'+Math.round(p.dev?.potential||p.rating)+'</td><td>'+actions+'</td></tr>';
    }).join('');
    const history=[...st.promotions.map(p=>({...p,season:s.season})),...st.history.flatMap(h=>h.promotions.map(p=>({...p,season:h.season})))].slice(0,15);
    return '<section class="cd04-panel" style="padding:18px;margin-top:18px"><h2>V77 · La passerelle professionnelle</h2>'+
      '<p>Sélectionnez un Espoir et la durée de son premier contrat : intégration immédiate dans l’effectif professionnel, puis sélection possible dans votre feuille de 23. Le temps de jeu fait progresser le joueur via le système de carrière existant.</p>'+
      '<p><strong>Promotions cette saison : '+st.promotions.length+'/3</strong> · Professionnels : '+s.clubs[s.club].players.length+'/42</p>'+
      '<div class="tablewrap"><table><thead><tr><th>Espoir</th><th>Poste</th><th>Niveau</th><th>Potentiel</th><th>Signer un premier contrat</th></tr></thead><tbody>'+rows+'</tbody></table></div>'+
      '<button type="button" onclick="nav(\'team\')">Composer la feuille de 23 →</button>'+
      '<h3>Historique des passages professionnels</h3><ul>'+
      (history.map(p=>'<li>S'+p.season+' : '+safe(p.name)+' · '+safe(p.pos)+' · '+p.years+' an(s) · '+Number(p.salary).toLocaleString('fr-FR')+' €/semaine</li>').join('')||'<li>Aucune promotion à ce jour.</li>')+
      '</ul><p class="help">Au maximum trois promotions par saison. Le XV Espoirs conserve ses postes, avec un remplaçant formé en cas de manque. Les nouveaux contrats utilisent la masse salariale professionnelle existante.</p></section>';
  }
  function install(g){
    if(!g||typeof g.start!=='function'||typeof g.advanceSeason!=='function'||typeof g.render!=='function'||!scout()||!movement())return false;
    if(typeof g.v77Promote==='function')return true;
    const get=()=>typeof S!=='undefined'?S:g.S;
    const save=()=>{if(typeof g.save!=='function')return false;const result=g.save();return result!==false&&(typeof lastSaveError==='undefined'||!lastSaveError)};
    const previousStart=g.start;
    g.start=function(){const result=previousStart.apply(this,arguments);if(get()){ensure(get());save()}return result};g.start.__v77=true;
    const previousSeason=g.advanceSeason;
    g.advanceSeason=function(){const before=get()?.season,result=previousSeason.apply(this,arguments);if(get()&&get().season!==before){ensure(get());save()}return result};
    const previousRender=g.render;
    g.render=function(){const result=previousRender.apply(this,arguments),s=get();
      if(s&&typeof document!=='undefined'&&typeof view!=='undefined'&&view==='formation'){
        const target=document.querySelector('.cd04-content [data-da42-page="dossiers"]')||document.querySelector('.cd04-content');
        if(target?.insertAdjacentHTML)target.insertAdjacentHTML('beforeend',panel(s));
      }return result};
    g.v77Promote=(id,years)=>{const ok=promote(get(),id,years,save);if(ok)g.render();return ok};
    return true;
  }
  const api={valid,ensure,academy,salary,canPromote,promote,panel,install};
  root.CDEspoirsProV77=api;
  if(typeof module==='object'&&module.exports)module.exports=api;
  if(!root.CDNativeHeadless&&typeof document!=='undefined')install(root);
})(typeof globalThis==='object'?globalThis:this);

'use strict';
(function(root){
  const move=()=>root.CDEspoirsMovementV75;
  const elite=()=>root.CDEspoirsV73;
  const accession=()=>root.CDEspoirsAccessionV74;
  const clone=x=>JSON.parse(JSON.stringify(x));
  const safe=x=>String(x).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;').replace(/'/g,'&#39;');
  const hash=x=>{let h=2166136261;for(const c of String(x)){h^=c.charCodeAt(0);h=Math.imul(h,16777619)}return h>>>0};
  const centers=s=>{
    const m=move()?.ensure(s);if(!m)return [];
    return [...m.elite.map((id,slot)=>({id,division:'elite',slot})),...m.accession.map((id,slot)=>({id,division:'accession',slot}))];
  };
  const own=s=>centers(s).find(c=>c.division==='elite'&&c.slot===s.club)||null;
  function players(s,c){
    if(!c)return [];
    const m=move()?.ensure(s),override=m?.rosters[c.id];
    if(Array.isArray(override))return override;
    if(c.division==='elite')return elite()?.clubPlayers(s,c.slot)||[];
    return s.v74Accession?.centers?.[c.slot]?.players||[];
  }
  const label=(s,c)=>c.division==='elite'?elite()?.clubName(s,c.slot):accession()?.name(s,c.slot);
  const initialBudget=(c)=>72000+(hash(c.id+':v76')%7)*8000;
  function valid(st){
    return !!st&&st.version===1&&Number.isInteger(st.season)&&
      st.budgets&&typeof st.budgets==='object'&&!Array.isArray(st.budgets)&&
      Object.values(st.budgets).every(v=>Number.isInteger(v)&&v>=0&&v<=200000)&&
      typeof st.focus==='string'&&Array.isArray(st.scouted)&&Array.isArray(st.recruited)&&
      Array.isArray(st.history)&&st.history.length<=4&&
      st.scouted.length<=44&&st.recruited.length<=8;
  }
  function ensure(s){
    if(!s||!Number.isInteger(s.season)||!move()?.ensure(s)||!elite()||!accession())return null;
    if(s.v76Scouting!==undefined){
      if(!valid(s.v76Scouting))return null;
      if(s.v76Scouting.season===s.season)return s.v76Scouting;
      if(s.v76Scouting.season>s.season)return null;
      const old=s.v76Scouting,ids=centers(s);
      const history=[{season:old.season,recruited:clone(old.recruited),spent:old.spent||0},...old.history].slice(0,4);
      s.v76Scouting={version:1,season:s.season,budgets:Object.fromEntries(ids.map(c=>[c.id,initialBudget(c)])),
        focus:ids.find(c=>c.id===old.focus)?.id||ids.find(c=>c.id!==own(s)?.id)?.id||'',
        scouted:[],recruited:[],spent:0,history};
      return s.v76Scouting;
    }
    const ids=centers(s),manager=own(s);
    s.v76Scouting={version:1,season:s.season,budgets:Object.fromEntries(ids.map(c=>[c.id,initialBudget(c)])),
      focus:ids.find(c=>c.id!==manager?.id)?.id||'',scouted:[],recruited:[],spent:0,history:[]};
    return s.v76Scouting;
  }
  function candidate(s,id){
    const found=centers(s).find(c=>c.id===id);
    return found&&found.id!==own(s)?.id?found:null;
  }
  function available(s,c){
    const pool=players(s,c);
    if(pool.length<=15)return [];
    const taken=new Set((ensure(s)?.recruited||[]).map(x=>x.playerId));
    return pool.filter(p=>p&&typeof p.id==='string'&&!taken.has(p.id)&&
      Number.isFinite(p.rating)&&Number.isFinite(p.potential??p.dev?.potential)&&Number.isInteger(p.age)&&p.age<=21).sort((a,b)=>
        (b.potential??b.dev?.potential)-(a.potential??a.dev?.potential)||b.rating-a.rating||a.id.localeCompare(b.id)).slice(0,5);
  }
  function price(s,c,p){
    const potential=p.potential??p.dev?.potential??p.rating;
    const base=4500+Math.max(0,Math.round(potential)-50)*320+Math.max(0,Math.round(p.rating)-50)*180;
    const competition=hash(s.season+':'+c.id+':'+p.id)%4;
    return {minimum:Math.round((base+competition*1800)/500)*500,competition};
  }
  function scout(s,id,save){
    const st=ensure(s),c=candidate(s,id),manager=own(s);
    if(!st||!c||!manager||s.live||s.phase==='ended'||st.scouted.includes(id)||st.scouted.length>=12||st.budgets[manager.id]<1200)return false;
    if(!available(s,c).length)return false;
    const old=clone(st);st.budgets[manager.id]-=1200;st.spent+=1200;st.scouted.push(id);st.focus=id;
    try{if(save&&save()===false)throw Error('save');return true}catch{s.v76Scouting=old;return false}
  }
  function focus(s,id,save){
    const st=ensure(s);if(!st||!candidate(s,id)||s.live||s.phase==='ended')return false;
    const old=st.focus;st.focus=id;
    try{if(save&&save()===false)throw Error('save');return true}catch{st.focus=old;return false}
  }
  function recruit(s,id,offer,save){
    const st=ensure(s),manager=own(s);
    if(!st||!manager||s.live||s.phase==='ended'||st.recruited.length>=3||!Number.isInteger(offer)||offer<0)return false;
    const source=centers(s).find(c=>c.id!==manager.id&&st.scouted.includes(c.id)&&players(s,c).some(p=>p.id===id));
    if(!source)return false;
    const origin=players(s,source),target=players(s,manager),p=origin.find(p=>p.id===id);
    if(!p||origin.length<=15||target.some(q=>q.id===id)||target.length>=40||!Number.isFinite(p.potential??p.dev?.potential))return false;
    const cost=price(s,source,p),required=cost.minimum;
    if(offer<required||offer>st.budgets[manager.id]||offer>200000)return false;
    const m=move()?.ensure(s);if(!m)return false;
    const beforeState=clone(st),oldOrigin=m.rosters[source.id]===undefined?undefined:clone(m.rosters[source.id]);
    const oldTarget=m.rosters[manager.id]===undefined?undefined:clone(m.rosters[manager.id]);
    const previousNative=s.development?.academy,previousAccession=source.division==='accession'?s.v74Accession?.centers?.[source.slot]?.players:null;
    const chosen=clone(p),nextOrigin=origin.filter(q=>q.id!==id).map(clone),nextTarget=target.map(clone);
    if(chosen.pos&&source.division!==manager.division){
      const slot=Number.isInteger(chosen.slot)?chosen.slot:0;
      chosen.pos=move().normalize([chosen],manager.division)[0]?.pos||chosen.pos;
      chosen.slot=slot;
    }
    // Un centre promu d'Accession peut contenir des profils V74 allégés.
    // Normaliser l'ensemble de l'académie native avant toute sauvegarde.
    nextTarget.push(chosen);
    if(manager.division==='elite'&&manager.slot===s.club){
      if(typeof ensureSkills!=='function'||typeof ensureDevelopment!=='function'||
         typeof POS==='undefined'||typeof FAMILIES==='undefined')return false;
      for(const youth of nextTarget){
        const index=POS.indexOf(youth.pos);
        if(index<0)return false;
        youth.fam=FAMILIES[index];
        youth.injury=Number.isInteger(youth.injury)?youth.injury:0;
        youth.salary=Number.isInteger(youth.salary)?youth.salary:2000;
        youth.academy=true;youth.contractEnd=null;
        ensureSkills(youth);ensureDevelopment(youth);
        const potential=Number.isFinite(youth.potential)?youth.potential:youth.dev.potential;
        youth.dev.potential=Math.min(99,Math.max(youth.rating,potential));
      }
    }
    m.rosters[source.id]=nextOrigin;m.rosters[manager.id]=nextTarget;
    if(manager.division==='elite'&&manager.slot===s.club&&s.development)s.development.academy=clone(nextTarget.filter(p=>p.age<=21));
    if(source.division==='accession'&&s.v74Accession?.centers?.[source.slot])
      s.v74Accession.centers[source.slot].players=clone(nextOrigin);
    st.budgets[manager.id]-=offer;st.spent+=offer;
    st.recruited.push({playerId:id,name:chosen.name,from:source.id,to:manager.id,fee:offer,season:s.season,potential:chosen.potential??chosen.dev?.potential});
    try{if(save&&save()===false)throw Error('save');return true}catch{
      s.v76Scouting=beforeState;
      if(oldOrigin===undefined)delete m.rosters[source.id];else m.rosters[source.id]=oldOrigin;
      if(oldTarget===undefined)delete m.rosters[manager.id];else m.rosters[manager.id]=oldTarget;
      if(s.development)s.development.academy=previousNative;
      if(source.division==='accession'&&s.v74Accession?.centers?.[source.slot])s.v74Accession.centers[source.slot].players=previousAccession;
      return false;
    }
  }
  function panel(s){
    const st=ensure(s),manager=own(s);if(!st||!manager)return '';
    const all=centers(s).filter(c=>c.id!==manager.id),selected=candidate(s,st.focus)||all[0];
    const scouted=st.scouted.includes(selected?.id),locked=!!s.live||s.phase==='ended';
    const options=all.map(c=>'<option value="'+safe(c.id)+'" '+(c.id===selected?.id?'selected':'')+'>'+safe(label(s,c)||c.id)+' ('+(c.division==='elite'?'Élite':'Accession')+')</option>').join('');
    const reports=scouted?available(s,selected).map(p=>{
      const q=price(s,selected,p),pot=p.potential??p.dev?.potential??p.rating;
      const disabled=locked||st.recruited.length>=3||st.budgets[manager.id]<q.minimum;
      return '<tr><td>'+safe(p.name)+'</td><td>'+safe(p.pos)+'</td><td>'+Math.round(p.rating)+'</td><td>'+Math.round(pot)+'</td><td>'+q.minimum.toLocaleString('fr-FR')+' €</td><td><button type="button" onclick="v76Recruit('+JSON.stringify(p.id).replace(/"/g,'&quot;')+','+q.minimum+')" '+(disabled?'disabled':'')+'>Faire une offre</button></td></tr>';
    }).join(''):'';
    const market='<div class="tablewrap"><table><thead><tr><th>Joueur</th><th>Poste</th><th>Niveau</th><th>Potentiel estimé</th><th>Offre concurrentielle minimale</th><th>Décision</th></tr></thead><tbody>'+reports+'</tbody></table></div>';
    return '<section class="cd04-panel" style="padding:18px;margin-top:18px"><h2>V76 · Détection et recrutement Espoirs</h2>'+
      '<p>44 centres, mutations réelles des effectifs et concurrence simulée. Enveloppe de recrutement fictive et distincte de la trésorerie senior.</p>'+
      '<p><strong>Centre géré : '+safe(label(s,manager)||manager.id)+'</strong> · Budget restant : '+st.budgets[manager.id].toLocaleString('fr-FR')+
      ' € · Recrues '+st.recruited.length+'/3 · Rapports '+st.scouted.length+'/12</p>'+
      '<label>Centre à observer <select aria-label="Centre Espoirs à observer" onchange="v76Focus(this.value)" '+(locked?'disabled':'')+'>'+options+'</select></label>'+
      '<button type="button" onclick="v76Scout('+JSON.stringify(selected?.id||'').replace(/"/g,'&quot;')+')" '+
      (locked||scouted||st.scouted.length>=12||st.budgets[manager.id]<1200?'disabled':'')+'>Observer ce centre · 1 200 €</button>'+
      (scouted?market:'<p>Commandez un rapport pour révéler cinq candidats et les offres minimales tenant compte de la concurrence.</p>')+
      '<h3>Recrutements de la saison</h3><ul>'+(st.recruited.map(x=>'<li>'+safe(x.name)+' · '+safe(x.from)+' → '+safe(x.to)+' · '+x.fee.toLocaleString('fr-FR')+' €</li>').join('')||'<li>Aucune recrue.</li>')+'</ul>'+
      '<p class="help">Les jeunes conservent leur identité et leur potentiel. Les centres cédants conservent au minimum 15 joueurs. Budget renouvelé chaque saison ; historique limité à quatre saisons.</p></section>';
  }
  function install(g){
    if(!g||typeof g.start!=='function'||typeof g.render!=='function'||typeof g.advanceSeason!=='function'||!move()||!elite()||!accession())return false;
    if(g.start.__v76)return true;
    const get=()=>typeof S!=='undefined'?S:g.S;
    const save=()=>{if(typeof g.save!=='function')return false;const result=g.save();return result!==false&&(typeof lastSaveError==='undefined'||!lastSaveError)};
    const oldStart=g.start;g.start=function(){const result=oldStart.apply(this,arguments);if(get()){ensure(get());save()}return result};g.start.__v76=true;
    const oldSeason=g.advanceSeason;g.advanceSeason=function(){const s=get(),season=s?.season,r=oldSeason.apply(this,arguments);if(get()&&get().season!==season){ensure(get());save()}return r};
    const oldRender=g.render;g.render=function(){const result=oldRender.apply(this,arguments);const s=get();
      if(s&&typeof document!=='undefined'&&typeof view!=='undefined'&&view==='formation'){
        const target=document.querySelector('.cd04-content [data-da42-page="dossiers"]')||document.querySelector('.cd04-content');
        if(target?.insertAdjacentHTML)target.insertAdjacentHTML('beforeend',panel(s));
      }return result};
    g.v76Focus=id=>{const ok=focus(get(),id,save);if(ok)g.render();return ok};
    g.v76Scout=id=>{const ok=scout(get(),id,save);if(ok)g.render();return ok};
    g.v76Recruit=(id,offer)=>{const ok=recruit(get(),id,offer,save);if(ok)g.render();return ok};
    return true;
  }
  const api={centers,own,players,label,valid,ensure,available,price,scout,focus,recruit,panel,install};
  root.CDEspoirsScoutingV76=api;
  if(typeof module==='object'&&module.exports)module.exports=api;
  if(typeof document!=='undefined')install(root);
})(typeof globalThis==='object'?globalThis:this);

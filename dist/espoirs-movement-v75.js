'use strict';
(function(root){
  const eliteIds=()=>Array.from({length:24},(_,i)=>'elite:'+i);
  const accessionIds=()=>Array.from({length:20},(_,i)=>'accession:'+i);
  const keyOK=k=>typeof k==='string'&&/^(elite:(?:[0-9]|1[0-9]|2[0-3])|accession:(?:[0-9]|1[0-9]))$/.test(k);
  const clone=x=>JSON.parse(JSON.stringify(x));
  const unique=a=>new Set(a).size===a.length;
  const fields=['Pilier G','Talonneur','Pilier D','Deuxième ligne','Deuxième ligne','Troisième ligne','Troisième ligne','N°8','Mêlée','Ouverture','Ailier G','Centre','Centre','Ailier D','Arrière'];
  const eliteFields=['Pilier gauche','Talonneur','Pilier droit','Deuxième ligne','Deuxième ligne','Troisième ligne','Troisième ligne','Numéro 8','Demi de mêlée','Demi d’ouverture','Ailier','Centre','Centre','Ailier','Arrière'];
  function valid(st){
    return !!st&&st.version===1&&Number.isInteger(st.season)&&
      Array.isArray(st.elite)&&st.elite.length===24&&Array.isArray(st.accession)&&st.accession.length===20&&
      st.elite.concat(st.accession).every(keyOK)&&unique(st.elite.concat(st.accession))&&
      st.rosters&&typeof st.rosters==='object'&&!Array.isArray(st.rosters)&&
      st.names&&typeof st.names==='object'&&!Array.isArray(st.names)&&
      Array.isArray(st.history)&&st.history.length<=4;
  }
  function ensure(s){
    if(!s||!Number.isInteger(s.season))return null;
    if(s.v75Movement!==undefined)return valid(s.v75Movement)?s.v75Movement:null;
    const st={version:1,season:s.season,elite:eliteIds(),accession:accessionIds(),rosters:{},names:{},history:[]};
    s.v75Movement=st;return st;
  }
  function identity(s,division,slot){
    const st=ensure(s),list=st?.[division];
    return Array.isArray(list)&&Number.isInteger(slot)?list[slot]||null:null;
  }
  function name(s,division,slot,legacy){
    const id=identity(s,division,slot);
    return id&&s.v75Movement.names[id]||legacy;
  }
  function roster(s,division,slot,fallback){
    const id=identity(s,division,slot),mapped=!!id&&id!==division+':'+slot;
    if(!id)return fallback;
    return s.v75Movement.rosters[id]||(mapped?[]:fallback);
  }
  function initialGroups(st){
    if(st.initialGroups?.length===4&&st.initialGroups.every(g=>g.length===6))return st.initialGroups;
    const edges=st.results.filter(m=>m.phase==='preliminaire'&&Array.isArray(m.pair)).map(m=>m.pair);
    const pending=new Set(Array.from({length:24},(_,i)=>i)),groups=[];
    while(pending.size){
      const seed=pending.values().next().value,seen=new Set([seed]),stack=[seed];
      while(stack.length){const id=stack.pop();for(const pair of edges)if(pair.includes(id))for(const other of pair)
        if(!seen.has(other)){seen.add(other);stack.push(other)}}
      for(const id of seen)pending.delete(id);
      groups.push([...seen].sort((a,b)=>a-b));
    }
    return groups.length===4&&groups.every(g=>g.length===6)?groups:null;
  }
  function candidates(s){
    const elite=root.CDEspoirsV73?.read(s),acc=root.CDEspoirsAccessionV74?.read(s);
    if(!elite||!acc||elite.season!==s.season||acc.season!==s.season||
       !Number.isInteger(elite.champion)||!Number.isInteger(acc.champion)||
       !Array.isArray(acc.finalists)||acc.finalists.length!==2||!unique(acc.finalists))return null;
    const groups=initialGroups(elite);if(!groups)return null;
    const prelim=elite.results.filter(m=>m.phase==='preliminaire');
    const bottom=groups.map(g=>root.CDEspoirsV73.standing(s,g,prelim).at(-1));
    if(bottom.some(x=>!x))return null;
    bottom.sort((a,b)=>a.points-b.points||(a.for-a.against)-(b.for-b.against)||a.id-b.id);
    const relegated=bottom.slice(0,2).map(x=>x.id);
    const promoted=acc.finalists.slice();
    if(promoted.some(x=>!Number.isInteger(x)||x<0||x>=20)||relegated.some(x=>!Number.isInteger(x)||x<0||x>=24))return null;
    return {season:s.season,promoted,relegated};
  }
  function normalize(players,target){
    const count={};
    return players.map(p=>{
      const x=clone(p),source=fields.includes(x.pos)?fields:eliteFields;
      let slot=Number.isInteger(x.slot)&&x.slot>=0&&x.slot<15?x.slot:-1;
      if(slot<0){
        const matches=source.map((pos,i)=>pos===x.pos?i:-1).filter(i=>i>=0);
        const n=count[x.pos]||0;
        slot=matches.length?matches[n%matches.length]:Object.values(count).reduce((a,b)=>a+b,0)%15;
        count[x.pos]=n+1;
      }
      x.slot=slot;
      x.pos=(target==='elite'?eliteFields:fields)[slot];
      if(!Number.isFinite(x.potential))x.potential=Math.max(x.rating||45,x.dev?.potential||x.rating||45);
      x.condition=100;
      if(Number.isFinite(x.age))x.age++;
      return x;
    });
  }
  function snapshot(s,choice){
    const elite=choice.relegated.map(slot=>{
      const base=root.CDEspoirsV73.clubPlayers(s,slot);
      return {slot,id:identity(s,'elite',slot),name:root.CDEspoirsV73.clubName(s,slot),players:normalize(base,'accession')};
    });
    const acc=choice.promoted.map(slot=>{
      const base=s.v74Accession?.centers?.[slot]?.players||[];
      return {slot,id:identity(s,'accession',slot),name:root.CDEspoirsAccessionV74.name(s,slot),players:normalize(base,'elite')};
    });
    if([...elite,...acc].some(x=>!x.id||!Array.isArray(x.players)||x.players.length<15))return null;
    return {elite,acc};
  }
  function sync(s){
    const st=ensure(s),acc=s?.v74Accession;
    if(!st||!acc||acc.season!==s.season)return false;
    for(let slot=0;slot<20;slot++){
      const id=st.accession[slot];
      if(st.rosters[id]&&acc.centers?.[slot])acc.centers[slot].players=clone(st.rosters[id]);
    }
    return true;
  }
  function transfer(s,choice,snap){
    const st=ensure(s),old=choice?.season;
    if(!st||!snap||!Number.isInteger(old)||st.season!==old||
      s.season!==old+1||st.history.some(h=>h.season===old)||
      choice.promoted?.length!==2||choice.relegated?.length!==2||
      !unique(choice.promoted)||!unique(choice.relegated))return false;
    const next=clone(st),swaps=[];
    for(let i=0;i<2;i++){
      const down=snap.elite[i],up=snap.acc[i];
      if(down.slot!==choice.relegated[i]||up.slot!==choice.promoted[i]||
         next.elite[down.slot]!==down.id||next.accession[up.slot]!==up.id)return false;
      next.elite[down.slot]=up.id;next.accession[up.slot]=down.id;
      next.rosters[down.id]=down.players;next.rosters[up.id]=up.players;
      next.names[down.id]=down.name;next.names[up.id]=up.name;
      swaps.push({up:up.id,down:down.id,eliteSlot:down.slot,accessionSlot:up.slot});
    }
    next.season=s.season;next.history.unshift({season:old,swaps});
    next.history=next.history.slice(0,4);
    if(!valid(next))return false;
    s.v75Movement=next;sync(s);return true;
  }
  function carry(s,snap){
    const st=ensure(s);
    if(!st||!snap)return;
    for(const item of snap){
      if(st.rosters[item.id])st.rosters[item.id]=item.players;
    }
    st.season=s.season;
    sync(s);
  }
  function captureExisting(s){
    const st=ensure(s);if(!st)return [];
    const result=[];
    for(let i=0;i<24;i++){
      const id=st.elite[i];
      if(st.rosters[id])result.push({id,players:normalize(root.CDEspoirsV73.clubPlayers(s,i),'elite')});
    }
    for(let i=0;i<20;i++){
      const id=st.accession[i];
      if(st.rosters[id])result.push({id,players:normalize(s.v74Accession?.centers?.[i]?.players||[],'accession')});
    }
    return result.filter(x=>x.players.length>=15);
  }
  function panel(s){
    const st=ensure(s);if(!st)return '';
    const escape=x=>String(x).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
    const items=st.history.flatMap(h=>h.swaps.map(sw=>'<li>Saison '+h.season+' : '+escape(st.names[sw.up]||sw.up)+' monte en Élite ; '+escape(st.names[sw.down]||sw.down)+' descend en Accession</li>')).join('');
    return '<section class="cd04-panel" style="padding:18px;margin-top:18px"><h2>V75 · Montées et descentes Espoirs</h2><p>Deux finalistes Accession montent contre les deux derniers représentants des poules initiales Élite les moins bien classés. Mouvement appliqué à la saison suivante, avec conservation des effectifs et des identités.</p><ul>'+(items||'<li>Première saison en cours : aucun mouvement.</li>')+'</ul></section>';
  }
  function install(g){
    if(!g||typeof g.advanceSeason!=='function'||!root.CDEspoirsV73||!root.CDEspoirsAccessionV74)return false;
    if(g.advanceSeason.__v75)return true;
    const current=()=>typeof S!=='undefined'?S:g.S;
    const prev=g.advanceSeason;
    g.advanceSeason=function(){
      const s=current();
      if(!s||s.phase!=='ended'||s.live)return prev.apply(this,arguments);
      const st=ensure(s),year=s.season;
      if(!st)return prev.apply(this,arguments);
      root.CDEspoirsV73.advance(s);
      root.CDEspoirsAccessionV74.advance(s);
      const choice=candidates(s),shots=choice?snapshot(s,choice):null,existing=captureExisting(s);
      const result=prev.apply(this,arguments);
      const updated=current();
      if(updated===s&&updated.season===year+1){
        if(choice&&shots&&!transfer(updated,choice,shots))carry(updated,existing);
        else if(!choice||!shots)carry(updated,existing);
        for(const item of existing){
          const k=updated.v75Movement?.rosters;
          if(k&&k[item.id]&&!shots?.elite.some(x=>x.id===item.id)&&!shots?.acc.some(x=>x.id===item.id))k[item.id]=item.players;
        }
        sync(updated);
        if(typeof g.save==='function')g.save();
      }
      return result;
    };
    g.advanceSeason.__v75=true;
    const prevStart=g.start;
    if(typeof prevStart==='function')g.start=function(){
      const result=prevStart.apply(this,arguments);if(current())ensure(current());return result;
    };
    const prevRender=g.render;
    if(typeof prevRender==='function')g.render=function(){
      const result=prevRender.apply(this,arguments);
      if(typeof document!=='undefined'&&typeof view!=='undefined'&&view==='formation'){
        const target=document.querySelector('.cd04-content [data-da42-page="dossiers"]');
        if(target?.insertAdjacentHTML)target.insertAdjacentHTML('beforeend',panel(current()));
      }
      return result;
    };
    return true;
  }
  const api={valid,ensure,identity,name,roster,initialGroups,candidates,normalize,snapshot,sync,transfer,carry,panel,install};
  root.CDEspoirsMovementV75=api;
  if(typeof module==='object'&&module.exports)module.exports=api;
  if(typeof document!=='undefined')install(root);
})(typeof globalThis==='object'?globalThis:this);

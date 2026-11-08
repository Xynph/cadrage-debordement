'use strict';
module.exports={
 files:['vestiaire-v64.js','relations-duos-v70.js','living-locker-room-v117-v123.js'],
 commands:['relationship_activate','relationship_conversation','relationship_promise','relationship_duo','locker_room_decision'],
 factory:function nativeRelationships(){
  const copy=x=>JSON.parse(JSON.stringify(x));
  const object=x=>x!==null&&typeof x==='object'&&!Array.isArray(x);
  const integer=(x,a=0,b=1000000)=>Number.isSafeInteger(x)&&x>=a&&x<=b;
  const text=(x,max=160)=>typeof x==='string'&&x.length>0&&x.length<=max&&!/[\u0000-\u001f]/.test(x);
  const check=(ok,detail)=>{if(!ok)throw Error('Relations de vestiaire incohérentes : '+detail+'.');};
  const keys=(x,allowed)=>object(x)&&Object.keys(x).every(k=>allowed.includes(k));
  function validate(s){
   if(!s)return true;
   const time=(x)=>integer(x.season,1,s.season)&&integer(x.week,0,s.economy?.week??0);
   if(s.v70Relations!==undefined){
    const r=s.v70Relations;check(keys(r,['version','last','pairs'])&&r.version===1&&text(r.last)&&Array.isArray(r.pairs)&&r.pairs.length<=8,'duos/version');
    const m=/^(\d+):(\d+)$/.exec(r.last);check(m&&integer(Number(m[1]),1,s.season)&&integer(Number(m[2]),0,s.economy.week),'date des duos');
    const seen=new Set();for(const p of r.pairs){check(keys(p,['key','a','b','score','season','week'])&&text(p.a)&&text(p.b)&&p.a!==p.b&&p.key===[p.a,p.b].sort().join('|')&&!seen.has(p.key)&&integer(p.score,-30,60)&&time(p),'lien');seen.add(p.key);}
   }
   if(s.livingLockerRoom!==undefined){
    const r=s.livingLockerRoom;check(keys(r,['version','history','commitments','closed'])&&r.version===1&&Array.isArray(r.history)&&r.history.length<=80&&Array.isArray(r.commitments)&&r.commitments.length<=30&&Array.isArray(r.closed)&&r.closed.length===0,'événements/version');
    const seen=new Set();for(const e of r.history){
     check(keys(e,['key','playerId','kind','title','context','trait','leadership','choice','season','week','status'])&&text(e.key)&&e.key===e.season+':'+e.week&&!seen.has(e.key)&&text(e.playerId)&&time(e)&&['tension','fatigue','revelation','contrat','leadership','ambition'].includes(e.kind)&&text(e.title,200)&&text(e.context,400)&&text(e.trait,40)&&integer(e.leadership,0,100)&&Object.hasOwn(CDLivingLockerRoom.CHOICES,e.choice)&&e.status==='decided','décision hebdomadaire');seen.add(e.key);
    }
    const ids=new Set();for(const c of r.commitments){
     check(keys(c,['id','playerId','originSeason','originWeek','dueWeek','baseline','target','status','resolvedWeek'])&&text(c.id,350)&&!ids.has(c.id)&&text(c.playerId)&&integer(c.originSeason,1,s.season)&&integer(c.originWeek,0,s.economy.week)&&c.id===c.originSeason+':'+c.originWeek+':'+c.playerId&&c.dueWeek===c.originWeek+2&&Number.isFinite(c.baseline)&&c.baseline>=0&&c.baseline<=100000&&c.target===60&&['open','honored','broken','expired'].includes(c.status),'engagement');
     check(c.status==='open'?c.resolvedWeek===undefined:integer(c.resolvedWeek,c.originWeek,s.economy.week),'clôture engagement');ids.add(c.id);
    }
   }
   for(const match of [s.live,s.lastReport])if(match?.v70Relations!==undefined){
    const r=match.v70Relations;check(keys(r,['version','side','duos'])&&r.version===1&&integer(r.side,0,1)&&r.side===match.userSide&&match.pair?.[r.side]===s.club&&Array.isArray(r.duos)&&r.duos.length>=1&&r.duos.length<=8,'photographie match');
    const players=new Set(match.sheets?.[r.side]?.initial||[]),seen=new Set();
    for(const p of r.duos){const key=[p.a,p.b].sort().join('|');check(keys(p,['a','b','score'])&&text(p.a)&&text(p.b)&&p.a!==p.b&&players.has(p.a)&&players.has(p.b)&&!seen.has(key)&&integer(p.score,-30,60),'partenaires au coup d’envoi');seen.add(key);}
   }
   return true;
  }
  const context=()=>({season:S.season,week:S.economy.week,club:S.club});
  const locked=()=>!!S.live||S.phase==='ended';
  const roster=()=>S.clubs[S.club].players;
  function project(){
   if(!S)return null;
   const ctx=context(),active=S.satisfactionVersion===1&&S.relationsVersion===1,blocked=locked()||Object.keys(S.economy?.talks||{}).length>0;
   const event=CDLivingLockerRoom.weeklyEvent(S),history=S.livingLockerRoom?.history||[];
   return {context:ctx,active,available:!blocked,reason:blocked?'Match en cours, saison terminée ou négociation ouverte.':'',morale:S.morale,trust:S.trust,
    players:roster().map(p=>({id:p.id,pos:p.pos,score:p.satisfaction?.score??null,condition:p.condition,injury:p.injury,minutes:p.dev?.minutes??null,personality:CDLivingLockerRoom.personality(p),promise:p.satisfaction?.promise?copy(p.satisfaction.promise):null,promiseHistory:copy(p.satisfaction?.history||[]),conversationAvailable:active&&!blocked&&!(p.satisfaction?.coachMeeting?.season===S.season&&p.satisfaction.coachMeeting.week===S.economy.week),promiseAvailable:active&&!blocked&&S.phase==='league'&&S.round<=23&&!p.injury&&!p.satisfaction?.promise})),
    conversations:[{id:'ecouter',label:'Écouter',detail:'Satisfaction +2.'},{id:'rassurer',label:'Rassurer',detail:'Satisfaction +1 ; premier entretien : moral +1.'},{id:'clarifier',label:'Clarifier',detail:'Premier entretien : confiance +1.'}],
    promiseOptions:Object.entries(PROMISE_MINUTES).map(([id,minutes])=>({id,minutes})),
    leaderId:CDRelationsV70.leader(S)?.id??null,pairs:copy(S.v70Relations?.pairs||[]),duoAvailable:CDRelationsV70.allowed(S),duoActions:Object.entries(CDRelationsV70.ACTIONS).map(([id,c])=>({id,...c})),
    event:event?{...event,available:CDLivingLockerRoom.allowed(S)&&!blocked,choices:Object.entries(CDLivingLockerRoom.CHOICES).map(([id,c])=>({id,label:c.label,detail:c.detail}))}:null,
    commitments:copy(S.livingLockerRoom?.commitments||[]),history:copy(history).reverse(),conversationHistory:(S.economy.relationLog||[]).filter(e=>e.kind==='coach').map(e=>({season:e.season,round:e.round,playerId:e.playerId,choice:e.detail,before:e.amount,after:e.minimum})),
    notice:'Relations, traits et réactions simulés. Les promesses portent sur trois rencontres jouées ; une blessure sans minute suspend le suivi. Deux partenaires doivent jouer simultanément pour influencer l’attaque (+1,8 point au maximum).'};
  }
  function execute(command,p){
   check(!!S,'carrière absente');validate(S);
   const fields={relationship_activate:['context'],relationship_conversation:['context','playerId','choice'],relationship_promise:['context','playerId','target'],relationship_duo:['context','mode','a','b'],locker_room_decision:['context','eventKey','choice']}[command];
   if(!fields)throw Error('Commande de relations inconnue.');
   if(!keys(p,fields)||!keys(p.context,['season','week','club'])||JSON.stringify(context())!==JSON.stringify({season:p.context.season,week:p.context.week,club:p.context.club}))throw Error('Contexte de vestiaire périmé.');
   if(locked()||Object.keys(S.economy?.talks||{}).length)throw Error('Décision de vestiaire indisponible.');
   let ok=false;
   if(command==='relationship_activate'){
    if(S.satisfactionVersion===1&&S.relationsVersion===1)throw Error('Le suivi du vestiaire est déjà actif.');
    if(S.satisfactionVersion!==1&&!activateSatisfaction())throw Error('Activation du suivi indisponible.');
    ok=S.relationsVersion===1||activateRelations();
   }else if(command==='relationship_conversation'){
    if(!text(p.playerId)||!['ecouter','rassurer','clarifier'].includes(p.choice))throw Error('Entretien invalide.');
    const first=!roster().some(p=>p.satisfaction?.coachMeeting?.season===S.season&&p.satisfaction.coachMeeting.week===S.economy.week);
    const person=roster().find(x=>x.id===p.playerId);if(person&&S.satisfactionVersion===1)ensureSatisfaction(person);
    ok=coachConversation(p.playerId,p.choice);
    if(ok){const impact=CDVestiaireV64.meetingImpact(p.choice,first);S.morale=clamp(S.morale+impact.morale,25,98);S.trust=clamp(S.trust+impact.trust,0,100);}
   }else if(command==='relationship_promise'){
    if(!text(p.playerId)||!Object.hasOwn(PROMISE_MINUTES,p.target))throw Error('Promesse invalide.');ok=makePlayingPromise(p.playerId,p.target);
   }else if(command==='relationship_duo'){
    if(!text(p.a)||!text(p.b)||!Object.hasOwn(CDRelationsV70.ACTIONS,p.mode))throw Error('Duo invalide.');ok=CDRelationsV70.perform(S,p.mode,p.a,p.b,{save:()=>true});
   }else{
    const event=CDLivingLockerRoom.weeklyEvent(S);if(!event||event.key!==p.eventKey||!Object.hasOwn(CDLivingLockerRoom.CHOICES,p.choice))throw Error('Événement de vestiaire périmé.');ok=CDLivingLockerRoom.apply(S,p.choice,{save:()=>true});
   }
   if(!ok)throw Error('Décision de vestiaire refusée : vérifiez disponibilité et limite hebdomadaire.');
   validate(S);return {relationshipDecision:{command,context:context()}};
  }
  let installed=false;
  function installHooks(){
   if(installed)return true;installed=true;
   const oldRound=recordSatisfactionRound;recordSatisfactionRound=function(l){
    const can=S&&S.satisfactionVersion===1&&S.relationsVersion===1&&l?.finished&&l.pair[l.userSide]===S.club;
    const before=can?CDVestiaireV64.snapshot(roster()):null,out=oldRound(l);
    if(out&&can)S.morale=clamp(S.morale+CDVestiaireV64.roundImpact(roster(),before).moodDelta,25,98);return out;
   };
   const oldCreate=createRugbyMatch;createRugbyMatch=function(pair,legacy=null,automated=false,preparation=null){const m=oldCreate(pair,legacy,automated,preparation);if(!legacy&&!automated){const data=CDRelationsV70.matchSnapshot(S,m);if(data)m.v70Relations=data;}return m;};
   const oldEdge=teamEdge;teamEdge=function(m,side,kind){return oldEdge(m,side,kind)+CDRelationsV70.matchBonus(m,side,kind);};
   const oldWeek=managerWeek;managerWeek=function(){const out=oldWeek.apply(this,arguments);if(S)CDLivingLockerRoom.settle(S);return out;};
   const oldReset=resetSatisfactionSeason;resetSatisfactionSeason=function(){const out=oldReset.apply(this,arguments);if(S)CDLivingLockerRoom.settle(S);return out;};
   return true;
  }
  return {project,execute,validate,installHooks};
 }
};

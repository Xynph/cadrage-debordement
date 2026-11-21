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
  // Dernière journée (numérotée à partir de 1) où une promesse de temps de jeu peut être faite : la règle de dist/economy.js (makePlayingPromise : refus si round > 23, round compté à partir de 0).
  const PROMISE_LAST_JOURNEY=24;
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
   if(s.groupTrustHistory!==undefined)check(Array.isArray(s.groupTrustHistory)&&s.groupTrustHistory.length<=70&&s.groupTrustHistory.every(h=>keys(h,['date','saison','confiance'])&&/^\d{4}-\d{2}-\d{2}$/.test(h.date)&&integer(h.saison,1,s.season)&&integer(h.confiance,0,100)),'relevé de confiance du groupe');
   for(const match of [s.live,s.lastReport])if(match?.v70Relations!==undefined){
    const r=match.v70Relations;check(keys(r,['version','side','duos'])&&r.version===1&&integer(r.side,0,1)&&r.side===match.userSide&&match.pair?.[r.side]===s.club&&Array.isArray(r.duos)&&r.duos.length>=1&&r.duos.length<=8,'photographie match');
    const players=new Set(match.sheets?.[r.side]?.initial||[]),seen=new Set();
    for(const p of r.duos){const key=[p.a,p.b].sort().join('|');check(keys(p,['a','b','score'])&&text(p.a)&&text(p.b)&&p.a!==p.b&&players.has(p.a)&&players.has(p.b)&&!seen.has(key)&&integer(p.score,-30,60),'partenaires au coup d’envoi');seen.add(key);}
   }
   return true;
  }
  const context=()=>({season:S.season,week:S.economy.week,club:S.club});
  // Confiance des joueurs envers le manager (21/11/2026) : distincte de S.trust (confiance du conseil). Par joueur :
  // 70 % de sa satisfaction (temps de jeu, entretiens, décisions de vestiaire) et 30 % de la fiabilité du manager envers
  // lui (promesses de temps de jeu et engagements de vestiaire tenus ou non, base 70, +10 par parole tenue, −15 par
  // parole non tenue). Groupe : moyenne pondérée par le leadership (un cadre pèse plus). Calculée à la volée depuis la
  // carrière : une ancienne sauvegarde a donc sa valeur dès le chargement.
  const satisfactionOf=p=>Number.isFinite(p?.satisfaction?.score)?p.satisfaction.score:65;
  function paroles(p,s=S){
   let tenues=0,rompues=0;
   for(const h of p?.satisfaction?.history||[]){if(h?.status==='kept')tenues++;else if(h?.status==='broken')rompues++;}
   for(const c of s?.livingLockerRoom?.commitments||[])if(c?.playerId===p?.id){if(c.status==='honored')tenues++;else if(c.status==='broken')rompues++;}
   return {tenues,rompues};
  }
  function playerTrust(p,s=S){
   const {tenues,rompues}=paroles(p,s),fiabilite=clamp(70+10*tenues-15*rompues,0,100);
   return clamp(Math.round(.7*satisfactionOf(p)+.3*fiabilite),0,100);
  }
  function groupTrust(s=S){
   const players=s?.clubs?.[s.club]?.players||[];if(!players.length)return null;
   let n=0,d=0;for(const p of players){const w=.5+(CDLivingLockerRoom.personality(p)?.leadership??50)/100;n+=w*playerTrust(p,s);d+=w;}
   return d?Math.round(n/d):null;
  }
  // Tensions du vestiaire : joueurs mécontents (satisfaction < 45, forte sous 30), paroles non tenues cette saison
  // (promesse de temps de jeu ou engagement de vestiaire), duos en risque de rivalité (lien suivi ≤ −12, ou deux
  // joueurs du même poste insatisfaits, règle du lien des duos). Niveau 0 calme, 1 faible, 2 vive, 3 crise.
  function tensions(s=S){
   const players=s?.clubs?.[s.club]?.players||[],rows=new Map(),add=(p,raison,points)=>{const r=rows.get(p.id)||{id:p.id,satisfaction:satisfactionOf(p),trust:playerTrust(p,s),raisons:[],points:0};if(!r.raisons.includes(raison)){r.raisons.push(raison);r.points+=points;}rows.set(p.id,r);};
   for(const p of players){
    const sat=satisfactionOf(p);if(sat<45)add(p,'mecontent',sat<30?3:2);
    const rompue=(p.satisfaction?.history||[]).some(h=>h?.status==='broken'&&h.season===s.season)||(s.livingLockerRoom?.commitments||[]).some(c=>c?.playerId===p.id&&c.status==='broken'&&c.originSeason===s.season);
    if(rompue)add(p,'promesse',2);
   }
   const byId=new Map(players.map(p=>[p.id,p])),duos=[],seen=new Set();
   for(const r of s?.v70Relations?.pairs||[]){const a=byId.get(r.a),b=byId.get(r.b);if(a&&b&&Number.isFinite(r.score)&&r.score<=-12&&!seen.has(r.key)){seen.add(r.key);duos.push({a:a.id,b:b.id,score:r.score});}}
   const tristes=players.filter(p=>satisfactionOf(p)<55);
   for(let i=0;i<tristes.length;i++)for(let j=i+1;j<tristes.length;j++){
    const a=tristes[i],b=tristes[j],key=[a.id,b.id].sort().join('|');
    if(a.fam!==b.fam||seen.has(key)||(s?.v70Relations?.pairs||[]).some(r=>r.key===key))continue;
    seen.add(key);duos.push({a:a.id,b:b.id,score:Math.min(satisfactionOf(a),satisfactionOf(b))<40?-20:-15});
   }
   duos.sort((x,y)=>x.score-y.score||String(x.a+x.b).localeCompare(String(y.a+y.b)));
   for(const d of duos)for(const id of [d.a,d.b])add(byId.get(id),'rivalite',1);
   const joueurs=[...rows.values()].sort((x,y)=>y.points-x.points||x.satisfaction-y.satisfaction||String(x.id).localeCompare(String(y.id)));
   const score=joueurs.reduce((n,r)=>n+r.points,0);
   return {level:score===0?0:score<=3?1:score<=7?2:3,score,players:joueurs,duos:duos.slice(0,6)};
  }
  // Relevé hebdomadaire de la confiance du groupe (même cadence et même date que finance.cashHistory), gardé 70 semaines.
  function trustReleve(){
   try{
    const date=typeof CDWorldCareer!=='undefined'&&S?.worldMode?CDWorldCareer.calendarToday(S):null,v=groupTrust();
    if(!date||!Number.isFinite(v))return;
    const h=S.groupTrustHistory=Array.isArray(S.groupTrustHistory)?S.groupTrustHistory:[],dernier=h[h.length-1];
    if(dernier&&dernier.date===date)dernier.confiance=v;else h.push({date,saison:S.season,confiance:v});
    if(h.length>70)h.splice(0,h.length-70);
   }catch(e){}
  }
  const locked=()=>!!S.live||S.phase==='ended';
  const roster=()=>S.clubs[S.club].players;
  function project(){
   if(!S)return null;
   const ctx=context(),active=S.satisfactionVersion===1&&S.relationsVersion===1,blocked=locked()||Object.keys(S.economy?.talks||{}).length>0;
   const event=CDLivingLockerRoom.weeklyEvent(S),history=S.livingLockerRoom?.history||[];
   return {context:ctx,active,available:!blocked,reason:blocked?'Match en cours, saison terminée ou négociation ouverte.':'',morale:S.morale,trust:S.trust,playerTrust:groupTrust(),playerTrustHistory:Array.isArray(S.groupTrustHistory)?copy(S.groupTrustHistory):[],tensions:tensions(),
    players:roster().map(p=>({id:p.id,pos:p.pos,score:p.satisfaction?.score??null,trust:playerTrust(p),condition:p.condition,injury:p.injury,minutes:p.dev?.minutes??null,personality:CDLivingLockerRoom.personality(p),promise:p.satisfaction?.promise?copy(p.satisfaction.promise):null,promiseHistory:copy(p.satisfaction?.history||[]),conversationAvailable:active&&!blocked&&!(p.satisfaction?.coachMeeting?.season===S.season&&p.satisfaction.coachMeeting.week===S.economy.week),promiseAvailable:active&&!blocked&&S.phase==='league'&&S.round<PROMISE_LAST_JOURNEY&&!p.injury&&!p.satisfaction?.promise})),
    conversations:[{id:'ecouter',label:'Écouter',detail:'Satisfaction +2.'},{id:'rassurer',label:'Rassurer',detail:'Satisfaction +1 ; premier entretien : moral +1.'},{id:'clarifier',label:'Clarifier',detail:'Premier entretien : confiance +1.'}],
    promiseLastJourney:PROMISE_LAST_JOURNEY,promiseOptions:Object.entries(PROMISE_MINUTES).map(([id,minutes])=>({id,minutes})),
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
   if(!ok)throw Error('Décision de vestiaire refusée : vérifie disponibilité et limite hebdomadaire.');
   validate(S);return {relationshipDecision:{command,context:context()}};
  }
  let installed=false;
  function installHooks(){
   if(installed)return true;installed=true;
   const oldRound=recordSatisfactionRound;recordSatisfactionRound=function(l){
    const can=S&&S.satisfactionVersion===1&&S.relationsVersion===1&&l?.finished&&l.pair[l.userSide]===S.club;
    const before=can?CDVestiaireV64.snapshot(roster()):null,out=oldRound(l);
    if(out&&can)S.morale=clamp(S.morale+CDVestiaireV64.roundImpact(roster(),before).moodDelta,25,98);trustReleve();return out;
   };
   const oldCreate=createRugbyMatch;createRugbyMatch=function(pair,legacy=null,automated=false,preparation=null){const m=oldCreate(pair,legacy,automated,preparation);if(!legacy&&!automated){const data=CDRelationsV70.matchSnapshot(S,m);if(data)m.v70Relations=data;}return m;};
   const oldEdge=teamEdge;teamEdge=function(m,side,kind){return oldEdge(m,side,kind)+CDRelationsV70.matchBonus(m,side,kind);};
   const oldWeek=managerWeek;managerWeek=function(){const out=oldWeek.apply(this,arguments);if(S)CDLivingLockerRoom.settle(S);return out;};
   const oldReset=resetSatisfactionSeason;resetSatisfactionSeason=function(){const out=oldReset.apply(this,arguments);if(S)CDLivingLockerRoom.settle(S);return out;};
   return true;
  }
  return {project,execute,validate,installHooks,tensions,groupTrust,playerTrust};
 }
};

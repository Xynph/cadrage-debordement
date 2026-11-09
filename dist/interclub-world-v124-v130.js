'use strict';
// V124-V130 — Monde vivant interclubs; source sportive : record(r) natif uniquement.
// Club fictif ou mod réel : aucune personnalité attribuée à un entraîneur réel.
(function(root,factory){
 const api=factory();
 if(typeof module==='object'&&module.exports)module.exports=api;
 if(root)root.CDInterclubWorld=api;
})(typeof globalThis==='object'?globalThis:null,function(){
 const clamp=(v,a,b)=>Math.max(a,Math.min(b,Math.round(v)));
 const safe=x=>String(x??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
 const TONES=['Analytique','Prudent','Combattif','Protecteur','Exigeant'];
 const idOf=c=>Number.isInteger(c?.id)?c.id:null;
 const pairKey=(a,b)=>[a,b].sort((x,y)=>x-y).join(':');
 const world=s=>typeof CDWorldCareer!=='undefined'&&CDWorldCareer.active(s);
 const context=(s,r)=>world(s)?{season:r?.season??s.season,phase:r?.phase,round:r?.week,week:r?.week,fixtureId:r?.fixtureId,leagueId:r?.competitionId}:r?.franceContext||{season:s?.season,phase:s?.phase,round:s?.round};
 const stamp=(s,r)=>context(s,r).fixtureId?s.season+':'+context(s,r).fixtureId:[s.season,s.phase,s.round,r.pair[0],r.pair[1]].join(':');
 const fresh=()=>({version:1,pairs:{},coaches:{},events:[],years:[],lastSeason:0,observedSeason:0,seen:[],seasonMatches:0});
 const state=s=>s?.interclubWorld?.version===1&&s.interclubWorld.pairs&&
  Array.isArray(s.interclubWorld.events)&&Array.isArray(s.interclubWorld.years)?s.interclubWorld:fresh();
 function validMatch(s,r){
  if(!s||!Number.isInteger(s.season)||s.season<1||!Number.isInteger(s.round)||
   !(world(s)?['league','pool','r16','quarter','barrage','semi','final','access']:['league','barrage','semi','final','access']).includes(context(s,r).phase)||!Array.isArray(s.clubs))return false;
  if(world(s)&&(!r||typeof r.fixtureId!=='string'||!r.fixtureId||r.season!==s.season||!Number.isInteger(r.week)||r.week!==s.round||typeof r.competitionId!=='string'))return false;
  if(!r||!Array.isArray(r.pair)||r.pair.length!==2||!Array.isArray(r.score)||r.score.length!==2)return false;
  const [a,b]=r.pair;
  return Number.isInteger(a)&&Number.isInteger(b)&&a!==b&&s.clubs.some(c=>idOf(c)===a)&&s.clubs.some(c=>idOf(c)===b)&&
   r.score.every(n=>Number.isInteger(n)&&n>=0&&n<=250);
 }
 function profile(id){
  if(!Number.isInteger(id)||id<0||id>200)return null;
  return {style:TONES[(id*17+3)%TONES.length],name:'Banc du club '+id};
 }
 function reaction(style,won,margin,upset){
  if(won)return upset?'Notre groupe a déjoué les pronostics ; il doit confirmer.':
   style==='Prudent'?'Le résultat est acquis ; rien n’est terminé.':
   style==='Exigeant'?'La victoire ne doit pas masquer nos lacunes.':
   'Le collectif a répondu sur le terrain ; gardons le cap.';
  if(margin<=7)return 'La rencontre s’est jouée sur des détails. Nous devons répondre.';
  return style==='Protecteur'?'Je protège le groupe ; nous travaillerons sur les erreurs.':
   style==='Combattif'?'Nous avons manqué de caractère ; une réaction est attendue.':
   'Nous devons analyser ce revers et corriger notre préparation.';
 }
 function accept(s,r){
  if(!validMatch(s,r))return null;
  const a=r.pair[0],b=r.pair[1],first=s.clubs.find(c=>c.id===a),second=s.clubs.find(c=>c.id===b);
  const key=pairKey(a,b),tick=stamp(s,r),prior=state(s);
  if(prior.events.some(e=>e.id===tick)||prior.observedSeason===s.season&&prior.seen?.includes(tick))return null;
  const next=JSON.parse(JSON.stringify(prior)),p=next.pairs[key]||{a:Math.min(a,b),b:Math.max(a,b),games:0,winsA:0,winsB:0,draws:0,tension:20,years:[],lastWinner:null,lastSeason:0};
  const ctx=context(s,r),h=r.score[0],away=r.score[1],diff=h-away,winner=ctx.phase!=='league'&&r.pair.includes(r.winner)?r.winner:diff===0?null:diff>0?a:b,loser=winner===a?b:a;
  if(next.observedSeason!==s.season){next.observedSeason=s.season;next.seen=[];next.seasonMatches=0;}
  next.seen.push(tick);next.seasonMatches++;
  const close=Math.abs(diff)<=7,switched=winner!==null&&p.lastWinner!==null&&p.lastWinner!==winner;
  p.games++;
  if(winner===null)p.draws++;else if(winner===p.a)p.winsA++;else p.winsB++;
  p.tension=clamp(p.tension+(close?8:Math.abs(diff)>=25?-3:3)+(switched?7:0)+(p.games>=4?2:0),0,100);
  p.years=Array.from(new Set([...p.years,s.season])).slice(-20);
  p.lastWinner=winner;p.lastSeason=s.season;
  next.pairs[key]=p;
  const weaker=Number.isFinite(first.base)&&Number.isFinite(second.base)?
   (first.base+10<second.base?a:second.base+10<first.base?b:null):null;
  const upset=winner!==null&&winner===weaker;
  const type=upset?'surprise':close&&p.games>=3?'rivalite':Math.abs(diff)>=25?'large_ecart':winner===null?'nul':'rencontre';
  const target=winner===null?null:loser,clubId=target??b,coach=next.coaches[String(clubId)]||{
   clubId,style:profile(clubId).style,pressure:30,consecutiveLosses:0,season: s.season,
   lastReaction:'',lastRound:-1};
  const targetLost=winner!==null&&clubId===loser;
  coach.pressure=clamp(coach.pressure+(targetLost?(close?4:9):-5)+(upset&&targetLost?5:0),0,100);
  coach.consecutiveLosses=targetLost?Math.min(20,coach.consecutiveLosses+1):0;
  coach.season=s.season;coach.lastRound=ctx.round;
  coach.lastReaction=reaction(coach.style,!targetLost,Math.abs(diff),upset);
  next.coaches[String(clubId)]=coach;
  const event={id:tick,season:s.season,round:ctx.round,phase:ctx.phase,...(ctx.fixtureId?{fixtureId:ctx.fixtureId,week:ctx.week,leagueId:ctx.leagueId}:{}),a,b,home:h,away,
   winner,type,tension:p.tension,clubId,reaction:coach.lastReaction,pressure:coach.pressure,
   close,upset};
  next.events.push(event);
  next.events=next.events.slice(-140);
  s.interclubWorld=next;
  return event;
 }
 function season(s,previousSeason){
  if(!s||!Number.isInteger(s.season)||s.season<=previousSeason)return false;
  const current=s.interclubWorld;
  if(!current||current.version!==1||current.lastSeason>=previousSeason)return false;
  const matches=current.events.filter(e=>e.season===previousSeason);
  const active=Object.values(current.pairs).filter(p=>p.lastSeason===previousSeason)
   .sort((a,b)=>b.tension-a.tension||pairKey(a.a,a.b).localeCompare(pairKey(b.a,b.b)));
  current.years.push({season:previousSeason,matches:current.observedSeason===previousSeason?current.seasonMatches:matches.length,mostIntense:active[0]?pairKey(active[0].a,active[0].b):null,
   rivalries:active.filter(p=>p.tension>=55).length});
  current.years=current.years.slice(-20);current.lastSeason=previousSeason;
  for(const c of Object.values(current.coaches)){
   c.pressure=clamp(c.pressure*.8+6,0,100);
   c.consecutiveLosses=0;
  }
  return true;
 }
 function top(s,n=5){
  const all=Object.values(state(s).pairs).filter(p=>p.games>=2);
  return all.sort((a,b)=>b.tension-a.tension||b.games-a.games||a.a-b.a||a.b-b.b).slice(0,n);
 }
 function panel(s,full=false){
  if(!s||!Array.isArray(s.clubs))return '';
  const st=state(s),club=id=>s.clubs.find(x=>x.id===id),events=st.events.slice(- (full?8:4)).reverse();
  const leading=top(s,full?7:3);
  const headline='<div class="cardtitle"><h2>La vie des clubs · Rivalités et réactions</h2><span class="tag">V124–V130</span></div>';
  const rivalry=leading.map(p=>'<div class="row budgetline"><span>'+
   safe(club(p.a)?.abbr||'Club '+p.a)+' / '+safe(club(p.b)?.abbr||'Club '+p.b)+
   '</span><strong>Tension '+p.tension+'/100 · '+p.games+' rencontres</strong></div>').join('');
  const stories=events.map(e=>{
   const label=e.type==='surprise'?'Surprise sportive':e.type==='rivalite'?'Duel sous tension':
    e.type==='large_ecart'?'Large écart':e.type==='nul'?'Match nul':'Résultat du championnat';
   return '<article class="office-message"><small>S'+e.season+' · Journée '+(e.round+1)+' · '+safe(label)+'</small>'+
    '<p><strong>'+safe(club(e.a)?.abbr||'Club '+e.a)+' '+e.home+' – '+e.away+' '+
    safe(club(e.b)?.abbr||'Club '+e.b)+'</strong></p>'+
    '<p>Réaction simulée du banc de '+safe(club(e.clubId)?.name||'club '+e.clubId)+
    ' : « '+safe(e.reaction)+' » · Pression '+e.pressure+'/100</p></article>';
  }).join('');
  return '<section class="card" aria-label="Monde vivant interclubs V124">'+headline+
   '<p class="help">Rivalités évolutives fondées uniquement sur les matchs réellement simulés. Réactions fictives, non attribuées à des entraîneurs réels. Historique intersaisons enregistré sans toucher aux scores.</p>'+
   (rivalry||'<p>Les rivalités émergent après plusieurs confrontations.</p>')+
   (full?'<h3>Échos du championnat</h3>':'<details><summary>Échos du championnat ('+events.length+')</summary>')+
   (stories||'<p>Aucun résultat encore enregistré dans cette carrière.</p>')+
   (full?'':'</details>')+
   (full?'<p class="help">Archives : '+st.years.length+' saison(s) clôturée(s) · '+Object.keys(st.pairs).length+' face-à-face suivis.</p>':'')+
   '</section>';
 }
 function install(root){
  if(!root||typeof root.record!=='function'||typeof root.advanceSeason!=='function'||typeof root.render!=='function')return false;
  if(root.__interclubLivingInstalled)return true;
  root.__interclubLivingInstalled=true;
  const current=()=>typeof S!=='undefined'?S:root.S;
  const oldRecord=root.record,oldSeason=root.advanceSeason,oldRender=root.render;
  root.record=function(r){
   const out=oldRecord.apply(this,arguments);
   const s=current();
   if(s)accept(s,r);
   return out;
  };
  root.advanceSeason=function(){
   const s=current(),previous=s?.season;
   const out=oldSeason.apply(this,arguments);
   const currentState=current();
   if(Number.isInteger(previous)&&currentState?.season===previous+1&&season(currentState,previous)&&typeof root.save==='function')root.save();
   return out;
  };
  root.render=function(){
   const out=oldRender.apply(this,arguments);
   if(typeof document==='undefined'||typeof view==='undefined'||view!=='dashboard')return out;
   const target=root.document?.querySelector('#app .layout .main .da42-workspace-shell[data-da43-section="dashboard"] [data-da42-page="dossiers"]');
   if(target&&typeof target.insertAdjacentHTML==='function')target.insertAdjacentHTML('beforeend',panel(current()));
   return out;
  };
  if(typeof root.worldLeaguePanel==='function'){
   const original=root.worldLeaguePanel;
   root.worldLeaguePanel=function(){return original.apply(this,arguments)+panel(current(),true)};
  }
  return true;
 }
 return Object.freeze({profile,reaction,validMatch,accept,season,top,panel,state,install});
});
if(typeof CDNativeHeadless==='undefined'&&typeof document!=='undefined'&&typeof CDInterclubWorld==='object')CDInterclubWorld.install(globalThis);

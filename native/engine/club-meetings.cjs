'use strict';
// Serialized in the career VM. This domain records obligations only; the existing
// press, medical and strategy controllers retain every actual career effect.
module.exports={
 files:[],
 commands:['club_meeting_ack','club_meeting_continue'],
 factory:function nativeClubMeetings(){
  const copy=x=>JSON.parse(JSON.stringify(x)),object=x=>x!==null&&typeof x==='object'&&!Array.isArray(x);
  const integer=(x,a=0,b=1000000)=>Number.isSafeInteger(x)&&x>=a&&x<=b;
  const text=(x,max=600)=>typeof x==='string'&&x.length>0&&x.length<=max&&!/[\u0000-\u001f\u007f]/.test(x);
  const playerId=x=>text(x,180)&&/^[A-Za-z0-9:_-]+$/.test(x);
  const shape=(x,allowed,required=allowed)=>object(x)&&Object.keys(x).every(k=>allowed.includes(k))&&required.every(k=>Object.hasOwn(x,k));
  const check=(ok,message)=>{if(!ok)throw Error('Rendez-vous du club : '+message+'.');};
  const same=(a,b)=>!!a&&!!b&&a.season===b.season&&a.week===b.week&&a.club===b.club;
  const context=(s=S)=>({season:s.season,week:s.franceMode?.version===1?s.franceMode.week:s.round,club:s.club});
  const hasClub=(s=S)=>s?.national?.role?.club!==false;
  const roster=(s=S)=>s.clubs[s.club].players;
  const reasons={press:'Une conférence de presse est disponible pour cette semaine.',injury:'Une blessure enregistrée appelle un point médical.',reprise:'Une reprise est enregistrée pour ce joueur.',intro:'Prendre connaissance des priorités et du bilan actuels du club.',periodic:'Faire le bilan des quatre dernières semaines simulées.',objective:'Un objectif enregistré a changé de statut de bilan.',finance:'La projection financière du club présente un montant négatif.'};
  const rank={press:0,medical:1,board:2};
  let installed=false,advanceFrom=null;
  const readCommands=['snapshot','export','save','load','import','shutdown','list_profiles','profile_list'];
  // Réglages de présentation des packs d'identités : ni temps, ni effectif, ni finances, ni décision de club.
  // Ils restent possibles pendant un rendez-vous ; le pack n'est appliqué qu'à l'affichage (voir docs/packs-pendant-un-rendez-vous.md).
  // Suivre un club (fiche club) : simple préférence de lecture, permise pendant un rendez-vous.
  const presentationCommands=['pack_inspect','pack_install','pack_select','club_follow'];
  const passive=command=>readCommands.includes(command)||presentationCommands.includes(command);
  const pending='terminez le rendez-vous en attente, dans votre courrier, en Réception, avant de poursuivre';
  const stage=p=>p.medicalV68?.stage||null;
  const medicalAvailable=s=>!s.live&&!s.trained&&s.phase==='league';
  const priority=s=>s.v105to110?.priority||'stabilite';
  const pressAvailableState=s=>typeof CDV60RichPress!=='undefined'?!!CDV60RichPress.prepare(s):!s.live&&!same(s.pressConference?.lastOutcome?.context,context(s))&&!(s.pressConference?.history||[]).some(h=>h.season===s.season&&h.week===context(s).week&&(h.club===undefined||h.club===s.club));
  const medicalDecisionRequired=(e,s=S)=>e.kind==='medical'&&medicalAvailable(s)&&roster(s).some(p=>p.id===e.playerId&&p.injury>0);
  const ackAllowed=(e,s=S)=>!!e&&!e.completed&&(e.kind==='board'||e.kind==='medical'&&!medicalDecisionRequired(e,s));
  const projectDomain=id=>nativeSystems.domain(id)?.project()||null;
  function sourceValid(e){
   const c=e.context;
   if(e.kind==='press')return e.reason===reasons.press&&e.sourceKey==='press:'+c.season+':'+c.club+':'+c.week;
   if(e.kind==='medical'){
    const prefix='medical:'+c.season+':'+c.club+':'+e.playerId+':',suffix=e.sourceKey.slice(prefix.length),m=/^(injury|reprise):(0|[1-9]\d*)$/.exec(suffix);
    return e.sourceKey.startsWith(prefix)&&m&&integer(+m[2],m[1]==='injury'?1:0)&&e.reason===reasons[m[1]];
   }
   if(e.reason===reasons.intro)return e.sourceKey==='board:intro:'+c.season+':'+c.club;
   if(e.reason===reasons.periodic)return c.week>=4&&e.sourceKey==='board:periodic:'+c.season+':'+c.club+':'+Math.floor(c.week/4);
   if(e.reason===reasons.finance)return ['cash','forecast'].some(w=>e.sourceKey==='board:finance:'+c.season+':'+c.club+':'+c.week+':'+w);
   return e.reason===reasons.objective&&e.sourceKey.startsWith('board:objective:'+c.season+':'+c.club+':')&&/:(met|missed|unverified)$/.test(e.sourceKey);
  }
  function state(){return S.clubMeetings||(S.clubMeetings={version:1,serial:0,current:null,queue:[],receipts:[],seen:[],observed:null});}
  function validate(s){
   if(!s||s.clubMeetings===undefined)return true;
   const st=s.clubMeetings,active=hasClub(s);
   check(shape(st,['version','serial','current','queue','receipts','seen','observed'])&&st.version===1&&integer(st.serial)&&Array.isArray(st.queue)&&st.queue.length<=80&&Array.isArray(st.receipts)&&st.receipts.length<=96&&Array.isArray(st.seen)&&st.seen.length<=256&&st.seen.every(x=>text(x))&&new Set(st.seen).size===st.seen.length,'version, bornes ou champs inconnus');
   check(!active||st.queue.length===0||!s.live&&(st.current!==null||!!s.sceneInvitations?.activeId),'file sans rendez-vous actif ou en conflit avec un match');
   const maxWeek=typeof CDWorldCareer!=='undefined'&&CDWorldCareer.active(s)?CDWorldCareer.sizing(s).maxRound:s.franceMode?.version===1?34:26;
   const date=c=>shape(c,['season','week','club'])&&integer(c.season,1,s.season)&&integer(c.week,0,maxWeek)&&integer(c.club,0,s.clubs.length-1)&&(c.season<s.season||c.week<=context(s).week);
   const ids=new Set(),sources=new Set();
   const decision=(e,live)=>{
    const d=e.decision;
    check(shape(d,['command','value','stage','protocol'],['command','value'])&&text(d.command,60)&&(d.value===null||text(d.value,180)),'reçu de décision');
    if(e.kind==='press'){
     check(d.command==='press_conference'&&d.value===null&&d.stage===undefined&&d.protocol===undefined,'réponse de presse');
     if(live)check(same(s.pressConference?.lastOutcome?.context,e.context),'conférence non enregistrée');
    }else if(e.kind==='board'){
     check(['club_meeting_ack','club_board_priority','club_board_project','club_board_objective'].includes(d.command)&&text(d.value,180)&&d.stage===undefined&&d.protocol===undefined,'décision de direction');
     if(['club_meeting_ack','club_board_priority'].includes(d.command))check(['performance','stabilite','finances','effectif'].includes(d.value),'priorité du reçu');
     if(d.command==='club_board_project')check(['video','medical','logistique'].includes(d.value),'projet du reçu');
     if(d.command==='club_board_objective')check(['wins','points','rank','cash'].some(type=>d.value==='goal:'+e.context.season+':'+e.context.club+':'+type),'objectif du reçu');
     if(live){
      if(['club_meeting_ack','club_board_priority'].includes(d.command))check(d.value===priority(s),'priorité non enregistrée');
      if(d.command==='club_board_project')check(s.v105to110?.projects.some(p=>p.kind===d.value),'projet non enregistré');
      if(d.command==='club_board_objective')check(s.nativeBoardCalendar?.objectives.some(o=>o.id===d.value),'objectif non enregistré');
     }
    }else{
     check(['club_meeting_ack','medical_protocol','medical_return'].includes(d.command)&&['blesse','reprise','progressif','termine',null].includes(d.stage)&&(d.protocol===null||['prudent','standard','accelere'].includes(d.protocol)),'décision médicale');
     if(d.command==='medical_protocol')check(['prudent','standard','accelere'].includes(d.value)&&d.protocol===d.value&&d.stage==='blesse','protocole du reçu');
     if(d.command==='medical_return')check(['progressif','complet'].includes(d.value)&&d.stage===(d.value==='progressif'?'progressif':'termine'),'retour du reçu');
     if(d.command==='club_meeting_ack')check(d.value==='maintain'?d.stage==='reprise':d.value==='read'&&d.stage!=='reprise','confirmation médicale');
     if(live){const p=roster(s).find(p=>p.id===e.playerId);check(p&&stage(p)===d.stage&&(p.medicalV68?.protocol||null)===d.protocol,'plan médical non enregistré');if(d.command==='club_meeting_ack')check(!medicalDecisionRequired(e,s),'protocole médical encore requis');}
    }
   };
   function entry(e,live,receipt=false){
    check(shape(e,['id','kind','context','playerId','reason','sourceKey','completed','decision'],['id','kind','context','reason','sourceKey','completed','decision'])&&text(e.id,180)&&Object.hasOwn(rank,e.kind)&&date(e.context)&&text(e.sourceKey)&&typeof e.completed==='boolean'&&(e.decision===null||object(e.decision))&&e.completed===!!e.decision,'réunion ou achèvement invalide');
    const match=/^club-meeting:(\d+):(\d+):(\d+):(\d+)$/.exec(e.id);
    check(match&&e.id==='club-meeting:'+e.context.season+':'+e.context.week+':'+e.context.club+':'+Number(match[4])&&+match[1]===e.context.season&&+match[2]===e.context.week&&+match[3]===e.context.club&&integer(+match[4],1,st.serial)&&!ids.has(e.id)&&!sources.has(e.sourceKey),'identifiant ou doublon');ids.add(e.id);sources.add(e.sourceKey);
    check((e.kind==='medical'?playerId(e.playerId):e.playerId===undefined)&&sourceValid(e),'source de réunion invalide');
    if(active&&e.kind==='press'&&!e.completed)check(pressAvailableState(s),'conférence déjà réalisée ou indisponible');
    if(live){check(same(e.context,context(s))&&!s.live&&!s.sceneInvitations?.activeId,'contexte de réunion périmé');if(e.kind==='medical'){const p=roster(s).find(p=>p.id===e.playerId);check(p,'joueur médical absent');if(!e.completed)check(p.injury>0||stage(p)==='reprise','suivi médical sans blessure ni reprise');}}
    if(receipt)check(e.completed,'reçu incomplet');
    if(e.decision)decision(e,live);
   }
   if(st.current!==null)entry(st.current,active);
   for(let i=0;i<st.queue.length;i++){const e=st.queue[i];entry(e,false);check((!active||same(e.context,context(s)))&&!e.completed&&(i===0||rank[e.kind]>=rank[st.queue[i-1].kind]),'file périmée, désordonnée ou déjà traitée');if(active&&e.kind==='medical')check(roster(s).some(p=>p.id===e.playerId&&(p.injury>0||stage(p)==='reprise')),'joueur absent ou suivi médical indisponible dans la file');}
   for(const e of st.receipts)entry(e,false,true);
   const observed=st.observed;
   if(observed!==null){
    check(shape(observed,['context','players','objectives','warning'])&&date(observed.context)&&Array.isArray(observed.players)&&observed.players.length<=150&&Array.isArray(observed.objectives)&&observed.objectives.length<=8&&['none','forecast','cash'].includes(observed.warning),'observations invalides');
    const people=new Set(),goals=new Set();
    for(const p of observed.players){check(shape(p,['id','injured','stage','episode'])&&text(p.id,180)&&typeof p.injured==='boolean'&&['blesse','reprise','progressif','termine',null].includes(p.stage)&&integer(p.episode,0)&&!people.has(p.id),'observation de joueur');people.add(p.id);}
    for(const o of observed.objectives){check(shape(o,['id','status'])&&text(o.id,180)&&['pending','unverified','met','missed'].includes(o.status)&&!goals.has(o.id),'observation d’objectif');goals.add(o.id);}
   }
   return true;
  }
  function project(){
   const st=S?.clubMeetings,active=hasClub();
   const display=e=>({...copy(e),ackAllowed:ackAllowed(e)});
   return {scene:active&&st?.current?display(st.current):null,queue:(active?st?.queue||[]:[]).map(display),receipts:copy(st?.receipts||[]),notice:active?'Rendez-vous de carrière obligatoires. Les décisions sont appliquées par les systèmes existants ; lire un bilan n’accorde aucun effet sportif.':'Vous vous consacrez à votre sélection. Les reçus des rendez-vous du club restent consultables.'};
  }
  function add(st,kind,reason,sourceKey,playerId){
   if(st.seen.includes(sourceKey)||st.queue.length>=80)return;
   const c=context(),e={id:'club-meeting:'+c.season+':'+c.week+':'+c.club+':'+(++st.serial),kind,context:c,...(playerId?{playerId}:{}),reason,sourceKey,completed:false,decision:null};
   st.queue.push(e);st.queue.sort((a,b)=>rank[a.kind]-rank[b.kind]);st.seen.push(sourceKey);st.seen=st.seen.slice(-256);
  }
  function promote(st){if(!st.current&&!S.live&&!S.sceneInvitations?.activeId)st.current=st.queue.shift()||null;}
  function complete(e,command,value){
   const p=e.kind==='medical'?roster().find(p=>p.id===e.playerId):null;
   e.decision={command,value,...(p?{stage:stage(p),protocol:p.medicalV68?.protocol||null}:{})};e.completed=true;
  }
  function observe(command,payload={}){
   // Called by the worker after an accepted command, inside its atomic save.
   if(!S||typeof command!=='string'||passive(command))return;
   const transition=advanceFrom;advanceFrom=null;
   let st=S.clubMeetings;
   // Leaving the club expires its pending work, never its decision history.
   // Reads of old saves stay pure; the next accepted mutation does the cleanup.
   if(!hasClub()){if(st){st.current=null;st.queue=[];}return;}
   if(!st&&command.startsWith('club_meeting_'))return;
   if(st){
    const e=st.current;
    if(e&&!e.completed&&same(e.context,context())){
     if(e.kind==='press'&&command==='press_conference'&&same(payload.context,e.context)&&same(S.pressConference?.lastOutcome?.context,e.context))complete(e,command,null);
     if(e.kind==='medical'&&payload.id===e.playerId&&same(payload.context,e.context)){
      const p=roster().find(p=>p.id===e.playerId);
      if(command==='medical_protocol'&&p?.medicalV68?.protocol===payload.protocol&&stage(p)==='blesse')complete(e,command,payload.protocol);
      if(command==='medical_return'&&['progressif','complet'].includes(payload.choice)&&stage(p)===(payload.choice==='progressif'?'progressif':'termine'))complete(e,command,payload.choice);
     }
     if(e.kind==='board'&&same(payload.context,e.context)){
      if(command==='club_board_priority'&&priority(S)===payload.key)complete(e,command,payload.key);
      if(command==='club_board_project'&&S.v105to110?.projects.some(p=>p.kind===payload.kind))complete(e,command,payload.kind);
      if(command==='club_board_objective'){const id='goal:'+S.season+':'+S.club+':'+payload.type;if(S.nativeBoardCalendar?.objectives.some(o=>o.id===id))complete(e,command,id);}
     }
    }
    // A deliberately replaced context, or an actually departed player, expires
    // stale work. Ordinary progression is blocked before mutation by guard().
    if(st.current&&(!same(st.current.context,context())||st.current.kind==='medical'&&!roster().some(p=>p.id===st.current.playerId)))st.current=null;
    st.queue=st.queue.filter(e=>same(e.context,context())&&(e.kind!=='medical'||roster().some(p=>p.id===e.playerId)));
   }
   if(S.live)return;
   st=st||state();
   // A legacy save can enter a match before any management baseline exists.
   // The hook captures only a real clock transition, never a guessed advance.
   const previous=st.observed||(transition?{context:transition.from,players:[],objectives:[],warning:'none'}:null),c=context(),scope=previous&&previous.context.season===c.season&&previous.context.club===c.club;
   const advanced=!!previous&&!same(previous.context,c),fresh=command==='new_career'||!!previous&&!scope;
   const press=projectDomain('press'),support=projectDomain('clubSupport'),strategy=projectDomain('clubStrategy');
   if((command==='new_career'||advanced)&&press?.conference?.available&&same(press.context,c))add(st,'press',reasons.press,'press:'+c.season+':'+c.club+':'+c.week);
   const oldPlayers=new Map((scope?previous.players:[]).map(p=>[p.id,p]));
   const players=roster().map(p=>{const old=oldPlayers.get(p.id),injured=p.injury>0;return {id:p.id,injured,stage:stage(p),episode:(old?.episode||0)+(injured&&!old?.injured?1:0)};});
   for(const p of support?.medical?.players||[]){
    const now=players.find(x=>x.id===p.id),old=oldPlayers.get(p.id);if(!now)continue;
    if(p.injury>0&&!old?.injured)add(st,'medical',reasons.injury,'medical:'+c.season+':'+c.club+':'+p.id+':injury:'+now.episode,p.id);
    else if(p.injury<=0&&p.stage==='reprise'&&old?.stage!=='reprise')add(st,'medical',reasons.reprise,'medical:'+c.season+':'+c.club+':'+p.id+':reprise:'+now.episode,p.id);
   }
   const board=strategy?.board,objectives=(board?.objectives||[]).map(o=>({id:o.id,status:o.status}));
   const finance=strategy?.finance,warning=finance?.cash<0?'cash':finance?.baseForecast<0?'forecast':'none';
   if(board&&same(strategy.context,c)){
    if(fresh)add(st,'board',reasons.intro,'board:intro:'+c.season+':'+c.club);
    else if(advanced&&scope&&Math.floor(c.week/4)>Math.floor(previous.context.week/4))add(st,'board',reasons.periodic,'board:periodic:'+c.season+':'+c.club+':'+Math.floor(c.week/4));
    const oldGoals=new Map((scope?previous.objectives:[]).map(o=>[o.id,o.status]));
    const changed=objectives.find(o=>oldGoals.has(o.id)&&oldGoals.get(o.id)!==o.status&&['met','missed','unverified'].includes(o.status));
    if(changed)add(st,'board',reasons.objective,'board:objective:'+c.season+':'+c.club+':'+changed.id+':'+changed.status);
    if(previous&&scope&&warning!=='none'&&warning!==previous.warning)add(st,'board',reasons.finance,'board:finance:'+c.season+':'+c.club+':'+c.week+':'+warning);
   }
   st.observed={context:c,players,objectives,warning};promote(st);
  }
  function guard(command,payload={}){
   const st=S?.clubMeetings,e=st?.current||st?.queue?.[0];
   if(!hasClub()||!e||passive(command)||command==='new_career')return true;
   // The mandate controller validates the actual offer and confirmation before
   // observe() expires club obligations after an accepted departure.
   if(command==='national_take_job'&&payload.role==='nation'&&payload.confirmed===true)return true;
   // A pre-existing private conversation gets to finish before queued rooms.
   if(!st.current&&S.sceneInvitations?.activeId&&['scene_invitation_reply','scene_invitation_close'].includes(command)&&payload.id===S.sceneInvitations.activeId)return true;
   if(['club_meeting_ack','club_meeting_continue'].includes(command))return true;
   if(!st.current||e.completed)check(false,pending);
   check(!S.live&&same(e.context,context()),'contexte périmé');
   if(e.kind==='press'&&command==='press_conference'){check(same(payload.context,e.context),'contexte de presse périmé');return true;}
   if(e.kind==='medical'&&['medical_protocol','medical_return'].includes(command)){
    check(payload.id===e.playerId&&same(payload.context,e.context),'décision médicale pour un autre joueur ou contexte');
    const p=roster().find(p=>p.id===e.playerId);
    check(command==='medical_protocol'?p?.injury>0:p&&p.injury<=0&&stage(p)==='reprise','décision médicale inadaptée');return true;
   }
   if(e.kind==='medical'&&command==='set_player_load'){
    const p=roster().find(p=>p.id===e.playerId);
    check(payload.playerId===e.playerId&&p&&p.injury<=0&&stage(p)==='reprise'&&!S.trained&&S.phase!=='ended'&&['collective','repos','normal','intense'].includes(payload.mode),'charge de reprise indisponible pour ce joueur');return true;
   }
   if(e.kind==='board'&&['club_board_priority','club_board_project','club_board_objective'].includes(command)){check(same(payload.context,e.context),'contexte de direction périmé');return true;}
   check(false,pending);
  }
  function execute(command,payload){
   check(!!S,'carrière absente');check(hasClub(),'mandat en club absent');validate(S);
   check(['club_meeting_ack','club_meeting_continue'].includes(command)&&shape(payload,['meetingId'])&&text(payload.meetingId,180),'commande ou paramètres invalides');
   const st=S.clubMeetings,e=st?.current;
   check(e&&e.id===payload.meetingId&&same(e.context,context())&&!S.live,'rendez-vous absent ou périmé');
   if(command==='club_meeting_ack'){
    check(ackAllowed(e),'une décision réelle est encore requise');
    complete(e,command,e.kind==='board'?priority(S):stage(roster().find(p=>p.id===e.playerId))==='reprise'?'maintain':'read');
   }else{
    check(e.completed&&e.decision,'terminez les échanges ou la décision avant de continuer');
    st.receipts.push(copy(e));st.receipts=st.receipts.slice(-96);st.current=null;promote(st);
   }
   validate(S);return {clubMeetingDecision:{command,meetingId:e.id,kind:e.kind,completed:e.completed}};
  }
  function installHooks(){
   if(installed)return true;installed=true;
   for(const name of ['finishRound','advanceSeason']){
    const original=globalThis[name];if(typeof original!=='function')continue;
    const wrapped=function(){
     const before=S?context():null,result=original.apply(this,arguments),after=S?context():null;
     if(before&&after&&!same(before,after))advanceFrom={from:advanceFrom?.from||before,to:after};
     return result;
    };
    Object.assign(wrapped,original);globalThis[name]=wrapped;
   }
   return true;
  }
  function clearTransient(){advanceFrom=null;}
  return {project,validate,execute,observe,guard,installHooks,clearTransient};
 }
};

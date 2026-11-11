'use strict';
const files=Object.freeze(['press-relations.js','press-question-bank.js','media-evidence-v60.js','media-native-adapter-v60.js','media-world-v60.js','press-conference-interactive.js']);
const commands=Object.freeze(['press_conference']);
function factory(){
 const copy=x=>JSON.parse(JSON.stringify(x)),obj=x=>!!x&&typeof x==='object'&&!Array.isArray(x),int=(x,a,b)=>Number.isInteger(x)&&x>=a&&x<=b,num=(x,a,b)=>Number.isFinite(x)&&x>=a&&x<=b;
 const check=(ok,message='État de presse invalide.')=>{if(!ok)throw Error(message);};
 const world=s=>typeof CDWorldCareer!=='undefined'&&CDWorldCareer.active(s);
 const weekOf=s=>s.franceMode?.version===1?s.franceMode.week:s.round;
 const maxWeek=s=>world(s)?CDWorldCareer.sizing(s).maxRound:s.franceMode?.version===1?34:26;
 const context=s=>s?{season:s.season,week:weekOf(s),club:s.club}:null;
 const invitationId=c=>'press-v1:'+c.season+':'+c.week+':'+c.club;
 const invitationLimit=24;
 const invitationKinds=['arrival','weekly','knockout','season_review'];
 const priorityThemes={arrival:['carriere','vestiaire','formation'],knockout:['phase_finale','avant_match'],season_review:['classement','carriere','supporters']};
 const requiredReason='Ouvrez l’invitation dans Réception et publiez vos réponses avant de poursuivre.';
 const mandatory=()=>typeof nativeMandatoryPress!=='undefined'&&nativeMandatoryPress;
 function recorded(s,c){
  const history=s.pressConference?.history;
  return Array.isArray(history)&&history.some(h=>h.season===c.season&&h.week===c.week&&(h.club===undefined||h.club===c.club));
 }
 function invitationStatus(s,entry){
  if(entry.status!=='pending')return entry.status;
  if(recorded(s,entry.context))return 'published';
  return entry.id===invitationId(context(s))?'pending':'expired';
 }
 const pendingInvitation=s=>s?.pressInvitations?.entries.find(i=>invitationStatus(s,i)==='pending');
 function invitationKind(s,previous,current,created){
  if(created||previous&&previous.club!==current.club||current.week===0&&(current.season===1||
   s.managerMobility?.history.some(move=>move.toClub===current.club&&move.arrivalSeason===current.season)))return 'arrival';
  if(s.phase==='ended')return 'season_review';
  const phase=world(s)?CDWorldCareer.userFixture(s)?.phase:
   s.franceMode?.version===1?CDFranceCompetition.userFixture(s)?.phase:nextMatch()?s.phase:null;
  return phase&&!['league','pool'].includes(phase)?'knockout':'weekly';
 }
 function observeInvitation(previous=null,created=false){
  if(!mandatory()||!S||S.live)return;
  const current=context(S);
  const id=invitationId(current);
  const entries=S.pressInvitations?.entries??[];
  for(const entry of entries)entry.status=invitationStatus(S,entry);
  if(entries.some(i=>i.id===id))return;
  const kind=invitationKind(S,previous,current,created);
  const published=recorded(S,current);
  if(!published&&(CDV60RichPress.prepare(S,priorityThemes[kind])?.length??0)<2)return;
  S.pressInvitations={version:1,entries:[{id,context:current,kind,status:published?'published':'pending'},...entries].slice(0,invitationLimit)};
 }
 function canPublish(s,invitation){
  return !!invitation&&!s.live&&(CDV60RichPress.prepare(s,priorityThemes[invitation.kind])?.length??0)>=2;
 }
 function requiresConference(){
  return mandatory()&&canPublish(S,pendingInvitation(S));
 }
 function guardProgress(){
  check(!requiresConference(),requiredReason);
 }
 const keys=(value,allowed)=>obj(value)&&Object.keys(value).every(k=>allowed.includes(k));
 const text=t=>typeof t==='string'&&t.length>0&&t.length<=600&&!/[\u0000-\u0008\u000b\u000c\u000e-\u001f]/.test(t);
 const reporter=id=>CDPressQuestionBank.journalists.find(j=>j.id===id);
 // L'archive garde la signature écrite le jour de la conférence. L'écran présente
 // l'identité actuelle du même journaliste (base, ou pack actif par projection),
 // comme pour les joueurs et les clubs ; la sauvegarde n'est pas réécrite.
 const signature=id=>{const j=reporter(id);return {id:j.id,name:j.name,outlet:j.outlet};};
 const validAnswer=(id,answerId)=>CDPressQuestionBank.questions.some(q=>q.id===id&&q.answers.some(a=>a.id===answerId));
 function validate(s){
  if(!s)return true;
  // Anciennes carrières : les identifiants de dix journalistes ont changé. On les renomme sans toucher aux textes archivés.
  {const anciens=CDPressQuestionBank.legacyJournalistIds||{},cle=t=>{let h=2166136261;for(const o of unescape(encodeURIComponent(String(t)))){h^=o.charCodeAt(0);h=Math.imul(h,16777619);}return (h>>>0).toString(16).padStart(8,'0');},neuf=id=>reporter(id)?id:anciens[cle(id)]||id;
   for(const h of s.pressConference?.history||[])if(h.journalist?.id!==undefined)h.journalist.id=neuf(h.journalist.id);
   for(const e of s.pressConference?.lastOutcome?.exchanges||[])if(e.journalistId!==undefined)e.journalistId=neuf(e.journalistId);
   const c=s.pressPeople?.contacts;if(c)for(const id of Object.keys(c)){const n=neuf(id);if(n!==id&&c[n]===undefined){c[n]=c[id];delete c[id];}}}
  const date=(season,week)=>int(season,1,s.season)&&int(week,0,maxWeek(s))&&(season<s.season||week<=weekOf(s));
  const clubId=id=>typeof id==='string'&&/^club-\d+$/.test(id)&&int(Number(id.slice(5)),0,s.clubs.length-1);
  if(s.pressInvitations!==undefined){
   const agenda=s.pressInvitations,currentId=invitationId(context(s));
   check(keys(agenda,['version','entries'])&&agenda.version===1&&Array.isArray(agenda.entries)&&agenda.entries.length>0&&agenda.entries.length<=invitationLimit,'Agenda des invitations de presse invalide.');
   const seen=new Set();
   let prior=Infinity,pending=0;
   for(const entry of agenda.entries){
    check(keys(entry,['id','context','kind','status'])&&keys(entry.context,['season','week','club']),'Invitation de presse invalide.');
    const c=entry.context, order=c.season*100+c.week;
    check(date(c.season,c.week)&&int(c.club,0,s.clubs.length-1)&&entry.id===invitationId(c)&&!seen.has(entry.id)&&order<=prior&&invitationKinds.includes(entry.kind)&&['pending','published','expired'].includes(entry.status),'Invitation de presse invalide.');
    // Un ancien moteur peut conserver le courrier brut en avançant ou en publiant.
    // Son statut est alors calculé à la lecture, puis réglé à la prochaine transition.
    if(entry.status==='pending')check(++pending===1,'Plusieurs invitations de presse en attente.');
    if(entry.status==='expired')check(entry.id!==currentId||s.phase==='ended','Invitation de presse expirée pendant le créneau courant.');
    if(entry.status==='published')check(recorded(s,c),'Reçu de presse sans conférence publiée.');
    seen.add(entry.id);prior=order;
   }
  }
  if(s.pressRelations!==undefined){
   const p=s.pressRelations;check(keys(p,['version','clubId','season','week','mediaTrust','fanTrust','boardPressure','morale','stories','history','used'])&&p.version===1&&clubId(p.clubId)&&date(p.season,p.week));
   check([p.mediaTrust,p.fanTrust,p.boardPressure,p.morale].every(x=>num(x,0,100)));
   check(Array.isArray(p.stories)&&p.stories.length<=40&&Array.isArray(p.history)&&p.history.length<=500&&Array.isArray(p.used)&&p.used.length<=500);
   const ownDate=(season,week)=>date(season,week)&&(season<p.season||season===p.season&&week<=p.week);
   check(new Set(p.used).size===p.used.length,'Interview de presse répétée.');
   check(new Set(p.stories.map(e=>e?.id)).size===p.stories.length,'Histoire de presse répétée.');
   for(const id of p.used){const m=typeof id==='string'&&id.match(/^(\d+):(\d+):([a-z]+)$/);check(m&&ownDate(+m[1],+m[2])&&CDPressRelations.topics.includes(m[3]));}
   for(const e of p.stories){check(keys(e,['type','id','season','week','topic','tone','performance','delta'])&&e.type==='press'&&ownDate(e.season,e.week)&&CDPressRelations.topics.includes(e.topic)&&CDPressRelations.tones.includes(e.tone)&&int(e.performance,-2,2)&&e.id===e.season+':'+e.week+':'+e.topic&&(e.season<p.season-1||p.used.includes(e.id)));check(keys(e.delta,['mediaTrust','fanTrust','boardPressure','morale'])&&Object.keys(e.delta).length===4&&Object.values(e.delta).every(x=>num(x,-30,30)));}
   let prior=-1;for(const h of p.history){check(keys(h,['season','week','mediaTrust','fanTrust','boardPressure','morale'])&&ownDate(h.season,h.week)&&[h.mediaTrust,h.fanTrust,h.boardPressure,h.morale].every(x=>num(x,0,100)));const d=h.season*100+h.week;check(d>=prior);prior=d;}
  }
  if(s.pressConference!==undefined){
   const p=s.pressConference;check(keys(p,['version','history','lastOutcome','week','season','club'])&&p.version===1&&Array.isArray(p.history)&&p.history.length<=500,'Historique de conférence de presse invalide.');
   if(p.week!==undefined)check(int(p.week,0,maxWeek(s)));if(p.season!==undefined)check(int(p.season,1,s.season));if(p.club!==undefined)check(int(p.club,0,s.clubs.length-1));
   const seen=new Set(),groups=new Map();let previous=-1;
   for(const h of p.history){check(keys(h,['id','season','week','answerId','club','questionText','answerText','journalist'])&&date(h.season,h.week)&&CDPressQuestionBank.questions.some(q=>q.id===h.id)&&/^r[0-4]$/.test(h.answerId)&&(h.club===undefined||int(h.club,0,s.clubs.length-1)),'Choix de conférence de presse invalide.');if(h.journalist!==undefined)check(keys(h.journalist,['id','name','outlet'])&&Object.keys(h.journalist).length===3&&!!reporter(h.journalist.id)&&text(h.journalist.name)&&text(h.journalist.outlet),'Journaliste de conférence invalide.');if(h.questionText!==undefined||h.answerText!==undefined)check([h.questionText,h.answerText].every(t=>typeof t==='string'&&t.length>0&&t.length<=600&&!/[\u0000-\u0008\u000b\u000c\u000e-\u001f]/.test(t)),'Libellé de conférence de presse invalide.');const key=h.season+':'+h.week+':'+(h.club??'legacy'),id=key+':'+h.id;check(!seen.has(id),'Choix de conférence de presse répété.');seen.add(id);groups.set(key,(groups.get(key)||0)+1);check(groups.get(key)<=4);const d=h.season*100+h.week;check(d>=previous);previous=d;}
   if(p.lastOutcome!==undefined){const o=p.lastOutcome;check(keys(o,['context','before','after','delta','exchanges'])&&keys(o.context,['season','week','club'])&&date(o.context.season,o.context.week)&&int(o.context.club,0,s.clubs.length-1));for(const key of ['before','after','delta'])check(keys(o[key],['morale','trust','mediaTrust','fanTrust','boardPressure'])&&Object.keys(o[key]).length===5&&Object.values(o[key]).every(x=>num(x,key==='delta'?-100:0,100)));for(const key of Object.keys(o.delta))check(o.after[key]-o.before[key]===o.delta[key]);if(o.exchanges!==undefined){check(Array.isArray(o.exchanges)&&o.exchanges.length>=2&&o.exchanges.length<=4);for(const e of o.exchanges)check(keys(e,['journalistId','before','after','delta'])&&Object.keys(e).length===4&&!!reporter(e.journalistId)&&int(e.before,-100,100)&&int(e.after,-100,100)&&int(e.delta,-6,6)&&e.after-e.before===e.delta,'Retour de relation journaliste invalide.');}check(p.history.some(h=>h.season===o.context.season&&h.week===o.context.week&&(h.club===undefined||h.club===o.context.club)));}
  }
  if(s.pressPeople!==undefined){
   const p=s.pressPeople;check(keys(p,['version','contacts'])&&Object.keys(p).length===2&&p.version===1&&obj(p.contacts)&&Object.keys(p.contacts).length<=30,'Relations personnelles de presse invalides.');
   check(JSON.stringify(p).length<30000,'Mémoire des journalistes trop volumineuse.');
   for(const [id,c] of Object.entries(p.contacts)){
    check(!!reporter(id)&&keys(c,['score','encounters','memory'])&&Object.keys(c).length===3&&int(c.score,-100,100)&&int(c.encounters,1,10000000)&&Array.isArray(c.memory)&&c.memory.length===Math.min(3,c.encounters),'Relation de journaliste invalide.');
    const seen=new Set();let previous=-1;
    for(const e of c.memory){check(keys(e,['season','week','club','questionId','answerId','delta'])&&Object.keys(e).length===6&&date(e.season,e.week)&&int(e.club,0,s.clubs.length-1)&&validAnswer(e.questionId,e.answerId)&&int(e.delta,-6,6),'Mémoire de journaliste invalide.');const archived=s.pressConference?.history?.find(h=>h.season===e.season&&h.week===e.week&&h.club===e.club&&h.id===e.questionId);if(archived)check(archived.journalist?.id===id&&archived.answerId===e.answerId,'Mémoire de journaliste incompatible avec la conférence conservée.');const key=e.season+':'+e.week+':'+e.club+':'+e.questionId,d=e.season*100+e.week;check(!seen.has(key)&&d>=previous,'Mémoire de journaliste répétée ou désordonnée.');seen.add(key);previous=d;}
   }
  }
  return true;
 }
 function measures(s){const p=s.pressRelations;return {morale:s.morale,trust:s.trust,mediaTrust:p?.mediaTrust??50,fanTrust:p?.fanTrust??50,boardPressure:p?.boardPressure??30};}
 const fixtureStages={barrage:'le barrage',elimination:'le match de barrage',quarter:'le quart de finale',semi:'la demi-finale',final:'la finale',r16:'le huitième de finale',access:'le barrage d’accession','third-place':'le match pour la troisième place',promotion:'la manche de promotion'};
 const nameOf=value=>text(value)&&value.trim()&&value.trim().length<=100?value.trim():null;
 function conferenceFacts(s){
  const club=id=>s.clubs.find(c=>c?.id===id);
  const opponent=pair=>Array.isArray(pair)&&pair.length===2&&pair[0]!==pair[1]&&pair.includes(s.club)
   ?nameOf(club(pair.find(id=>id!==s.club))?.name):null;
  let scheduled=null;
  if(s.phase!=='ended'){
   if(world(s))scheduled=CDWorldCareer.userFixture?.(s);
   else if(s.franceMode?.version===1){
    const france=s.franceMode;
    const hasCalendar=france.week>=33||['elite','accession'].every(id=>{
     const league=france.leagues?.[id];
     return league&&(france.week>=30||Array.isArray(league.schedule));
    });
    if(hasCalendar&&typeof CDFranceCompetition!=='undefined')scheduled=CDFranceCompetition.userFixture?.(s);
   }else if(typeof nextMatch==='function'&&typeof S!=='undefined'&&s===S)scheduled={pair:nextMatch(),phase:s.phase};
  }
  const nextOpponent=scheduled&&opponent(scheduled.pair??[scheduled.homeId,scheduled.awayId]);
  const fixture=nextOpponent?{opponent:nextOpponent,stage:Object.hasOwn(fixtureStages,scheduled.phase)?fixtureStages[scheduled.phase]:null}:null;
  const week=weekOf(s);
  let result=null;
  for(const match of Array.isArray(s.history)?s.history:[]){
   const date=match?.week??match?.round;
   if(!int(date,Math.max(0,week-1),week)||(match.season??s.season)!==s.season
      ||result&&date<result.week||!Array.isArray(match.score)||match.score.length!==2
      ||!match.score.every(n=>Number.isSafeInteger(n)&&n>=0))continue;
   const rival=opponent(match.pair);
   if(!rival)continue;
   const index=match.pair.indexOf(s.club);
   result={opponent:rival,week:date,for:match.score[index],against:match.score[1-index]};
  }
  const injured=club(s.club)?.players?.find(p=>Number.isFinite(p?.injury)&&p.injury>0&&nameOf(p.name));
  return {fixture,result,injured:nameOf(injured?.name)};
 }
 function contextualQuestion(q,{fixture,result,injured}){
  const write=(question,answers)=>({...q,question,answers:q.answers.map((a,i)=>({...a,text:answers[i]}))});
  if(fixture&&(q.theme==='avant_match'||q.theme==='phase_finale'&&fixture.stage)){
   const match=(fixture.stage||'le match')+' face à '+fixture.opponent;
   return write('Pour '+match+', quelle est votre priorité ?',[
    'Pour '+match+', je veux qu’on sorte proprement de nos 22 mètres avant de chercher les extérieurs.',
    'Je privilégierai les joueurs qui connaissent nos annonces en touche. Chaque changement devra servir le plan de match.',
    'Je veux qu’on joue dans leur camp dès le coup d’envoi. À nous de leur faire remonter le terrain.',
    'Je garde la composition pour le groupe. La priorité, c’est de sécuriser les renvois et nos premières possessions.',
    'Les flèches du tableau noir ne gagneront pas un mètre. Je veux d’abord des soutiens proches du porteur.'
   ]);
  }
  if(result&&['attaque','defense','defaite','victoire'].includes(q.theme)){
   const match=result.for+'–'+result.against+' face à '+result.opponent;
   const defense=q.theme==='defense';
   let review;
   if(result.for<result.against)review='J’assume nos choix après le '+match+'. '+(defense
    ?'Je veux revoir le rôle du premier plaqueur et du joueur qui ferme son intérieur.'
    :'Je veux revoir à quel moment on choisit de jouer et à quel moment il faut sortir au pied.');
   else if(result.for>result.against)review='On a gagné '+match+'. '+(defense
    ?'Je veux encore vérifier la couverture du fond quand le premier rideau monte.'
    :'Je veux quand même vérifier les soutiens autour du porteur avant de reconduire nos consignes.');
   else review='Le score de '+match+' est resté à égalité. '+(defense
    ?'Je veux travailler la relance après récupération pour tirer profit d’un ballon gagné.'
    :'Je veux travailler comment transformer les possessions près de la ligne en points.');
   if(defense)return write('Après le '+match+', que voulez-vous travailler en défense ?',[
    'Je veux que le premier rideau monte ensemble et que le fond du terrain reste couvert.',
    review,
    'Nous devons fermer l’axe et pousser l’adversaire vers la touche.',
    'Je veux revoir nos replis après perte de balle avant de changer l’organisation.',
    'Le plus court chemin vers le bon plaquage commence souvent par un pas ensemble.'
   ]);
   return write('Après le '+match+', quelle priorité fixez-vous à votre attaque ?',[
    'Je veux des soutiens proches du porteur pour pouvoir rejouer vite après le premier contact.',
    review,
    'Je veux qu’on attaque l’axe avant d’écarter. À nous de fixer leur défense.',
    'Je regarderai d’abord nos sorties de camp. Je déciderai ensuite où nous devons accélérer.',
    'Un porteur ne devrait pas avoir à lancer un avis de recherche. Je veux du soutien dès le contact.'
   ]);
  }
  if(injured&&q.theme==='blessures')return write(injured+' est indisponible. Comment gérez-vous cette absence ?',[
   'Pendant l’absence de '+injured+', je prépare un joueur qui connaît déjà les annonces du poste.',
   'Je ne donnerai pas de date pour '+injured+'. Nous préparerons la suite avec le groupe disponible.',
   'Je veux que les joueurs disponibles prennent leur place. Le groupe doit pouvoir avancer pendant cette absence.',
   'Je garderai les détails pour le joueur et le staff. Le retour dépendra de sa disponibilité.',
   'Le calendrier ne soigne personne. Je préfère travailler dès maintenant la couverture du poste.'
  ]);
  return q;
 }
 // A callback is a quotation from this saved career, never a reconstruction
 // from a tone or the question bank. Its exact displayed text is archived below.
 function prepareConference(s,invitation){
  const questions=mandatory()&&!invitation?null:CDV60RichPress.prepare(s,priorityThemes[invitation?.kind]);
  if(!questions||questions.length<2)return null;
  const history=s.pressConference?.history||[],prefix='Lors de notre échange de saison ';
  const facts=conferenceFacts(s);
  return questions.map(base=>{
   const q=contextualQuestion(base,facts);
   const sources=history.filter(h=>h.journalist?.id===q.journalist.id&&h.club===s.club&&h.season===s.season&&int(h.week,0,weekOf(s)-1)&&CDPressQuestionBank.questions.some(source=>source.id===h.id&&source.theme===q.theme)&&text(h.questionText)&&text(h.answerText)&&!h.questionText.startsWith(prefix));
   for(const h of sources.slice().reverse()){
    const reminder=prefix+h.season+', semaine '+(h.week+1)+', pour ce club, vous aviez répondu : « '+h.answerText+' ». ';
    if(history.some(p=>p.journalist?.id===q.journalist.id&&p.club===s.club&&p.season===s.season&&p.questionText?.startsWith(reminder)))continue;
    const question=reminder+q.question;if(!text(question))continue;
    return {...q,question,followUp:{context:{season:h.season,week:h.week,club:h.club},quote:h.answerText,question:h.questionText,label:'Déclaration archivée · saison '+h.season+' · semaine '+(h.week+1)+' · même club et même journaliste'}};
   }
   return q;
  });
 }
 function project(){
  if(!S)return null;
  const events=CDMediaNativeAdapter.collect(S),edition=world(S)?CDWorldCareer.edition(S):null;
  const divisionIds=edition?[...edition.leagueIds,'champions','challenge','access',...(edition.leagueIds.includes('jlo-d2')?['jlo-d1-d2']:[]),...(edition.leagueIds.includes('nationale')?['access-nationale']:[])]:S.franceMode?.version===1?['elite','accession','access']:['historical'];
  const presentationNames=new Map((edition?.registry.leagues||[]).map(l=>[l.id,l.name]));
  const divisions=divisionIds.map(id=>({id,label:({elite:'Élite',accession:'Accession',access:'Barrage d’accession',prem:'Premiership',urc:'United Rugby Championship',champions:'Coupe des champions',challenge:'Challenge européen',historical:'Championnat historique','jlo-d1-d2':'Barrage Japon D1 / D2','access-nationale':'Barrage Pro D2 / Nationale'})[id]??presentationNames.get(id)??'Compétition',standings:events.filter(e=>e.kind==='standing'&&e.facts.divisionId===id).map(e=>copy(e.facts)),results:events.filter(e=>e.kind==='result'&&e.facts.divisionId===id).slice(-24).reverse().map(e=>({id:e.id,season:e.season,week:e.week,...copy(e.facts)})),injuries:events.filter(e=>e.kind==='injury'&&e.facts.divisionId===id).map(e=>({...copy(e.facts),playerName:S.clubs.find(c=>c.id===e.facts.clubId)?.players?.find(p=>p.id===e.facts.playerId)?.name||String(e.facts.playerId)}))})).filter(d=>d.standings.length||d.results.length||d.injuries.length);
  const people=CDPressQuestionBank.journalists.map(j=>{
   const c=S.pressPeople?.contacts?.[j.id],score=c?.score??0,encounters=c?.encounters??0,style=CDPressRelations.dialogueStyles[j.style];
   return {...copy(j),identityLabel:j.fictional?'Personnage fictif':'Journaliste référencé',personality:style.personality,styleLabel:style.label,score,encounters,relationLabel:CDPressRelations.relationLabel(score,encounters),memory:(c?.memory||[]).map(e=>{const h=S.pressConference?.history?.find(h=>h.journalist?.id===j.id&&h.season===e.season&&h.week===e.week&&h.club===e.club&&h.id===e.questionId&&h.answerId===e.answerId);return {...copy(e),question:h?.questionText??null,answer:h?.answerText??null,toneLabel:CDPressRelations.dialogueTones[CDPressQuestionBank.questions.find(q=>q.id===e.questionId).answers.find(a=>a.id===e.answerId).tone]};})};
  });
  const invitation=pendingInvitation(S);
  const invitations=(S.pressInvitations?.entries??[]).map(entry=>({...copy(entry),status:invitationStatus(S,entry)}));
  const lastOutcome=copy(S.pressConference?.lastOutcome??null);
  if(lastOutcome){
   const receipt=invitations.find(entry=>entry.status==='published'&&entry.id===invitationId(lastOutcome.context));
   if(receipt)lastOutcome.invitationId=receipt.id;
  }
  const questions=prepareConference(S,invitation),projected=questions?.map(q=>{
   const person=people.find(p=>p.id===q.journalist.id);
   return {...copy(q),journalist:{...copy(q.journalist),identityLabel:person.identityLabel,personality:person.personality,styleLabel:person.styleLabel},relation:{score:person.score,label:person.relationLabel,encounters:person.encounters},answers:q.answers.map(a=>{const effects=CDPressRelations.dialogueEffect(q.journalist,a.tone,q.theme,person.score),mod=['crise','direction'].includes(q.theme)?2:1;const applied={morale:effects.morale*mod,media:effects.media*mod,fans:effects.fans*mod,pressure:effects.pressure*mod,relation:Math.max(-100,Math.min(100,person.score+effects.relation))-person.score};const signed=n=>n>=0?'+'+n:String(n);return {...copy(a),toneLabel:CDPressRelations.dialogueTones[a.tone],effects:applied,consequence:'Moral '+signed(applied.morale)+' · médias '+signed(applied.media)+' · supporters '+signed(applied.fans)+' · pression '+signed(applied.pressure)+' · relation '+signed(applied.relation)};})};
  });
  const required=mandatory()&&!!questions;
  const reason=S.live?'Conférence indisponible pendant un match.':required?requiredReason:
   questions?'':mandatory()?'Aucune invitation de presse en attente.':'Conférence déjà réalisée cette semaine.';
  return {context:context(S),notice:'Dialogues et personnalités simulés. Catalogue de journalistes référencés et de personnages fictifs ; aucune citation réelle. Les relations sont personnelles au coach.',journal:{divisions},metrics:measures(S),people,invitations,conference:{available:!!questions,required,invitationId:invitation?.id??null,reason,memoryNotice:'Une relance cite une déclaration archivée du même journaliste, du même club et de cette saison. Une archive absente ou déjà relancée ne devient pas un souvenir inventé.',questions:projected||[]},history:copy((S.pressConference?.history||[]).slice(-40)).map(h=>({...h,...(h.journalist&&reporter(h.journalist.id)?{journalist:signature(h.journalist.id)}:{}),question:h.questionText??null,answer:h.answerText??null})),lastOutcome};
 }
 function execute(command,payload){
  check(command==='press_conference','Commande de presse inconnue.');check(!!S,'Créez ou importez une carrière.');check(!S.live,'Conférence indisponible pendant un match.');validate(S);
  check(keys(payload,['context','answers','invitationId'])&&keys(payload.context,['season','week','club'])&&Object.keys(payload.context).length===3&&Array.isArray(payload.answers),'Paramètres de conférence de presse invalides.');
  check(JSON.stringify(context(S))===JSON.stringify({season:payload.context.season,week:payload.context.week,club:payload.context.club}),'Préparation de conférence périmée.');
  const invitation=pendingInvitation(S);
  if(mandatory()||payload.invitationId!==undefined)check(!!invitation&&payload.invitationId===invitation.id,'Invitation de presse périmée ou inconnue.');
  const questions=prepareConference(S,invitation);check(!!questions,'Conférence déjà réalisée cette semaine.');check(payload.answers.length===questions.length,'Réponses de conférence incomplètes.');
  questions.forEach((q,i)=>check(keys(payload.answers[i],['questionId','answerId'])&&payload.answers[i].questionId===q.id&&q.answers.some(a=>a.id===payload.answers[i].answerId),'Question ou réponse de conférence périmée.'));
  const scores=questions.map(q=>({journalistId:q.journalist.id,before:S.pressPeople?.contacts?.[q.journalist.id]?.score??0}));
  const before=measures(S);check(CDV60RichPress.apply(S,payload.answers.map(a=>a.answerId),priorityThemes[invitation?.kind])===true,'Conférence de presse refusée.');const after=measures(S),delta=Object.fromEntries(Object.keys(before).map(k=>[k,after[k]-before[k]]));
  for(const [index,q] of questions.entries()){
   const archived=S.pressConference.history.find(h=>h.id===q.id&&h.season===S.season&&h.week===weekOf(S)&&h.club===S.club);
   check(!!archived,'Déclaration de conférence non archivée.');
   archived.questionText=q.question;
   archived.answerText=q.answers.find(a=>a.id===payload.answers[index].answerId).text;
  }
  if(invitation)invitation.status='published';
  S.pressConference.lastOutcome={context:context(S),before,after,delta,exchanges:scores.map(e=>{const after=S.pressPeople.contacts[e.journalistId].score;return {...e,after,delta:after-e.before};})};validate(S);return {pressOutcome:{...copy(S.pressConference.lastOutcome),...(invitation?{invitationId:invitation.id}:{})}};
 }
 function installHooks(){
  if(typeof advanceSeason!=='function'||advanceSeason.__nativePressSeason)return true;
  const previous=advanceSeason;
  const wrapped=function(...args){const result=previous(...args);if(S?.pressRelations)while(S.pressRelations.season<S.season)S.pressRelations=CDPressRelations.nextSeason(S.pressRelations);return result;};
  wrapped.__nativePressSeason=true;advanceSeason=wrapped;return true;
 }
 return {project,validate,execute,installHooks,context,observeInvitation,guardProgress,requiresConference};
}
module.exports={files,commands,factory};
